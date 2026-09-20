# =============================================================================
# helpers_aqs.R - the EPA AQS sample-data request and screen, defined once.
#
# Two steps need sample-level formaldehyde from AQS: step 11 for the national
# network, and step 01 for the Colorado case study, whose 24 h record used to be
# read from CDPHE's annual data packets instead. Two copies of the request, the
# cache and the screening would be two copies free to drift apart - which is
# exactly how the TEMPO cell screen went wrong before it was centralised in
# helpers_screen.R. So there is one copy, and both steps call it.
#
# The cache is shared as well. Both steps read and write
#   data/raw/aqs/samples/sample_<state>_<year>.csv.gz
# so Colorado is downloaded once no matter how many steps ask for it, and a
# re-run of either step costs nothing.
# =============================================================================

aqs_credentials <- function() {
  email <- Sys.getenv("AQS_EMAIL"); key <- Sys.getenv("AQS_KEY")
  if (!nzchar(email) || !nzchar(key)) {
    stop("AQS_EMAIL and AQS_KEY are not set in the environment.\n",
         "  Sign up once with\n",
         "    browseURL(\"https://aqs.epa.gov/data/api/signup?email=YOUR@EMAIL\")\n",
         "  then put both in ~/.Renviron and restart R.")
  }
  list(email = email, key = key)
}

aqs_api <- function(service, email, key, ...) {
  req <- public_request(paste0("https://aqs.epa.gov/data/api/", service)) |>
    httr2::req_url_query(email = email, key = key, ...) |>
    httr2::req_timeout(300)
  resp <- httr2::req_perform(req)
  Sys.sleep(CFG$aqs_api_pause_s)
  j <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  status <- if (is.null(j$Header$status)) "unknown" else j$Header$status[1]
  list(status = status,
       data = if (is.null(j$Data) || !length(j$Data)) tibble() else tibble::as_tibble(j$Data))
}

# One request per state and year, cached on disk. Returns raw character columns;
# aqs_clean_samples() does the typing and screening.
aqs_fetch_state_years <- function(states, years, cache_dir, refresh = FALSE) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cred <- aqs_credentials()
  map(states, function(st) {
    map(years, function(y) {
      f <- file.path(cache_dir, sprintf("sample_%s_%d.csv.gz", st, y))
      if (file.exists(f) && !refresh) return(read_tbl(f, colClasses = "character"))
      res <- tryCatch(
        aqs_api("sampleData/byState", cred$email, cred$key,
                param = CFG$aqs_param_hcho,
                bdate = sprintf("%d0101", y), edate = sprintf("%d1231", y), state = st),
        error = function(e) {
          log_msg("  request failed for state ", st, " ", y, ": ", conditionMessage(e))
          list(status = "error", data = tibble())
        })
      if (!identical(res$status, "Success") && !nrow(res$data)) {
        log_msg("  state ", st, " ", y, ": ", res$status)
        return(NULL)
      }
      d <- mutate(res$data, across(everything(), as.character))
      data.table::fwrite(d, f)
      log_msg("  state ", st, " ", y, ": ", nrow(d), " sample rows")
      d
    }) |> list_rbind()
  }) |> list_rbind()
}

AQS_SAMPLE_FIELDS <- c("state_code", "county_code", "site_number", "poc",
                       "latitude", "longitude", "date_local", "time_local",
                       "date_gmt", "time_gmt", "sample_measurement",
                       "units_of_measure", "sample_duration", "qualifier",
                       "method", "sample_frequency")

