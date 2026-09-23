# =============================================================================
# 08_smoke_hms.R - NOAA Hazard Mapping System (HMS) smoke flags for each sample
#
# Downloads the daily HMS smoke polygon shapefiles (analyst-drawn from GOES
# imagery; Density = Light / Medium / Heavy; Start/End in UTC, "YYYYDDD HHMM"),
# finds the polygons covering each site, and flags a sample as smoke-affected
# when a covering polygon's Start-End overlaps the sampling window:
#   24-h arm : 00-24 MST on the sample date (HMS files for that UTC day and the next)
#   3-h arm  : the 3-h window, for each stamp convention
# Windows are widened by hms_time_pad_hours on each side, because HMS times are
# analyst imagery periods with gaps (see R/00_config.R). smoke_any_day ignores
# polygon times altogether (any polygon over the site on the window's HMS days).
# A day whose HMS file is unavailable gets hms_available = FALSE and NA flags -
# a missing file is not treated as "no smoke".
# Outputs: data/processed/smoke_flags.csv, output/tables/smoke_inventory.csv
# =============================================================================
source("R/00_config.R")
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf", repos = "https://cloud.r-project.org")
suppressMessages(sf::sf_use_s2(FALSE))   # planar point-in-polygon; avoids s2 errors on invalid HMS rings
dir.create(P$raw_hms, recursive = TRUE, showWarnings = FALSE)

# ---- 1. sampling windows from both arms -----------------------------------------
day_start_utc <- function(d) as.POSIXct(paste(d, "00:00:00"), tz = "UTC") - CFG$utc_offset_hours * 3600

co <- read_tbl(arm_paths("coatts")$samples) |>
  mutate(sample_date = as.Date(sample_date)) |>
  filter(!is.na(hcho_ugm3), !is.na(lat))
windows <- co |>
  distinct(site, lat, lon, sample_date) |>
  mutate(arm = "coatts", convention = NA_character_, stamp_local = NA_character_,
         win_start_utc = day_start_utc(sample_date), win_end_utc = win_start_utc + 86400)

th_path <- arm_paths("threeh")$samples
if (isTRUE(CFG$run_three_hour_arm) && file.exists(th_path)) {
  th <- read_tbl(th_path, colClasses = list(character = "stamp_local")) |>
    filter(!is.na(hcho_ugm3), !is.na(lat)) |>
    mutate(sample_date = as.Date(sample_date),
           stamp = parse_date_time(stamp_local, orders = c("Ymd HM", "Ymd HMS"), tz = "UTC"))
  # the sampling window itself: [stamp - duration, stamp), the stamp being the
  # end of sampling (confirmed against AQS start times in step 10)
  w3 <- th |>
    distinct(site, lat, lon, sample_date, stamp_local, stamp) |>
    mutate(arm = "threeh", convention = "sampling window",
           win_start_local = stamp - CFG$threeh_duration_s,
           win_start_utc = win_start_local - CFG$utc_offset_hours * 3600,
           win_end_utc = win_start_utc + CFG$threeh_duration_s) |>
    select(-stamp, -win_start_local)
  windows <- bind_rows(windows, w3)
}
# The national arm. Its windows come from AQS, which records start_utc and
# end_utc directly, so unlike the Colorado arms it needs no CFG$utc_offset_hours
# assumption - and must not use one, because 123 sites span four time zones and
# a single MST offset would mis-place every window outside Colorado by hours.
#
# This file does not exist until step 11 has run, so step 08 is scheduled twice:
# once before the Colorado analyses, which need only their own flags, and again
# after step 11 so the national arm is included before step 13 reads them.
nat_path <- file.path(P$processed, "aqs_hcho_samples.csv")
if (file.exists(nat_path)) {
  nat <- read_tbl(nat_path, colClasses = list(character = "site_id")) |>
    filter(!is.na(hcho_ugm3), !is.na(lat), !is.na(start_utc), !is.na(end_utc))
  wn <- nat |>
    transmute(site = site_id, lat, lon,
              sample_date = as.Date(sample_date_local),
              arm = "national",
              convention = duration_class,
              stamp_local = NA_character_,
              win_start_utc = as.POSIXct(start_utc, tz = "UTC"),
              win_end_utc   = as.POSIXct(end_utc,   tz = "UTC")) |>
    distinct()
  windows <- bind_rows(windows, wn)
  log_msg("  national arm: ", nrow(wn), " sampling windows at ",
          n_distinct(wn$site), " sites")
} else {
  log_msg("  national samples not yet built (step 11); smoke flags cover the Colorado arms only")
}

