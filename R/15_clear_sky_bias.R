# =============================================================================
# 15_clear_sky_bias.R - are the days TEMPO can observe representative?
#
# Cloud screening is only one of the reasons a sample day ends up without a
# usable TEMPO observation, so this step does two things. First it attributes
# screening failures: for every site-day that TEMPO observed but where no scan
# passed the full screen, it asks which single criterion, if relaxed, would have
# rescued the day. Second it compares surface HCHO between days with and without
# a usable observation. The contrast is therefore one of OBSERVABILITY, not of
# cloud cover, and the terminology throughout says so.
#
# Goldberg et al. (2025) found the corresponding effect for NO2 and interpreted
# it partly through slower photochemical loss under cloud. We report the sign and
# size of the HCHO effect; the covariates of cloudiness (temperature, biogenic
# emissions, boundary-layer depth, transport) are not separated here.
#
# Inference: observations are nested within monitors, so the fixed-effects
# standard error is cluster-robust by site (CR1), and the paired site-month
# difference carries a site-cluster bootstrap interval.
#
# Inputs : data/processed/matched_primary.csv        (Colorado, 24 h)
#          data/processed/aqs_matched_primary.csv.gz (national, 24 h)
#          data/processed/tempo_site_cells.csv.gz + tempo_manifest.csv
#          data/processed/aqs_tempo_site_cells.csv.gz
# Outputs: output/tables/observability_day_types.csv
#          output/tables/observability_screen_attribution.csv
#          output/tables/observability_bias.csv
#          output/tables/observability_bias_fixed_effects.csv
#          output/figures/fig14_observability_bias.png
# =============================================================================
source("R/00_config.R")
set.seed(42)

is_true <- function(x) x %in% c(TRUE, "TRUE", "True", "true", "1", 1)
NBOOT <- 2000L
MIN_SITES_CI <- 5L   # fewest site clusters for which a bootstrap interval is reported

# ---- 1. the two arms, 24 h samples only --------------------------------------
co <- read_tbl(file.path(P$processed, "matched_primary.csv")) |>
  transmute(arm = "Colorado (24 h)", site, sample_date = as.Date(sample_date),
            season, hcho_ugm3, n_scans,
            mean_ecf = suppressWarnings(as.numeric(mean_ecf)),
            usable = is_true(usable))

nat <- read_tbl(file.path(P$processed, "aqs_matched_primary.csv.gz"),
                colClasses = list(character = c("site", "site_id"))) |>
  filter(duration_class == "24 h", lag_h == 0) |>
  transmute(arm = "National (24 h)", site, sample_date = as.Date(sample_date),
            season, hcho_ugm3, n_scans, mean_ecf = NA_real_, usable = is_true(usable))

d <- bind_rows(co, nat) |>
  filter(!is.na(hcho_ugm3)) |>
  mutate(day_type = case_when(usable ~ "usable",
                              n_scans > 0 ~ "screened out",
                              TRUE ~ "no granule"),
         ym = format(sample_date, "%Y-%m"))

types <- d |>
  group_by(arm, day_type) |>
  summarise(days = n(), median_ecf = suppressWarnings(median(mean_ecf, na.rm = TRUE)),
            median_hcho = median(hcho_ugm3), .groups = "drop") |>
  group_by(arm) |> mutate(pct = round(100 * days / sum(days), 1)) |> ungroup()
data.table::fwrite(types, file.path(P$tables, "observability_day_types.csv"))
print(types)
for (a in unique(types$arm)) {
  t <- filter(types, arm == a)
  log_msg(a, ": ", paste(sprintf("%s %d (%.1f%%)", t$day_type, t$days, t$pct), collapse = "; "))
}

