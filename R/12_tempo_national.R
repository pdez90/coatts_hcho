# =============================================================================
# 12_tempo_national.R - TEMPO subsets over the national AQS sites
#
# Same idea as step 03, but for many sites spread across the country: the sites
# are grouped into boxes ("clusters"), and one OPeNDAP request per cluster and
# scan returns a lat/lon box covering that cluster's sites. Granules are found
# with one CMR query per cluster and month (split automatically if a query fills
# its page), then kept only if a scan falls inside one of that cluster's sample
# windows, padded by CFG$aqs_lag_pad_h so the lag analysis has scans on each side.
#
# Which samples are extracted is set by CFG$aqs_arm_durations - run the
# sub-daily sites first ("3 h", "8 h"), then the 24-h sites, so a long run can
# be split. Everything caches: rerun to resume.
# Needs steps 10 and 11, and Earthdata Login (EARTHDATA_TOKEN or ~/.netrc).
# Outputs: data/processed/aqs_tempo_site_cells.csv.gz
#          data/processed/aqs_tempo_manifest.csv
#          data/interim/aqs_tempo_cells/<cluster>/<granule>.csv  (cache)
# =============================================================================
source("R/00_config.R")

samples_path <- file.path(P$processed, "aqs_hcho_samples.csv")
if (!file.exists(samples_path)) stop("Run R/11_aqs_samples.R first (no ", samples_path, ")")

# Cells and manifests are cached per duration set: adding the 24-h sites later
# must not change the site list of a box that already holds sub-daily cells
# (that would clear them). Step 5 below combines every arm's cells.
arm_tag    <- gsub("[^0-9a-z]", "", paste(sort(CFG$aqs_arm_durations), collapse = "_"))
cells_root <- file.path(P$interim, "aqs_tempo_cells")
cells_dir  <- file.path(cells_root, arm_tag)
man_dir    <- file.path(P$interim, "aqs_manifests", arm_tag)
invisible(lapply(c(cells_dir, man_dir), dir.create, recursive = TRUE, showWarnings = FALSE))

samples <- read_tbl(samples_path, colClasses = list(character = c("site_id", "qualifiers"))) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"),
         end_utc   = as.POSIXct(end_utc, tz = "UTC"),
         sample_date_local = as.Date(sample_date_local)) |>
  filter(duration_class %in% CFG$aqs_arm_durations, !is.na(lat), !is.na(lon), !is.na(start_utc))
if (!nrow(samples)) stop("No samples with durations ", paste(CFG$aqs_arm_durations, collapse = ", "))

cluster_of <- function(lat, lon) sprintf("lat%+03d_lon%+04d",
                                         round(lat / CFG$aqs_cluster_deg_lat),
                                         round(lon / CFG$aqs_cluster_deg_lon))
sites <- samples |>
  group_by(site_id) |>
  summarise(lat = median(lat), lon = median(lon), site_name = first(site_name),
            duration_class = paste(sort(unique(duration_class)), collapse = "+"), .groups = "drop") |>
  mutate(cluster = cluster_of(lat, lon)) |>
  arrange(cluster, site_id)
samples <- left_join(samples, select(sites, site_id, cluster), by = "site_id")
clusters <- sort(unique(sites$cluster))
if (!is.na(CFG$aqs_max_clusters)) {
  clusters <- head(clusters, CFG$aqs_max_clusters)
  log_msg("TEST MODE: only the first ", length(clusters), " clusters (CFG$aqs_max_clusters)")
}
log_msg(nrow(sites), " sites (", paste(CFG$aqs_arm_durations, collapse = ", "), ") in ",
        length(clusters), " clusters; ", nrow(samples), " samples")

