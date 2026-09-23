# =============================================================================
# helpers_met.R - near-surface meteorology for the number density, defined once.
#
# Three steps turn a reported mass concentration (at 25 C and 1 atm) into an
# ambient number density, and from there an effective mixing height
# H_eff = column / number density: step 04 (Colorado 24 h), step 07 (3 h) and
# step 13 (national). Until Sept 2026 each did it differently, and two of the
# three were wrong in ways that mattered:
#
#   * Steps 07 and 13 used ONE temperature for every site, season and year
#     (CFG$hcho_fallback_temp_c = 15 C). H_eff is proportional to T, so a 35 C
#     summer day was understated by ~7 % and a -15 C winter day overstated by
#     ~10 %: the seasonal contrast in H_eff was compressed by ~19 points.
#   * Step 04 preferred the CDPHE packets' own "Pressure" over TEMPO's. That
#     column is 45-60 hPa (~6 %) BELOW the ambient barometric pressure at every
#     Colorado site - 593.9 mmHg median at Commerce City against ~631 mmHg for
#     the standard atmosphere at its elevation, while TEMPO sits on the standard
#     atmosphere at all seven sites. The packets' Temperature, by contrast, is
#     plainly ambient (median 10.5 C at Commerce City, range -17 to +30). A
#     sensor in the sampled flow and a sensor in the open air is the natural
#     reading, and it made n_air ~6 % too low and H_eff ~6 % too high on the
#     118 of 326 Colorado site-days that carried it.
#
# So all three now read the same field: NOAA HRRR, 3 km, hourly, averaged over
# each sample's own window. The packets' Temperature is kept as a CROSS-CHECK
# (step 19 reports HRRR against it) and their Pressure is no longer used for
# the number density at all.
#
# Nothing here touches hcho_ugm3, which is what every correlation, slope,
# anomaly and permutation test in the paper actually uses. This file only
# affects H_eff and the meteorology comparisons.
# =============================================================================

# One site key for the three arms, which label the same monitor differently
# (ADCO / 08-001-3001) but agree on where it is. 4 dp is ~11 m, far inside
# HRRR's 3 km cell, so this never merges two real sites.
met_site_id <- function(lat, lon) sprintf("%+09.4f%+010.4f", lat, lon)

# UTC hour index. Same definition as steps 13, 15 and 17.
met_hour_key <- function(t) as.integer(as.numeric(t) %/% 3600)

# (site, start_utc, duration_h) -> one row per whole UTC hour the window spans.
# A window is [start, start + duration), so the last hour is excluded, exactly
# as sample_hours() does in step 13.
met_expand_hours <- function(w) {
  w |>
    dplyr::distinct(met_site_id, start_utc, duration_h) |>
    dplyr::mutate(h0 = met_hour_key(start_utc),
                  h1 = met_hour_key(start_utc + duration_h * 3600)) |>
    dplyr::mutate(hour = purrr::map2(h0, h1, ~ seq.int(.x, .y - 1L))) |>
    tidyr::unnest(hour) |>
    dplyr::transmute(met_site_id, start_utc, duration_h, hour)
}

