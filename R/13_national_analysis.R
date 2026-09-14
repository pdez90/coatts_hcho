# =============================================================================
# 13_national_analysis.R - national AQS formaldehyde vs TEMPO
#
# Matches every national sample (step 11) to the TEMPO scans extracted for it
# (step 12) and repeats the Colorado analysis across the country:
#   * coverage, correlations and within-month anomaly correlations by site,
#     sample duration and lag from the sampling window
#   * the test the Colorado 3-h result asks for: at the 8-h PAMS sites, which
#     sample window agrees best - the one starting 04:00 local (which straddles
#     the morning transition), 12:00 (the mixed afternoon) or 20:00 (night)?
#   * the same by lag, so "when TEMPO looks relative to the sample" is measured
#     on 44 sites instead of two
# Scans are assigned by the hour containing their midpoint, as in steps 04 and 07;
# sample windows start on the hour, so this is exact.
# Outputs: data/processed/aqs_matched_*.csv.gz,
#          output/tables/national_*.csv, output/figures/fig11-13_national_*.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_stats.R")
set.seed(42)

samples_path <- file.path(P$processed, "aqs_hcho_samples.csv")
cells_path   <- file.path(P$processed, "aqs_tempo_site_cells.csv.gz")
man_path     <- file.path(P$processed, "aqs_tempo_manifest.csv")
for (f in c(samples_path, cells_path, man_path)) {
  if (!file.exists(f)) stop("Missing ", f, " - run steps 11 and 12 first.")
}

samples <- read_tbl(samples_path, colClasses = list(character = c("site_id", "qualifiers"))) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"),
         end_utc = as.POSIXct(end_utc, tz = "UTC"),
         sample_date = as.Date(sample_date_local),
         season = factor(season, levels = c("DJF", "MAM", "JJA", "SON"))) |>
  filter(!is.na(hcho_ugm3), !is.na(start_utc))

cells <- read_tbl(cells_path, colClasses = list(character = c("granule", "scan_start_utc", "site")))
for (col in setdiff(names(cells), c("granule", "scan_start_utc", "site"))) {
  x <- cells[[col]]
  if (!is.numeric(x) || inherits(x, "integer64")) cells[[col]] <- suppressWarnings(as.numeric(as.character(x)))
}
for (v in c("main_data_quality_flag", "eff_cloud_fraction", "snow_ice_fraction",
            "solar_zenith_angle", "pbl_height", "vertical_column_uncertainty", "surface_pressure")) {
  if (!v %in% names(cells)) cells[[v]] <- NA_real_
}
manifest <- read_tbl(man_path, colClasses = "character") |>
  transmute(granule, mid_utc = ymd_hms(mid_utc)) |>
  distinct(granule, .keep_all = TRUE)

samples <- filter(samples, site_id %in% unique(cells$site))
log_msg(nrow(samples), " samples at ", n_distinct(samples$site_id), " sites with TEMPO cells; ",
        nrow(cells), " cell rows")
print(count(samples, duration_class, name = "samples"))

# ---- 1. scan-level values (screening as in steps 04 and 07) -----------------
hour_key <- function(t) as.integer(as.numeric(t) %/% 3600)      # UTC hour index

scan_values <- function(max_ecf, block) {
  cells |>
    filter(abs(di) <= block, abs(dj) <= block) |>
    mutate(pass = !is.na(vertical_column) &
             coalesce(main_data_quality_flag, 0) <= CFG$qc_max_quality_flag &
             !is.na(eff_cloud_fraction) & eff_cloud_fraction <= max_ecf &
             coalesce(solar_zenith_angle, 0) <= CFG$qc_max_sza &
             coalesce(snow_ice_fraction, 0) <= CFG$qc_max_snow_ice) |>
    group_by(granule, site) |>
    summarise(n_cells = n(), n_pass = sum(pass),
              vc  = if (any(pass)) mean(vertical_column[pass]) else NA_real_,
              pbl = if (any(pass)) mean(pbl_height[pass], na.rm = TRUE) else NA_real_,
              sp  = if (any(pass)) mean(surface_pressure[pass], na.rm = TRUE) else NA_real_,
              .groups = "drop") |>
    mutate(valid = n_pass >= pmax(1, ceiling(CFG$qc_min_cell_fraction * n_cells))) |>
    inner_join(manifest, by = "granule") |>
    transmute(site, hour = hour_key(mid_utc), valid, vc, pbl, sp)
}

