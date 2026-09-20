# =============================================================================
# 01_coatts.R - the Colorado 24-h formaldehyde record
#
# SOURCE OF RECORD: EPA AQS. Six of the seven COATTS sites report to AQS, and
# the measurement comes from AQS, exactly as it does for the other 122 sites in
# the national arm. That was not always so: this step used to read
# all seven from CDPHE's annual data packets, which meant the Colorado results
# and the national results were derived from different copies of the same
# measurements and were never compared, and a reader can now reproduce the
# whole paper from a single public source with a free AQS key.
#
# ALL SEVEN sites come from AQS, Wheat Ridge (JFCO) included. That one is easy
# to miss, and was missed at first: AQS files it as 08-059-0015 "Peak
# Expeditionary School", it carries only 15 samples, and 15 is below
# CFG$aqs_min_samples, so step 10 never lists it as a candidate and it never
# reaches aqs_hcho_samples.csv. It is in the raw state download all the same.
# This step selects by site_id rather than by the candidate list, so it gets it.
#
# The consequence is worth stating rather than hiding: the Colorado case study
# contains one site the national arm excludes, and it is excluded by a stated
# minimum sample count, not by an accident of provenance.
#
# If a site ever genuinely leaves AQS, set its aqs_site_id to NA in the
# crosswalk below; it falls back to the CDPHE packet and is labelled
# source = "CDPHE packet". Nothing else needs to change.
#
# The packets are still downloaded and parsed for ONE reason: the per-sample
# detection limit and the sampling temperature and pressure. AQS does not
# publish those, and Colorado's effective mixing height is computed from the
# measured temperature and pressure where they exist, which makes it a better
# estimate than the national arm can produce. Step 04 also carries the national
# convention alongside, so the difference between the two is measured rather
# than assumed. Concentrations are never taken from the packets.
#
# Packet layouts parsed:
#   * 2025+ "AQDxLite" long format  (sheet Carbonyls_data)
#   * 2024  wide format             (sheet "Carbonyls Field Samples")
# Output: data/processed/coatts_hcho.csv  (one row per site x sample day)
# =============================================================================
source("R/00_config.R")
source("R/helpers_aqs.R")   # one definition of the AQS request and screen

# CDPHE site code <-> AQS site_id. site_name is CDPHE's, which is what the
# manuscript and Figure S1 use; AQS's own name for the same station sometimes
# differs (ADCO is "Birch Street" in AQS).
COATTS_XWALK <- tibble::tribble(
  ~site,  ~site_name,         ~aqs_site_id,
  "ADCO", "Commerce City",    "08-001-0010",
  "CNCO", "Canon City",       "08-043-0004",
  "COCO", "Colorado Springs", "08-041-0017",
  "GPCO", "Grand Junction",   "08-077-0018",
  "JFCO", "Wheat Ridge",      "08-059-0015",   # AQS: "Peak Expeditionary School"
  "LSCO", "La Salle",         "08-123-0015",
  "POCO", "Pueblo",           "08-101-0017"
)
stopifnot(setequal(COATTS_XWALK$site, CFG$coatts_sites))

# ---- 1. the AQS-sourced sites ----------------------------------------------
aqs_sites <- COATTS_XWALK |> filter(!is.na(aqs_site_id))
log_msg("Colorado 24-h record: ", nrow(aqs_sites), " sites from AQS, ",
        sum(is.na(COATTS_XWALK$aqs_site_id)), " from the CDPHE packets")

co_states <- sort(unique(substr(aqs_sites$aqs_site_id, 1, 2)))
raw_aqs <- aqs_fetch_state_years(co_states, CFG$aqs_years,
                                 file.path(P$raw_aqs, "samples"), CFG$aqs_refresh)
if (!nrow(raw_aqs)) stop("AQS returned no formaldehyde for Colorado (state ",
                         paste(co_states, collapse = ", "), ").")

aqs_24h <- aqs_clean_samples(raw_aqs, keep_site_ids = aqs_sites$aqs_site_id) |>
  filter(duration_class == "24 h",
         sample_date_local >= CFG$date_range[1], sample_date_local <= CFG$date_range[2]) |>
  left_join(select(aqs_sites, site, site_name, aqs_site_id), by = c("site_id" = "aqs_site_id"))

missing_from_aqs <- setdiff(aqs_sites$site, aqs_24h$site)
if (length(missing_from_aqs)) {
  stop("These sites are in the crosswalk but returned no 24 h AQS formaldehyde: ",
       paste(missing_from_aqs, collapse = ", "),
       ".\n  Either the site_id is wrong or the site stopped reporting; do not ",
       "silently fall back to the packet, which would reintroduce mixed provenance.")
}
log_msg("  AQS: ", nrow(aqs_24h), " site-days at ", n_distinct(aqs_24h$site), " sites")