# ---- the window list, built from whatever sample files exist -----------------
# Step 18 needs to know which (site, hour) pairs to download; steps 04, 07 and
# 13 need to aggregate over exactly the same windows. One definition, so the
# fetch cannot cover a different set of hours than the analysis asks for.
#
# Colorado 24 h: the sample day is the MST calendar day (step 04 works in MST
#   throughout), so the window starts at 00:00 local standard time.
# Colorado 3 h : stamp_local is the END of the window - see sample_windows()
#   in step 07 - so the window is [stamp - 3 h, stamp).
# National     : start_utc and duration_h come straight from AQS.
met_windows_all <- function(paths = P, lags_h = NULL) {
  out <- list()

  f <- file.path(paths$processed, "coatts_hcho.csv")
  if (file.exists(f)) {
    d <- read_tbl(f)
    if (nrow(d)) {
      out$coatts <- d |>
        dplyr::filter(!is.na(lat), !is.na(lon), !is.na(sample_date)) |>
        dplyr::transmute(
          arm = "coatts", site = site, lat = lat, lon = lon,
          start_utc = as.POSIXct(paste0(as.Date(sample_date), " 00:00:00"), tz = "UTC") -
                      CFG$utc_offset_hours * 3600,
          duration_h = 24)
    }
  }

  f <- file.path(paths$processed, "threeh_hcho.csv")
  if (file.exists(f)) {
    d <- read_tbl(f, colClasses = list(character = "stamp_local"))
    if (nrow(d)) {
      dur_h <- CFG$threeh_duration_s / 3600
      # stamp_local is stored as text and parsed the way step 07 parses it:
      # an MST clock time held in a UTC-labelled POSIXct, so no DST shift.
      d$stamp_local <- lubridate::parse_date_time(
        as.character(d$stamp_local), orders = c("Ymd HM", "Ymd HMS"), tz = "UTC")
      out$threeh <- d |>
        dplyr::filter(!is.na(lat), !is.na(lon), !is.na(stamp_local)) |>
        dplyr::transmute(
          arm = "threeh", site = site, lat = lat, lon = lon,
          start_utc = stamp_local - CFG$threeh_duration_s - CFG$utc_offset_hours * 3600,
          duration_h = dur_h)
    }
  }

  f <- file.path(paths$processed, "aqs_hcho_samples.csv")
  if (file.exists(f)) {
    d <- read_tbl(f, colClasses = list(character = "site_id"))
    if (nrow(d)) {
      d$start_utc <- as.POSIXct(d$start_utc, tz = "UTC")
      out$national <- d |>
        dplyr::filter(!is.na(lat), !is.na(lon), !is.na(start_utc)) |>
        dplyr::transmute(arm = "national", site = site_id, lat = lat, lon = lon,
                         start_utc = start_utc, duration_h = duration_h)
    }
  }

  if (!length(out)) {
    stop("No sample files found in ", paths$processed, ".\n",
         "  Run R/01_coatts.R (and R/06, R/11) before R/18_hrrr_met.R.")
  }
  w <- dplyr::bind_rows(out) |>
    dplyr::mutate(met_site_id = met_site_id(lat, lon))

  # Steps 07 and 13 also match TEMPO at +/- lag. The number density belongs to
  # the SAMPLE, not to the lagged scan window, so lagged windows are not added
  # here; lags_h is accepted only so a caller can ask for them explicitly.
  if (!is.null(lags_h) && length(setdiff(lags_h, 0))) {
    extra <- purrr::map(setdiff(lags_h, 0), function(L) {
      w |> dplyr::filter(duration_h < 24) |>
        dplyr::mutate(start_utc = start_utc + L * 3600, arm = paste0(arm, "_lag", L))
    })
    w <- dplyr::bind_rows(c(list(w), extra))
  }
  w
}

# ---- reading the cache and aggregating over a window -------------------------
met_cache_path <- function(paths = P) file.path(paths$processed, "hrrr_site_hours.csv.gz")

met_read_cache <- function(paths = P) {
  f <- met_cache_path(paths)
  if (!file.exists(f)) {
    stop("No HRRR cache at ", f, ".\n",
         "  Run R/18_hrrr_met.R first, or set CFG$run_hrrr_met = FALSE and accept\n",
         "  that H_eff cannot be computed (every correlation in the paper is unaffected).")
  }
  m <- read_tbl(f, colClasses = list(character = "met_site_id"))
  need <- c("met_site_id", "hour", "temp_c", "press_hpa", "pbl_m")
  miss <- setdiff(need, names(m))
  if (length(miss)) stop("HRRR cache lacks: ", paste(miss, collapse = ", "))
  m
}

# w must carry met_site_id, start_utc and duration_h. Returns one row per
# distinct (met_site_id, start_utc, duration_h) with the window means and the
# share of the window's hours that HRRR actually supplied.
met_window_means <- function(w, met, min_coverage = CFG$hrrr_min_window_coverage) {
  hrs <- met_expand_hours(w)
  n_want <- hrs |>
    dplyr::count(met_site_id, start_utc, duration_h, name = "n_hours_window")
  got <- hrs |>
    dplyr::inner_join(met, by = c("met_site_id", "hour")) |>
    dplyr::group_by(met_site_id, start_utc, duration_h) |>
    dplyr::summarise(n_hours_met = dplyr::n(),
                     temp_c_hrrr   = mean(temp_c,   na.rm = TRUE),
                     press_hpa_hrrr = mean(press_hpa, na.rm = TRUE),
                     pbl_m_hrrr    = mean(pbl_m,    na.rm = TRUE),
                     .groups = "drop")
  out <- n_want |>
    dplyr::left_join(got, by = c("met_site_id", "start_utc", "duration_h")) |>
    dplyr::mutate(n_hours_met = dplyr::coalesce(n_hours_met, 0L),
                  met_coverage = n_hours_met / n_hours_window)
  # A window covered by too few HRRR hours yields NA rather than a quietly
  # thin mean. The count is logged by the caller.
  bad <- out$met_coverage < min_coverage
  out$temp_c_hrrr[bad]    <- NA_real_
  out$press_hpa_hrrr[bad] <- NA_real_
  out$pbl_m_hrrr[bad]     <- NA_real_
  out
}

