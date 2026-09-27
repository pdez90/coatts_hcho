# =============================================================================
# 20_agreement_diagnostics.R - why agreement differs, not another version of it.
#
# Four analyses that the earlier steps set up but did not run:
#
#   A. Sample duration within the same monitors. Twenty-three sites report
#      both 24 h and 8 h HCHO. Comparing the two durations at the same site
#      removes the site/network confounding that the pooled Table 1 contrast
#      cannot, and the paired difference across sites is the statistic.
#      A second contrast uses the 24 h surface sample against TEMPO columns
#      restricted to the hours of each 8 h block, so the effect of restricting
#      the column can be separated from the effect of restricting the sample.
#   B. The gap to the retrieval-noise ceiling. Step 17 gives every 24 h site
#      an observed anomaly correlation and the ceiling that scan-to-scan noise
#      alone would allow. Here the site-level correlation (Fisher z, weighted)
#      and the noise-corrected efficiency E = r_obs / r_ceiling are modelled
#      against a small pre-specified set of site descriptors: atmospheric
#      signal, signal-to-noise ratio, temporal averaging, observability, mixing
#      depth and smoke prevalence. E is the interesting outcome: what predicts
#      the agreement that noise does NOT explain?
#   C. Temporal averaging, empirically. For 24 h samples with at least KMIN
#      valid scans, draw k = 1, 2, ... scans at random, average them, and
#      recompute the within-month anomaly correlation, for each spatial block.
#      This tests the noise-averaging explanation of Sect. 3.3 directly rather
#      than through the scan-difference estimator, and the variance of the
#      column anomaly as a function of k gives an independent estimate of the
#      single-scan noise.
#   D. Boundary-layer state. For 8 h samples the HRRR mixing depth over the
#      sampling window is independent of the surface HCHO outcome (unlike
#      H_eff). Within each 8 h start hour, so that time of day is held fixed,
#      observations are split into tertiles of the mixing depth (absolute, and
#      relative to the site-month) and the anomaly correlation is compared;
#      an interaction model with site-clustered errors gives the same test in
#      regression form.
#
# Reads what steps 11-13 and 17 wrote; downloads nothing. Screen, anomaly
# definition and bootstrap are the shared ones in helpers_*.R.
#
# Outputs: output/tables/diag7_dual_duration_sites.csv
#          output/tables/diag7_dual_duration_paired.csv
#          output/tables/diag8_ceiling_gap_sites.csv
#          output/tables/diag8_ceiling_gap_models.csv
#          output/tables/diag8_ceiling_gap_univariate.csv
#          output/tables/diag9_temporal_averaging.csv
#          output/tables/diag9_temporal_averaging_noise.csv
#          output/tables/diag10_pbl_tertiles.csv
#          output/tables/diag10_pbl_interaction.csv
#          output/tables/manuscript_numbers_20.csv
#          output/figures/fig20_dual_duration.png
#          output/figures/fig21_ceiling_gap.png
#          output/figures/fig22_temporal_averaging.png
#          output/figures/fig23_pbl_tertiles.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_screen.R")
source("R/helpers_stats.R")
set.seed(42)
HAS_GG <- requireNamespace("ggplot2", quietly = TRUE)
if (HAS_GG) theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))

primary_path  <- file.path(P$processed, "aqs_matched_primary.csv.gz")
samples_path  <- file.path(P$processed, "aqs_hcho_samples.csv")
cells_path    <- file.path(P$processed, "aqs_tempo_site_cells.csv.gz")
man_path      <- file.path(P$processed, "aqs_tempo_manifest.csv")
noise_path    <- file.path(P$tables, "national_noise_ceiling.csv")
bysite_path   <- file.path(P$tables, "national_stats_by_site.csv")
cover_path    <- file.path(P$tables, "national_coverage.csv")
smoke_path    <- file.path(P$processed, "smoke_flags.csv")
for (f in c(primary_path, samples_path, cells_path, man_path, noise_path, bysite_path, cover_path)) {
  if (!file.exists(f)) stop("Missing ", f, " - run steps 11-13 and 17 first.")
}

MIN_ANOM_PAIRS <- 10L    # anomaly pairs for a site-level correlation (as in steps 13, 17)
NBOOT          <- 2000L
KMIN           <- 4L     # valid scans a 24 h sample needs to enter the temporal-averaging draw
NDRAW          <- 200L   # random draws per (block, k)
fz  <- function(r) atanh(pmin(pmax(r, -0.999), 0.999))
ifz <- function(z) tanh(z)

# ---- inputs ------------------------------------------------------------------
prim <- read_tbl(primary_path, colClasses = list(character = c("site_id", "site", "qualifiers"))) |>
  filter(lag_h == 0) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"), sample_date = as.Date(sample_date))
log_msg(nrow(prim), " primary matched rows at lag 0 (", n_distinct(prim$site), " sites)")

smoke <- NULL
if (file.exists(smoke_path)) {
  smoke <- read_tbl(smoke_path, colClasses = list(character = c("site", "smoke_class", "convention"))) |>
    filter(arm == "national") |>
    transmute(site = site, start_utc = as.POSIXct(win_start_utc, tz = "UTC"), hms_available, smoke_any)
  stopifnot(!anyDuplicated(smoke[, c("site", "start_utc")]))
}

anom_r <- function(d, min_n = MIN_ANOM_PAIRS) {
  if (nrow(d) < min_n) return(NA_real_)
  cor(d$column_anom, d$surface_anom)
}
anom_slope <- function(d, min_n = MIN_ANOM_PAIRS) {
  if (nrow(d) < min_n) return(NA_real_)
  coef(lm(surface_anom ~ column_anom, data = d))[[2]]
}
# anomalies within site x year-month x start hour (the window-stratified form of Sect. S4)
add_window_anomalies <- function(d, min_n) {
  d |>
    mutate(ym = floor_date(sample_date, "month")) |>
    group_by(site, ym, window_start_hour) |>
    filter(n() >= min_n) |>
    mutate(surface_anom = hcho_ugm3 - mean(hcho_ugm3),
           column_anom = tempo_vc_1e15 - mean(tempo_vc_1e15)) |>
    ungroup()
}
# CR1 cluster-robust covariance for an lm
cluster_vcov <- function(fit, cl) {
  X <- model.matrix(fit); e <- residuals(fit); n <- nrow(X); k <- ncol(X)
  cl <- as.character(cl); G <- n_distinct(cl)
  bread <- solve(crossprod(X))
  meat <- Reduce(`+`, lapply(split(seq_len(n), cl), function(i) {
    s <- crossprod(X[i, , drop = FALSE], e[i]); s %*% t(s)
  }))
  adj <- (G / (G - 1)) * ((n - 1) / (n - k))
  adj * bread %*% meat %*% bread
}

# ============================================================================
# A. 24 h versus 8 h within the same monitors
# ============================================================================
dual_sites <- prim |>
  filter(duration_class %in% c("24 h", "8 h")) |>
  distinct(site, duration_class) |>
  count(site) |> filter(n == 2) |> pull(site)
