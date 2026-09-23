# =============================================================================
# 19_met_comparison.R - HRRR against TEMPO's meteorology, and against the
# CDPHE packets' own sensors. No downloads; reads steps 04, 07, 13 and 18.
#
# Three comparisons are computed. Two of them reach the manuscript:
#
#  1. Surface pressure. TEMPO's support_data carries a surface pressure that
#     every arm used for the number density. HRRR resolves terrain at 3 km.
#     Where they disagree, the model terrain height (step 18) says why.
#     -> Figure S4a, Table S3, and the Methods statement that the two agree.
#  2. PBL height. TEMPO's pbl_height and HRRR's HPBL are different models at
#     very different resolutions, and TEMPO's runs the deeper of the two at
#     the hours it observes, which the Limitations report.
#     -> Figure S4b, Table S3.
#  3. Temperature and pressure against the CDPHE packet sensors, Colorado
#     only. As of 2026-09-23 this no longer appears in the paper: the author
#     dropped the packet sensors as a data source. It is still computed and
#     still written to met_hrrr_vs_measured_colorado.csv and the met_co_*
#     manuscript numbers, so the result stays in the pipeline record, but
#     nothing in the manuscript cites it and it is not drawn.
#
# Outputs: output/tables/met_hrrr_vs_tempo_pressure.csv
#          output/tables/met_hrrr_vs_tempo_pbl.csv
#          output/tables/met_hrrr_vs_measured_colorado.csv
#          output/tables/manuscript_numbers_19.csv
#          output/figures/fig19_met_comparison.png
# =============================================================================
source("R/00_config.R")
source("R/helpers_met.R")

read_arm <- function(path, arm) {
  if (!file.exists(path)) { log_msg("  no ", basename(path), " - ", arm, " skipped"); return(NULL) }
  d <- read_tbl(path)
  need <- c("temp_c_hrrr", "press_hpa_hrrr", "pbl_m_hrrr")
  if (!all(need %in% names(d))) {
    log_msg("  ", basename(path), " predates the HRRR step - re-run it; ", arm, " skipped")
    return(NULL)
  }
  d$arm <- arm
  d
}

arms <- list(
  read_arm(file.path(P$processed, "matched_primary.csv"), "Colorado 24 h"),
  read_arm(file.path(P$processed, "threeh_matched_primary.csv"), "Colorado 3 h"),
  read_arm(file.path(P$processed, "aqs_matched_primary.csv.gz"), "National")
) |> compact()
if (!length(arms)) stop("No matched files carry HRRR columns. Run R/18_hrrr_met.R, then steps 04/07/13.")

pick_cols <- function(d) {
  keep <- intersect(c("arm", "site", "site_name", "season", "sample_date", "start_utc",
                      "met_site_id", "lag_h", "usable",
                      "temp_c", "press_hpa", "temp_c_hrrr", "press_hpa_hrrr", "pbl_m_hrrr",
                      "scan_hours", "tempo_press_hpa", "tempo_pbl_m"), names(d))
  d[, keep, drop = FALSE]
}
d <- map(arms, pick_cols) |> list_rbind()
if ("lag_h" %in% names(d)) d <- filter(d, is.na(lag_h) | lag_h == 0)
if ("usable" %in% names(d)) d <- filter(d, is.na(usable) | usable)
log_msg(nrow(d), " matched samples across ", n_distinct(d$arm), " arms")

# HRRR averaged over the hours TEMPO's valid scans actually fell in. Comparing
# TEMPO's daytime-only scan mean with a 24 h window mean would attribute to the
# models a difference that is entirely one of sampling: half a 24 h window is
# night, when the boundary layer is shallow. The window means stay in the table
# beside these so the size of that artefact is on the record rather than
# asserted.
if (!"scan_hours" %in% names(d)) {
  stop("The matched files carry no scan_hours column. Re-run steps 04, 07 and 13\n",
       "  after the Sept 2026 change - step 19 cannot compare TEMPO's scan mean\n",
       "  with HRRR without knowing which hours the scans fell in.")
}
d <- bind_cols(d, met_mean_at_hours(d$met_site_id, d$scan_hours, met_read_cache()))
log_msg("HRRR at TEMPO's own scan hours: ", sum(!is.na(d$pbl_m_hrrr_scan)), " of ", nrow(d),
        " samples; median ", round(median(d$n_scan_hours, na.rm = TRUE)), " scan-hours each")

