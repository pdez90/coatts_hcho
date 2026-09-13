# =============================================================================
# 07_threeh_analysis.R - 3-h samples vs TEMPO scans, by lag from the sampling window
#
# The sampling window is now known: AQS records the time each sample began, and
# reports 06:00 with a 3-hour duration for Chatfield State Park and Platteville
# (step 10). The 09:00 stamp in CDPHE's packets is therefore the END of the
# sample, and the window is [stamp - duration, stamp).
#
# For each lag L in CFG$threeh_lags_h, TEMPO scans whose midpoint falls in
# [win_start + L, win_end + L) are screened and averaged. L = 0 is the sampling
# window itself; positive lags are scans after sampling ended, which test how
# agreement depends on the delay between sampling and the satellite view (the
# morning boundary layer grows and mixes over these hours).
# Needs: step 06, then steps 02 and 03 run with options(hcho.arm = "threeh").
# Outputs: data/processed/threeh_matched_*.csv, output/tables/threeh_*.csv,
#          output/figures/fig7_threeh_scatter.png, fig8_threeh_sensitivity.png,
#          fig10_threeh_lag_curve.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_stats.R")
set.seed(42)
A3 <- arm_paths("threeh")

samples <- read_tbl(A3$samples, colClasses = list(character = "stamp_local")) |>
  mutate(sample_date = as.Date(sample_date),
         # MST clock time, held in a UTC-labelled POSIXct (no DST shifts)
         stamp_local = parse_date_time(stamp_local, orders = c("Ymd HM", "Ymd HMS"), tz = "UTC"),
         season = factor(season, levels = c("DJF", "MAM", "JJA", "SON"))) |>
  filter(!is.na(hcho_ugm3))
if (CFG$threeh_exclude_unusual_stamps && "stamp_time_unusual" %in% names(samples)) {
  odd <- as.logical(samples$stamp_time_unusual) %in% TRUE
  if (any(odd)) log_msg("Leaving out ", sum(odd), " samples with an unusual stamp time (threeh_exclude_unusual_stamps): ",
                        paste(samples$site[odd], format(samples$stamp_local[odd], "%Y-%m-%d %H:%M"), collapse = "; "))
  samples <- samples[!odd, , drop = FALSE]
}
manifest <- read_tbl(A3$manifest) |>
  mutate(mid_utc = as.POSIXct(mid_utc, tz = "UTC")) |>
  distinct(granule, mid_utc)
cells <- read_tbl(A3$cells, colClasses = list(character = c("granule", "scan_start_utc", "site")))
for (col in setdiff(names(cells), c("granule", "scan_start_utc", "site"))) {
  x <- cells[[col]]
  if (!is.numeric(x) || inherits(x, "integer64")) cells[[col]] <- suppressWarnings(as.numeric(as.character(x)))
}
for (v in c("main_data_quality_flag", "eff_cloud_fraction", "snow_ice_fraction",
            "solar_zenith_angle", "pbl_height", "vertical_column_uncertainty",
            "surface_pressure")) {
  if (!v %in% names(cells)) cells[[v]] <- NA_real_
}
log_msg(nrow(samples), " 3-h samples; ", nrow(cells), " TEMPO cell rows")

# label a lag with the clock hours it covers, from the usual sample stamp
modal_end_hour <- as.integer(names(sort(table(hour(samples$stamp_local)), decreasing = TRUE))[1])
dur_h <- CFG$threeh_duration_s / 3600
lag_clock <- function(l) sprintf("%s%g h: %02d-%02d MST", ifelse(l > 0, "+", ""), l,
                                 (modal_end_hour - dur_h + l) %% 24, (modal_end_hour + l) %% 24)
lag_levels <- sort(unique(CFG$threeh_lags_h))
lag_label <- function(l) factor(l, levels = lag_levels,
                                labels = ifelse(lag_levels == 0,
                                                paste0("sampling window (", lag_clock(0), ")"),
                                                vapply(lag_levels, lag_clock, character(1))))

# ---- screening and scan-level values (as in step 04) -------------------------
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
    inner_join(manifest, by = "granule")
}

# sampling window: [stamp - duration, stamp); shifted by lag_h hours
sample_windows <- function(lag_h) {
  dur <- CFG$threeh_duration_s
  samples |>
    mutate(win_start_local = stamp_local - dur + lag_h * 3600,
           win_end_local = win_start_local + dur,
           win_start_utc = win_start_local - CFG$utc_offset_hours * 3600,
           win_end_utc = win_end_local - CFG$utc_offset_hours * 3600)
}

