# =============================================================================
# 01_coatts.R - find, download and parse CDPHE 24-h formaldehyde samples
#
# Scrapes the CDPHE Air Toxics repository page for annual data packets, keeps
# COATTS (and optionally ozone-precursor) site files, downloads them, and
# extracts formaldehyde from two layouts:
#   * 2025+ "AQDxLite" long format  (sheet Carbonyls_data)
#   * 2024  wide format             (sheet "Carbonyls Field Samples")
# Output: data/processed/coatts_hcho.csv  (one row per site x sample day)
# =============================================================================
source("R/00_config.R")

# ---- 1. discover files on the repository page -------------------------------
log_msg("Reading repository page: ", CFG$coatts_repo_url)
page  <- public_request(CFG$coatts_repo_url) |> httr2::req_perform() |> httr2::resp_body_html()
a     <- xml2::xml_find_all(page, "//a[@href]")
href  <- xml2::url_absolute(xml2::xml_attr(a, "href"), CFG$coatts_repo_url)
fname <- str_match(href, "file=([^&]+\\.xlsx)")[, 2]
fname <- vapply(fname, function(x) if (is.na(x)) NA_character_ else utils::URLdecode(x), character(1), USE.NAMES = FALSE)

sites_wanted <- c(CFG$coatts_sites,
                  if (CFG$include_ozone_precursor_sites) CFG$ozone_precursor_sites)
site_pat <- paste(sites_wanted, collapse = "|")

files <- tibble(file = fname, url = href) |>
  filter(!is.na(file)) |>
  mutate(site = coalesce(str_match(file, sprintf("^(%s)_AQDxLite", site_pat))[, 2],
                         str_match(file, sprintf("^\\d{4}_AnnualFile_(%s)", site_pat))[, 2]),
         year = as.integer(str_extract(file, "20\\d{2}"))) |>
  filter(!is.na(site)) |>
  distinct(file, .keep_all = TRUE) |>
  mutate(program = if_else(site %in% CFG$coatts_sites, "COATTS", "COOPs (ozone precursor)"))

# COOPs carbonyls are 3-h samples (CDPHE, Sept 2026). The 2024 wide packets carry
# no duration field, so they would otherwise be read as 24-h days; they are used
# by the 3-h arm (step 06) instead.
coops_wide <- files$site %in% CFG$ozone_precursor_sites & !str_detect(files$file, "AQDxLite")
if (any(coops_wide)) {
  log_msg("Skipping COOPs wide packets (3-h samples, not 24-h): ", paste(files$file[coops_wide], collapse = ", "))
  files <- files[!coops_wide, ]
}

if (!nrow(files)) stop("No annual data packets found - page layout may have changed.")
log_msg("Found ", nrow(files), " annual packets: ", paste(files$file, collapse = ", "))

# ---- 2. download (skips files already on disk unless coatts_refresh) --------
files$path <- file.path(P$raw_coatts, files$file)
manifest_path <- file.path(P$raw_coatts, "download_manifest.csv")
old_manifest <- if (file.exists(manifest_path)) read_tbl(manifest_path, colClasses = "character") else NULL

is_xlsx <- function(path) file.exists(path) && file.size(path) > 4 &&
  identical(readBin(path, "raw", n = 2), charToRaw("PK"))

for (i in seq_len(nrow(files))) {
  if (is_xlsx(files$path[i]) && !CFG$coatts_refresh) next
  log_msg("Downloading ", files$file[i])
  tmp <- tempfile(fileext = ".xlsx")
  resp <- public_request(files$url[i]) |>
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform(path = tmp)
  if (httr2::resp_status(resp) >= 400 || !is_xlsx(tmp)) {
    stop("Download failed for ", files$file[i], " (HTTP ", httr2::resp_status(resp),
         "). If this persists, download it in a browser into ", P$raw_coatts, ".")
  }
  file.copy(tmp, files$path[i], overwrite = TRUE); unlink(tmp)
  Sys.sleep(1)  # be polite to the state server
}

# provenance: checksum of every packet used
files <- files |>
  mutate(bytes = file.size(path),
         md5 = unname(tools::md5sum(path)),
         file_mtime = format(file.mtime(path), "%Y-%m-%d %H:%M:%S %Z"))
if (!is.null(old_manifest)) {
  changed <- inner_join(select(files, file, md5), select(old_manifest, file, md5_old = md5), by = "file") |>
    filter(md5 != md5_old)
  if (nrow(changed)) warning("CDPHE revised these packets since the last run: ",
                             paste(changed$file, collapse = ", "))
}
data.table::fwrite(select(files, program, site, year, file, url, bytes, md5, file_mtime), manifest_path)

# ---- 3. parsers ------------------------------------------------------------
# (date parsing, flag and QC helpers live in R/00_config.R)

