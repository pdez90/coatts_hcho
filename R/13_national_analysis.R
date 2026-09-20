# =============================================================================
# 13_national_analysis.R - national AQS formaldehyde vs TEMPO
#
# Matches every national sample (step 11) to the TEMPO scans extracted for it
# (step 12) and repeats the Colorado analysis across the country:
#   * coverage, correlations and within-month anomaly correlations by site,
#     sample duration and lag from the sampling window
#   * the test the Colorado 3-h result asks for: at the 8-h PAMS sites, which
#     sample window agrees best - the one starting 04:00 local (which straddles
#     the morning transition), 12:00 (the mixed afternoon) or 20:00 (night)?
#   * the same by lag, so "when TEMPO looks relative to the sample" is measured
#     on 44 sites instead of two
# Scans are assigned by the hour containing their midpoint, as in steps 04 and 07;
# matching is hourly; nearly every sample window starts on the hour, and a
# fractional start is binned into the hour it begins in and named in the log.
# Outputs: data/processed/aqs_matched_*.csv.gz,
#          output/tables/national_*.csv, output/figures/fig11-13_national_*.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_screen.R")   # one definition of the TEMPO cell screen
source("R/helpers_stats.R")
source("R/helpers_basemap.R")  # US/state outlines for Figure 1
set.seed(42)

samples_path <- file.path(P$processed, "aqs_hcho_samples.csv")
cells_path   <- file.path(P$processed, "aqs_tempo_site_cells.csv.gz")
man_path     <- file.path(P$processed, "aqs_tempo_manifest.csv")
for (f in c(samples_path, cells_path, man_path)) {
  if (!file.exists(f)) stop("Missing ", f, " - run steps 11 and 12 first.")
}

samples <- read_tbl(samples_path, colClasses = list(character = c("site_id", "qualifiers"))) |>
  mutate(start_utc = as.POSIXct(start_utc, tz = "UTC"),
         end_utc = as.POSIXct(end_utc, tz = "UTC"),
         sample_date = as.Date(sample_date_local),
         season = factor(season, levels = c("DJF", "MAM", "JJA", "SON"))) |>
  filter(!is.na(hcho_ugm3), !is.na(start_utc))

cells <- read_tbl(cells_path, colClasses = list(character = c("granule", "scan_start_utc", "site")))
for (col in setdiff(names(cells), c("granule", "scan_start_utc", "site"))) {
  x <- cells[[col]]
  if (!is.numeric(x) || inherits(x, "integer64")) cells[[col]] <- suppressWarnings(as.numeric(as.character(x)))
}
# Placeholders for absent ancillary columns are NOT created here. Creating them
# before hcho_prepare_cells() runs would hide true schema absence from it: the
# helper decides availability from names(cells), so a manufactured all-NA column
# reads as "present but broken" and stops the run, instead of skipping an
# unavailable criterion loudly as intended. The helper creates every placeholder
# it needs, after it has recorded what the extraction actually carried.
manifest <- read_tbl(man_path, colClasses = "character") |>
  transmute(granule, mid_utc = ymd_hms(mid_utc)) |>
  distinct(granule, .keep_all = TRUE)

samples <- filter(samples, site_id %in% unique(cells$site))
log_msg(nrow(samples), " samples at ", n_distinct(samples$site_id), " sites with TEMPO cells; ",
        nrow(cells), " cell rows")
print(count(samples, duration_class, name = "samples"))

# ---- 0. what the extraction contained ---------------------------------------
# The SI describes the extraction by its size. Counted from the cells file with
# the same cluster rule step 12 used, so the figures follow the data rather than
# a run log.
site_ll <- samples |>
  group_by(site_id) |>
  summarise(lat = median(lat), lon = median(lon), .groups = "drop")
extraction <- cells |>
  distinct(granule, site) |>
  inner_join(site_ll, by = c(site = "site_id")) |>
  mutate(cluster = cluster_of(lat, lon))
data.table::fwrite(
  tibble(key = c("n_clusters", "n_cluster_scans", "n_cell_records_million"),
         value = c(as.character(n_distinct(cluster_of(site_ll$lat, site_ll$lon))),
                   format(n_distinct(paste(extraction$cluster, extraction$granule)), big.mark = " "),
                   sprintf("%.2f", nrow(cells) / 1e6)),
         source = "R/13_national_analysis.R"),
  file.path(P$tables, "manuscript_numbers_13_extraction.csv"))
log_msg("Extraction: ", n_distinct(cluster_of(site_ll$lat, site_ll$lon)), " clusters, ",
        n_distinct(paste(extraction$cluster, extraction$granule)), " cluster-scans with cells, ",
        nrow(cells), " cell records")
rm(extraction)

# ---- 1. scan-level values (screening as in steps 04 and 07) -----------------
hour_key <- function(t) as.integer(as.numeric(t) %/% 3600)      # UTC hour index

# The screen, the criterion availability and the gap report come from
# helpers_screen.R, the same definition step 04 uses.
.prep <- hcho_prepare_cells(cells)
cells <- .prep$cells
QC_ABSENT <- .prep$absent

