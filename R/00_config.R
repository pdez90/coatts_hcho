# =============================================================================
# 00_config.R - settings, packages and shared helpers
# Sourced at the top of every script. Run scripts from the project root (~/HCHO).
# =============================================================================

if (!file.exists("R/00_config.R")) {
  stop("Run from the project root, e.g. setwd('~/HCHO') before sourcing scripts.")
}

# ---- packages ---------------------------------------------------------------
.required <- c("httr2", "curl", "jsonlite", "xml2", "readxl", "dplyr", "tidyr", "tibble",
               "purrr", "stringr", "lubridate", "ncdf4", "data.table", "ggplot2")
.optional <- c("lme4")

.missing <- .required[!vapply(.required, requireNamespace, logical(1), quietly = TRUE)]
if (length(.missing)) {
  # For exact versions use renv (see README): renv::restore() installs what
  # renv.lock records; this fallback installs current CRAN versions.
  message("Installing missing packages: ", paste(.missing, collapse = ", "))
  install.packages(.missing, repos = "https://cloud.r-project.org")
}
.min_versions <- c(dplyr = "1.1.0", purrr = "1.0.0", tidyr = "1.2.0", httr2 = "1.0.0", readxl = "1.4.0")
for (.p in names(.min_versions)) {
  if (utils::packageVersion(.p) < .min_versions[[.p]]) {
    stop(.p, " >= ", .min_versions[[.p]], " is required (installed: ", utils::packageVersion(.p), ").")
  }
}
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(stringr)
  library(lubridate); library(ggplot2)
})

# ---- configuration ----------------------------------------------------------
CFG <- list(
  # Analysis period. Fixed so that packets CDPHE posts later (e.g. 2026) do
  # not silently change results. TEMPO V04 starts Aug 2023.
  date_range = as.Date(c("2024-01-01", "2025-12-31")),
  # CDPHE revises packets "as data review and validation is completed".
  # FALSE = use files already in data/raw/coatts (reproducible);
  # TRUE  = download again and report files whose checksum changed.
  coatts_refresh = FALSE,

  # CDPHE lists QC samples (qc_code 8, flag AY = "Q C Control Points (zero/span)",
  # i.e. blanks at ~0.05 ug/m3) in the same sheet and on the same dates as
  # ambient samples. Only ambient rows are kept.
  coatts_keep_qc_codes = 0L,
  coatts_exclude_flags = c("AY"),   # add e.g. "QX", "LB", "TT" for a stricter screen
  min_days_per_site_month = 3L,     # for the within-month (deseasonalised) analysis

  # CDPHE Air Toxics & Ozone Precursor Data Repository
  coatts_repo_url = "https://www.colorado.gov/airquality/air_toxics_repo.aspx",
  # COATTS sites. Ozone-precursor sites (CHCO Littleton, PVCO Platteville) also
  # report carbonyls, but their 2025 packets hold no 24-h formaldehyde, so they
  # are off by default. Turning this on re-extracts TEMPO for the new sites.
  coatts_sites = c("ADCO", "LSCO", "GPCO", "JFCO", "COCO", "CNCO", "POCO"),
  ozone_precursor_sites = c("PVCO", "BFCO", "CHCO", "MPCO"),
  include_ozone_precursor_sites = FALSE,

  # ---- 3-hour arm: ozone-precursor sites with 3-h carbonyl samples ----
  run_three_hour_arm = TRUE,
  threeh_sites = c("CHCO", "PVCO"),       # Littleton (Chatfield), Platteville
  threeh_duration_s = 10800,
  # CDPHE stamps these samples 09:00 MST. Whether that is the start (09-12) or
  # the end (06-09) is unconfirmed, so both are analysed; "start" is primary.
  threeh_stamp_conventions = c("start", "end"),
  threeh_primary_convention = "start",
  threeh_query_local_hours = c(5, 13),     # TEMPO scans listed for this MST span
  # 2024 wide packets for these sites have 09:00 stamps but no duration field;
  # set TRUE once CDPHE confirms they are the same 3-h samples.
  threeh_include_2024 = FALSE,

  # ---- smoke flags: NOAA Hazard Mapping System smoke polygons ----
  run_smoke_flags = TRUE,
  hms_base_url = "https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/Shapefile",

  # TEMPO formaldehyde Level 3, version 4 (0.02 deg, hourly scans)
  tempo_collection = "C3685897141-LARC_CLOUD",   # TEMPO_HCHO_L3 V04
  cmr_url = "https://cmr.earthdata.nasa.gov/search/granules.umm_json",
  opendap_base = "https://opendap.earthdata.nasa.gov/collections",

  # COATTS samples are midnight-to-midnight local standard time (MST, UTC-7)
  utc_offset_hours = -7,
  midday_local_hours = c(10, 14),   # "midday" window [start, end) in MST

  # Subsetting: cells kept on each side of the site's nearest cell
  # (2 -> 5x5 block, ~10 km), plus padding for the bounding box request
  half_width_cells = 2L,
  bbox_pad_cells = 3L,

  # Variables requested from each granule (missing ones are skipped)
  tempo_vars = c("/product/vertical_column",
                 "/product/vertical_column_uncertainty",
                 "/product/main_data_quality_flag",
                 "/support_data/eff_cloud_fraction",
                 "/support_data/snow_ice_fraction",
                 "/support_data/pbl_height",
                 "/support_data/amf",
                 "/support_data/surface_pressure",
                 "/geolocation/solar_zenith_angle",
                 "/qa_statistics/num_vertical_column_samples"),

  # Quality screening (primary analysis); sensitivity grid is in 04_match.R
  qc_max_quality_flag = 0,     # 0 = good
  qc_max_cloud_fraction = 0.2, # user guide: < 0.1 for highest quality
  qc_max_sza = 70,
  qc_max_snow_ice = 0,
  qc_min_cell_fraction = 0.5,  # share of block cells that must pass QC

  n_parallel = 4L,             # concurrent OPeNDAP requests
  max_granules = NA,           # e.g. 5 for a quick test of step 3; NA = all
  keep_subsets = FALSE,        # delete each granule subset once its site cells are extracted
  hcho_molar_mass = 30.026     # g/mol
)

