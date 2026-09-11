# =============================================================================
# 07_threeh_analysis.R - match 3-h samples to TEMPO scans inside each window
#
# For each sample, the sampling window is [stamp, stamp + 3 h) under the
# "start" convention or [stamp - 3 h, stamp) under "end" (CDPHE to confirm).
# TEMPO scans whose midpoint falls in the window are screened and averaged
# (same screening as the 24-h arm). Variants: convention x cloud threshold x block.
# Needs: step 06, then steps 02 and 03 run with options(hcho.arm = "threeh").
# Outputs: data/processed/threeh_matched_*.csv, output/tables/threeh_*.csv,
#          output/figures/fig7_threeh_scatter.png, fig8_threeh_sensitivity.png
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
            "solar_zenith_angle", "pbl_height", "vertical_column_uncertainty")) {
  if (!v %in% names(cells)) cells[[v]] <- NA_real_
}
log_msg(nrow(samples), " 3-h samples; ", nrow(cells), " TEMPO cell rows")

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
              .groups = "drop") |>
    mutate(valid = n_pass >= pmax(1, ceiling(CFG$qc_min_cell_fraction * n_cells))) |>
    inner_join(manifest, by = "granule")
}

sample_windows <- function(convention) {
  dur <- CFG$threeh_duration_s
  samples |>
    mutate(win_start_local = if (convention == "start") stamp_local else stamp_local - dur,
           win_end_local = win_start_local + dur,
           win_start_utc = win_start_local - CFG$utc_offset_hours * 3600,
           win_end_utc = win_end_local - CFG$utc_offset_hours * 3600)
}

variants <- expand_grid(convention = CFG$threeh_stamp_conventions,
                        max_ecf = c(0.1, 0.2, 0.3), block = c(0L, 1L, 2L)) |>
  mutate(block_label = sprintf("%dx%d", 2L * block + 1L, 2L * block + 1L))

scan_cache <- list()
matched <- pmap(variants, function(convention, max_ecf, block, block_label) {
  key <- paste(max_ecf, block)
  if (is.null(scan_cache[[key]])) scan_cache[[key]] <<- scan_values(max_ecf, block)
  sv <- scan_cache[[key]]
  w <- sample_windows(convention)
  per_sample <- w |>
    select(site, stamp_local, win_start_utc, win_end_utc) |>
    inner_join(sv, by = "site", relationship = "many-to-many") |>
    filter(mid_utc >= win_start_utc, mid_utc < win_end_utc) |>
    group_by(site, stamp_local) |>
    summarise(n_scans = n(), n_valid_scans = sum(valid),
              tempo_vc = if (any(valid)) mean(vc[valid]) else NA_real_,
              tempo_pbl_m = if (any(valid)) mean(pbl[valid], na.rm = TRUE) else NA_real_,
              .groups = "drop")
  w |>
    left_join(per_sample, by = c("site", "stamp_local")) |>
    mutate(convention = convention, max_ecf = max_ecf, block = block, block_label = block_label,
           n_scans = coalesce(n_scans, 0L), n_valid_scans = coalesce(n_valid_scans, 0L))
}) |> list_rbind() |>
  mutate(tempo_vc_1e15 = tempo_vc / 1e15,
         h_eff_km = ifelse(tempo_vc > 0 & hcho_molec_cm3 > 0, tempo_vc / hcho_molec_cm3 / 1e5, NA_real_),
         tempo_pbl_km = tempo_pbl_m / 1000,
         usable = !is.na(tempo_vc) & !is.na(hcho_ugm3))

data.table::fwrite(matched, file.path(P$processed, "threeh_matched_variants.csv"))
primary <- matched |> filter(max_ecf == CFG$qc_max_cloud_fraction, block == 1L)   # both conventions
data.table::fwrite(primary, file.path(P$processed, "threeh_matched_primary.csv"))

# ---- coverage ---------------------------------------------------------------------
coverage <- primary |>
  group_by(convention, site, site_name) |>
  summarise(samples = n(), with_any_scan = sum(n_scans > 0), n_usable = sum(usable),
            usable_pct = round(100 * mean(usable), 1),
            median_scans_in_window = median(n_scans), .groups = "drop")
data.table::fwrite(coverage, file.path(P$tables, "threeh_coverage.csv"))
print(coverage)

# ---- relationship ------------------------------------------------------------------
use <- filter(primary, usable)
stats <- bind_rows(
  use |> group_by(convention) |> group_modify(~ relstats(.x)) |> ungroup() |> mutate(site = "all sites"),
  use |> group_by(convention, site) |> group_modify(~ relstats(.x)) |> ungroup()
) |> relocate(convention, site)
data.table::fwrite(stats, file.path(P$tables, "threeh_stats_by_site.csv"))
print(select(stats, convention, site, n, pearson_r, pearson_p, spearman_rho, rma_slope, median_h_eff_km))

anom_stats <- map(CFG$threeh_stamp_conventions, function(cv) {
  an <- add_month_anomalies(filter(use, convention == cv), CFG$min_days_per_site_month)
  bind_rows(anomstats(an) |> mutate(site = "all sites"),
            an |> group_by(site) |> group_modify(~ anomstats(.x)) |> ungroup()) |>
    mutate(convention = cv)
}) |> list_rbind() |> relocate(convention, site)
data.table::fwrite(anom_stats, file.path(P$tables, "threeh_stats_within_month_anomalies.csv"))
print(anom_stats)