scan_values <- function(max_ecf, block) {
  cells |>
    filter(abs(di) <= block, abs(dj) <= block) |>
    mutate(pass = hcho_screen_pass(pick(everything()), max_ecf, QC_ABSENT)) |>
    group_by(granule, site) |>
    summarise(n_cells = n(), n_pass = sum(pass),
              vc  = if (any(pass)) mean(vertical_column[pass]) else NA_real_,
              pbl = if (any(pass)) mean(pbl_height[pass], na.rm = TRUE) else NA_real_,
              sp  = if (any(pass)) mean(surface_pressure[pass], na.rm = TRUE) else NA_real_,
              .groups = "drop") |>
    mutate(valid = hcho_scan_valid(n_pass, n_cells)) |>
    inner_join(manifest, by = "granule") |>
    transmute(site, hour = hour_key(mid_utc), valid, vc, pbl, sp)
}

# every hour covered by a sample window, shifted by the lag
sample_hours <- function(lag_h) {
  s <- samples
  if (lag_h != 0) s <- filter(s, duration_class != "24 h")   # lags only for sub-daily samples
  if (!nrow(s)) return(NULL)
  s |>
    mutate(h0 = hour_key(start_utc) + lag_h, h1 = hour_key(end_utc) + lag_h, .keep = "all") |>
    select(site_id, start_utc, duration_class, h0, h1) |>
    mutate(hour = map2(h0, h1, ~ seq.int(.x, .y - 1L))) |>
    tidyr::unnest(hour) |>
    transmute(site = site_id, start_utc, hour, lag_h = lag_h)
}

variants <- expand_grid(lag_h = CFG$aqs_lags_h, max_ecf = c(0.1, 0.2, 0.3), block = c(0L, 1L, 2L)) |>
  mutate(block_label = sprintf("%dx%d", 2L * block + 1L, 2L * block + 1L))

scan_cache <- list()
hours_cache <- list()
matched <- pmap(variants, function(lag_h, max_ecf, block, block_label) {
  key <- paste(max_ecf, block)
  if (is.null(scan_cache[[key]])) scan_cache[[key]] <<- scan_values(max_ecf, block)
  sv <- scan_cache[[key]]
  hk <- as.character(lag_h)
  if (is.null(hours_cache[[hk]])) hours_cache[[hk]] <<- sample_hours(lag_h)
  sh <- hours_cache[[hk]]
  if (is.null(sh)) return(NULL)
  per_sample <- sh |>
    inner_join(sv, by = c("site", "hour"), relationship = "many-to-many") |>
    group_by(site, start_utc) |>
    summarise(n_scans = n(), n_valid_scans = sum(valid),
              tempo_vc = if (any(valid)) mean(vc[valid]) else NA_real_,
              tempo_pbl_m = if (any(valid)) mean(pbl[valid], na.rm = TRUE) else NA_real_,
              tempo_press_hpa = if (any(valid)) mean(sp[valid], na.rm = TRUE) else NA_real_,
              .groups = "drop")
  base <- if (lag_h == 0) samples else filter(samples, duration_class != "24 h")
  base |>
    left_join(per_sample, by = c("site_id" = "site", "start_utc")) |>
    mutate(lag_h = lag_h, max_ecf = max_ecf, block = block, block_label = block_label,
           n_scans = coalesce(n_scans, 0L), n_valid_scans = coalesce(n_valid_scans, 0L))
}) |> list_rbind() |>
  mutate(tempo_vc_1e15 = tempo_vc / 1e15,
         # reported values are at 25 C and 1 atm (Sect. 2.1): convert to a mixing
         # ratio, then to number density at TEMPO's surface pressure
         hcho_ppb_std = ugm3_std_to_ppb(hcho_ugm3),
         hcho_molec_cm3_local = ppb_to_molec_cm3(hcho_ppb_std, CFG$hcho_fallback_temp_c, tempo_press_hpa),
         h_eff_km = ifelse(tempo_vc > 0 & hcho_molec_cm3_local > 0,
                           tempo_vc / hcho_molec_cm3_local / 1e5, NA_real_),
         tempo_pbl_km = tempo_pbl_m / 1000,
         usable = !is.na(tempo_vc) & !is.na(hcho_ugm3),
         site = site_id,
         # Bin a sample by the clock hour its window begins in. floor(), not
         # round(): the rule is declared rather than emergent, and it does not
         # depend on R's round-half-to-even, which would send a 23:30 start to
         # hour 24 and a 22:30 start to 22. The epsilon guards a whole hour
         # stored as 11.999999.
         window_start_hour = floor(start_hour_local + 1e-9))

# Almost every AQS monitor reports whole-hour starts. Any that does not is named
# in the log, so an off-schedule sample is binned visibly instead of silently.
odd_hr <- with(matched, !is.na(start_hour_local) &
                        abs(start_hour_local - round(start_hour_local)) > 1e-6)
if (any(odd_hr)) {
  od <- distinct(matched[odd_hr, c("site", "duration_class",
                                   "start_hour_local", "window_start_hour")])
  log_msg("  ", nrow(od), " site/start-hour combination(s) not on a whole hour, ",
          "binned by the hour the window starts in:")
  for (i in seq_len(nrow(od)))
    log_msg("    ", od$site[i], " (", od$duration_class[i], "): ",
            sprintf("%.2f -> %d", od$start_hour_local[i], od$window_start_hour[i]))
}

data.table::fwrite(matched, file.path(P$processed, "aqs_matched_variants.csv.gz"))
primary <- filter(matched, max_ecf == CFG$qc_max_cloud_fraction, block == 1L)
data.table::fwrite(primary, file.path(P$processed, "aqs_matched_primary.csv.gz"))
log_msg(nrow(primary), " matched rows in the primary variant (", sum(primary$usable), " usable)")

