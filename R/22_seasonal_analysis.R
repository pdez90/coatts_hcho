# =============================================================================
# 22_seasonal_analysis.R - agreement by season, nationally
#
# The only earlier national surface-satellite HCHO comparison (Wang et al.,
# 2022: OMI vs AQS, 2006-2015) worked in seasonal means and found agreement in
# summer but not in winter, with satellite seasonal variability 20-100 % larger
# than at the surface. This step asks the same questions of TEMPO, three ways:
#
#  A. Pooled correlation by season: every matched sample in the season, all
#     sites together (site-clustered bootstrap interval for r).
#  B. Day-to-day correlation by season: within-month anomalies (site x
#     year-month, >= CFG$min_days_per_site_month), grouped by the season of the
#     month; within-site-month permutation p-value, as everywhere else.
#  C. Spatial correlation of seasonal means - the comparison closest to Wang's:
#     for each season, each site's mean surface HCHO against its mean column,
#     over sites with >= MIN_SEASON_SAMPLES matched samples in that season
#     (Wang required six surface samples per season).
#  D. Seasonal amplitude: at sites with >= MIN_SEASON_SAMPLES in all four
#     seasons, (max - min of the four seasonal means) / their mean, for the
#     column and for the surface, and the summer-to-winter (JJA/DJF) ratio.
#
# Inputs : data/processed/aqs_matched_primary.csv.gz  (step 13)
# Outputs: output/tables/national_seasonal.csv            (A, B by duration x season)
#          output/tables/national_seasonal_spatial.csv    (C)
#          output/tables/national_seasonal_amplitude.csv  (D, one row per site)
#          output/tables/manuscript_numbers_22.csv
#          output/figures/fig24_seasonal.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_stats.R")
set.seed(42)
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))

primary_path <- file.path(P$processed, "aqs_matched_primary.csv.gz")
if (!file.exists(primary_path)) stop("Missing ", primary_path, " - run step 13 first.")

MIN_SEASON_SAMPLES <- 6L      # site-season means (C, D); Wang et al. (2022) used six per season
NBOOT              <- 2000L   # cluster bootstrap for the pooled r
SEASONS            <- c("DJF", "MAM", "JJA", "SON")
DURATIONS          <- c("24 h", "8 h")   # 3 h: four sites, too few to split by season

use <- read_tbl(primary_path, colClasses = list(character = c("site_id", "site", "qualifiers"))) |>
  filter(lag_h == 0, usable, duration_class %in% DURATIONS) |>
  mutate(sample_date = as.Date(sample_date),
         season = factor(as.character(season_of(sample_date)), levels = SEASONS))
log_msg(nrow(use), " usable matched samples (", paste(DURATIONS, collapse = ", "), ") at ",
        n_distinct(use$site), " sites")

# Pearson r with a site-clustered bootstrap interval (boot_index falls back to
# rows below five sites; the basis is returned and written to the table)
boot_r <- function(x, y, cl) {
  bi <- boot_index(length(x), cl)
  b <- replicate(NBOOT, { k <- bi$draw(); suppressWarnings(cor(x[k], y[k])) })
  ok <- is.finite(b)
  list(lo = if (any(ok)) quantile(b[ok], 0.025)[[1]] else NA_real_,
       hi = if (any(ok)) quantile(b[ok], 0.975)[[1]] else NA_real_,
       basis = bi$basis)
}
# p-values as keys: three decimals, and "<0.001" rather than "0.000"
pkey <- function(p) ifelse(is.na(p), NA_character_, ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))

col_or_na <- function(t, col) if (col %in% names(t)) t[[col]][1] else NA_real_

# ---- A and B: pooled and day-to-day correlation by season -------------------
anom <- use |>
  group_by(duration_class) |>
  group_modify(~ add_month_anomalies(.x, CFG$min_days_per_site_month)) |>
  ungroup()