# ---- shared helpers (same logic as step 03) ---------------------------------
is_netcdf4 <- function(path) {
  if (!file.exists(path) || file.size(path) <= 8) return(FALSE)
  head <- readBin(path, "raw", n = 4)
  identical(head, as.raw(c(0x89, 0x48, 0x44, 0x46))) || identical(head[1:3], charToRaw("CDF"))
}
get_coord <- function(nc, name) {
  if (name %in% names(nc$dim) && isTRUE(nc$dim[[name]]$create_dimvar)) return(as.vector(nc$dim[[name]]$vals))
  as.vector(ncdf4::ncvar_get(nc, name))
}
check_resp <- function(resp, what) {
  st <- httr2::resp_status(resp)
  if (st %in% c(401, 403)) stop(what, ": HTTP ", st, " - Earthdata Login failed. Check EARTHDATA_TOKEN ",
                                "(tokens expire after 60 days) or ~/.netrc.")
  if (st >= 400) stop(what, ": HTTP ", st, " - ", substr(httr2::resp_body_string(resp), 1, 300))
  invisible(resp)
}
read_latlon_matrix <- function(nc, vname) {
  v <- nc$var[[vname]]
  a <- ncdf4::ncvar_get(nc, vname, collapse_degen = FALSE)
  dn <- map_chr(v$dim, "name")
  ilat <- which(str_detect(dn, "lat")); ilon <- which(str_detect(dn, "lon"))
  if (length(ilat) != 1 || length(ilon) != 1) { ilon <- 1; ilat <- 2 }
  other <- setdiff(seq_along(dim(a)), c(ilat, ilon))
  a <- aperm(a, c(ilat, ilon, other))
  matrix(a, nrow = dim(a)[1], ncol = dim(a)[2])
}

# ---- 1. grid layout (shared with step 03) -----------------------------------
layout_path <- file.path(P$interim, "tempo_layout.rds")
if (!file.exists(layout_path)) {
  stop("No cached TEMPO layout (", layout_path, "). Run R/03_tempo_extract.R once first, ",
       "which reads the grid and variable list from a granule.")
}
L <- readRDS(layout_path)
if (!identical(L$requested, CFG$tempo_vars)) {
  stop("The cached layout was built for different tempo_vars. Delete ", layout_path,
       " and run R/03_tempo_extract.R once to rebuild it.")
}
log_msg("Grid ", length(L$lat), " x ", length(L$lon), "; variables: ", paste(basename(L$wanted), collapse = ", "))

# ---- 2. granules for a cluster, from CMR ------------------------------------
cmr_query <- function(bbox, t0, t1, depth = 0) {
  req <- public_request(CFG$cmr_url) |>
    httr2::req_url_query(collection_concept_id = CFG$tempo_collection,
                         temporal = paste(format(t0, "%Y-%m-%dT%H:%M:%SZ"),
                                          format(t1, "%Y-%m-%dT%H:%M:%SZ"), sep = ","),
                         bounding_box = bbox, page_size = 2000, sort_key = "start_date")
  resp  <- httr2::req_perform(req)
  items <- httr2::resp_body_json(resp, simplifyVector = FALSE)$items
  if (length(items) >= 2000 && depth < 4) {           # page full: split the interval
    tm <- t0 + as.numeric(difftime(t1, t0, units = "secs")) / 2
    return(bind_rows(cmr_query(bbox, t0, tm, depth + 1), cmr_query(bbox, tm, t1, depth + 1)))
  }
  if (!length(items)) return(NULL)
  map(items, function(it) {
    u <- it$umm
    urls <- map_chr(u$RelatedUrls %||% list(), ~ .x$URL %||% NA_character_)
    types <- map_chr(u$RelatedUrls %||% list(), ~ paste(.x$Type %||% "", .x$Subtype %||% ""))
    od <- urls[str_detect(types, "OPENDAP")][1]
    if (is.na(od)) od <- file.path(CFG$opendap_base, CFG$tempo_collection, "granules", u$GranuleUR)
    tibble(granule = u$GranuleUR,
           begin_utc = ymd_hms(u$TemporalExtent$RangeDateTime$BeginningDateTime),
           end_utc   = ymd_hms(u$TemporalExtent$RangeDateTime$EndingDateTime),
           opendap_url = od)
  }) |> list_rbind() |> distinct(granule, .keep_all = TRUE)
}

