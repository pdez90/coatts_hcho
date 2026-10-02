# =============================================================================
# 23_export_dataset.R - the matched surface HCHO x TEMPO dataset, for release
#
# data/ is not tracked (run_all.R regenerates it). This step writes a release
# copy of the matched data to dataset/, which is tracked, in one schema for all
# three arms:
#   dataset/matched_primary.csv.gz       the primary screening (effective cloud
#                                        fraction <= 0.2, 3 x 3 block, scans in
#                                        the sampling window), at every lag
#   dataset/matched_all_variants.csv.gz  every screening variant of every arm
#   dataset/data_dictionary.csv          one row per column
#   dataset/README.md                    contents, row counts and provenance
#
# Values are copied as text from the outputs of steps 04, 07, 08 and 13, so
# nothing is rounded or re-printed. The only columns computed here are the
# sample end time of the Colorado arms, the TEMPO window, and the scan hours
# written as ISO 8601 times instead of hour indices.
#
# The .gz files are written through R's gzfile(), whose gzip header carries no
# time stamp, so an unchanged dataset is byte-identical from run to run and git
# records no change.
#
# Inputs : data/processed/aqs_matched_variants.csv.gz (step 13),
#          matched_variants.csv (step 04), threeh_matched_variants.csv (step 07),
#          smoke_flags.csv (step 08), aqs_matched_primary.csv.gz,
#          matched_primary.csv and threeh_matched_primary.csv (row-count checks)
# Outputs: dataset/
# =============================================================================
source("R/00_config.R")

OUT  <- "dataset"
ARMS <- c("national", "colorado_24h", "colorado_3h")
dir.create(OUT, showWarnings = FALSE)

# ---- helpers -----------------------------------------------------------------
# Every column is read as text, and an empty field becomes NA.
rd <- function(f) {
  p <- file.path(P$processed, f)
  if (!file.exists(p)) stop("Missing ", p, " - run steps 04, 07, 08 and 13 first.")
  d <- tibble::as_tibble(data.table::fread(p, colClasses = "character"))
  d[] <- lapply(d, function(x) replace(x, !is.na(x) & x == "", NA_character_))
  d
}
ISO    <- "%Y-%m-%dT%H:%M:%SZ"
to_t   <- function(x) as.POSIXct(x, format = ISO, tz = "UTC")
from_t <- function(t) format(t, ISO, tz = "UTC")
shift  <- function(x, hours) from_t(to_t(x) + as.numeric(hours) * 3600)

