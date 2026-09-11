# =============================================================================
# 09_diagnostics.R - tests of candidate explanations for the main results
#
# Uses outputs of steps 04, 05, 07 and 08 only (no downloads).
#   1. 3-h arm: do TEMPO columns in the two candidate windows (06-09 and 09-12
#      MST) vary together from day to day? Are early scans screened out more
#      often, or noisier, at one site than the other?
#   2. 3-h arm: start vs end convention compared on the SAME samples
#      (Williams' test for dependent correlations + paired bootstrap), and the
#      seasonal mix of usable samples under each convention
#   3. 24-h arm: how much day-to-day column variability is retrieval noise, and
#      the correlation ceiling that noise alone implies (by site and block size)
#   4. Terrain heterogeneity inside the averaging blocks (TEMPO surface
#      pressure); day-to-day agreement by site and season
#   5. Smoke days: cloud fraction and scan survival by smoke class within
#      season (HMS analysts map smoke only where skies are clear)
# Outputs: output/tables/diag1_* ... diag5_*, output/figures/figS3_*, figS4_*
# =============================================================================
source("R/00_config.R")
source("R/helpers_stats.R")
set.seed(42)
nboot <- 2000L
A24 <- arm_paths("coatts")
A3  <- arm_paths("threeh")
season_levels <- c("DJF", "MAM", "JJA", "SON")

out_tbl <- function(d, name) {
  data.table::fwrite(d, file.path(P$tables, name))
  log_msg("  table: ", name)
  invisible(d)
}
# run fun() on every site and on all sites pooled; fun gets a data frame with a site column
by_site_and_all <- function(d, fun) {
  per_site <- imap(split(d, d$site), function(x, s) mutate(fun(x), site = s, .before = 1)) |> list_rbind()
  bind_rows(per_site, mutate(fun(d), site = "all sites", .before = 1))
}
read_cells <- function(path) {
  cells <- read_tbl(path, colClasses = list(character = c("granule", "scan_start_utc", "site")))
  for (col in setdiff(names(cells), c("granule", "scan_start_utc", "site"))) {
    x <- cells[[col]]
    if (!is.numeric(x) || inherits(x, "integer64")) cells[[col]] <- suppressWarnings(as.numeric(as.character(x)))
  }
  for (v in c("main_data_quality_flag", "eff_cloud_fraction", "snow_ice_fraction", "solar_zenith_angle",
              "pbl_height", "vertical_column_uncertainty", "surface_pressure")) {
    if (!v %in% names(cells)) cells[[v]] <- NA_real_
  }
  cells
}
read_manifest <- function(path) {
  read_tbl(path, colClasses = "character") |>
    transmute(sample_date = as.Date(sample_date), granule, mid_utc = ymd_hms(mid_utc),
              local_hour = as.numeric(local_hour)) |>
    distinct()
}
nan_to_na <- function(x) ifelse(is.nan(x), NA_real_, x)