log_msg("A. ", length(dual_sites), " sites report both 24 h and 8 h samples")

per_dur <- prim |>
  filter(site %in% dual_sites, duration_class %in% c("24 h", "8 h")) |>
  group_by(site, site_name, state, duration_class) |>
  group_modify(function(d, k) {
    u <- filter(d, usable)
    an <- add_month_anomalies(u, CFG$min_days_per_site_month)
    tibble(n_samples = nrow(d),
           n_with_scan = sum(d$n_scans > 0),
           n_usable = nrow(u),
           usable_pct = 100 * nrow(u) / sum(d$n_scans > 0),
           median_valid_scans = median(u$n_valid_scans),
           median_surface_ugm3 = median(u$hcho_ugm3),
           median_column_1e15 = median(u$tempo_vc_1e15),
           anom_n = nrow(an), anom_site_months = n_distinct(an$ym),
           anom_r = anom_r(an), anom_slope = anom_slope(an),
           sd_surface_anom = if (nrow(an) >= MIN_ANOM_PAIRS) sd(an$surface_anom) else NA_real_,
           sd_column_anom  = if (nrow(an) >= MIN_ANOM_PAIRS) sd(an$column_anom) else NA_real_)
  }, .keep = TRUE) |> ungroup()

# 8 h agreement by block (window-stratified anomalies), at the same sites
per_block <- prim |>
  filter(site %in% dual_sites, duration_class == "8 h", usable, window_start_hour %in% c(4L, 12L)) |>
  add_window_anomalies(CFG$min_days_per_site_month) |>
  group_by(site, window_start_hour) |>
  summarise(n = n(), r = anom_r(pick(everything())), .groups = "drop") |>
  pivot_wider(names_from = window_start_hour, values_from = c(n, r), names_glue = "{.value}_8h_start{window_start_hour}")

wide <- per_dur |>
  select(site, site_name, state, duration_class, n_samples, usable_pct, median_valid_scans,
         median_surface_ugm3, median_column_1e15, anom_n, anom_r, anom_slope) |>
  pivot_wider(names_from = duration_class, values_from = c(n_samples, usable_pct, median_valid_scans,
                                                           median_surface_ugm3, median_column_1e15, anom_n, anom_r, anom_slope),
              names_glue = "{.value}_{gsub(' ', '', duration_class)}") |>
  left_join(per_block, by = "site")

# ---- A2. the 24 h surface sample against the column restricted to each 8 h block --
# Scan-level values are needed for that; they are also what analysis C uses.
samples24 <- read_tbl(samples_path, colClasses = list(character = c("site_id", "qualifiers"))) |>
  filter(duration_class == "24 h", !is.na(hcho_ugm3)) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"), end_utc = as.POSIXct(end_utc, tz = "UTC"),
         sample_date = as.Date(sample_date_local), site = site_id)
cells <- read_tbl(cells_path, colClasses = list(character = c("granule", "scan_start_utc", "site")))
for (col in setdiff(names(cells), c("granule", "scan_start_utc", "site"))) {
  x <- cells[[col]]
  if (!is.numeric(x) || inherits(x, "integer64")) cells[[col]] <- suppressWarnings(as.numeric(as.character(x)))
}
manifest <- read_tbl(man_path, colClasses = "character") |>
  transmute(granule, mid_utc = ymd_hms(mid_utc)) |> distinct(granule, .keep_all = TRUE)
.prep <- hcho_prepare_cells(cells); cells <- .prep$cells; QC_ABSENT <- .prep$absent
cells <- semi_join(cells, samples24, by = "site")
hour_key <- function(t) as.integer(as.numeric(t) %/% 3600)
scan_values <- function(block) {
  cells |>
    filter(abs(di) <= block, abs(dj) <= block) |>
    mutate(pass = hcho_screen_pass(pick(everything()), CFG$qc_max_cloud_fraction, QC_ABSENT)) |>
    group_by(granule, site) |>
    summarise(n_cells = n(), n_pass = sum(pass),
              vc = if (any(pass)) mean(vertical_column[pass]) else NA_real_, .groups = "drop") |>
    mutate(valid = hcho_scan_valid(n_pass, n_cells)) |>
    inner_join(manifest, by = "granule") |>
    mutate(hour = hour_key(mid_utc))
}
sample_hours <- samples24 |>
  transmute(site, start_utc, sample_date, start_hour_local, hcho_ugm3,
            h0 = hour_key(start_utc), h1 = hour_key(end_utc)) |>
  mutate(hour = map2(h0, h1, ~ seq.int(.x, .y - 1L))) |>
  tidyr::unnest(hour) |>
  select(site, start_utc, sample_date, start_hour_local, hcho_ugm3, hour)
assign_scans <- function(sv) {
  sample_hours |>
    inner_join(sv, by = c("site", "hour"), relationship = "many-to-many") |>
    filter(valid) |>
    mutate(local_hour = (start_hour_local + as.numeric(difftime(mid_utc, start_utc, units = "hours"))) %% 24,
           vc_1e15 = vc / 1e15)
}
block_label <- function(b) sprintf("%dx%d", 2L * b + 1L, 2L * b + 1L)
scans <- map(c(0L, 1L, 2L), function(b) assign_scans(scan_values(b)))
names(scans) <- block_label(c(0L, 1L, 2L))
log_msg("scan-level values: ", paste(names(scans), vapply(scans, nrow, integer(1)), collapse = "; "), " valid scan-sample rows")

restricted <- scans[["3x3"]] |>
  filter(site %in% dual_sites) |>
  mutate(block8 = case_when(local_hour >= 4 & local_hour < 12 ~ "start4",
                            local_hour >= 12 & local_hour < 20 ~ "start12",
                            TRUE ~ NA_character_)) |>
  filter(!is.na(block8)) |>
  group_by(site, start_utc, sample_date, hcho_ugm3, block8) |>
  summarise(tempo_vc_1e15 = mean(vc_1e15), n_valid = n(), .groups = "drop") |>
  group_by(site, block8) |>
  group_modify(function(d, k) {
    an <- add_month_anomalies(d, CFG$min_days_per_site_month)
    tibble(n = nrow(an), r = anom_r(an))
  }, .keep = TRUE) |> ungroup() |>
  pivot_wider(names_from = block8, values_from = c(n, r), names_glue = "{.value}_24h_col_{block8}")
wide <- left_join(wide, restricted, by = "site") |>
  mutate(diff_r_8h_minus_24h = anom_r_8h - anom_r_24h,
         diff_slope_8h_minus_24h = anom_slope_8h - anom_slope_24h,
         diff_usable_pct_8h_minus_24h = usable_pct_8h - usable_pct_24h,
         diff_scans_8h_minus_24h = median_valid_scans_8h - median_valid_scans_24h)
data.table::fwrite(wide, file.path(P$tables, "diag7_dual_duration_sites.csv"))

