# =============================================================================
# 03_tempo_extract.R - subset TEMPO HCHO granules over the sites via OPeNDAP
#
# 1. Reads the variable/dimension layout (DMR) and the lat/lon grid once.
# 2. For every granule, requests only a lat/lon box covering all sites (DAP4
#    constraint expression, netCDF-4 response) - a few hundred KB instead of
#    the ~1 GB full file.
# 3. Keeps a (2*half_width+1)^2 block of cells around each site, unscreened,
#    so quality thresholds can be changed later without downloading again.
# Serves both arms (options(hcho.arm = "coatts" | "threeh")); caches are per arm.
# Output: A$cells (data/processed/tempo_site_cells.csv.gz for coatts)
# Requires Earthdata Login (EARTHDATA_TOKEN in ~/.Renviron, or ~/.netrc).
# =============================================================================
source("R/00_config.R")
log_msg("Arm: ", ARM)

manifest <- read_tbl(A$manifest) |>
  mutate(mid_utc = as.POSIXct(mid_utc, tz = "UTC"))
coatts <- read_tbl(A$samples)
sites  <- coatts |> distinct(site, lat, lon) |> filter(!is.na(lat)) |> arrange(site)
granules <- manifest |> distinct(granule, opendap_url, mid_utc)
log_msg(nrow(granules), " granules, ", nrow(sites), " sites")

# netCDF-4 files start with the HDF5 signature; classic netCDF with "CDF"
is_netcdf4 <- function(path) {
  if (!file.exists(path) || file.size(path) <= 8) return(FALSE)
  head <- readBin(path, "raw", n = 4)
  identical(head, as.raw(c(0x89, 0x48, 0x44, 0x46))) || identical(head[1:3], charToRaw("CDF"))
}

# coordinate variables are stored as netCDF dimensions in ncdf4
get_coord <- function(nc, name) {
  if (name %in% names(nc$dim) && isTRUE(nc$dim[[name]]$create_dimvar)) return(as.vector(nc$dim[[name]]$vals))
  as.vector(ncdf4::ncvar_get(nc, name))
}

check_resp <- function(resp, what) {
  st <- httr2::resp_status(resp)
  if (st %in% c(401, 403)) {
    stop(what, ": HTTP ", st, " - Earthdata Login failed. Check EARTHDATA_TOKEN ",
         "(tokens expire after 60 days) or ~/.netrc.")
  }
  if (st >= 400) stop(what, ": HTTP ", st, " - ", substr(httr2::resp_body_string(resp), 1, 300))
  invisible(resp)
}

# ---- 1. layout: variables, dimensions, grid --------------------------------
layout_path <- file.path(P$interim, "tempo_layout.rds")
if (file.exists(layout_path) && !identical(readRDS(layout_path)$requested, CFG$tempo_vars)) {
  log_msg("tempo_vars changed since the layout was cached - rebuilding it")
  unlink(layout_path)
}
if (!file.exists(layout_path)) {
  url0 <- granules$opendap_url[1]
  log_msg("Reading DMR from ", basename(url0))
  resp <- edl_request(paste0(url0, ".dmr.xml")) |>
    httr2::req_error(is_error = function(r) FALSE) |> httr2::req_perform()
  check_resp(resp, "DMR")
  dmr <- xml2::read_xml(httr2::resp_body_string(resp)) |> xml2::xml_ns_strip()

  dims <- xml2::xml_find_all(dmr, "/Dataset/Dimension")
  dim_sizes <- setNames(as.integer(xml2::xml_attr(dims, "size")),
                        paste0("/", xml2::xml_attr(dims, "name")))
  vnodes <- xml2::xml_find_all(dmr, "//*[Dim]")
  var_path <- map_chr(vnodes, function(n) {
    grp <- xml2::xml_attr(xml2::xml_find_all(n, "ancestor::Group"), "name")
    paste0("/", paste(c(grp, xml2::xml_attr(n, "name")), collapse = "/"))
  })
  var_dims <- map(vnodes, ~ xml2::xml_attr(xml2::xml_find_all(.x, "Dim"), "name")) |>
    setNames(var_path)

  wanted <- intersect(CFG$tempo_vars, var_path)
  absent_vars <- setdiff(CFG$tempo_vars, var_path)
  if (length(absent_vars)) log_msg("Not in this collection (skipped): ", paste(absent_vars, collapse = ", "))
  if (!"/product/vertical_column" %in% wanted) stop("vertical_column not found in DMR.")

  log_msg("Reading latitude/longitude grid")
  tmp <- tempfile(fileext = ".nc4")
  ce  <- utils::URLencode("/latitude;/longitude", reserved = TRUE)
  resp <- edl_request(paste0(url0, ".dap.nc4?dap4.ce=", ce)) |>
    httr2::req_error(is_error = function(r) FALSE) |> httr2::req_perform(path = tmp)
  check_resp(resp, "grid")
  if (!is_netcdf4(tmp)) stop("Grid response is not netCDF-4: ", readLines(tmp, n = 3, warn = FALSE))
  nc <- ncdf4::nc_open(tmp)
  lat <- get_coord(nc, "latitude")
  lon <- get_coord(nc, "longitude")
  ncdf4::nc_close(nc); unlink(tmp)

  saveRDS(list(requested = CFG$tempo_vars, dim_sizes = dim_sizes, var_dims = var_dims[wanted], wanted = wanted,
               lat = lat, lon = lon), layout_path)
}
L <- readRDS(layout_path)
log_msg("Grid ", length(L$lat), " x ", length(L$lon), "; variables: ", paste(basename(L$wanted), collapse = ", "))