parse_aqdx <- function(path) {
  sh <- readxl::excel_sheets(path)
  if (!"Carbonyls_data" %in% sh) return(NULL)
  d <- readxl::read_excel(path, sheet = "Carbonyls_data", col_types = "text")
  d <- d |>
    mutate(dt = excel_or_text_datetime(datetime),
           duration = suppressWarnings(as.numeric(duration)),
           value = suppressWarnings(as.numeric(parameter_value)),
           dl = suppressWarnings(as.numeric(dl)),
           lat = suppressWarnings(as.numeric(lat)),
           lon = suppressWarnings(as.numeric(lon)))
  met <- d |>
    filter(parameter_name %in% c("Temperature", "Pressure")) |>
    mutate(sample_date = sample_date_of(dt)) |>
    group_by(sample_date, parameter_name, unit_name) |>
    summarise(v = mean(value, na.rm = TRUE), .groups = "drop") |>
    mutate(v = case_when(parameter_name == "Pressure" & unit_name == "mmHg" ~ v * 1.33322,
                         parameter_name == "Temperature" & unit_name %in% c("F", "degF") ~ (v - 32) * 5 / 9,
                         TRUE ~ v),
           parameter_name = recode(parameter_name, Temperature = "temp_c", Pressure = "press_hpa")) |>
    select(-unit_name) |>
    pivot_wider(names_from = parameter_name, values_from = v, values_fn = mean)
  hc_all <- d |> filter(str_detect(parameter_name, regex("^formaldehyde$", ignore_case = TRUE)))
  if (nrow(hc_all) && !any(is.na(hc_all$duration) | abs(hc_all$duration - 86400) < 1)) {
    log_msg("  ", basename(path), ": formaldehyde present but not 24-h (durations ",
            paste(sort(unique(hc_all$duration)), collapse = ", "), " s) - skipped")
  }
  hc <- hc_all |>
    filter(is.na(duration) | abs(duration - 86400) < 1) |>
    drop_qc_rows(qc = qc_code, flags = qualifier_codes, file = basename(path),
                 null_codes = null_qualifiers_of(path)) |>
    mutate(sample_date = sample_date_of(dt),
           unit = unit_name,
           value = case_when(unit %in% c("ppbv", "ppb") ~ value / 0.8148,  # fallback, 25C/1atm
                             TRUE ~ value))
  if (!nrow(hc)) return(NULL)
  out <- hc |>
    transmute(sample_date, lat, lon, device_id, value, dl,
              qc_code = suppressWarnings(as.integer(qc_code)),
              flags = qualifier_codes)
  if (nrow(met)) out <- left_join(out, met, by = "sample_date")
  out
}

parse_wide <- function(path) {
  sh <- readxl::excel_sheets(path)
  s <- sh[str_detect(sh, regex("^Carbonyls Field Samples$", ignore_case = TRUE))]
  if (!length(s)) return(NULL)
  d <- readxl::read_excel(path, sheet = s[1], col_types = "text")
  vcol <- grep("^Formaldehyde_ug", names(d), value = TRUE)[1]
  fcol <- grep("^Formaldehyde_flags", names(d), value = TRUE)[1]
  tcol <- grep("^Datetime", names(d), value = TRUE)[1]
  if (is.na(vcol) || is.na(tcol)) return(NULL)
  tibble(sample_date = sample_date_of(excel_or_text_datetime(d[[tcol]])),
         value = suppressWarnings(as.numeric(d[[vcol]])),
         flags = if (!is.na(fcol)) d[[fcol]] else NA_character_,
         lat = NA_real_, lon = NA_real_, device_id = NA_character_,
         dl = NA_real_, qc_code = NA_integer_) |>
    drop_qc_rows(qc = qc_code, flags = flags, file = basename(path),
                 null_codes = null_qualifiers_of(path))
}

# ---- 4. parse all packets --------------------------------------------------
parsed <- pmap(select(files, file, site, program, path), function(file, site, program, path) {
  res <- tryCatch(
    if (str_detect(file, "AQDxLite")) parse_aqdx(path) else parse_wide(path),
    error = function(e) { warning(file, ": ", conditionMessage(e)); NULL })
  if (is.null(res) || !nrow(res)) { log_msg("  no formaldehyde in ", file); return(NULL) }
  log_msg("  ", file, ": ", nrow(res), " formaldehyde rows")
  mutate(res, site = site, program = program, source_file = file)
}) |> list_rbind()

if (is.null(parsed) || !nrow(parsed)) stop("No formaldehyde rows parsed.")
for (col in c("temp_c", "press_hpa")) if (!col %in% names(parsed)) parsed[[col]] <- NA_real_

mean_or_na <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
max_or_na  <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)