cluster_manifest <- function(cl, cl_sites, cl_samples) {
  f <- file.path(man_dir, paste0(cl, ".csv"))
  # 24-h samples already span the day, so they need no lag padding
  pad <- if_else(cl_samples$duration_class == "24 h", 0, CFG$aqs_lag_pad_h * 3600)
  windows <- cl_samples |> transmute(w0 = start_utc - pad, w1 = end_utc + pad)
  if (file.exists(f)) {
    man <- read_tbl(f, colClasses = "character") |>
      transmute(granule, opendap_url, mid_utc = ymd_hms(mid_utc))
  } else {
    bbox <- sprintf("%.3f,%.3f,%.3f,%.3f", min(cl_sites$lon) - 0.1, min(cl_sites$lat) - 0.1,
                    max(cl_sites$lon) + 0.1, max(cl_sites$lat) + 0.1)
    months <- sort(unique(floor_date(as.Date(windows$w0), "month")))
    man <- map(months, function(m0) {
      t0 <- as.POSIXct(paste(m0, "00:00:00"), tz = "UTC")
      t1 <- t0 + as.integer(days_in_month(m0)) * 86400
      tryCatch(cmr_query(bbox, t0, t1), error = function(e) {
        warning("CMR failed for ", cl, " ", m0, ": ", conditionMessage(e)); NULL })
    }) |> list_rbind()
    if (is.null(man) || !nrow(man)) return(NULL)
    man <- man |>
      mutate(mid_utc = begin_utc + (end_utc - begin_utc) / 2) |>
      distinct(granule, .keep_all = TRUE) |>
      select(granule, opendap_url, mid_utc)
    data.table::fwrite(man, f)
  }
  # keep scans that fall inside a padded sample window
  keep <- rep(FALSE, nrow(man))
  for (w in seq_len(nrow(windows))) {
    keep <- keep | (man$mid_utc >= windows$w0[w] & man$mid_utc < windows$w1[w])
  }
  man[keep, , drop = FALSE] |> arrange(mid_utc)
}

