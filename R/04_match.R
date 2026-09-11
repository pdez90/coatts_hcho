# =============================================================================
# 04_match.R - screen TEMPO cells, build daily site values, join to COATTS
#
# For each variant (cloud threshold x block size x time window):
#   hourly  : mean of QC-passing cells in the block; the scan counts only if
#             >= qc_min_cell_fraction of block cells pass
#   daily   : mean of valid scans within the COATTS sample day (MST)
# Surface HCHO is converted to number density so that an effective mixing
# height H_eff = column / surface density can be computed (km).
# Outputs: data/processed/matched_variants.csv, matched_primary.csv
# =============================================================================
source("R/00_config.R")

coatts <- read_tbl(file.path(P$processed, "coatts_hcho.csv")) |>
  mutate(sample_date = as.Date(sample_date), season = factor(season, levels = c("DJF", "MAM", "JJA", "SON")))
manifest <- read_tbl(file.path(P$processed, "tempo_manifest.csv")) |>
  mutate(sample_date = as.Date(sample_date)) |>
  select(granule, sample_date, local_hour)
cells <- read_tbl(file.path(P$processed, "tempo_site_cells.csv.gz"),
                  colClasses = list(character = c("granule", "scan_start_utc", "site")))
value_cols <- setdiff(names(cells), c("granule", "scan_start_utc", "site"))
for (col in value_cols) {
  x <- cells[[col]]
  if (!is.numeric(x) || inherits(x, "integer64")) {
    xc <- trimws(as.character(x))
    num <- suppressWarnings(as.numeric(xc))
    bad <- unique(xc[is.na(num) & !is.na(xc) & xc != ""])
    if (length(bad)) warning(col, ": non-numeric values set to NA: ", paste(head(bad, 5), collapse = ", "))
    cells[[col]] <- num
  }
}
log_msg(nrow(cells), " TEMPO cell rows")

sites_with_tempo <- unique(cells$site)
dropped <- setdiff(unique(coatts$site), sites_with_tempo)
if (length(dropped)) {
  log_msg("No TEMPO cells for ", paste(dropped, collapse = ", "),
          " (no coordinates at extraction time) - excluded from matching")
  coatts <- filter(coatts, site %in% sites_with_tempo)
}

# columns that may be missing depending on the collection version
for (v in c("main_data_quality_flag", "eff_cloud_fraction", "snow_ice_fraction",
            "solar_zenith_angle", "pbl_height", "vertical_column_uncertainty")) {
  if (!v %in% names(cells)) cells[[v]] <- NA_real_
}

variants <- expand_grid(max_ecf = c(0.1, 0.2, 0.3),
                        block = c(0L, 1L, 2L),         # 1x1, 3x3, 5x5
                        window = c("all_day", "midday"))

screen_pass <- function(d, max_ecf) {
  with(d, !is.na(vertical_column) &
         coalesce(main_data_quality_flag, 0) <= CFG$qc_max_quality_flag &
         !is.na(eff_cloud_fraction) & eff_cloud_fraction <= max_ecf &
         coalesce(solar_zenith_angle, 0) <= CFG$qc_max_sza &
         coalesce(snow_ice_fraction, 0) <= CFG$qc_max_snow_ice)
}

hourly_for <- function(max_ecf, block) {
  cells |>
    filter(abs(di) <= block, abs(dj) <= block) |>
    mutate(pass = screen_pass(pick(everything()), max_ecf)) |>
    group_by(granule, site) |>
    summarise(n_cells = n(), n_pass = sum(pass),
              vc  = if (any(pass)) mean(vertical_column[pass]) else NA_real_,
              vcu = if (any(pass)) sqrt(mean(vertical_column_uncertainty[pass]^2)) else NA_real_,
              pbl = if (any(pass)) mean(pbl_height[pass], na.rm = TRUE) else NA_real_,
              ecf = mean(eff_cloud_fraction, na.rm = TRUE),
              .groups = "drop") |>
    mutate(valid = n_pass >= pmax(1, ceiling(CFG$qc_min_cell_fraction * n_cells)))
}

daily_for <- function(h, window) {
  h <- inner_join(h, manifest, by = "granule", relationship = "many-to-many")
  if (window == "midday") {
    h <- filter(h, local_hour >= CFG$midday_local_hours[1], local_hour < CFG$midday_local_hours[2])
  }
  h |>
    group_by(site, sample_date) |>
    summarise(n_scans = n(),
              n_valid_scans = sum(valid),
              tempo_vc = if (any(valid)) mean(vc[valid]) else NA_real_,
              tempo_vc_sd = if (sum(valid) > 1) sd(vc[valid]) else NA_real_,
              tempo_vcu = if (any(valid)) sqrt(mean(vcu[valid]^2)) / sqrt(sum(valid)) else NA_real_,
              tempo_pbl_m = if (any(valid)) mean(pbl[valid], na.rm = TRUE) else NA_real_,
              mean_ecf = mean(ecf, na.rm = TRUE),
              .groups = "drop")
}

variants <- mutate(variants, block_label = sprintf("%dx%d", 2L * block + 1L, 2L * block + 1L))

daily <- pmap(variants, function(max_ecf, block, window, block_label) {
  log_msg(sprintf("  variant: ECF <= %.1f, %s block, %s", max_ecf, block_label, window))
  daily_for(hourly_for(max_ecf, block), window) |>
    mutate(max_ecf = max_ecf, block = block, block_label = block_label, window = window)
}) |> list_rbind()

# Every COATTS day appears in every variant; days without any TEMPO scan
# (outages, or no midday scan) get n_scans = 0 and a missing column value.
matched <- coatts |>
  filter(!is.na(hcho_ugm3)) |>
  select(site, site_name, program, lat, lon, sample_date, season, year,
         hcho_ugm3, hcho_molec_cm3, hcho_ppb_local, non_detect, below_mdl, flags) |>
  cross_join(variants) |>
  left_join(daily, by = c("site", "sample_date", "max_ecf", "block", "block_label", "window")) |>
  mutate(n_scans = coalesce(n_scans, 0L),
         n_valid_scans = coalesce(n_valid_scans, 0L),
         tempo_vc_1e15 = tempo_vc / 1e15,
         h_eff_km = ifelse(tempo_vc > 0 & hcho_molec_cm3 > 0, tempo_vc / hcho_molec_cm3 / 1e5, NA_real_),
         tempo_pbl_km = tempo_pbl_m / 1000,
         usable = !is.na(tempo_vc) & !is.na(hcho_ugm3))

data.table::fwrite(matched, file.path(P$processed, "matched_variants.csv"))

primary <- matched |>
  filter(max_ecf == CFG$qc_max_cloud_fraction, block == 1L, window == "all_day")
data.table::fwrite(primary, file.path(P$processed, "matched_primary.csv"))

log_msg("Primary variant (ECF <= ", CFG$qc_max_cloud_fraction, ", 3x3, all day): ",
        sum(primary$usable), " usable site-days of ", nrow(primary), " COATTS sample days (",
        sum(primary$n_scans == 0), " with no TEMPO scan at all)")