pad <- CFG$hms_time_pad_hours * 3600
windows <- mutate(windows, pad_start_utc = win_start_utc - pad, pad_end_utc = win_end_utc + pad)
log_msg(nrow(windows), " sampling windows (", paste(unique(windows$arm), collapse = ", "),
        "); time padding +/-", CFG$hms_time_pad_hours, " h")

# HMS days needed: UTC dates touched by each window
hms_days <- sort(unique(c(as.Date(windows$pad_start_utc), as.Date(windows$pad_end_utc - 1))))
log_msg(length(hms_days), " HMS days needed")

# ---- 2. download -------------------------------------------------------------------
hms_url  <- function(d) sprintf("%s/%s/%s/hms_smoke%s.zip", CFG$hms_base_url,
                                format(d, "%Y"), format(d, "%m"), format(d, "%Y%m%d"))
hms_file <- function(d) file.path(P$raw_hms, sprintf("hms_smoke%s.zip", format(d, "%Y%m%d")))
is_zip   <- function(path) file.exists(path) && file.size(path) > 4 &&
  identical(readBin(path, "raw", n = 2), charToRaw("PK"))

status_path <- file.path(P$raw_hms, "hms_download_manifest.csv")
old_status <- if (file.exists(status_path)) read_tbl(status_path, colClasses = "character") else NULL

status <- map(seq_along(hms_days), function(k) {
  d <- hms_days[k]; f <- hms_file(d)
  if (k %% 50 == 0) log_msg("  HMS ", k, "/", length(hms_days))
  if (is_zip(f)) return(tibble(date = d, status = "ok"))
  prev <- if (!is.null(old_status)) old_status$status[old_status$date == as.character(d)] else character()
  if (length(prev) && prev[1] == "not_found" && !isTRUE(CFG$hms_retry_not_found))
    return(tibble(date = d, status = "not_found"))
  tmp <- tempfile(fileext = ".zip")
  resp <- tryCatch(public_request(hms_url(d)) |> httr2::req_error(is_error = function(r) FALSE) |>
                     httr2::req_perform(path = tmp), error = function(e) NULL)
  Sys.sleep(0.2)
  if (is.null(resp)) return(tibble(date = d, status = "error"))
  if (httr2::resp_status(resp) == 404) return(tibble(date = d, status = "not_found"))
  if (httr2::resp_status(resp) >= 400 || !is_zip(tmp)) return(tibble(date = d, status = paste("http", httr2::resp_status(resp))))
  file.copy(tmp, f, overwrite = TRUE); unlink(tmp)
  tibble(date = d, status = "ok")
}) |> list_rbind() |>
  mutate(url = hms_url(date),
         md5 = ifelse(status == "ok", unname(tools::md5sum(hms_file(date))), NA_character_))
data.table::fwrite(status, status_path)
log_msg("HMS files: ", paste(names(table(status$status)), table(status$status), sep = " = ", collapse = "; "))
data.table::fwrite(                     # SI S6 quotes these; the second pass (all arms) overwrites
  tibble(key = c("hms_days_needed", "hms_days_missing"),
         value = as.character(c(nrow(status), sum(status$status != "ok"))),
         source = "R/08_smoke_hms.R"),
  file.path(P$tables, "manuscript_numbers_08.csv"))

# ---- 3. polygons covering each site ----------------------------------------------------
sites <- windows |> distinct(site, lat, lon)
pts <- sf::st_as_sf(sites, coords = c("lon", "lat"), crs = 4326)