# ---- 2. coverage -------------------------------------------------------------
coverage <- primary |>
  group_by(duration_class, lag_h, site, site_name, state) |>
  summarise(samples = n(), with_any_scan = sum(n_scans > 0), n_usable = sum(usable),
            usable_pct = round(100 * mean(usable), 1),
            median_scans = median(n_scans),                       # scans with a granule
            median_valid_scans = median(n_valid_scans[usable]),   # scans passing the screen, usable days
            .groups = "drop") |>
  arrange(duration_class, lag_h, desc(n_usable))
data.table::fwrite(coverage, file.path(P$tables, "national_coverage.csv"))
# Table 1 quotes the median number of USABLE scans per sample: computed over
# usable samples, pooled across sites, not the median of scans with a granule.
scans_usable <- primary |>
  filter(lag_h == 0, usable) |>
  group_by(duration_class) |>
  summarise(median_valid_scans = median(n_valid_scans), .groups = "drop")
data.table::fwrite(
  tibble(key = paste0("scans_usable_median_", sub(" h", "", scans_usable$duration_class)),
         value = sprintf("%.0f", scans_usable$median_valid_scans),
         source = "R/13_national_analysis.R"),
  file.path(P$tables, "manuscript_numbers_13_coverage.csv"))
print(coverage |> group_by(duration_class, lag_h) |>
        summarise(sites = n(), samples = sum(samples), usable = sum(n_usable),
                  usable_pct = round(100 * sum(n_usable) / sum(samples), 1), .groups = "drop"))

use <- filter(primary, usable)

# ---- 3. correlations by duration and lag ------------------------------------
# within-site-month anomalies; works whether or not `site` is a grouping column
anom_of <- function(d) {
  d <- mutate(d, ym = floor_date(sample_date, "month"))
  g <- if ("site" %in% names(d)) c("site", "ym") else "ym"
  d |>
    group_by(across(all_of(g))) |>
    filter(n() >= CFG$min_days_per_site_month) |>
    mutate(surface_anom = hcho_ugm3 - mean(hcho_ugm3),
           column_anom = tempo_vc_1e15 - mean(tempo_vc_1e15)) |>
    ungroup()
}
stats_dl <- use |>
  group_by(duration_class, lag_h) |>
  group_modify(~ relstats(.x, cluster = "site")) |>
  ungroup()
anom_dl <- use |>
  group_by(duration_class, lag_h) |>
  group_modify(~ {
    an <- anom_of(.x)
    if (nrow(an) < 6) return(tibble(n = nrow(an)))
    anomstats(an)
  }) |>
  ungroup() |>
  rename_with(~ paste0("anom_", .x), -c(duration_class, lag_h))
by_duration_lag <- left_join(stats_dl, anom_dl, by = c("duration_class", "lag_h")) |>
  arrange(duration_class, lag_h)
for (cn in c("anom_n", "anom_pearson_r")) if (!cn %in% names(by_duration_lag)) by_duration_lag[[cn]] <- NA_real_
data.table::fwrite(by_duration_lag, file.path(P$tables, "national_stats_by_duration_lag.csv"))
print(by_duration_lag |> select(duration_class, lag_h, n, pearson_r, spearman_rho,
                                anom_n, anom_pearson_r, median_h_eff_km, median_tempo_pbl_km))

# ---- 4. the time-of-day test -------------------------------------------------
# For sub-daily samples: does agreement depend on when the sample was collected?
by_hour <- use |>
  filter(duration_class != "24 h", lag_h == 0) |>
  group_by(duration_class, window_start_hour) |>
  filter(n() >= 12) |>
  group_modify(~ {
    an <- anom_of(.x)
    bind_cols(relstats(.x, cluster = "site"),
              if (nrow(an) >= 6) rename_with(anomstats(an), ~ paste0("anom_", .x)) else tibble())
  }) |>
  ungroup() |>
  arrange(duration_class, window_start_hour)
data.table::fwrite(by_hour, file.path(P$tables, "national_stats_by_start_hour.csv"))
print(by_hour |> select(any_of(c("duration_class", "window_start_hour", "n", "pearson_r",
                                 "spearman_rho", "anom_n", "anom_pearson_r", "median_tempo_pbl_km"))))

# ---- 5. per-site statistics --------------------------------------------------
by_site <- use |>
  filter(lag_h == 0) |>
  group_by(duration_class, site, site_name, state, networks, lat, lon) |>
  filter(n() >= 10) |>
  group_modify(~ {
    an <- anom_of(.x)
    bind_cols(relstats(.x, nboot = 200),
              if (nrow(an) >= 6) rename_with(anomstats(an), ~ paste0("anom_", .x)) else tibble())
  }) |>
  ungroup() |>
  arrange(duration_class, desc(pearson_r))
# many site-level tests: report a Benjamini-Hochberg false-discovery-rate count
# alongside the nominal one, so the significance counts are not read as 141
# independent uncorrected tests
by_site <- by_site |>
  mutate(pearson_q = p.adjust(pearson_p, method = "BH"),
         anom_pearson_q = if ("anom_pearson_p" %in% names(by_site))
           p.adjust(anom_pearson_p, method = "BH") else NA_real_,
         # The anomaly p-values reported everywhere else are permutation values,
         # so the false-discovery count has to be available on the same basis.
         # Both are kept: the parametric pair is what earlier versions reported,
         # and the difference between them is itself worth seeing.
         anom_pearson_q_perm = if ("anom_pearson_p_perm" %in% names(by_site))
           p.adjust(anom_pearson_p_perm, method = "BH") else NA_real_)
