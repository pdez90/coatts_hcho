# COATTS formaldehyde vs TEMPO HCHO

Compares CDPHE's 24-hour formaldehyde samples (Colorado Air Toxics Trends,
COATTS, plus ozone-precursor sites that also collect carbonyls) with same-day
TEMPO Level 3 V04 formaldehyde columns. Everything — finding and downloading
the CDPHE packets, listing and subsetting TEMPO granules, matching, statistics
and figures — runs from R.

## One-time setup

1. **R ≥ 4.2** with a working compiler toolchain for packages (on macOS, the
   CRAN binaries are fine).
2. **Earthdata Login** (free): https://urs.earthdata.nasa.gov
   - Profile → *Generate Token*, then add one line to `~/.Renviron`
     (not to this project, so the token is never committed or shared):
     ```
     EARTHDATA_TOKEN=eyJ0eXAiOi...
     ```
     Restart R afterwards. Tokens expire after 60 days.
   - Alternative: a `~/.netrc` with
     `machine urs.earthdata.nasa.gov login <user> password <password>`.
3. **Restore the pinned package versions.** `renv.lock` is committed, so a
   fresh clone reproduces the environment the analysis was run with:
   ```r
   setwd("~/HCHO")
   install.packages("renv")
   renv::restore()     # installs the versions recorded in renv.lock
   ```
   `renv::snapshot()` is only needed if you change the package set and want the
   lock file to record it. Without renv, `R/00_config.R` installs whatever CRAN
   currently serves, which is convenient but not reproducible.

## Run

Get the code (or use your existing project folder):
```sh
git clone https://github.com/pdez90/coatts_hcho.git
cd coatts_hcho
```

Terminal (from the project folder):
```sh
Rscript run_all.R
```
RStudio: `setwd("<project folder>"); source("run_all.R")`

`data/`, `output/` and `logs/` are not in the repository; `run_all.R`
recreates them from the public CDPHE, NASA and NOAA sources. The checksums in
`data/raw/*/..._manifest.csv` record exactly which files a given run used.

Scripts can also be run one at a time (each sources `R/00_config.R`):

| Step | Script | What it does | Main output |
|---|---|---|---|
| 1 | `R/01_coatts.R` | Reads the seven Colorado 24 h sites' formaldehyde from EPA AQS (selected by site ID, so Wheat Ridge is included despite its short record). Also downloads CDPHE's annual packets and records their checksums; nothing in the paper uses the packet fields | `data/processed/coatts_hcho.csv`, `data/raw/coatts/download_manifest.csv` |
| 2 | `R/02_tempo_manifest.R` | Lists TEMPO granules (CMR, no login) whose scan midpoint falls in each 00–24 MST sample day | `data/processed/tempo_manifest.csv` |
| 3 | `R/03_tempo_extract.R` | Server-side OPeNDAP (DAP4) subset of each granule to a box around the sites; keeps an unscreened 5×5 cell block per site | `data/processed/tempo_site_cells.csv.gz`, `tempo_request_spec.txt` |
| 4 | `R/04_match.R` | Quality screening, hourly → daily aggregation, join to COATTS, 18 screening variants | `data/processed/matched_primary.csv`, `matched_variants.csv` |
| 5 | `R/05_analysis.R` | Coverage, correlations, OLS/RMA slopes (bootstrap CIs), mixed model, sensitivity, figures | `output/tables/*.csv`, `output/figures/*.png` |

**Check each step before the long download.** Run `source("R/01_coatts.R")` and
check that `output/tables/coatts_hcho_inventory.csv` lists the seven sites with
the sample counts of Table S1. Then run
step 2, set `max_granules = 5` in `R/00_config.R`, run step 3 and open
`data/processed/tempo_request_spec.txt` and one CSV in `data/interim/tempo_cells/`
(column values ~10¹⁵–10¹⁶ molec/cm², cell_lat/cell_lon next to the site). Set
`max_granules = NA` again for the full run.

### 3-hour arm (Littleton CHCO, Platteville PVCO)

These two sites belong to CDPHE's COOPs (ozone precursor) network, which was
discontinued at the end of June 2026; the historical data remain available.
Their formaldehyde samples are 3-hour samples that AQS records as starting at
06:00 MST with a 3 h duration. `run_all.R` runs this arm after the 24-h arm
(`run_three_hour_arm = TRUE`):

