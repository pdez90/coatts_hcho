# =============================================================================
# 15_clear_sky_bias.R - are sampling days with a usable TEMPO observation
#                       representative of the days screening removes?
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
#          data/processed/aqs_tempo_site_cells.csv.gz + aqs_tempo_manifest.csv
#          data/processed/aqs_hcho_samples.csv        (national sample windows)
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
# For each site-day TEMPO observed, re-evaluate the block under the full screen
# and under the screen with one criterion relaxed at a time, and ask whether the
# day would then have become usable.
#
# This mirrors the pipeline exactly rather than approximately, because a
# diagnostic that screens or dates scans differently from the analysis it is
# explaining invites the question it is meant to settle:
#   * the cell test is screen_pass() of R/04 and scan_values() of R/13 - a cell
#     needs a vertical column, and a MISSING flag, solar zenith angle or snow
#     fraction passes (coalesce to 0) while a missing cloud fraction fails;
#   * a scan counts when n_pass >= pmax(1, ceiling(qc_min_cell_fraction*n_cells));
#   * scans are assigned to sample days the way the pipeline assigns them -
#     Colorado through tempo_manifest.csv, nationally by matching the scan's
#     UTC hour key to the hours spanned by each AQS sample window.
# Every screened-out sample day therefore appears here, and appears as screened
# out; the script warns if that ever stops being true.
#
# The rescue counts are NOT mutually exclusive. A sampling period usually
# contains several scans and different scans within it can fail different
# criteria, so one screened-out period can be rescued by more than one single
# relaxation. Only rescued_by_none is disjoint from the rest.
#
# Two scopes are tabulated, distinguished by the `scope` column:
#   "comparison (24 h)" - exactly the screened-out 24 h sample days that enter
#                         the contrast in part 2, so the denominator matches the
#                         day-type table above. This is what the paper quotes.
#   "all site-days"     - every site-day the extraction can place: both Colorado
#                         arms, and nationally every sample duration. Reported
#                         for completeness only.
hour_key <- function(t) as.integer(as.numeric(t) %/% 3600)   # as in R/13

attribute <- function(cells_path, label, day_from, keep = NULL) {
  if (!file.exists(cells_path)) { log_msg("  ", basename(cells_path), " absent; attribution skipped"); return(NULL) }
  cols <- c("granule", "site", "di", "dj", "vertical_column",
            "main_data_quality_flag", "eff_cloud_fraction",
            "snow_ice_fraction", "solar_zenith_angle")
  # site must stay character: some AQS site keys are numeric-looking and would
  # otherwise lose their leading zeros and fail to join to the matched data
  cells <- data.table::fread(cells_path, select = cols,
                             colClasses = list(character = "site"),
                             showProgress = FALSE)
  cells <- cells[abs(di) <= 1L & abs(dj) <= 1L]
  z <- function(x) data.table::fifelse(is.na(x), 0, as.numeric(x))  # missing passes
  cells[, `:=`(
    ok_v = !is.na(vertical_column),
    ok_q = z(main_data_quality_flag) <= CFG$qc_max_quality_flag,
    ok_e = !is.na(eff_cloud_fraction) & eff_cloud_fraction <= CFG$qc_max_cloud_fraction,
    ok_s = z(solar_zenith_angle) <= CFG$qc_max_sza,
    ok_n = z(snow_ice_fraction)  <= CFG$qc_max_snow_ice)]
  per_scan <- cells[, .(n_cells = .N,
                        full    = sum(ok_v & ok_q & ok_e & ok_s & ok_n),
                        noCloud = sum(ok_v & ok_q & ok_s & ok_n),
                        noSZA   = sum(ok_v & ok_q & ok_e & ok_n),
                        noSnow  = sum(ok_v & ok_q & ok_e & ok_s),
                        noFlag  = sum(ok_v & ok_e & ok_s & ok_n)),
                    by = .(site, granule)]
  per_scan[, thr := pmax(1L, as.integer(ceiling(CFG$qc_min_cell_fraction * n_cells)))]
  per_scan <- day_from(per_scan)
  per_scan <- per_scan[!is.na(sample_date)]
  per_day <- per_scan[, .(full    = any(full    >= thr),
                          noCloud = any(noCloud >= thr),
                          noSZA   = any(noSZA   >= thr),
                          noSnow  = any(noSnow  >= thr),
                          noFlag  = any(noFlag  >= thr)),
                      by = .(site, sample_date)]

  tally <- function(pd, scope) {
    so <- pd[full == FALSE]
    n  <- max(nrow(so), 1L)
    data.table::data.table(
      arm = label, scope = scope,
      site_days = nrow(pd), usable_days = sum(pd$full),
      screened_out_days = nrow(so),
      rescued_by_cloud  = sum(so$noCloud),
      rescued_by_snow   = sum(so$noSnow),
      rescued_by_sza    = sum(so$noSZA),
      rescued_by_flag   = sum(so$noFlag),
      rescued_by_none   = sum(!so$noCloud & !so$noSnow & !so$noSZA & !so$noFlag),
      pct_cloud = round(100 * sum(so$noCloud) / n, 1))
  }

  res <- list(tally(per_day, "all site-days"))
  if (!is.null(keep) && nrow(keep)) {
    k <- unique(data.table::as.data.table(keep)[, .(site = as.character(site),
                                                    sample_date = as.Date(sample_date))])
    m <- per_day[k, on = .(site, sample_date), nomatch = 0L]
    log_msg(sprintf("  %s: %d of %d screened-out 24 h sample days reproduced by the diagnostic (%.1f%%)",
                    label, nrow(m), nrow(k), 100 * nrow(m) / max(nrow(k), 1L)))
    if (nrow(m) < nrow(k))
      warning(label, ": ", nrow(k) - nrow(m),
              " screened-out sample days are absent from the cell extraction; ",
              "the quoted denominator will not match the day-type table.",
              call. = FALSE)
    if (any(m$full))
      warning(label, ": ", sum(m$full), " days classified as screened out in the ",
              "matched data pass the full screen when re-evaluated here.", call. = FALSE)
    # Nationally the diagnostic places scans through the 24 h sample windows, so
    # it only ever sees 24 h sample days and the two scopes coincide. Write one
    # row rather than two identical ones.
    cmp <- tally(m, "comparison (24 h)")
    same <- cmp$screened_out_days == res[[1]]$screened_out_days &&
            cmp$rescued_by_cloud  == res[[1]]$rescued_by_cloud
    if (same) log_msg("  ", label, ": the two scopes coincide; one row written")
    res <- if (same) list(cmp) else c(list(cmp), res)
  }
  data.table::rbindlist(res)
}