# Cell screening exactly as in steps 04 and 07, plus the reason(s) a cell fails
flag_cells <- function(d, max_ecf = CFG$qc_max_cloud_fraction) {
  d |>
    mutate(fail_sza   = coalesce(solar_zenith_angle, 0) > CFG$qc_max_sza,
           fail_snow  = coalesce(snow_ice_fraction, 0) > CFG$qc_max_snow_ice,
           fail_qf    = is.na(vertical_column) | coalesce(main_data_quality_flag, 0) > CFG$qc_max_quality_flag,
           fail_cloud = is.na(eff_cloud_fraction) | eff_cloud_fraction > max_ecf,
           pass = !fail_sza & !fail_snow & !fail_qf & !fail_cloud)
}
# One row per granule x site: block mean of passing cells and screening shares
scan_level <- function(cells, block, max_ecf = CFG$qc_max_cloud_fraction) {
  cells |>
    filter(abs(di) <= block, abs(dj) <= block) |>
    flag_cells(max_ecf) |>
    group_by(granule, site) |>
    summarise(n_cells = n(), n_pass = sum(pass),
              vc    = if (any(pass)) mean(vertical_column[pass]) else NA_real_,
              u_rms = if (any(pass)) sqrt(mean(vertical_column_uncertainty[pass]^2, na.rm = TRUE)) else NA_real_,
              ecf   = mean(eff_cloud_fraction, na.rm = TRUE),
              sza   = mean(solar_zenith_angle, na.rm = TRUE),
              share_fail_sza = mean(fail_sza), share_fail_snow = mean(fail_snow),
              share_fail_qf = mean(fail_qf), share_fail_cloud = mean(fail_cloud),
              share_pass = mean(pass), .groups = "drop") |>
    mutate(valid = n_pass >= pmax(1, ceiling(CFG$qc_min_cell_fraction * n_cells)),
           u_rms = nan_to_na(u_rms), ecf = nan_to_na(ecf), sza = nan_to_na(sza))
}
# Williams' t for two dependent correlations sharing y: cor(y, x1) vs cor(y, x2)
# (Steiger 1980, eq. 7), with a paired bootstrap CI for the difference
dep_cor_test <- function(y, x1, x2) {
  ok <- is.finite(y) & is.finite(x1) & is.finite(x2)
  y <- y[ok]; x1 <- x1[ok]; x2 <- x2[ok]; n <- length(y)
  if (n < 8) return(tibble(n = n))
  r12 <- cor(y, x1); r13 <- cor(y, x2); r23 <- cor(x1, x2)
  detR <- 1 - r12^2 - r13^2 - r23^2 + 2 * r12 * r13 * r23
  rbar <- (r12 + r13) / 2
  t <- (r12 - r13) * sqrt((n - 1) * (1 + r23) / (2 * ((n - 1) / (n - 3)) * detR + rbar^2 * (1 - r23)^3))
  bt <- replicate(nboot, {
    k <- sample.int(n, n, replace = TRUE)
    suppressWarnings(cor(y[k], x1[k]) - cor(y[k], x2[k]))
  })
  tibble(n = n, r_start = r12, r_end = r13, r_between_window_columns = r23, diff_start_minus_end = r12 - r13,
         diff_ci_lo = quantile(bt, 0.025, na.rm = TRUE)[[1]], diff_ci_hi = quantile(bt, 0.975, na.rm = TRUE)[[1]],
         williams_t = t, df = n - 3, williams_p = 2 * pt(-abs(t), df = n - 3))
}

summary_lines <- character()
note <- function(...) { line <- paste0(...); summary_lines <<- c(summary_lines, line); log_msg(line) }