| Step | Script | What it does | Main output |
|---|---|---|---|
| 6 | `R/06_threeh_samples.R` | Reads the two sites' 3-h formaldehyde from EPA AQS (null-qualified rows removed), one row per sample, window end = AQS start + duration | `data/processed/threeh_hcho.csv`, `output/tables/threeh_inventory.csv` |
| 2, 3 | same scripts, arm `threeh` | TEMPO scans 03–19 MST on sample days; cells around the two sites (separate caches) | `threeh_tempo_manifest.csv`, `threeh_tempo_site_cells.csv.gz` |
| 7 | `R/07_threeh_analysis.R` | Averages screened scans in the sampling window and in windows lagged from it; correlations, within-month anomalies, month-effects regression, sensitivity, and agreement against lag | `output/tables/threeh_*.csv`, `fig7_threeh_scatter.png`, `fig8_threeh_sensitivity.png`, `fig10_threeh_lag_curve.png` |

The 09:00 stamp is the **end** of sampling: EPA's AQS holds these samples with a
start time of 06:00 MST and a duration of 3 hours (step 10), so the sampling
window is 06:00–09:00 MST. Step 7 averages TEMPO scans over that window and over
windows shifted by `threeh_lags_h` (default −3, 0, +3, +6, +9 h), which measures
how agreement depends on the delay between sampling and the satellite view;
`fig10_threeh_lag_curve.png` is that curve. Scans are assigned by their granule
midpoint, which can be ~30 min off the time TEMPO actually viewed Colorado.
Every sample in the AQS record begins at 06:00 MST; a sample that did not would
be flagged `stamp_time_unusual = TRUE` and left out of the matching
(`threeh_exclude_unusual_stamps`).
To run one step of this arm by hand: `options(hcho.arm = "threeh"); source("R/03_tempo_extract.R")`.

### Smoke flags (NOAA Hazard Mapping System)

| Step | Script | What it does | Main output |
|---|---|---|---|
| 8 | `R/08_smoke_hms.R` | Downloads the daily HMS smoke polygon shapefiles for every sample day, finds polygons covering each site, and flags a sample when a covering polygon's Start–End time overlaps its sampling window (00–24 MST for 24-h; the 3-h window for each stamp convention), widened by `hms_time_pad_hours` (3 h) on each side because HMS polygons are analyst delineations from discrete visible imagery, so an hour with no covering polygon is not established as smoke-free. Its effect is in `output/tables/smoke_pad_sensitivity.csv`; nationally the widening raises the smoke-affected share of windows from 30 % to 38 %. `smoke_any_day` ignores times altogether. Density: none / light / medium-heavy. A day without an HMS file gets `hms_available = FALSE` and missing flags, not "no smoke". | `data/processed/smoke_flags.csv`, `output/tables/smoke_inventory.csv` |

Step 5 then adds `smoke_coverage.csv` (TEMPO data loss by smoke class), `smoke_by_season.csv`,
`stats_by_smoke.csv`, `stats_within_month_anomalies_smoke_sensitivity.csv` and
`fig9_smoke_stratified.png`; step 7 adds `threeh_stats_by_smoke.csv`. Step 8
needs the `sf` package (installed automatically if missing). HMS polygons mark
smoke anywhere in the column, not necessarily at the surface.

### Diagnostics (tests of explanations)

Step 9 (`R/09_diagnostics.R`) reuses the outputs above (no downloads) to test
explanations for the main results. Run it alone with `source("R/09_diagnostics.R")`.

