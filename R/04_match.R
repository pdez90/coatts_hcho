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
source("R/helpers_screen.R")   # one definition of the TEMPO cell screen
source("R/helpers_met.R")      # one definition of the near-surface meteorology

coatts <- read_tbl(file.path(P$processed, "coatts_hcho.csv")) |>
  mutate(sample_date = as.Date(sample_date), season = factor(season, levels = c("DJF", "MAM", "JJA", "SON")))
manifest <- read_tbl(file.path(P$processed, "tempo_manifest.csv")) |>
  mutate(sample_date = as.Date(sample_date)) |>
  mutate(mid_utc = as.POSIXct(mid_utc, tz = "UTC")) |>
  select(granule, sample_date, local_hour, mid_utc)
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

# Availability of the QC criteria, placeholders for anything the extraction does
# not carry, and the per-cell gap report - all in helpers_screen.R, so steps 04,
# 07 and 13 cannot drift apart again.
.prep <- hcho_prepare_cells(cells)
cells <- .prep$cells
QC_ABSENT <- .prep$absent

# Temperature for the number density: the packet's own met where the site and
# month have it, otherwise the site median, otherwise CFG$hcho_fallback_temp_c.
met_month <- coatts |>
  filter(!is.na(temp_c)) |>
  group_by(site, month = month(sample_date)) |>
  summarise(temp_c_month = median(temp_c), .groups = "drop")
met_site <- coatts |>
  filter(!is.na(temp_c)) |>
  group_by(site) |>
  summarise(temp_c_site = median(temp_c), .groups = "drop")

# The temperature and pressure that actually go into the number density come
# from HRRR, averaged over this sample's own 24 h MST window. The packets'
# Temperature is kept beside it and checked against HRRR in step 19; their
# Pressure is no longer used at all - it is 45-60 hPa below ambient at every
# site, which is the note at the top of R/helpers_met.R.
coatts <- coatts |>
  mutate(start_utc = as.POSIXct(paste0(as.Date(sample_date), " 00:00:00"), tz = "UTC") -
                     CFG$utc_offset_hours * 3600,
         duration_h = 24) |>
  met_attach(what = "Colorado 24 h")

variants <- expand_grid(max_ecf = c(0.1, 0.2, 0.3),
                        block = c(0L, 1L, 2L),         # 1x1, 3x3, 5x5
                        window = c("all_day", "midday"))

# A cell passes only if every QC variable the collection provides is present and
# within its limit. A missing value fails: the earlier coalesce(x, 0) turned an
# absent quality flag into "good", an absent solar zenith angle into 0 deg and an
# absent snow fraction into "no snow", all of which are the most permissive value
# the criterion admits. Criteria in QC_ABSENT are skipped, having been reported
# above, so that a collection lacking a variable degrades visibly rather than
# rejecting every cell.
screen_pass <- function(d, max_ecf) hcho_screen_pass(d, max_ecf, QC_ABSENT)