# =============================================================================
# Tests 1-2: 3-h arm
# =============================================================================
th_primary_path <- file.path(P$processed, "threeh_matched_primary.csv")
have_threeh <- isTRUE(CFG$run_three_hour_arm) && file.exists(th_primary_path) && file.exists(A3$cells)
if (have_threeh) {
  log_msg("Tests 1-2: 3-h arm")
  prim3 <- read_tbl(th_primary_path, colClasses = list(character = "stamp_local")) |>
    mutate(sample_date = as.Date(sample_date), season = factor(season, levels = season_levels),
           usable = as.logical(usable))
  if ("stamp_time_unusual" %in% names(prim3) && isTRUE(CFG$threeh_exclude_unusual_stamps)) {
    prim3 <- filter(prim3, !(as.logical(stamp_time_unusual) %in% TRUE))
  }
  stopifnot(all(c("start", "end") %in% prim3$convention))

  wide3 <- prim3 |>
    select(site, sample_date, stamp_local, season, hcho_ugm3, convention, tempo_vc_1e15, n_valid_scans) |>
    pivot_wider(names_from = convention, values_from = c(tempo_vc_1e15, n_valid_scans))
  both <- wide3 |> filter(is.finite(hcho_ugm3), is.finite(tempo_vc_1e15_start), is.finite(tempo_vc_1e15_end))
  note("3-h samples usable under both conventions: ", nrow(both), " (",
       paste(names(table(both$site)), table(both$site), sep = " ", collapse = ", "), ")")

  # ---- 1a. same-day columns in the two windows ------------------------------------
  window_pair <- function(d) {
    if (nrow(d) < 6) return(tibble(n = nrow(d)))
    an <- d |>
      mutate(ym = floor_date(sample_date, "month")) |>
      group_by(site, ym) |> filter(n() >= CFG$min_days_per_site_month) |>
      mutate(a_start = tempo_vc_1e15_start - mean(tempo_vc_1e15_start),
             a_end = tempo_vc_1e15_end - mean(tempo_vc_1e15_end)) |>
      ungroup()
    dif <- d$tempo_vc_1e15_start - d$tempo_vc_1e15_end
    tibble(n = nrow(d),
           r_columns = cor(d$tempo_vc_1e15_start, d$tempo_vc_1e15_end),
           n_anomalies = nrow(an),
           r_column_anomalies = if (nrow(an) >= 6) cor(an$a_start, an$a_end) else NA_real_,
           median_column_start_1e15 = median(d$tempo_vc_1e15_start),
           median_column_end_1e15 = median(d$tempo_vc_1e15_end),
           median_diff_start_minus_end = median(dif),
           wilcoxon_p = suppressWarnings(wilcox.test(dif)$p.value))
  }
  t1a <- by_site_and_all(both, window_pair)
  out_tbl(t1a, "diag1_threeh_window_columns.csv")
  print(t1a)
  for (i in seq_len(nrow(t1a))) note("  ", t1a$site[i], ": r(09-12 vs 06-09 columns) = ", round(t1a$r_columns[i], 2),
                                     "; anomalies r = ", round(t1a$r_column_anomalies[i], 2),
                                     "; median start-end = ", round(t1a$median_diff_start_minus_end[i], 2), " e15")

  # ---- 1b. screening and noise of scans in each window ------------------------------
  cells3 <- read_cells(A3$cells)
  man3 <- read_manifest(A3$manifest) |> distinct(granule, mid_utc)
  scans3 <- scan_level(cells3, block = 1L) |> inner_join(man3, by = "granule", relationship = "many-to-many")
  samp3 <- prim3 |> distinct(site, sample_date, stamp_local, season)
  win3 <- map(c("start", "end"), function(cv) {
    samp3 |>
      mutate(stamp = parse_date_time(stamp_local, orders = c("Ymd HM", "Ymd HMS"), tz = "UTC"),
             win_start_local = if (cv == "start") stamp else stamp - CFG$threeh_duration_s,
             win_start_utc = win_start_local - CFG$utc_offset_hours * 3600,
             win_end_utc = win_start_utc + CFG$threeh_duration_s,
             convention = cv)
  }) |> list_rbind()
  sw <- win3 |>
    select(site, sample_date, stamp_local, season, convention, win_start_utc, win_end_utc) |>
    inner_join(scans3, by = "site", relationship = "many-to-many") |>
    filter(mid_utc >= win_start_utc, mid_utc < win_end_utc)

  screen_summary <- function(g) {
    g |> summarise(samples = n_distinct(stamp_local), scans = n(),
                   valid_scan_share = mean(valid),
                   median_sza = median(sza, na.rm = TRUE),
                   share_cells_fail_sza = mean(share_fail_sza),
                   share_cells_fail_snow = mean(share_fail_snow),
                   share_cells_fail_quality_flag = mean(share_fail_qf),
                   share_cells_fail_cloud = mean(share_fail_cloud),
                   share_cells_pass = mean(share_pass),
                   median_cell_uncertainty_1e15 = median(u_rms[valid], na.rm = TRUE) / 1e15,
                   .groups = "drop")
  }
  noise3 <- sw |>
    filter(valid) |>
    arrange(convention, site, stamp_local, mid_utc) |>
    group_by(convention, site, stamp_local) |>
    mutate(d = vc - lag(vc)) |>
    ungroup() |>
    filter(!is.na(d)) |>
    group_by(convention, site) |>
    summarise(n_scan_pairs = n(),
              scan_noise_rms_1e15 = sqrt(mean(d^2) / 2) / 1e15,   # upper bound: includes real hourly change
              scan_noise_mad_1e15 = mad(d) / sqrt(2) / 1e15,
              .groups = "drop")
  t1b <- bind_rows(
    sw |> group_by(convention, site) |> screen_summary() |> mutate(season = "all") |> left_join(noise3, by = c("convention", "site")),
    sw |> group_by(convention, site, season) |> screen_summary() |> mutate(season = as.character(season))
  ) |>
    mutate(window = if_else(convention == "start", "stamp to stamp+3h (09-12 MST)", "stamp-3h to stamp (06-09 MST)")) |>
    relocate(convention, window, site, season) |>
    arrange(site, season != "all", season, convention)
  out_tbl(t1b, "diag1_threeh_window_screening.csv")
  print(filter(t1b, season == "all") |>
          select(convention, site, scans, valid_scan_share, share_cells_fail_sza, share_cells_fail_cloud,
                 median_cell_uncertainty_1e15, scan_noise_rms_1e15))

  # ---- 2a. start vs end on the same samples ---------------------------------------------
  both_anom <- both |>
    mutate(ym = floor_date(sample_date, "month")) |>
    group_by(site, ym) |> filter(n() >= CFG$min_days_per_site_month) |>
    mutate(s_a = hcho_ugm3 - mean(hcho_ugm3),
           cs_a = tempo_vc_1e15_start - mean(tempo_vc_1e15_start),
           ce_a = tempo_vc_1e15_end - mean(tempo_vc_1e15_end)) |>
    ungroup()
  t2a <- bind_rows(
    by_site_and_all(both, function(d) dep_cor_test(d$hcho_ugm3, d$tempo_vc_1e15_start, d$tempo_vc_1e15_end)) |>
      mutate(comparison = "whole period", .after = site),
    by_site_and_all(both_anom, function(d) dep_cor_test(d$s_a, d$cs_a, d$ce_a)) |>
      mutate(comparison = "within-month anomalies", .after = site)
  )
  out_tbl(t2a, "diag2_threeh_paired_conventions.csv")
  print(t2a)
  for (i in seq_len(nrow(t2a))) note("  ", t2a$site[i], ", ", t2a$comparison[i], " (same ", t2a$n[i], " samples): r start ",
                                     round(t2a$r_start[i], 2), " vs end ", round(t2a$r_end[i], 2),
                                     ", Williams p = ", signif(t2a$williams_p[i], 2))

  # ---- 2b. which months end up usable under each convention ---------------------------
  t2b <- prim3 |>
    group_by(convention, site, season) |>
    summarise(samples = n(), usable = sum(usable), usable_pct = round(100 * mean(usable), 1), .groups = "drop") |>
    arrange(site, convention, season)
  out_tbl(t2b, "diag2_threeh_usable_by_season.csv")

  # ---- figure S3 ------------------------------------------------------------------
  labs3 <- t1a |> filter(site != "all sites") |>
    mutate(label = sprintf("n = %d, r = %.2f\nanomaly r = %.2f", n, r_columns, r_column_anomalies))
  pS3 <- ggplot(both, aes(tempo_vc_1e15_end, tempo_vc_1e15_start, colour = season)) +
    geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") +
    geom_point(size = 1.6, alpha = 0.8) +
    geom_text(data = labs3, aes(x = -Inf, y = Inf, label = label), inherit.aes = FALSE,
              hjust = -0.08, vjust = 1.2, size = 3) +
    facet_wrap(~site) +
    labs(x = "TEMPO column, window before the stamp (06-09 MST), 1e15 molec/cm2",
         y = "TEMPO column, window after the stamp (09-12 MST), 1e15 molec/cm2",
         colour = "Season", title = "Same-sample TEMPO columns in the two candidate 3-h windows") +
    theme_bw(base_size = 10)
  ggsave(file.path(P$figures, "figS3_threeh_window_columns.png"), pS3, width = 8, height = 4.3, dpi = 300)
  log_msg("  figure: figS3_threeh_window_columns.png")
} else {
  log_msg("Tests 1-2 skipped (3-h arm outputs not found)")
}

