# =============================================================================
# 05_analysis.R - statistics, sensitivity and figures
#
# Relationship between daily TEMPO HCHO column and 24-h surface HCHO:
#   per site and season: n, Pearson r, Spearman rho, OLS and reduced-major-axis
#   (RMA) slopes with bootstrap CIs, median effective mixing height
#   pooled: linear mixed model with site random intercepts (if lme4 installed)
# Outputs in output/tables and output/figures
# =============================================================================
source("R/00_config.R")
set.seed(42)

primary  <- read_tbl(file.path(P$processed, "matched_primary.csv")) |>
  mutate(sample_date = as.Date(sample_date), season = factor(season, levels = c("DJF", "MAM", "JJA", "SON")))
variants <- read_tbl(file.path(P$processed, "matched_variants.csv")) |>
  mutate(sample_date = as.Date(sample_date))
use <- filter(primary, usable)

site_levels <- primary |> group_by(site) |> summarise(lon = first(lon)) |> arrange(lon) |> pull(site)  # west -> east
lab <- function(d) mutate(d, site = factor(site, levels = site_levels))

source("R/helpers_stats.R")   # rma_fit, relstats, add_month_anomalies, anomstats

# ---- 1. coverage -----------------------------------------------------------------
coverage <- primary |>
  group_by(site, site_name, program) |>
  summarise(coatts_days = n(),
            days_with_any_tempo_scan = sum(n_scans > 0),
            days_with_screened_tempo = sum(usable),
            usable_pct = round(100 * mean(usable), 1),
            median_valid_scans_per_day = median(n_valid_scans),
            .groups = "drop")
data.table::fwrite(coverage, file.path(P$tables, "coverage_by_site.csv"))
print(coverage)

# ---- 2. relationship by site, season, pooled ------------------------------------------
by_site   <- use |> group_by(site, site_name) |> group_modify(~ relstats(.x)) |> ungroup()
by_season <- use |> group_by(season) |> group_modify(~ relstats(.x)) |> ungroup()
by_site_season <- use |> group_by(site, season) |> group_modify(~ relstats(.x, nboot = 200)) |> ungroup()
pooled    <- relstats(use) |> mutate(group = "all sites")
data.table::fwrite(by_site, file.path(P$tables, "stats_by_site.csv"))
data.table::fwrite(by_season, file.path(P$tables, "stats_by_season.csv"))
data.table::fwrite(by_site_season, file.path(P$tables, "stats_by_site_season.csv"))
data.table::fwrite(pooled, file.path(P$tables, "stats_pooled.csv"))
print(by_site |> select(site, n, pearson_r, spearman_rho, rma_slope, median_h_eff_km))

# Mixed model: surface ~ column + season, random intercept by site
if (requireNamespace("lme4", quietly = TRUE) && n_distinct(use$site) >= 3) {
  fml <- if (n_distinct(use$season) >= 2) hcho_ugm3 ~ tempo_vc_1e15 + season + (1 | site) else hcho_ugm3 ~ tempo_vc_1e15 + (1 | site)
  m <- lme4::lmer(fml, data = mutate(use, season = droplevels(season)))
  fe <- summary(m)$coefficients
  mm <- tibble(term = rownames(fe), estimate = fe[, 1], std_error = fe[, 2], t_value = fe[, 3])
  data.table::fwrite(mm, file.path(P$tables, "mixed_model_fixed_effects.csv"))
  capture.output(summary(m), file = file.path(P$tables, "mixed_model_summary.txt"))
  print(mm)
} else {
  log_msg("lme4 not installed or < 3 sites - skipping mixed model")
}

# Same model with month-of-year effects (4 seasons leave within-season trends,
# e.g. the Sep -> Nov decline, in the column term)
if (requireNamespace("lme4", quietly = TRUE) && n_distinct(use$site) >= 3) {
  m2 <- lme4::lmer(hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date)) + (1 | site), data = use)
  fe2 <- summary(m2)$coefficients
  data.table::fwrite(tibble(term = rownames(fe2), estimate = fe2[, 1], std_error = fe2[, 2], t_value = fe2[, 3]),
                     file.path(P$tables, "mixed_model_month_effects.csv"))
  log_msg("Mixed model with month effects: column slope ", signif(fe2["tempo_vc_1e15", 1], 3),
          " (t = ", signif(fe2["tempo_vc_1e15", 3], 3), ")")
}

