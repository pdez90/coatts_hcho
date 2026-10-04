# =============================================================================
# 24_app_data.R - data for the Shiny explorer in app/, and its manifest
#
# Writes app/appdata/app_data.rds, which the app reads, holding
#   sites   one row per monitor: AQS ID, CDPHE code (Colorado), name, state,
#           position, networks, and the day-to-day correlation the map colours by
#   tempo   the released matched dataset (dataset/matched_primary.csv.gz, step
#           23): surface HCHO, the TEMPO column, HRRR and smoke flags, every arm
#           and lag of the primary screening
#   screen  the other TEMPO screening variants of the released data (pixel
#           block, cloud-fraction limit, Colorado midday scans), from
#           dataset/matched_all_variants.csv.gz
#   sens_nat agreement across configurations at every site-duration of the
#           national comparison, from app/R/sensitivity.R (the app's own code)
#   toxics  every air toxic in the CDPHE COATTS and COOPs annual packets that
#           step 01 downloads (carbonyls, VOCs, PAHs, metals; SNMOC and methane at
#           the ozone-precursor sites), screened as step 01 screens formaldehyde
#   meta    provenance: checksums of the dataset and of every packet
# and, when rsconnect is installed, app/manifest.json for Posit Connect Cloud.
#
# Checks (the step stops if one fails):
#   * app/R/stats.R, which the app uses, reproduces n, r, anomaly pairs and the
#     anomaly r of every site in output/tables/national_stats_by_site.csv;
#   * the CDPHE code -> AQS ID crosswalk matches R/01_coatts.R and
#     R/06_threeh_samples.R;
#   * the primary rows of matched_all_variants.csv.gz are matched_primary.csv.gz;
#   * ntile3() in app/R/sensitivity.R equals dplyr::ntile(), and the unchanged
#     configuration of sens_nat reproduces national_stats_by_site.csv.
# Packet formaldehyde is compared with the AQS values the paper uses and the
# agreement is logged (the packets are not used for any result in the paper).
#
# The .rds holds no time stamp, so an unchanged input gives an identical file.
# Inputs : dataset/matched_primary.csv.gz and matched_all_variants.csv.gz
#          (step 23), data/raw/coatts/*.xlsx
#          (step 01), output/tables/national_stats_by_site.csv (step 13)
# Outputs: app/appdata/app_data.rds, app/manifest.json
# =============================================================================
source("R/00_config.R")
source("R/helpers_basemap.R")   # Census boundaries, cached in data/raw/basemap
source("app/R/stats.R")
source("app/R/sensitivity.R")   # agreement across configurations, as the app computes it

APP <- "app"
OUT <- file.path(APP, "appdata")   # not "data/": .gitignore excludes every data/ folder
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
check <- function(ok, ...) if (!isTRUE(all(ok))) stop(...)

