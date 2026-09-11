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
3. **Pin package versions with renv** (recommended for reproducibility):
   ```r
   setwd("~/HCHO")
   install.packages("renv")
   renv::init()        # first time: creates renv.lock from this project's packages
   # ... after a successful run:
   renv::snapshot()    # records exact versions
   # on another machine / later:
   renv::restore()
   ```
   Without renv, `R/00_config.R` installs any missing packages from CRAN.

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
| 1 | `R/01_coatts.R` | Reads the CDPHE repository page, downloads the annual packets for COATTS (and ozone-precursor) sites, extracts formaldehyde from both the 2024 wide and 2025 AQDx layouts, records checksums | `data/processed/coatts_hcho.csv`, `data/raw/coatts/download_manifest.csv` |
| 2 | `R/02_tempo_manifest.R` | Lists TEMPO granules (CMR, no login) whose scan midpoint falls in each 00–24 MST sample day | `data/processed/tempo_manifest.csv` |
| 3 | `R/03_tempo_extract.R` | Server-side OPeNDAP (DAP4) subset of each granule to a box around the sites; keeps an unscreened 5×5 cell block per site | `data/processed/tempo_site_cells.csv.gz`, `tempo_request_spec.txt` |
| 4 | `R/04_match.R` | Quality screening, hourly → daily aggregation, join to COATTS, 18 screening variants | `data/processed/matched_primary.csv`, `matched_variants.csv` |
| 5 | `R/05_analysis.R` | Coverage, correlations, OLS/RMA slopes (bootstrap CIs), mixed model, sensitivity, figures | `output/tables/*.csv`, `output/figures/*.png` |

**Check each step before the long download.** Run `source("R/01_coatts.R")` and
compare `output/tables/coatts_hcho_inventory.csv` with the packets (e.g. ADCO 2024:
62 sample days, median ≈2.9 µg/m³; ADCO 2025: 63 days, median ≈3.0). Then run
step 2, set `max_granules = 5` in `R/00_config.R`, run step 3 and open
`data/processed/tempo_request_spec.txt` and one CSV in `data/interim/tempo_cells/`
(column values ~10¹⁵–10¹⁶ molec/cm², cell_lat/cell_lon next to the site). Set
`max_granules = NA` again for the full run.

### 3-hour arm (Littleton CHCO, Platteville PVCO)

CDPHE's 2025 packets for these two ozone-precursor sites hold formaldehyde as
3-hour samples stamped 09:00 MST. `run_all.R` runs this arm after the 24-h arm
(`run_three_hour_arm = TRUE`):

| Step | Script | What it does | Main output |
|---|---|---|---|
| 6 | `R/06_threeh_samples.R` | Downloads the site packets, keeps ambient 3-h formaldehyde (QC rows removed), one row per sample | `data/processed/threeh_hcho.csv`, `output/tables/threeh_inventory.csv` |
| 2, 3 | same scripts, arm `threeh` | TEMPO scans 05–13 MST on sample days; cells around the two sites (separate caches) | `threeh_tempo_manifest.csv`, `threeh_tempo_site_cells.csv.gz` |
| 7 | `R/07_threeh_analysis.R` | Averages screened scans whose midpoint falls inside each sampling window; correlations, within-month anomalies, month-effects regression, sensitivity | `output/tables/threeh_*.csv`, `fig7_threeh_scatter.png`, `fig8_threeh_sensitivity.png` |

Whether the 09:00 stamp is the start (09–12 MST) or end (06–09 MST) of the
sample is not yet confirmed, so every result is given for both conventions
(`threeh_stamp_conventions`); "start" is treated as primary. Scans are assigned
by their granule midpoint, which can be ~30 min off the time TEMPO actually
viewed Colorado. The 2024 packets for these sites (09:00 stamps, no duration
field) are excluded until CDPHE confirms their duration (`threeh_include_2024`).
To run one step of this arm by hand: `options(hcho.arm = "threeh"); source("R/03_tempo_extract.R")`.

### Smoke flags (NOAA Hazard Mapping System)