# ---- 1b. why does screening reject a day? ------------------------------------
# For each site-day TEMPO observed, evaluate the 3 x 3 block under the full
# screen and under the screen with one criterion relaxed at a time. A scan is
# valid when at least half the block's cells pass; a day is usable when at least
# one scan is valid. "Rescued by cloud" means the day becomes usable if the
# effective cloud fraction threshold alone is dropped.
attribute <- function(cells_path, label, day_from) {
  if (!file.exists(cells_path)) { log_msg("  ", basename(cells_path), " absent; attribution skipped"); return(NULL) }
  cols <- c("granule", "site", "di", "dj", "cell_lon", "scan_start_utc",
            "main_data_quality_flag", "eff_cloud_fraction",
            "snow_ice_fraction", "solar_zenith_angle")
  cells <- data.table::fread(cells_path, select = cols, showProgress = FALSE)
  cells <- cells[abs(di) <= 1L & abs(dj) <= 1L]
  cells[, `:=`(
    ok_q = !is.na(main_data_quality_flag) & main_data_quality_flag <= 0,
    ok_e = !is.na(eff_cloud_fraction)     & eff_cloud_fraction <= CFG$qc_max_cloud_fraction,
    ok_s = !is.na(solar_zenith_angle)     & solar_zenith_angle <= CFG$qc_max_sza,
    ok_n = !is.na(snow_ice_fraction)      & snow_ice_fraction <= CFG$qc_max_snow_ice)]
  per_scan <- cells[, .(n = .N,
                        full = sum(ok_q & ok_e & ok_s & ok_n),
                        noCloud = sum(ok_q & ok_s & ok_n),
                        noSZA   = sum(ok_q & ok_e & ok_n),
                        noSnow  = sum(ok_q & ok_e & ok_s),
                        noFlag  = sum(ok_e & ok_s & ok_n),
                        lon = data.table::first(cell_lon),
                        scan_start_utc = data.table::first(scan_start_utc)),
                    by = .(site, granule)]
  per_scan <- day_from(per_scan)
  per_scan <- per_scan[!is.na(sample_date)]
  v <- function(x, n) x >= 0.5 * n
  per_day <- per_scan[, .(full = sum(v(full, n)) > 0,
                          noCloud = sum(v(noCloud, n)) > 0,
                          noSZA   = sum(v(noSZA, n)) > 0,
                          noSnow  = sum(v(noSnow, n)) > 0,
                          noFlag  = sum(v(noFlag, n)) > 0),
                      by = .(site, sample_date)]
  out <- per_day[full == FALSE, .(
    screened_out_days = .N,
    rescued_by_cloud  = sum(noCloud),
    rescued_by_snow   = sum(noSnow),
    rescued_by_sza    = sum(noSZA),
    rescued_by_flag   = sum(noFlag),
    rescued_by_none   = sum(!noCloud & !noSnow & !noSZA & !noFlag))]
  out[, `:=`(arm = label, usable_days = sum(per_day$full),
             pct_cloud = round(100 * rescued_by_cloud / screened_out_days, 1))]
  data.table::setcolorder(out, "arm")
  out[]
}

attr_co <- attribute(
  file.path(P$processed, "tempo_site_cells.csv.gz"), "Colorado (24 h)",
  function(ps) {
    man <- read_tbl(file.path(P$processed, "tempo_manifest.csv")) |>
      distinct(granule, sample_date) |> mutate(sample_date = as.Date(sample_date))
    merge(ps, data.table::as.data.table(man), by = "granule", all.x = TRUE)
  })
# national: local standard date from the scan time and the site's longitude
attr_nat <- attribute(
  file.path(P$processed, "aqs_tempo_site_cells.csv.gz"), "National (24 h)",
  function(ps) {
    ps[, sample_date := as.Date(as.POSIXct(scan_start_utc, tz = "UTC") +
                                  round(lon / 15) * 3600)]
    ps
  })
attr_all <- data.table::rbindlist(list(attr_co, attr_nat), fill = TRUE)
if (nrow(attr_all)) {
  data.table::fwrite(attr_all, file.path(P$tables, "observability_screen_attribution.csv"))
  for (i in seq_len(nrow(attr_all))) {
    a <- attr_all[i]
    log_msg(sprintf("%s screening attribution: %d screened-out site-days; relaxing the cloud threshold alone rescues %d (%.0f%%), snow/ice %d, SZA %d, quality flag %d; %d rescued by none",
                    a$arm, a$screened_out_days, a$rescued_by_cloud, a$pct_cloud,
                    a$rescued_by_snow, a$rescued_by_sza, a$rescued_by_flag, a$rescued_by_none))
  }
}