# the screened-out days that actually enter the contrast in part 2
screened_days <- function(a) {
  data.table::as.data.table(
    d |> filter(arm == a, day_type == "screened out") |>
      dplyr::select(site, sample_date) |> dplyr::distinct())
}

# Colorado: the granule-to-sample-day map the pipeline itself uses (R/04)
co_days <- function(ps) {
  man <- read_tbl(file.path(P$processed, "tempo_manifest.csv")) |>
    distinct(granule, sample_date) |> mutate(sample_date = as.Date(sample_date))
  merge(ps, data.table::as.data.table(man), by = "granule")
}

# National: the sample-window match the pipeline itself uses (R/13) - a scan
# belongs to a sample when its UTC hour key falls in the hours the sample spans.
nat_days <- function(ps) {
  man <- read_tbl(file.path(P$processed, "aqs_tempo_manifest.csv"), colClasses = "character") |>
    transmute(granule, mid_utc = ymd_hms(mid_utc)) |>
    distinct(granule, .keep_all = TRUE)
  s <- read_tbl(file.path(P$processed, "aqs_hcho_samples.csv"),
                colClasses = list(character = c("site_id", "qualifiers"))) |>
    mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"),
           end_utc   = as.POSIXct(end_utc, tz = "UTC"),
           sample_date = as.Date(sample_date_local)) |>
    filter(duration_class == "24 h", !is.na(hcho_ugm3), !is.na(start_utc))
  win <- data.table::as.data.table(
    transmute(s, site = site_id, sample_date, h0 = hour_key(start_utc), h1 = hour_key(end_utc)))
  hours <- win[, .(hour = seq.int(h0, h1 - 1L)), by = .(site, sample_date, h0, h1)][
    , .(site, sample_date, hour)]
  ps <- merge(ps, data.table::as.data.table(man), by = "granule")
  ps[, hour := hour_key(mid_utc)]
  merge(ps, hours, by = c("site", "hour"), allow.cartesian = TRUE)
}

attr_co  <- attribute(file.path(P$processed, "tempo_site_cells.csv.gz"),
                      "Colorado (24 h)", co_days, keep = screened_days("Colorado (24 h)"))
attr_nat <- attribute(file.path(P$processed, "aqs_tempo_site_cells.csv.gz"),
                      "National (24 h)", nat_days, keep = screened_days("National (24 h)"))
attr_all <- data.table::rbindlist(list(attr_co, attr_nat), fill = TRUE)
if (nrow(attr_all)) {
  data.table::fwrite(attr_all, file.path(P$tables, "observability_screen_attribution.csv"))
  for (i in seq_len(nrow(attr_all))) {
    a <- attr_all[i]
    log_msg(sprintf("%s screening attribution [%s]: %d screened-out site-days; relaxing the cloud threshold alone rescues %d (%.0f%%), snow/ice %d, SZA %d, quality flag %d; %d rescued by none (counts overlap)",
                    a$arm, a$scope, a$screened_out_days, a$rescued_by_cloud, a$pct_cloud,
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
  # Seed each stratum's bootstrap independently. Sharing one RNG stream would
  # make every interval depend on how many strata ran before it, so adding or
  # suppressing a stratum would silently shift the others' confidence limits.
  set.seed(42L)
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
       title = "Are sampling days with a usable TEMPO observation representative?",
       subtitle = paste("Screened out = TEMPO returned granules but no scan passed; days with no granule are excluded.",
                        "Deviations from the site and calendar-month mean; diamonds are means. Axes truncated near the 1st and 99th percentiles.",
                        sep = "\n")) +
  theme_bw(base_size = 10) +
  theme(plot.subtitle = element_text(size = 8), panel.grid.minor = element_blank())

ggsave(file.path(P$figures, "fig14_observability_bias.png"), p, width = 7, height = 4.6, dpi = 300)
log_msg("  figure: fig14_observability_bias.png")
log_msg("Observability bias test done.")
