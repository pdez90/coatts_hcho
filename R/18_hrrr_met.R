# =============================================================================
# 18_hrrr_met.R - near-surface meteorology at every monitor, from NOAA HRRR
#
# Why: the number density behind H_eff needs the air temperature and pressure
# at the site during the sample. Until Sept 2026 the Colorado arm used the
# CDPHE packets' own sampling pressure (which is ~6 % below ambient - see
# R/helpers_met.R) and the 3 h and national arms used a single fixed 15 C for
# the whole country and both years. HRRR replaces both: 3 km, hourly, the same
# field for every arm, averaged over each sample's own window.
#
# What it downloads: from each hourly HRRR analysis file (wrfsfcf00) only the
# three GRIB2 messages needed, by byte range off the file's .idx - 2 m
# temperature, surface pressure and PBL height - plus the static surface
# geopotential height once, so the model terrain at each site is on record.
# The CONUS grid is 1059 x 1799 at 3 km; these are 2-D surface fields.
#
# Cost: the sample windows of the three arms span about 11,000 distinct UTC
# hours over 2023-08..2025-12 (62 % of the hours in that span - the 1-in-6 and
# 1-in-12 schedules leave the rest empty). Three messages an hour is roughly
# 40 GB transferred and a few hours wall clock; nothing is kept but the site
# points, so the cache on disk is a few MB. One day per cache file, so an
# interrupted run resumes.
#
# It runs more than once in run_all.R, as step 08 does: after step 01 it can
# only see the Colorado 24 h windows, after step 06 the 3 h windows, after
# step 11 the national ones. Cached days are skipped, so the repeats are cheap.
#
# Outputs: data/raw/hrrr/hrrr_points_<YYYYMMDD>.csv.gz   (cache, one per day)
#          data/processed/hrrr_site_hours.csv.gz         (site x UTC hour)
#          data/processed/hrrr_site_terrain.csv          (model terrain height)
#          output/tables/hrrr_coverage.csv               (what was and was not got)
# =============================================================================
source("R/00_config.R")
source("R/helpers_met.R")

for (.p in c("terra")) {
  if (!requireNamespace(.p, quietly = TRUE)) stop(.p, " is required by R/18_hrrr_met.R")
}

dir.create(P$raw_hrrr, recursive = TRUE, showWarnings = FALSE)

windows <- met_windows_all()
log_msg(nrow(windows), " sample windows from ",
        paste(sort(unique(windows$arm)), collapse = ", "))

sites <- windows |>
  group_by(met_site_id) |>
  summarise(lat = first(lat), lon = first(lon),
            arms = paste(sort(unique(arm)), collapse = "+"),
            sites = paste(sort(unique(site)), collapse = "+"), .groups = "drop")
log_msg(nrow(sites), " distinct monitor locations")

need <- met_expand_hours(windows) |>
  distinct(met_site_id, hour) |>
  mutate(t = as.POSIXct(hour * 3600, origin = "1970-01-01", tz = "UTC"),
         day = as.Date(t), utc_hour = as.integer(format(t, "%H")))
log_msg(nrow(need), " site-hours over ", n_distinct(need$hour), " distinct UTC hours, ",
        n_distinct(need$day), " days")

days <- sort(unique(need$day))
if (!is.na(CFG$hrrr_max_days)) {
  days <- head(days, CFG$hrrr_max_days)
  log_msg("TEST MODE: only ", length(days), " days (CFG$hrrr_max_days)")
}

# ---- the three fields, exactly as the .idx spells them ----------------------
# Confirmed against the NCEP inventory of hrrr.tHHz.wrfsfcf00.grib2:
#   HPBL surface analysis  Planetary Boundary Layer Height [m]
#   PRES surface analysis  Pressure [Pa]
#   TMP  2 m above ground  analysis  Temperature [K]
#   HGT  surface analysis  Geopotential Height [gpm]   (static; fetched once)
FIELDS <- tibble::tribble(
  ~name,       ~var,   ~level,
  "temp_c",    "TMP",  "2 m above ground",
  "press_hpa", "PRES", "surface",
  "pbl_m",     "HPBL", "surface")
TERRAIN <- tibble::tibble(name = "terrain_m", var = "HGT", level = "surface")