# Raw AQS rows -> one row per site x sampling window, unit-corrected and screened.
#
# The caller applies its own duration and date filters afterwards; everything
# here is common to both arms, so that the national network and the Colorado
# case study cannot end up screened differently.
aqs_clean_samples <- function(raw, keep_site_ids = NULL) {
  miss <- setdiff(AQS_SAMPLE_FIELDS, names(raw))
  if (length(miss)) {
    stop("AQS sample records lack: ", paste(miss, collapse = ", "),
         "\n  fields present: ", paste(names(raw), collapse = ", "))
  }

  # "24 HOUR", "3 HOURS", "8 HOUR" -> hours
  duration_hours <- function(x) {
    n <- suppressWarnings(as.numeric(str_extract(x, "\\d+(\\.\\d+)?")))
    ifelse(str_detect(x, regex("minute", ignore_case = TRUE)), n / 60, n)
  }

  d <- raw |>
    mutate(site_id = paste(state_code, county_code, site_number, sep = "-"),
           value_raw = suppressWarnings(as.numeric(sample_measurement)),
           lat = suppressWarnings(as.numeric(latitude)),
           lon = suppressWarnings(as.numeric(longitude)),
           duration_h = duration_hours(sample_duration),
           start_utc = suppressWarnings(ymd_hm(paste(date_gmt, time_gmt), tz = "UTC")),
           sample_date_local = suppressWarnings(as.Date(date_local)),
           start_hour_local = suppressWarnings(as.numeric(substr(time_local, 1, 2)) +
                                               as.numeric(substr(time_local, 4, 5)) / 60),
           qualifier = coalesce(qualifier, ""))
  d <- if (is.null(keep_site_ids)) {
    filter(d, !is.na(value_raw), !is.na(start_utc), !is.na(duration_h), duration_h > 0)
  } else {
    filter(d, site_id %in% keep_site_ids,
           !is.na(value_raw), !is.na(start_utc), !is.na(duration_h), duration_h > 0)
  }

  # units: AQS reports carbonyls in ug/m3, occasionally in ppb
  unit_tbl <- count(d, units_of_measure, name = "rows")
  log_msg("Units: ", paste(unit_tbl$units_of_measure, unit_tbl$rows, sep = " = ", collapse = "; "))
  d <- d |>
    mutate(is_ppb = str_detect(units_of_measure, regex("billion", ignore_case = TRUE)),
           hcho_ugm3 = if_else(is_ppb, value_raw * CFG$hcho_molar_mass / 24.45, value_raw))
  if (any(d$is_ppb)) {
    log_msg("  ", sum(d$is_ppb), " rows reported in ppb were converted at 25 C and 1 atm")
  }

  # drop rows carrying an AQS null data qualifier (invalid or QC/QA values)
  null_codes <- CFG$aqs_null_qualifiers_fallback
  has_null_q <- function(q) {
    codes <- str_split(q, "[,;]\\s*")
    vapply(codes, function(cc) any(str_trim(str_extract(cc, "^[A-Z0-9]+")) %in% null_codes), logical(1))
  }
  bad <- has_null_q(d$qualifier)
  if (any(bad)) log_msg("Dropped ", sum(bad), " samples carrying a null data qualifier")
  d <- d[!bad, , drop = FALSE]

  # average duplicate POCs / repeated records of the same window
  d |>
    group_by(site_id, start_utc, duration_h) |>
    summarise(hcho_ugm3 = mean(hcho_ugm3),
              n_poc = n_distinct(poc),
              lat = median(lat), lon = median(lon),
              sample_date_local = first(sample_date_local),
              start_hour_local = first(start_hour_local),
              units = first(units_of_measure),
              method = first(method),
              sample_frequency = first(sample_frequency),
              qualifiers = paste(sort(unique(qualifier[nzchar(qualifier)])), collapse = "; "),
              .groups = "drop") |>
    mutate(end_utc = start_utc + duration_h * 3600,
           duration_class = case_when(abs(duration_h - 1) < 0.01 ~ "1 h",
                                      abs(duration_h - 3) < 0.01 ~ "3 h",
                                      abs(duration_h - 8) < 0.01 ~ "8 h",
                                      abs(duration_h - 24) < 0.01 ~ "24 h",
                                      TRUE ~ paste0(duration_h, " h")),
           season = season_of(sample_date_local),
           year = year(sample_date_local),
           hcho_molec_cm3 = ugm3_to_molec_cm3(hcho_ugm3))
}

# AQS qualifiers arrive as full text, e.g.
#   "TT - Transport Temperaure is Out of Specs."
# has_flag() and CDPHE's own files both work in bare codes, so reduce them.
# NOT named qualifier_codes(): that is also the name of a COLUMN in CDPHE's
# AQDxLite sheets, and a reader should not have to know how tidy evaluation
# resolves the clash to be sure there is no bug.
aqs_qualifier_codes <- function(x) {
  vapply(str_split(coalesce(x, ""), "[,;]\\s*"), function(cc) {
    cc <- str_trim(str_extract(cc, "^[A-Z0-9]+"))
    paste(sort(unique(cc[!is.na(cc) & nzchar(cc)])), collapse = " ")
  }, character(1))
}