data.table::fwrite(by_site, file.path(P$tables, "national_stats_by_site.csv"))

# ---- 5a. the site-level distribution, as the numbers the text quotes ----------
# Median and quartiles of the whole-period and day-to-day correlations by
# duration (Table 1, Results, abstract), their extremes, and the day-to-day
# correlation by thirds of each site's median surface concentration - the
# concentration dependence a fixed retrieval noise predicts. Written by name so
# the text cannot carry a quartile from an earlier run.
if (!"anom_pearson_r" %in% names(by_site)) stop("by_site lacks anom_pearson_r")
site_summary_keys <- function(d, tag) {
  q <- function(x, p) sprintf("%.2f", quantile(x, p, na.rm = TRUE))
  tibble(key = paste0(c("n_sites_", "site_r_median_", "site_r_q25_", "site_r_q75_",
                        "site_dd_median_", "site_dd_q25_", "site_dd_q75_",
                        "site_dd_min_", "site_dd_max_"), tag),
         value = c(as.character(nrow(d)),
                   q(d$pearson_r, 0.5), q(d$pearson_r, 0.25), q(d$pearson_r, 0.75),
                   q(d$anom_pearson_r, 0.5), q(d$anom_pearson_r, 0.25), q(d$anom_pearson_r, 0.75),
                   q(d$anom_pearson_r, 0), q(d$anom_pearson_r, 1)))
}
site_keys <- bind_rows(
  site_summary_keys(filter(by_site, duration_class == "24 h"), "24"),
  site_summary_keys(filter(by_site, duration_class == "8 h"),  "8"),
  site_summary_keys(filter(by_site, duration_class == "3 h"),  "3"))

# Thirds are cut at the tertiles of the site medians, not by ntile(): several
# sites share the same median (AQS reports to 0.1 ppbC), and ntile() would split
# a tie across two groups by row order, making the result depend on sort order.
thirds <- by_site |>
  filter(duration_class == "24 h", !is.na(anom_pearson_r)) |>
  mutate(third = as.integer(cut(median_surface_ugm3,
                                breaks = quantile(median_surface_ugm3, c(0, 1/3, 2/3, 1)),
                                include.lowest = TRUE, labels = FALSE))) |>
  group_by(third) |>
  summarise(n_sites = n(), median_dd_r = median(anom_pearson_r),
            conc_lo = min(median_surface_ugm3), conc_hi = max(median_surface_ugm3),
            .groups = "drop")
data.table::fwrite(thirds, file.path(P$tables, "national_site_conc_thirds.csv"))
print(thirds)
third_keys <- tibble(
  key = c("tert_low_r", "tert_mid_r", "tert_high_r", "tert_low_lo", "tert_low_hi"),
  value = c(sprintf("%.2f", thirds$median_dd_r[thirds$third == 1]),
            sprintf("%.2f", thirds$median_dd_r[thirds$third == 2]),
            sprintf("%.2f", thirds$median_dd_r[thirds$third == 3]),
            sprintf("%.1f", thirds$conc_lo[thirds$third == 1]),
            sprintf("%.1f", thirds$conc_hi[thirds$third == 1])))
data.table::fwrite(bind_rows(site_keys, third_keys) |> mutate(source = "R/13_national_analysis.R"),
                   file.path(P$tables, "manuscript_numbers_13_sites.csv"))

# ---- 5b. heterogeneity between states ----------------------------------------
# A pooled correlation rewards any seasonal cycle the pooled sites share, so it
# exceeds the day-to-day correlation by an amount that depends on how much
# regional structure the pooling spans. Rather than explain that from one state,
# compute it for every state with enough 24 h sites to pool: the gap becomes a
# distribution with a spread, and any single state can be placed in it.
big_states <- by_site |>
  filter(duration_class == "24 h") |>
  count(state, name = "n_sites") |>
  filter(n_sites >= CFG$min_sites_per_state) |>
  pull(state)