by_season <- map_dfr(DURATIONS, function(dc) map_dfr(SEASONS, function(s) {
  d  <- filter(use,  duration_class == dc, season == s)
  da <- filter(anom, duration_class == dc, season == s)
  if (nrow(d) < 6) return(tibble(duration_class = dc, season = s, n = nrow(d)))
  ci <- boot_r(d$tempo_vc_1e15, d$hcho_ugm3, d$site)
  an <- if (nrow(da) >= 6) anomstats(da) else tibble(n = nrow(da))
  tibble(duration_class = dc, season = s, n = nrow(d), n_sites = n_distinct(d$site),
         pearson_r = cor(d$tempo_vc_1e15, d$hcho_ugm3), r_lo = ci$lo, r_hi = ci$hi, ci_basis = ci$basis,
         median_surface_ugm3 = median(d$hcho_ugm3), median_tempo_1e15 = median(d$tempo_vc_1e15),
         anom_n = an$n, anom_site_months = col_or_na(an, "site_months"),
         anom_pearson_r = col_or_na(an, "pearson_r"),
         anom_pearson_p_perm = col_or_na(an, "pearson_p_perm"))
}))
data.table::fwrite(by_season, file.path(P$tables, "national_seasonal.csv"))
print(by_season |> select(duration_class, season, n, n_sites, pearson_r, r_lo, r_hi,
                          anom_n, anom_pearson_r, anom_pearson_p_perm), n = Inf)

# ---- C: spatial correlation of site-season means (24 h) ----------------------
site_season <- use |>
  filter(duration_class == "24 h") |>
  group_by(site, season) |>
  summarise(n = n(), surface = mean(hcho_ugm3), column = mean(tempo_vc_1e15), .groups = "drop") |>
  filter(n >= MIN_SEASON_SAMPLES)
spatial <- site_season |>
  group_by(season) |>
  summarise(n_sites = n(),
            spatial_r = if (n() >= 6) cor(column, surface) else NA_real_,
            spatial_p = if (n() >= 6) cor.test(column, surface)$p.value else NA_real_,
            spatial_rho = if (n() >= 6) suppressWarnings(cor(column, surface, method = "spearman")) else NA_real_,
            .groups = "drop") |>
  arrange(season)
data.table::fwrite(spatial, file.path(P$tables, "national_seasonal_spatial.csv"))
print(spatial)

# ---- D: seasonal amplitude, column against surface (24 h) --------------------
amp <- site_season |>
  group_by(site) |>
  filter(n_distinct(season) == length(SEASONS)) |>
  summarise(surface_amp = (max(surface) - min(surface)) / mean(surface),
            column_amp  = (max(column)  - min(column))  / mean(column),
            surface_jja_djf = surface[season == "JJA"] / surface[season == "DJF"],
            column_jja_djf  = column[season == "JJA"]  / column[season == "DJF"],
            .groups = "drop") |>
  mutate(amp_ratio = column_amp / surface_amp)
data.table::fwrite(amp, file.path(P$tables, "national_seasonal_amplitude.csv"))
log_msg("Seasonal amplitude at ", nrow(amp), " 24 h sites with >= ", MIN_SEASON_SAMPLES,
        " samples in every season: column/surface amplitude ratio median ",
        sprintf("%.2f", median(amp$amp_ratio)), " (IQR ", sprintf("%.2f", quantile(amp$amp_ratio, 0.25)),
        "-", sprintf("%.2f", quantile(amp$amp_ratio, 0.75)), "); JJA/DJF surface ",
        sprintf("%.2f", median(amp$surface_jja_djf)), ", column ", sprintf("%.2f", median(amp$column_jja_djf)))

# ---- manuscript numbers ------------------------------------------------------
g <- function(dc, s, col) by_season[[col]][by_season$duration_class == dc & by_season$season == s]
tag <- function(dc) sub(" h", "", dc)
k1 <- map_dfr(DURATIONS, function(dc) map_dfr(SEASONS, function(s) tibble(
  key = paste0(c("seas_r_", "seas_rlo_", "seas_rhi_", "seas_n_", "seas_dd_", "seas_ddn_", "seas_ddp_"),
               tag(dc), "_", tolower(s)),
  value = c(sprintf("%.2f", g(dc, s, "pearson_r")), sprintf("%.2f", g(dc, s, "r_lo")),
            sprintf("%.2f", g(dc, s, "r_hi")), as.character(g(dc, s, "n")),
            sprintf("%.2f", g(dc, s, "anom_pearson_r")), as.character(g(dc, s, "anom_n")),
            pkey(g(dc, s, "anom_pearson_p_perm"))))))
k2 <- tibble(key = c(paste0("seas_sp_", tolower(spatial$season)), paste0("seas_spn_", tolower(spatial$season)),
                     paste0("seas_spp_", tolower(spatial$season))),
             value = c(sprintf("%.2f", spatial$spatial_r), as.character(spatial$n_sites),
                       pkey(spatial$spatial_p)))
