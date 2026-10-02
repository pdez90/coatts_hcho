# =============================================================================
# 21_manuscript_tables.R - the display tables of the manuscript, as the build
# renders them, written by the pipeline rather than typed.
#
# Table 1 of the main text used to be a block of literal strings in the
# manuscript source that check_est.js verified against the output tables. A
# verified transcription is still a transcription: a row can be re-typed
# correctly against a stale table, or a value placed in the wrong column with
# every cell still "found". This step writes the table itself, cell by cell,
# from the step-13 outputs, so the document's Table 1 is a
# rendering of output/tables/manuscript_table1.csv and nothing else.
#
# The supplement's Tables S2-S4 and S8-S11 are rendered by tables_amt.js
# directly from the CSVs of steps 13, 19, 20 and 22; this step only adds the
# one table that needed assembling from several sources.
#
# Outputs: output/tables/manuscript_table1.csv   (row_label, 24 h, 8 h, 3 h)
# =============================================================================
source("R/00_config.R")
source("R/helpers_stats.R")

primary_path <- file.path(P$processed, "aqs_matched_primary.csv.gz")
dur_path     <- file.path(P$tables, "national_stats_by_duration_lag.csv")
site_path    <- file.path(P$tables, "national_stats_by_site.csv")
fx_path      <- file.path(P$tables, "national_month_effects_lm.csv")
for (f in c(primary_path, dur_path, site_path, fx_path)) if (!file.exists(f)) stop("Missing ", f, " - run step 13 first.")

prim <- read_tbl(primary_path, colClasses = list(character = c("site_id", "site", "qualifiers"))) |> filter(lag_h == 0)
dur  <- read_tbl(dur_path) |> filter(lag_h == 0)
bys  <- read_tbl(site_path, colClasses = list(character = c("site", "networks")))
fx   <- read_tbl(fx_path) |> filter(lag_h == 0)
DUR  <- c("24 h", "8 h", "3 h")

f2 <- function(x) sprintf("%.2f", x)
sites_states <- function(d) {
  st <- unique(d$state)
  dc <- any(st == "District Of Columbia")
  n_st <- sum(st != "District Of Columbia")
  sprintf("%d (%d%s)", n_distinct(d$site), n_st, if (dc) " + DC" else "")
}
# start hours holding at least 5 % of a duration's samples; the 3 h row is split
# by state because the two states use different schedules
principal_hours <- function(d) {
  hrs <- function(x) {
    tb <- sort(table(x$window_start_hour), decreasing = TRUE)
    keep <- as.integer(names(tb))[tb / nrow(x) >= 0.05]
    paste(sprintf("%02d", sort(keep)), collapse = ", ")
  }
  if (n_distinct(d$state) > 1 && d$duration_class[1] == "3 h") {
    parts <- d |> group_by(state) |> group_map(~ sprintf("%s (%s)", hrs(.x), state.abb[match(.y$state, state.name)]))
    return(paste(unlist(parts), collapse = "; "))
  }
  hrs(d)
}

cells <- map(DUR, function(dc) {
  d  <- filter(prim, duration_class == dc)
  u  <- filter(d, usable)
  r  <- filter(dur, duration_class == dc)
  # the site distribution exactly as step 13 summarises it: sites with >= 10
  # matched samples and >= CFG$min_anom_pairs_site anomaly pairs
  s  <- filter(bys, duration_class == dc, !is.na(anom_pearson_r))
  e  <- filter(fx, duration_class == dc)
  c("Sites (states)" = sites_states(d),
    "Samples" = as.character(nrow(d)),
    "Principal window start hours (LST)" = principal_hours(d),
    "Samples with a usable scan" = sprintf("%d (%.0f%%)", nrow(u), 100 * nrow(u) / nrow(d)),
    "Median usable scans per sample" = as.character(median(u$n_valid_scans)),
    "Pearson r" = f2(r$pearson_r),
    "Spearman ρ" = f2(r$spearman_rho),
    "Within-month anomaly r (n)^{a}" = sprintf("%s (%d)", f2(r$anom_pearson_r), r$anom_n),
    "Column coefficient (µg m^{−3} per 10^{15} molecules cm^{−2})" = sprintf("%.3f ± %.3f", e$estimate, e$std_error_site_clustered),   # site-clustered SE
    "Median surface HCHO (µg m^{−3})" = f2(r$median_surface_ugm3),
    "Median column (10^{15} molecules cm^{−2})" = f2(r$median_tempo_1e15),
    "Median H_{eff} / median TEMPO PBL height (km)" = sprintf("%s / %s", f2(r$median_h_eff_km), f2(r$median_tempo_pbl_km)),
    "Median anomaly r by site (IQR)^{a}" = sprintf("%s (%s–%s)", f2(median(s$anom_pearson_r)),
                                                   f2(quantile(s$anom_pearson_r, 0.25)), f2(quantile(s$anom_pearson_r, 0.75))))
})
tab <- tibble(row_label = names(cells[[1]]), `24 h` = cells[[1]], `8 h` = cells[[2]], `3 h` = cells[[3]])
data.table::fwrite(tab, file.path(P$tables, "manuscript_table1.csv"))
print(as.data.frame(tab), right = FALSE)
log_msg("Table 1 written: output/tables/manuscript_table1.csv")