# every hour covered by a sample window, shifted by the lag
sample_hours <- function(lag_h) {
  s <- samples
  if (lag_h != 0) s <- filter(s, duration_class != "24 h")   # lags only for sub-daily samples
  if (!nrow(s)) return(NULL)
  s |>
    mutate(h0 = hour_key(start_utc) + lag_h, h1 = hour_key(end_utc) + lag_h, .keep = "all") |>
    select(site_id, start_utc, duration_class, h0, h1) |>
    mutate(hour = map2(h0, h1, ~ seq.int(.x, .y - 1L))) |>
    tidyr::unnest(hour) |>
    transmute(site = site_id, start_utc, hour, lag_h = lag_h)
}

variants <- expand_grid(lag_h = CFG$aqs_lags_h, max_ecf = c(0.1, 0.2, 0.3), block = c(0L, 1L, 2L)) |>
  mutate(block_label = sprintf("%dx%d", 2L * block + 1L, 2L * block + 1L))

scan_cache <- list()
hours_cache <- list()
matched <- pmap(variants, function(lag_h, max_ecf, block, block_label) {
  key <- paste(max_ecf, block)
  if (is.null(scan_cache[[key]])) scan_cache[[key]] <<- scan_values(max_ecf, block)
  sv <- scan_cache[[key]]
  hk <- as.character(lag_h)
  if (is.null(hours_cache[[hk]])) hours_cache[[hk]] <<- sample_hours(lag_h)
  sh <- hours_cache[[hk]]
  if (is.null(sh)) return(NULL)
  per_sample <- sh |>
    inner_join(sv, by = c("site", "hour"), relationship = "many-to-many") |>
    group_by(site, start_utc) |>
    summarise(n_scans = n(), n_valid_scans = sum(valid),
              tempo_vc = if (any(valid)) mean(vc[valid]) else NA_real_,
              tempo_pbl_m = if (any(valid)) mean(pbl[valid], na.rm = TRUE) else NA_real_,
              tempo_press_hpa = if (any(valid)) mean(sp[valid], na.rm = TRUE) else NA_real_,
              .groups = "drop")
  base <- if (lag_h == 0) samples else filter(samples, duration_class != "24 h")
  base |>
    left_join(per_sample, by = c("site_id" = "site", "start_utc")) |>
    mutate(lag_h = lag_h, max_ecf = max_ecf, block = block, block_label = block_label,
           n_scans = coalesce(n_scans, 0L), n_valid_scans = coalesce(n_valid_scans, 0L))
}) |> list_rbind() |>
  mutate(tempo_vc_1e15 = tempo_vc / 1e15,
         # reported values are at 25 C and 1 atm (Sect. 2.1): convert to a mixing
         # ratio, then to number density at TEMPO's surface pressure
         hcho_ppb_std = ugm3_std_to_ppb(hcho_ugm3),
         hcho_molec_cm3_local = ppb_to_molec_cm3(hcho_ppb_std, CFG$hcho_fallback_temp_c, tempo_press_hpa),
         h_eff_km = ifelse(tempo_vc > 0 & hcho_molec_cm3_local > 0,
                           tempo_vc / hcho_molec_cm3_local / 1e5, NA_real_),
         tempo_pbl_km = tempo_pbl_m / 1000,
         usable = !is.na(tempo_vc) & !is.na(hcho_ugm3),
         site = site_id,
         window_start_hour = round(start_hour_local))

data.table::fwrite(matched, file.path(P$processed, "aqs_matched_variants.csv.gz"))
primary <- filter(matched, max_ecf == CFG$qc_max_cloud_fraction, block == 1L)
data.table::fwrite(primary, file.path(P$processed, "aqs_matched_primary.csv.gz"))
log_msg(nrow(primary), " matched rows in the primary variant (", sum(primary$usable), " usable)")

# ---- 2. coverage -------------------------------------------------------------
coverage <- primary |>
  group_by(duration_class, lag_h, site, site_name, state) |>
  summarise(samples = n(), with_any_scan = sum(n_scans > 0), n_usable = sum(usable),
            usable_pct = round(100 * mean(usable), 1),
            median_scans = median(n_scans), .groups = "drop") |>
  arrange(duration_class, lag_h, desc(n_usable))
data.table::fwrite(coverage, file.path(P$tables, "national_coverage.csv"))
print(coverage |> group_by(duration_class, lag_h) |>
        summarise(sites = n(), samples = sum(samples), usable = sum(n_usable),
                  usable_pct = round(100 * sum(n_usable) / sum(samples), 1), .groups = "drop"))

use <- filter(primary, usable)

# ---- 3. correlations by duration and lag ------------------------------------
# within-site-month anomalies; works whether or not `site` is a grouping column
anom_of <- function(d) {
  d <- mutate(d, ym = floor_date(sample_date, "month"))
  g <- if ("site" %in% names(d)) c("site", "ym") else "ym"
  d |>
    group_by(across(all_of(g))) |>
    filter(n() >= CFG$min_days_per_site_month) |>
    mutate(surface_anom = hcho_ugm3 - mean(hcho_ugm3),
           column_anom = tempo_vc_1e15 - mean(tempo_vc_1e15)) |>
    ungroup()
}
stats_dl <- use |>
  group_by(duration_class, lag_h) |>
  group_modify(~ relstats(.x)) |>
  ungroup()