k3 <- tibble(key = c("seas_min_samples", "seas_n_8_total", "seas_amp_sites", "seas_amp_ratio_median", "seas_amp_ratio_q25",
                     "seas_amp_ratio_q75", "seas_jja_djf_surface", "seas_jja_djf_column"),
             value = c(MIN_SEASON_SAMPLES, sum(by_season$n[by_season$duration_class == "8 h"]), nrow(amp),
                       sprintf("%.2f", median(amp$amp_ratio)),
                       sprintf("%.2f", quantile(amp$amp_ratio, 0.25)), sprintf("%.2f", quantile(amp$amp_ratio, 0.75)),
                       sprintf("%.2f", median(amp$surface_jja_djf)), sprintf("%.2f", median(amp$column_jja_djf))))
nums <- bind_rows(k1, k2, k3) |> mutate(value = as.character(value), source = "R/22_seasonal_analysis.R")
data.table::fwrite(nums, file.path(P$tables, "manuscript_numbers_22.csv"))

# ---- figure ------------------------------------------------------------------
pa_d <- bind_rows(
  by_season |> transmute(duration_class, season, kind = "pooled (whole period)", r = pearson_r, lo = r_lo, hi = r_hi, n),
  by_season |> transmute(duration_class, season, kind = "day-to-day (within-month anomalies)", r = anom_pearson_r,
                         lo = NA_real_, hi = NA_real_, n = anom_n)) |>
  mutate(season = factor(season, levels = SEASONS)) |>
  # 8 h samples are almost all summer (PAMS season), so only 24 h is drawn by
  # season; the 8 h rows stay in national_seasonal.csv and Table S11
  filter(duration_class == "24 h") |>
  # labels off the point and clear of the error bars and connecting lines:
  # pooled below-right, day-to-day above-left
  mutate(pooled = kind == "pooled (whole period)",
         lab_hjust = ifelse(pooled, -0.3, 1.2), lab_vjust = ifelse(pooled, 1.6, -0.7))
pa <- ggplot(pa_d, aes(season, r, colour = kind, group = kind)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  # the two series are dodged sideways so their points, intervals and labels
  # never sit on top of each other (autumn has r 0.32 and 0.35)
  geom_line(linewidth = 0.6, position = position_dodge(width = 0.3)) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.12, na.rm = TRUE, position = position_dodge(width = 0.3)) +
  geom_point(size = 2.4, position = position_dodge(width = 0.3)) +
  geom_text(aes(label = n, hjust = lab_hjust, vjust = lab_vjust), size = 2.6, show.legend = FALSE,
            position = position_dodge(width = 0.3)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00"), name = NULL) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.15))) +
  labs(x = NULL, y = "Pearson r, TEMPO column vs surface HCHO",
       title = "(a) 24 h samples by season (labels: samples or anomaly pairs)") +
  theme(legend.position = "bottom", plot.title = element_text(size = 11))
pb <- ggplot(mutate(site_season, season = factor(season, levels = SEASONS)), aes(column, surface)) +
  geom_point(alpha = 0.6, size = 1.4, colour = "#0072B2") +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "grey30", linewidth = 0.5) +
  geom_text(data = mutate(spatial, season = factor(season, levels = SEASONS)),
            aes(x = -Inf, y = Inf, label = sub("^r = -", "r = \u2212", sprintf("r = %.2f (%d sites)", spatial_r, n_sites))),
            hjust = -0.1, vjust = 1.4, size = 2.8, inherit.aes = FALSE) +
  facet_wrap(~ season, nrow = 1, scales = "free") +
  labs(x = expression("Site-season mean column ("*10^15~molecules~cm^-2*")"),
       y = expression("Site-season mean surface HCHO ("*mu*g~m^-3*")"),
       title = sprintf("(b) Seasonal means across 24 h sites (\u2265 %d samples per site-season)", MIN_SEASON_SAMPLES)) +
  theme(plot.title = element_text(size = 11))
fig <- if (requireNamespace("patchwork", quietly = TRUE)) {
  patchwork::wrap_plots(pa, pb, ncol = 1, heights = c(1.1, 1))
} else {
  log_msg("  patchwork not installed - fig24 holds panel (a) only")
  pa
}
ggsave(file.path(P$figures, "fig24_seasonal.png"), fig, width = 9, height = 8, dpi = 300)
log_msg("  figure: fig24_seasonal.png")
log_msg("Seasonal analysis done.")
