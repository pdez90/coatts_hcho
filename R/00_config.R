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

  # Sample screening (CDPHE guidance, email of Sept 2026):
  #  * qc_code follows AQDx v2. The 2025 sheets list QC samples (qc_code 8, e.g.
  #    flag AY "Q C Control Points (zero/span)") beside ambient samples (qc_code 0);
  #    only ambient rows are kept.
  #  * Rows carrying any AQS "Null Data Qualifier" are invalid or QC/QA and are
  #    excluded. The list is read from each packet's "Qualifier Flags" sheet
  #    (Qualifier Type = "Null Data Qualifier"); the fallback below is used only
  #    if a packet has no such sheet (list copied from the 2025 packets).
  #  * Quality Assurance / Informational qualifiers (LJ, TT, QX, LB, FB, SQ, IT, ...)
  #    are kept and listed in `flags`; add codes to coatts_exclude_flags for a
  #    stricter screen (e.g. "FB" field blank above limit, "QX" fails QC criteria).
  coatts_keep_qc_codes = 0L,
  exclude_null_qualifiers = TRUE,
  aqs_null_qualifiers_fallback = c("AA", "AG", "AH", "AJ", "AL", "AN", "AO", "AQ", "AT",
                                   "AV", "AX", "AY", "AZ", "BA", "BD", "BH", "BK", "BL",
                                   "BM", "BR", "EC", "MB", "SC", "SV", "TS", "XX"),
  coatts_exclude_flags = character(),
  min_days_per_site_month = 3L,     # for the within-month (deseasonalised) analysis

  # CDPHE Air Toxics & Ozone Precursor Data Repository
  coatts_repo_url = "https://www.colorado.gov/airquality/air_toxics_repo.aspx",
  # COATTS sites. The ozone-precursor sites belong to CDPHE's COOPs network
  # (discontinued end of June 2026; historical data stay available). Their
  # carbonyls are 3-h samples (CDPHE confirmed for CHCO and PVCO in 2024 and
  # 2025), handled by the 3-h arm below; step 01 never reads their 2024 wide
  # packets as 24-h data, and their 2025 AQDx rows fail its 24-h duration test.
  coatts_sites = c("ADCO", "LSCO", "GPCO", "JFCO", "COCO", "CNCO", "POCO"),
  ozone_precursor_sites = c("PVCO", "BFCO", "CHCO", "MPCO"),
  include_ozone_precursor_sites = FALSE,

  # ---- 3-hour arm: ozone-precursor sites with 3-h carbonyl samples ----
  run_three_hour_arm = TRUE,
  threeh_sites = c("CHCO", "PVCO"),       # Littleton (Chatfield), Platteville
  threeh_duration_s = 10800,
  # CDPHE stamps these samples 09:00. EPA's AQS holds the same samples with a
  # start time of 06:00 MST and a duration of 3 hours (step 10), so the packet
  # stamp is the END of sampling and the window is [stamp - 3 h, stamp).
  threeh_stamp_is = "end",
  # TEMPO scans are also averaged over windows shifted by these lags (hours)
  # from the sampling window, to see how agreement depends on the delay between
  # sampling and the satellite view (0 = the sampling window itself).
  threeh_lags_h = c(-3, 0, 3, 6, 9),
  threeh_primary_lag_h = 0,
  threeh_query_local_hours = c(3, 19),     # TEMPO scans listed for this MST span
  # 2024 wide packets for these sites have 09:00 stamps but no duration field.
  # CDPHE confirmed (Sept 2026) that they are the same 3-h samples.
  threeh_include_2024 = TRUE,
  # Two 2025 samples (CHCO and PVCO, 2025-06-12) are stamped 23:59 instead of
  # 09:00: qc_code 0, no qualifiers, on the regular 1-in-6-day schedule. Until
  # CDPHE confirms their timing they are kept in threeh_hcho.csv (flagged
  # stamp_time_unusual) but left out of the TEMPO matching in step 07.
  threeh_exclude_unusual_stamps = TRUE,

  # ---- national arm: EPA AQS formaldehyde (NATTS / NCore / PAMS) ----
  # Step 10 inventories what AQS holds for formaldehyde: which monitors, at what
  # sample duration (24-h NATTS/NCore style, sub-daily PAMS style), in which
  # networks. EPA's AirData files need no key; sample-level records (which carry
  # the time each sample began) come from the AQS API and need AQS_EMAIL/AQS_KEY.
  run_aqs_inventory = TRUE,
  run_aqs_samples = TRUE,                    # step 11: sample-level pull (needs an API key)
  aqs_api_pause_s = 5,                       # AQS asks for modest request rates
  # site grouping for the national TEMPO extraction (step 12): one OPeNDAP
  # request per group and scan, so bigger boxes mean fewer, larger requests
  aqs_cluster_deg_lat = 1.25,
  aqs_cluster_deg_lon = 2.5,
  aqs_scans_per_day_guess = 13,              # daylight TEMPO scans, for the cost estimate
  # step 12: which national samples get TEMPO subsets. The sub-daily sites
  # ("3 h", "8 h") were extracted on 12 Sept 2026 and are cached per duration
  # set, so this now covers the 24-h sites; set it back to c("3 h", "8 h") only
  # if those need re-extracting. Step 13 always analyses every site that has
  # cells, whichever arm they came from.
  run_aqs_tempo = FALSE,                     # step 12 is long: switch it on deliberately
  aqs_arm_durations = c("24 h"),
  aqs_lag_pad_h = 3,                         # hours kept on each side of a sample window
  aqs_max_clusters = NA,                     # test mode: only the first N clusters
  # step 13: lags (hours) from each sampling window, as in the 3-h arm. The 24-h
  # samples are matched only at lag 0, since they already span the day.
  run_aqs_analysis = TRUE,
  aqs_lags_h = c(-3, 0, 3, 6),
  aqs_base_url = "https://aqs.epa.gov/aqsweb/airdata/",
  aqs_param_hcho = "43502",                  # AQS parameter code for formaldehyde
  aqs_years = c(2024L, 2025L),
  aqs_refresh = FALSE,                       # TRUE re-downloads the AirData files
  aqs_durations = c("24 h", "8 h", "3 h", "1 h"),
  aqs_min_samples = 20L,                     # per site over aqs_years, to be a candidate
  aqs_conus_bbox = c(-125, 24, -66, 50),     # lon_min, lat_min, lon_max, lat_max
  # Sample-level check of sampling clocks. AQS records the time each sample
  # BEGAN, in local standard time. The first pull (Sept 2026) returned
  # time_local 06:00 with duration "3 HOURS" for Chatfield State Park and
  # Platteville: the 09:00 stamp in CDPHE's packets is the END of a 06:00-09:00
  # MST sample. This list adds the COATTS 24-h sites (to confirm
  # midnight-to-midnight), the other two national 3-h sites (California) and
  # three 8-h PAMS sites (to learn the 8-h sampling clock).
  aqs_sites_of_interest = c(
    "08-035-0004", "08-123-0008",                                   # CHCO, PVCO (3 h)
    "08-001-0010", "08-123-0015", "08-077-0018", "08-059-0015",     # ADCO, LSCO, GPCO, JFCO (24 h)
    "08-041-0017", "08-043-0004", "08-101-0017",                    # COCO, CNCO, POCO (24 h)
    "06-029-2012", "06-019-5001",                                   # Bakersfield, Clovis (3 h)
    "08-059-0006", "06-065-8001", "39-035-0060"),                   # Rocky Flats, Rubidoux, GT Craig (8 h)

  # ---- diagnostics (step 09): tests of explanations, uses existing outputs ----
  run_diagnostics = TRUE,

  # ---- smoke flags: NOAA Hazard Mapping System smoke polygons ----
  run_smoke_flags = TRUE,
  hms_base_url = "https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/Shapefile",
  # HMS polygon Start-End times are the imagery periods analysts used, which
  # cluster around ~11-15 UTC and ~18-24 UTC. A strict overlap test therefore
  # misses mid-morning MST windows (09-12 MST = 16-19 UTC) even on smoky days.
  # Windows are widened by this many hours on each side before the test.
  hms_time_pad_hours = 3,

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
  hcho_molar_mass = 30.026,    # g/mol
  # CDPHE's ug/m3 match the same samples' AQS ppb records converted at 25 C and
  # 1 atm to within 0.2 % at every Colorado site (checked in step 11), so the
  # reported mass concentrations are at standard conditions, not local ones.
  hcho_reported_conditions = "standard",
  # Temperature used for the number density when no co-located measurement is
  # available. A 10 K error moves the number density (and H_eff) by about 3.5 %.
  hcho_fallback_temp_c = 15
)

