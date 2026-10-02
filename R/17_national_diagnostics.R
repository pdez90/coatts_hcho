# =============================================================================
# 17_national_diagnostics.R - two diagnostics that step 09 runs on the Colorado
# 24 h sites, run at every 24 h site in the national comparison.
#
#   A. Retrieval noise and the correlation ceiling it implies. Successive valid
#      scans of the same site and sampling day differ by retrieval noise plus
#      whatever the column really did in the hour between them; the spread of
#      those differences bounds the random noise of a single scan, and dividing
#      by the number of valid scans gives the noise in the daily mean. Compared
#      with the variance of the within-month column anomalies it gives the share
#      of that variance that is noise and the correlation noise alone would
#      allow. Step 09 does this at seven Colorado sites; here it is done at every
#      24 h site with enough scan pairs, so the site-to-site spread in Figure 1
#      can be read against the ceiling at each site.
#   B. Time of day. At 24 h sites the sample covers every hour, so the column
#      in 06-09 local time and the column in 09-12 can be compared against the
#      same surface value: any difference is in the retrievals, not the sample.
#      Step 09 does this at the Colorado sites (152 site-days); here at all.
#
# Reads what steps 11-13 wrote; downloads nothing. The screen is the shared
# one in helpers_screen.R, the anomaly definition and Williams' test the shared
# ones in helpers_stats.R, so these numbers cannot be screened or tested
# differently from the rest of the paper.
#
# Outputs: output/tables/national_noise_ceiling.csv      (site x block)
#          output/tables/national_time_of_day_paired.csv
#          output/tables/manuscript_numbers_17.csv
#          output/figures/fig18_national_noise_ceiling.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_screen.R")
source("R/helpers_stats.R")
set.seed(42)
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))

samples_path  <- file.path(P$processed, "aqs_hcho_samples.csv")
variants_path <- file.path(P$processed, "aqs_matched_variants.csv.gz")
cells_path    <- file.path(P$processed, "aqs_tempo_site_cells.csv.gz")
man_path      <- file.path(P$processed, "aqs_tempo_manifest.csv")
for (f in c(samples_path, variants_path, cells_path, man_path)) {
  if (!file.exists(f)) stop("Missing ", f, " - run steps 11-13 first.")
}

MIN_ANOM_PAIRS <- CFG$min_anom_pairs_site   # anomaly pairs a site needs for a site-level ceiling (00_config.R)
MIN_SCAN_PAIRS <- 20L   # successive-scan pairs a site needs for its own noise estimate
MAX_GAP_H      <- 1.6   # successive scans further apart than this are not "successive"
TOD_MIN_PAIRS  <- 20L   # site-days with both windows, for a site-level time-of-day contrast

# ---- inputs ------------------------------------------------------------------
samples <- read_tbl(samples_path, colClasses = list(character = c("site_id", "qualifiers"))) |>
  filter(duration_class == "24 h", !is.na(hcho_ugm3)) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"),
         end_utc   = as.POSIXct(end_utc, tz = "UTC"),
         sample_date = as.Date(sample_date_local),
         site = site_id)
variants <- read_tbl(variants_path, colClasses = list(character = c("site_id", "site", "qualifiers"))) |>
  filter(duration_class == "24 h", lag_h == 0, max_ecf == CFG$qc_max_cloud_fraction, usable) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"), sample_date = as.Date(sample_date))
cells <- read_tbl(cells_path, colClasses = list(character = c("granule", "scan_start_utc", "site")))
for (col in setdiff(names(cells), c("granule", "scan_start_utc", "site"))) {
  x <- cells[[col]]
  if (!is.numeric(x) || inherits(x, "integer64")) cells[[col]] <- suppressWarnings(as.numeric(as.character(x)))
}
manifest <- read_tbl(man_path, colClasses = "character") |>
  transmute(granule, mid_utc = ymd_hms(mid_utc)) |>
  distinct(granule, .keep_all = TRUE)
.prep <- hcho_prepare_cells(cells)
cells <- .prep$cells
QC_ABSENT <- .prep$absent
cells <- semi_join(cells, samples, by = "site")          # 24 h sites only
log_msg(nrow(samples), " 24 h samples at ", n_distinct(samples$site), " sites; ",
        nrow(cells), " cell rows at those sites")

# ---- scan-level values, and which sample each scan falls in --------------------
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
# every UTC hour of every 24 h sample window, keyed like step 13
sample_hours <- samples |>
  transmute(site, start_utc, sample_date, start_hour_local,
            h0 = hour_key(start_utc), h1 = hour_key(end_utc)) |>
  mutate(hour = map2(h0, h1, ~ seq.int(.x, .y - 1L))) |>
  tidyr::unnest(hour) |>
  select(site, start_utc, sample_date, start_hour_local, hour)
