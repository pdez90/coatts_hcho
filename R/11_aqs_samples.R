# =============================================================================
# 11_aqs_samples.R - sample-level formaldehyde from EPA's AQS for the national arm
#
# Step 10 lists the candidate monitors; this step pulls their individual samples
# (AQS parameter 43502) for CFG$aqs_years and writes one row per sample with the
# start and end of the sampling period in UTC. AQS records the time each sample
# began, in local standard time, and also gives the GMT date and time, so the
# sampling window needs no time-zone assumption.
#
# Requests go state by state (one call per state and year, cached on disk), which
# is far fewer calls than one per site. Needs AQS_EMAIL and AQS_KEY in
# ~/.Renviron; see the README.
# Outputs: data/processed/aqs_hcho_samples.csv        (one row per sample)
#          output/tables/aqs_sample_clocks.csv        (start hours by site)
#          output/tables/aqs_samples_inventory.csv    (site x duration summary)
#          data/raw/aqs/samples/sample_<state>_<year>.csv.gz  (cached responses)
# =============================================================================
source("R/00_config.R")

aqs_email <- Sys.getenv("AQS_EMAIL")
aqs_key   <- Sys.getenv("AQS_KEY")
if (!nzchar(aqs_email) || !nzchar(aqs_key)) {
  stop("AQS_EMAIL and AQS_KEY are not set. Sign up once with\n",
       "  browseURL(\"https://aqs.epa.gov/data/api/signup?email=YOUR@EMAIL\")\n",
       "then put AQS_EMAIL and AQS_KEY in ~/.Renviron and restart R.")
}
cand_path <- file.path(P$processed, "aqs_candidate_sites.csv")
if (!file.exists(cand_path)) stop("Run R/10_aqs_inventory.R first (no ", cand_path, ")")

sample_dir <- file.path(P$raw_aqs, "samples")
dir.create(sample_dir, recursive = TRUE, showWarnings = FALSE)

cand <- read_tbl(cand_path, colClasses = list(character = c("site_id", "years"))) |>
  filter(duration_class %in% CFG$aqs_durations)
states <- sort(unique(substr(cand$site_id, 1, 2)))
log_msg(nrow(cand), " candidate monitors at ", n_distinct(cand$site_id), " sites in ",
        length(states), " states; ", length(states) * length(CFG$aqs_years), " AQS requests at most")

# ---- 1. one request per state and year, cached --------------------------------
aqs_api <- function(service, ...) {
  req <- public_request(paste0("https://aqs.epa.gov/data/api/", service)) |>
    httr2::req_url_query(email = aqs_email, key = aqs_key, ...) |>
    httr2::req_timeout(300)
  resp <- httr2::req_perform(req)
  Sys.sleep(CFG$aqs_api_pause_s)
  j <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  status <- if (is.null(j$Header$status)) "unknown" else j$Header$status[1]
  list(status = status,
       data = if (is.null(j$Data) || !length(j$Data)) tibble() else tibble::as_tibble(j$Data))
}