paired_summary <- function(x, label) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 5) return(tibble(quantity = label, n_sites = n))
  bt <- replicate(NBOOT, mean(sample(x, n, replace = TRUE)))
  w <- suppressWarnings(wilcox.test(x, exact = FALSE))
  tibble(quantity = label, n_sites = n, n_positive = sum(x > 0), n_negative = sum(x < 0),
         median_diff = median(x), mean_diff = mean(x),
         mean_ci_lo = quantile(bt, 0.025)[[1]], mean_ci_hi = quantile(bt, 0.975)[[1]],
         iqr_lo = quantile(x, 0.25)[[1]], iqr_hi = quantile(x, 0.75)[[1]],
         wilcoxon_p = w$p.value)
}
both <- filter(wide, is.finite(anom_r_24h), is.finite(anom_r_8h))
paired <- bind_rows(
  paired_summary(both$diff_r_8h_minus_24h, "anomaly r, 8 h minus 24 h"),
  paired_summary(both$diff_slope_8h_minus_24h, "anomaly slope (ug m-3 per 1e15), 8 h minus 24 h"),
  paired_summary(both$diff_usable_pct_8h_minus_24h, "usable share (%), 8 h minus 24 h"),
  paired_summary(both$diff_scans_8h_minus_24h, "median valid scans per sample, 8 h minus 24 h"),
  paired_summary(both$r_8h_start12 - both$anom_r_24h, "anomaly r, 8 h 12:00 block minus 24 h"),
  paired_summary(both$r_8h_start4 - both$anom_r_24h, "anomaly r, 8 h 04:00 block minus 24 h"),
  paired_summary(both$r_24h_col_start12 - both$anom_r_24h, "anomaly r, 24 h sample vs 12-20 LST column minus vs all-day column"),
  paired_summary(both$r_24h_col_start4 - both$anom_r_24h, "anomaly r, 24 h sample vs 04-12 LST column minus vs all-day column"),
  paired_summary(both$r_8h_start12 - both$r_24h_col_start12, "anomaly r, 8 h 12:00 sample minus 24 h sample, both vs 12-20 LST column"),
  paired_summary(both$r_8h_start4 - both$r_24h_col_start4, "anomaly r, 8 h 04:00 sample minus 24 h sample, both vs 04-12 LST column"))
# pooled anomaly r at the dual sites, each duration, for reference
pooled_dual <- prim |>
  filter(site %in% both$site, duration_class %in% c("24 h", "8 h"), usable) |>
  group_by(duration_class) |>
  group_modify(function(d, k) { an <- add_month_anomalies(d, CFG$min_days_per_site_month); tibble(n = nrow(an), r = anom_r(an)) }, .keep = TRUE) |>
  ungroup()
paired <- bind_rows(paired,
  tibble(quantity = paste0("pooled anomaly r at these sites, ", pooled_dual$duration_class), n_sites = nrow(both),
         median_diff = pooled_dual$r, mean_diff = pooled_dual$n))
data.table::fwrite(paired, file.path(P$tables, "diag7_dual_duration_paired.csv"))
log_msg("A. ", nrow(both), " sites with >= ", MIN_ANOM_PAIRS, " anomaly pairs at both durations; median r 24 h ",
        round(median(both$anom_r_24h), 2), ", 8 h ", round(median(both$anom_r_8h), 2),
        "; paired median difference ", round(paired$median_diff[1], 2), " (Wilcoxon p = ", signif(paired$wilcoxon_p[1], 2), ")")

# ============================================================================
# B. The gap to the noise ceiling and what predicts it
# ============================================================================
nc <- read_tbl(noise_path, colClasses = list(character = c("site", "block_label"))) |>
  filter(block_label == "3x3", is.finite(ceiling_empirical), n_anomalies >= MIN_ANOM_PAIRS, ceiling_empirical > 0)
bysite <- read_tbl(bysite_path, colClasses = list(character = c("site", "networks"))) |>
  filter(duration_class == "24 h") |>
  select(site, lat, lon, networks, median_surface_ugm3, median_tempo_1e15)
cover <- read_tbl(cover_path, colClasses = list(character = "site")) |>
  filter(duration_class == "24 h", lag_h == 0) |>
  select(site, usable_pct)
site_env <- prim |>
  filter(duration_class == "24 h", usable) |>
  { \(d) if (!is.null(smoke)) left_join(d, smoke, by = c("site", "start_utc")) else mutate(d, smoke_any = NA, hms_available = NA) }() |>
  group_by(site) |>
  summarise(pbl_hrrr_km = mean(pbl_m_hrrr, na.rm = TRUE) / 1000,
            smoke_share = if (any(hms_available %in% TRUE)) mean(smoke_any[hms_available %in% TRUE] %in% TRUE) else NA_real_,
            .groups = "drop")
gap <- nc |>
  inner_join(bysite, by = "site") |>
  left_join(cover, by = "site") |>
  left_join(site_env, by = "site") |>
  mutate(efficiency = pmin(r_noise_corrected, 1.2),                    # r_obs / ceiling; a few sites can exceed 1
         gap_to_ceiling = ceiling_empirical - anomaly_r_observed,
         snr = sd_column_anomaly_1e15 / noise_sd_empirical_1e15,
         z_obs = fz(anomaly_r_observed), z_eff = fz(pmin(efficiency, 0.999)),
         log_surface = log(median_surface_ugm3), log_snr = log(snr), log_scans = log(median_valid_scans))
data.table::fwrite(gap, file.path(P$tables, "diag8_ceiling_gap_sites.csv"))
log_msg("B. ", nrow(gap), " sites with a ceiling; median E = r_obs/ceiling ", round(median(gap$efficiency), 2),
        ", within 20 % of ceiling: ", sum(gap$efficiency >= 0.8), ", below half: ", sum(gap$efficiency < 0.5))

preds <- c(log_surface = "log median surface HCHO", log_snr = "log signal-to-noise ratio",
           log_scans = "log median valid scans", usable_pct = "usable share (%)",
           pbl_hrrr_km = "HRRR mixing depth (km)", smoke_share = "smoke-affected share")
uni <- map_dfr(names(preds), function(p) {
  d <- gap[is.finite(gap[[p]]), ]
  bind_rows(
    tibble(outcome = "anomaly r (observed)", predictor = preds[[p]], n = nrow(d),
           spearman_rho = cor(d[[p]], d$anomaly_r_observed, method = "spearman"),
           spearman_p = suppressWarnings(cor.test(d[[p]], d$anomaly_r_observed, method = "spearman", exact = FALSE))$p.value),
    tibble(outcome = "E = r_obs / ceiling", predictor = preds[[p]], n = nrow(d),
           spearman_rho = cor(d[[p]], d$efficiency, method = "spearman"),
           spearman_p = suppressWarnings(cor.test(d[[p]], d$efficiency, method = "spearman", exact = FALSE))$p.value))
})
data.table::fwrite(uni, file.path(P$tables, "diag8_ceiling_gap_univariate.csv"))