assign_scans <- function(sv) {
  sample_hours |>
    inner_join(sv, by = c("site", "hour"), relationship = "many-to-many") |>
    # local standard hour of the scan; %% 24 because 3 % of 24 h samples begin at 23:00 LST
    mutate(local_hour = (start_hour_local + as.numeric(difftime(mid_utc, start_utc, units = "hours"))) %% 24)
}

blocks <- c(0L, 1L, 2L)
block_label <- function(b) sprintf("%dx%d", 2L * b + 1L, 2L * b + 1L)
scans <- map(blocks, function(b) assign_scans(scan_values(b)))
names(scans) <- block_label(blocks)

# ---- A. noise ceiling at every 24 h site ------------------------------------------
# Same estimator as step 09 (Test 3), empirical branch: differences between
# successive valid scans <= MAX_GAP_H apart within a sampling day, variance / 2 =
# single-scan noise variance; divided by the valid scans in the daily mean and
# by (1 - 1/n_month) for the month mean the anomaly removed.
ceiling_stats <- function(an, scan_var) {
  if (nrow(an) < MIN_ANOM_PAIRS || !is.finite(scan_var)) return(tibble(n_anomalies = nrow(an)))
  shrink  <- 1 - 1 / an$n_month
  obs_var <- var(an$column_anom)                                   # (1e15)^2
  nv_emp  <- mean(scan_var / an$n_valid_scans * shrink) / 1e30
  ceil    <- sqrt(max(0, 1 - nv_emp / obs_var))
  r_obs   <- cor(an$column_anom, an$surface_anom)
  tibble(n_anomalies = nrow(an),
         anomaly_r_observed = r_obs,
         sd_column_anomaly_1e15 = sqrt(obs_var),
         median_valid_scans = median(an$n_valid_scans),
         scan_noise_sd_single_1e15 = sqrt(scan_var) / 1e15,
         noise_sd_empirical_1e15 = sqrt(nv_emp),
         noise_share_empirical = nv_emp / obs_var,
         ceiling_empirical = ceil,
         r_noise_corrected = if (ceil > 0) r_obs / ceil else NA_real_)
}

noise_rows <- map(blocks, function(b) {
  bl <- block_label(b)
  d  <- variants |> filter(block == b) |>
    select(site, site_name, state, sample_date, start_utc, hcho_ugm3, tempo_vc_1e15, n_valid_scans)
  sc <- scans[[bl]] |> filter(valid) |> semi_join(d, by = c("site", "start_utc"))
  emp <- sc |>
    arrange(site, start_utc, mid_utc) |>
    group_by(site, start_utc) |>
    mutate(dv = vc - lag(vc), gap_h = as.numeric(difftime(mid_utc, lag(mid_utc), units = "hours"))) |>
    ungroup() |>
    filter(!is.na(dv), gap_h <= MAX_GAP_H)
  emp_site <- emp |> group_by(site) |> summarise(scan_noise_var = mean(dv^2) / 2, n_scan_pairs = n(), .groups = "drop")
  emp_all  <- tibble(site = "all sites", scan_noise_var = mean(emp$dv^2) / 2, n_scan_pairs = nrow(emp))
  an <- add_month_anomalies(d, CFG$min_days_per_site_month) |>
    group_by(site, ym) |> mutate(n_month = n()) |> ungroup()
  per_site <- imap(split(an, an$site), function(x, s) {
    e <- emp_site[emp_site$site == s, ]
    sv <- if (nrow(e) && e$n_scan_pairs >= MIN_SCAN_PAIRS) e$scan_noise_var else NA_real_
    mutate(ceiling_stats(x, sv), site = s, .before = 1)
  }) |> list_rbind()
  pooled <- mutate(ceiling_stats(an, emp_all$scan_noise_var), site = "all sites", .before = 1)
  bind_rows(per_site, pooled) |>
    left_join(bind_rows(emp_site, emp_all) |> select(site, n_scan_pairs), by = "site") |>
    left_join(distinct(d, site, site_name, state), by = "site") |>
    mutate(block_label = bl, .after = site)
}) |> list_rbind()
data.table::fwrite(noise_rows, file.path(P$tables, "national_noise_ceiling.csv"))