# a difference summary that is the same shape everywhere it is used
diff_stats <- function(d, a, b, ...) {
  d <- d |> filter(is.finite(.data[[a]]), is.finite(.data[[b]]))
  d |>
    group_by(...) |>
    summarise(n = n(),
              median_a = median(.data[[a]]),
              median_b = median(.data[[b]]),
              median_diff = median(.data[[b]] - .data[[a]]),
              mean_diff = mean(.data[[b]] - .data[[a]]),
              sd_diff = sd(.data[[b]] - .data[[a]]),
              p05_diff = stats::quantile(.data[[b]] - .data[[a]], 0.05),
              p95_diff = stats::quantile(.data[[b]] - .data[[a]], 0.95),
              r = if (n() >= 3 && sd(.data[[a]]) > 0 && sd(.data[[b]]) > 0)
                    stats::cor(.data[[a]], .data[[b]]) else NA_real_,
              .groups = "drop") |>
    mutate(across(where(is.numeric), ~ round(.x, 4)))
}

# ---- 1. surface pressure: HRRR vs TEMPO -------------------------------------
terr_path <- file.path(P$processed, "hrrr_site_terrain.csv")
terr <- if (file.exists(terr_path)) read_tbl(terr_path, colClasses = list(character = "met_site_id")) else NULL

press <- bind_rows(
  diff_stats(d, "press_hpa_hrrr_scan", "tempo_press_hpa", arm, site, site_name),
  diff_stats(d, "press_hpa_hrrr_scan", "tempo_press_hpa", arm) |> mutate(site = "all", site_name = ""),
  diff_stats(d, "press_hpa_hrrr_scan", "tempo_press_hpa") |> mutate(arm = "all arms", site = "all", site_name = "")
) |> relocate(arm, site, site_name)
if (!is.null(terr)) {
  press <- left_join(press, select(terr, site = sites, terrain_m), by = "site")
}
data.table::fwrite(press, file.path(P$tables, "met_hrrr_vs_tempo_pressure.csv"))
pa <- filter(press, arm == "all arms")
log_msg("Surface pressure, TEMPO minus HRRR: median ", pa$median_diff, " hPa (5-95 % ",
        pa$p05_diff, " to ", pa$p95_diff, "), r = ", pa$r, ", n = ", pa$n)

# ---- 2. PBL height: HRRR vs TEMPO -------------------------------------------
pbl <- bind_rows(
  diff_stats(d, "pbl_m_hrrr_scan", "tempo_pbl_m", arm, season),
  diff_stats(d, "pbl_m_hrrr_scan", "tempo_pbl_m", arm) |> mutate(season = "all"),
  diff_stats(d, "pbl_m_hrrr_scan", "tempo_pbl_m") |> mutate(arm = "all arms", season = "all")
) |> relocate(arm, season) |> mutate(hrrr_hours = "TEMPO scan hours")
d_all <- mutate(d, arm = "all arms")
# The same contrast computed on the window mean, kept only to show how much of
# a naive comparison is sampling rather than model disagreement.
pbl_window <- diff_stats(bind_rows(d, d_all), "pbl_m_hrrr", "tempo_pbl_m", arm) |>
  mutate(season = "all", hrrr_hours = "whole sampling window") |>
  relocate(arm, season)
pbl <- bind_rows(pbl, pbl_window)
data.table::fwrite(pbl, file.path(P$tables, "met_hrrr_vs_tempo_pbl.csv"))
ba <- filter(pbl, arm == "all arms", hrrr_hours == "TEMPO scan hours")
log_msg("PBL height at TEMPO's scan hours, TEMPO minus HRRR: median ", ba$median_diff,
        " m (HRRR ", ba$median_a, " m, TEMPO ", ba$median_b, " m), r = ", ba$r, ", n = ", ba$n)
for (a in unique(pbl_window$arm)) {
  w <- filter(pbl_window, arm == a); s <- filter(pbl, arm == a, hrrr_hours == "TEMPO scan hours")
  if (nrow(w) == 1 && nrow(s) == 1) {
    log_msg("  ", a, ": HRRR median ", s$median_a, " m over the scan hours vs ",
            w$median_a, " m over the whole window - the gap between those two is sampling, not physics")
  }
}

# ---- 3. Colorado: HRRR against the packets' own sensors ----------------------
co <- filter(d, arm == "Colorado 24 h")
cmp <- NULL
if (nrow(co) && "temp_c" %in% names(co)) {
  cmp <- bind_rows(
    diff_stats(co, "temp_c_hrrr", "temp_c", site, site_name) |> mutate(quantity = "temperature (C)"),
    diff_stats(co, "temp_c_hrrr", "temp_c") |> mutate(site = "all", site_name = "", quantity = "temperature (C)"),
    diff_stats(co, "press_hpa_hrrr", "press_hpa", site, site_name) |> mutate(quantity = "pressure (hPa)"),
    diff_stats(co, "press_hpa_hrrr", "press_hpa") |> mutate(site = "all", site_name = "", quantity = "pressure (hPa)")
  ) |> relocate(quantity, site, site_name)
  data.table::fwrite(cmp, file.path(P$tables, "met_hrrr_vs_measured_colorado.csv"))
  tt <- filter(cmp, quantity == "temperature (C)", site == "all")
  pp <- filter(cmp, quantity == "pressure (hPa)", site == "all")
  log_msg("Colorado packets minus HRRR: temperature ", tt$median_diff, " C (r = ", tt$r,
          ", n = ", tt$n, "); pressure ", pp$median_diff, " hPa (r = ", pp$r, ", n = ", pp$n, ")")
  log_msg("  A packet temperature that tracks HRRR and a packet pressure tens of hPa below it ",
          "is the signature of an ambient thermometer and an in-line pressure sensor.")
}