# ---- 2b. within-month anomalies (removes the shared seasonal cycle) -------------------
# Both quantities peak in summer, so correlations over the year partly reflect
# seasonality. Demeaning within each site x calendar month keeps only
# day-to-day covariation. p-values ignore the degrees of freedom used by the
# monthly means and are therefore optimistic.
anom <- add_month_anomalies(use, CFG$min_days_per_site_month)
anom_stats <- bind_rows(
  anomstats(anom) |> mutate(site = "all sites", .before = 1),
  anom |> group_by(site) |> group_modify(~ anomstats(.x)) |> ungroup()
)
data.table::fwrite(anom_stats, file.path(P$tables, "stats_within_month_anomalies.csv"))
print(anom_stats)

# ---- 3. sensitivity to screening choices ---------------------------------------------
sens <- variants |>
  filter(usable) |>
  group_by(max_ecf, block_label, window) |>
  summarise(n = n(),
            spearman_rho = suppressWarnings(cor(tempo_vc, hcho_ugm3, method = "spearman")),
            pearson_r = cor(tempo_vc, hcho_ugm3),
            median_h_eff_km = median(h_eff_km, na.rm = TRUE),
            .groups = "drop")
data.table::fwrite(sens, file.path(P$tables, "sensitivity_screening.csv"))

# ---- 3b. smoke (NOAA HMS) ------------------------------------------------------------
smoke_path <- file.path(P$processed, "smoke_flags.csv")
has_smoke <- file.exists(smoke_path)
if (has_smoke) {
  smoke24 <- read_tbl(smoke_path) |>
    filter(arm == "coatts") |>
    transmute(site, sample_date = as.Date(sample_date), hms_available, smoke_any,
              smoke_class = factor(smoke_class, levels = c("none", "light", "medium/heavy")))
  primary_s <- left_join(primary, smoke24, by = c("site", "sample_date"))
  use_s <- filter(primary_s, usable)

  # TEMPO data loss on smoke days (smoke is often screened out as cloud)
  smoke_cov <- primary_s |>
    group_by(smoke_class) |>
    summarise(coatts_days = n(), days_with_screened_tempo = sum(usable),
              usable_pct = round(100 * mean(usable), 1),
              median_surface_ugm3 = median(hcho_ugm3, na.rm = TRUE), .groups = "drop")
  data.table::fwrite(smoke_cov, file.path(P$tables, "smoke_coverage.csv"))
  print(smoke_cov)

  # Smoke days are mostly summer, when skies are clearer and the boundary layer is
  # deeper, so compare smoke classes within season as well
  smoke_season <- primary_s |>
    filter(!is.na(smoke_class)) |>
    group_by(season, smoke_class) |>
    summarise(coatts_days = n(), usable_pct = round(100 * mean(usable), 1),
              median_surface_ugm3 = median(hcho_ugm3, na.rm = TRUE),
              median_tempo_1e15 = median(tempo_vc_1e15[usable], na.rm = TRUE),
              median_h_eff_km = median(h_eff_km[usable], na.rm = TRUE),
              .groups = "drop")
  data.table::fwrite(smoke_season, file.path(P$tables, "smoke_by_season.csv"))
  print(smoke_season, n = Inf)

  smoke_stats <- bind_rows(
    use_s |> group_by(smoke_class) |> group_modify(~ relstats(.x)) |> ungroup() |>
      mutate(subset = "by smoke class"),
    relstats(filter(use_s, smoke_any %in% FALSE)) |> mutate(subset = "all sites, smoke days excluded")
  ) |> relocate(subset, smoke_class)
  data.table::fwrite(smoke_stats, file.path(P$tables, "stats_by_smoke.csv"))
  print(select(smoke_stats, subset, smoke_class, n, pearson_r, spearman_rho, median_h_eff_km))

  anom_ns <- add_month_anomalies(filter(use_s, smoke_any %in% FALSE), CFG$min_days_per_site_month)
  anom_smoke_stats <- bind_rows(
    anomstats(anom) |> mutate(subset = "all days"),
    anomstats(anom_ns) |> mutate(subset = "smoke days excluded")
  ) |> relocate(subset)
  data.table::fwrite(anom_smoke_stats, file.path(P$tables, "stats_within_month_anomalies_smoke_sensitivity.csv"))
  print(anom_smoke_stats)
} else {
  log_msg("No smoke_flags.csv (run R/08_smoke_hms.R) - skipping smoke analysis")
}

