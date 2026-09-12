# =============================================================================
# 10_aqs_inventory.R - what formaldehyde data does EPA's AQS hold for 2024-2025?
#
# Inventory step for the national arm: which monitors report formaldehyde
# (AQS parameter 43502), at what sample duration (24-h NATTS/NCore style, or
# sub-daily 1-h/3-h/8-h PAMS style), in which networks, and with how many
# samples. Uses EPA's pre-generated AirData files (no API key needed):
#   annual_conc_by_monitor_<year>.zip  - one row per monitor, duration and year
#   aqs_monitors.zip                   - monitor metadata incl. network names
# If AQS_EMAIL and AQS_KEY are set (see README), it also queries the AQS API for
# the sample-level records of named sites, to show what a sample time stamp
# looks like in AQS (AQS reports the time sampling began) - an independent check
# on the 09:00 stamps of the Colorado 3-h samples.
# Outputs: output/tables/aqs_hcho_inventory.csv, aqs_hcho_summary.csv,
#          output/tables/aqs_named_sites_sample_times.csv (with an API key),
#          data/processed/aqs_candidate_sites.csv
# =============================================================================
source("R/00_config.R")

dir.create(P$raw_aqs, recursive = TRUE, showWarnings = FALSE)

norm_names <- function(d) {
  n <- tolower(gsub("[^A-Za-z0-9]+", "_", names(d)))
  names(d) <- gsub("^_+|_+$", "", n)
  d
}
need_cols <- function(d, cols, what) {
  miss <- setdiff(cols, names(d))
  if (length(miss)) stop(what, ": missing columns ", paste(miss, collapse = ", "),
                         "\n  columns present: ", paste(head(names(d), 60), collapse = ", "))
  d
}
is_zip_file <- function(path) file.exists(path) && file.size(path) > 1000 &&
  identical(readBin(path, "raw", n = 2), charToRaw("PK"))

fetch_zip <- function(name) {
  dest <- file.path(P$raw_aqs, name)
  if (is_zip_file(dest) && !CFG$aqs_refresh) return(dest)
  url <- paste0(CFG$aqs_base_url, name)
  log_msg("Downloading ", url)
  tmp <- tempfile(fileext = ".zip")
  resp <- public_request(url) |>
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform(path = tmp)
  if (httr2::resp_status(resp) >= 400 || !is_zip_file(tmp)) {
    stop("Download failed for ", url, " (HTTP ", httr2::resp_status(resp), "). ",
         "The file list is at ", CFG$aqs_base_url, "download_files.html")
  }
  file.copy(tmp, dest, overwrite = TRUE)
  unlink(tmp)
  Sys.sleep(1)
  dest
}
read_zip_csv <- function(zip_path) {
  inside <- utils::unzip(zip_path, list = TRUE)
  csv <- inside$Name[grepl("\\.csv$", inside$Name, ignore.case = TRUE)][1]
  if (is.na(csv)) stop("No csv inside ", zip_path)
  td <- tempfile()
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  utils::unzip(zip_path, files = csv, exdir = td)
  norm_names(read_tbl(file.path(td, csv), colClasses = "character"))
}
site_key <- function(state, county, site) paste(state, county, site, sep = "-")

# ---- 1. annual summaries for formaldehyde -----------------------------------
ann <- map(CFG$aqs_years, function(y) {
  d <- read_zip_csv(fetch_zip(sprintf("annual_conc_by_monitor_%d.zip", y)))
  site_col <- intersect(c("site_num", "site_number"), names(d))[1]
  if (is.na(site_col)) stop("annual file has no site number column: ", paste(head(names(d), 40), collapse = ", "))
  d <- need_cols(d, c("state_code", "county_code", "parameter_code", "poc", "latitude", "longitude",
                      "sample_duration", "year", "observation_count", "arithmetic_mean",
                      "units_of_measure", "local_site_name", "method_name", "state_name",
                      "county_name", site_col),
                 sprintf("annual_conc_by_monitor_%d", y))
  d |>
    filter(parameter_code == CFG$aqs_param_hcho) |>
    mutate(site_id = site_key(state_code, county_code, .data[[site_col]]),
           year = suppressWarnings(as.integer(year)),
           lat = suppressWarnings(as.numeric(latitude)),
           lon = suppressWarnings(as.numeric(longitude)),
           obs = suppressWarnings(as.integer(observation_count)),
           mean_value = suppressWarnings(as.numeric(arithmetic_mean)))
}) |> list_rbind()
if (!nrow(ann)) stop("No formaldehyde (parameter ", CFG$aqs_param_hcho, ") rows in the annual AQS files.")