fit_gap <- function(outcome, pred_names, label) {
  d <- gap |> select(all_of(c(outcome, pred_names, "n_anomalies"))) |> drop_na()
  Z <- d |> mutate(across(all_of(pred_names), ~ as.numeric(scale(.x))))
  f <- reformulate(pred_names, response = outcome)
  fit <- lm(f, data = Z, weights = n_anomalies - 3)
  s <- summary(fit)
  co <- coef(s)
  # partial R2 of each term, from the drop in R2 when it is removed
  pr2 <- vapply(pred_names, function(p) {
    f0 <- reformulate(setdiff(pred_names, p), response = outcome)
    summary(lm(f0, data = Z, weights = n_anomalies - 3))$r.squared
  }, numeric(1))
  tibble(model = label, outcome = outcome, n_sites = nrow(d), r2 = s$r.squared, adj_r2 = s$adj.r.squared,
         term = rownames(co), estimate_per_sd = co[, 1], se = co[, 2], t = co[, 3], p = co[, 4],
         partial_r2 = c(NA_real_, s$r.squared - pr2))
}
models <- bind_rows(
  fit_gap("z_obs", names(preds), "M1: Fisher z of observed r ~ all six"),
  fit_gap("z_eff", names(preds), "M2: Fisher z of E ~ all six"),
  fit_gap("z_eff", setdiff(names(preds), c("log_snr", "log_scans")), "M3: Fisher z of E ~ without the noise terms"))
data.table::fwrite(models, file.path(P$tables, "diag8_ceiling_gap_models.csv"))
for (m in unique(models$model)) {
  mm <- filter(models, model == m)
  log_msg("B. ", m, ": n = ", mm$n_sites[1], ", R2 = ", round(mm$r2[1], 2), "; ",
          paste(sprintf("%s %+.2f (p=%.3f)", mm$term[-1], mm$estimate_per_sd[-1], mm$p[-1]), collapse = ", "))
}

# ============================================================================
# C. Temporal averaging: k random scans per 24 h sample
# ============================================================================
# a fixed sample set: 24 h samples with >= KMIN valid scans in every block
counts <- map_dfr(names(scans), function(b) scans[[b]] |> count(site, start_utc, name = "n_valid") |> mutate(block = b))
eligible <- counts |> group_by(site, start_utc) |> summarise(min_valid = min(n_valid), n_blocks = n(), .groups = "drop") |>
  filter(n_blocks == 3, min_valid >= KMIN) |> select(site, start_utc)
log_msg("C. ", nrow(eligible), " 24 h samples with >= ", KMIN, " valid scans in all three blocks")

draw_r_fast <- function(sv, k) {
  dt <- data.table::as.data.table(sv)[, .(site, start_utc, sample_date, hcho_ugm3, vc_1e15)]
  if (is.finite(k)) {
    # k scans per sample without replacement: a random key, sort, keep the first k per sample
    dt[, rk := stats::runif(.N)]
    data.table::setorder(dt, site, start_utc, rk)
    dt[, idx := seq_len(.N), by = .(site, start_utc)]
    dt <- dt[idx <= k]
  }
  per <- dt[, .(tempo_vc_1e15 = mean(vc_1e15)), by = .(site, start_utc, sample_date, hcho_ugm3)] |> tibble::as_tibble()
  an <- add_month_anomalies(per, CFG$min_days_per_site_month)
  site_r <- an |> group_by(site) |> filter(n() >= MIN_ANOM_PAIRS) |>
    summarise(r = cor(column_anom, surface_anom), .groups = "drop")
  tibble(n_anomalies = nrow(an), r_pooled = cor(an$column_anom, an$surface_anom),
         sd_column_anom = sd(an$column_anom), sd_surface_anom = sd(an$surface_anom),
         median_site_r = median(site_r$r), n_sites = nrow(site_r))
}
ks <- c(seq_len(KMIN), Inf)
ta <- map_dfr(names(scans), function(b) {
  sv <- scans[[b]] |> semi_join(eligible, by = c("site", "start_utc"))
  map_dfr(ks, function(k) {
    reps <- if (is.finite(k)) map_dfr(seq_len(NDRAW), ~ draw_r_fast(sv, k)) else draw_r_fast(sv, k)
    tibble(block = b, k_scans = if (is.finite(k)) as.character(k) else "all", n_draws = nrow(reps),
           n_anomalies = median(reps$n_anomalies),
           r_pooled = mean(reps$r_pooled), r_pooled_lo = quantile(reps$r_pooled, 0.025)[[1]], r_pooled_hi = quantile(reps$r_pooled, 0.975)[[1]],
           median_site_r = mean(reps$median_site_r), median_site_r_lo = quantile(reps$median_site_r, 0.025)[[1]],
           median_site_r_hi = quantile(reps$median_site_r, 0.975)[[1]],
           sd_column_anom_1e15 = mean(reps$sd_column_anom), sd_surface_anom = mean(reps$sd_surface_anom),
           n_sites = median(reps$n_sites))
  })
})
# median valid scans among eligible samples, for the "all" row
all_k <- counts |> semi_join(eligible, by = c("site", "start_utc")) |> group_by(block) |>
  summarise(median_valid_scans_all = median(n_valid), .groups = "drop")
ta <- left_join(ta, all_k, by = "block")
data.table::fwrite(ta, file.path(P$tables, "diag9_temporal_averaging.csv"))

# variance of the column anomaly against 1/k: var = signal + noise^2 / k. The
# slope is an estimate of the single-scan noise variance that does not use the
# scan-difference estimator, so it is an independent check of Sect. 3.3.
noise_fit <- ta |> filter(k_scans != "all") |>
  mutate(k = as.numeric(k_scans), v = sd_column_anom_1e15^2) |>
  group_by(block) |>
  group_modify(function(d, key) {
    f <- lm(v ~ I(1 / k), data = d)
    tibble(n_k = nrow(d), signal_var_1e30 = coef(f)[[1]], single_scan_noise_var_1e30 = coef(f)[[2]],
           single_scan_noise_sd_1e15 = sqrt(max(0, coef(f)[[2]])), r2_fit = summary(f)$r.squared)
  }) |> ungroup()
data.table::fwrite(noise_fit, file.path(P$tables, "diag9_temporal_averaging_noise.csv"))
for (b in names(scans)) {
  tb <- filter(ta, block == b)
  log_msg("C. ", b, ": r_pooled k=1 ", round(tb$r_pooled[tb$k_scans == "1"], 3), " -> k=", KMIN, " ",
          round(tb$r_pooled[tb$k_scans == as.character(KMIN)], 3), " -> all ", round(tb$r_pooled[tb$k_scans == "all"], 3),
          "; single-scan noise from var(1/k): ", round(noise_fit$single_scan_noise_sd_1e15[noise_fit$block == b], 2), " x1e15")
}