# ---- 4. figures ----------------------------------------------------------------
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))
# unit labels as unicode escapes so the source file is plain ASCII
U_UGM3 <- "\u00b5g/m\u00b3"
U_COL  <- "10\u00b9\u2075 molec/cm\u00b2"
U_RHO  <- "\u03c1"
season_cols <- c(DJF = "#3b6fb6", MAM = "#5aa469", JJA = "#d9822b", SON = "#8a5fb0")
save_fig <- function(p, name, w, h) {
  ggsave(file.path(P$figures, name), p, width = w, height = h, dpi = 300)
  log_msg("  figure: ", name)
}

# 4a. time series (surface and column on separate rows)
ts <- primary |>
  lab() |>
  transmute(site, sample_date, surface = hcho_ugm3, column = tempo_vc_1e15) |>
  pivot_longer(c(surface, column), names_to = "metric", values_to = "value") |>
  filter(!is.na(value)) |>
  mutate(metric = factor(metric, levels = c("surface", "column"),
                         labels = c(paste0("Surface HCHO (", U_UGM3, ", 24-h)"),
                                    paste0("TEMPO column (", U_COL, ")"))))
p1 <- ggplot(ts, aes(sample_date, value)) +
  geom_line(colour = "grey70", linewidth = 0.3) + geom_point(size = 0.8) +
  facet_grid(metric ~ site, scales = "free_y", switch = "y") +
  labs(x = NULL, y = NULL, title = "COATTS 24-h formaldehyde and same-day TEMPO HCHO column") +
  theme(strip.placement = "outside", axis.text.x = element_text(angle = 45, hjust = 1))
save_fig(p1, "fig1_timeseries.png", 3 + 2.2 * n_distinct(ts$site), 5)

# 4b. scatter by site with RMA line
rma_lines <- by_site |> filter(!is.na(rma_slope)) |> lab()
p2 <- ggplot(lab(use), aes(tempo_vc_1e15, hcho_ugm3)) +
  geom_point(aes(colour = season), size = 1.4, alpha = 0.8) +
  geom_abline(data = rma_lines, aes(slope = rma_slope, intercept = rma_intercept), linewidth = 0.6) +
  geom_text(data = lab(filter(by_site, !is.na(pearson_r))), aes(x = -Inf, y = Inf, label = sprintf("n=%d  r=%.2f  %s=%.2f", n, pearson_r, U_RHO, spearman_rho)),
            hjust = -0.05, vjust = 1.3, size = 3) +
  facet_wrap(~ site, scales = "free") +
  scale_colour_manual(values = season_cols) +
  labs(x = paste0("TEMPO HCHO column, daily mean of screened scans (", U_COL, ")"),
       y = paste0("Surface HCHO, 24-h (", U_UGM3, ")"), colour = NULL,
       title = "Surface vs column formaldehyde (RMA line shown where r is significant)")
save_fig(p2, "fig2_scatter_by_site.png", 11, 7)

# 4c. effective mixing height by month vs TEMPO PBL height
# H_eff is undefined when the daily column is <= 0 (TEMPO noise at low columns); those days are left out
heff <- use |> filter(is.finite(h_eff_km)) |> lab() |>
  mutate(month = factor(month(sample_date), levels = 1:12, labels = month.abb))
pbl_m <- heff |> group_by(site, month) |> summarise(pbl = median(tempo_pbl_km, na.rm = TRUE), .groups = "drop")
p3 <- ggplot(heff, aes(month, h_eff_km)) +
  geom_boxplot(outlier.size = 0.6, fill = "grey90") +
  geom_point(data = pbl_m, aes(month, pbl), colour = "#d9822b", shape = 18, size = 2.5) +
  facet_wrap(~ site) +
  coord_cartesian(ylim = c(0, quantile(heff$h_eff_km, 0.98, na.rm = TRUE))) +
  labs(x = NULL, y = "H_eff = column / surface density (km)",
       title = "Effective mixing height; orange = median TEMPO PBL height on matched days") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5))