if (length(big_states)) {
  log_msg("States with >= ", CFG$min_sites_per_state, " sites sampling 24 h: ",
          length(big_states), " (", paste(sort(big_states), collapse = ", "), ")")

  state_pool <- use |>
    filter(lag_h == 0, duration_class == "24 h", state %in% big_states) |>
    group_by(state) |>
    group_modify(~ {
      an <- anom_of(.x)
      rs <- relstats(.x, nboot = 200, cluster = "site")
      as <- if (nrow(an) >= 6) anomstats(an) else tibble()
      tibble(n_sites   = n_distinct(.x$site),
             n         = nrow(.x),
             pooled_r  = if (nrow(rs)) rs$pearson_r[1] else NA_real_,
             anom_n    = nrow(an),
             anom_r    = if (nrow(as)) as$pearson_r[1] else NA_real_,
             anom_p_perm = if (nrow(as) && "pearson_p_perm" %in% names(as))
                             as$pearson_p_perm[1] else NA_real_)
    }) |>
    ungroup() |>
    mutate(pooling_gain = pooled_r - anom_r)

  # the spread of site-level day-to-day skill inside each state
  state_spread <- by_site |>
    filter(duration_class == "24 h", state %in% big_states, !is.na(anom_pearson_r)) |>
    group_by(state) |>
    summarise(n_sites_scored   = n(),
              median_site_r    = median(anom_pearson_r),
              q25_site_r       = quantile(anom_pearson_r, 0.25),
              q75_site_r       = quantile(anom_pearson_r, 0.75),
              min_site_r       = min(anom_pearson_r),
              max_site_r       = max(anom_pearson_r),
              .groups = "drop")

  by_state <- left_join(state_pool, state_spread, by = "state") |>
    arrange(desc(pooling_gain))
  data.table::fwrite(by_state, file.path(P$tables, "national_state_heterogeneity.csv"))
  print(by_state |> select(state, n_sites, n, pooled_r, anom_r, pooling_gain,
                           median_site_r, min_site_r, max_site_r), n = Inf)
  log_msg("Pooling gain (pooled r minus day-to-day r) across ", nrow(by_state),
          " states: median ", round(median(by_state$pooling_gain, na.rm = TRUE), 2),
          ", range ", round(min(by_state$pooling_gain, na.rm = TRUE), 2), " to ",
          round(max(by_state$pooling_gain, na.rm = TRUE), 2))
  log_msg("Median site-level day-to-day r by state: ",
          paste(by_state$state, round(by_state$median_site_r, 2), sep = " ", collapse = "; "))

  # Figure: the within-state distribution of site-level day-to-day skill, with
  # each state's pooled value marked, so the pooling gain is visible per state.
  sd_pts <- by_site |>
    filter(duration_class == "24 h", state %in% big_states, !is.na(anom_pearson_r)) |>
    left_join(select(by_state, state, median_site_r, pooled_r, anom_r), by = "state") |>
    mutate(state = reorder(state, median_site_r))
  # How much of the spread between monitors is geography? Decompose the
  # site-level day-to-day correlation into a between-state and a within-state
  # part. The answer is the point of the figure, so it is computed rather than
  # asserted in the caption.
  grand <- mean(sd_pts$anom_pearson_r)
  ss_total <- sum((sd_pts$anom_pearson_r - grand)^2)
  ss_between <- sd_pts |>
    group_by(state) |>
    summarise(k = n(), m = mean(anom_pearson_r), .groups = "drop") |>
    summarise(v = sum(k * (m - grand)^2)) |> pull(v)
  pct_between <- 100 * ss_between / ss_total
  log_msg("Site-level day-to-day agreement: ", round(pct_between), " % of the variance ",
          "lies BETWEEN states, ", round(100 - pct_between), " % within them ",
          "(between-state SD of medians ", round(sd(by_state$median_site_r), 3),
          ", mean within-state SD ",
          round(mean(tapply(sd_pts$anom_pearson_r, sd_pts$state, sd), na.rm = TRUE), 3), ")")

  # Numbers the manuscript quotes are written out by name, so the text can refer
  # to them instead of transcribing them. Transcription is how "12 %" reached
  # three places in the manuscript when the pipeline said 14: a decomposition
  # centred on state medians rather than state means. A number that is derived
  # cannot drift from the run that produced it.
  data.table::fwrite(
    tibble(key = c("pct_between_states", "pct_within_states", "n_multi_site_states",
                   "pooling_gain_median", "pooling_gain_min", "pooling_gain_max"),
           value = c(sprintf("%.0f", pct_between),
                     sprintf("%.0f", 100 - pct_between),
                     as.character(length(big_states)),
                     sprintf("%.2f", median(by_state$pooling_gain, na.rm = TRUE)),
                     sprintf("%.2f", min(by_state$pooling_gain, na.rm = TRUE)),
                     sprintf("%.2f", max(by_state$pooling_gain, na.rm = TRUE))),
           source = "R/13_national_analysis.R"),
    file.path(P$tables, "manuscript_numbers_13.csv"))

  p_state <- ggplot(sd_pts, aes(anom_pearson_r, state)) +
    geom_vline(xintercept = 0, colour = "grey70") +
    geom_point(aes(size = anom_n), alpha = 0.55, colour = "#1f78b4") +
    geom_point(aes(x = anom_r), shape = 124, size = 5, colour = "#b2182b") +
    scale_size_continuous(range = c(1.2, 4), name = "n") +
    labs(x = "Day-to-day correlation (within-month anomalies)", y = NULL,
         title = "Most variation in day-to-day agreement lies within states, not between them",
         subtitle = sprintf(paste("Each point a 24 h monitor, red bar the state's pooled value;",
                                  "only %.0f %% of the variance between monitors is between-state"),
                            pct_between))
  ggsave(file.path(P$figures, "fig15_state_heterogeneity.png"), p_state,
         width = 7.5, height = 4.8, dpi = 300)
  log_msg("  figure: fig15_state_heterogeneity.png")
}
log_msg("Sites with a significant whole-period correlation: ",
        sum(by_site$pearson_p < 0.05, na.rm = TRUE), " of ", nrow(by_site),
        " at nominal p < 0.05; ", sum(by_site$pearson_q < 0.05, na.rm = TRUE),
        " at Benjamini-Hochberg q < 0.05")