# =============================================================================
# Test 3: retrieval noise and the correlation ceiling it implies (24-h arm)
# =============================================================================
log_msg("Test 3: retrieval noise (24-h arm)")
variants24 <- read_tbl(file.path(P$processed, "matched_variants.csv")) |>
  mutate(sample_date = as.Date(sample_date), season = factor(season, levels = season_levels),
         usable = as.logical(usable)) |>
  filter(window == "all_day", max_ecf == CFG$qc_max_cloud_fraction)
cells24 <- read_cells(A24$cells)
man24 <- read_manifest(A24$manifest) |> select(granule, sample_date, mid_utc)

noise_rows <- map(sort(unique(variants24$block)), function(b) {
  d <- filter(variants24, block == b, usable)
  blabel <- first(d$block_label)
  sc <- scan_level(cells24, block = b) |>
    inner_join(man24, by = "granule", relationship = "many-to-many") |>
    semi_join(d, by = c("site", "sample_date"))
  daily <- sc |>
    group_by(site, sample_date) |>
    summarise(n_valid = sum(valid),
              vc_recomputed = if (any(valid)) mean(vc[valid]) else NA_real_,
              # reported uncertainty of the daily mean, two bounds:
              var_corr  = if (any(valid)) mean(u_rms[valid]^2, na.rm = TRUE) / sum(valid) else NA_real_,               # cells in a block fully correlated
              var_indep = if (any(valid)) mean(u_rms[valid]^2 / n_pass[valid], na.rm = TRUE) / sum(valid) else NA_real_, # cells independent
              .groups = "drop")
  chk <- inner_join(daily, select(d, site, sample_date, tempo_vc), by = c("site", "sample_date"))
  log_msg(sprintf("  %s: recomputed daily columns match step 04 to within %.2g molec/cm2 (n = %d)",
                  blabel, max(abs(chk$vc_recomputed - chk$tempo_vc), na.rm = TRUE), nrow(chk)))
  # empirical scan-to-scan noise from successive valid scans (<= 1.6 h apart) on the same day
  emp <- sc |>
    filter(valid) |>
    arrange(site, sample_date, mid_utc) |>
    group_by(site, sample_date) |>
    mutate(dv = vc - lag(vc), gap_h = as.numeric(difftime(mid_utc, lag(mid_utc), units = "hours"))) |>
    ungroup() |>
    filter(!is.na(dv), gap_h <= 1.6)
  emp_site <- emp |> group_by(site) |> summarise(scan_noise_var = mean(dv^2) / 2, n_scan_pairs = n(), .groups = "drop")
  emp_all  <- tibble(site = "all sites", scan_noise_var = mean(emp$dv^2) / 2, n_scan_pairs = nrow(emp))

  an <- add_month_anomalies(d, CFG$min_days_per_site_month) |>
    group_by(site, ym) |> mutate(n_month = n()) |> ungroup() |>
    left_join(select(daily, site, sample_date, n_valid, var_corr, var_indep), by = c("site", "sample_date"))

  ceiling_stats <- function(x, scan_var) {
    if (nrow(x) < 6) return(tibble(n_anomalies = nrow(x)))
    shrink <- 1 - 1 / x$n_month                     # removing the month mean also removes some noise
    obs_var <- var(x$column_anom)
    nv_corr  <- mean(x$var_corr * shrink, na.rm = TRUE) / 1e30
    nv_indep <- mean(x$var_indep * shrink, na.rm = TRUE) / 1e30
    nv_emp   <- mean(scan_var / x$n_valid * shrink, na.rm = TRUE) / 1e30
    ceil <- function(nv) sqrt(max(0, 1 - nv / obs_var))
    tibble(n_anomalies = nrow(x),
           anomaly_r_observed = cor(x$column_anom, x$surface_anom),
           sd_column_anomaly_1e15 = sqrt(obs_var),
           median_valid_scans = median(x$n_valid, na.rm = TRUE),
           noise_sd_reported_corr_1e15 = sqrt(nv_corr),
           noise_sd_reported_indep_1e15 = sqrt(nv_indep),
           noise_sd_empirical_1e15 = sqrt(nv_emp),
           noise_share_empirical = nv_emp / obs_var,
           ceiling_reported_corr = ceil(nv_corr),
           ceiling_reported_indep = ceil(nv_indep),
           ceiling_empirical = ceil(nv_emp))
  }
  per_site <- imap(split(an, an$site), function(x, s) {
    sv <- emp_site$scan_noise_var[emp_site$site == s]
    mutate(ceiling_stats(x, if (length(sv)) sv else NA_real_), site = s, .before = 1)
  }) |> list_rbind()
  pooled <- mutate(ceiling_stats(an, emp_all$scan_noise_var), site = "all sites", .before = 1)
  bind_rows(per_site, pooled) |>
    left_join(bind_rows(emp_site, emp_all) |> select(site, n_scan_pairs), by = "site") |>
    mutate(block_label = blabel, .after = site)
}) |> list_rbind()
out_tbl(noise_rows, "diag3_noise_ceiling.csv")
print(noise_rows |> select(site, block_label, n_anomalies, anomaly_r_observed, sd_column_anomaly_1e15,
                           noise_sd_empirical_1e15, ceiling_empirical, ceiling_reported_corr, ceiling_reported_indep))