# the annual file repeats each monitor by event type / pollutant standard: keep the fullest row
monitors <- ann |>
  arrange(site_id, poc, sample_duration, year, desc(obs)) |>
  distinct(site_id, poc, sample_duration, year, .keep_all = TRUE) |>
  transmute(site_id, poc, sample_duration, year, obs, mean_value,
            units = units_of_measure, lat, lon,
            site_name = local_site_name, state = state_name, county = county_name,
            method = method_name)
log_msg(nrow(monitors), " monitor-duration-year rows of formaldehyde in ",
        paste(CFG$aqs_years, collapse = ", "))

# ---- 2. network membership (NATTS, NCore, PAMS, ...) ------------------------
mon_meta <- tryCatch({
  d <- read_zip_csv(fetch_zip("aqs_monitors.zip"))
  site_col <- intersect(c("site_num", "site_number"), names(d))[1]
  net_col  <- intersect(c("networks", "network"), names(d))[1]
  if (is.na(site_col) || is.na(net_col)) {
    log_msg("  aqs_monitors.zip has no network column - network labels will be blank")
    NULL
  } else {
    d |>
      filter(parameter_code == CFG$aqs_param_hcho) |>
      mutate(site_id = site_key(state_code, county_code, .data[[site_col]]),
             net = coalesce(.data[[net_col]], "")) |>
      group_by(site_id, poc) |>
      summarise(networks = paste(sort(unique(net[nzchar(net)])), collapse = "; "), .groups = "drop")
  }
}, error = function(e) {
  log_msg("  monitor metadata unavailable: ", conditionMessage(e))
  NULL
})

inv <- monitors
inv <- if (is.null(mon_meta)) mutate(inv, networks = NA_character_) else left_join(inv, mon_meta, by = c("site_id", "poc"))
inv <- inv |>
  mutate(duration_class = case_when(
           str_detect(sample_duration, regex("^1 hour", ignore_case = TRUE))  ~ "1 h",
           str_detect(sample_duration, regex("^3 hour", ignore_case = TRUE))  ~ "3 h",
           str_detect(sample_duration, regex("^8 hour", ignore_case = TRUE))  ~ "8 h",
           str_detect(sample_duration, regex("^24 hour", ignore_case = TRUE)) ~ "24 h",
           TRUE ~ sample_duration),
         in_conus = !is.na(lat) & !is.na(lon) &
           lon >= CFG$aqs_conus_bbox[1] & lat >= CFG$aqs_conus_bbox[2] &
           lon <= CFG$aqs_conus_bbox[3] & lat <= CFG$aqs_conus_bbox[4]) |>
  arrange(desc(obs))
data.table::fwrite(inv, file.path(P$tables, "aqs_hcho_inventory.csv"))

wide <- inv |>
  group_by(site_id, site_name, state, county, lat, lon, networks, duration_class, in_conus) |>
  summarise(samples = sum(obs, na.rm = TRUE),
            years = paste(sort(unique(year)), collapse = "+"),
            mean_ugm3 = round(stats::weighted.mean(mean_value, obs, na.rm = TRUE), 2),
            .groups = "drop")

summary_tbl <- wide |>
  mutate(network_group = case_when(
           str_detect(coalesce(networks, ""), regex("NATTS", ignore_case = TRUE)) ~ "NATTS",
           str_detect(coalesce(networks, ""), regex("NCORE", ignore_case = TRUE)) ~ "NCore",
           str_detect(coalesce(networks, ""), regex("PAMS", ignore_case = TRUE))  ~ "PAMS",
           nzchar(coalesce(networks, "")) ~ "other network",
           TRUE ~ "no network label")) |>
  group_by(duration_class, network_group) |>
  summarise(sites = n_distinct(site_id), monitors = n(), samples = sum(samples),
            sites_with_enough = n_distinct(site_id[samples >= CFG$aqs_min_samples]),
            .groups = "drop") |>
  arrange(duration_class, desc(sites))
data.table::fwrite(summary_tbl, file.path(P$tables, "aqs_hcho_summary.csv"))
print(summary_tbl, n = 50)

# ---- 3. candidate sites for the national arm --------------------------------
cand <- wide |>
  filter(in_conus, duration_class %in% CFG$aqs_durations, samples >= CFG$aqs_min_samples) |>
  arrange(duration_class, desc(samples))