# ---- paths -----------------------------------------------------------------
P <- list(
  raw_coatts   = "data/raw/coatts",
  raw_tempo    = "data/raw/tempo_subsets",
  raw_hms      = "data/raw/hms_smoke",
  interim      = "data/interim",
  tempo_cells  = "data/interim/tempo_cells",
  processed    = "data/processed",
  figures      = "output/figures",
  tables       = "output/tables",
  logs         = "logs",
  cookies      = file.path(tempdir(), "edl_cookies.txt")
)
invisible(lapply(P[names(P) != "cookies"], dir.create, recursive = TRUE, showWarnings = FALSE))

# ---- analysis arms ---------------------------------------------------------
# "coatts": 24-h COATTS samples vs daily TEMPO means   (steps 01, 02, 03, 04, 05)
# "threeh": 3-h ozone-precursor samples vs TEMPO scans  (steps 06, 02, 03, 07)
# Steps 02 and 03 serve both; the arm is chosen with options(hcho.arm = ...),
# which run_all.R sets. Default is "coatts".
arm_paths <- function(arm) {
  switch(arm,
    coatts = list(
      samples = file.path(P$processed, "coatts_hcho.csv"),
      manifest = file.path(P$processed, "tempo_manifest.csv"),
      cells_dir = P$tempo_cells,
      sites_file = file.path(P$interim, "tempo_sites_extracted.csv"),
      cells = file.path(P$processed, "tempo_site_cells.csv.gz"),
      request_spec = file.path(P$processed, "tempo_request_spec.txt"),
      query_local_hours = c(0, 24),
      subset_suffix = ".subset.nc4"),
    threeh = list(
      samples = file.path(P$processed, "threeh_hcho.csv"),
      manifest = file.path(P$processed, "threeh_tempo_manifest.csv"),
      cells_dir = file.path(P$interim, "threeh_tempo_cells"),
      sites_file = file.path(P$interim, "threeh_tempo_sites_extracted.csv"),
      cells = file.path(P$processed, "threeh_tempo_site_cells.csv.gz"),
      request_spec = file.path(P$processed, "threeh_tempo_request_spec.txt"),
      query_local_hours = CFG$threeh_query_local_hours,
      subset_suffix = ".threeh.subset.nc4"),
    stop("Unknown analysis arm: ", arm, " (use 'coatts' or 'threeh')"))
}
ARM <- getOption("hcho.arm", "coatts")
A <- arm_paths(ARM)
dir.create(A$cells_dir, recursive = TRUE, showWarnings = FALSE)

# ---- helpers ----------------------------------------------------------------
log_msg <- function(...) {
  line <- paste0(format(Sys.time(), "[%Y-%m-%d %H:%M:%S] "), ...)
  message(line)
  lf <- getOption("hcho.log_file")          # set by run_all.R
  if (!is.null(lf)) cat(line, "\n", sep = "", file = lf, append = TRUE)
}

# data.table reads 16-digit whole numbers (fwrite writes 2.8e15 as
# "2831327546935760") as integer64 by default; across files rbindlist then
# casts decimals to integer64. Read them as double everywhere.
options(datatable.integer64 = "double")

# fread -> tibble (avoids data.table semantics inside dplyr pipelines)
read_tbl <- function(path, ...) tibble::as_tibble(data.table::fread(path, ...))

UA <- "HCHO-COATTS-TEMPO/1.0 (R httr2; research use)"