parse_hms_time <- function(x) as.POSIXct(strptime(trimws(as.character(x)), "%Y%j %H%M", tz = "UTC"))
density_level <- function(x) {
  x <- tolower(trimws(as.character(x)))
  case_when(x == "light" ~ 1L, x == "medium" ~ 2L, x == "heavy" ~ 3L,
            x %in% c("5", "5.0") ~ 1L, x %in% c("16", "16.0") ~ 2L, x %in% c("27", "27.0") ~ 3L,  # older numeric codes
            TRUE ~ NA_integer_)
}

site_polys <- map(status$date[status$status == "ok"], function(d) {
  td <- tempfile(); dir.create(td)
  on.exit(unlink(td, recursive = TRUE))
  utils::unzip(hms_file(d), exdir = td)
  shp <- list.files(td, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  if (!length(shp)) return(NULL)
  poly <- tryCatch(sf::st_read(shp[1], quiet = TRUE), error = function(e) NULL)
  if (is.null(poly) || !nrow(poly)) return(NULL)
  names(poly) <- tolower(names(poly))
  if (is.na(sf::st_crs(poly))) sf::st_crs(poly) <- 4326 else poly <- sf::st_transform(poly, 4326)
  poly <- suppressWarnings(sf::st_make_valid(poly))
  hits <- suppressMessages(sf::st_intersects(pts, poly))
  map(seq_along(hits), function(i) {
    if (!length(hits[[i]])) return(NULL)
    p <- sf::st_drop_geometry(poly[hits[[i]], ])
    col <- function(name) if (name %in% names(p)) p[[name]] else rep(NA_character_, nrow(p))
    tibble(hms_date = d, site = sites$site[i],
           start_utc = parse_hms_time(col("start")), end_utc = parse_hms_time(col("end")),
           density = density_level(col("density")))
  }) |> list_rbind()
}) |> list_rbind()
if (is.null(site_polys)) {
  site_polys <- tibble(hms_date = as.Date(character()), site = character(),
                       start_utc = as.POSIXct(character(), tz = "UTC"), end_utc = as.POSIXct(character(), tz = "UTC"),
                       density = integer())
}
data.table::fwrite(site_polys, file.path(P$interim, "hms_polygons_over_sites.csv"))
log_msg(nrow(site_polys), " HMS polygon-site intersections")

# ---- 4. flags per sampling window -------------------------------------------------------
ok_days <- status$date[status$status == "ok"]
flags <- windows |>
  mutate(day1 = as.Date(pad_start_utc), day2 = as.Date(pad_end_utc - 1),
         hms_available = day1 %in% ok_days & day2 %in% ok_days,
         wid = row_number())
same_days <- flags |>
  select(wid, site, day1, day2, pad_start_utc, pad_end_utc) |>
  inner_join(site_polys, by = "site", relationship = "many-to-many") |>
  filter(hms_date >= day1, hms_date <= day2)
day_level <- same_days |> distinct(wid) |> mutate(any_day = TRUE)
overlaps <- same_days |>
  # polygons without parseable times count for the whole HMS day
  filter(is.na(start_utc) | is.na(end_utc) | (start_utc < pad_end_utc & end_utc > pad_start_utc)) |>
  group_by(wid) |>
  summarise(n_smoke_polygons = n(),
            smoke_max_density = if (all(is.na(density))) 1L else max(density, na.rm = TRUE),
            .groups = "drop")

smoke <- flags |>
  left_join(overlaps, by = "wid") |>
  left_join(day_level, by = "wid") |>
  mutate(n_smoke_polygons = ifelse(hms_available, coalesce(n_smoke_polygons, 0L), NA_integer_),
         smoke_max_density = ifelse(hms_available, coalesce(smoke_max_density, 0L), NA_integer_),
         smoke_any = smoke_max_density > 0,
         smoke_any_day = ifelse(hms_available, coalesce(any_day, FALSE), NA),
         smoke_class = factor(case_when(is.na(smoke_max_density) ~ NA_character_,
                                        smoke_max_density == 0 ~ "none",
                                        smoke_max_density == 1 ~ "light",
                                        TRUE ~ "medium/heavy"),
                              levels = c("none", "light", "medium/heavy"))) |>
  select(arm, convention, site, sample_date, stamp_local, win_start_utc, win_end_utc,
         hms_available, n_smoke_polygons, smoke_max_density, smoke_any, smoke_class, smoke_any_day)

data.table::fwrite(smoke, file.path(P$processed, "smoke_flags.csv"))
inv <- smoke |>
  group_by(arm, convention, site) |>
  summarise(samples = n(), hms_available = sum(hms_available),
            smoke_any = sum(smoke_any, na.rm = TRUE),
            smoke_any_day = sum(smoke_any_day, na.rm = TRUE),
            medium_heavy = sum(smoke_class == "medium/heavy", na.rm = TRUE), .groups = "drop")
data.table::fwrite(inv, file.path(P$tables, "smoke_inventory.csv"))

# ---- 4b. sensitivity: what a strict overlap test would have given ------------
# Widening each window by hms_time_pad_hours is a precaution, not a neutral
# default: HMS polygons are analyst delineations from discrete visible imagery,
# so an hour no polygon covers is not thereby established as free of smoke. The strict test it
# replaces is therefore reported rather than merely described, so a reader can
# see how much the padding changes and judge it. This writes a table only; the
# flags above, and every result that uses them, are unchanged.
flag_with_pad <- function(pad_h) {
  p_s <- pad_h * 3600
  w <- windows |>
    mutate(s_utc = win_start_utc - p_s, e_utc = win_end_utc + p_s,
           day1 = as.Date(s_utc), day2 = as.Date(e_utc - 1),
           hms_available = day1 %in% ok_days & day2 %in% ok_days,
           wid = row_number())
  ov <- w |>
    select(wid, site, day1, day2, s_utc, e_utc) |>
    inner_join(site_polys, by = "site", relationship = "many-to-many") |>
    filter(hms_date >= day1, hms_date <= day2) |>
    filter(is.na(start_utc) | is.na(end_utc) | (start_utc < e_utc & end_utc > s_utc)) |>
    group_by(wid) |>
    summarise(dens = if (all(is.na(density))) 1L else max(density, na.rm = TRUE),
              .groups = "drop")
  w |>
    left_join(ov, by = "wid") |>
    mutate(pad_hours = pad_h,
           dens = ifelse(hms_available, coalesce(dens, 0L), NA_integer_),
           flagged = dens > 0) |>
    select(pad_hours, arm, site, sample_date, hms_available, flagged)
}

pad_levels <- sort(unique(c(0, CFG$hms_time_pad_hours)))
pad_sens <- purrr::map(pad_levels, flag_with_pad) |> purrr::list_rbind()
pad_summary <- pad_sens |>
  group_by(arm, pad_hours) |>
  # flagged_pct is computed BEFORE flagged is redefined as a count: summarise()
  # evaluates its arguments in order and a later one sees the earlier result,
  # so reusing the name here silently averaged the count instead of the column.
  summarise(windows = n(), with_hms = sum(hms_available),
            flagged_pct = round(100 * mean(flagged, na.rm = TRUE), 1),
            flagged = sum(flagged, na.rm = TRUE), .groups = "drop") |>
  relocate(flagged, .before = flagged_pct) |>
  arrange(arm, pad_hours)
data.table::fwrite(pad_summary, file.path(P$tables, "smoke_pad_sensitivity.csv"))
log_msg("HMS time-padding sensitivity (0 h = strict overlap; the analysis uses ",
        CFG$hms_time_pad_hours, " h):")
print(pad_summary, n = Inf)
pad_by_site <- pad_sens |>
  group_by(arm, site, pad_hours) |>
  summarise(flagged = sum(flagged, na.rm = TRUE), .groups = "drop") |>
  tidyr::pivot_wider(names_from = pad_hours, values_from = flagged,
                     names_prefix = "flagged_pad_")
data.table::fwrite(pad_by_site, file.path(P$tables, "smoke_pad_sensitivity_by_site.csv"))
print(pad_by_site, n = Inf)
print(inv, n = Inf)
log_msg("Wrote smoke flags for ", nrow(smoke), " sampling windows to ", file.path(P$processed, "smoke_flags.csv"))