for (i in which(noise_rows$block_label == "3x3")) {
  note("  ", noise_rows$site[i], " (3x3): anomaly r ", round(noise_rows$anomaly_r_observed[i], 2),
       "; ceiling from column noise ", round(noise_rows$ceiling_empirical[i], 2), " (empirical), ",
       round(noise_rows$ceiling_reported_corr[i], 2), "-", round(noise_rows$ceiling_reported_indep[i], 2), " (reported)")
}

site_order <- c(noise_rows |> filter(site != "all sites") |> distinct(site) |> pull(site), "all sites")
fS4 <- noise_rows |>
  filter(block_label == "3x3") |>
  select(site, `observed anomaly r` = anomaly_r_observed,
         `ceiling: empirical scan-to-scan noise` = ceiling_empirical,
         `ceiling: reported uncertainty, cells correlated` = ceiling_reported_corr,
         `ceiling: reported uncertainty, cells independent` = ceiling_reported_indep) |>
  pivot_longer(-site) |>
  mutate(site = factor(site, levels = rev(site_order)),
         y = as.numeric(site) + (as.numeric(factor(name)) - 2.5) * 0.18)   # small vertical offsets per series
pS4 <- ggplot(fS4, aes(value, y, colour = name, shape = name)) +
  geom_vline(xintercept = 0, colour = "grey70") +
  geom_point(size = 2.4, na.rm = TRUE) +
  scale_y_continuous(breaks = seq_along(levels(fS4$site)), labels = levels(fS4$site)) +
  scale_x_continuous(limits = c(-1, 1)) +
  labs(x = "Correlation", y = NULL, colour = NULL, shape = NULL,
       title = "Day-to-day agreement (24-h, 3x3 block) vs the ceiling set by TEMPO noise alone") +
  theme_bw(base_size = 10) + theme(legend.position = "bottom", legend.direction = "vertical")