# ============================================================================
# D. Mixing depth and column-surface coupling, time of day held fixed
# ============================================================================
d8 <- prim |>
  filter(duration_class == "8 h", usable, window_start_hour %in% c(4L, 12L), is.finite(pbl_m_hrrr)) |>
  add_window_anomalies(CFG$min_days_per_site_month) |>
  group_by(site, ym, window_start_hour) |>
  mutate(pbl_anom_m = pbl_m_hrrr - mean(pbl_m_hrrr)) |>
  ungroup()
d24 <- prim |>
  filter(duration_class == "24 h", usable, is.finite(pbl_m_hrrr)) |>
  add_month_anomalies(CFG$min_days_per_site_month) |>
  group_by(site, ym) |> mutate(pbl_anom_m = pbl_m_hrrr - mean(pbl_m_hrrr)) |> ungroup() |>
  mutate(window_start_hour = 0L)
dd <- bind_rows(d8, d24)
if (!is.null(smoke)) dd <- left_join(dd, smoke, by = c("site", "start_utc"))

tertile_r <- function(d, var, label) {
  d <- d |> mutate(tert = ntile(.data[[var]], 3))
  by_t <- d |> group_by(tert) |>
    summarise(n = n(), r = cor(column_anom, surface_anom),
              pbl_median_km = median(pbl_m_hrrr) / 1000,
              sd_column_anom_1e15 = sd(column_anom), sd_surface_anom = sd(surface_anom),
              median_column_1e15 = median(tempo_vc_1e15), median_surface_ugm3 = median(hcho_ugm3),
              median_valid_scans = median(n_valid_scans),
              smoke_share = if (!is.null(smoke)) mean(smoke_any %in% TRUE) else NA_real_, .groups = "drop")
  # cluster (site) bootstrap for r(top) - r(bottom)
  bi <- boot_index(nrow(d), d$site)
  diffs <- replicate(NBOOT, {
    i <- bi$draw(); s <- d[i, ]
    suppressWarnings(cor(s$column_anom[s$tert == 3], s$surface_anom[s$tert == 3]) -
                     cor(s$column_anom[s$tert == 1], s$surface_anom[s$tert == 1]))
  })
  by_t |> mutate(stratification = label, diff_top_minus_bottom = r[tert == 3] - r[tert == 1],
                 diff_ci_lo = quantile(diffs, 0.025, na.rm = TRUE)[[1]], diff_ci_hi = quantile(diffs, 0.975, na.rm = TRUE)[[1]],
                 ci_basis = bi$basis, n_sites = n_distinct(d$site))
}
tert <- map_dfr(c(4L, 12L, 0L), function(h) {
  d <- filter(dd, window_start_hour == h)
  lab <- if (h == 0L) "24 h" else sprintf("8 h, start %02d:00 LST", h)
  out <- bind_rows(tertile_r(d, "pbl_m_hrrr", "absolute HRRR mixing depth") |> mutate(sample = lab),
                   tertile_r(d, "pbl_anom_m", "mixing depth relative to site-month") |> mutate(sample = lab))
  if (!is.null(smoke)) {
    ds <- filter(d, hms_available %in% TRUE, !(smoke_any %in% TRUE))
    out <- bind_rows(out, tertile_r(ds, "pbl_anom_m", "relative to site-month, smoke-free days only") |> mutate(sample = lab))
  }
  out
}) |> select(sample, stratification, tert, n, r, pbl_median_km, sd_column_anom_1e15, sd_surface_anom, median_column_1e15,
             median_surface_ugm3, median_valid_scans, smoke_share, diff_top_minus_bottom, diff_ci_lo, diff_ci_hi, ci_basis, n_sites)
data.table::fwrite(tert, file.path(P$tables, "diag10_pbl_tertiles.csv"))

inter <- map_dfr(c(4L, 12L, 0L), function(h) {
  d <- filter(dd, window_start_hour == h) |>
    group_by(site, ym, window_start_hour) |> mutate(level_1e15 = mean(tempo_vc_1e15)) |> ungroup() |>
    mutate(pbl_std = as.numeric(scale(pbl_anom_m)), col_std = as.numeric(scale(column_anom)),
           scans_std = as.numeric(scale(n_valid_scans)), level_std = as.numeric(scale(log(pmax(level_1e15, 0.5)))))
  lab <- if (h == 0L) "24 h" else sprintf("8 h, start %02d:00 LST", h)
  one <- function(f, model) {
    fit <- lm(f, data = d)
    V <- cluster_vcov(fit, d$site)
    co <- coef(fit); se <- sqrt(diag(V))
    tibble(sample = lab, model = model, n = nrow(d), n_sites = n_distinct(d$site),
           term = names(co), estimate = co, se_cluster = se, t = co / se,
           p = 2 * pt(-abs(co / se), df = n_distinct(d$site) - 1))
  }
  bind_rows(one(surface_anom ~ col_std * pbl_std, "mixing depth only"),
            one(surface_anom ~ col_std * pbl_std + col_std:scans_std + col_std:level_std + scans_std + level_std,
                "mixing depth, with valid-scan count and column level as competing moderators"))
})
data.table::fwrite(inter, file.path(P$tables, "diag10_pbl_interaction.csv"))
for (s in unique(tert$sample)) for (st in unique(tert$stratification)) {
  t1 <- filter(tert, sample == s, stratification == st)
  log_msg("D. ", s, ", ", st, ": r by tertile ", paste(round(t1$r, 2), collapse = " / "),
          " (n ", paste(t1$n, collapse = "/"), "); top - bottom ", round(t1$diff_top_minus_bottom[1], 2),
          " [", round(t1$diff_ci_lo[1], 2), ", ", round(t1$diff_ci_hi[1], 2), "]")
}
for (s in unique(inter$sample)) for (mo in unique(inter$model)) {
  i1 <- filter(inter, sample == s, model == mo, term == "col_std:pbl_std")
  log_msg("D. ", s, " [", mo, "]: interaction column x mixing depth ", sprintf("%+.3f (cluster SE %.3f, p = %.3f)", i1$estimate, i1$se_cluster, i1$p))
}