nr <- function(bl, col) noise_rows[[col]][noise_rows$site == "all sites" & noise_rows$block_label == bl]
# scored = a defined, positive ceiling. A site whose noise bound exceeds its anomaly
# variance (ceiling forced to 0) is counted separately, not folded into the quantiles.
scored_all <- noise_rows |> filter(site != "all sites", block_label == "3x3", is.finite(ceiling_empirical))
scored <- filter(scored_all, ceiling_empirical > 0)
# quantiles of the corrected r are over sites with a positive ceiling; the count of
# sites where the noise bound exceeds the anomaly variance is reported alongside
log_msg("National noise ceiling (3x3): pooled observed r ", round(nr("3x3", "anomaly_r_observed"), 2),
        ", noise share ", round(100 * nr("3x3", "noise_share_empirical")), " %, ceiling ",
        round(nr("3x3", "ceiling_empirical"), 2), ", corrected ", round(nr("3x3", "r_noise_corrected"), 2),
        "; ", nrow(scored), " sites scored, median ceiling ", round(median(scored$ceiling_empirical), 2),
        ", median corrected r ", round(median(scored$r_noise_corrected, na.rm = TRUE), 2))
print(noise_rows |> filter(site == "all sites") |>
        select(block_label, n_anomalies, anomaly_r_observed, scan_noise_sd_single_1e15,
               noise_sd_empirical_1e15, noise_share_empirical, ceiling_empirical, r_noise_corrected))

q2 <- function(x, p) sprintf("%.2f", quantile(x, p, na.rm = TRUE))
noise_keys <- tibble(
  key = c("nat_noise_single_1x1_1e15", "nat_noise_daily_3x3_1e15", "nat_noise_share_3x3_pct",
          "nat_ceiling_3x3", "nat_anom_obs_1x1", "nat_anom_obs_3x3", "nat_anom_obs_5x5",
          "nat_r_corr_1x1", "nat_r_corr_3x3", "nat_r_corr_5x5",
          "nat_sites_scored", "nat_site_ceiling_median", "nat_site_ceiling_q25", "nat_site_ceiling_q75",
          "nat_site_rcorr_median", "nat_site_rcorr_q25", "nat_site_rcorr_q75",
          "nat_sites_near_ceiling", "nat_sites_far_below", "nat_site_share_median_pct",
          "nat_sites_ceiling_undefined", "nat_site_obs_min", "nat_site_obs_max"),
  value = c(sprintf("%.1f", nr("1x1", "scan_noise_sd_single_1e15")),
            sprintf("%.1f", nr("3x3", "noise_sd_empirical_1e15")),
            sprintf("%.0f", 100 * nr("3x3", "noise_share_empirical")),
            sprintf("%.2f", nr("3x3", "ceiling_empirical")),
            sprintf("%.2f", nr("1x1", "anomaly_r_observed")),
            sprintf("%.2f", nr("3x3", "anomaly_r_observed")),
            sprintf("%.2f", nr("5x5", "anomaly_r_observed")),
            sprintf("%.2f", nr("1x1", "r_noise_corrected")),
            sprintf("%.2f", nr("3x3", "r_noise_corrected")),
            sprintf("%.2f", nr("5x5", "r_noise_corrected")),
            as.character(nrow(scored)),
            q2(scored$ceiling_empirical, 0.5), q2(scored$ceiling_empirical, 0.25), q2(scored$ceiling_empirical, 0.75),
            q2(scored$r_noise_corrected, 0.5), q2(scored$r_noise_corrected, 0.25), q2(scored$r_noise_corrected, 0.75),
            as.character(sum(scored$r_noise_corrected >= 0.8, na.rm = TRUE)),
            as.character(sum(scored$r_noise_corrected < 0.5, na.rm = TRUE)),
            sprintf("%.0f", 100 * median(scored$noise_share_empirical)),
            # noise variance >= anomaly variance: the upper-bound estimator overshoots, no ceiling
            as.character(sum(scored_all$ceiling_empirical <= 0)),
            sprintf("%.2f", min(scored$anomaly_r_observed)), sprintf("%.2f", max(scored$anomaly_r_observed))))

