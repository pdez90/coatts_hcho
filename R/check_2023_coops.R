# =============================================================================
# check_2023_coops.R - is there a 2023 extension for the 3 h COOPs arm?
#
# A ONE-OFF DIAGNOSTIC, deliberately not wired into run_all.R. It writes nothing
# to data/processed and changes no result; it only answers two questions:
#
#   1. Does AQS hold 2023 formaldehyde for the two COOPs sites, and if so with
#      the same 06:00-09:00 MST sampling window? AQS is the route to prefer over
#      CDPHE's 2023 precursor summary workbook, because AQS carries the sample
#      start time, which is what makes the lag analysis possible at all.
#   2. Does TEMPO have granules over those sites in August-December 2023? TEMPO
#      began science operations in August 2023, so the answer sets how much of
#      2023 could actually be matched.
#
# Both are read-only queries. Cached under data/raw/aqs/samples/ so a re-run
# costs nothing. Needs AQS_EMAIL and AQS_KEY in ~/.Renviron, as step 11 does.
#
# Usage: cd ~/HCHO && Rscript R/check_2023_coops.R
# =============================================================================
source("R/00_config.R")

YEAR  <- 2023L
SITES <- tibble::tribble(
  ~code,  ~name,                  ~state, ~county, ~site,   ~lat,      ~lon,
  "CHCO", "Chatfield State Park", "08",   "035",   "0004",  39.534488, -105.070358,
  "PVCO", "Platteville",          "08",   "123",   "0008",  40.209387, -104.82405
)

aqs_email <- Sys.getenv("AQS_EMAIL")
aqs_key   <- Sys.getenv("AQS_KEY")
if (!nzchar(aqs_email) || !nzchar(aqs_key)) {
  stop("AQS_EMAIL and AQS_KEY are not set; see R/11_aqs_samples.R for the sign-up URL.")
}

# ---- 1. AQS: does 2023 exist, and on what clock? -----------------------------
aqs_api <- function(service, ...) {                 # same shape as step 11
  req <- public_request(paste0("https://aqs.epa.gov/data/api/", service)) |>
    httr2::req_url_query(email = aqs_email, key = aqs_key, ...) |>
    httr2::req_timeout(300)
  j <- httr2::resp_body_json(httr2::req_perform(req), simplifyVector = TRUE)
  Sys.sleep(CFG$aqs_api_pause_s)
  list(status = if (is.null(j$Header$status)) "unknown" else j$Header$status[1],
       data = if (is.null(j$Data) || !length(j$Data)) tibble() else tibble::as_tibble(j$Data))
}

cache_dir <- file.path(P$raw_aqs, "samples")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

raw <- purrr::pmap(SITES, function(code, name, state, county, site, lat, lon) {
  f <- file.path(cache_dir, sprintf("check%d_%s.csv.gz", YEAR, code))
  if (file.exists(f)) {
    log_msg(code, ": cached")
    return(read_tbl(f, colClasses = "character"))
  }
  res <- tryCatch(
    aqs_api("sampleData/bySite", param = CFG$aqs_param_hcho,
            bdate = sprintf("%d0101", YEAR), edate = sprintf("%d1231", YEAR),
            state = state, county = county, site = site),
    error = function(e) { log_msg("  ", code, " request failed: ", conditionMessage(e))
                          list(status = "error", data = tibble()) })
  log_msg(code, " (", name, "): AQS says '", res$status, "', ", nrow(res$data), " rows")
  if (!nrow(res$data)) return(NULL)
  d <- dplyr::mutate(res$data, dplyr::across(dplyr::everything(), as.character))
  data.table::fwrite(d, f)
  d
}) |> purrr::list_rbind()

if (!nrow(raw)) {
  log_msg("\nNo 2023 formaldehyde at either COOPs site in AQS. The CDPHE 2023 ",
          "precursor summary workbook would be the only route, and it carries no ",
          "sample start times, so the lag analysis could not be repeated on it.")
} else {
  s <- raw |>
    dplyr::mutate(site_id = paste(state_code, county_code, site_number, sep = "-"),
                  value = suppressWarnings(as.numeric(sample_measurement)),
                  date_local = as.Date(date_local),
                  month = as.integer(format(date_local, "%m")),
                  start_local_h = suppressWarnings(as.numeric(substr(time_local, 1, 2))),
                  start_utc = suppressWarnings(ymd_hm(paste(date_gmt, time_gmt), tz = "UTC"))) |>
    dplyr::filter(!is.na(value), !is.na(start_utc))

  log_msg("\n2023 AQS formaldehyde at the COOPs sites")
  print(s |> dplyr::count(site_id, sample_duration, units_of_measure, name = "samples"))
  log_msg("  date range: ", format(min(s$date_local)), " to ", format(max(s$date_local)))
  log_msg("  local start hours: ", paste(sort(unique(s$start_local_h)), collapse = ", "),
          "   (2024-2025 record: 6)")

  # the daylight-saving question, month by month: 7 h all year means MST
  offs <- s |>
    dplyr::mutate(local = as.POSIXct(paste(date_local, sprintf("%02d:00:00", start_local_h)), tz = "UTC"),
                  off_h = as.numeric(difftime(start_utc, local, units = "hours"))) |>
    dplyr::count(month, off_h, name = "samples")
  log_msg("  UTC-minus-local offset by month (7 in every month = MST year-round):")
  print(offs)

  aug_dec <- dplyr::filter(s, month >= 8)
  log_msg("  samples from August onwards, when TEMPO was observing: ", nrow(aug_dec))
  print(dplyr::count(aug_dec, site_id, month, name = "samples"))
}

# ---- 2. TEMPO: were there granules over these sites in Aug-Dec 2023? ---------
bbox <- sprintf("%.3f,%.3f,%.3f,%.3f",
                min(SITES$lon) - 0.1, min(SITES$lat) - 0.1,
                max(SITES$lon) + 0.1, max(SITES$lat) + 0.1)

cmr_count <- function(t0, t1) {
  req <- public_request(CFG$cmr_url) |>
    httr2::req_url_query(collection_concept_id = CFG$tempo_collection,
                         temporal = paste(t0, t1, sep = ","),
                         bounding_box = bbox, page_size = 1, sort_key = "start_date")
  resp <- httr2::req_perform(req)
  n <- suppressWarnings(as.integer(httr2::resp_header(resp, "CMR-Hits")))
  if (is.na(n)) n <- length(httr2::resp_body_json(resp, simplifyVector = FALSE)$items)
  n
}

log_msg("\nTEMPO granules over the two sites, ", CFG$tempo_collection)
months <- sprintf("%d-%02d", YEAR, 1:12)
gran <- purrr::map_int(months, function(m) {
  t0 <- paste0(m, "-01T00:00:00Z")
  nxt <- seq(as.Date(paste0(m, "-01")), by = "month", length.out = 2)[2]
  tryCatch(cmr_count(t0, paste0(format(nxt - 1), "T23:59:59Z")),
           error = function(e) { log_msg("  CMR failed for ", m, ": ", conditionMessage(e)); NA_integer_ })
})
print(tibble::tibble(month = months, granules = gran))

first <- months[which(!is.na(gran) & gran > 0)][1]
log_msg(if (is.na(first)) "  no TEMPO granules anywhere in 2023 for this collection"
        else paste0("  first month with granules: ", first))
log_msg("\nA 2023 extension is worth doing only where BOTH have rows above: ",
        "AQS samples with a 06:00 start, and TEMPO granules in the same month.")