ggsave(file.path(P$figures, "figS4_noise_ceiling.png"), pS4, width = 7, height = 5, dpi = 300)
log_msg("  figure: figS4_noise_ceiling.png")

# =============================================================================
# Test 4: terrain inside the averaging blocks; agreement by site and season
# =============================================================================
log_msg("Test 4: terrain and seasonal agreement")
cells_all <- bind_rows(select(cells24, site, di, dj, surface_pressure),
                       if (have_threeh) select(cells3, site, di, dj, surface_pressure))
cell_p <- cells_all |>
  filter(is.finite(surface_pressure), surface_pressure > 0) |>
  group_by(site, di, dj) |>
  summarise(p_hpa = median(surface_pressure), .groups = "drop")
terrain <- map(c(1L, 2L), function(b) {
  cell_p |>
    filter(abs(di) <= b, abs(dj) <= b) |>
    group_by(site) |>
    summarise(block_label = sprintf("%dx%d", 2L * b + 1L, 2L * b + 1L),
              n_cells = n(),
              centre_p_hpa = p_hpa[di == 0 & dj == 0][1],
              p_range_hpa = max(p_hpa) - min(p_hpa),
              p_sd_hpa = sd(p_hpa),
              approx_elev_range_m = 8000 * log(max(p_hpa) / min(p_hpa)),  # scale height ~8 km
              .groups = "drop")
}) |> list_rbind()
if (all(is.na(cell_p$p_hpa)) || !nrow(cell_p)) log_msg("  surface_pressure not available - terrain table empty")
if (isTRUE(suppressWarnings(max(abs(terrain$centre_p_hpa), na.rm = TRUE)) > 2000)) log_msg("  NOTE: surface_pressure looks like Pa, not hPa - divide the table by 100")