# Mean of the HRRR fields over an EXPLICIT list of UTC hours, rather than over a
# whole sampling window. Steps 04, 07 and 13 record the hours their valid TEMPO
# scans fell in; this averages HRRR over exactly those, so a model field can be
# compared with TEMPO's own scan mean.
#
# Why it has to exist: TEMPO only sees a site in daylight, while a 24 h sampling
# window is half night. The boundary layer collapses overnight, so a window-mean
# HRRR PBL sits hundreds of metres below TEMPO's daytime scan mean for reasons
# of sampling alone. Surface pressure has almost no diurnal cycle and is
# indifferent to the choice, which is the tell that the difference is sampling
# rather than physics. Repeated hours are kept: two scans in one hour weight
# that hour twice on both sides, as TEMPO's own mean over scans does.
met_mean_at_hours <- function(site_ids, hours_text, met,
                              fields = c("temp_c", "press_hpa", "pbl_m")) {
  idx <- tibble::tibble(row_id = seq_along(site_ids),
                        met_site_id = as.character(site_ids),
                        hours_text = dplyr::coalesce(as.character(hours_text), ""))
  long <- idx |>
    dplyr::filter(nzchar(hours_text)) |>
    dplyr::mutate(hour = strsplit(hours_text, " ", fixed = TRUE)) |>
    tidyr::unnest(hour) |>
    dplyr::mutate(hour = suppressWarnings(as.integer(hour))) |>
    dplyr::filter(!is.na(hour)) |>
    dplyr::inner_join(met, by = c("met_site_id", "hour")) |>
    dplyr::group_by(row_id) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(fields), ~ mean(.x, na.rm = TRUE)),
                     n_scan_hours = dplyr::n(), .groups = "drop")
  out <- dplyr::left_join(tibble::tibble(row_id = idx$row_id), long, by = "row_id")
  for (f in fields) names(out)[names(out) == f] <- paste0(f, "_hrrr_scan")
  dplyr::select(out, -row_id)
}

# The one call the analysis steps make. Adds temp_c_hrrr, press_hpa_hrrr,
# pbl_m_hrrr, met_coverage to d, and logs how well the windows were covered.
met_attach <- function(d, lat_col = "lat", lon_col = "lon",
                       start_col = "start_utc", dur_col = "duration_h",
                       paths = P, what = "") {
  d$met_site_id <- met_site_id(d[[lat_col]], d[[lon_col]])
  w <- tibble::tibble(met_site_id = d$met_site_id,
                      start_utc = d[[start_col]],
                      duration_h = d[[dur_col]])
  mw <- met_window_means(w, met_read_cache(paths))
  out <- dplyr::left_join(
    d, mw, by = c("met_site_id", stats::setNames("start_utc", start_col),
                  stats::setNames("duration_h", dur_col)))
  n_ok <- sum(!is.na(out$temp_c_hrrr))
  log_msg("HRRR met", if (nzchar(what)) paste0(" (", what, ")") else "", ": ",
          n_ok, " of ", nrow(out), " windows covered (median ",
          round(100 * stats::median(out$met_coverage, na.rm = TRUE)), " % of hours); ",
          "median T ", round(stats::median(out$temp_c_hrrr, na.rm = TRUE), 1), " C, ",
          "median p ", round(stats::median(out$press_hpa_hrrr, na.rm = TRUE)), " hPa, ",
          "median PBL ", round(stats::median(out$pbl_m_hrrr, na.rm = TRUE)), " m")
  if (n_ok < nrow(out)) {
    log_msg("  ", nrow(out) - n_ok, " windows below CFG$hrrr_min_window_coverage (",
            CFG$hrrr_min_window_coverage, ") - H_eff is NA for these")
  }
  out
}