anom_dl <- use |>
  group_by(duration_class, lag_h) |>
  group_modify(~ {
    an <- anom_of(.x)
    if (nrow(an) < 6) return(tibble(n = nrow(an)))
    anomstats(an)
  }) |>
  ungroup() |>
  rename_with(~ paste0("anom_", .x), -c(duration_class, lag_h))
by_duration_lag <- left_join(stats_dl, anom_dl, by = c("duration_class", "lag_h")) |>
  arrange(duration_class, lag_h)
for (cn in c("anom_n", "anom_pearson_r")) if (!cn %in% names(by_duration_lag)) by_duration_lag[[cn]] <- NA_real_
data.table::fwrite(by_duration_lag, file.path(P$tables, "national_stats_by_duration_lag.csv"))
print(by_duration_lag |> select(duration_class, lag_h, n, pearson_r, spearman_rho,
                                anom_n, anom_pearson_r, median_h_eff_km, median_tempo_pbl_km))

# ---- 4. the time-of-day test -------------------------------------------------
# For sub-daily samples: does agreement depend on when the sample was collected?
by_hour <- use |>
  filter(duration_class != "24 h", lag_h == 0) |>
  group_by(duration_class, window_start_hour) |>
  filter(n() >= 12) |>
  group_modify(~ {
    an <- anom_of(.x)
    bind_cols(relstats(.x),
              if (nrow(an) >= 6) rename_with(anomstats(an), ~ paste0("anom_", .x)) else tibble())
  }) |>
  ungroup() |>
  arrange(duration_class, window_start_hour)
data.table::fwrite(by_hour, file.path(P$tables, "national_stats_by_start_hour.csv"))
print(by_hour |> select(any_of(c("duration_class", "window_start_hour", "n", "pearson_r",
                                 "spearman_rho", "anom_n", "anom_pearson_r", "median_tempo_pbl_km"))))

# ---- 5. per-site statistics --------------------------------------------------
by_site <- use |>
  filter(lag_h == 0) |>
  group_by(duration_class, site, site_name, state, networks, lat, lon) |>
  filter(n() >= 10) |>
  group_modify(~ {
    an <- anom_of(.x)
    bind_cols(relstats(.x, nboot = 200),
              if (nrow(an) >= 6) rename_with(anomstats(an), ~ paste0("anom_", .x)) else tibble())
  }) |>
  ungroup() |>
  arrange(duration_class, desc(pearson_r))
data.table::fwrite(by_site, file.path(P$tables, "national_stats_by_site.csv"))
log_msg("Sites with a significant whole-period correlation: ",
        sum(by_site$pearson_p < 0.05, na.rm = TRUE), " of ", nrow(by_site))
if ("anom_pearson_r" %in% names(by_site)) {
  log_msg("Median within-month anomaly r across sites: ",
          round(median(by_site$anom_pearson_r, na.rm = TRUE), 2),
          " (24 h: ", round(median(by_site$anom_pearson_r[by_site$duration_class == "24 h"], na.rm = TRUE), 2),
          "; 8 h: ", round(median(by_site$anom_pearson_r[by_site$duration_class == "8 h"], na.rm = TRUE), 2), ")")
}

# ---- 6. regression with site and month effects -------------------------------
month_fx <- use |>
  group_by(duration_class, lag_h) |>
  group_modify(~ {
    d <- .x
    if (nrow(d) < 30 || n_distinct(d$site) < 2) return(tibble())
    co <- summary(lm(hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date)) + site, data = d))$coefficients
    tibble(n = nrow(d), estimate = co["tempo_vc_1e15", 1], std_error = co["tempo_vc_1e15", 2],
           p_value = co["tempo_vc_1e15", 4])
  }) |>
  ungroup()
data.table::fwrite(month_fx, file.path(P$tables, "national_month_effects_lm.csv"))
print(month_fx)

# ---- 7. sensitivity to screening --------------------------------------------
sens <- matched |>
  filter(usable) |>
  group_by(duration_class, lag_h, max_ecf, block_label) |>
  summarise(n = n(), pearson_r = cor(tempo_vc, hcho_ugm3),
            spearman_rho = suppressWarnings(cor(tempo_vc, hcho_ugm3, method = "spearman")),
            .groups = "drop")
data.table::fwrite(sens, file.path(P$tables, "national_sensitivity.csv"))

# ---- 8. figures --------------------------------------------------------------
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))