| Test | Question | Output |
|---|---|---|
| 1 | 3-h arm: do same-sample TEMPO columns in the sampling window and in the window after it vary together? Are the scans in either window screened out (solar zenith angle, cloud, snow, quality flag) or noisier at one site? | `diag1_threeh_window_columns.csv`, `diag1_threeh_window_screening.csv`, `figS3_threeh_window_columns.png` |
| 2 | 3-h arm: the sampling window vs the window after it, on the same samples (Williams' test for dependent correlations, paired bootstrap CI); seasonal mix of usable samples | `diag2_threeh_window_vs_after.csv`, `diag2_threeh_usable_by_season.csv` |
| 3 | 24-h arm: share of day-to-day column variance that is retrieval noise, and the correlation ceiling it implies, by site and block size. Noise is estimated from reported uncertainties (cells in a block fully correlated or independent) and from differences between successive valid scans (an upper bound on noise, since it includes real hourly change) | `diag3_noise_ceiling.csv`, `figS4_noise_ceiling.png` |
| 4 | Terrain heterogeneity inside each averaging block (spread of TEMPO surface pressure) next to site agreement; within-month anomaly correlations by site and season | `diag4_terrain_and_agreement.csv`, `diag4_anomaly_r_by_site_season.csv` |
| 5 | Smoke days: cloud fraction, scan survival and coverage by smoke class within season (HMS maps smoke only in clear imagery) | `diag5_smoke_clouds_by_season.csv`, `diag5_smoke_cloud_tests.csv` |

Key lines are also written to `output/tables/diag_summary.txt`.

### National formaldehyde data (EPA AQS)

Step 10 (`R/10_aqs_inventory.R`) inventories every formaldehyde monitor in EPA's
Air Quality System (parameter 43502) for `aqs_years`, using the pre-generated
AirData files (`annual_conc_by_monitor_<year>.zip`, `aqs_monitors.zip`; no API
key needed, cached in `data/raw/aqs`). It reports monitors by sample duration
(24 h as at NATTS/NCore sites, and 1 h / 3 h / 8 h as at PAMS sites) and by
network, and writes the sites that pass `aqs_durations` and `aqs_min_samples`.

| Step | Script | What it does | Main output |
|---|---|---|---|
| 10 | `R/10_aqs_inventory.R` | Downloads the AirData annual summaries and monitor metadata, keeps formaldehyde, classifies monitors by duration and network, lists candidate sites | `output/tables/aqs_hcho_summary.csv`, `output/tables/aqs_hcho_inventory.csv`, `data/processed/aqs_candidate_sites.csv` |
| 11 | `R/11_aqs_samples.R` | Pulls the individual samples for those sites from the AQS API (one request per state and year, cached), converts units, drops null-qualified records, averages duplicate POCs, and writes each sample's window in UTC. Also reports the sampling clock at each site and the likely cost of the national TEMPO extraction | `data/processed/aqs_hcho_samples.csv`, `output/tables/aqs_sample_clocks.csv`, `output/tables/aqs_samples_inventory.csv`, `output/tables/aqs_cluster_cost.csv` |

With an AQS API key the step also pulls sample-level records for
`aqs_sites_of_interest` and tabulates their time stamps and durations
(`output/tables/aqs_named_sites_sample_times.csv`). AQS records the time each
sample began, so this is an independent check on the 09:00 stamps of the 3-hour
Colorado samples. To get a key, run
`browseURL("https://aqs.epa.gov/data/api/signup?email=YOUR@EMAIL")` once and put
`AQS_EMAIL` and `AQS_KEY` in `~/.Renviron`.

| Step | Script | What it does | Main output |
|---|---|---|---|
| 12 | `R/12_tempo_national.R` | Groups the national sites into boxes, finds TEMPO granules for each box (one CMR query per box and month), then requests one OPeNDAP subset per box and scan, keeping a 5×5 cell block around each site. `aqs_arm_durations` selects which samples to cover; everything caches, so a long run can be stopped and resumed | `data/processed/aqs_tempo_site_cells.csv.gz`, `data/processed/aqs_tempo_manifest.csv` |
| 13 | `R/13_national_analysis.R` | Matches every national sample to its TEMPO scans (and to windows lagged from it), then reports coverage, correlations and within-month anomaly correlations by site, sample duration, lag and time of day, with a sensitivity table and three figures | `output/tables/national_*.csv`, `fig11_national_lag_curve.png`, `fig12_national_by_start_hour.png`, `fig13_national_site_map.png` |
| 14 | `R/14_site_map.R` | Map of the Colorado sites on terrain (supplement Fig. S1) | `fig0_site_map.png` |
| 15 | `R/15_clear_sky_bias.R` | Whether TEMPO-observable days are representative: surface HCHO on observable against screened-out days, within site and month, with site-clustered intervals, and which screening criterion is responsible (main Sect. 3.4, Fig. 3) | `output/tables/observability_*.csv`, `fig14_observability_bias.png` |
| 16 | `R/16_toc_graphic.R` | Table-of-contents graphic; checks the site range it quotes against `manuscript_numbers_13_sites.csv` | `toc_graphic.png` |
| 17 | `R/17_national_diagnostics.R` | Retrieval-noise ceiling at every 24 h site (main Sect. 3.3, supplement Sect. S4; plotted with the site descriptors in Fig. S7 by step 20) and the paired time-of-day comparison | `national_noise_ceiling.csv`, `national_time_of_day_paired.csv`, `manuscript_numbers_17.csv`, `fig18_national_noise_ceiling.png` |
| 18 | `R/18_hrrr_met.R` | Near-surface meteorology for every monitor from the NOAA HRRR analysis: per hour, only the 2 m temperature, surface pressure and PBL height messages are fetched by byte range off each GRIB2 file's `.idx`, plus the surface geopotential height once. One cache file per day, so an interrupted run resumes. Runs after steps 01, 06 and 11, as step 08 does, because each pass is the first sight of a new set of sample windows | `data/processed/hrrr_site_hours.csv.gz`, `data/processed/hrrr_site_terrain.csv`, `output/tables/hrrr_coverage.csv`, `output/tables/manuscript_numbers_18.csv` |
| 19 | `R/19_met_comparison.R` | HRRR against the meteorology supplied with the TEMPO retrieval and against the CDPHE sampler sensors. Boundary-layer depths are averaged over the UTC hours each sample's valid scans actually fell in, not over the whole sampling window, because TEMPO sees only daylight while a 24 h window is half night | `output/tables/met_hrrr_vs_tempo_pressure.csv`, `met_hrrr_vs_tempo_pbl.csv`, `met_hrrr_vs_measured_colorado.csv`, `fig19_met_comparison.png` |
| 20 | `R/20_agreement_diagnostics.R` | Why agreement differs: (A) 24 h against 8 h at the 23 monitors that report both, as paired within-site differences, plus the 24 h sample against the column restricted to each 8 h block; (B) the gap between each 24 h site's anomaly correlation and its step-17 noise ceiling, and a weighted Fisher-z model of both against six pre-specified site descriptors; (C) the empirical temporal-averaging curve, k = 1..4 random scans per 24 h sample against all scans, by spatial block, with the single-scan noise re-estimated from the variance against 1/k; (D) the column-surface anomaly correlation by tertile of HRRR mixing depth within each 8 h start hour, with a site-clustered interaction model and smoke-free and competing-moderator checks | `output/tables/diag7_dual_duration_*.csv`, `diag8_ceiling_gap_*.csv`, `diag9_temporal_averaging*.csv`, `diag10_pbl_*.csv`, `manuscript_numbers_20.csv`, `fig20`-`fig23` |
| 21 | `R/21_manuscript_tables.R` | Table 1 of the manuscript, cell by cell, from the step-13 outputs, so the document renders a CSV rather than a transcription. The supplement's Tables S2-S4 and S8-S11 are rendered from the CSVs of steps 13, 19, 22 and 20 directly by `manuscript/src/tables_amt.js` | `output/tables/manuscript_table1.csv` |
| 22 | `R/22_seasonal_analysis.R` | Agreement by season nationally (main Sect. 3.1; supplement Table S4, Fig. S5): pooled and day-to-day correlation by season (24 h, 8 h), the spatial correlation of site-season means (>= 6 samples per site-season, as in Wang et al. 2022) and the column-to-surface seasonal amplitude | `output/tables/national_seasonal*.csv`, `manuscript_numbers_22.csv`, `fig24_seasonal.png` |

Step 12 is the long one. `aqs_arm_durations` names all three duration sets, so
it covers every national site. Two different numbers describe its size and they
are not in conflict: step 11 prints a **pre-flight estimate** — 58 clusters and
roughly 85,000 requests, being every site that has samples times a
scans-per-day guess (`aqs_scans_per_day_guess`) — while the extraction that
produced the published outputs is summarised in
`output/tables/manuscript_numbers_13_extraction.csv` (clusters and cluster-scans
that returned data), because step 12 drops sites without coordinates or without
granules and counts the scans it actually retrieves. Either way, expect many hours. It is
off by default (`run_aqs_tempo = FALSE`), and it reuses the grid layout cached
by step 3, so run step 3 at least once first.

`run_all.R` order: 01 → 02 → 03 → 04 (24-h data) → 06 → 02 → 03 (3-h data) →
08 (smoke) → 05 → 07 (analyses) → 09 (diagnostics) → 10, 11 (national data) →
12 (national TEMPO) → 13 (national analysis) → 17 (national noise ceiling and
time of day) → 14 (site map) → 15 (observability bias) → 16 (TOC graphic) → 19
(HRRR against TEMPO meteorology) → 20 (agreement diagnostics) → 21 (Table 1) → 22
(agreement by season);
step 18 (HRRR meteorology) runs before each arm's matching. Every arm reads AQS,
so `run_all.R` stops at once if AQS credentials are absent.

**Reproducing the national arm from a clean clone takes one edit and one
command, not one command.** Step 12 is off by default because it is a multi-hour
download, so set `run_aqs_tempo = TRUE` in `R/00_config.R` first. With that flag
on, a single `Rscript run_all.R` schedules 12 → 13 → 14–16 in the same
invocation: each step is gated on its input being produced earlier in that run,
not on a file that happened to exist at startup. Leave the flag off and
the Colorado case study, its diagnostics, the HRRR meteorology and the AQS
inventory and sample pull still run end to end; the national analysis (steps 13,
15-17 and 20-22) needs the national TEMPO extraction.
Turn parts off with `run_three_hour_arm`, `run_smoke_flags`, `run_diagnostics`,
`run_aqs_inventory`, `run_aqs_samples` and `run_aqs_tempo` in `R/00_config.R`. Every arm needs an
AQS API key (`AQS_EMAIL`, `AQS_KEY` in `~/.Renviron`); without one `run_all.R`
stops before any download and says how to get one.

Every step caches what it has done. If step 3 is interrupted (it makes roughly
one request per TEMPO scan, on the order of 2,000), run it again and it
continues. Expect it to take from tens of minutes to a few hours depending on
the OPeNDAP server.

## Settings

All choices live in `CFG` in `R/00_config.R`:

- `date_range` — fixed analysis period (default 2023-08-01 to 2025-12-31, which
  is when TEMPO granules begin). The 24-h and national analyses use 2024-2025;
  only the 3-h arm reaches back to August 2023, and only at Platteville, which is
  the one site that reported formaldehyde to AQS that year. Controlled by
  `threeh_include_2023_aqs` / `threeh_aqs_year`; set the first to `FALSE` for a
  strictly 2024-2025 run.
- `coatts_refresh` — `FALSE` reuses downloaded packets; `TRUE` re-downloads and
  warns if CDPHE revised a file (checksums in `download_manifest.csv`)
- `include_ozone_precursor_sites` — add the COOPs sites to the 24-h arm. Off by
  default and normally pointless: their carbonyls are 3-h samples (used by the 3-h
  arm), 2024 wide COOPs packets are always skipped in step 1, and 2025 COOPs rows
  fail the 24-h duration test.
- `exclude_null_qualifiers`, `coatts_exclude_flags` — sample screening (see caveats)
- `qc_max_quality_flag`, `qc_max_cloud_fraction`, `qc_max_sza`, `qc_max_snow_ice`,
  `qc_min_cell_fraction` — screening for the primary analysis
- `midday_local_hours` — the alternative "midday" daily window
- `half_width_cells` — block size stored around each site (2 → 5×5)
- `keep_subsets` — keep the per-granule netCDF subsets (default deletes them after extraction)

Primary analysis: effective cloud fraction ≤ 0.2, quality flag 0, SZA ≤ 70°,
no snow/ice, 3×3 block (~6 km) with ≥ 50 % of cells passing, mean of all
screened scans in the sample day. `sensitivity_screening.csv` and
`fig5_sensitivity.png` show how results change with cloud threshold (0.1/0.2/0.3),
block (1×1/3×3/5×5) and window (all day/midday).

## Reproducibility record

Each `run_all.R` run writes to `logs/`:
- `run_<time>.log` — progress messages, warnings and errors
- `config_<time>.json` — the full `CFG` used
- `sessionInfo_<time>.txt` — R and package versions

Data provenance:
- CDPHE packets: URL, size, MD5 and file time in `data/raw/coatts/download_manifest.csv`
  (and `download_manifest_threeh.csv`). Archive `data/raw/` alongside a published
  analysis; CDPHE updates packets as validation continues.
- NOAA HMS smoke files: URL, status and MD5 in `data/raw/hms_smoke/hms_download_manifest.csv`.
- TEMPO: collection pinned by concept ID (`C3685897141-LARC_CLOUD`, TEMPO_HCHO_L3 V04);
  granule names and CMR query times in `tempo_manifest.csv`; the exact DAP4
  constraint in `tempo_request_spec.txt`.
- Bootstrap uses `set.seed(42)`.

## Method notes and caveats

- **Different quantities.** COATTS is a 24-h integrated surface concentration
  (µg/m³, reported at standard conditions, 25 °C and 1 atm); TEMPO is a daytime
  tropospheric column. The daily
  TEMPO value is the mean of screened daytime scans, so the comparison tests
  day-to-day and seasonal covariation, not hour-level agreement.
- **Effective mixing height.** `h_eff_km` = column ÷ surface number density.
  The reported µg/m³ is a standard-conditions mass concentration, so it is first
  converted to a mixing ratio (χ = C × 24.45/M) and then to a number density at
  the temperature and pressure of the sample, which is what makes `h_eff_km` a
  height rather than a unit conversion. Compared with TEMPO's `pbl_height` in
  `fig3`.
- **Sampling.** COATTS is 1-in-6 days; Colorado Springs, Pueblo and Cañon City
  start mid-2025 and Wheat Ridge in October 2025, so their seasonal statistics are thin.
- **Known TEMPO issues.** HCHO is provisional; published comparisons find it
  biased low along the Front Range and least reliable in thick smoke, over snow
  and at high solar zenith angles. Smoke days are flagged with NOAA HMS
  polygons (step 8); HMS marks smoke in the column, which may be aloft.
- **Non-detects** are left as missing (formaldehyde had none in 2024–2025);
  values below the MDL are kept as reported and flagged `below_mdl`.
- **Sample screening (per CDPHE).** `qc_code` follows AQDx v2: the 2025 AQDx
  sheets list QC samples (qc_code 8, e.g. flag `AY` "Q C Control Points
  (zero/span)", ~0.05 µg/m³) on the same dates as ambient samples (qc_code 0);
  only qc_code 0 is kept (`coatts_keep_qc_codes`). Rows with any AQS **Null Data
  Qualifier** are invalid or QC/QA and are dropped; the list is read from each
  packet's "Qualifier Flags" sheet (`exclude_null_qualifiers`, with
  `aqs_null_qualifiers_fallback` if a packet lacks the sheet). In the 2024–2025
  packets this removes only QC samples and one ADCO 2024 row without a value
  (`AV`, power failure), so results are unchanged. Quality Assurance and
  Informational qualifiers (e.g. `LJ` estimate, `TT` transport temperature, `QX`,
  `FB` field blank above limit, `IT` wildfire) are kept and listed in `flags` —
  add them to `coatts_exclude_flags` for a stricter screen.
- **Seasonality.** Surface and column formaldehyde both peak in summer, so
  whole-year correlations partly reflect the shared seasonal cycle.
  `stats_within_month_anomalies.csv` / `fig6` remove site-month means; the
  month-effects mixed model (`mixed_model_month_effects.csv`) does the same in a
  regression. RMA slopes and their intervals are reported for every group; the
  figures draw a fitted line only where the correlation reaches p < 0.05, but the
  tables withhold nothing. Anomaly p-values are within-site-month permutation
  values, not the ordinary correlation test.
- **Reporting conditions.** Settled, not assumed: CDPHE reports at standard
  conditions (25 °C, 1 atm). Two independent checks agree - the packet value
  against the AQS value for the same sample gives a ratio of 1.0019 over 438
  pairs, and the 2023 precursor workbook against the analysis file gives 1.0020
  over 25 days. Local-conditions reporting would have given ~0.88 at Platteville's
  elevation, so the distinction is not subtle. The conversion in step 04 uses this.
- **Coverage.** Every COATTS sample day appears in the matched tables; days with
  no TEMPO scan at all have `n_scans = 0`, days whose scans all failed screening
  have `usable = FALSE`.

## Troubleshooting

- *HTTP 401/403 in step 3* — token missing/expired: regenerate and update `~/.Renviron`, restart R.
- *Download failed for a CDPHE packet* — the state site may be down or changed;
  download the file in a browser into `data/raw/coatts/` and rerun.
- *"No annual data packets found"* — the repository page layout changed; check
  the link pattern in `R/01_coatts.R` (section 1).
- *A different TEMPO version* — change `tempo_collection`, delete
  `data/interim/tempo_layout.rds` and `data/interim/tempo_cells/`, rerun steps 2–5.