# Plausible ranges for a near-surface field anywhere in CONUS. A value outside
# these means the wrong GRIB record was read, which is a bug rather than
# weather - so it is caught on the first hour instead of after a 660-day run.
MET_RANGE <- list(temp_c = c(-90, 60), press_hpa = c(500, 1100),
                  pbl_m = c(0, 6000), terrain_m = c(-100, 4500))

to_units <- function(field, x) {
  f <- field[[1]]
  if (identical(f, "press_hpa")) return(x / 100)
  if (!identical(f, "temp_c")) return(x)
  # GDAL's GRIB driver converts temperature from K to C when its
  # GRIB_NORMALIZE_UNITS option is on, which is the default - so depending on
  # the build the message arrives in either unit, and subtracting 273.15
  # unconditionally gives about -250 C. Kelvin and Celsius cannot overlap for a
  # 2 m temperature, so the unit is read off the values rather than assumed.
  med <- stats::median(x, na.rm = TRUE)
  if (is.finite(med) && med > 150) x - 273.15 else x
}

met_implausible <- function(field, x) {
  rng <- MET_RANGE[[field[[1]]]]
  if (is.null(rng)) return(FALSE)
  med <- stats::median(x, na.rm = TRUE)
  !is.finite(med) || med < rng[1] || med > rng[2]
}

hrrr_url <- function(day, utc_hour) {
  sprintf("%shrrr.%s/conus/hrrr.t%02dz.%s.grib2",
          CFG$hrrr_base_url, format(day, "%Y%m%d"), utc_hour, CFG$hrrr_product)
}

par_formals <- names(formals(httr2::req_perform_parallel))
perform_parallel <- function(reqs, paths) {
  if (!length(reqs)) return(invisible(NULL))
  args <- list(reqs, paths = paths, on_error = "continue", progress = FALSE)
  if ("max_active" %in% par_formals) {
    args$max_active <- CFG$hrrr_n_parallel
  } else if ("pool" %in% par_formals) {
    args$pool <- curl::new_pool(total_con = CFG$hrrr_n_parallel,
                                host_con = CFG$hrrr_n_parallel)
  }
  try(do.call(httr2::req_perform_parallel, args), silent = TRUE)
  invisible(NULL)
}

# "3:145206:d=2024071518:TMP:2 m above ground:anl:" -> start and end bytes.
# The end of a record is the byte before the next record starts; the last
# record in the file has no end, which an open-ended Range header covers.
parse_idx <- function(path) {
  if (!file.exists(path) || file.size(path) < 50) return(NULL)
  ln <- readLines(path, warn = FALSE)
  ln <- ln[nzchar(ln)]
  if (!length(ln)) return(NULL)
  pp <- strsplit(ln, ":", fixed = TRUE)
  keep <- lengths(pp) >= 6
  pp <- pp[keep]
  if (!length(pp)) return(NULL)
  tibble::tibble(start = suppressWarnings(as.numeric(vapply(pp, `[`, "", 2L))),
                 var   = vapply(pp, `[`, "", 4L),
                 level = vapply(pp, `[`, "", 5L)) |>
    mutate(end = lead(start) - 1) |>
    filter(!is.na(start))
}

# Points, projected into the HRRR grid's own CRS. The CRS is the same in every
# file, so this is built once from the first message that reads.
pts_ll <- terra::vect(as.matrix(sites[, c("lon", "lat")]), type = "points",
                      crs = "EPSG:4326")
pts_proj <- NULL

extract_points <- function(grib_path, field) {
  r <- try(terra::rast(grib_path), silent = TRUE)
  if (inherits(r, "try-error")) return(NULL)
  if (is.null(pts_proj)) pts_proj <<- terra::project(pts_ll, terra::crs(r))
  v <- try(terra::extract(r[[1]], pts_proj, method = "bilinear", ID = FALSE),
           silent = TRUE)
  if (inherits(v, "try-error")) return(NULL)
  # Converted BEFORE the tibble: inside tibble() a later argument sees the
  # columns already built, so `to_units(field, ...)` with a column also called
  # `field` would be handed the whole column instead of the scalar.
  vals <- to_units(field, as.numeric(v[[1]]))
  if (met_implausible(field, vals)) {
    log_msg("  IMPLAUSIBLE ", field, " (median ",
            round(stats::median(vals, na.rm = TRUE), 2), ", expected ",
            paste(MET_RANGE[[field[[1]]]], collapse = " to "), ") from ",
            basename(grib_path), " - record not used")
    return(NULL)
  }
  tibble::tibble(met_site_id = sites$met_site_id, name = field, value = vals)
}