hourly_for <- function(max_ecf, block) {
  cells |>
    filter(abs(di) <= block, abs(dj) <= block) |>
    mutate(pass = screen_pass(pick(everything()), max_ecf)) |>
    group_by(granule, site) |>
    summarise(n_cells = n(), n_pass = sum(pass),
              vc  = if (any(pass)) mean(vertical_column[pass]) else NA_real_,
              vcu = if (any(pass)) sqrt(mean(vertical_column_uncertainty[pass]^2)) else NA_real_,
              pbl = if (any(pass)) mean(pbl_height[pass], na.rm = TRUE) else NA_real_,
              sp  = if (any(pass)) mean(surface_pressure[pass], na.rm = TRUE) else NA_real_,
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
              tempo_press_hpa = if (any(valid)) mean(sp[valid], na.rm = TRUE) else NA_real_,
              mean_ecf = mean(ecf, na.rm = TRUE),
              # the UTC hours the valid scans fell in, so step 19 can average
              # HRRR over the same hours TEMPO actually saw rather than over
              # the whole 24 h window, half of which is night
              scan_hours = paste(met_hour_key(mid_utc[valid]), collapse = " "),
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
  mutate(month = month(sample_date)) |>
  select(site, site_name, program, lat, lon, sample_date, month, season, year,
         hcho_ugm3, hcho_molec_cm3, hcho_ppb_local, non_detect, below_mdl, flags,
         temp_c, press_hpa,
         start_utc, duration_h, met_site_id, met_coverage,
         temp_c_hrrr, press_hpa_hrrr, pbl_m_hrrr) |>
  cross_join(variants) |>
  left_join(daily, by = c("site", "sample_date", "max_ecf", "block", "block_label", "window")) |>
  left_join(met_month, by = c("site", "month" = "month")) |>
  left_join(met_site, by = "site") |>
  mutate(n_scans = coalesce(n_scans, 0L),
         n_valid_scans = coalesce(n_valid_scans, 0L),
         tempo_vc_1e15 = tempo_vc / 1e15,
         # reported concentrations are at 25 C and 1 atm, so convert to a mixing
         # ratio and then to the number density at the site's own T and P.
         # Both now come from HRRR over the sample window; no fallback, because
         # a window HRRR could not cover should show as a missing H_eff rather
         # than as one computed at an assumed temperature.
         temp_c_used = temp_c_hrrr,
         press_hpa_used = press_hpa_hrrr,
         hcho_ppb_std = ugm3_std_to_ppb(hcho_ugm3),
         hcho_molec_cm3_local = ppb_to_molec_cm3(hcho_ppb_std, temp_c_used, press_hpa_used),
         h_eff_std_km = ifelse(tempo_vc > 0 & hcho_molec_cm3 > 0, tempo_vc / hcho_molec_cm3 / 1e5, NA_real_),
         h_eff_km = ifelse(tempo_vc > 0 & hcho_molec_cm3_local > 0,
                           tempo_vc / hcho_molec_cm3_local / 1e5, h_eff_std_km),
         # The convention every arm used before HRRR: a fixed temperature
         # (CFG$hcho_fallback_temp_c) and TEMPO's own surface pressure. Kept as
         # an audit column so the size of the Sept 2026 change is visible in the
         # output rather than asserted - step 05 reports the two side by side.
         hcho_molec_cm3_natconv = ppb_to_molec_cm3(hcho_ppb_std, CFG$hcho_fallback_temp_c,
                                                   tempo_press_hpa),
         h_eff_natconv_km = ifelse(tempo_vc > 0 & hcho_molec_cm3_natconv > 0,
                                   tempo_vc / hcho_molec_cm3_natconv / 1e5, NA_real_),
         tempo_pbl_km = tempo_pbl_m / 1000,
         usable = !is.na(tempo_vc) & !is.na(hcho_ugm3))

data.table::fwrite(matched, file.path(P$processed, "matched_variants.csv"))

primary <- matched |>
  filter(max_ecf == CFG$qc_max_cloud_fraction, block == 1L, window == "all_day")
data.table::fwrite(primary, file.path(P$processed, "matched_primary.csv"))

prim_chk <- filter(matched, max_ecf == CFG$qc_max_cloud_fraction, block == 1L, window == "all_day", usable)
log_msg("Number density: ", sum(!is.na(prim_chk$temp_c_hrrr)), " of ", nrow(prim_chk),
        " matched days carry HRRR temperature and pressure; ",
        sum(!is.na(prim_chk$temp_c)), " also carry the packets' own thermometer (step 19 compares them); ",
        "median H_eff ", round(median(prim_chk$h_eff_km, na.rm = TRUE), 2), " km at HRRR conditions vs ",
        round(median(prim_chk$h_eff_std_km, na.rm = TRUE), 2), " km at standard conditions, ",
        round(median(prim_chk$h_eff_natconv_km, na.rm = TRUE), 2), " km at the pre-HRRR convention")
log_msg("Primary variant (ECF <= ", CFG$qc_max_cloud_fraction, ", 3x3, all day): ",
        sum(primary$usable), " usable site-days of ", nrow(primary), " COATTS sample days (",
        sum(primary$n_scans == 0), " with no TEMPO scan at all)")