if ("anom_pearson_p" %in% names(by_site)) {
  log_msg("Sites with a significant day-to-day correlation, PERMUTATION p (the ",
          "basis used throughout): ",
          sum(by_site$anom_pearson_p_perm < 0.05, na.rm = TRUE), " of ",
          sum(!is.na(by_site$anom_pearson_p_perm)), " at nominal p < 0.05; ",
          sum(by_site$anom_pearson_q_perm < 0.05, na.rm = TRUE), " at BH q < 0.05")
  log_msg("  the same counts on the ordinary Pearson p, for comparison only: ",
          sum(by_site$anom_pearson_p < 0.05, na.rm = TRUE), " and ",
          sum(by_site$anom_pearson_q < 0.05, na.rm = TRUE))
  by_dur <- by_site |>
    group_by(duration_class) |>
    summarise(sites = n(),
              perm_nominal = sum(anom_pearson_p_perm < 0.05, na.rm = TRUE),
              perm_bh      = sum(anom_pearson_q_perm < 0.05, na.rm = TRUE),
              param_nominal = sum(anom_pearson_p < 0.05, na.rm = TRUE),
              param_bh      = sum(anom_pearson_q < 0.05, na.rm = TRUE),
              .groups = "drop")
  log_msg("  day-to-day significance counts by duration (Table S3):")
  print(by_dur)
}
if ("anom_pearson_r" %in% names(by_site)) {
  log_msg("Median within-month anomaly r across sites: ",
          round(median(by_site$anom_pearson_r, na.rm = TRUE), 2),
          " (24 h: ", round(median(by_site$anom_pearson_r[by_site$duration_class == "24 h"], na.rm = TRUE), 2),
          "; 8 h: ", round(median(by_site$anom_pearson_r[by_site$duration_class == "8 h"], na.rm = TRUE), 2), ")")
}

# ---- 6. regression with site and month effects -------------------------------
month_fx <- use |>
  group_by(duration_class, lag_h) |>
  group_modify(~ {
    d <- .x
    if (nrow(d) < 30 || n_distinct(d$site) < 2) return(tibble())
    co <- summary(lm(hcho_ugm3 ~ tempo_vc_1e15 + factor(month(sample_date)) + site, data = d))$coefficients
    tibble(n = nrow(d), estimate = co["tempo_vc_1e15", 1], std_error = co["tempo_vc_1e15", 2],
           p_value = co["tempo_vc_1e15", 4])
  }) |>
  ungroup()
data.table::fwrite(month_fx, file.path(P$tables, "national_month_effects_lm.csv"))
print(month_fx)

# ---- 7. sensitivity to screening --------------------------------------------
sens <- matched |>
  filter(usable) |>
  group_by(duration_class, lag_h, max_ecf, block_label) |>
  summarise(n = n(), pearson_r = cor(tempo_vc, hcho_ugm3),
            spearman_rho = suppressWarnings(cor(tempo_vc, hcho_ugm3, method = "spearman")),
            .groups = "drop")
data.table::fwrite(sens, file.path(P$tables, "national_sensitivity.csv"))

