# =============================================================================
# helpers_stats.R - statistics shared by 05_analysis.R and 07_threeh_analysis.R
# =============================================================================

rma_fit <- function(x, y) {
  r <- cor(x, y); b <- sign(r) * sd(y) / sd(x)
  c(slope = b, intercept = mean(y) - b * mean(x))
}
relstats <- function(d, x = "tempo_vc_1e15", y = "hcho_ugm3", nboot = 1000) {
  d <- d[is.finite(d[[x]]) & is.finite(d[[y]]), ]
  n <- nrow(d)
  if (n < 6) return(tibble(n = n))
  xx <- d[[x]]; yy <- d[[y]]
  pr <- cor.test(xx, yy, method = "pearson")
  sp <- suppressWarnings(cor.test(xx, yy, method = "spearman", exact = FALSE))
  ols <- coef(lm(yy ~ xx))
  rma <- rma_fit(xx, yy)
  boot <- replicate(nboot, { k <- sample.int(n, n, replace = TRUE); rma_fit(xx[k], yy[k])[["slope"]] })
  # RMA slope = sign(r) * sd(y)/sd(x): undefined in practice when r ~ 0 (the
  # bootstrap flips sign), so it is only reported when the correlation is significant
  if (pr$p.value >= 0.05) { rma[] <- NA_real_; boot[] <- NA_real_ }
  tibble(n = n,
         pearson_r = pr$estimate[[1]], pearson_p = pr$p.value,
         spearman_rho = sp$estimate[[1]], spearman_p = sp$p.value,
         ols_slope = ols[[2]], ols_intercept = ols[[1]],
         rma_slope = rma[["slope"]],
         rma_slope_lo = if (all(is.na(boot))) NA_real_ else quantile(boot, 0.025, na.rm = TRUE)[[1]],
         rma_slope_hi = if (all(is.na(boot))) NA_real_ else quantile(boot, 0.975, na.rm = TRUE)[[1]],
         rma_intercept = rma[["intercept"]],
         median_surface_ugm3 = median(yy), median_tempo_1e15 = median(xx),
         median_h_eff_km = median(d$h_eff_km, na.rm = TRUE),
         median_tempo_pbl_km = median(d$tempo_pbl_km, na.rm = TRUE))
}

# Remove site x calendar-month means so only day-to-day covariation remains.
# Months with fewer than min_n usable samples are dropped.
add_month_anomalies <- function(d, min_n) {
  d |>
    mutate(ym = floor_date(sample_date, "month")) |>
    group_by(site, ym) |>
    filter(n() >= min_n) |>
    mutate(surface_anom = hcho_ugm3 - mean(hcho_ugm3),
           column_anom = tempo_vc_1e15 - mean(tempo_vc_1e15)) |>
    ungroup()
}

# Correlation of anomalies. p-values ignore the degrees of freedom used by the
# monthly means and are therefore optimistic.
anomstats <- function(d) {
  if (nrow(d) < 6) return(tibble(n = nrow(d)))
  pr <- cor.test(d$column_anom, d$surface_anom)
  sp <- suppressWarnings(cor.test(d$column_anom, d$surface_anom, method = "spearman", exact = FALSE))
  months <- if ("site" %in% names(d)) n_distinct(paste(d$site, d$ym)) else n_distinct(d$ym)
  tibble(n = nrow(d), site_months = months,
         pearson_r = pr$estimate[[1]], pearson_p = pr$p.value,
         spearman_rho = sp$estimate[[1]], spearman_p = sp$p.value,
         ols_slope = coef(lm(surface_anom ~ column_anom, data = d))[[2]])
}