read_if <- function(f) if (file.exists(file.path(P$tables, f))) read_tbl(file.path(P$tables, f)) else NULL
s24 <- read_if("stats_by_site.csv"); a24 <- read_if("stats_within_month_anomalies.csv")
s3 <- read_if("threeh_stats_by_site.csv"); a3 <- read_if("threeh_stats_within_month_anomalies.csv")
perf <- bind_rows(
  if (!is.null(s24)) transmute(s24, site, arm = "24-h", r_whole_period = pearson_r),
  if (!is.null(s3)) s3 |> filter(convention == "start", site != "all sites") |> transmute(site, arm = "3-h (start)", r_whole_period = pearson_r)
) |>
  left_join(bind_rows(
    if (!is.null(a24)) a24 |> filter(site != "all sites") |> transmute(site, arm = "24-h", r_anomalies = pearson_r, n_anomalies = n),
    if (!is.null(a3)) a3 |> filter(convention == "start", site != "all sites") |> transmute(site, arm = "3-h (start)", r_anomalies = pearson_r, n_anomalies = n)
  ), by = c("site", "arm"))
t4a <- left_join(terrain, perf, by = "site", relationship = "many-to-many") |> arrange(block_label, desc(approx_elev_range_m))
out_tbl(t4a, "diag4_terrain_and_agreement.csv")
print(filter(t4a, block_label == "3x3"))
if (nrow(filter(t4a, block_label == "3x3", !is.na(r_anomalies))) >= 5) {
  tt <- filter(t4a, block_label == "3x3", !is.na(r_anomalies))
  note("  Spearman rho across sites, 3x3 elevation range vs anomaly r: ",
       round(suppressWarnings(cor(tt$approx_elev_range_m, tt$r_anomalies, method = "spearman")), 2),
       " (", nrow(tt), " site-arm rows; descriptive only)")
}