# ---- 2. contrast, with site-clustered inference ------------------------------
# Sign convention throughout: positive = MORE surface HCHO on observable days.
# Percentages are relative to the median surface HCHO of the days entering the
# comparison.
cluster_se <- function(m, cluster) {          # CR1 cluster-robust standard errors
  X <- model.matrix(m); u <- as.numeric(residuals(m))
  bread <- tryCatch(solve(crossprod(X)), error = function(e) chol2inv(chol(crossprod(X) + diag(1e-8, ncol(X)))))
  meat <- matrix(0, ncol(X), ncol(X))
  for (g in split(seq_along(u), cluster)) {
    s <- crossprod(X[g, , drop = FALSE], u[g])
    meat <- meat + tcrossprod(s)
  }
  G <- length(unique(cluster)); n <- nrow(X); k <- ncol(X)
  V <- bread %*% meat %*% bread * (G / (G - 1)) * ((n - 1) / (n - k))
  sqrt(pmax(diag(V), 0))
}

fe <- lapply(unique(d$arm), function(a) {
  x <- filter(d, arm == a, day_type != "no granule") |>
    mutate(month = factor(format(sample_date, "%m")), site = factor(site))
  if (n_distinct(x$usable) < 2 || n_distinct(x$site) < 2) return(NULL)
  m <- lm(hcho_ugm3 ~ usable + site + month, data = x)
  cf <- summary(m)$coefficients
  j <- grep("^usableTRUE$", rownames(cf))
  se_cl <- cluster_se(m, x$site)[j]
  est <- cf[j, 1]
  tibble(arm = a, n = nrow(x), sites = n_distinct(x$site),
         beta_observable_minus_screened = est,
         se_iid = cf[j, 2], se_site_clustered = se_cl,
         t_clustered = est / se_cl,
         p_clustered = 2 * pt(-abs(est / se_cl), df = n_distinct(x$site) - 1),
         ci_lo = est - 1.96 * se_cl, ci_hi = est + 1.96 * se_cl,
         median_hcho = median(x$hcho_ugm3),
         pct_of_median = 100 * est / median(x$hcho_ugm3))
}) |> bind_rows()
if (nrow(fe)) {
  data.table::fwrite(fe, file.path(P$tables, "observability_bias_fixed_effects.csv"))
  for (i in seq_len(nrow(fe))) {
    b <- fe[i, ]
    log_msg(sprintf("%s, site + month fixed effects: observable minus screened-out %+.3f ug/m3 (%+.1f%% of the median); SE %.3f iid, %.3f site-clustered; 95%% CI %.3f to %.3f; p = %.3g (n = %d, %d sites)",
                    b$arm, b$beta_observable_minus_screened, b$pct_of_median,
                    b$se_iid, b$se_site_clustered, b$ci_lo, b$ci_hi, b$p_clustered,
                    b$n, b$sites))
  }
}

# within site-month, paired at the site-month level, bootstrapped over sites
contrast <- function(x, label, arm) {
  g <- x |>
    group_by(site, ym) |>
    filter(n() >= CFG$min_days_per_site_month, any(usable), any(!usable)) |>
    mutate(anom = hcho_ugm3 - mean(hcho_ugm3)) |>
    ungroup()
  if (!nrow(g)) return(tibble())
  pm <- g |> group_by(site, ym) |>
    summarise(d = mean(anom[usable]) - mean(anom[!usable]), .groups = "drop")  # observable - screened
  sites <- unique(pm$site)
  # A cluster bootstrap over very few sites resamples only a handful of distinct
  # values, so its interval is degenerate rather than narrow. Report no interval
  # below MIN_SITES_CI clusters.
  boot <- if (length(sites) >= MIN_SITES_CI) replicate(NBOOT, {
    s <- sample(sites, length(sites), replace = TRUE)
    mean(unlist(lapply(s, function(z) pm$d[pm$site == z])))
  }) else rep(NA_real_, NBOOT)
  tibble(arm = arm, stratum = label,
         sites = length(sites), site_months = nrow(pm),
         paired_observable_minus_screened = mean(pm$d),
         boot_lo = unname(quantile(boot, 0.025, na.rm = TRUE)),
         boot_hi = unname(quantile(boot, 0.975, na.rm = TRUE)),
         median_hcho = median(g$hcho_ugm3),
         pct_of_median = 100 * mean(pm$d) / median(g$hcho_ugm3))
}

