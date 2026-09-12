# Step 10 (AQS inventory) — three small edits

Save `10_aqs_inventory.R` into `~/HCHO/R/`, then make these three edits.

## 1. `R/00_config.R` — add a path

In the `P <- list(` block, after `raw_hms = "data/raw/hms_smoke",` add:

```r
  raw_aqs      = "data/raw/aqs",
```

## 2. `R/00_config.R` — add settings

In the `CFG <- list(` block, just before the `# ---- diagnostics (step 09)` comment, add:

```r
  # ---- national arm: EPA AQS formaldehyde (NATTS / NCore / PAMS) ----
  # Step 10 inventories what AQS holds; sites are then matched to TEMPO like
  # the Colorado sites. AirData files need no key; sample-level records (the
  # start time of each sample) come from the AQS API and need AQS_EMAIL/AQS_KEY.
  run_aqs_inventory = TRUE,
  aqs_base_url = "https://aqs.epa.gov/aqsweb/airdata/",
  aqs_param_hcho = "43502",                  # AQS parameter code for formaldehyde
  aqs_years = c(2024L, 2025L),
  aqs_refresh = FALSE,                       # TRUE re-downloads the AirData files
  aqs_durations = c("24 h", "8 h", "3 h", "1 h"),
  aqs_min_samples = 20L,                     # per site over aqs_years, to be a candidate
  aqs_conus_bbox = c(-125, 24, -66, 50),     # lon_min, lat_min, lon_max, lat_max
  # sample-level check of the time stamps at Littleton and Platteville
  aqs_sites_of_interest = c("08-035-0004", "08-123-0008"),
```

## 3. `run_all.R` — add the step (optional)

Next to the other `add(...)` lines:

```r
  add("R/10_aqs_inventory.R",   "coatts", isTRUE(cfg_env$CFG$run_aqs_inventory))
```

and above it, with the other flags:

```r
  aqs     <- isTRUE(cfg_env$CFG$run_aqs_inventory)
```

(then use `aqs` in the `add` call instead of the `isTRUE(...)` expression, if you prefer).

## Run it on its own

```sh
cd ~/HCHO
Rscript -e 'source("R/10_aqs_inventory.R")'
```

It downloads three AirData files (roughly 50–100 MB total, cached in
`data/raw/aqs`) and writes:

- `output/tables/aqs_hcho_summary.csv` — sites by sample duration and network
- `output/tables/aqs_hcho_inventory.csv` — every formaldehyde monitor, 2024–2025
- `data/processed/aqs_candidate_sites.csv` — the sites that pass the filters

## Optional: AQS API key (worth doing)

One-time signup, from R:

```r
browseURL("https://aqs.epa.gov/data/api/signup?email=YOUR@EMAIL")
```

The key arrives by email. Then add to `~/.Renviron` (and restart R):

```
AQS_EMAIL=YOUR@EMAIL
AQS_KEY=thekeyfromtheemail
```

With the key set, step 10 also pulls the sample-level records for Littleton and
Platteville. AQS records the time each sample began, so this may answer the
09:00 start-or-end question without waiting for CDPHE.