# scan_hours holds UTC hour indices (hours since 1970-01-01 00:00 UTC), space
# separated; write each as the ISO 8601 time at which that hour begins.
scan_times <- function(x) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  if (any(ok)) {
    parts <- strsplit(x[ok], " ", fixed = TRUE)
    h <- as.numeric(unlist(parts))
    if (anyNA(h)) stop("scan_hours holds a value that is not an hour index")
    iso <- format(as.POSIXct(h * 3600, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%MZ", tz = "UTC")
    out[ok] <- vapply(split(iso, rep.int(seq_along(parts), lengths(parts))),
                      paste, character(1), collapse = " ", USE.NAMES = FALSE)
  }
  out
}
check <- function(ok, ...) if (!isTRUE(all(ok))) stop(...)

# CDPHE site code -> AQS site ID, as in R/01_coatts.R (24 h) and
# R/06_threeh_samples.R (3 h). Checked against both files below, so the two
# cannot drift apart unnoticed.
XWALK <- tibble::tribble(
  ~site_code, ~site_id,
  "ADCO", "08-001-0010",
  "CNCO", "08-043-0004",
  "COCO", "08-041-0017",
  "GPCO", "08-077-0018",
  "JFCO", "08-059-0015",
  "LSCO", "08-123-0015",
  "POCO", "08-101-0017",
  "CHCO", "08-035-0004",
  "PVCO", "08-123-0008"
)
src <- paste(c(readLines("R/01_coatts.R"), readLines("R/06_threeh_samples.R")), collapse = "\n")
for (i in seq_len(nrow(XWALK))) {
  check(grepl(sprintf('"%s",[^\n]*"%s"', XWALK$site_code[i], XWALK$site_id[i]), src, perl = TRUE),
        "Crosswalk ", XWALK$site_code[i], " = ", XWALK$site_id[i],
        " is not the one in R/01_coatts.R or R/06_threeh_samples.R")
}

# ---- 1. national arm (step 13) --------------------------------------------------
nat <- rd("aqs_matched_variants.csv.gz")
check(as.numeric(difftime(to_t(nat$end_utc), to_t(nat$start_utc), units = "hours")) ==
        as.numeric(nat$duration_h), "National end_utc is not start_utc + duration_h")
nat <- nat |>
  transmute(arm = "national", site_id, site_code = NA_character_, site_name, state, county, networks,
            lat, lon, duration_h, start_utc, end_utc, sample_date_local,
            hcho_ugm3, hcho_ppb = hcho_ppb_std, hcho_molec_cm3 = hcho_molec_cm3_local,
            n_poc, qualifiers, method, sample_frequency,
            temp_c_hrrr, press_hpa_hrrr, pbl_m_hrrr, met_coverage,
            lag_h, max_ecf, block = block_label, scan_window = "sampling window",
            tempo_start_utc = shift(start_utc, lag_h), tempo_end_utc = shift(end_utc, lag_h),
            n_scans, n_valid_scans, tempo_vc, tempo_pbl_m, tempo_press_hpa,
            scan_times_utc = scan_times(scan_hours), h_eff_km, usable)

# ---- 2. Colorado 24 h arm (step 04) ---------------------------------------------
mid <- CFG$midday_local_hours
co <- rd("matched_variants.csv")
check(co$window %in% c("all_day", "midday"), "Unexpected window in matched_variants.csv")
check(co$site %in% XWALK$site_code, "A Colorado 24 h site is not in the crosswalk")
# the 24 h window is 00-24 local standard time on the sample date
check(to_t(co$start_utc) == as.POSIXct(paste(co$sample_date, "00:00:00"), tz = "UTC") -
        CFG$utc_offset_hours * 3600, "A Colorado 24 h sample does not start at local midnight")
co24 <- co |>
  left_join(XWALK, by = c("site" = "site_code"), keep = FALSE) |>
  transmute(arm = "colorado_24h", site_id, site_code = site, site_name, state = "Colorado",
            county = NA_character_, networks = NA_character_,
            lat, lon, duration_h, start_utc, end_utc = shift(start_utc, duration_h),
            sample_date_local = sample_date,
            hcho_ugm3, hcho_ppb = hcho_ppb_std, hcho_molec_cm3 = hcho_molec_cm3_local,
            n_poc = NA_character_, qualifiers = flags, method = NA_character_,
            sample_frequency = NA_character_,
            temp_c_hrrr, press_hpa_hrrr, pbl_m_hrrr, met_coverage,
            lag_h = "0", max_ecf, block = block_label,
            scan_window = ifelse(window == "midday",
                                 sprintf("midday %02d:00-%02d:00 local standard time", mid[1], mid[2]),
                                 "sampling window"),
            tempo_start_utc = ifelse(window == "midday", shift(start_utc, mid[1]), start_utc),
            tempo_end_utc   = ifelse(window == "midday", shift(start_utc, mid[2]), end_utc),
            n_scans, n_valid_scans, tempo_vc, tempo_pbl_m, tempo_press_hpa,
            scan_times_utc = scan_times(scan_hours), h_eff_km, usable)

# ---- 3. Colorado 3 h arm (step 07) ----------------------------------------------
th <- rd("threeh_matched_variants.csv")
check(th$site %in% XWALK$site_code, "A Colorado 3 h site is not in the crosswalk")
check(th$win_start_utc == shift(th$start_utc, th$lag_h) &
        th$win_end_utc == shift(th$start_utc, as.numeric(th$duration_h) + as.numeric(th$lag_h)),
      "The 3 h TEMPO window is not the sampling window shifted by lag_h")
co3 <- th |>
  left_join(XWALK, by = c("site" = "site_code"), keep = FALSE) |>
  transmute(arm = "colorado_3h", site_id, site_code = site, site_name, state = "Colorado",
            county = NA_character_, networks = NA_character_,
            lat, lon, duration_h, start_utc, end_utc = shift(start_utc, duration_h),
            sample_date_local = sample_date,
            hcho_ugm3, hcho_ppb = hcho_ppb_std, hcho_molec_cm3 = hcho_molec_cm3_local,
            n_poc = NA_character_, qualifiers = flags, method = NA_character_,
            sample_frequency = NA_character_,
            temp_c_hrrr, press_hpa_hrrr, pbl_m_hrrr, met_coverage,
            lag_h, max_ecf, block = block_label, scan_window = "sampling window",
            tempo_start_utc = win_start_utc, tempo_end_utc = win_end_utc,
            n_scans, n_valid_scans, tempo_vc, tempo_pbl_m, tempo_press_hpa,
            scan_times_utc = scan_times(scan_hours), h_eff_km, usable)

# The Colorado arms carry their own coordinates; where the same monitor is also
# in the national arm, they must agree, which confirms the crosswalk.
co_xy <- distinct(bind_rows(co24, co3), site_id, lat, lon)
nat_xy <- distinct(nat, site_id, lat_n = lat, lon_n = lon)
xy <- inner_join(co_xy, nat_xy, by = "site_id")
check(abs(as.numeric(xy$lat) - as.numeric(xy$lat_n)) < 1e-6 &
        abs(as.numeric(xy$lon) - as.numeric(xy$lon_n)) < 1e-6,
      "A Colorado site's coordinates differ from the national arm's for the same AQS ID")

# ---- 4. smoke flags (step 08) ------------------------------------------------------
arm_of <- c(national = "national", coatts = "colorado_24h", threeh = "colorado_3h")
smoke <- rd("smoke_flags.csv") |>
  filter(arm %in% names(arm_of)) |>
  transmute(arm = unname(arm_of[arm]), site_key = site, start_utc = win_start_utc, end_utc = win_end_utc,
            hms_available, n_smoke_polygons, smoke_max_density, smoke_class, smoke_any, smoke_any_day)

ds <- bind_rows(nat, co24, co3) |>
  mutate(site_key = coalesce(site_code, site_id)) |>
  left_join(smoke, by = c("arm", "site_key", "start_utc", "end_utc"), relationship = "many-to-one")
check(!is.na(ds$hms_available), sum(is.na(ds$hms_available)),
      " matched rows have no smoke flags; re-run step 08")
ds <- ds |>
  select(-site_key) |>
  arrange(match(arm, ARMS), site_id, start_utc, as.numeric(duration_h), as.numeric(lag_h),
          as.numeric(max_ecf), block, scan_window)

key <- paste(ds$arm, ds$site_id, ds$start_utc, ds$duration_h, ds$lag_h, ds$max_ecf,
             ds$block, ds$scan_window)
check(!anyDuplicated(key), "Two rows share arm, site, sample, lag and screening variant")

# ---- 5. the primary variant, checked against the pipeline's own primary files ----
primary <- filter(ds, as.numeric(max_ecf) == CFG$qc_max_cloud_fraction, block == "3x3",
                  scan_window == "sampling window")
n_ref <- c(national     = nrow(data.table::fread(file.path(P$processed, "aqs_matched_primary.csv.gz"), select = 1L)),
           colorado_24h = nrow(data.table::fread(file.path(P$processed, "matched_primary.csv"), select = 1L)),
           colorado_3h  = nrow(data.table::fread(file.path(P$processed, "threeh_matched_primary.csv"), select = 1L)))
n_out <- vapply(ARMS, function(a) sum(primary$arm == a), integer(1))
check(n_out == n_ref[ARMS], "Primary rows differ from the pipeline's primary files: ",
      paste(ARMS, n_out, "vs", n_ref[ARMS], collapse = "; "))

# ---- 6. data dictionary -------------------------------------------------------------
dict <- tibble::tribble(
  ~column, ~units, ~description,
  "arm", "", "national: the CONUS EPA AQS formaldehyde monitors of the national analysis (24 h, 8 h and 3 h samples, Colorado included); colorado_24h: the seven Colorado 24 h sites of the case study; colorado_3h: the Colorado 3 h ozone-precursor sites (Chatfield State Park, Platteville). A Colorado sample can therefore appear in both a Colorado arm and the national arm.",
  "site_id", "", "EPA AQS site ID (state-county-site).",
  "site_code", "", "CDPHE site code (Colorado arms only).",
  "site_name", "", "Site name: AQS's for the national arm, CDPHE's for the Colorado arms (they can differ for the same station).",
  "state", "", "U.S. state.",
  "county", "", "County (national arm only).",
  "networks", "", "AQS monitoring networks, e.g. NATTS, PAMS (national arm only; blank when AQS lists none).",
  "lat", "degrees north", "Monitor latitude.",
  "lon", "degrees east", "Monitor longitude.",
  "duration_h", "h", "Sampling duration.",
  "start_utc", "ISO 8601 UTC", "Start of the sampling window.",
  "end_utc", "ISO 8601 UTC", "End of the sampling window (start_utc + duration_h).",
  "sample_date_local", "date", "Local standard-time date on which sampling began.",
  "hcho_ugm3", "ug m-3", "Surface formaldehyde as reported to AQS, at 25 C and 1 atm; values reported in ppb (ppbC) were converted at 25 C and 1 atm. Collocated monitors (POCs) for the same window are averaged.",
  "hcho_ppb", "ppb", "hcho_ugm3 as a mixing ratio (x 24.45 / 30.026).",
  "hcho_molec_cm3", "molecules cm-3", "Surface number density: hcho_ppb at the HRRR temperature and pressure averaged over the sampling window.",
  "n_poc", "", "Number of collocated monitors (POCs) averaged (national arm only).",
  "qualifiers", "", "AQS qualifiers: code and description for the national arm, codes only for the Colorado arms. Samples with AQS null-data qualifiers were removed.",
  "method", "", "AQS sampling and analysis method (national arm only).",
  "sample_frequency", "", "AQS sampling frequency (national arm only).",
  "temp_c_hrrr", "C", "NOAA HRRR 2 m temperature averaged over the hours of the sampling window.",
  "press_hpa_hrrr", "hPa", "NOAA HRRR surface pressure averaged over the hours of the sampling window.",
  "pbl_m_hrrr", "m", "NOAA HRRR planetary boundary layer height averaged over the hours of the sampling window.",
  "met_coverage", "fraction", "Share of the sampling window's hours with an HRRR analysis.",
  "lag_h", "h", "Shift of the TEMPO window relative to the sampling window (0 = the sampling window itself; national sub-daily samples -3, 0, 3; Colorado 3 h -3 to 9; 24 h samples 0 only).",
  "max_ecf", "", "TEMPO screen: maximum effective cloud fraction of a pixel (0.1, 0.2 or 0.3; primary 0.2).",
  "block", "", "TEMPO pixel block averaged around the monitor: 1x1, 3x3 or 5x5 pixels (primary 3x3).",
  "scan_window", "", "Which TEMPO scans were used: those in the sampling window (shifted by lag_h), or, for a second Colorado 24 h variant, only those between 10:00 and 14:00 local standard time.",
  "tempo_start_utc", "ISO 8601 UTC", "Start of the TEMPO window. A scan is assigned to the UTC hour containing its mid-scan time, and the scans whose hours fall in [tempo_start_utc, tempo_end_utc) are averaged.",
  "tempo_end_utc", "ISO 8601 UTC", "End of the TEMPO window.",
  "n_scans", "", "TEMPO scans with data over the site in the TEMPO window.",
  "n_valid_scans", "", "Scans in which at least half of the block's pixels pass the screen (main data quality flag 0, effective cloud fraction <= max_ecf, and the solar zenith angle and snow/ice limits in R/00_config.R).",
  "tempo_vc", "molecules cm-2", "TEMPO L3 V04 HCHO vertical column: mean over valid scans of each scan's mean over the passing pixels of the block.",
  "tempo_pbl_m", "m", "Boundary-layer height supplied with the TEMPO retrieval, mean over valid scans.",
  "tempo_press_hpa", "hPa", "Surface pressure supplied with the TEMPO retrieval, mean over valid scans.",
  "scan_times_utc", "ISO 8601 UTC", "Space-separated start of the UTC hour of each valid scan.",
  "h_eff_km", "km", "Effective mixing height: tempo_vc / hcho_molec_cm3 / 1e5.",
  "usable", "", "TRUE when the sample has both a surface value and a TEMPO column (at least one valid scan).",
  "hms_available", "", "TRUE when NOAA Hazard Mapping System smoke files exist for every day the window touches; the smoke columns are blank otherwise.",
  "n_smoke_polygons", "", "HMS smoke polygons over the site whose analysis period overlaps the sampling window widened by 3 h on each side.",
  "smoke_max_density", "", "Densest of those polygons: 0 none, 1 light, 2 medium, 3 heavy.",
  "smoke_class", "", "none, light or medium/heavy, from smoke_max_density.",
  "smoke_any", "", "TRUE when smoke_max_density > 0.",
  "smoke_any_day", "", "TRUE when any HMS polygon covered the site on the window's HMS days, whatever its analysis period."
)
check(identical(dict$column, names(ds)), "The data dictionary does not list the dataset's columns in order")

# ---- 7. write -------------------------------------------------------------------------
write_gz <- function(df, path) {
  tmp <- tempfile(fileext = ".csv")
  data.table::fwrite(df, tmp, na = "")
  con_in  <- file(tmp, "rb")
  con_out <- gzfile(path, "wb", compression = 9)
  repeat {
    b <- readBin(con_in, "raw", 16e6)
    if (!length(b)) break
    writeBin(b, con_out)
  }
  close(con_in); close(con_out); unlink(tmp)
  invisible(path)
}
write_gz(primary, file.path(OUT, "matched_primary.csv.gz"))
write_gz(ds,      file.path(OUT, "matched_all_variants.csv.gz"))
data.table::fwrite(dict, file.path(OUT, "data_dictionary.csv"))

# ---- 8. README ---------------------------------------------------------------------------
count_tbl <- function(d) {
  vapply(ARMS, function(a) {
    x <- d[d$arm == a, ]
    sprintf("| %s | %s | %s | %s | %s to %s |", a,
            format(nrow(x), big.mark = ","),
            format(sum(x$usable == "TRUE"), big.mark = ","),
            n_distinct(x$site_id),
            min(x$sample_date_local), max(x$sample_date_local))
  }, character(1), USE.NAMES = FALSE)
}
lp <- filter(primary, lag_h == "0")
readme <- c(
  "# Matched surface formaldehyde and TEMPO HCHO dataset",
  "",
  "Written by `R/23_export_dataset.R` (run by `run_all.R`); do not edit by hand.",
  "Every value is copied from the pipeline's processed files, so re-running the",
  "pipeline reproduces these files byte for byte.",
  "",
  "Each row is one surface formaldehyde sample matched to TEMPO HCHO vertical",
  "columns under one screening variant and one time lag, with HRRR meteorology",
  "and NOAA HMS smoke flags. Columns are described in `data_dictionary.csv`.",
  "",
  "| File | Contents | Rows |",
  "|---|---|---|",
  sprintf("| `matched_primary.csv.gz` | Primary screening: max_ecf = %s, 3x3 block, scans in the sampling window; every lag | %s |",
          CFG$qc_max_cloud_fraction, format(nrow(primary), big.mark = ",")),
  sprintf("| `matched_all_variants.csv.gz` | Every variant: max_ecf 0.1/0.2/0.3 x block 1x1/3x3/5x5 x lag (and the Colorado 24 h midday window) | %s |",
          format(nrow(ds), big.mark = ",")),
  "| `data_dictionary.csv` | One row per column: units and definition | |",
  "",
  "The main analyses use `matched_primary.csv.gz` with `lag_h` = 0 and `usable` = TRUE:",
  "",
  "| Arm | Samples | Usable | Sites | Sample dates |",
  "|---|---|---|---|---|",
  count_tbl(lp),
  "",
  "Notes",
  "",
  "- The national arm includes the Colorado monitors, so a Colorado sample can",
  "  appear in both a Colorado arm and the national arm (same `site_id` and",
  "  `start_utc`).",
  "- `usable` = FALSE rows (no TEMPO column passing the screen) are kept, so",
  "  observability can be studied; the TEMPO columns are blank on those rows.",
  "- Blank fields are missing values.",
  "- Surface concentrations are at 25 C and 1 atm as reported to AQS;",
  "  `hcho_molec_cm3` is at the HRRR temperature and pressure of the window.",
  "",
  "Sources: U.S. EPA Air Quality System (surface formaldehyde); NASA TEMPO",
  "Level 3 V04 HCHO (https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004); NOAA",
  "HRRR analyses (NOAA Open Data Dissemination archive on AWS); NOAA Hazard",
  "Mapping System smoke polygons. Code: https://github.com/pdez90/coatts_hcho."
)
writeLines(readme, file.path(OUT, "README.md"))

log_msg("Dataset: ", nrow(primary), " primary rows and ", nrow(ds), " rows over all variants, ",
        "from ", paste(ARMS, n_out, sep = " ", collapse = ", "), " (primary); written to ", OUT, "/")