variants <- expand_grid(lag_h = lag_levels, max_ecf = c(0.1, 0.2, 0.3), block = c(0L, 1L, 2L)) |>
  mutate(block_label = sprintf("%dx%d", 2L * block + 1L, 2L * block + 1L))

scan_cache <- list()
matched <- pmap(variants, function(lag_h, max_ecf, block, block_label) {
  key <- paste(max_ecf, block)
  if (is.null(scan_cache[[key]])) scan_cache[[key]] <<- scan_values(max_ecf, block)
  sv <- scan_cache[[key]]
  w <- sample_windows(lag_h)
  per_sample <- w |>
    select(site, stamp_local, win_start_utc, win_end_utc) |>
    inner_join(sv, by = "site", relationship = "many-to-many") |>
    filter(mid_utc >= win_start_utc, mid_utc < win_end_utc) |>
    group_by(site, stamp_local) |>
    summarise(n_scans = n(), n_valid_scans = sum(valid),
              tempo_vc = if (any(valid)) mean(vc[valid]) else NA_real_,
              tempo_pbl_m = if (any(valid)) mean(pbl[valid], na.rm = TRUE) else NA_real_,
              tempo_press_hpa = if (any(valid)) mean(sp[valid], na.rm = TRUE) else NA_real_,
              .groups = "drop")
  w |>
    left_join(per_sample, by = c("site", "stamp_local")) |>
    mutate(lag_h = lag_h, max_ecf = max_ecf, block = block, block_label = block_label,
           n_scans = coalesce(n_scans, 0L), n_valid_scans = coalesce(n_valid_scans, 0L))
}) |> list_rbind() |>
  mutate(tempo_vc_1e15 = tempo_vc / 1e15,
         # as in step 04: reported values are at 25 C and 1 atm; these packets carry
         # no met, so the number density uses TEMPO's surface pressure and a fixed
         # temperature (CFG$hcho_fallback_temp_c)
         hcho_ppb_std = ugm3_std_to_ppb(hcho_ugm3),
         hcho_molec_cm3_local = ppb_to_molec_cm3(hcho_ppb_std, CFG$hcho_fallback_temp_c, tempo_press_hpa),
         h_eff_std_km = ifelse(tempo_vc > 0 & hcho_molec_cm3 > 0, tempo_vc / hcho_molec_cm3 / 1e5, NA_real_),
         h_eff_km = ifelse(tempo_vc > 0 & hcho_molec_cm3_local > 0,
                           tempo_vc / hcho_molec_cm3_local / 1e5, h_eff_std_km),
         tempo_pbl_km = tempo_pbl_m / 1000,
         usable = !is.na(tempo_vc) & !is.na(hcho_ugm3))

data.table::fwrite(matched, file.path(P$processed, "threeh_matched_variants.csv"))
primary <- matched |> filter(max_ecf == CFG$qc_max_cloud_fraction, block == 1L)   # all lags
data.table::fwrite(primary, file.path(P$processed, "threeh_matched_primary.csv"))

# ---- coverage ---------------------------------------------------------------------
coverage <- primary |>
  group_by(lag_h, site, site_name) |>
  summarise(samples = n(), with_any_scan = sum(n_scans > 0), n_usable = sum(usable),
            usable_pct = round(100 * mean(usable), 1),
            median_scans_in_window = median(n_scans), .groups = "drop") |>
  mutate(window = as.character(lag_label(lag_h)), .after = lag_h) |>
  arrange(site, lag_h)
data.table::fwrite(coverage, file.path(P$tables, "threeh_coverage.csv"))
print(coverage)

# ---- relationship ------------------------------------------------------------------
use <- filter(primary, usable)
stats <- bind_rows(
  use |> group_by(lag_h) |> group_modify(~ relstats(.x)) |> ungroup() |> mutate(site = "all sites"),
  use |> group_by(lag_h, site) |> group_modify(~ relstats(.x)) |> ungroup()
) |>
  mutate(window = as.character(lag_label(lag_h))) |>
  relocate(lag_h, window, site) |>
  arrange(site, lag_h)
data.table::fwrite(stats, file.path(P$tables, "threeh_stats_by_site.csv"))
print(select(stats, lag_h, site, n, pearson_r, pearson_p, spearman_rho, rma_slope, median_h_eff_km))