# ---- 3. extraction for one cluster ------------------------------------------
extract_cluster <- function(cl, cl_sites, man) {
  dir_c <- file.path(cells_dir, cl)
  dir.create(dir_c, recursive = TRUE, showWarnings = FALSE)
  cell_file <- function(g) file.path(dir_c, paste0(tools::file_path_sans_ext(g), ".csv"))
  nc_file <- function(g) file.path(P$raw_tempo, sub("\\.nc$", paste0(".", cl, ".subset.nc4"), g))

  # cached cells are only valid for the site set they were extracted for
  sites_file <- file.path(dir_c, "_sites.csv")
  if (file.exists(sites_file)) {
    prev <- read_tbl(sites_file, colClasses = list(character = "site_id"))
    if (!setequal(prev$site_id, cl_sites$site_id)) {
      log_msg("  ", cl, ": site list changed - clearing cached cells for this cluster")
      unlink(list.files(dir_c, pattern = "\\.csv$", full.names = TRUE))
    }
  }
  data.table::fwrite(select(cl_sites, site_id, lat, lon), sites_file)

  # index box for this cluster
  ii <- map_int(cl_sites$lat, ~ which.min(abs(L$lat - .x)))
  jj <- map_int(cl_sites$lon, ~ which.min(abs(L$lon - .x)))
  pad <- CFG$half_width_cells + CFG$bbox_pad_cells
  i0 <- max(min(ii) - pad, 1); i1 <- min(max(ii) + pad, length(L$lat))
  j0 <- max(min(jj) - pad, 1); j1 <- min(max(jj) + pad, length(L$lon))
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

  extract_cells <- function(path, granule) {
    nc <- ncdf4::nc_open(path)
    on.exit(ncdf4::nc_close(nc))
    lat <- get_coord(nc, "latitude"); lon <- get_coord(nc, "longitude")
    tvals <- tryCatch(get_coord(nc, "time"), error = function(e) NA_real_)
    tunits <- tryCatch(ncdf4::ncatt_get(nc, "time", "units")$value, error = function(e) "")
    origin <- str_match(tunits, "since\\s+([0-9-]+[ T]?[0-9:]*)")[, 2]
    scan_start <- if (!is.na(origin)) ymd_hms(origin, truncated = 3, tz = "UTC") + tvals[1] else as.POSIXct(NA)
    present <- intersect(sub("^/", "", L$wanted), names(nc$var))
    mats <- map(setNames(present, basename(present)), ~ read_latlon_matrix(nc, .x))
    hw <- CFG$half_width_cells
    map(seq_len(nrow(cl_sites)), function(k) {
      a <- which.min(abs(lat - cl_sites$lat[k])); b <- which.min(abs(lon - cl_sites$lon[k]))
      blk <- expand_grid(di = -hw:hw, dj = -hw:hw) |>
        mutate(row_i = a + di, col_j = b + dj) |>
        filter(row_i >= 1, row_i <= length(lat), col_j >= 1, col_j <= length(lon))
      idx <- cbind(blk$row_i, blk$col_j)
      vals <- as_tibble(lapply(mats, function(m) m[idx]))
      bind_cols(tibble(granule = granule, scan_start_utc = scan_start, site = cl_sites$site_id[k],
                       di = blk$di, dj = blk$dj, cell_lat = lat[blk$row_i], cell_lon = lon[blk$col_j]),
                vals)
    }) |> list_rbind()
  }

  todo <- man |> filter(!file.exists(cell_file(granule)))
  if (!nrow(todo)) return(0L)
  par_formals <- names(formals(httr2::req_perform_parallel))
  batches <- split(todo, ceiling(seq_len(nrow(todo)) / 40))
  for (b in batches) {
    need <- b |> filter(!map_lgl(nc_file(granule), is_netcdf4))
    if (nrow(need)) {
      reqs <- map(need$opendap_url, ~ edl_request(paste0(.x, ".dap.nc4?dap4.ce=", CE)))
      paths <- nc_file(need$granule)
      args <- list(reqs, paths = paths, on_error = "continue", progress = FALSE)
      if ("max_active" %in% par_formals) args$max_active <- CFG$n_parallel
      else if ("pool" %in% par_formals) args$pool <- curl::new_pool(total_con = CFG$n_parallel,
                                                                    host_con = CFG$n_parallel)
      try(do.call(httr2::req_perform_parallel, args), silent = TRUE)
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
  nrow(todo)
}

# ---- 4. run over clusters ----------------------------------------------------
t_start <- Sys.time()
manifests <- list()
done_granules <- 0L
for (ci in seq_along(clusters)) {
  cl <- clusters[ci]
  cl_sites <- filter(sites, cluster == cl)
  cl_samples <- filter(samples, cluster == cl)
  man <- cluster_manifest(cl, cl_sites, cl_samples)
  if (is.null(man) || !nrow(man)) { log_msg("  ", cl, ": no TEMPO granules"); next }
  manifests[[cl]] <- mutate(man, cluster = cl)
  n_new <- extract_cluster(cl, cl_sites, man)
  done_granules <- done_granules + n_new
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  log_msg(sprintf("  [%d/%d] %s: %d sites, %d scans (%d new); %.1f min elapsed",
                  ci, length(clusters), cl, nrow(cl_sites), nrow(man), n_new, el))
}
manifest_all <- list_rbind(manifests)
if (!nrow(manifest_all)) stop("No granules found for any cluster.")
man_out <- file.path(P$processed, "aqs_tempo_manifest.csv")
if (file.exists(man_out)) {                       # keep granules listed by earlier arms
  old <- read_tbl(man_out, colClasses = "character") |>
    transmute(granule, opendap_url, mid_utc = ymd_hms(mid_utc),
              cluster = if ("cluster" %in% names(read_tbl(man_out, nrows = 1))) cluster else NA_character_)
  manifest_all <- bind_rows(manifest_all, old) |> distinct(granule, .keep_all = TRUE)
}
data.table::fwrite(manifest_all, man_out)

# ---- 5. combine the cell files ----------------------------------------------
files <- list.files(cells_root, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
files <- files[!str_detect(basename(files), "^_sites")]
id_cols <- c("granule", "scan_start_utc", "site")
cells <- data.table::rbindlist(
  lapply(files, data.table::fread, colClasses = list(character = id_cols), integer64 = "double"), fill = TRUE)
for (col in setdiff(names(cells), id_cols)) {
  data.table::set(cells, j = col, value = suppressWarnings(as.numeric(as.character(cells[[col]]))))
}
cells <- unique(cells, by = c("granule", "site", "di", "dj"))   # a site can appear in two arms
out <- file.path(P$processed, "aqs_tempo_site_cells.csv.gz")
data.table::fwrite(cells, out)
log_msg("Wrote ", nrow(cells), " cell rows from ", length(files), " cached scan files (all arms) to ", out)
log_msg("Total ", nrow(manifest_all), " cluster-scans over ", length(manifests), " clusters; ",
        done_granules, " extracted in this run; ",
        sprintf("%.1f", as.numeric(difftime(Sys.time(), t_start, units = "mins"))), " min elapsed")