# Plain HTTPS request (public sites)
public_request <- function(url) {
  httr2::request(url) |>
    httr2::req_user_agent(UA) |>
    httr2::req_timeout(300) |>
    httr2::req_retry(max_tries = 4, backoff = function(i) 5 * i)
}

# Earthdata Login request. Uses EARTHDATA_TOKEN (preferred; put it in
# ~/.Renviron) or falls back to ~/.netrc. Forces HTTP/1.1: OPeNDAP over
# HTTP/2 fails from R/libcurl.
edl_request <- function(url) {
  req <- httr2::request(url) |>
    httr2::req_user_agent(UA) |>
    httr2::req_options(http_version = 2L) |>      # CURL_HTTP_VERSION_1_1
    httr2::req_headers(`Accept-Encoding` = "identity") |>  # NASA OPeNDAP guidance: avoid compressed transfer
    httr2::req_timeout(600) |>
    httr2::req_retry(
      max_tries = 5,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504),
      backoff = function(i) 10 * i
    )
  tok <- Sys.getenv("EARTHDATA_TOKEN")
  if (nzchar(tok)) {
    req <- httr2::req_auth_bearer_token(req, tok)
  } else {
    netrc <- path.expand("~/.netrc")
    if (!file.exists(netrc)) {
      stop("No Earthdata credentials found. Generate a token at ",
           "https://urs.earthdata.nasa.gov (Generate Token) and add ",
           "EARTHDATA_TOKEN=<token> to ~/.Renviron, or create ~/.netrc ",
           "with 'machine urs.earthdata.nasa.gov login <user> password <pw>'.")
    }
    req <- httr2::req_options(req, netrc = 1L, netrc_file = netrc,
                              followlocation = 1L, unrestricted_auth = 1L,
                              cookiefile = P$cookies, cookiejar = P$cookies)
  }
  req
}

# ---- CDPHE packet helpers (used by steps 01 and 06) ---------------------------
excel_or_text_datetime <- function(x) {
  x <- as.character(x)
  num <- suppressWarnings(as.numeric(x))
  out <- as.POSIXct(rep(NA_real_, length(x)), origin = "1970-01-01", tz = "UTC")
  is_num <- !is.na(num)
  out[is_num]  <- as.POSIXct(round(num[is_num] * 86400), origin = "1899-12-30", tz = "UTC")
  txt <- !is_num & !is.na(x) & nzchar(x)
  if (any(txt)) {
    out[txt] <- suppressWarnings(lubridate::parse_date_time(
      x[txt], orders = c("mdY HM", "mdY HMS", "Ymd HMS", "Ymd HM", "mdY", "Ymd"), tz = "UTC"))
  }
  out
}

# Sample date = calendar day the midnight-to-midnight sample represents.
# Stamps are either the day itself ("01/01/2024 12:00") or 23:59 of that day.
sample_date_of <- function(dt) as.Date(dt)

has_flag <- function(flags, code) str_detect(coalesce(flags, ""), paste0("(^|[ ,;])", code, "($|[ ,;])"))

# Remove QC samples (blanks, zero/span points) that share dates with ambient samples
drop_qc_rows <- function(d, qc, flags, file) {
  qc_int <- suppressWarnings(as.integer(pull(d, {{ qc }})))
  fl <- pull(d, {{ flags }})
  bad_flag <- Reduce(`|`, lapply(CFG$coatts_exclude_flags, function(f) has_flag(fl, f)), FALSE)
  keep <- (is.na(qc_int) | qc_int %in% CFG$coatts_keep_qc_codes) & !bad_flag
  if (any(!keep)) log_msg("  ", file, ": dropped ", sum(!keep), " QC/blank rows (qc_code or flags ",
                          paste(CFG$coatts_exclude_flags, collapse = ","), ")")
  d[keep, , drop = FALSE]
}

season_of <- function(d) {
  m <- lubridate::month(d)
  factor(dplyr::case_when(m %in% c(12, 1, 2) ~ "DJF", m %in% 3:5 ~ "MAM",
                          m %in% 6:8 ~ "JJA", TRUE ~ "SON"),
         levels = c("DJF", "MAM", "JJA", "SON"))
}

# ug/m3 (local conditions) -> molecules/cm3 ; independent of T and P
ugm3_to_molec_cm3 <- function(c_ugm3, M = CFG$hcho_molar_mass) {
  c_ugm3 * 6.02214076e23 * 1e-12 / M
}
# ug/m3 -> ppbv given temperature (C) and pressure (hPa)
ugm3_to_ppb <- function(c_ugm3, temp_c, press_hpa, M = CFG$hcho_molar_mass) {
  c_ugm3 * 8.314462618 * (temp_c + 273.15) * 1e3 / (M * press_hpa * 100)
}