raw <- map(states, function(st) {
  map(CFG$aqs_years, function(y) {
    f <- file.path(sample_dir, sprintf("sample_%s_%d.csv.gz", st, y))
    if (file.exists(f) && !CFG$aqs_refresh) return(read_tbl(f, colClasses = "character"))
    res <- tryCatch(aqs_api("sampleData/byState", param = CFG$aqs_param_hcho,
                            bdate = sprintf("%d0101", y), edate = sprintf("%d1231", y), state = st),
                    error = function(e) { log_msg("  request failed for state ", st, " ", y, ": ",
                                                  conditionMessage(e)); list(status = "error", data = tibble()) })
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
if (!nrow(raw)) stop("AQS returned no sample-level formaldehyde data.")
log_msg(nrow(raw), " raw sample rows downloaded or cached")

# ---- 2. clean --------------------------------------------------------------------
need <- c("state_code", "county_code", "site_number", "poc", "latitude", "longitude",
          "date_local", "time_local", "date_gmt", "time_gmt", "sample_measurement",
          "units_of_measure", "sample_duration", "qualifier", "method", "sample_frequency")
miss <- setdiff(need, names(raw))
if (length(miss)) stop("AQS sample records lack: ", paste(miss, collapse = ", "),
                       "\n  fields present: ", paste(names(raw), collapse = ", "))

# "24 HOUR", "3 HOURS", "8 HOUR" -> hours
duration_hours <- function(x) {
  n <- suppressWarnings(as.numeric(str_extract(x, "\\d+(\\.\\d+)?")))
  ifelse(str_detect(x, regex("minute", ignore_case = TRUE)), n / 60, n)
}
null_codes <- CFG$aqs_null_qualifiers_fallback

samples <- raw |>
  mutate(site_id = paste(state_code, county_code, site_number, sep = "-"),
         value_raw = suppressWarnings(as.numeric(sample_measurement)),
         lat = suppressWarnings(as.numeric(latitude)),
         lon = suppressWarnings(as.numeric(longitude)),
         duration_h = duration_hours(sample_duration),
         start_utc = suppressWarnings(ymd_hm(paste(date_gmt, time_gmt), tz = "UTC")),
         sample_date_local = suppressWarnings(as.Date(date_local)),
         start_hour_local = suppressWarnings(as.numeric(substr(time_local, 1, 2)) +
                                             as.numeric(substr(time_local, 4, 5)) / 60),
         qualifier = coalesce(qualifier, "")) |>
  filter(site_id %in% cand$site_id,
         !is.na(value_raw), !is.na(start_utc), !is.na(duration_h), duration_h > 0)

# units: AQS reports carbonyls in ug/m3, occasionally in ppb
unit_tbl <- count(samples, units_of_measure, name = "rows")
log_msg("Units: ", paste(unit_tbl$units_of_measure, unit_tbl$rows, sep = " = ", collapse = "; "))
samples <- samples |>
  mutate(is_ppb = str_detect(units_of_measure, regex("billion", ignore_case = TRUE)),
         hcho_ugm3 = if_else(is_ppb, value_raw * CFG$hcho_molar_mass / 24.45, value_raw))
if (any(samples$is_ppb)) log_msg("  ", sum(samples$is_ppb),
                                 " rows reported in ppb were converted at 25 C and 1 atm")

# drop rows carrying an AQS null data qualifier (invalid or QC/QA values)
has_null_q <- function(q) {
  codes <- str_split(q, "[,;]\\s*")
  vapply(codes, function(cc) any(str_trim(str_extract(cc, "^[A-Z0-9]+")) %in% null_codes), logical(1))
}
bad <- has_null_q(samples$qualifier)
if (any(bad)) log_msg("Dropped ", sum(bad), " samples carrying a null data qualifier")
samples <- samples[!bad, , drop = FALSE]

# average duplicate POCs / repeated records of the same window
samples <- samples |>
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
         hcho_molec_cm3 = ugm3_to_molec_cm3(hcho_ugm3)) |>
  filter(duration_class %in% CFG$aqs_durations,
         sample_date_local >= CFG$date_range[1], sample_date_local <= CFG$date_range[2]) |>
  left_join(cand |> group_by(site_id) |>
              summarise(site_name = first(site_name), state = first(state), county = first(county),
                        networks = paste(sort(unique(networks[!is.na(networks) & nzchar(networks)])), collapse = "; "),
                        .groups = "drop"), by = "site_id") |>
  arrange(site_id, start_utc)

data.table::fwrite(samples, file.path(P$processed, "aqs_hcho_samples.csv"))
log_msg("Wrote ", nrow(samples), " samples at ", n_distinct(samples$site_id), " sites to ",
        file.path(P$processed, "aqs_hcho_samples.csv"))

# ---- 3. what clock does each site sample on? -------------------------------------
clocks <- samples |>
  count(site_id, site_name, state, duration_class, start_hour_local, name = "samples") |>
  arrange(site_id, duration_class, start_hour_local)
data.table::fwrite(clocks, file.path(P$tables, "aqs_sample_clocks.csv"))

inv <- samples |>
  group_by(duration_class, site_id, site_name, state, networks, lat, lon) |>
  summarise(samples = n(), days = n_distinct(sample_date_local),
            first = min(sample_date_local), last = max(sample_date_local),
            start_hours = paste(sort(unique(round(start_hour_local))), collapse = ","),
            median_ugm3 = round(median(hcho_ugm3), 2), .groups = "drop") |>
  arrange(duration_class, desc(samples))
data.table::fwrite(inv, file.path(P$tables, "aqs_samples_inventory.csv"))

for (dc in sort(unique(samples$duration_class))) {
  x <- filter(samples, duration_class == dc)
  hrs <- sort(unique(round(x$start_hour_local)))
  log_msg(dc, ": ", n_distinct(x$site_id), " sites, ", nrow(x), " samples, ",
          n_distinct(x$sample_date_local), " distinct dates; start hours ",
          paste(hrs, collapse = ", "))
}
print(inv |> group_by(duration_class) |> slice_head(n = 5) |>
        select(duration_class, site_id, site_name, state, samples, days, start_hours))

# ---- 4. what the TEMPO extraction will cost --------------------------------------
# sites are grouped into boxes; step 12 makes one OPeNDAP request per box and scan
clus <- samples |>
  distinct(site_id, lat, lon, duration_class, sample_date_local) |>
  mutate(cluster = paste0("c", round(lat / CFG$aqs_cluster_deg_lat), "_",
                          round(lon / CFG$aqs_cluster_deg_lon)))
cost <- clus |>
  group_by(cluster) |>
  summarise(sites = n_distinct(site_id), dates = n_distinct(sample_date_local), .groups = "drop")
log_msg(nrow(cost), " site clusters (", CFG$aqs_cluster_deg_lat, " deg lat x ",
        CFG$aqs_cluster_deg_lon, " deg lon); ", sum(cost$dates), " cluster-days; roughly ",
        format(sum(cost$dates) * CFG$aqs_scans_per_day_guess, big.mark = ","),
        " OPeNDAP requests for step 12")
data.table::fwrite(cost, file.path(P$tables, "aqs_cluster_cost.csv"))
print(arrange(cost, desc(dates)) |> head(10))
log_msg("AQS sample pull done.")