# ---- 2. index box (0-based, inclusive) ---------------------------------------
sites <- sites |>
  mutate(i = map_int(lat, ~ which.min(abs(L$lat - .x))),
         j = map_int(lon, ~ which.min(abs(L$lon - .x))),
         cell_dist_deg = sqrt((L$lat[i] - lat)^2 + (L$lon[j] - lon)^2))
if (any(sites$cell_dist_deg > 0.03)) warning("Some sites fall outside the TEMPO grid.")

pad <- CFG$half_width_cells + CFG$bbox_pad_cells
i0 <- max(min(sites$i) - pad, 1); i1 <- min(max(sites$i) + pad, length(L$lat))
j0 <- max(min(sites$j) - pad, 1); j1 <- min(max(sites$j) + pad, length(L$lon))
log_msg(sprintf("Box: lat %.2f to %.2f, lon %.2f to %.2f (%d x %d cells)",
                L$lat[i0], L$lat[i1], L$lon[j0], L$lon[j1], i1 - i0 + 1, j1 - j0 + 1))

index_for <- function(dimname) {
  size <- if (dimname %in% names(L$dim_sizes)) L$dim_sizes[[dimname]] else NA
  if (str_detect(dimname, "lat")) return(sprintf("[%d:1:%d]", i0 - 1, i1 - 1))
  if (str_detect(dimname, "lon")) return(sprintf("[%d:1:%d]", j0 - 1, j1 - 1))
  if (!is.na(size) && size == 1) return("[0:1:0]")
  ""
}
ce_parts <- c(sprintf("/latitude[%d:1:%d]", i0 - 1, i1 - 1),
              sprintf("/longitude[%d:1:%d]", j0 - 1, j1 - 1),
              "/time",
              map_chr(L$wanted, ~ paste0(.x, paste(map_chr(L$var_dims[[.x]], index_for), collapse = ""))))
CE <- utils::URLencode(paste(ce_parts, collapse = ";"), reserved = TRUE)