anom_stats <- map(lag_levels, function(l) {
  d <- filter(use, lag_h == l)
  if (nrow(d) < 6) return(NULL)
  an <- add_month_anomalies(d, CFG$min_days_per_site_month)
  if (!nrow(an)) return(NULL)
  bind_rows(anomstats(an) |> mutate(site = "all sites"),
            an |> group_by(site) |> group_modify(~ anomstats(.x)) |> ungroup()) |>
    mutate(lag_h = l)
}) |> list_rbind() |>
  mutate(window = as.character(lag_label(lag_h))) |>
  relocate(lag_h, window, site) |>
  arrange(site, lag_h)
data.table::fwrite(anom_stats, file.path(P$tables, "threeh_stats_within_month_anomalies.csv"))
print(anom_stats)

# Pooled regression with site and month-of-year effects, per lag
month_fx <- map(lag_levels, function(l) {
  d <- filter(use, lag_h == l)
  if (nrow(d) < 12 || n_distinct(month(d$sample_date)) < 2) return(NULL)
  fml <- if (n_distinct(d$site) > 1) hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date)) + site
         else hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date))
  co <- summary(lm(fml, data = d))$coefficients
  tibble(lag_h = l, window = as.character(lag_label(l)), n = nrow(d),
         estimate = co["tempo_vc_1e15", 1], std_error = co["tempo_vc_1e15", 2],
         p_value = co["tempo_vc_1e15", 4])
}) |> list_rbind()
if (!is.null(month_fx) && nrow(month_fx)) {
  data.table::fwrite(month_fx, file.path(P$tables, "threeh_month_effects_lm.csv"))
  print(month_fx)
}

sens <- matched |>
  filter(usable) |>
  group_by(lag_h, max_ecf, block_label) |>
  summarise(n = n(),
            spearman_rho = suppressWarnings(cor(tempo_vc, hcho_ugm3, method = "spearman")),
            pearson_r = cor(tempo_vc, hcho_ugm3), .groups = "drop") |>
  mutate(window = as.character(lag_label(lag_h)), .after = lag_h)
data.table::fwrite(sens, file.path(P$tables, "threeh_sensitivity.csv"))

# ---- smoke (NOAA HMS) -------------------------------------------------------------------
# The smoke flag describes the sample's own window, so it applies to every lag.
smoke_path <- file.path(P$processed, "smoke_flags.csv")
if (file.exists(smoke_path) && nrow(use)) {
  smoke3 <- read_tbl(smoke_path, colClasses = list(character = "stamp_local")) |>
    filter(arm == "threeh") |>
    select(site, stamp_key = stamp_local, hms_available, smoke_any, smoke_class) |>
    distinct(site, stamp_key, .keep_all = TRUE)
  use_s <- use |>
    mutate(stamp_key = format(stamp_local, "%Y-%m-%d %H:%M")) |>
    left_join(smoke3, by = c("site", "stamp_key"))
  if (!any(!is.na(use_s$smoke_any))) {
    log_msg("No HMS coverage for the 3-h windows - skipping smoke stratification")
  } else {
    smoke_stats3 <- bind_rows(
      use_s |> filter(!is.na(smoke_any)) |> group_by(lag_h, smoke_any) |>
        group_modify(~ relstats(.x)) |> ungroup() |> mutate(subset = "by smoke flag"),
      use_s |> filter(smoke_any %in% FALSE) |> group_by(lag_h) |>
        group_modify(~ relstats(.x)) |> ungroup() |> mutate(subset = "smoke windows excluded")
    ) |>
      mutate(window = as.character(lag_label(lag_h))) |>
      relocate(subset, lag_h, window, smoke_any)
    data.table::fwrite(smoke_stats3, file.path(P$tables, "threeh_stats_by_smoke.csv"))
    print(select(smoke_stats3, any_of(c("subset", "lag_h", "smoke_any", "n", "pearson_r", "spearman_rho"))))
  }
} else {
  log_msg("No smoke_flags.csv (run R/08_smoke_hms.R) - skipping smoke analysis")
}

# ---- figures ------------------------------------------------------------------------
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))
U_UGM3 <- "\u00b5g/m\u00b3"; U_COL <- "10\u00b9\u2075 molec/cm\u00b2"; U_RHO <- "\u03c1"
season_cols <- c(DJF = "#3b6fb6", MAM = "#5aa469", JJA = "#d9822b", SON = "#8a5fb0")