# Pooled regression with site and month-of-year effects
month_fx <- map(CFG$threeh_stamp_conventions, function(cv) {
  d <- filter(use, convention == cv)
  if (nrow(d) < 12 || n_distinct(month(d$sample_date)) < 2) return(NULL)
  fml <- if (n_distinct(d$site) > 1) hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date)) + site
         else hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date))
  co <- summary(lm(fml, data = d))$coefficients
  tibble(convention = cv, n = nrow(d), estimate = co["tempo_vc_1e15", 1],
         std_error = co["tempo_vc_1e15", 2], p_value = co["tempo_vc_1e15", 4])
}) |> list_rbind()
if (!is.null(month_fx)) data.table::fwrite(month_fx, file.path(P$tables, "threeh_month_effects_lm.csv"))

sens <- matched |>
  filter(usable) |>
  group_by(convention, max_ecf, block_label) |>
  summarise(n = n(),
            spearman_rho = suppressWarnings(cor(tempo_vc, hcho_ugm3, method = "spearman")),
            pearson_r = cor(tempo_vc, hcho_ugm3), .groups = "drop")
data.table::fwrite(sens, file.path(P$tables, "threeh_sensitivity.csv"))

# ---- smoke (NOAA HMS) -------------------------------------------------------------------
smoke_path <- file.path(P$processed, "smoke_flags.csv")
if (file.exists(smoke_path) && nrow(use)) {
  smoke3 <- read_tbl(smoke_path, colClasses = list(character = "stamp_local")) |>
    filter(arm == "threeh") |>
    select(site, stamp_key = stamp_local, convention, hms_available, smoke_any, smoke_class)
  use_s <- use |>
    mutate(stamp_key = format(stamp_local, "%Y-%m-%d %H:%M")) |>
    left_join(smoke3, by = c("site", "stamp_key", "convention"))
  if (!any(!is.na(use_s$smoke_any))) {
    log_msg("No HMS coverage for the 3-h windows - skipping smoke stratification")
  } else {
  smoke_stats3 <- bind_rows(
    use_s |> filter(!is.na(smoke_any)) |> group_by(convention, smoke_any) |>
      group_modify(~ relstats(.x)) |> ungroup() |> mutate(subset = "by smoke flag"),
    use_s |> filter(smoke_any %in% FALSE) |> group_by(convention) |>
      group_modify(~ relstats(.x)) |> ungroup() |> mutate(subset = "smoke windows excluded")
  ) |> relocate(subset, convention, smoke_any)
  data.table::fwrite(smoke_stats3, file.path(P$tables, "threeh_stats_by_smoke.csv"))
  print(select(smoke_stats3, any_of(c("subset", "convention", "smoke_any", "n", "pearson_r", "spearman_rho"))))
  }
} else {
  log_msg("No smoke_flags.csv (run R/08_smoke_hms.R) - skipping smoke analysis")
}

# ---- figures ------------------------------------------------------------------------
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))
U_UGM3 <- "\u00b5g/m\u00b3"; U_COL <- "10\u00b9\u2075 molec/cm\u00b2"; U_RHO <- "\u03c1"
season_cols <- c(DJF = "#3b6fb6", MAM = "#5aa469", JJA = "#d9822b", SON = "#8a5fb0")
conv_lab <- function(x) factor(x, levels = c("start", "end"),
                               labels = c("stamp = start (09-12 MST)", "stamp = end (06-09 MST)"))

site_stats <- filter(stats, site != "all sites", !is.na(pearson_r)) |> mutate(convention = conv_lab(convention))
if (nrow(use)) {
  p7 <- ggplot(mutate(use, convention = conv_lab(convention)), aes(tempo_vc_1e15, hcho_ugm3)) +
    geom_point(aes(colour = season), size = 1.6, alpha = 0.85) +
    geom_abline(data = filter(site_stats, !is.na(rma_slope)),
                aes(slope = rma_slope, intercept = rma_intercept), linewidth = 0.6) +
    geom_text(data = site_stats, aes(x = -Inf, y = Inf,
              label = sprintf("n=%d  r=%.2f  %s=%.2f", n, pearson_r, U_RHO, spearman_rho)),
              hjust = -0.05, vjust = 1.3, size = 3) +
    facet_grid(convention ~ site, scales = "free") +
    scale_colour_manual(values = season_cols, drop = FALSE) +
    labs(x = paste0("TEMPO HCHO column, mean of screened scans in the 3-h window (", U_COL, ")"),
         y = paste0("Surface HCHO, 3-h (", U_UGM3, ")"), colour = NULL,
         title = "3-hour samples vs TEMPO scans in the sampling window (RMA line where r is significant)")
  ggsave(file.path(P$figures, "fig7_threeh_scatter.png"), p7, width = 9, height = 7, dpi = 300)
  log_msg("  figure: fig7_threeh_scatter.png")
}
p8 <- ggplot(mutate(sens, convention = conv_lab(convention)),
             aes(factor(max_ecf), spearman_rho, colour = block_label, group = block_label)) +
  geom_line() + geom_point(aes(size = n)) + facet_wrap(~ convention) +
  scale_size_continuous(range = c(1.5, 4)) +
  labs(x = "Maximum effective cloud fraction", y = paste("Pooled Spearman", U_RHO),
       colour = "Block", size = "n", title = "3-hour arm: sensitivity to screening and stamp convention")
ggsave(file.path(P$figures, "fig8_threeh_sensitivity.png"), p8, width = 8, height = 4, dpi = 300)
log_msg("  figure: fig8_threeh_sensitivity.png")
log_msg("3-hour arm done.")