# provenance: exactly what is requested from every granule
writeLines(c(paste("collection:", CFG$tempo_collection),
             paste("written:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
             sprintf("box (1-based rows/cols): lat %d-%d, lon %d-%d", i0, i1, j0, j1),
             "constraint expression (DAP4):", paste(ce_parts, collapse = ";\n")),
           A$request_spec)

# ---- 3. extraction from one subset file -------------------------------------
read_latlon_matrix <- function(nc, vname) {
  v <- nc$var[[vname]]
  a <- ncdf4::ncvar_get(nc, vname, collapse_degen = FALSE)
  dn <- map_chr(v$dim, "name")
  ilat <- which(str_detect(dn, "lat")); ilon <- which(str_detect(dn, "lon"))
  if (length(ilat) != 1 || length(ilon) != 1) {           # fall back to R order (lon, lat, time)
    ilon <- 1; ilat <- 2
  }
  other <- setdiff(seq_along(dim(a)), c(ilat, ilon))
  a <- aperm(a, c(ilat, ilon, other))
  matrix(a, nrow = dim(a)[1], ncol = dim(a)[2])           # first time step
}

extract_cells <- function(path, granule) {
  nc <- ncdf4::nc_open(path)
  on.exit(ncdf4::nc_close(nc))
  lat <- get_coord(nc, "latitude")
  lon <- get_coord(nc, "longitude")
  tvals <- tryCatch(get_coord(nc, "time"), error = function(e) NA_real_)
  tunits <- tryCatch(ncdf4::ncatt_get(nc, "time", "units")$value, error = function(e) "")
  origin <- str_match(tunits, "since\\s+([0-9-]+[ T]?[0-9:]*)")[, 2]
  scan_start <- if (!is.na(origin)) ymd_hms(origin, truncated = 3, tz = "UTC") + tvals[1] else as.POSIXct(NA)
  present <- intersect(sub("^/", "", L$wanted), names(nc$var))
  mats <- map(setNames(present, basename(present)), ~ read_latlon_matrix(nc, .x))

  hw <- CFG$half_width_cells
  map(seq_len(nrow(sites)), function(k) {
    ii <- which.min(abs(lat - sites$lat[k])); jj <- which.min(abs(lon - sites$lon[k]))
    blk <- expand_grid(di = -hw:hw, dj = -hw:hw) |>
      mutate(row_i = ii + di, col_j = jj + dj) |>
      filter(row_i >= 1, row_i <= length(lat), col_j >= 1, col_j <= length(lon))
    idx  <- cbind(blk$row_i, blk$col_j)
    vals <- as_tibble(lapply(mats, function(m) m[idx]))
    bind_cols(tibble(granule = granule, scan_start_utc = scan_start, site = sites$site[k],
                     di = blk$di, dj = blk$dj, cell_lat = lat[blk$row_i], cell_lon = lon[blk$col_j]),
              vals)
  }) |> list_rbind()
}

# ---- 4. download + extract, in batches ---------------------------------------
cell_file <- function(g) file.path(A$cells_dir, paste0(tools::file_path_sans_ext(g), ".csv"))
nc_file   <- function(g) file.path(P$raw_tempo, sub("\\.nc$", A$subset_suffix, g))

# Cached cell files are only valid for the site set they were extracted for
sites_path <- A$sites_file
if (file.exists(sites_path)) {
  prev <- read_tbl(sites_path)
  if (!setequal(prev$site, sites$site) ||
      !isTRUE(all.equal(arrange(prev, site)$lat, sites$lat, tolerance = 1e-6))) {
    log_msg("Site list changed since cells were extracted - clearing cached cells so every granule is re-extracted")
    unlink(list.files(A$cells_dir, full.names = TRUE))
  }
}
data.table::fwrite(select(sites, site, lat, lon), sites_path)

todo <- granules |> filter(!file.exists(cell_file(granule)))
if (!is.na(CFG$max_granules)) {
  todo <- head(todo, CFG$max_granules)
  log_msg("TEST MODE: processing only ", nrow(todo), " granules (CFG$max_granules)")
}
log_msg(nrow(todo), " granules still to process (", nrow(granules) - nrow(todo), " cached)")

par_formals <- names(formals(httr2::req_perform_parallel))

perform_batch <- function(b) {
  need <- b |> filter(!map_lgl(nc_file(granule), is_netcdf4))
  if (nrow(need)) {
    reqs  <- map(need$opendap_url, ~ edl_request(paste0(.x, ".dap.nc4?dap4.ce=", CE)))
    paths <- nc_file(need$granule)
    args  <- list(reqs, paths = paths, on_error = "continue", progress = FALSE)
    if ("max_active" %in% par_formals) {
      args$max_active <- CFG$n_parallel
    } else if ("pool" %in% par_formals) {
      args$pool <- curl::new_pool(total_con = CFG$n_parallel, host_con = CFG$n_parallel)
    }
    try(do.call(httr2::req_perform_parallel, args), silent = TRUE)
    # sequential retry for anything that failed or returned a non-netCDF body
    for (k in which(!map_lgl(paths, is_netcdf4))) {
      unlink(paths[k])
      resp <- try(reqs[[k]] |> httr2::req_error(is_error = function(r) FALSE) |>
                    httr2::req_perform(path = paths[k]), silent = TRUE)
      if (inherits(resp, "try-error")) { warning(need$granule[k], ": ", resp); next }
      if (httr2::resp_status(resp) %in% c(401, 403)) check_resp(resp, need$granule[k])
      if (!is_netcdf4(paths[k])) { warning(need$granule[k], ": HTTP ", httr2::resp_status(resp)); unlink(paths[k]) }
    }
  }
  for (k in seq_len(nrow(b))) {
    f <- nc_file(b$granule[k])
    if (!is_netcdf4(f)) next
    cells <- tryCatch(extract_cells(f, b$granule[k]), error = function(e) {
      warning(b$granule[k], ": ", conditionMessage(e)); NULL })
    if (is.null(cells)) next
    data.table::fwrite(cells, cell_file(b$granule[k]))
    if (!CFG$keep_subsets) unlink(f)
  }
}

batch_size <- 40
if (nrow(todo)) {
  batches <- split(todo, ceiling(seq_len(nrow(todo)) / batch_size))
  t0 <- Sys.time()
  for (bi in seq_along(batches)) {
    perform_batch(batches[[bi]])
    done_n <- min(bi * batch_size, nrow(todo))
    el <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
    log_msg(sprintf("  %d/%d granules  (%.1f min elapsed, ~%.0f min left)",
                    done_n, nrow(todo), el, el / done_n * (nrow(todo) - done_n)))
  }
}

# ---- 5. combine ---------------------------------------------------------------
files <- cell_file(granules$granule)
files <- files[file.exists(files)]
id_cols <- c("granule", "scan_start_utc", "site")
cells <- data.table::rbindlist(
  lapply(files, data.table::fread, colClasses = list(character = id_cols), integer64 = "double"), fill = TRUE)
# a granule whose variable is entirely missing is read as logical/character;
# force every value column to numeric so the combined file has one type per column
for (col in setdiff(names(cells), id_cols)) {
  data.table::set(cells, j = col, value = suppressWarnings(as.numeric(as.character(cells[[col]]))))
}
data.table::fwrite(cells, A$cells)
log_msg("Wrote ", nrow(cells), " cell rows from ", length(files), "/", nrow(granules),
        " granules to ", A$cells)
missing_g <- nrow(granules) - length(files)
if (missing_g) log_msg("NOTE: ", missing_g, " granules failed - rerun this script to retry them.")