# ---- one day ----------------------------------------------------------------
fetch_day <- function(day, want_terrain) {
  hrs <- sort(unique(need$utc_hour[need$day == day]))
  td <- file.path(tempdir(), paste0("hrrr_", format(day, "%Y%m%d")))
  dir.create(td, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  urls <- vapply(hrs, function(h) hrrr_url(day, h), "")
  idx_paths <- file.path(td, sprintf("%02d.idx", hrs))
  perform_parallel(map(paste0(urls, ".idx"), public_request), idx_paths)

  jobs <- list()
  for (k in seq_along(hrs)) {
    idx <- parse_idx(idx_paths[k])
    if (is.null(idx)) { log_msg("  no .idx for ", basename(urls[k])); next }
    ff <- if (want_terrain && k == 1L) bind_rows(FIELDS, TERRAIN) else FIELDS
    sel <- inner_join(ff, idx, by = c("var", "level"))
    missing_f <- setdiff(ff$name, sel$name)
    if (length(missing_f)) log_msg("  ", basename(urls[k]), ": no record for ",
                                   paste(missing_f, collapse = ", "))
    if (!nrow(sel)) next
    for (j in seq_len(nrow(sel))) {
      jobs[[length(jobs) + 1L]] <- list(
        hour = hrs[k], name = sel$name[j], url = urls[k],
        range = if (is.na(sel$end[j])) sprintf("bytes=%.0f-", sel$start[j])
                else sprintf("bytes=%.0f-%.0f", sel$start[j], sel$end[j]),
        path = file.path(td, sprintf("%02d_%s.grib2", hrs[k], sel$name[j])))
    }
  }
  if (!length(jobs)) return(NULL)

  perform_parallel(map(jobs, ~ public_request(.x$url) |>
                                httr2::req_headers(Range = .x$range)),
                   vapply(jobs, function(j) j$path, ""))

  vals <- map(jobs, function(j) {
    v <- extract_points(j$path, j$name)
    if (is.null(v)) { log_msg("  unreadable: ", basename(j$path)); return(NULL) }
    mutate(v, hour = met_hour_key(as.POSIXct(paste0(day, " ", sprintf("%02d", j$hour),
                                                    ":00:00"), tz = "UTC")))
  }) |> list_rbind()
  if (!nrow(vals)) return(NULL)

  terrain <- vals |> filter(name == "terrain_m") |>
    distinct(met_site_id, terrain_m = value)
  out <- vals |>
    filter(name != "terrain_m") |>
    tidyr::pivot_wider(names_from = name, values_from = value) |>
    arrange(hour, met_site_id)
  list(points = out, terrain = terrain)
}

# ---- the day loop -----------------------------------------------------------
terr_path <- file.path(P$processed, "hrrr_site_terrain.csv")
want_terrain <- !file.exists(terr_path) || isTRUE(CFG$hrrr_refresh)
n_new <- 0L
# A day's cache holds the sites and hours that were needed when it was written.
# run_all.R runs this step once per arm (Colorado 24 h, then 3 h, then national),
# so a day cached for an earlier arm can lack the later arms' sites or hours. It
# is reused only if it covers every site-hour needed now; otherwise the day is
# fetched again for all current sites.
day_complete <- function(f, d) {
  have <- read_tbl(f, colClasses = list(character = "met_site_id")) |>
    distinct(met_site_id, hour)
  want <- need |> filter(.data$day == .env$d) |> distinct(met_site_id, hour)
  nrow(anti_join(want, have, by = c("met_site_id", "hour"))) == 0L
}
for (day in days) {
  day <- as.Date(day, origin = "1970-01-01")
  f <- file.path(P$raw_hrrr, sprintf("hrrr_points_%s.csv.gz", format(day, "%Y%m%d")))
  if (file.exists(f) && !isTRUE(CFG$hrrr_refresh) && day_complete(f, day)) next
  res <- fetch_day(day, want_terrain)
  if (is.null(res)) { log_msg("  ", format(day), ": nothing retrieved"); next }
  tmp <- paste0(f, ".part")
  data.table::fwrite(res$points, tmp)
  file.rename(tmp, f)
  if (want_terrain && nrow(res$terrain)) {
    data.table::fwrite(left_join(sites, res$terrain, by = "met_site_id"), terr_path)
    want_terrain <- FALSE
    log_msg("  model terrain height written to ", terr_path)
  }
  n_new <- n_new + 1L
  if (n_new %% 10L == 0L) log_msg("  ", n_new, " days fetched (latest ", format(day), ")")
}
log_msg(n_new, " new days fetched; ", length(days) - n_new, " already cached")

# ---- assemble ---------------------------------------------------------------
cached <- list.files(P$raw_hrrr, pattern = "^hrrr_points_\\d{8}\\.csv\\.gz$", full.names = TRUE)
if (!length(cached)) stop("No HRRR day caches in ", P$raw_hrrr)
met <- map(cached, ~ read_tbl(.x, colClasses = list(character = "met_site_id"))) |>
  list_rbind() |>
  distinct(met_site_id, hour, .keep_all = TRUE) |>
  arrange(met_site_id, hour)
data.table::fwrite(met, met_cache_path())
log_msg("Wrote ", nrow(met), " site-hours to ", met_cache_path())

# ---- coverage report --------------------------------------------------------
# Only the days this run was asked for: in a full run that is every day, and
# under CFG$hrrr_max_days it keeps the percentage meaningful instead of
# dividing the handful of test hours by the whole two-year need.
cov <- need |>
  filter(day %in% days) |>
  left_join(mutate(met, got = TRUE) |> select(met_site_id, hour, got),
            by = c("met_site_id", "hour")) |>
  mutate(got = coalesce(got, FALSE)) |>
  group_by(day) |>
  summarise(site_hours = n(), got = sum(got), .groups = "drop") |>
  mutate(pct = round(100 * got / site_hours, 1))
data.table::fwrite(cov, file.path(P$tables, "hrrr_coverage.csv"))
log_msg("Coverage: ", sum(cov$got), " of ", sum(cov$site_hours), " site-hours (",
        round(100 * sum(cov$got) / sum(cov$site_hours), 2), " %); ",
        sum(cov$pct < 100), " days incomplete")
# One last guard before steps 04, 07 and 13 are allowed to consume any of this.
for (.f in c("temp_c", "press_hpa", "pbl_m")) {
  if (!.f %in% names(met)) stop("R/18 produced no ", .f, " column")
  if (met_implausible(.f, met[[.f]])) {
    stop(.f, ": median ", round(stats::median(met[[.f]], na.rm = TRUE), 2),
         " is outside ", paste(MET_RANGE[[.f]], collapse = " to "),
         " - the wrong GRIB record is being read; do not use this cache.")
  }
  log_msg("  ", .f, ": median ", round(stats::median(met[[.f]], na.rm = TRUE), 1),
          " (", round(min(met[[.f]], na.rm = TRUE), 1), " to ",
          round(max(met[[.f]], na.rm = TRUE), 1), ")")
}
# Numbers the manuscript quotes about this step, so that check_est.js can trace
# them to a table rather than to a line in a run log.
data.table::fwrite(
  tibble(key = c("hrrr_temp_min", "hrrr_temp_max", "hrrr_site_hours", "hrrr_sites", "hrrr_hours"),
         value = c(sprintf("%.1f", min(met$temp_c, na.rm = TRUE)),
                   sprintf("%.1f", max(met$temp_c, na.rm = TRUE)),
                   format(nrow(met), scientific = FALSE),
                   format(n_distinct(met$met_site_id), scientific = FALSE),
                   format(n_distinct(met$hour), scientific = FALSE)),
         source = "R/18_hrrr_met.R"),
  file.path(P$tables, "manuscript_numbers_18.csv"))

mw <- met_window_means(windows, met)
log_msg("Windows fully usable: ", sum(!is.na(mw$temp_c_hrrr)), " of ", nrow(mw))
log_msg("HRRR meteorology done.")