out <- list()
for (a in unique(d$arm)) {
  x <- filter(d, arm == a, day_type != "no granule")
  out[[length(out) + 1]] <- contrast(x, "all", a)
  for (s in c("DJF", "MAM", "JJA", "SON")) {
    r <- contrast(filter(x, season == s), s, a)
    if (nrow(r)) out[[length(out) + 1]] <- r
  }
}
bias <- bind_rows(out)
data.table::fwrite(bias, file.path(P$tables, "observability_bias.csv"))
for (i in seq_len(nrow(bias))) {
  b <- bias[i, ]
  ci <- if (is.na(b$boot_lo)) sprintf("no interval (%d site clusters < %d)", b$sites, MIN_SITES_CI)
        else sprintf("site-cluster bootstrap 95%% CI %.3f to %.3f", b$boot_lo, b$boot_hi)
  log_msg(sprintf("%s, %s: %d sites, %d site-months; observable minus screened-out %+.3f ug/m3 (%+.1f%%), %s",
                  b$arm, b$stratum, b$sites, b$site_months,
                  b$paired_observable_minus_screened, b$pct_of_median, ci))
}

# ---- 3. figure ---------------------------------------------------------------
plot_d <- d |>
  filter(day_type != "no granule") |>
  group_by(arm, site, ym) |>
  filter(n() >= CFG$min_days_per_site_month, any(usable), any(!usable)) |>
  mutate(anom = hcho_ugm3 - mean(hcho_ugm3)) |>
  ungroup() |>
  mutate(sky = factor(ifelse(usable, "TEMPO usable", "screened out"),
                      levels = c("TEMPO usable", "screened out")))

lab <- bias |> filter(stratum == "all") |>
  transmute(arm, txt = sprintf("adjusted difference %+.2f µg m⁻³ (95 %% CI %.2f to %.2f)",
                               paired_observable_minus_screened, boot_lo, boot_hi))

p <- ggplot(plot_d, aes(sky, anom, fill = sky)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_boxplot(width = 0.55, outlier.size = 0.4, outlier.alpha = 0.3, show.legend = FALSE) +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 2.4,
               fill = "white", show.legend = FALSE) +
  geom_text(data = lab, aes(x = 1.5, y = Inf, label = txt), inherit.aes = FALSE,
            vjust = 1.4, size = 2.6, colour = "grey20") +
  facet_wrap(~ arm) +
  scale_fill_manual(values = c("#5ab4ac", "#b8b8b8")) +
  coord_cartesian(ylim = quantile(plot_d$anom, c(0.01, 0.99), na.rm = TRUE) * c(1, 1.25)) +
  labs(x = NULL, y = expression("Surface HCHO anomaly ("*mu*g~m^{-3}*")"),
       title = "Are the days TEMPO can observe representative?",
       subtitle = "Deviations from the site and calendar-month mean; diamonds are means. Axes truncated near the 1st and 99th percentiles.") +
  theme_bw(base_size = 10) +
  theme(plot.subtitle = element_text(size = 8), panel.grid.minor = element_blank())

ggsave(file.path(P$figures, "fig14_observability_bias.png"), p, width = 7, height = 4.4, dpi = 300)
log_msg("  figure: fig14_observability_bias.png")
log_msg("Observability bias test done.")