save_fig(p3, "fig3_effective_height_by_month.png", 11, 7)

# 4d. coverage by month
cov_m <- primary |> lab() |>
  mutate(month = floor_date(sample_date, "month"),
         status = case_when(usable ~ "TEMPO value", n_scans == 0 ~ "no TEMPO scan", TRUE ~ "no screened scan")) |>
  count(site, month, status)
p4 <- ggplot(cov_m, aes(month, n, fill = status)) +
  geom_col(width = 25) + facet_wrap(~ site) +
  scale_fill_manual(values = c(`TEMPO value` = "#3b6fb6", `no screened scan` = "grey75", `no TEMPO scan` = "grey45")) +
  labs(x = NULL, y = "COATTS sample days", fill = NULL, title = "Matched-day coverage (primary screening)")
save_fig(p4, "fig4_coverage.png", 11, 6)

# 4e. sensitivity
p5 <- ggplot(sens, aes(factor(max_ecf), spearman_rho, colour = block_label, group = block_label)) +
  geom_line() + geom_point(aes(size = n)) + facet_wrap(~ window) +
  scale_size_continuous(range = c(1.5, 4)) +
  labs(x = "Maximum effective cloud fraction", y = paste("Pooled Spearman", U_RHO), colour = "Block", size = "n",
       title = "Sensitivity of the surface-column relationship to screening")
save_fig(p5, "fig5_sensitivity.png", 8, 4)

# 4f. within-month anomalies
if (nrow(anom) >= 6) {
  r_all <- anom_stats$pearson_r[anom_stats$site == "all sites"]
  p6 <- ggplot(lab(anom), aes(column_anom, surface_anom)) +
    geom_hline(yintercept = 0, colour = "grey70") + geom_vline(xintercept = 0, colour = "grey70") +
    geom_point(aes(colour = site), size = 1.4, alpha = 0.8) +
    geom_smooth(method = "lm", formula = y ~ x, colour = "black", linewidth = 0.6, se = TRUE) +
    labs(x = paste0("TEMPO column minus site-month mean (", U_COL, ")"),
         y = paste0("Surface HCHO minus site-month mean (", U_UGM3, ")"), colour = NULL,
         title = sprintf("Day-to-day covariation after removing site-month means (pooled r = %.2f, n = %d)",
                         r_all, nrow(anom)))
  save_fig(p6, "fig6_within_month_anomalies.png", 8, 5.5)
}

# 4g. smoke-stratified scatter
if (has_smoke && nrow(filter(use_s, !is.na(smoke_class)))) {
  lab_s <- use_s |> filter(!is.na(smoke_class)) |> count(smoke_class) |>
    left_join(filter(smoke_stats, subset == "by smoke class") |> select(smoke_class, pearson_r), by = "smoke_class")
  p9 <- ggplot(lab(filter(use_s, !is.na(smoke_class))), aes(tempo_vc_1e15, hcho_ugm3)) +
    geom_point(aes(colour = site), size = 1.3, alpha = 0.8) +
    geom_smooth(method = "lm", formula = y ~ x, colour = "black", linewidth = 0.6, se = FALSE) +
    geom_text(data = lab_s, aes(x = -Inf, y = Inf, label = sprintf("n=%d  r=%.2f", n, pearson_r)),
              hjust = -0.1, vjust = 1.4, size = 3.2) +
    facet_wrap(~ smoke_class) +
    labs(x = paste0("TEMPO HCHO column, daily mean (", U_COL, ")"),
         y = paste0("Surface HCHO, 24-h (", U_UGM3, ")"), colour = NULL,
         title = "COATTS vs TEMPO by NOAA HMS smoke class on the sample day")
  save_fig(p9, "fig9_smoke_stratified.png", 10, 4.5)
}

log_msg("Done. Tables in ", P$tables, "; figures in ", P$figures)
