# =============================================================================
# 06_threeh_samples.R - 3-hour formaldehyde samples at the ozone-precursor sites
#
# Chatfield State Park (CHCO) and Platteville (PVCO) belong to CDPHE's COOPs
# network and collect 3-h formaldehyde samples beginning at 06:00 MST.
#
# SOURCE OF RECORD: EPA AQS, as for every other site in the paper. This step
# used to parse CDPHE's annual packets for 2024-2025 and reach into AQS only for
# 2023, which left the two halves of one record on two different sources. AQS
# carries all of it, so all of it comes from AQS.
#
# STAMP CONVENTION. Downstream code (CFG$threeh_stamp_is = "end") treats
# stamp_local as the END of the sampling period and the window as
# [stamp - 3 h, stamp). AQS records the START. The end is therefore computed
# here as start + duration rather than assumed to be 09:00: every sample in this
# record does begin at 06:00, but a hard-coded 09:00 would silently mis-place
# any sample that did not, and the lag analysis in step 07 is built on this
# column being right.
#
# AQS records times in local STANDARD time year-round, so the window does not
# move with daylight saving.
#
# TEMPO scans are listed and extracted by steps 02 and 03 with
# options(hcho.arm = "threeh"), and matched in step 07.
# Output: data/processed/threeh_hcho.csv, output/tables/threeh_inventory.csv
# =============================================================================
source("R/00_config.R")
source("R/helpers_aqs.R")   # one definition of the AQS request and screen

THREEH_XWALK <- tibble::tribble(
  ~site,  ~site_name,             ~aqs_site_id,
  "CHCO", "Chatfield State Park", "08-035-0004",
  "PVCO", "Platteville",          "08-123-0008"
)

# 2023 is included only if configured. The packets never held it; AQS does, and
# TEMPO science operations began in August 2023, which CFG$date_range enforces.
years <- sort(unique(c(CFG$aqs_years,
                       if (isTRUE(CFG$threeh_include_2023_aqs)) CFG$threeh_aqs_year)))
log_msg("3-h arm from AQS: sites ", paste(THREEH_XWALK$site, collapse = ", "),
        "; years ", paste(years, collapse = ", "))

states <- sort(unique(substr(THREEH_XWALK$aqs_site_id, 1, 2)))
raw <- aqs_fetch_state_years(states, years, file.path(P$raw_aqs, "samples"), CFG$aqs_refresh)
if (!nrow(raw)) stop("AQS returned no formaldehyde for state(s) ", paste(states, collapse = ", "))

cl <- aqs_clean_samples(raw, keep_site_ids = THREEH_XWALK$aqs_site_id) |>
  filter(abs(duration_h * 3600 - CFG$threeh_duration_s) < 1,
         sample_date_local >= CFG$date_range[1], sample_date_local <= CFG$date_range[2]) |>
  left_join(THREEH_XWALK, by = c("site_id" = "aqs_site_id"))

if (!nrow(cl)) stop("No 3-h formaldehyde samples survived screening for ",
                    paste(THREEH_XWALK$site, collapse = ", "))
missing <- setdiff(THREEH_XWALK$site, cl$site)
if (length(missing)) {
  log_msg("NOTE: no 3-h AQS formaldehyde for ", paste(missing, collapse = ", "),
          " in ", paste(years, collapse = ", "))
}

# Naive local stamps are built in UTC so that formatting never shifts them; they
# are labels for a local standard clock, not instants to be converted.
cl <- cl |>
  mutate(start_local_dt = as.POSIXct(paste0(sample_date_local, " 00:00:00"), tz = "UTC") +
                          start_hour_local * 3600,
         stamp_local_dt = start_local_dt + duration_h * 3600)

coords <- cl |>
  group_by(site) |>
  summarise(lat = median(lat), lon = median(lon), .groups = "drop")

modal_time <- cl |>
  count(t = format(stamp_local_dt, "%H:%M")) |>
  slice_max(n, n = 1, with_ties = FALSE) |>
  pull(t)

threeh <- cl |>
  mutate(flags = aqs_qualifier_codes(qualifiers)) |>
  transmute(site, site_name,
            program = "COOPs (3-h)",
            sample_date = sample_date_local,
            stamp_local_dt,
            n_rows = n_poc,
            hcho_ugm3,
            below_mdl = has_flag(flags, "MD"),
            qc_codes = "",                      # AQS publishes ambient rows only
            flags,
            source_file = "AQS sampleData/byState") |>
  left_join(coords, by = "site") |>
  mutate(stamp_time_unusual = format(stamp_local_dt, "%H:%M") != modal_time,
         stamp_local = format(stamp_local_dt, "%Y-%m-%d %H:%M"),
         hcho_molec_cm3 = ugm3_to_molec_cm3(hcho_ugm3),
         season = season_of(sample_date),
         year = year(sample_date)) |>
  select(site, site_name, program, lat, lon, sample_date, stamp_local, n_rows,
         hcho_ugm3, below_mdl, qc_codes, flags, source_file, stamp_time_unusual,
         hcho_molec_cm3, season, year) |>
  arrange(site, stamp_local)

if (any(is.na(threeh$lat))) {
  stop("Missing coordinates for: ", paste(unique(threeh$site[is.na(threeh$lat)]), collapse = ", "))
}
if (any(threeh$stamp_time_unusual)) {
  log_msg("NOTE: ", sum(threeh$stamp_time_unusual), " samples end at a time other than ",
          modal_time, " (flagged stamp_time_unusual; ",
          if (CFG$threeh_exclude_unusual_stamps) "left out of" else "included in",
          " the TEMPO matching): ",
          paste(threeh$site[threeh$stamp_time_unusual],
                threeh$stamp_local[threeh$stamp_time_unusual], collapse = "; "))
}

data.table::fwrite(threeh, A_threeh <- arm_paths("threeh")$samples)
inv <- threeh |>
  group_by(site, site_name, year) |>
  summarise(samples = n(), with_value = sum(!is.na(hcho_ugm3)),
            first = min(sample_date), last = max(sample_date),
            usual_stamp = modal_time, unusual_stamps = sum(stamp_time_unusual),
            median_ugm3 = round(median(hcho_ugm3, na.rm = TRUE), 2), .groups = "drop")
data.table::fwrite(inv, file.path(P$tables, "threeh_inventory.csv"))
print(inv, n = Inf)
log_msg("Wrote ", nrow(threeh), " 3-h samples to ", A_threeh,
        " (all from AQS; sampling windows end at ", modal_time, ")")