# Screening sensitivity, nationally. The equivalent Colorado figure rested on
# seven monitors; this one rests on every site in the comparison, so the choice
# of a 0.2 cloud threshold and a 3 x 3 block is defended on the network the
# paper is actually about. The national grid has no midday/all-day split - the
# sub-daily arms are defined by their own sampling windows - so the axes are the
# cloud threshold and the averaging block only.
# ---- smoke, across the whole network ----------------------------------------
# Smoke used to be characterised at nine Colorado sites, which is too narrow to
# say whether the effect generalises. Step 08 now flags the national windows
# too, so the same question can be asked of every site in the comparison.
sm_path <- file.path(P$processed, "smoke_flags.csv")
if (file.exists(sm_path)) {
  sm <- read_tbl(sm_path, colClasses = list(character = c("site", "smoke_class", "convention"))) |>
    filter(arm == "national")
  if (nrow(sm)) {
    # Key on the WINDOW, not the day. An 8 h site runs three windows on the same
    # date with the same duration_class, so (site, date, duration) matches three
    # smoke rows and three sample rows and the join fans out to nine - which is
    # how a first attempt reported 17 607 flagged samples from 16 383 windows
    # and computed every correlation on duplicated data. start_utc is unique per
    # window and is what step 08 recorded.
    sm <- sm |>
      transmute(site_id = site,
                start_utc = as.POSIXct(win_start_utc, tz = "UTC"),
                hms_available,
                smoke_any,
                smoke_class = factor(smoke_class, levels = c("none", "light", "medium/heavy")))
    stopifnot(!anyDuplicated(sm[, c("site_id", "start_utc")]))
    n_before <- sum(use$lag_h == 0)
    su <- use |>
      filter(lag_h == 0) |>
      mutate(start_utc = as.POSIXct(start_utc, tz = "UTC")) |>
      inner_join(sm, by = c("site_id", "start_utc"))
    if (nrow(su) > n_before) {
      stop("The smoke join added rows (", n_before, " -> ", nrow(su),
           "); the key is not unique and every statistic below would be wrong.")
    }
    log_msg("National smoke: ", nrow(su), " matched samples carry an HMS flag at ",
            n_distinct(su$site_id), " sites; ", sum(su$smoke_any %in% TRUE),
            " smoke-affected")
    if (nrow(su) >= 20) {
      nat_smoke <- su |>
        filter(!is.na(smoke_class)) |>
        group_by(duration_class, smoke_class) |>
        group_modify(~ relstats(.x, nboot = 200, cluster = "site")) |>
        ungroup()
      data.table::fwrite(nat_smoke, file.path(P$tables, "national_smoke.csv"))
      print(nat_smoke |> select(any_of(c("duration_class", "smoke_class", "n", "pearson_r",
                                         "median_surface_ugm3", "median_tempo_1e15"))), n = Inf)

      # does removing smoke days change day-to-day agreement, as it does in Colorado?
      nat_smoke_sens <- bind_rows(
          mutate(su, subset = "all days"),
          mutate(filter(su, !smoke_any %in% TRUE), subset = "smoke days excluded")) |>
        group_by(duration_class, subset) |>
        group_modify(~ { an <- anom_of(.x)
                         if (nrow(an) >= 6) anomstats(an) else tibble(n = nrow(an)) }) |>
        ungroup()
      data.table::fwrite(nat_smoke_sens, file.path(P$tables, "national_smoke_sensitivity.csv"))

      # Figure: agreement by smoke class, every duration, so the smoke result has
      # a display item of its own rather than borrowing the Colorado one.
      ns_plot <- nat_smoke |>
        filter(duration_class %in% c("24 h", "8 h", "3 h")) |>
        mutate(duration_class = factor(duration_class, levels = c("24 h", "8 h", "3 h")),
               smoke_class = factor(smoke_class, levels = c("none", "light", "medium/heavy")))
      p_smoke <- ggplot(ns_plot, aes(smoke_class, pearson_r, group = duration_class)) +
        geom_hline(yintercept = 0, colour = "grey70") +
        geom_line(colour = "grey55", linewidth = 0.6) +
        geom_point(aes(size = n), colour = "#b2182b") +
        geom_text(aes(label = n), vjust = -1.1, size = 2.7) +
        scale_size_continuous(range = c(1.5, 5), guide = "none") +
        scale_y_continuous(expand = expansion(mult = c(0.1, 0.2))) +
        facet_wrap(~ duration_class) +
        labs(x = "HMS smoke class over the site during the sampling window",
             y = "Pearson r, surface HCHO vs TEMPO column",
             title = "Agreement rises with smoke, at every duration with enough samples",
             subtitle = "Labels are matched samples; the 3 h medium/heavy class has too few to interpret")
      ggsave(file.path(P$figures, "fig17_national_smoke.png"), p_smoke, width = 8, height = 3.8, dpi = 300)
      log_msg("  figure: fig17_national_smoke.png")

      # Numbers the smoke paragraphs quote, by name.
      g <- function(dc, sc, col) nat_smoke[[col]][nat_smoke$duration_class == dc & nat_smoke$smoke_class == sc]
      dd <- function(dc, sub) nat_smoke_sens$pearson_r[nat_smoke_sens$duration_class == dc & nat_smoke_sens$subset == sub]
      data.table::fwrite(
        tibble(key = c("smoke_n_flagged", "smoke_n_affected",
                       "smoke_r_24_none", "smoke_r_24_light", "smoke_r_24_heavy",
                       "smoke_r_8_none",  "smoke_r_8_light",  "smoke_r_8_heavy",
                       "smoke_dd_24_all", "smoke_dd_24_nosmoke", "smoke_dd_8_all", "smoke_dd_8_nosmoke",
                       "smoke_col_24_none", "smoke_col_24_light",
                       "smoke_n_3_none", "smoke_n_3_light", "smoke_n_3_heavy"),
               value = c(nrow(su), sum(su$smoke_any %in% TRUE),
                         sprintf("%.2f", g("24 h", "none", "pearson_r")), sprintf("%.2f", g("24 h", "light", "pearson_r")), sprintf("%.2f", g("24 h", "medium/heavy", "pearson_r")),
                         sprintf("%.2f", g("8 h", "none", "pearson_r")),  sprintf("%.2f", g("8 h", "light", "pearson_r")),  sprintf("%.2f", g("8 h", "medium/heavy", "pearson_r")),
                         sprintf("%.2f", dd("24 h", "all days")), sprintf("%.2f", dd("24 h", "smoke days excluded")),
                         sprintf("%.2f", dd("8 h", "all days")),  sprintf("%.2f", dd("8 h", "smoke days excluded")),
                         sprintf("%.2f", g("24 h", "none", "median_tempo_1e15")), sprintf("%.2f", g("24 h", "light", "median_tempo_1e15")),
                         g("3 h", "none", "n"), g("3 h", "light", "n"), g("3 h", "medium/heavy", "n")),
               source = "R/13_national_analysis.R"),
        file.path(P$tables, "manuscript_numbers_13_smoke.csv"))
      print(nat_smoke_sens |> select(any_of(c("duration_class", "subset", "n", "site_months",
                                              "pearson_r", "pearson_p_perm"))), n = Inf)
    } else {
      log_msg("  too few flagged national samples for a smoke breakdown")
    }
  } else {
    log_msg("Smoke flags contain no national arm - re-run step 08 after step 11")
  }
}

sens0 <- filter(sens, lag_h == 0)
if (nrow(sens0)) {
  p_sens <- ggplot(sens0, aes(max_ecf, spearman_rho, colour = block_label)) +
    geom_line(linewidth = 0.7) +
    geom_point(aes(size = n)) +
    scale_x_continuous(breaks = sort(unique(sens0$max_ecf))) +
    scale_size_continuous(range = c(1.2, 4), name = "matched\nsamples") +
    facet_wrap(~ duration_class, scales = "free_y") +
    labs(x = "Maximum effective cloud fraction", y = "Pooled Spearman correlation",
         colour = "Averaging block",
         title = "Screening choices and the pooled correlation, all sites",
         subtitle = "Scans inside the sampling window; the primary screening is 0.2 with a 3 x 3 block") +
    theme(legend.position = "right")
  ggsave(file.path(P$figures, "fig16_national_screening_sensitivity.png"), p_sens,
         width = 8, height = 4.4, dpi = 300)
  log_msg("  figure: fig16_national_screening_sensitivity.png")
}