site_stats <- filter(stats, site != "all sites", !is.na(pearson_r)) |> mutate(window_f = lag_label(lag_h))
if (nrow(use)) {
  p7 <- ggplot(mutate(use, window_f = lag_label(lag_h)), aes(tempo_vc_1e15, hcho_ugm3)) +
    geom_point(aes(colour = season), size = 1.5, alpha = 0.85) +
    geom_abline(data = filter(site_stats, !is.na(rma_slope)),
                aes(slope = rma_slope, intercept = rma_intercept), linewidth = 0.6) +
    geom_text(data = site_stats, aes(x = -Inf, y = Inf,
              label = sprintf("n=%d  r=%.2f  %s=%.2f", n, pearson_r, U_RHO, spearman_rho)),
              hjust = -0.05, vjust = 1.3, size = 2.8) +
    facet_grid(window_f ~ site, scales = "free") +
    scale_colour_manual(values = season_cols, drop = FALSE) +
    labs(x = paste0("TEMPO HCHO column, mean of screened scans in the window (", U_COL, ")"),
         y = paste0("Surface HCHO, 3-h sample (", U_UGM3, ")"), colour = NULL,
         title = "3-hour samples vs TEMPO scans, by lag from the sampling window",
         subtitle = "RMA line where the Pearson correlation is significant")
  ggsave(file.path(P$figures, "fig7_threeh_scatter.png"), p7, width = 8.5,
         height = 2 + 1.7 * length(lag_levels), dpi = 300, limitsize = FALSE)
  log_msg("  figure: fig7_threeh_scatter.png")
}

p8 <- ggplot(mutate(sens, window_f = lag_label(lag_h)),
             aes(factor(max_ecf), spearman_rho, colour = block_label, group = block_label)) +
  geom_line() + geom_point(aes(size = n)) + facet_wrap(~ window_f) +
  scale_size_continuous(range = c(1.5, 4)) +
  labs(x = "Maximum effective cloud fraction", y = paste("Pooled Spearman", U_RHO),
       colour = "Block", size = "n",
       title = "3-hour arm: sensitivity to screening, by lag from the sampling window")
ggsave(file.path(P$figures, "fig8_threeh_sensitivity.png"), p8, width = 9, height = 6, dpi = 300)
log_msg("  figure: fig8_threeh_sensitivity.png")

# agreement as a function of lag: the headline of this arm
lag_curve <- bind_rows(
  stats |> filter(site == "all sites") |> transmute(lag_h, n, r = pearson_r, kind = "whole period"),
  anom_stats |> filter(site == "all sites") |> transmute(lag_h, n, r = pearson_r, kind = "within-month anomalies")
) |> filter(!is.na(r))
if (nrow(lag_curve)) {
  p10 <- ggplot(lag_curve, aes(lag_h, r, colour = kind, shape = kind)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_vline(xintercept = 0, linetype = 2, colour = "grey60") +
    geom_line(linewidth = 0.7) + geom_point(size = 2.6) +
    geom_text(aes(label = n), vjust = -1.1, size = 3, show.legend = FALSE) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.16))) +   # room for the point labels
    scale_x_continuous(breaks = lag_levels,
                       labels = vapply(lag_levels, function(l) sub(":.*", "", lag_clock(l)), character(1))) +
    labs(x = paste0("Lag of the TEMPO window from the sampling window (0 = ", lag_clock(0), ")"),
         y = "Pearson r with 3-h surface HCHO", colour = NULL, shape = NULL,
         title = "Agreement peaks three hours after the sample ends",
         subtitle = "Point labels are the number of matched samples") +
    theme(legend.position = "bottom")
  ggsave(file.path(P$figures, "fig10_threeh_lag_curve.png"), p10, width = 7, height = 4.6, dpi = 300)
  log_msg("  figure: fig10_threeh_lag_curve.png")
  for (i in seq_len(nrow(lag_curve))) {
    log_msg("  ", lag_curve$kind[i], ", lag ", lag_curve$lag_h[i], " h (", lag_clock(lag_curve$lag_h[i]),
            "): r = ", round(lag_curve$r[i], 2), " (n = ", lag_curve$n[i], ")")
  }
}
log_msg("3-hour arm done.")