lag_curve <- by_duration_lag |>
  filter(duration_class != "24 h") |>
  select(duration_class, lag_h, whole = pearson_r, anomalies = anom_pearson_r, n, anom_n) |>
  pivot_longer(c(whole, anomalies), names_to = "kind", values_to = "r") |>
  mutate(n_lab = if_else(kind == "whole", n, anom_n))
if (nrow(lag_curve)) {
  p11 <- ggplot(lag_curve, aes(lag_h, r, colour = kind, shape = kind)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_vline(xintercept = 0, linetype = 2, colour = "grey60") +
    geom_line(linewidth = 0.7) + geom_point(size = 2.4) +
    geom_text(aes(label = n_lab), vjust = -1, size = 2.8, show.legend = FALSE) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.16))) +
    facet_wrap(~ duration_class) +
    labs(x = "Lag of the TEMPO window from the sampling window (h)",
         y = "Pearson r with surface HCHO", colour = NULL, shape = NULL,
         title = "National sub-daily samples: agreement against lag",
         subtitle = "Labels are the number of matched samples") +
    theme(legend.position = "bottom")
  ggsave(file.path(P$figures, "fig11_national_lag_curve.png"), p11, width = 8, height = 4.6, dpi = 300)
  log_msg("  figure: fig11_national_lag_curve.png")
}

if (nrow(by_hour)) {
  if (!"anom_pearson_r" %in% names(by_hour)) by_hour$anom_pearson_r <- NA_real_
  ph <- by_hour |>
    transmute(duration_class, window_start_hour, n, whole = pearson_r, anomalies = anom_pearson_r) |>
    pivot_longer(c(whole, anomalies), names_to = "kind", values_to = "r")
  p12 <- ggplot(ph, aes(window_start_hour, r, colour = kind, shape = kind)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_line(linewidth = 0.7) + geom_point(size = 2.6) +
    geom_text(aes(label = n), vjust = -1, size = 2.8, show.legend = FALSE) +
    scale_x_continuous(breaks = seq(0, 21, 4)) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.16))) +
    facet_wrap(~ duration_class) +
    labs(x = "Local standard hour the sample started",
         y = "Pearson r with surface HCHO", colour = NULL, shape = NULL,
         title = "Which sampling windows does TEMPO track?",
         subtitle = "Scans inside the sampling window; labels are the number of matched samples") +
    theme(legend.position = "bottom")
  ggsave(file.path(P$figures, "fig12_national_by_start_hour.png"), p12, width = 8, height = 4.6, dpi = 300)
  log_msg("  figure: fig12_national_by_start_hour.png")
}

if (nrow(by_site) && "anom_pearson_r" %in% names(by_site) && any(!is.na(by_site$anom_pearson_r))) {
  dur_order <- intersect(c("24 h", "8 h", "3 h", "1 h"), unique(by_site$duration_class))
  p13 <- by_site |>
    mutate(duration_class = factor(duration_class, levels = dur_order)) |>
    ggplot(aes(lon, lat, colour = anom_pearson_r, size = anom_n)) +
    geom_point(alpha = 0.9) +
    scale_colour_gradient2(low = "#b2182b", mid = "grey85", high = "#2166ac", midpoint = 0,
                           limits = c(-0.8, 0.8), oob = scales::squish) +
    scale_size_continuous(range = c(1.5, 5)) +
    facet_wrap(~ duration_class, ncol = 1) +
    labs(x = "Longitude", y = "Latitude", colour = "Day-to-day r", size = "n",
         title = "Day-to-day agreement, TEMPO vs surface HCHO",
         subtitle = "Within-month anomalies; scans inside the sampling window") +
    coord_quickmap()
  ggsave(file.path(P$figures, "fig13_national_site_map.png"), p13, width = 5.5, height = 8.8, dpi = 300)
  log_msg("  figure: fig13_national_site_map.png")
}

# ---- 9. headline lines for the log ------------------------------------------
for (i in seq_len(nrow(by_duration_lag))) {
  r <- by_duration_lag[i, ]
  log_msg("  ", r$duration_class, ", lag ", r$lag_h, " h: r = ", round(r$pearson_r, 2),
          " (n = ", r$n, "); day-to-day r = ", round(r$anom_pearson_r, 2),
          " (n = ", r$anom_n, "); median PBL ", round(r$median_tempo_pbl_km, 2), " km")
}
for (i in seq_len(nrow(by_hour))) {
  r <- by_hour[i, ]
  log_msg("  ", r$duration_class, " samples starting ", r$window_start_hour, ":00 local: r = ",
          round(r$pearson_r, 2), " (n = ", r$n, ")",
          if ("anom_pearson_r" %in% names(r)) paste0("; day-to-day r = ", round(r$anom_pearson_r, 2)) else "")
}
log_msg("National analysis done.")