# Figure: observed day-to-day r against the ceiling at each 24 h site
plot_sites <- filter(scored, ceiling_empirical > 0)   # a zero ceiling is "noise bound exceeds the variance", not a point
p18 <- ggplot(plot_sites, aes(ceiling_empirical, anomaly_r_observed)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey50") +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_point(aes(size = n_anomalies), alpha = 0.6, colour = "#1f78b4") +
  scale_size_continuous(range = c(1.2, 4.5), name = "anomaly pairs") +
  coord_cartesian(xlim = c(0, 1), ylim = c(min(-0.3, min(plot_sites$anomaly_r_observed)), 1)) +
  labs(x = "Correlation ceiling implied by scan-to-scan noise alone",
       y = "Observed day-to-day correlation (within-month anomalies)",
       title = "Retrieval noise sets a ceiling; most monitors sit well below it",
       subtitle = sprintf("%d 24 h monitors, 3 x 3 block; dashed line is the ceiling itself", nrow(plot_sites)))
ggsave(file.path(P$figures, "fig18_national_noise_ceiling.png"), p18, width = 6.5, height = 5, dpi = 300)
log_msg("  figure: fig18_national_noise_ceiling.png")

# ---- B. time of day at every 24 h site --------------------------------------------
# 06-09 against 09-12 local standard time, on the same site-days, with all valid
# scans in each window averaged. Anomalies as everywhere else; Williams' test for
# two correlations sharing the surface value (helpers_stats.R).
tod <- scans[["3x3"]] |>
  filter(valid) |>
  mutate(window = case_when(local_hour >= 6 & local_hour < 9 ~ "early",
                            local_hour >= 9 & local_hour < 12 ~ "late",
                            TRUE ~ NA_character_)) |>
  filter(!is.na(window)) |>
  group_by(site, start_utc, sample_date, window) |>
  summarise(col = mean(vc) / 1e15, n_scans = n(), .groups = "drop") |>
  tidyr::pivot_wider(names_from = window, values_from = c(col, n_scans)) |>
  filter(is.finite(col_early), is.finite(col_late)) |>
  inner_join(select(samples, site, start_utc, hcho_ugm3, site_name, state), by = c("site", "start_utc"))
log_msg(nrow(tod), " 24 h site-days with valid scans in both 06-09 and 09-12 local time, at ",
        n_distinct(tod$site), " sites")

tod_an <- tod |>
  mutate(ym = floor_date(sample_date, "month")) |>
  group_by(site, ym) |> filter(n() >= CFG$min_days_per_site_month) |>
  mutate(across(c(hcho_ugm3, col_early, col_late), ~ .x - mean(.x), .names = "{.col}_anom")) |>
  ungroup()
tod_pooled <- bind_rows(
  dep_cor_test(tod$hcho_ugm3, tod$col_late, tod$col_early) |> mutate(comparison = "whole period"),
  dep_cor_test(tod_an$hcho_ugm3_anom, tod_an$col_late_anom, tod_an$col_early_anom) |>
    mutate(comparison = "within-month anomalies")) |>
  mutate(site = "all sites", .before = 1)
tod_site <- tod_an |>
  group_by(site) |> filter(n() >= TOD_MIN_PAIRS) |>
  group_modify(~ dep_cor_test(.x$hcho_ugm3_anom, .x$col_late_anom, .x$col_early_anom)) |>
  ungroup() |> mutate(comparison = "within-month anomalies")
tod_out <- bind_rows(tod_pooled, tod_site) |>
  rename(r_09_12 = r_start, r_06_09 = r_end, diff_09_12_minus_06_09 = diff_start_minus_end)
tod_site <- filter(tod_out, site != "all sites")     # renamed columns, for the counts below
data.table::fwrite(tod_out, file.path(P$tables, "national_time_of_day_paired.csv"))
print(tod_out |> filter(site == "all sites") |>
        select(comparison, n, r_09_12, r_06_09, r_between_window_columns, williams_p))
ta <- tod_out |> filter(site == "all sites", comparison == "within-month anomalies")
tod_keys <- tibble(
  key = c("nat_tod_n", "nat_tod_r_0609", "nat_tod_r_0912", "nat_tod_p",
          "nat_tod_sites", "nat_tod_sites_late_better", "nat_tod_sites_sig", "nat_tod_sites_sig_lower"),
  value = c(as.character(ta$n), sprintf("%.2f", ta$r_06_09), sprintf("%.2f", ta$r_09_12),
            sprintf("%.3f", ta$williams_p),
            as.character(nrow(tod_site)),
            as.character(sum(tod_site$diff_09_12_minus_06_09 > 0, na.rm = TRUE)),
            as.character(sum(tod_site$williams_p < 0.05 & tod_site$diff_09_12_minus_06_09 > 0, na.rm = TRUE)),
            as.character(sum(tod_site$williams_p < 0.05 & tod_site$diff_09_12_minus_06_09 < 0, na.rm = TRUE))))
log_msg("Time of day, all 24 h sites, anomalies (n = ", ta$n, "): r 06-09 ", round(ta$r_06_09, 2),
        " vs 09-12 ", round(ta$r_09_12, 2), ", Williams p = ", signif(ta$williams_p, 2), "; ",
        nrow(tod_site), " sites with >= ", TOD_MIN_PAIRS, " paired days, later window higher at ",
        sum(tod_site$diff_09_12_minus_06_09 > 0, na.rm = TRUE), ", significant at ",
        sum(tod_site$williams_p < 0.05, na.rm = TRUE))

data.table::fwrite(bind_rows(noise_keys, tod_keys) |> mutate(source = "R/17_national_diagnostics.R"),
                   file.path(P$tables, "manuscript_numbers_17.csv"))
log_msg("National diagnostics done.")