prim24 <- filter(variants24, block == 1L)                     # = matched_primary
an24 <- add_month_anomalies(filter(prim24, usable), CFG$min_days_per_site_month)
t4b <- map(season_levels, function(se) {
  x <- filter(an24, season == se)
  if (!nrow(x)) return(NULL)
  by_site_and_all(x, anomstats) |> mutate(season = se, .after = site)
}) |> list_rbind() |>
  arrange(site, factor(season, levels = season_levels))
out_tbl(t4b, "diag4_anomaly_r_by_site_season.csv")
print(t4b |> select(site, season, n, pearson_r, pearson_p))

# =============================================================================
# Test 5: smoke days - clouds and scan survival within season
# =============================================================================
smoke_path <- file.path(P$processed, "smoke_flags.csv")
if (file.exists(smoke_path)) {
  log_msg("Test 5: smoke-day selection")
  smk <- read_tbl(smoke_path, colClasses = list(character = c("stamp_local", "convention"))) |>
    filter(arm == "coatts") |>
    transmute(site, sample_date = as.Date(sample_date), hms_available = as.logical(hms_available),
              smoke_class = factor(smoke_class, levels = c("none", "light", "medium/heavy")))
  d5 <- prim24 |>
    left_join(smk, by = c("site", "sample_date")) |>
    filter(hms_available %in% TRUE) |>
    mutate(smoke = smoke_class %in% c("light", "medium/heavy"),
           valid_scan_share = ifelse(n_scans > 0, n_valid_scans / n_scans, NA_real_))
  t5a <- d5 |>
    group_by(season, smoke_class) |>
    summarise(sample_days = n(), with_any_scan_pct = round(100 * mean(n_scans > 0), 1),
              usable_pct = round(100 * mean(usable), 1),
              median_mean_cloud_fraction = median(mean_ecf, na.rm = TRUE),
              pct_days_cloud_fraction_gt_0.3 = round(100 * mean(mean_ecf > 0.3, na.rm = TRUE), 1),
              mean_valid_scan_share = mean(valid_scan_share, na.rm = TRUE),
              .groups = "drop")
  out_tbl(t5a, "diag5_smoke_clouds_by_season.csv")
  print(t5a)
  t5b <- map(season_levels, function(se) {
    x <- filter(d5, season == se)
    if (sum(x$smoke) < 3 || sum(!x$smoke) < 3) return(NULL)
    tibble(season = se, smoke_days = sum(x$smoke), smoke_free_days = sum(!x$smoke),
           median_cloud_smoke = median(x$mean_ecf[x$smoke], na.rm = TRUE),
           median_cloud_smoke_free = median(x$mean_ecf[!x$smoke], na.rm = TRUE),
           wilcoxon_p_cloud = suppressWarnings(wilcox.test(mean_ecf ~ smoke, data = x)$p.value),
           usable_pct_smoke = round(100 * mean(x$usable[x$smoke]), 1),
           usable_pct_smoke_free = round(100 * mean(x$usable[!x$smoke]), 1),
           fisher_p_usable = tryCatch(fisher.test(table(x$smoke, x$usable))$p.value, error = function(e) NA_real_))
  }) |> list_rbind()
  out_tbl(t5b, "diag5_smoke_cloud_tests.csv")
  print(t5b)
  for (i in seq_len(nrow(t5b))) note("  ", t5b$season[i], ": median cloud fraction smoke ", round(t5b$median_cloud_smoke[i], 2),
                                     " vs smoke-free ", round(t5b$median_cloud_smoke_free[i], 2),
                                     " (p = ", signif(t5b$wilcoxon_p_cloud[i], 2), "); usable ", t5b$usable_pct_smoke[i],
                                     "% vs ", t5b$usable_pct_smoke_free[i], "%")
} else {
  log_msg("Test 5 skipped (smoke_flags.csv not found)")
}

writeLines(summary_lines, file.path(P$tables, "diag_summary.txt"))
log_msg("Diagnostics done. Key lines saved to output/tables/diag_summary.txt")