# Site coordinates: from any AQDx data sheet of the site (covers sites whose
# formaldehyde is only in the 2024 wide files), then the table below.
aqdx_coords <- function(path) {
  for (s in grep("_data$", readxl::excel_sheets(path), value = TRUE)) {
    d <- tryCatch(readxl::read_excel(path, sheet = s, n_max = 50, col_types = "text"), error = function(e) NULL)
    if (!is.null(d) && all(c("lat", "lon") %in% names(d))) {
      xy <- tibble(lat = suppressWarnings(as.numeric(d$lat)), lon = suppressWarnings(as.numeric(d$lon))) |>
        filter(!is.na(lat), !is.na(lon))
      if (nrow(xy)) return(summarise(xy, lat = median(lat), lon = median(lon)))
    }
  }
  NULL
}
xy_files <- files |> filter(str_detect(file, "AQDxLite"))
aqdx_xy <- map2(xy_files$path, xy_files$site, function(p, s) {
  xy <- aqdx_coords(p); if (is.null(xy)) NULL else mutate(xy, site = s)
}) |> list_rbind()
if (is.null(aqdx_xy) || !nrow(aqdx_xy)) aqdx_xy <- tibble(site = character(), lat = numeric(), lon = numeric())
aqdx_xy <- aqdx_xy |> group_by(site) |> summarise(lat_x = median(lat), lon_x = median(lon), .groups = "drop")

site_coords_fallback <- tribble(
  ~site,  ~site_name,          ~lat,       ~lon,
  "ADCO", "Commerce City",     39.828100, -104.936470,
  "LSCO", "La Salle",          40.261400, -104.706450,
  "GPCO", "Grand Junction",    39.064289, -108.561550,
  "JFCO", "Wheat Ridge",       39.781069, -105.107621,
  "COCO", "Colorado Springs",  38.848014, -104.828564,
  "CNCO", "Canon City",        38.469492, -105.208334,
  "POCO", "Pueblo",            38.236232, -104.581380,
  "CHCO", "Littleton",         NA,         NA,
  "PVCO", "Platteville",       NA,         NA,
  "BFCO", "Brighton",          NA,         NA,
  "MPCO", "Missile Park",      NA,         NA
)
coords <- parsed |>
  filter(!is.na(lat), !is.na(lon)) |>
  group_by(site) |>
  summarise(lat = median(lat), lon = median(lon), .groups = "drop") |>
  full_join(aqdx_xy, by = "site") |>
  full_join(select(site_coords_fallback, site, site_name, lat_fb = lat, lon_fb = lon), by = "site") |>
  mutate(lat = coalesce(lat, lat_x, lat_fb), lon = coalesce(lon, lon_x, lon_fb),
         site_name = coalesce(site_name, site)) |>
  select(site, site_name, lat, lon) |>
  filter(site %in% unique(parsed$site))

missing_xy <- coords$site[is.na(coords$lat)]
if (length(missing_xy)) warning("No coordinates for: ", paste(missing_xy, collapse = ", "),
                                " - add them to site_coords_fallback.")

# ---- 5. one row per site x sample day ---------------------------------------
coatts <- parsed |>
  filter(!is.na(sample_date),
         sample_date >= CFG$date_range[1], sample_date <= CFG$date_range[2]) |>
  group_by(site, program, sample_date) |>
  summarise(
    n_rows      = n(),
    hcho_ugm3   = mean_or_na(value),
    dl_ugm3     = max_or_na(dl),
    non_detect  = any(has_flag(flags, "ND")),
    below_mdl   = any(has_flag(flags, "MD")),
    qc_codes    = paste(sort(unique(na.omit(qc_code))), collapse = ";"),
    flags       = { f <- unique(unlist(str_split(na.omit(flags), "[ ,;]+"))); paste(sort(f[nzchar(f)]), collapse = " ") },
    temp_c      = mean_or_na(temp_c),
    press_hpa   = mean_or_na(press_hpa),
    source_file = paste(unique(source_file), collapse = ";"),
    .groups = "drop"
  ) |>
  left_join(coords, by = "site") |>
  mutate(hcho_molec_cm3 = ugm3_to_molec_cm3(hcho_ugm3),
         hcho_ppb_local = ugm3_to_ppb(hcho_ugm3, temp_c, press_hpa),
         season = season_of(sample_date),
         year = year(sample_date)) |>
  arrange(site, sample_date)

data.table::fwrite(coatts, file.path(P$processed, "coatts_hcho.csv"))

summary_tbl <- coatts |>
  group_by(program, site, site_name, year) |>
  summarise(sample_days = n(), with_value = sum(!is.na(hcho_ugm3)),
            first = min(sample_date), last = max(sample_date),
            median_ugm3 = round(median(hcho_ugm3, na.rm = TRUE), 2),
            .groups = "drop")
data.table::fwrite(summary_tbl, file.path(P$tables, "coatts_hcho_inventory.csv"))
print(summary_tbl, n = Inf)
log_msg("Wrote ", nrow(coatts), " site-days to ", file.path(P$processed, "coatts_hcho.csv"))
