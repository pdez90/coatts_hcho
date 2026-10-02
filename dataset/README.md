# Matched surface formaldehyde and TEMPO HCHO dataset

Written by `R/23_export_dataset.R` (run by `run_all.R`); do not edit by hand.
Every value is copied from the pipeline's processed files, so re-running the
pipeline reproduces these files byte for byte.

Each row is one surface formaldehyde sample matched to TEMPO HCHO vertical
columns under one screening variant and one time lag, with HRRR meteorology
and NOAA HMS smoke flags. Columns are described in `data_dictionary.csv`.

| File | Contents | Rows |
|---|---|---|
| `matched_primary.csv.gz` | Primary screening: max_ecf = 0.2, 3x3 block, scans in the sampling window; every lag | 33,312 |
| `matched_all_variants.csv.gz` | Every variant: max_ecf 0.1/0.2/0.3 x block 1x1/3x3/5x5 x lag (and the Colorado 24 h midday window) | 303,885 |
| `data_dictionary.csv` | One row per column: units and definition | |

The main analyses use `matched_primary.csv.gz` with `lag_h` = 0 and `usable` = TRUE:

| Arm | Samples | Usable | Sites | Sample dates |
|---|---|---|---|---|
| national | 16,383 | 10,017 | 123 | 2024-01-01 to 2025-12-31 |
| colorado_24h | 453 | 338 | 7 | 2024-01-01 to 2025-12-30 |
| colorado_3h | 234 | 110 | 2 | 2023-08-04 to 2025-12-27 |

Notes

- The national arm includes the Colorado monitors, so a Colorado sample can
  appear in both a Colorado arm and the national arm (same `site_id` and
  `start_utc`).
- `usable` = FALSE rows (no TEMPO column passing the screen) are kept, so
  observability can be studied; the TEMPO columns are blank on those rows.
- Blank fields are missing values.
- Surface concentrations are at 25 C and 1 atm as reported to AQS;
  `hcho_molec_cm3` is at the HRRR temperature and pressure of the window.

Sources: U.S. EPA Air Quality System (surface formaldehyde); NASA TEMPO
Level 3 V04 HCHO (https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004); NOAA
HRRR analyses (NOAA Open Data Dissemination archive on AWS); NOAA Hazard
Mapping System smoke polygons. Code: https://github.com/pdez90/coatts_hcho.