# aqs_qualifier_codes() lives in R/helpers_aqs.R, shared with step 06.

# ---- 2. discover CDPHE packets on the repository page -----------------------
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

# ---- 3. download (skips files already on disk unless coatts_refresh) --------
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

# ---- 4. parsers ------------------------------------------------------------
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

# ---- 5. parse all packets --------------------------------------------------
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

packet_days <- parsed |>
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
  )

# ---- 6. (the sample-by-sample cross-check against the packets was removed;
#          AQS is the source and the packets are not a second opinion on it)

# ---- 7. assemble: AQS for the six, the packet for Wheat Ridge --------------
# Detection limits and sampling temperature/pressure exist only in the packets,
# so they are carried across onto the AQS rows. The measurement is AQS's.
anc <- packet_days |> select(site, sample_date, dl_ugm3, temp_c, press_hpa)

from_aqs <- aqs_24h |>
  mutate(flags = aqs_qualifier_codes(qualifiers)) |>
  transmute(site, program = "COATTS", sample_date = sample_date_local,
            n_rows = n_poc, hcho_ugm3,
            non_detect = has_flag(flags, "ND"),
            below_mdl  = has_flag(flags, "MD"),
            qc_codes = "",                       # AQS publishes ambient rows only
            flags,
            source_file = "AQS sampleData/byState",
            source = "AQS",
            lat, lon, site_name) |>
  left_join(anc, by = c("site", "sample_date"))

packet_only <- COATTS_XWALK$site[is.na(COATTS_XWALK$aqs_site_id)]
from_packet <- packet_days |>
  filter(site %in% packet_only) |>
  mutate(source = "CDPHE packet") |>
  left_join(select(COATTS_XWALK, site, site_name), by = "site") |>
  left_join(parsed |> filter(!is.na(lat), !is.na(lon)) |> group_by(site) |>
              summarise(lat = median(lat), lon = median(lon), .groups = "drop"),
            by = "site")

# Coordinates for any packet-only site the packets do not geolocate.
site_coords_fallback <- tribble(
  ~site,  ~lat,       ~lon,
  "ADCO", 39.828100, -104.936470,
  "LSCO", 40.261400, -104.706450,
  "GPCO", 39.064289, -108.561550,
  "JFCO", 39.781069, -105.107621,
  "COCO", 38.848014, -104.828564,
  "CNCO", 38.469492, -105.208334,
  "POCO", 38.236232, -104.581380
)
from_packet <- from_packet |>
  left_join(rename(site_coords_fallback, lat_fb = lat, lon_fb = lon), by = "site") |>
  mutate(lat = coalesce(lat, lat_fb), lon = coalesce(lon, lon_fb)) |>
  select(-lat_fb, -lon_fb)

coatts <- bind_rows(from_aqs, from_packet) |>
  mutate(hcho_molec_cm3 = ugm3_to_molec_cm3(hcho_ugm3),
         hcho_ppb_local = ugm3_to_ppb(hcho_ugm3, temp_c, press_hpa),
         season = season_of(sample_date),
         year = year(sample_date)) |>
  select(site, program, sample_date, n_rows, hcho_ugm3, dl_ugm3, non_detect, below_mdl,
         qc_codes, flags, temp_c, press_hpa, source_file, source, site_name, lat, lon,
         hcho_molec_cm3, hcho_ppb_local, season, year) |>
  arrange(site, sample_date)

if (any(is.na(coatts$lat))) {
  stop("No coordinates for: ",
       paste(unique(coatts$site[is.na(coatts$lat)]), collapse = ", "),
       " - add them to site_coords_fallback.")
}

data.table::fwrite(coatts, file.path(P$processed, "coatts_hcho.csv"))

summary_tbl <- coatts |>
  group_by(program, source, site, site_name, year) |>
  summarise(sample_days = n(), with_value = sum(!is.na(hcho_ugm3)),
            first = min(sample_date), last = max(sample_date),
            median_ugm3 = round(median(hcho_ugm3, na.rm = TRUE), 2),
            .groups = "drop")
data.table::fwrite(summary_tbl, file.path(P$tables, "coatts_hcho_inventory.csv"))
print(summary_tbl, n = Inf)
log_msg("Wrote ", nrow(coatts), " site-days to ", file.path(P$processed, "coatts_hcho.csv"),
        " (", sum(coatts$source == "AQS"), " from AQS, ",
        sum(coatts$source == "CDPHE packet"), " from the CDPHE packets)")