# ---- 8. figures --------------------------------------------------------------
theme_set(theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92")))

lag_curve <- by_duration_lag |>
  filter(duration_class != "24 h") |>
  select(duration_class, lag_h, whole = pearson_r, anomalies = anom_pearson_r, n, anom_n) |>
  pivot_longer(c(whole, anomalies), names_to = "kind", values_to = "r") |>
  mutate(n_lab = if_else(kind == "whole", n, anom_n))
if (nrow(lag_curve)) {
  p11 <- ggplot(lag_curve, aes(lag_h, r, colour = kind, shape = kind)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_vline(xintercept = 0, linetype = 2, colour = "grey60") +
    geom_line(linewidth = 0.7) + geom_point(size = 2.4) +
    geom_text(aes(label = n_lab), vjust = -1, size = 2.8, show.legend = FALSE) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.16))) +
    facet_wrap(~ duration_class) +
    labs(x = "Lag of the TEMPO window from the sampling window (h)",
         y = "Pearson r with surface HCHO", colour = NULL, shape = NULL,
         title = "National sub-daily samples: agreement against lag",
         subtitle = "Labels are the number of matched samples") +
    theme(legend.position = "bottom")
  ggsave(file.path(P$figures, "fig11_national_lag_curve.png"), p11, width = 8, height = 4.6, dpi = 300)
  log_msg("  figure: fig11_national_lag_curve.png")
}

if (nrow(by_hour)) {
  if (!"anom_pearson_r" %in% names(by_hour)) by_hour$anom_pearson_r <- NA_real_
  ph <- by_hour |>
    transmute(duration_class, window_start_hour, n, whole = pearson_r, anomalies = anom_pearson_r) |>
    pivot_longer(c(whole, anomalies), names_to = "kind", values_to = "r")
  p12 <- ggplot(ph, aes(window_start_hour, r, colour = kind, shape = kind)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_line(linewidth = 0.7) + geom_point(size = 2.6) +
    geom_text(aes(label = n), vjust = -1, size = 2.8, show.legend = FALSE) +
    scale_x_continuous(breaks = seq(0, 21, 4)) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.16))) +
    facet_wrap(~ duration_class) +
    labs(x = "Local standard hour the sample started",
         y = "Pearson r with surface HCHO", colour = NULL, shape = NULL,
         title = "Which sampling windows does TEMPO track?",
         subtitle = "Scans inside the sampling window; labels are the number of matched samples") +
    theme(legend.position = "bottom")
  ggsave(file.path(P$figures, "fig12_national_by_start_hour.png"), p12, width = 8, height = 4.6, dpi = 300)
  log_msg("  figure: fig12_national_by_start_hour.png")
}

if (nrow(by_site) && "anom_pearson_r" %in% names(by_site) && any(!is.na(by_site$anom_pearson_r))) {
  dur_order <- intersect(c("24 h", "8 h", "3 h", "1 h"), unique(by_site$duration_class))
  # US and state boundaries under the points. us_conus_states() returns NULL if
  # sf or the Census download is unavailable, in which case the figure is drawn
  # exactly as it was before rather than the step failing over a basemap.
  conus <- us_conus_states()
  p13 <- ggplot()
  if (!is.null(conus)) {
    p13 <- p13 + geom_sf(data = conus, fill = "grey97", colour = "grey75", linewidth = 0.15)
  }
  p13 <- p13 +
    geom_point(data = mutate(by_site, duration_class = factor(duration_class, levels = dur_order)),
               aes(lon, lat, colour = anom_pearson_r, size = anom_n), alpha = 0.9) +
    scale_colour_gradient2(low = "#b2182b", mid = "grey85", high = "#2166ac", midpoint = 0,
                           limits = c(-0.8, 0.8), oob = scales::squish) +
    scale_size_continuous(range = c(1.5, 5)) +
    facet_wrap(~ duration_class, ncol = 1) +
    labs(x = "Longitude", y = "Latitude", colour = "Day-to-day r", size = "n",
         title = "Day-to-day agreement, TEMPO vs surface HCHO",
         subtitle = "Within-month anomalies; scans inside the sampling window")
  p13 <- p13 + (if (is.null(conus)) coord_quickmap()
                else coord_sf(xlim = CONUS_XLIM, ylim = CONUS_YLIM, expand = FALSE, crs = 4326))
  ggsave(file.path(P$figures, "fig13_national_site_map.png"), p13, width = 5.5, height = 8.8, dpi = 300)
  log_msg("  figure: fig13_national_site_map.png")
}

# ---- 9. headline lines for the log ------------------------------------------
for (i in seq_len(nrow(by_duration_lag))) {
  r <- by_duration_lag[i, ]
  log_msg("  ", r$duration_class, ", lag ", r$lag_h, " h: r = ", round(r$pearson_r, 2),
          " (n = ", r$n, "); day-to-day r = ", round(r$anom_pearson_r, 2),
          " (n = ", r$anom_n, "); median PBL ", round(r$median_tempo_pbl_km, 2), " km")
}
for (i in seq_len(nrow(by_hour))) {
  r <- by_hour[i, ]
  log_msg("  ", r$duration_class, " samples starting ", r$window_start_hour, ":00 local: r = ",
          round(r$pearson_r, 2), " (n = ", r$n, ")",
          if ("anom_pearson_r" %in% names(r)) paste0("; day-to-day r = ", round(r$anom_pearson_r, 2)) else "")
}
log_msg("National analysis done.")
