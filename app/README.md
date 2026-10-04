# TEMPO formaldehyde and surface air toxics: an interactive explorer

A Shiny app for exploring, monitor by monitor, how TEMPO formaldehyde columns
track surface formaldehyde, and the full CDPHE air-toxics record at the nine
Colorado sites.

* **Map.** All 123 national AQS formaldehyde monitors plus Wheat Ridge. Each is
  coloured by the day-to-day correlation of its longest-duration record with
  TEMPO. The nine Colorado sites with CDPHE air-toxics data have a black outline.
  Click a monitor to select it.
* **TEMPO vs surface HCHO.**
  * For the selected site, choose the data set (national comparison or the
    Colorado analysis), the sample duration and the TEMPO window (lag).
  * Filter by smoke and season.
  * The tab shows a time series, the whole-period and day-to-day scatter plots
    with their correlations, and surface HCHO on observable versus
    screened-out days.
* **Air toxics (Colorado sites).**
  * Every carbonyl, VOC, PAH and metal at the COATTS sites, and carbonyls,
    SNMOC and methane at the COOPs ozone-precursor sites.
  * Each pollutant has a time series (non-detects drawn at the detection
    limit), its seasonal distribution, a comparison across the Colorado sites,
    and a summary table for the pollutant group.

## Rebuild the data

The app reads `appdata/app_data.rds`. Step 24 of the pipeline writes that file
from:

* the released dataset (`dataset/`, step 23);
* the CDPHE annual packets (step 01).

From the project root:

```
Rscript R/24_app_data.R        # also writes app/manifest.json
Rscript app/tests/test_app.R   # computes every output for a set of sites
```

Step 24 stops if `app/R/stats.R`, the code that computes the correlations the
app shows, does not reproduce the correlation of every site in the paper's site
table (`output/tables/national_stats_by_site.csv`).

To run the app locally: `shiny::runApp("app")`.

## Deploy to Posit Connect Cloud

1. Commit and push `app/` to GitHub. That includes `app/appdata/app_data.rds`
   and `app/manifest.json`.
2. In Connect Cloud, choose **Publish** → **Shiny**. Then:
   * Repository: `pdez90/coatts_hcho`.
   * Branch: `main`.
   * Primary file: `app/app.R`.
3. Turn on automatic republishing so that every push to `main` redeploys the app.

Connect Cloud installs the packages listed in `manifest.json`. If you update
packages, rerun step 24 so the manifest records the new versions.