data.table::fwrite(cand, file.path(P$processed, "aqs_candidate_sites.csv"))
log_msg("Candidate sites (", paste(CFG$aqs_durations, collapse = ", "), ", >= ",
        CFG$aqs_min_samples, " samples in ", paste(CFG$aqs_years, collapse = "+"), "): ",
        nrow(cand), " monitors at ", n_distinct(cand$site_id), " sites")
for (dc in sort(unique(cand$duration_class))) {
  x <- filter(cand, duration_class == dc)
  log_msg("  ", dc, ": ", n_distinct(x$site_id), " sites, ", sum(x$samples), " samples, ",
          n_distinct(x$state), " states")
}
print(cand |> select(site_id, site_name, state, duration_class, samples, years, networks) |> head(25))

# ---- 4. optional: sample-level records for named sites (needs an API key) ----
aqs_email <- Sys.getenv("AQS_EMAIL")
aqs_key   <- Sys.getenv("AQS_KEY")
if (nzchar(aqs_email) && nzchar(aqs_key) && length(CFG$aqs_sites_of_interest)) {
  aqs_api <- function(service, ...) {
    req <- public_request(paste0("https://aqs.epa.gov/data/api/", service)) |>
      httr2::req_url_query(email = aqs_email, key = aqs_key, ...)
    resp <- httr2::req_perform(req)
    Sys.sleep(5)                       # AQS asks for modest request rates
    j <- httr2::resp_body_json(resp, simplifyVector = TRUE)
    st <- if (is.null(j$Header$status)) "unknown" else j$Header$status[1]
    if (!identical(st, "Success")) log_msg("  AQS API status: ", st)
    if (is.null(j$Data) || !length(j$Data)) tibble() else tibble::as_tibble(j$Data)
  }
  fields_logged <- FALSE
  stamps <- map(CFG$aqs_sites_of_interest, function(sid) {
    parts <- strsplit(sid, "-", fixed = TRUE)[[1]]
    if (length(parts) != 3) { log_msg("  skipping malformed site id: ", sid); return(NULL) }
    map(CFG$aqs_years, function(y) {
      d <- tryCatch(aqs_api("sampleData/bySite", param = CFG$aqs_param_hcho,
                            bdate = sprintf("%d0101", y), edate = sprintf("%d1231", y),
                            state = parts[1], county = parts[2], site = parts[3]),
                    error = function(e) {
                      log_msg("  API failed for ", sid, " ", y, ": ", conditionMessage(e))
                      tibble()
                    })
      if (!nrow(d)) return(NULL)
      if (!fields_logged) {
        log_msg("  AQS sampleData fields: ", paste(names(d), collapse = ", "))
        fields_logged <<- TRUE
      }
      mutate(d, site_id = sid, aqs_year = y)
    }) |> list_rbind()
  }) |> list_rbind()
  if (!is.null(stamps) && nrow(stamps)) {
    data.table::fwrite(stamps, file.path(P$processed, "aqs_sample_level_named_sites.csv"))
    time_col <- intersect(c("time_local", "time_gmt"), names(stamps))[1]
    dur_col  <- intersect(c("sample_duration", "sample_duration_code"), names(stamps))[1]
    if (!is.na(time_col) && !is.na(dur_col)) {
      tod <- stamps |>
        count(site_id, aqs_year, .data[[time_col]], .data[[dur_col]], name = "samples") |>
        arrange(site_id, aqs_year)
      data.table::fwrite(tod, file.path(P$tables, "aqs_named_sites_sample_times.csv"))
      print(tod, n = 50)
      log_msg("AQS reports the time sampling began, so these stamps say whether the 09:00 ",
              "Colorado samples cover 09:00-12:00 or 06:00-09:00.")
    } else {
      log_msg("  sample records returned without a time or duration column: ",
              paste(names(stamps), collapse = ", "))
    }
  } else {
    log_msg("  no sample-level records returned for ", paste(CFG$aqs_sites_of_interest, collapse = ", "))
  }
} else {
  log_msg("No AQS_EMAIL / AQS_KEY in the environment - skipping the sample-level check. ",
          "Sign up once with browseURL('https://aqs.epa.gov/data/api/signup?email=YOUR@EMAIL'), ",
          "then put AQS_EMAIL and AQS_KEY in ~/.Renviron")
}
log_msg("AQS inventory done.")