# ============================================================================
# manuscript numbers
# ============================================================================
p1 <- paired[1, ]; p12 <- filter(paired, startsWith(quantity, "anomaly r, 8 h 12:00 block minus 24 h"))
p4 <- filter(paired, startsWith(quantity, "anomaly r, 8 h 04:00 block minus 24 h"))
pc12 <- filter(paired, startsWith(quantity, "anomaly r, 24 h sample vs 12-20"))
pc4 <- filter(paired, startsWith(quantity, "anomaly r, 24 h sample vs 04-12"))
m2 <- filter(models, startsWith(model, "M2")); m1 <- filter(models, startsWith(model, "M1"))
t33 <- filter(ta, block == "3x3"); t11 <- filter(ta, block == "1x1"); t55 <- filter(ta, block == "5x5")
tr <- function(h, st, what) { x <- filter(tert, sample == h, stratification == st); x[[what]][1] }
nums <- tibble(
  key = c("dd_sites_total", "dd_sites_paired", "dd_median_r_24", "dd_median_r_8", "dd_diff_median", "dd_diff_lo", "dd_diff_hi",
          "dd_diff_positive", "dd_diff_p", "dd_diff12_median", "dd_diff12_lo", "dd_diff12_hi", "dd_diff12_p",
          "dd_diff4_median", "dd_diff4_lo", "dd_diff4_hi", "dd_diff4_p",
          "dd_col12_median", "dd_col12_lo", "dd_col12_hi", "dd_col4_median", "dd_col4_lo", "dd_col4_hi",
          "dd_usable_diff_median", "dd_scans_diff_median",
          "gap_sites", "gap_median_E", "gap_E_iqr_lo", "gap_E_iqr_hi", "gap_m1_r2", "gap_m2_r2", "gap_m2_sites",
          "gap_m2_surface_coef", "gap_m2_surface_p", "gap_m2_snr_coef", "gap_m2_snr_p", "gap_m2_pbl_coef", "gap_m2_pbl_p",
          "gap_m2_smoke_coef", "gap_m2_smoke_p", "gap_m2_usable_coef", "gap_m2_usable_p", "gap_m2_scans_coef", "gap_m2_scans_p",
          "gap_m1_snr_coef", "gap_m1_snr_p", "gap_m1_surface_coef", "gap_m1_surface_p",
          "gap_uni_E_surface_rho", "gap_uni_E_snr_rho", "gap_uni_r_snr_rho", "gap_uni_r_surface_rho",
          "ta_samples", "ta_kmin", "ta_draws", "ta_r1_33", "ta_r1_33_lo", "ta_r1_33_hi", "ta_r2_33", "ta_r3_33", "ta_r4_33", "ta_rall_33",
          "ta_all_median_scans_33", "ta_r1_11", "ta_rall_11", "ta_r1_55", "ta_rall_55",
          "ta_siter1_33", "ta_siterall_33", "ta_noise_33", "ta_noise_11", "ta_noise_55", "ta_sd1_33", "ta_sdall_33",
          "pbl_8h12_n", "pbl_8h12_r_low", "pbl_8h12_r_mid", "pbl_8h12_r_high", "pbl_8h12_diff", "pbl_8h12_lo", "pbl_8h12_hi",
          "pbl_8h12_rel_r_low", "pbl_8h12_rel_r_high", "pbl_8h12_rel_diff", "pbl_8h12_rel_lo", "pbl_8h12_rel_hi",
          "pbl_8h4_n", "pbl_8h4_r_low", "pbl_8h4_r_mid", "pbl_8h4_r_high", "pbl_8h4_diff", "pbl_8h4_lo", "pbl_8h4_hi",
          "pbl_8h4_rel_r_low", "pbl_8h4_rel_r_high", "pbl_8h4_rel_diff", "pbl_8h4_rel_lo", "pbl_8h4_rel_hi",
          "pbl_24_n", "pbl_24_r_low", "pbl_24_r_high", "pbl_24_diff", "pbl_24_lo", "pbl_24_hi",
          "pbl_24_rel_r_low", "pbl_24_rel_r_high", "pbl_24_rel_diff", "pbl_24_rel_lo", "pbl_24_rel_hi",
          "pbl_int_8h4", "pbl_int_8h4_p", "pbl_int_8h12", "pbl_int_8h12_p", "pbl_int_24", "pbl_int_24_p",
          "pbl_8h4_km_low", "pbl_8h4_km_high", "pbl_8h12_km_low", "pbl_8h12_km_high",
          "pbl_int_adj_8h4", "pbl_int_adj_8h4_p", "pbl_int_adj_8h12", "pbl_int_adj_8h12_p", "pbl_int_adj_24", "pbl_int_adj_24_p",
          "pbl_8h4_sf_r_low", "pbl_8h4_sf_r_high", "pbl_8h4_sf_diff", "pbl_8h4_sf_lo", "pbl_8h4_sf_hi", "pbl_8h4_sf_n",
          "pbl_8h12_sf_r_low", "pbl_8h12_sf_r_high", "pbl_8h12_sf_diff", "pbl_8h12_sf_lo", "pbl_8h12_sf_hi", "pbl_8h12_sf_n",
          "pbl_8h4_sdcol_low", "pbl_8h4_sdcol_high", "pbl_8h12_sdcol_low", "pbl_8h12_sdcol_high"),
  value = c(length(dual_sites), nrow(both), sprintf("%.2f", median(both$anom_r_24h)), sprintf("%.2f", median(both$anom_r_8h)),
            sprintf("%.2f", p1$median_diff), sprintf("%.2f", p1$mean_ci_lo), sprintf("%.2f", p1$mean_ci_hi),
            p1$n_positive, sprintf("%.2f", p1$wilcoxon_p),
            sprintf("%.2f", p12$median_diff), sprintf("%.2f", p12$mean_ci_lo), sprintf("%.2f", p12$mean_ci_hi), sprintf("%.2f", p12$wilcoxon_p),
            sprintf("%.2f", p4$median_diff), sprintf("%.2f", p4$mean_ci_lo), sprintf("%.2f", p4$mean_ci_hi), sprintf("%.2f", p4$wilcoxon_p),
            sprintf("%.2f", pc12$median_diff), sprintf("%.2f", pc12$mean_ci_lo), sprintf("%.2f", pc12$mean_ci_hi),
            sprintf("%.2f", pc4$median_diff), sprintf("%.2f", pc4$mean_ci_lo), sprintf("%.2f", pc4$mean_ci_hi),
            sprintf("%.0f", paired$median_diff[3]), sprintf("%.0f", paired$median_diff[4]),
            nrow(gap), sprintf("%.2f", median(gap$efficiency)), sprintf("%.2f", quantile(gap$efficiency, 0.25)[[1]]), sprintf("%.2f", quantile(gap$efficiency, 0.75)[[1]]),
            sprintf("%.2f", m1$r2[1]), sprintf("%.2f", m2$r2[1]), m2$n_sites[1],
            sprintf("%+.2f", m2$estimate_per_sd[m2$term == "log_surface"]), sprintf("%.3f", m2$p[m2$term == "log_surface"]),
            sprintf("%+.2f", m2$estimate_per_sd[m2$term == "log_snr"]), sprintf("%.3f", m2$p[m2$term == "log_snr"]),
            sprintf("%+.2f", m2$estimate_per_sd[m2$term == "pbl_hrrr_km"]), sprintf("%.3f", m2$p[m2$term == "pbl_hrrr_km"]),
            sprintf("%+.2f", m2$estimate_per_sd[m2$term == "smoke_share"]), sprintf("%.3f", m2$p[m2$term == "smoke_share"]),
            sprintf("%+.2f", m2$estimate_per_sd[m2$term == "usable_pct"]), sprintf("%.3f", m2$p[m2$term == "usable_pct"]),
            sprintf("%+.2f", m2$estimate_per_sd[m2$term == "log_scans"]), sprintf("%.3f", m2$p[m2$term == "log_scans"]),
            sprintf("%+.2f", m1$estimate_per_sd[m1$term == "log_snr"]), sprintf("%.3f", m1$p[m1$term == "log_snr"]),
            sprintf("%+.2f", m1$estimate_per_sd[m1$term == "log_surface"]), sprintf("%.3f", m1$p[m1$term == "log_surface"]),
            sprintf("%.2f", uni$spearman_rho[uni$outcome == "E = r_obs / ceiling" & uni$predictor == preds[["log_surface"]]]),
            sprintf("%.2f", uni$spearman_rho[uni$outcome == "E = r_obs / ceiling" & uni$predictor == preds[["log_snr"]]]),
            sprintf("%.2f", uni$spearman_rho[uni$outcome == "anomaly r (observed)" & uni$predictor == preds[["log_snr"]]]),
            sprintf("%.2f", uni$spearman_rho[uni$outcome == "anomaly r (observed)" & uni$predictor == preds[["log_surface"]]]),
            nrow(eligible), KMIN, NDRAW,
            sprintf("%.2f", t33$r_pooled[t33$k_scans == "1"]), sprintf("%.2f", t33$r_pooled_lo[t33$k_scans == "1"]), sprintf("%.2f", t33$r_pooled_hi[t33$k_scans == "1"]),
            sprintf("%.2f", t33$r_pooled[t33$k_scans == "2"]), sprintf("%.2f", t33$r_pooled[t33$k_scans == "3"]), sprintf("%.2f", t33$r_pooled[t33$k_scans == "4"]),
            sprintf("%.2f", t33$r_pooled[t33$k_scans == "all"]), t33$median_valid_scans_all[1],
            sprintf("%.2f", t11$r_pooled[t11$k_scans == "1"]), sprintf("%.2f", t11$r_pooled[t11$k_scans == "all"]),
            sprintf("%.2f", t55$r_pooled[t55$k_scans == "1"]), sprintf("%.2f", t55$r_pooled[t55$k_scans == "all"]),
            sprintf("%.2f", t33$median_site_r[t33$k_scans == "1"]), sprintf("%.2f", t33$median_site_r[t33$k_scans == "all"]),
            sprintf("%.1f", noise_fit$single_scan_noise_sd_1e15[noise_fit$block == "3x3"]),
            sprintf("%.1f", noise_fit$single_scan_noise_sd_1e15[noise_fit$block == "1x1"]),
            sprintf("%.1f", noise_fit$single_scan_noise_sd_1e15[noise_fit$block == "5x5"]),
            sprintf("%.2f", t33$sd_column_anom_1e15[t33$k_scans == "1"]), sprintf("%.2f", t33$sd_column_anom_1e15[t33$k_scans == "all"]),
            sum(filter(tert, sample == "8 h, start 12:00 LST", stratification == "absolute HRRR mixing depth")$n),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "absolute HRRR mixing depth", "r")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 12:00 LST", stratification == "absolute HRRR mixing depth", tert == 2)$r),
            sprintf("%.2f", filter(tert, sample == "8 h, start 12:00 LST", stratification == "absolute HRRR mixing depth", tert == 3)$r),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "absolute HRRR mixing depth", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "absolute HRRR mixing depth", "diff_ci_lo")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "absolute HRRR mixing depth", "diff_ci_hi")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "mixing depth relative to site-month", "r")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 12:00 LST", stratification == "mixing depth relative to site-month", tert == 3)$r),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "mixing depth relative to site-month", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "mixing depth relative to site-month", "diff_ci_lo")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "mixing depth relative to site-month", "diff_ci_hi")),
            sum(filter(tert, sample == "8 h, start 04:00 LST", stratification == "absolute HRRR mixing depth")$n),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "absolute HRRR mixing depth", "r")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 04:00 LST", stratification == "absolute HRRR mixing depth", tert == 2)$r),
            sprintf("%.2f", filter(tert, sample == "8 h, start 04:00 LST", stratification == "absolute HRRR mixing depth", tert == 3)$r),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "absolute HRRR mixing depth", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "absolute HRRR mixing depth", "diff_ci_lo")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "absolute HRRR mixing depth", "diff_ci_hi")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "mixing depth relative to site-month", "r")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 04:00 LST", stratification == "mixing depth relative to site-month", tert == 3)$r),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "mixing depth relative to site-month", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "mixing depth relative to site-month", "diff_ci_lo")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "mixing depth relative to site-month", "diff_ci_hi")),
            sum(filter(tert, sample == "24 h", stratification == "absolute HRRR mixing depth")$n),
            sprintf("%.2f", tr("24 h", "absolute HRRR mixing depth", "r")),
            sprintf("%.2f", filter(tert, sample == "24 h", stratification == "absolute HRRR mixing depth", tert == 3)$r),
            sprintf("%.2f", tr("24 h", "absolute HRRR mixing depth", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("24 h", "absolute HRRR mixing depth", "diff_ci_lo")),
            sprintf("%.2f", tr("24 h", "absolute HRRR mixing depth", "diff_ci_hi")),
            sprintf("%.2f", tr("24 h", "mixing depth relative to site-month", "r")),
            sprintf("%.2f", filter(tert, sample == "24 h", stratification == "mixing depth relative to site-month", tert == 3)$r),
            sprintf("%.2f", tr("24 h", "mixing depth relative to site-month", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("24 h", "mixing depth relative to site-month", "diff_ci_lo")),
            sprintf("%.2f", tr("24 h", "mixing depth relative to site-month", "diff_ci_hi")),
            sprintf("%+.3f", filter(inter, sample == "8 h, start 04:00 LST", model == "mixing depth only", term == "col_std:pbl_std")$estimate),
            sprintf("%.3f", filter(inter, sample == "8 h, start 04:00 LST", model == "mixing depth only", term == "col_std:pbl_std")$p),
            sprintf("%+.3f", filter(inter, sample == "8 h, start 12:00 LST", model == "mixing depth only", term == "col_std:pbl_std")$estimate),
            sprintf("%.3f", filter(inter, sample == "8 h, start 12:00 LST", model == "mixing depth only", term == "col_std:pbl_std")$p),
            sprintf("%+.3f", filter(inter, sample == "24 h", model == "mixing depth only", term == "col_std:pbl_std")$estimate),
            sprintf("%.3f", filter(inter, sample == "24 h", model == "mixing depth only", term == "col_std:pbl_std")$p),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "absolute HRRR mixing depth", "pbl_median_km")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 04:00 LST", stratification == "absolute HRRR mixing depth", tert == 3)$pbl_median_km),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "absolute HRRR mixing depth", "pbl_median_km")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 12:00 LST", stratification == "absolute HRRR mixing depth", tert == 3)$pbl_median_km),
            sprintf("%+.3f", filter(inter, sample == "8 h, start 04:00 LST", model != "mixing depth only", term == "col_std:pbl_std")$estimate),
            sprintf("%.3f", filter(inter, sample == "8 h, start 04:00 LST", model != "mixing depth only", term == "col_std:pbl_std")$p),
            sprintf("%+.3f", filter(inter, sample == "8 h, start 12:00 LST", model != "mixing depth only", term == "col_std:pbl_std")$estimate),
            sprintf("%.3f", filter(inter, sample == "8 h, start 12:00 LST", model != "mixing depth only", term == "col_std:pbl_std")$p),
            sprintf("%+.3f", filter(inter, sample == "24 h", model != "mixing depth only", term == "col_std:pbl_std")$estimate),
            sprintf("%.3f", filter(inter, sample == "24 h", model != "mixing depth only", term == "col_std:pbl_std")$p),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "relative to site-month, smoke-free days only", "r")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 04:00 LST", stratification == "relative to site-month, smoke-free days only", tert == 3)$r),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "relative to site-month, smoke-free days only", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "relative to site-month, smoke-free days only", "diff_ci_lo")),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "relative to site-month, smoke-free days only", "diff_ci_hi")),
            sum(filter(tert, sample == "8 h, start 04:00 LST", stratification == "relative to site-month, smoke-free days only")$n),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "relative to site-month, smoke-free days only", "r")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 12:00 LST", stratification == "relative to site-month, smoke-free days only", tert == 3)$r),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "relative to site-month, smoke-free days only", "diff_top_minus_bottom")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "relative to site-month, smoke-free days only", "diff_ci_lo")),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "relative to site-month, smoke-free days only", "diff_ci_hi")),
            sum(filter(tert, sample == "8 h, start 12:00 LST", stratification == "relative to site-month, smoke-free days only")$n),
            sprintf("%.2f", tr("8 h, start 04:00 LST", "absolute HRRR mixing depth", "sd_column_anom_1e15")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 04:00 LST", stratification == "absolute HRRR mixing depth", tert == 3)$sd_column_anom_1e15),
            sprintf("%.2f", tr("8 h, start 12:00 LST", "absolute HRRR mixing depth", "sd_column_anom_1e15")),
            sprintf("%.2f", filter(tert, sample == "8 h, start 12:00 LST", stratification == "absolute HRRR mixing depth", tert == 3)$sd_column_anom_1e15))
) |> mutate(value = as.character(value), source = "R/20_agreement_diagnostics.R")
data.table::fwrite(nums, file.path(P$tables, "manuscript_numbers_20.csv"))