# Packages the app needs; installed here so that writeManifest() can record them.
APP_PKGS <- c("shiny", "bslib", "leaflet", "plotly", "DT", "rsconnect")
miss <- APP_PKGS[!vapply(APP_PKGS, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) {
  log_msg("Installing packages for the app: ", paste(miss, collapse = ", "))
  install.packages(miss, repos = "https://cloud.r-project.org")
}

# CDPHE site code -> AQS site ID, as in R/01_coatts.R and R/06_threeh_samples.R
# (and R/23_export_dataset.R); checked against both files.
XWALK <- tibble::tribble(
  ~site_code, ~site_id,      ~program,
  "ADCO",     "08-001-0010", "COATTS (24 h)",
  "CNCO",     "08-043-0004", "COATTS (24 h)",
  "COCO",     "08-041-0017", "COATTS (24 h)",
  "GPCO",     "08-077-0018", "COATTS (24 h)",
  "JFCO",     "08-059-0015", "COATTS (24 h)",
  "LSCO",     "08-123-0015", "COATTS (24 h)",
  "POCO",     "08-101-0017", "COATTS (24 h)",
  "CHCO",     "08-035-0004", "COOPs ozone precursors (3 h)",
  "PVCO",     "08-123-0008", "COOPs ozone precursors (3 h)"
)
src <- paste(c(readLines("R/01_coatts.R"), readLines("R/06_threeh_samples.R")), collapse = "\n")
for (i in seq_len(nrow(XWALK))) {
  check(grepl(sprintf('"%s",[^\n]*"%s"', XWALK$site_code[i], XWALK$site_id[i]), src, perl = TRUE),
        "Crosswalk ", XWALK$site_code[i], " = ", XWALK$site_id[i], " is not the one in steps 01/06")
}

# ---- 1. matched surface HCHO x TEMPO -----------------------------------------
ds_path <- file.path("dataset", "matched_primary.csv.gz")
if (!file.exists(ds_path)) stop("Missing ", ds_path, " - run step 23 first.")
mp <- read_tbl(ds_path, colClasses = list(character = c("site_id", "site_code", "site_name", "state",
                                                        "networks", "start_utc", "sample_date_local",
                                                        "smoke_class", "arm")))
tempo <- mp |>
  transmute(arm, site_id, duration_h = as.integer(duration_h), lag_h = as.integer(lag_h),
            start_utc = as.POSIXct(start_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
            date = as.Date(sample_date_local), season = as.character(season_of(date)),
            hcho = hcho_ugm3, column = tempo_vc / 1e15,
            n_scans = as.integer(n_scans), n_valid = as.integer(n_valid_scans),
            usable = as.logical(usable), h_eff_km = h_eff_km,
            tempo_pbl_km = tempo_pbl_m / 1000, hrrr_pbl_km = pbl_m_hrrr / 1000,
            temp_c = temp_c_hrrr,
            smoke = if_else(is.na(smoke_class) | smoke_class == "", NA_character_, smoke_class))
check(!is.na(tempo$start_utc) & !is.na(tempo$date), "Unparsed dates in ", ds_path)
check(!is.na(tempo$usable), "usable is missing in ", ds_path)
log_msg("Matched data: ", nrow(tempo), " rows, ", n_distinct(tempo$site_id), " sites, arms ",
        paste(sort(unique(tempo$arm)), collapse = ", "))

# The app's statistics must be the paper's.
ref <- read_tbl(file.path(P$tables, "national_stats_by_site.csv"), colClasses = list(character = "site"))
nat0 <- filter(tempo, arm == "national", lag_h == 0L, usable)
chk <- map2(ref$site, ref$duration_class, function(s, dc) {
  d <- nat0[nat0$site_id == s & nat0$duration_h == as.integer(sub(" h$", "", dc)), ]
  st <- pair_stats(d$date, d$hcho, d$column)
  tibble(site = s, duration_class = dc, n = st$n, r = st$r, n_anom = st$n_anom, r_anom = st$r_anom)
}) |> list_rbind() |>
  inner_join(select(ref, site, duration_class, n_ref = n, r_ref = pearson_r,
                    n_anom_ref = anom_n, r_anom_ref = anom_pearson_r),
             by = c("site", "duration_class"))
bad <- with(chk, n != n_ref | n_anom != n_anom_ref | abs(r - r_ref) > 1e-6 | abs(r_anom - r_anom_ref) > 1e-6)
check(nrow(chk) == nrow(ref) & !is.na(bad) & !bad,
      sum(bad | is.na(bad)), " of ", nrow(ref), " site-durations differ from national_stats_by_site.csv")
log_msg("app/R/stats.R reproduces all ", nrow(chk), " site-duration correlations of step 13")

# ---- 1b. screening variants -----------------------------------------------------------
# The app compares the primary TEMPO screening with the other pixel blocks and
# cloud-fraction limits of the released data (and the Colorado midday-scan variant).
av_path <- file.path("dataset", "matched_all_variants.csv.gz")
if (!file.exists(av_path)) stop("Missing ", av_path, " - run step 23 first.")
check(n_distinct(mp$max_ecf) == 1 & n_distinct(mp$block) == 1 & n_distinct(mp$scan_window) == 1,
      ds_path, " holds more than one screening")
check(abs(as.numeric(mp$max_ecf[1]) - PRIMARY_SCREEN$max_ecf) < 1e-9 & mp$block[1] == PRIMARY_SCREEN$block &
        mp$scan_window[1] == PRIMARY_SCREEN$scan_window,
      "PRIMARY_SCREEN in app/R/sensitivity.R is not the screening of ", ds_path)
av <- read_tbl(av_path, colClasses = list(character = c("site_id", "start_utc", "sample_date_local", "smoke_class",
                                                        "arm", "block", "scan_window"))) |>
  transmute(arm, site_id, duration_h = as.integer(duration_h), lag_h = as.integer(lag_h),
            start_utc = as.POSIXct(start_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
            date = as.Date(sample_date_local), season = as.character(season_of(date)),
            hcho = hcho_ugm3, column = tempo_vc / 1e15, usable = as.logical(usable),
            smoke = if_else(is.na(smoke_class) | smoke_class == "", NA_character_, smoke_class),
            max_ecf = as.numeric(max_ecf), block, scan_window_raw = scan_window,
            scan_window = if_else(grepl("^midday", scan_window), "midday", scan_window))
check(av$scan_window %in% c("sampling window", "midday"), "Unexpected scan_window in ", av_path, ": ",
      paste(unique(av$scan_window_raw[!av$scan_window %in% c("sampling window", "midday")]), collapse = ", "))
is_prim <- abs(av$max_ecf - PRIMARY_SCREEN$max_ecf) < 1e-9 & av$block == PRIMARY_SCREEN$block &
  av$scan_window == PRIMARY_SCREEN$scan_window
vkey <- function(d) paste(d$arm, d$site_id, d$duration_h, d$lag_h, format(d$start_utc, "%Y-%m-%dT%H:%M", tz = "UTC"))
check(!anyDuplicated(vkey(tempo)), "Duplicate samples in ", ds_path)
pv <- av[is_prim, ]; m <- match(vkey(tempo), vkey(pv))
check(nrow(pv) == nrow(tempo) & !is.na(m), "The primary rows of ", av_path, " are not the samples of ", ds_path)
check(identical(pv$usable[m], tempo$usable) & isTRUE(all.equal(pv$column[m], tempo$column)) &
        isTRUE(all.equal(pv$hcho[m], tempo$hcho)), "The primary rows of ", av_path, " differ from ", ds_path)
screen <- as.data.frame(av[!is_prim, c("arm", "site_id", "duration_h", "lag_h", "date", "season", "smoke",
                                       "hcho", "column", "usable", "max_ecf", "block", "scan_window")])
log_msg("Screening variants: ", nrow(screen), " rows besides the primary (",
        paste(sort(unique(sprintf("%s ecf %.1f %s", screen$block, screen$max_ecf, screen$scan_window))), collapse = "; "),
        "); the primary rows of ", basename(av_path), " equal ", basename(ds_path))

# ---- 1c. agreement across configurations, every national site --------------------------
for (x in list(nat0$n_valid, nat0$hrrr_pbl_km, c(3, 1, NA, 2, 2, 5, 1), c(2, 1), numeric()))
  check(identical(ntile3(x), as.integer(dplyr::ntile(x, 3L))), "ntile3() in app/R/sensitivity.R differs from dplyr::ntile()")
nat_rows <- as.data.frame(tempo[tempo$arm == "national", ])
nat_scr  <- screen[screen$arm == "national", ]
sens_nat <- map2(ref$site, ref$duration_class, function(s, dc) {
  dur <- as.integer(sub(" h$", "", dc))
  cbind(data.frame(site_id = s, duration_h = dur, stringsAsFactors = FALSE),
        sensitivity_site(nat_rows[nat_rows$site_id == s, ], "national", dur, 0L,
                         screen = nat_scr[nat_scr$site_id == s, ], with_duration = FALSE))
}) |> list_rbind() |> as.data.frame()
cc <- merge(sens_nat[sens_nat$key == "current", ],
            transform(chk, site_id = site, duration_h = as.integer(sub(" h$", "", duration_class))),
            by = c("site_id", "duration_h"))
ok <- with(cc, n.x == n_ref & n_anom.x == n_anom_ref & abs(r.x - r_ref) < 1e-6 & abs(r_anom.x - r_anom_ref) < 1e-6)
check(nrow(cc) == nrow(chk) & !is.na(ok) & ok,
      "The unchanged configuration of sens_nat does not reproduce national_stats_by_site.csv")
log_msg("Agreement across configurations: ", nrow(sens_nat), " rows for ", nrow(chk),
        " national site-durations; the unchanged configuration reproduces the site table")
sens_summary <- sens_nat |>
  group_by(duration_h, dim, key, ord) |>
  summarise(sites = sum(n_anom >= MIN_REPORT & !is.na(r_anom)),
            median_r = round(median(r[n >= MIN_REPORT], na.rm = TRUE), 2),
            median_r_anom = round(median(r_anom[n_anom >= MIN_REPORT], na.rm = TRUE), 2), .groups = "drop") |>
  arrange(desc(duration_h), match(dim, DIM_ORDER), ord) |>
  mutate(dim = substr(dim, 1, 40)) |> select(-ord)
log_msg("Median site correlations by configuration (sites with >= ", MIN_REPORT, " anomaly pairs):")
print(as.data.frame(sens_summary), right = FALSE, row.names = FALSE)

# ---- 2. sites ---------------------------------------------------------------------
first_nonempty <- function(x) { x <- x[!is.na(x) & nzchar(x)]; if (length(x)) x[1] else NA_character_ }
sites <- mp |>
  group_by(site_id) |>
  summarise(aqs_name = first_nonempty(site_name[arm == "national"]),
            cdphe_name = first_nonempty(site_name[arm != "national"]),
            state = first_nonempty(state), lat = as.numeric(lat[1]), lon = as.numeric(lon[1]),
            networks = first_nonempty(networks[arm == "national"]),
            arms = paste(sort(unique(arm)), collapse = ";"),
            durations = paste(sort(unique(as.integer(duration_h)), decreasing = TRUE), collapse = ";"),
            .groups = "drop") |>
  left_join(XWALK, by = "site_id") |>
  mutate(name = coalesce(cdphe_name, aqs_name, paste("AQS site", site_id)),
         colorado_detail = !is.na(site_code))

# The map colours each site by the day-to-day correlation of its longest-duration
# record in the national comparison (the Colorado analysis for Wheat Ridge, which
# the national comparison does not include), at lag 0 with the primary screening.
map_stat <- map(sites$site_id, function(s) {
  d <- filter(tempo, site_id == s, lag_h == 0L, usable)
  arm_use <- if (any(d$arm == "national")) "national" else d$arm[1]
  d <- d[d$arm == arm_use, ]
  if (!nrow(d)) return(tibble(map_arm = arm_use, map_duration = NA_integer_, map_n = 0L,
                              map_r = NA_real_, map_n_anom = 0L, map_r_anom = NA_real_))
  dur <- max(d$duration_h); d <- d[d$duration_h == dur, ]
  st <- pair_stats(d$date, d$hcho, d$column)
  tibble(map_arm = arm_use, map_duration = dur, map_n = st$n, map_r = st$r,
         map_n_anom = st$n_anom, map_r_anom = st$r_anom)
}) |> list_rbind()
sites <- bind_cols(sites, map_stat) |> arrange(desc(colorado_detail), state, name)

# ---- 3. air toxics from the CDPHE packets --------------------------------------------
KNOWN_UNIT <- "(ug|ng|\u00b5g)/m(\u00b3|3)|ppbv|ppbC|ppmC|ppb|ppm"
norm_unit  <- function(u) str_replace_all(u, c("\u00b3" = "3", "\u00b5" = "u"))
class_of   <- function(sheet) {
  x <- str_remove(sheet, regex("(_data|\\s*Field Samples)$", ignore_case = TRUE))
  dplyr::recode(x, SVOCs = "PAHs")
}

read_aqdx_sheet <- function(path, sheet, nulls) {
  d <- readxl::read_excel(path, sheet = sheet, col_types = "text")
  need <- c("datetime", "duration", "parameter_name", "parameter_value", "unit_name", "qc_code", "qualifier_codes")
  if (!all(need %in% names(d))) {
    log_msg("  ", basename(path), " [", sheet, "]: unexpected columns - skipped"); return(NULL)
  }
  if (!"dl" %in% names(d)) d$dl <- NA_character_
  d <- filter(d, !is.na(parameter_name), !parameter_name %in% c("Temperature", "Pressure"))
  d <- drop_qc_rows(d, qc = qc_code, flags = qualifier_codes,
                    file = paste0(basename(path), " [", sheet, "]"), null_codes = nulls)
  tibble(dt = excel_or_text_datetime(d$datetime),
         duration_h = suppressWarnings(as.numeric(d$duration)) / 3600,
         parameter = str_squish(d$parameter_name),
         value = suppressWarnings(as.numeric(d$parameter_value)),
         unit = norm_unit(d$unit_name),
         dl = suppressWarnings(as.numeric(d$dl)),
         flags = coalesce(d$qualifier_codes, ""))
}

read_wide_sheet <- function(path, sheet, nulls, duration_h) {
  d <- readxl::read_excel(path, sheet = sheet, col_types = "text")
  tcol <- grep("^Datetime", names(d), value = TRUE)[1]
  if (is.na(tcol)) { log_msg("  ", basename(path), " [", sheet, "]: no Datetime column - skipped"); return(NULL) }
  d <- d[!is.na(d[[tcol]]) & nzchar(d[[tcol]]), , drop = FALSE]
  vcols <- grep(paste0("_(", KNOWN_UNIT, ")(_Air)?$"), names(d), value = TRUE)
  if (!nrow(d) || !length(vcols)) return(NULL)
  long <- map(vcols, function(v) {
    pu    <- str_remove(v, "_Air$")
    unit  <- str_extract(pu, "[^_]+$")
    param <- str_remove(pu, "_[^_]+$")
    fcol  <- paste0(param, "_flags")
    tibble(dt_raw = d[[tcol]], parameter = str_squish(param), unit = norm_unit(unit),
           value_raw = d[[v]], qc_code = NA_character_,
           flags = if (fcol %in% names(d)) coalesce(d[[fcol]], "") else "")
  }) |> list_rbind()
  long <- drop_qc_rows(long, qc = qc_code, flags = flags,
                       file = paste0(basename(path), " [", sheet, "]"), null_codes = nulls)
  tibble(dt = excel_or_text_datetime(long$dt_raw), duration_h = duration_h,
         parameter = long$parameter, value = suppressWarnings(as.numeric(long$value_raw)),
         unit = long$unit, dl = NA_real_, flags = long$flags)
}

packets <- list.files(P$raw_coatts, pattern = "\\.xlsx$", full.names = TRUE)
code_pat <- paste(XWALK$site_code, collapse = "|")
toxics_raw <- map(packets, function(path) {
  code <- str_extract(basename(path), code_pat)
  if (is.na(code)) return(NULL)
  sh    <- readxl::excel_sheets(path)
  nulls <- null_qualifiers_of(path)
  aqdx  <- any(str_detect(sh, "_data$"))
  use_sh <- if (aqdx) sh[str_detect(sh, "_data$")] else sh[str_detect(sh, regex("Field Samples$", ignore_case = TRUE))]
  wide_dur <- if (code %in% CFG$ozone_precursor_sites) 3 else 24   # COOPs packets hold 3-h samples
  map(use_sh, function(s) {
    res <- tryCatch(if (aqdx) read_aqdx_sheet(path, s, nulls) else read_wide_sheet(path, s, nulls, wide_dur),
                    error = function(e) { warning(basename(path), " [", s, "]: ", conditionMessage(e)); NULL })
    if (is.null(res) || !nrow(res)) return(NULL)
    mutate(res, site_code = code, class = class_of(s), source_file = basename(path))
  }) |> list_rbind()
}) |> list_rbind()
check(!is.null(toxics_raw) && nrow(toxics_raw) > 0, "No air-toxics rows parsed from ", P$raw_coatts)

n_bad_dt <- sum(is.na(toxics_raw$dt))
if (n_bad_dt) log_msg("  ", n_bad_dt, " packet rows without a parseable date dropped")
toxics <- toxics_raw |>
  filter(!is.na(dt)) |>
  mutate(sample_date = as.Date(dt),
         duration_h = coalesce(duration_h, if_else(site_code %in% CFG$ozone_precursor_sites, 3, 24)),
         # the COOPs volatile organics are SNMOC (ppbC), reported as "VOCs" in 2024
         class = if_else(class == "VOCs" & unit == "ppbC", "SNMOC", class),
         nondetect = has_flag(flags, "ND")) |>
  filter(sample_date >= CFG$date_range[1], sample_date <= CFG$date_range[2]) |>
  group_by(site_code, class, parameter, unit, duration_h, sample_date) |>
  summarise(value = if (all(is.na(value))) NA_real_ else mean(value, na.rm = TRUE),
            dl = if (all(is.na(dl))) NA_real_ else max(dl, na.rm = TRUE),
            nondetect = all(nondetect),
            flags = paste(sort(unique(unlist(str_split(str_squish(paste(flags, collapse = " ")), " ")))), collapse = " "),
            n_records = n(), source_file = paste(sort(unique(source_file)), collapse = ";"),
            .groups = "drop") |>
  left_join(select(XWALK, site_code, site_id), by = "site_code") |>
  mutate(season = as.character(season_of(sample_date))) |>
  arrange(site_code, class, parameter, sample_date)
toxics$flags[toxics$flags == ""] <- NA_character_

# A parameter reported in two units (e.g. a change between packet years) would mix
# incomparable values in one series; such parameters carry their unit in the name.
units_per <- count(distinct(toxics, class, parameter, unit), class, parameter, name = "n_units")
toxics <- toxics |>
  left_join(units_per, by = c("class", "parameter")) |>
  mutate(parameter = if_else(n_units > 1, paste0(parameter, " (", unit, ")"), parameter)) |>
  select(-n_units)
if (any(units_per$n_units > 1))
  log_msg("  reported in more than one unit, kept as separate series: ",
          paste(units_per$parameter[units_per$n_units > 1], collapse = ", "))
log_msg("Air toxics: ", nrow(toxics), " site-sample values; ", n_distinct(toxics$parameter), " parameters; ",
        paste(sprintf("%s %d", names(table(toxics$class)), as.integer(table(toxics$class))), collapse = ", "))
print(toxics |> count(site_code, class) |> tidyr::pivot_wider(names_from = class, values_from = n), n = Inf)

# Packet formaldehyde against the AQS values the paper uses (24 h sites)
pk <- filter(toxics, class == "Carbonyls", parameter == "Formaldehyde", duration_h == 24, !is.na(value))
aq <- tempo |> filter(arm == "colorado_24h", lag_h == 0L) |> distinct(site_id, date, hcho)
cmp <- inner_join(pk, aq, by = c("site_id", "sample_date" = "date"))
if (nrow(cmp)) {
  rel <- abs(cmp$value - cmp$hcho) / pmax(cmp$hcho, 1e-9)
  log_msg(sprintf("Packet vs AQS formaldehyde (24 h): %d site-days, median |difference| %.3f ug/m3, %.0f%% within 2%%",
                  nrow(cmp), median(abs(cmp$value - cmp$hcho)), 100 * mean(rel <= 0.02)))
}

sites <- sites |> mutate(has_toxics = site_id %in% toxics$site_id)

# ---- 3b. map background --------------------------------------------------------------
# CARTO's raster tiles now need an API key, so the app draws its own background:
# Census state outlines (and Colorado counties), simplified, as longitude/latitude
# vectors with NA between rings, which leaflet draws without the sf package.
rings_of <- function(g, tol) {
  if (is.null(g) || !nrow(g)) return(NULL)
  old <- sf::sf_use_s2(); suppressMessages(sf::sf_use_s2(FALSE)); on.exit(suppressMessages(sf::sf_use_s2(old)))
  geom <- suppressWarnings(sf::st_simplify(sf::st_geometry(sf::st_transform(g, 4326)),
                                           dTolerance = tol, preserveTopology = TRUE))
  cc <- sf::st_coordinates(sf::st_cast(geom, "MULTIPOLYGON"))
  ring <- paste(cc[, "L3"], cc[, "L2"], cc[, "L1"])
  parts <- split(seq_len(nrow(cc)), factor(ring, levels = unique(ring)))
  data.frame(lng = unlist(lapply(parts, function(i) c(round(cc[i, "X"], 4), NA)), use.names = FALSE),
             lat = unlist(lapply(parts, function(i) c(round(cc[i, "Y"], 4), NA)), use.names = FALSE))
}
geo <- list(states = NULL, co_counties = NULL)
if (have_sf()) {
  geo$states <- rings_of(us_conus_states(), tol = 0.01)
  cty <- cb_try("county", "500k")
  if (!is.null(cty)) geo$co_counties <- rings_of(cty[cty$STATEFP == "08", ], tol = 0.005)
}
if (is.null(geo$states)) log_msg("  no state outlines (sf or the Census files unavailable): the map will rely on tiles")
log_msg("Map background: ", sum(is.na(geo$states$lng)), " state rings, ",
        sum(is.na(geo$co_counties$lng)), " Colorado county rings")

# ---- 4. write -----------------------------------------------------------------------
md5 <- function(f) unname(tools::md5sum(f))
meta <- list(
  dataset = list(file = ds_path, md5 = md5(ds_path)),
  variants = list(file = av_path, md5 = md5(av_path)),
  packets = tibble(file = basename(packets), md5 = vapply(packets, md5, character(1), USE.NAMES = FALSE)),
  date_range = format(CFG$date_range),
  screening = sprintf("effective cloud fraction <= %.1f, 3 x 3 block, scans in the sampling window",
                      CFG$qc_max_cloud_fraction),
  repo = "https://github.com/pdez90/coatts_hcho"
)
tempo <- as.data.frame(tempo); toxics <- as.data.frame(toxics); sites <- as.data.frame(sites)
saveRDS(list(sites = sites, tempo = tempo, screen = screen, sens_nat = sens_nat, toxics = toxics,
             meta = meta, geo = geo),
        file.path(OUT, "app_data.rds"), compress = "xz")
log_msg("Wrote ", file.path(OUT, "app_data.rds"), " (", round(file.size(file.path(OUT, "app_data.rds")) / 1e6, 1),
        " MB): ", nrow(sites), " sites, ", nrow(tempo), " matched rows, ", nrow(screen), " variant rows, ",
        nrow(sens_nat), " configuration rows, ", nrow(toxics), " air-toxics values")

# manifest.json for Posit Connect Cloud, which installs the packages it lists
if (requireNamespace("rsconnect", quietly = TRUE)) {
  rsconnect::writeManifest(appDir = APP, appPrimaryDoc = "app.R")
  log_msg("Wrote ", file.path(APP, "manifest.json"))
} else {
  log_msg("rsconnect is not installed, so app/manifest.json was not written")
}