# ---- manuscript numbers ------------------------------------------------------
g <- function(d, ...) { r <- filter(d, ...); if (nrow(r) != 1) NA_real_ else r }
keys <- tibble(
  key = c("met_press_tempo_minus_hrrr", "met_press_tempo_hrrr_r", "met_press_n",
          "met_pbl_hrrr_median", "met_pbl_tempo_median", "met_pbl_tempo_minus_hrrr",
          "met_pbl_r", "met_pbl_hrrr_window_median"),
  value = c(sprintf("%.1f", pa$median_diff), sprintf("%.2f", pa$r), sprintf("%.0f", pa$n),
            sprintf("%.0f", ba$median_a), sprintf("%.0f", ba$median_b),
            sprintf("%.0f", ba$median_diff), sprintf("%.2f", ba$r),
            sprintf("%.0f", filter(pbl_window, arm == "all arms")$median_a[1])),
  source = "R/19_met_comparison.R")
if (!is.null(cmp)) {
  tt <- filter(cmp, quantity == "temperature (C)", site == "all")
  pp <- filter(cmp, quantity == "pressure (hPa)", site == "all")
  keys <- bind_rows(keys, tibble(
    key = c("met_co_temp_packet_minus_hrrr", "met_co_temp_r",
            "met_co_press_packet_minus_hrrr", "met_co_press_n"),
    value = c(sprintf("%.1f", tt$median_diff), sprintf("%.2f", tt$r),
              sprintf("%.1f", pp$median_diff), sprintf("%.0f", pp$n)),
    source = "R/19_met_comparison.R"))
}
data.table::fwrite(keys, file.path(P$tables, "manuscript_numbers_19.csv"))
print(keys, n = Inf)

# ---- figure ------------------------------------------------------------------
dir.create(P$figures, recursive = TRUE, showWarnings = FALSE)
# colour_by_arm = FALSE is for a panel drawn from a single arm: with guides =
# "collect" patchwork would otherwise gather a second, one-entry colour legend
# and the combined legend would list that arm twice. No panel needs it since
# the Colorado packet panel was dropped; it is kept for whoever restores one.
panel <- function(d, a, b, lab_a, lab_b, title, colour_by_arm = TRUE) {
  d <- filter(d, is.finite(.data[[a]]), is.finite(.data[[b]]))
  if (!nrow(d)) return(NULL)
  mapping <- if (colour_by_arm) aes(.data[[a]], .data[[b]], colour = arm)
             else aes(.data[[a]], .data[[b]])
  ggplot(d, mapping) +
    geom_abline(slope = 1, intercept = 0, linewidth = 0.3, colour = "grey50") +
    geom_point(alpha = 0.25, size = 0.7) +
    labs(x = lab_a, y = lab_b, title = title, colour = NULL) +
    theme_minimal(base_size = 9) +
    theme(legend.position = "bottom")
}
ps <- compact(list(
  panel(d, "press_hpa_hrrr_scan", "tempo_press_hpa", "HRRR surface pressure (hPa)",
        "TEMPO surface pressure (hPa)", "a  Surface pressure"),
  panel(d, "pbl_m_hrrr_scan", "tempo_pbl_m", "HRRR PBL height (m)",
        "TEMPO PBL height (m)", "b  Boundary-layer depth")))
# A third panel drew HRRR against the CDPHE packet temperature until 2026-09-23;
# see comparison 3 in the header for why it went and what still computes it.
if (length(ps)) {
  fig <- if (requireNamespace("patchwork", quietly = TRUE)) {
    Reduce(`+`, ps) + patchwork::plot_layout(nrow = 1, guides = "collect") &
      theme(legend.position = "bottom")
  } else ps[[1]]
  ggsave(file.path(P$figures, "fig19_met_comparison.png"), fig,
         width = 3.3 * length(ps), height = 3.6, dpi = 300)
  log_msg("Wrote ", file.path(P$figures, "fig19_met_comparison.png"))
}
log_msg("Meteorology comparison done.")