# ============================================================================
# figures
# ============================================================================
if (HAS_GG) {
  # fig20: paired r at the dual-duration sites
  p20 <- ggplot(both, aes(anom_r_24h, anom_r_8h)) +
    geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = 2) +
    geom_hline(yintercept = 0, colour = "grey85") + geom_vline(xintercept = 0, colour = "grey85") +
    geom_point(aes(size = pmin(anom_n_24h, anom_n_8h)), shape = 21, fill = "steelblue", alpha = 0.8) +
    geom_text(aes(label = state), size = 2.4, vjust = -1) +
    scale_size_area(max_size = 6, name = "anomaly pairs\n(smaller duration)") +
    coord_equal(xlim = c(-0.3, 1), ylim = c(-0.3, 1)) +
    labs(x = "Within-month anomaly r, 24 h samples", y = "Within-month anomaly r, 8 h samples",
         title = sprintf("%d monitors reporting both durations", nrow(both)))
  ggsave(file.path(P$figures, "fig20_dual_duration.png"), p20, width = 5.5, height = 5.2, dpi = 300)

  # fig21: observed r against its ceiling, and E against the site descriptors
  long <- gap |>
    select(site, efficiency, anomaly_r_observed, median_surface_ugm3, snr, median_valid_scans, usable_pct, pbl_hrrr_km, smoke_share) |>
    pivot_longer(c(median_surface_ugm3, snr, median_valid_scans, usable_pct, pbl_hrrr_km, smoke_share),
                 names_to = "predictor", values_to = "x") |>
    mutate(predictor = factor(predictor, levels = c("median_surface_ugm3", "snr", "median_valid_scans", "usable_pct", "pbl_hrrr_km", "smoke_share"),
                              labels = c("median surface HCHO (µg m⁻³)", "signal-to-noise ratio", "median valid scans",
                                         "usable share (%)", "HRRR mixing depth (km)", "smoke-affected share")))
  p21a <- ggplot(gap, aes(ceiling_empirical, anomaly_r_observed)) +
    geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = 2) +
    geom_abline(slope = 0.5, intercept = 0, colour = "grey80", linetype = 3) +
    geom_point(aes(colour = median_surface_ugm3), size = 2) +
    scale_colour_viridis_c(name = "median surface\nHCHO (µg m⁻³)", trans = "log10") +
    coord_equal(xlim = c(0.5, 1), ylim = c(-0.3, 1)) +
    labs(x = "Noise ceiling on r", y = "Observed anomaly r", title = "(a) Observed against ceiling")
  p21b <- ggplot(long, aes(x, efficiency)) +
    geom_hline(yintercept = 1, colour = "grey60", linetype = 2) +
    geom_point(alpha = 0.6, size = 1.4) + geom_smooth(method = "loess", se = FALSE, colour = "firebrick", linewidth = 0.6, span = 1) +
    facet_wrap(~ predictor, scales = "free_x") +
    labs(x = NULL, y = "E = observed r / ceiling", title = "(b) The noise-corrected agreement against site descriptors")
  png(file.path(P$figures, "fig21_ceiling_gap.png"), width = 8.5, height = 9, units = "in", res = 300)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(2, 1, heights = grid::unit(c(0.42, 0.58), "npc"))))
  print(p21a, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
  print(p21b, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
  dev.off()

  # fig22: r against scans averaged, by block
  p22 <- ggplot(ta |> mutate(k = factor(k_scans, levels = c(as.character(seq_len(KMIN)), "all"))),
                aes(k, r_pooled, group = block, colour = block)) +
    geom_ribbon(aes(ymin = r_pooled_lo, ymax = r_pooled_hi, fill = block), alpha = 0.15, colour = NA) +
    geom_line() + geom_point() +
    labs(x = "TEMPO scans averaged per 24 h sample", y = "Within-month anomaly r (pooled)",
         colour = "grid-cell block", fill = "grid-cell block",
         title = sprintf("%d samples with at least %d valid scans", nrow(eligible), KMIN))
  ggsave(file.path(P$figures, "fig22_temporal_averaging.png"), p22, width = 6, height = 4, dpi = 300)

  # fig23: r by mixing-depth tertile
  p23 <- ggplot(tert |> mutate(tert = factor(tert, labels = c("shallow", "middle", "deep"))),
                aes(tert, r, fill = stratification)) +
    geom_col(position = position_dodge(0.7), width = 0.65) +
    facet_wrap(~ sample) +
    labs(x = "HRRR mixing depth over the sampling window (tertile)", y = "Within-month anomaly r", fill = NULL) +
    theme(legend.position = "bottom")
  ggsave(file.path(P$figures, "fig23_pbl_tertiles.png"), p23, width = 8, height = 3.8, dpi = 300)
}
log_msg("Agreement diagnostics done.")