| Step | Script | What it does | Main output |
|---|---|---|---|
| 8 | `R/08_smoke_hms.R` | Downloads the daily HMS smoke polygon shapefiles for every sample day, finds polygons covering each site, and flags a sample when a covering polygon's Start–End time overlaps its sampling window (00–24 MST for 24-h; the 3-h window for each stamp convention), widened by `hms_time_pad_hours` (3 h) on each side because HMS times are the analysts' imagery periods, which cluster around 11–15 and 18–24 UTC and leave a 09–12 MST gap. `smoke_any_day` ignores times altogether. Density: none / light / medium-heavy. A day without an HMS file gets `hms_available = FALSE` and missing flags, not "no smoke". | `data/processed/smoke_flags.csv`, `output/tables/smoke_inventory.csv` |

Step 5 then adds `smoke_coverage.csv` (TEMPO data loss by smoke class), `smoke_by_season.csv`,
`stats_by_smoke.csv`, `stats_within_month_anomalies_smoke_sensitivity.csv` and
`fig9_smoke_stratified.png`; step 7 adds `threeh_stats_by_smoke.csv`. Step 8
needs the `sf` package (installed automatically if missing). HMS polygons mark
smoke anywhere in the column, not necessarily at the surface.

`run_all.R` order: 01 → 02 → 03 → 04 (24-h data) → 06 → 02 → 03 (3-h data) →
08 (smoke) → 05 → 07 (analyses). Turn arms off with `run_three_hour_arm` and
`run_smoke_flags` in `R/00_config.R`.

Every step caches what it has done. If step 3 is interrupted (it makes roughly
one request per TEMPO scan, on the order of 2,000), run it again and it
continues. Expect it to take from tens of minutes to a few hours depending on
the OPeNDAP server.

## Settings

All choices live in `CFG` in `R/00_config.R`:

- `date_range` — fixed analysis period (default 2024-01-01 to 2025-12-31)
- `coatts_refresh` — `FALSE` reuses downloaded packets; `TRUE` re-downloads and
  warns if CDPHE revised a file (checksums in `download_manifest.csv`)
- `include_ozone_precursor_sites` — also use 2024 carbonyls from Littleton (CHCO) and
  Platteville (PVCO). Off by default: their 2025 packets hold no 24-h formaldehyde.
  Turning it on makes step 3 re-extract every granule (~25 min) for the added sites.
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
  (µg/m³, local conditions); TEMPO is a daytime tropospheric column. The daily
  TEMPO value is the mean of screened daytime scans, so the comparison tests
  day-to-day and seasonal covariation, not hour-level agreement.
- **Effective mixing height.** `h_eff_km` = column ÷ surface number density.
  Surface µg/m³ converts to molecules/cm³ without temperature or pressure.
  Compared with TEMPO's `pbl_height` in `fig3`.
- **Sampling.** COATTS is 1-in-6 days; Colorado Springs, Pueblo and Cañon City
  start mid-2025 and Wheat Ridge in October 2025, so their seasonal statistics are thin.
- **Known TEMPO issues.** HCHO is provisional; published comparisons find it
  biased low along the Front Range and least reliable in thick smoke, over snow
  and at high solar zenith angles. Smoke days are flagged with NOAA HMS
  polygons (step 8); HMS marks smoke in the column, which may be aloft.
- **Non-detects** are left as missing (formaldehyde had none in 2024–2025);
  values below the MDL are kept as reported and flagged `below_mdl`.
- **CDPHE QC rows.** The 2025 AQDx sheets list QC samples (qc_code 8, flag `AY`,
  "Q C Control Points (zero/span)", ~0.05 µg/m³) on the same dates as ambient
  samples. They are removed (`coatts_keep_qc_codes`, `coatts_exclude_flags`);
  other qualifiers (e.g. `LJ` estimate, `TT` transport temperature, `QX`) are kept
  and listed in `flags` — add them to `coatts_exclude_flags` for a stricter screen.
- **Seasonality.** Surface and column formaldehyde both peak in summer, so
  whole-year correlations partly reflect the shared seasonal cycle.
  `stats_within_month_anomalies.csv` / `fig6` remove site-month means; the
  month-effects mixed model (`mixed_model_month_effects.csv`) does the same in a
  regression. RMA slopes are left blank when the correlation is not significant.
- **Reporting conditions.** Surface concentrations are assumed to be at local
  temperature and pressure (the convention for AQS air toxics). If CDPHE reports
  at standard conditions (25 °C, 1 atm), surface number densities are ~15 % too
  high and `h_eff_km` ~15 % too low at Front Range elevations.
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