# ---- paths -----------------------------------------------------------------
P <- list(
  raw_coatts   = "data/raw/coatts",
  raw_tempo    = "data/raw/tempo_subsets",
  raw_hms      = "data/raw/hms_smoke",
  raw_aqs      = "data/raw/aqs",
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

# AQS Null Data Qualifiers listed in a packet's "Qualifier Flags" sheet
# (columns "Qualifier Flags", "Description", "Qualifier Type" under a title row)
null_qualifiers_of <- function(path) {
  sh <- readxl::excel_sheets(path)
  s  <- sh[str_detect(sh, regex("^\\s*qualifier flags\\s*$", ignore_case = TRUE))]
  fallback <- function(why) {
    log_msg("  ", basename(path), ": ", why, " - using aqs_null_qualifiers_fallback")
    CFG$aqs_null_qualifiers_fallback
  }
  if (!length(s)) return(fallback("no Qualifier Flags sheet"))
  q <- readxl::read_excel(path, sheet = s[1], col_names = FALSE, col_types = "text",
                          .name_repair = ~ paste0("c", seq_along(.x)))
  is_hdr <- apply(q, 1, function(r) any(str_detect(coalesce(r, ""), regex("^\\s*qualifier type\\s*$", ignore_case = TRUE))))
  hdr <- which(is_hdr)[1]
  if (is.na(hdr)) return(fallback("Qualifier Flags sheet has no 'Qualifier Type' header"))
  h <- str_trim(coalesce(as.character(unlist(q[hdr, ])), ""))
  code_col <- which(str_detect(h, regex("^qualifier flag", ignore_case = TRUE)))[1]
  type_col <- which(str_detect(h, regex("^qualifier type$", ignore_case = TRUE)))[1]
  if (is.na(code_col) || is.na(type_col)) return(fallback("unexpected Qualifier Flags columns"))
  body  <- q[-seq_len(hdr), , drop = FALSE]
  codes <- str_trim(body[[code_col]][str_detect(coalesce(body[[type_col]], ""), regex("null", ignore_case = TRUE))])
  codes <- unique(codes[!is.na(codes) & nzchar(codes)])
  if (!length(codes)) return(fallback("no Null Data Qualifiers listed"))
  codes
}

# Keep ambient samples only: qc_code in coatts_keep_qc_codes (or missing, as in
# the 2024 wide sheets, which hold field samples only) and no excluded qualifier
# (AQS Null Data Qualifiers from the packet, plus coatts_exclude_flags).
drop_qc_rows <- function(d, qc, flags, file, null_codes = character()) {
  qc_int <- suppressWarnings(as.integer(pull(d, {{ qc }})))
  fl <- pull(d, {{ flags }})
  excl <- unique(c(if (CFG$exclude_null_qualifiers) null_codes, CFG$coatts_exclude_flags))
  hit  <- matrix(FALSE, nrow = length(fl), ncol = length(excl))
  for (k in seq_along(excl)) hit[, k] <- has_flag(fl, excl[k])
  bad_flag <- rowSums(hit) > 0
  bad_qc   <- !(is.na(qc_int) | qc_int %in% CFG$coatts_keep_qc_codes)
  keep <- !bad_qc & !bad_flag
  if (any(!keep)) {
    found <- excl[colSums(hit[!bad_qc, , drop = FALSE]) > 0]
    log_msg("  ", file, ": dropped ", sum(!keep), " rows (", sum(bad_qc), " QC samples by qc_code; ",
            sum(bad_flag & !bad_qc), " ambient rows with excluded qualifiers",
            if (length(found)) paste0(" ", paste(found, collapse = ",")), ")")
  }
  d[keep, , drop = FALSE]
}

season_of <- function(d) {
  m <- lubridate::month(d)
  factor(dplyr::case_when(m %in% c(12, 1, 2) ~ "DJF", m %in% 3:5 ~ "MAM",
                          m %in% 6:8 ~ "JJA", TRUE ~ "SON"),
         levels = c("DJF", "MAM", "JJA", "SON"))
}

# ug/m3 -> molecules/cm3 IF the concentration is a mass per actual volume.
# CDPHE and AQS report at standard conditions (25 C, 1 atm), so this is the
# number density the air would have at 25 C and 1 atm, not at the site.
ugm3_to_molec_cm3 <- function(c_ugm3, M = CFG$hcho_molar_mass) {
  c_ugm3 * 6.02214076e23 * 1e-12 / M
}
# Reported ug/m3 at standard conditions -> mixing ratio (exact), then the number
# density at the site's own temperature and pressure.
ugm3_std_to_ppb <- function(c_ugm3, M = CFG$hcho_molar_mass) c_ugm3 * 24.45 / M
ppb_to_molec_cm3 <- function(ppb, temp_c, press_hpa) {
  n_air <- (press_hpa * 100) / (1.380649e-23 * (temp_c + 273.15)) * 1e-6   # molecules/cm3
  ppb * 1e-9 * n_air
}
# ug/m3 -> ppbv given temperature (C) and pressure (hPa)
ugm3_to_ppb <- function(c_ugm3, temp_c, press_hpa, M = CFG$hcho_molar_mass) {
  c_ugm3 * 8.314462618 * (temp_c + 273.15) * 1e3 / (M * press_hpa * 100)
}
