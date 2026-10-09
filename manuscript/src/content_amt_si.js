// content_amt_si.js - the supplement source (Copernicus).
//
// Short methods (S1-S6) and the display items. Figures and tables are numbered
// in order of first citation in the main text (check_amt.js verifies this).
// Tables S1, S5, S6 and S7 are literal rows verified by check_amt.js; Tables S2,
// S3, S4 and S8-S11 are rendered from the CSVs of steps 13, 19, 20 and 22 by
// tables_amt.js.
module.exports = {
  "title": "Supplement of Hourly Satellite Formaldehyde Columns and Routine Surface Air Toxics Monitoring: Day-to-Day Agreement at 123 United States Sites",
  "abstract": [],
  "sections": [
    {
      "h1": "S1. Colorado sites and samples",
      "p": [
        "CDPHE's Colorado Air Toxics Trends (COATTS) network became fully operational in two phases, on 1 January 2024 and 1 July 2025{{cdpherepo2026}}, and Wheat Ridge began sampling in October 2025; formaldehyde is one of its priority toxic air contaminants{{cdphetac2026}}. All seven COATTS sites collect 24 h integrated samples, from 00:00 to 24:00 local standard time, on a 1-in-6-day schedule, using DNPH-coated silica cartridges with a potassium iodide ozone scrubber followed by HPLC with ultraviolet detection, consistent with Compendium Method TO-11A{{epato11a1999}}; Grand Junction (08-077-0018) is also a National Air Toxics Trends Station{{epanatts2025}}. Two ozone-precursor (COOPs) sites, Chatfield State Park and Platteville, report 3 h samples beginning at 06:00 MST. AQS records local standard time, so this window is the same in summer and winter.",
        "Surface HCHO for all nine sites comes from AQS{{epaaqs2026}} and was screened as in the national analysis: records with a null-data qualifier were excluded, other qualifiers were retained, and duplicate records of one sampling window were averaged. This left 453 valid 24 h samples and 234 3 h samples, 115 at Chatfield State Park (February 2024–December 2025) and 119 at Platteville (August 2023–July 2025). Sites, periods and counts are in Table S1, and their locations in Fig. S1."
      ]
    },
    {
      "h1": "S2. TEMPO extraction and matching",
      "p": [
        "TEMPO scans North America from east to west about once an hour in daylight{{zoogman2017}}. Level 3 files place each scan's Level 2 retrievals on a 0.02° grid by area weighting and carry the HCHO vertical column and its uncertainty, the main data-quality flag, effective cloud fraction, snow and ice fraction, solar zenith angle and, from version 4, a planetary boundary-layer height from the GEOS-CF version 2 model that is not used in the retrieval{{nasaguide2025}}; we treat that height as an auxiliary model quantity and compare it with HRRR in Table S3 and Fig. S4.",
        "For the Colorado sites, granules found through NASA's Common Metadata Repository were assigned to a sample when the midpoint of the granule's time coverage fell in the sampling period: 1582 granules on 146 of 151 24 h sampling dates, and for the 3 h sites 988 granules between 03:00 and 19:00 MST on 146 of 153 dates. Nationally, the 123 sites were grouped into {{n:n_clusters}} clusters no larger than 1.25° latitude by 2.5° longitude, one OPeNDAP subset was requested per cluster and scan, and the 5 × 5 cell block around each site was extracted locally ({{n:n_cluster_scans}} cluster-scans with data, {{n:n_cell_records_million}} million cell records). Only the scans a sample needs were requested: its sampling day for a 24 h sample, and its window plus 3 h on either side for a sub-daily sample. National samples are matched to scans by UTC hour; the one window that does not begin on the hour, an 8 h sample at Los Angeles-North Main Street beginning at 08:15, is assigned to the hour it begins in. Lags of ±3 h are applied only to sub-daily samples, and the +6 and +9 h lags only at the Colorado 3 h sites. Granules were retrieved in September 2026, after version 4 had been back-processed over the whole record; on the 2024–2025 days on which no granule covered any monitor, neither version 3 nor version 4 holds data (checked against the Common Metadata Repository in October 2026), so these are gaps in TEMPO observations."
      ]
    },
    {
      "h1": "S3. Statistics",
      "p": [
        "Slopes are reduced major axis (RMA) slopes, because both measurements carry error. Confidence intervals are bootstrap percentile intervals: 1000 replicates unless stated; 200 for the national site-, state- and smoke-class breakdowns; and 2000 for the Williams'-test differences, the mixing-depth tertile contrasts, the dual-duration summaries, the observability differences and the seasonal pooled correlations. Pooled analyses resample whole sites, so that the samples of one monitor stay together; with fewer than five sites individual samples are resampled and the interval is marked descriptive. The sign of an RMA slope is unstable when r is near zero, so scatter plots of surface HCHO against the column show a fitted line only where the Pearson correlation is significant (p < 0.05); the least-squares lines of Figs. S5b and S6b and the loess curves of Fig. S8 are drawn in every panel, for illustration.",
        "Anomaly correlations are tested by permutation, because the site-month means are estimated from the same samples and the parametric p-value is too small: one variable is permuted within each site × year-month stratum, which leaves the removed means unchanged, and the observed |r| is compared with 2000 permuted values (smallest attainable p, 1/2001 = 0.0005). Whole-period correlations and regressions use their usual parametric tests. A difference between two correlations sharing the surface measurement carries a bootstrap interval and two-sided percentile-bootstrap p-value (2000 replicates): for anomaly correlations the bootstrap resamples whole site-months at a single site and whole sites when sites are pooled, so that every resampled stratum keeps the samples its anomalies were formed from. Williams' test{{steiger1980}}, which treats the pairs as independent, is reported alongside as an approximate check. Column coefficients come from ordinary least squares with fixed effects for site and calendar month; nationally their standard errors are clustered by site, while the two Colorado 3 h sites are too few to cluster (Table S9). Site-level significance counts are given with a Benjamini–Hochberg false-discovery-rate correction (Table S2).",
        "For 8 h and 3 h samples a site-month mixes sampling windows, so an anomaly can retain systematic differences between times of day. Computing the anomalies within site, month and start hour instead gave r = 0.38 at the 8 h sites (n = 3483, 477 strata) and r = 0.33 at the 3 h sites (n = 369, 56 strata), both with permutation p = 0.0005, against 0.38 and 0.39 with the windows pooled (Table 1). At the 8 h sites, which sample every block on every sampling day, the two agree; at the 3 h sites pooling adds 0.06 from systematic diurnal differences. Table 1 reports the pooled values.",
        "The product uncertainty of a scan's block is the root mean square of its passing cells' uncertainties, the fully correlated limit; the empirical estimator of Sect. S4 is used for the agreement analysis instead. Terrain heterogeneity is indexed by the spread of TEMPO surface pressure across a block of grid cells, because the surface pressure supplied with each cell follows that cell's terrain: at the Colorado sites as the pressure range within the block (Sect. S6), and nationally as the height difference implied by the highest and lowest surface pressure in the 5 × 5 block, H ln(p_{max}/p_{min}) with H = {{n:geo_scale_h_km}} km, taken as the median over scans (main text Sect. 2.3.2). The synoptic pressure gradient across a block, of order 0.1 hPa, is small beside these differences. Distance to the coast is the geodesic distance from a monitor to the nearest Atlantic, Pacific or Gulf of Mexico feature of the U.S. Census TIGER/Line coastline file{{censuscoast2023}}; Great Lakes shorelines are not counted as coast."
      ]
    },
    {
      "h1": "S4. Retrieval-noise estimator",
      "p": [
        "Retrieval noise is estimated from pairs of successive valid scans of the same site on the same day, no more than 1.6 h apart: the root mean square of their differences, divided by √2, is the random error of a single scan. It is an upper bound, because the column can change between scans, and it cannot detect errors that persist through the day. Its square, divided by the number of valid scans in the sample's mean and multiplied by 1 − 1/m for the m samples of the site-month mean that the anomaly removes, is the noise variance of the column anomaly. Its ratio to the observed variance of the column anomalies is the noise fraction, and r_{ceiling} = √(1 − noise fraction) is the correlation expected if retrieval noise were the only source of disagreement.",
        "A site-level ceiling requires at least 20 successive-scan pairs and 10 anomaly pairs. Of the {{n:n_sites_24}} 24 h sites with a site-level correlation, {{n:nat_sites_scored}} have a ceiling (Fig. S6a); at the remaining {{n:nat_sites_ceiling_undefined}} sites the noise variance exceeds the anomaly variance and no ceiling is defined. The uncertainties reported with the product imply much lower ceilings. Pooled over the Colorado sites, they give a ceiling of 0 if the cells of a block are treated as fully correlated and 0.04 if they are treated as independent (0.44 for independent cells if each sample's median rather than mean scan uncertainty is used), against the {{n:noise_ceiling_3x3}} of the empirical estimate and an observed day-to-day correlation of {{n:anom_r_observed_3x3}} (all seven sites; the six in the national comparison give 0.32, main text Sect. 3.2); this is why they are not taken at face value."
      ]
    },
    {
      "h1": "S5. Smoke classification",
      "p": [
        "A sample is smoke-affected when a NOAA Hazard Mapping System (HMS) smoke polygon{{noaahms2026}} covers the site and the polygon's time interval overlaps the sampling window widened by 3 h on each side{{rolph2009}}{{brey2018}}. Polygons are drawn from satellite images taken at a few times a day, so a short window can fall between analysis times while smoke persists; the widening reduces that mismatch. It changed little in Colorado (41 rather than 39 of the 234 3 h samples flagged, and no change for the 453 24 h samples) but more nationally, where strict overlap flags 4899 of 16 383 windows (29.9%) and the widened window 6268 (38.3%); the additional windows are mostly 3 h and 8 h windows that fall between HMS analysis times. All smoke results use the widened window. Each sample takes the class of the densest overlapping polygon (none, light, or medium–heavy); polygons without a density count as light, and a polygon whose times cannot be parsed applies to the whole day. Daily shapefiles were retrieved for all {{n:hms_days_needed}} days that the sampling windows touch."
      ]
    },
    {
      "h1": "S6. Checks at the Colorado sites",
      "p": [
        "Noise ceilings and terrain. With the estimator of Sect. S4 (3 × 3 block), La Salle and Cañon City lie close to their ceilings, with noise-corrected day-to-day correlations of {{n:r_corrected_LSCO}} and {{n:r_corrected_CNCO}}; Commerce City is intermediate ({{n:r_corrected_ADCO}}) and Grand Junction far below ({{n:r_corrected_GPCO}}). Cañon City, Colorado Springs and Pueblo began sampling in July 2025 and have only 20–23 anomaly pairs each; at Colorado Springs and Pueblo the noise-corrected correlations are negative (−0.25 and −0.32), and Wheat Ridge has too few pairs (8) for a ceiling. Terrain does not explain the ordering of the first four sites: the spread of TEMPO surface pressure within the block is smallest at Commerce City (1.8 hPa) and largest at Cañon City (11.5 hPa), the opposite of what a terrain effect would produce. Nationally, by contrast, day-to-day agreement was weaker at monitors with more terrain relief (main text Sect. 3.4, Fig. S8); four Colorado sites are too few to show such a relation.",
        "Midday scans. Restricting TEMPO to 10:00–14:00 MST lowered the pooled whole-period correlation of the 24 h samples at every block size, to 0.38, 0.50 and 0.59 for 1 × 1, 3 × 3 and 5 × 5 blocks from 0.47, 0.56 and 0.61 with all daylight scans, so the all-day mean is the better match to a 24 h sample.",
        "Smoke. Smoke affected 69 of the 453 Colorado 24 h samples (15%). The whole-period correlation was lower on smoke-affected days, 0.46 on smoke-free days (n = 276), 0.36 under light smoke (n = 48) and 0.37 under medium–heavy smoke (n = 14), but excluding smoke days still lowered the day-to-day correlation, from 0.30 to 0.23, as it did nationally. Within season, smoke-affected and smoke-free samples had similar median cloud fractions (summer 0.16 and 0.18, p = 0.52; autumn 0.13 and 0.13, p = 0.82)."
      ]
    },
    {
      "table": {
        "caption": "Table S1. Colorado monitoring sites, periods and sample counts. Matched days are samples with at least one TEMPO scan passing the primary screening. Medians are for all valid samples in each year.",
        "header": [
          "Site (code)",
          "AQS ID",
          "County",
          "Lat (°N)",
          "Lon (°E)",
          "Period",
          "Samples",
          "Matched",
          "Median HCHO (µg m^{−3})"
        ],
        "rows": [
          [
            "24 h COATTS samples",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
          ],
          [
            "Grand Junction (GPCO)",
            "08-077-0018",
            "Mesa",
            "39.064",
            "−108.562",
            "2024–2025",
            "123",
            "105",
            "2.33 (2024), 2.70 (2025)"
          ],
          [
            "Cañon City (CNCO)",
            "08-043-0004",
            "Fremont",
            "38.469",
            "−105.208",
            "Jul–Dec 2025",
            "26",
            "21",
            "1.41"
          ],
          [
            "Wheat Ridge (JFCO)",
            "08-059-0015",
            "Jefferson",
            "39.781",
            "−105.108",
            "Oct–Dec 2025",
            "15",
            "10",
            "2.70"
          ],
          [
            "Commerce City (ADCO)",
            "08-001-0010",
            "Adams",
            "39.828",
            "−104.936",
            "2024–2025",
            "120",
            "84",
            "2.95 (2024), 3.32 (2025)"
          ],
          [
            "Colorado Springs (COCO)",
            "08-041-0017",
            "El Paso",
            "38.848",
            "−104.829",
            "Jul–Dec 2025",
            "29",
            "23",
            "2.46"
          ],
          [
            "La Salle (LSCO)",
            "08-123-0015",
            "Weld",
            "40.261",
            "−104.706",
            "2024–2025",
            "110",
            "70",
            "2.09 (2024), 2.21 (2025)"
          ],
          [
            "Pueblo (POCO)",
            "08-101-0017",
            "Pueblo",
            "38.236",
            "−104.581",
            "Jul–Dec 2025",
            "30",
            "25",
            "2.46"
          ],
          [
            "3 h COOPs ozone-precursor samples",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
          ],
          [
            "Chatfield State Park (CHCO)",
            "08-035-0004",
            "Douglas",
            "39.534",
            "−105.070",
            "Feb 2024–Dec 2025",
            "115",
            "54^{a}",
            "1.96 (2024), 2.95 (2025)"
          ],
          [
            "Platteville (PVCO)",
            "08-123-0008",
            "Weld",
            "40.209",
            "−104.824",
            "Aug 2023–Jul 2025",
            "119",
            "56^{a}",
            "2.58 (2023), 2.70 (2024), 2.95 (2025)"
          ]
        ],
        "notes": "^{a} Matched samples with at least one screened TEMPO scan inside the 06:00–09:00 MST sampling window. Identifiers are AQS site codes. Site names are CDPHE's; AQS records some stations under a different name, Commerce City as Birch Street, Wheat Ridge as Peak Expeditionary School, Pueblo as St. Charles Mesa Water District, Grand Junction as Grand Junction - Pitkin, La Salle as La Salle Tower, Cañon City as Canon City - Harrison School, Colorado Springs as Colorado Springs - College College, and Platteville as Platteville - Middle School."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S2. Site-level correlations reaching nominal and false-discovery-rate significance, by sample duration. Counts are over site-duration combinations with at least 10 matched samples and 10 anomaly pairs, at the primary screening and with scans inside the sampling window. The Benjamini-Hochberg correction is applied across all site-duration tests in each family (the All row). Whole-period counts use the ordinary correlation test; day-to-day counts use the within-site-month permutation test (Sect. S3), which is the stricter of the two – the ordinary test applied to the same anomalies would give {{n:sig_dd_ord_nominal}} and {{n:sig_dd_ord_bh}} rather than {{n:sig_dd_perm_nominal}} and {{n:sig_dd_perm_bh}}. These counts are reported for completeness; the distribution of the correlations themselves is more informative, and no conclusion in the paper depends on a count.",
        "builder": "siteSignificance"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S3. The HRRR meteorology compared with the meteorology supplied with the TEMPO retrieval. The arms are the national comparison and the Colorado 24 h and 3 h analyses. The difference is the median of the paired differences (TEMPO minus HRRR) and need not equal the difference of the two medians. HRRR pressure and boundary-layer depth are averaged over the UTC hours in which each sample's valid TEMPO scans fell; the last row repeats the all-arms comparison with HRRR averaged over the whole sampling window instead, which is not like-for-like because TEMPO observes only in daylight while a 24 h window is half night. Nationally the boundary-layer difference grows from {{n:met_pbl_nat_djf_diff}} m in winter to {{n:met_pbl_nat_son_diff}} m in autumn. The all-arms rows count each sample once: samples at the six Colorado 24 h sites in the national arm and the 2024–2025 samples at Chatfield and Platteville belong to both a Colorado arm and the national arm.",
        "builder": "metComparison"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S4. Agreement by season (main text, Sect. 3.1). Seasons are those of the sampling date. n and Sites are usable matched samples and monitors in the season (primary screening, scans inside the sampling window). Pooled r carries a site-clustered bootstrap 95% interval (2000 replicates). Day-to-day r is the within-month anomaly correlation, with the number of anomaly pairs and the within-site-month permutation p-value (the smallest attainable is 0.0005). Across sites r relates site-season mean column and surface concentration over 24 h sites with at least {{n:seas_min_samples}} matched samples in the season, with the number of sites and the ordinary p-value. The 8 h samples are almost all from summer ({{n:seas_n_8_jja}} of {{n:seas_n_8_total}}) and are not interpreted by season.",
        "builder": "seasonal",
        "notes": "^{a} Fewer than five sites: the interval is a row bootstrap and descriptive only."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S5. The temporal-averaging experiment of Fig. 3 for each spatial block: {{n:ta_samples}} 24 h samples with at least four valid scans in every block, {{n:ta_draws}} random draws per k, {{n:ta_pairs}} anomaly pairs in all; the site median is over the {{n:ta_sites}} sites with at least 10 pairs. The last row of each block is the single-scan noise implied by the slope of the column-anomaly variance against 1/k (R^{2} > 0.99), to be compared with the site medians of the scan-difference estimator: {{n:nc_single_median_11}}, {{n:nc_single_median_33}} and {{n:nc_single_median_55}} × 10^{15} molecules cm^{−2}.",
        "builder": "temporalAveraging"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S6. Weighted least-squares models of the Fisher-transformed observed within-month correlation (M1) and of the noise-corrected ratio E = r_{obs}/r_{ceiling} (M2, M3) at the {{n:gap_sites}} 24 h sites with a retrieval-noise ceiling. Predictors are standardized (coefficients are per standard deviation, standard errors in parentheses), weights are n − 3, with n the number of anomaly pairs, and the six descriptors were fixed in advance. Usable share is the percentage of all samples with at least one usable scan. E is capped at 0.999 before transformation. Univariate Spearman correlations are in output/tables/diag8_ceiling_gap_univariate.csv of the code archive, and the models that add the three geographic descriptors of main text Sect. 3.4 (west of {{n:geo_west_lon}}° W, distance to the ocean coastline and terrain relief) are in output/tables/geography_models.csv.",
        "builder": "ceilingGapModels"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S7. Agreement between surface HCHO and the TEMPO column by HMS smoke class over the site during the sampling window widened by 3 h on each side (Sect. S5), for every duration in the national comparison, at the primary screening with scans inside the sampling window. Medians are over matched samples. The 3 h smoke classes hold too few samples to interpret.",
        "header": [
          "Duration",
          "Smoke class",
          "Matched samples",
          "Pearson r",
          "Surface HCHO (µg m^{−3})",
          "Column (10^{15} molecules cm^{−2})",
          "H_{eff} (km)"
        ],
        "rows": [
          [
            "24 h",
            "none",
            "3950",
            "0.29",
            "2.09",
            "4.07",
            "0.93"
          ],
          [
            "24 h",
            "light",
            "1854",
            "0.38",
            "3.19",
            "8.83",
            "1.39"
          ],
          [
            "24 h",
            "medium–heavy",
            "302",
            "0.47",
            "3.41",
            "8.52",
            "1.32"
          ],
          [
            "8 h",
            "none",
            "1675",
            "0.22",
            "3.93",
            "9.08",
            "1.24"
          ],
          [
            "8 h",
            "light",
            "1599",
            "0.42",
            "4.42",
            "12.07",
            "1.38"
          ],
          [
            "8 h",
            "medium–heavy",
            "235",
            "0.49",
            "4.18",
            "11.11",
            "1.34"
          ],
          [
            "3 h",
            "none",
            "295",
            "0.47",
            "3.81",
            "8.20",
            "1.02"
          ],
          [
            "3 h",
            "light",
            "95",
            "0.34",
            "4.05",
            "10.98",
            "1.22"
          ],
          [
            "3 h",
            "medium–heavy",
            "12",
            "0.70",
            "3.93",
            "9.82",
            "1.06"
          ]
        ],
        "notes": "Smoke-affected samples nationally: {{n:smoke_n_affected}} of 10,017 matched samples carrying a classification. Excluding them leaves 2645 of 5218 anomaly pairs at the 24 h sites and 1610 of 3509 at the 8 h sites."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S8. The {{n:dd_sites_total}} monitors reporting both 24 h and 8 h formaldehyde. n and r are the number of within-month anomaly pairs and their correlation (primary screening, 3 × 3 block, scans inside the sampling window); r_{8h} 04:00 and 12:00 use anomalies computed within site, month and start hour; the last two correlations pair the 24 h surface sample with the mean of only those scans falling in the hours of each 8 h block. Usable share is the percentage of samples with TEMPO coverage that had at least one usable scan; scans is the median number of valid scans per usable sample. Two sites have too few 24 h anomaly pairs for a correlation. Paired summaries, including the comparison restricted to the months of the 8 h record, are in output/tables/diag7_dual_duration_paired.csv of the code archive (see Code and data availability).",
        "builder": "dualDurationSites"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S9. Comparison of 3 h surface HCHO at the two Colorado sites (Chatfield 2024–2025, Platteville August 2023–July 2025) with the mean of valid TEMPO scans in the sampling window (06:00–09:00 MST) and in windows shifted 3 and 6 h later (primary screening, 3 × 3 cells).",
        "header": [
          "",
          "Sampling window (06–09 MST)",
          "+3 h (09–12 MST)",
          "+6 h (12–15 MST)"
        ],
        "rows": [
          [
            "Matched samples, Chatfield State Park",
            "54 of 115 (47%)",
            "72 of 115 (63%)",
            "52 of 115 (45%)"
          ],
          [
            "Matched samples, Platteville",
            "56 of 119 (47%)",
            "72 of 119 (61%)",
            "64 of 119 (54%)"
          ],
          [
            "Median TEMPO scans per window (all samples, before screening)",
            "2",
            "3",
            "1"
          ],
          [
            "Pearson r, both sites",
            "0.36 (n = 110, p < 0.001)",
            "0.49 (n = 144, p < 0.001)",
            "0.18 (n = 116, p = 0.048)"
          ],
          [
            "Pearson r, Chatfield State Park",
            "0.24 (n = 54, p = 0.08)",
            "0.56 (n = 72, p < 0.001)",
            "0.11 (n = 52, p = 0.44)"
          ],
          [
            "Pearson r, Platteville",
            "0.48 (n = 56, p < 0.001)",
            "0.36 (n = 72, p = 0.002)",
            "0.24 (n = 64, p = 0.06)"
          ],
          [
            "Within-month anomaly r, both sites",
            "0.12 (n = 90, p = 0.26)",
            "0.31 (n = 128, p = 0.0005)",
            "0.06 (n = 85, p = 0.62)"
          ],
          [
            "Within-month anomaly r, Chatfield State Park",
            "-0.01 (n = 47, p = 0.93)",
            "0.48 (n = 64, p = 0.001)",
            "0.18 (n = 34, p = 0.40)"
          ],
          [
            "Within-month anomaly r, Platteville",
            "0.24 (n = 43, p = 0.16)",
            "0.15 (n = 64, p = 0.26)",
            "-0.01 (n = 51, p = 0.97)"
          ],
          [
            "Column coefficient with site and month effects",
            "0.035 ± 0.036 (p = 0.33)",
            "0.121 ± 0.036 (p = 0.001)",
            "-0.011 ± 0.029 (p = 0.71)"
          ],
          [
            "Median H_{eff} / median TEMPO PBL height (km)",
            "0.98 / 0.45",
            "0.93 / 1.50",
            "0.92 / 2.21"
          ]
        ],
        "notes": "Anomaly p-values are within-site-month permutation values (Sect. S3); the smallest attainable is 0.0005. The column coefficient's ± is its ordinary standard error: two sites are too few to cluster by site, unlike Table 1. Whole-period p-values are from the ordinary parametric test. In the sampling window 36% of grid cells failed the solar-zenith-angle screen, against 4% in 09:00–12:00 MST, and in winter (December–February) no scan in the sampling window passed screening at either site. The −3 h window (03–06 MST) contained no usable scans; the +9 h window (15–18 MST) yielded seven Platteville samples and is not shown. The column coefficient is in µg m^{−3} per 10^{15} molecules cm^{−2}."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S10. Does the 2023 extension create the difference between the two sites? Both 3 h sites were recomputed on 2024–2025 alone, besides the record as analyzed. Chatfield State Park reported no 2023 formaldehyde, so its values are identical in the two periods and are given once.",
        "header": [
          "",
          "Sampling window (06–09 MST)",
          "+3 h (09–12 MST)",
          "+6 h (12–15 MST)"
        ],
        "rows": [
          [
            "Platteville, whole-period r, 2024–2025 only",
            "0.54 (n = 44)",
            "0.46 (n = 56)",
            "0.25 (n = 51)"
          ],
          [
            "Platteville, whole-period r, with 2023",
            "0.48 (n = 56)",
            "0.36 (n = 72)",
            "0.24 (n = 64)"
          ],
          [
            "Platteville, anomaly r, 2024–2025 only",
            "0.25 (n = 32, p = 0.23)",
            "0.26 (n = 51, p = 0.07)",
            "-0.09 (n = 40, p = 0.60)"
          ],
          [
            "Platteville, anomaly r, with 2023",
            "0.24 (n = 43, p = 0.16)",
            "0.15 (n = 64, p = 0.26)",
            "-0.01 (n = 51, p = 0.97)"
          ],
          [
            "Chatfield State Park, anomaly r (no 2023 record)",
            "-0.01 (n = 47, p = 0.93)",
            "0.48 (n = 64, p = 0.001)",
            "0.18 (n = 34, p = 0.40)"
          ]
        ],
        "notes": "Anomaly p-values are within-site-month permutation values (Sect. S3). The later window has no advantage at Platteville in either period, which is the claim made in the text; the apparent preference for the sampling window in the anomaly correlations appears only once 2023 is included (the whole-period correlations favour it in both periods), and no Platteville anomaly correlation is significant in either period."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S11. Within-month anomaly correlation by tertile of the HRRR mixing depth averaged over the sampling window. The anomalies, and the mixing-depth anomaly used for the relative tertiles, are deviations from the site-month mean (for 8 h samples, the site-month-start-hour mean); tertile boundaries are then set over all samples of that 8 h block (or all 24 h samples). On smoke-free days all three anomalies are recomputed from the smoke-free samples alone (site-months with at least three). The difference between the deepest and shallowest tertile carries a site-clustered bootstrap interval (2000 replicates). The interaction rows give the coefficient of column anomaly × mixing-depth anomaly (both standardized) in a regression of the surface anomaly, with site-clustered standard errors; for 24 h samples the window-mean mixing depth includes the night, which is expected to weaken the contrast. The adjusted version also lets the column slope depend on the number of valid scans and on the site-month column level.",
        "builder": "pblTertiles"
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig0_site_map.png",
        "caption": "Figure S1. The Colorado sites: seven COATTS sites sampling 24 h integrated formaldehyde (circles) and two COOPs sites sampling 3 h integrated formaldehyde (triangles), over terrain and county boundaries. Inset: the 123 sites across the contiguous United States that reported formaldehyde to AQS in 2024–2025, colored by sample duration, with Colorado outlined. Elevation is from the AWS Terrain Tiles{{aws}}, retrieved with the elevatr package{{hollister2023}}; boundaries are US Census cartographic boundary files{{census2023}}."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig16_national_screening_sensitivity.png",
        "caption": "Figure S2. Pooled Spearman correlation between surface HCHO and the mean TEMPO column at every site in the comparison, as a function of the maximum effective cloud fraction and the averaging block (1 × 1, 3 × 3 or 5 × 5 cells), for scans inside the sampling window. Panels are sample duration; symbol size is the number of matched samples. The primary screening used throughout is a cloud fraction of 0.2 with a 3 × 3 block; the product user guide recommends 0.1 for the highest-quality retrievals (main text Sect. 2.2). The Pearson values quoted in the text follow the same ordering."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig8_threeh_sensitivity.png",
        "caption": "Figure S3. Pooled Spearman correlation between 3 h surface HCHO and the window-mean TEMPO column as a function of the maximum effective cloud fraction and the averaging block, for each lag from the sampling window, at the two Colorado 3 h sites (Chatfield State Park and Platteville). Symbol size shows the number of matched samples; the +9 h panel rests on ten samples or fewer."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig19_met_comparison.png",
        "caption": "Figure S4. The HRRR meteorology used for the number density, compared with the meteorology supplied with the TEMPO retrieval, over the matched samples of all three arms ({{n:met_press_n}} distinct samples; those at the six Colorado 24 h sites in the national arm and the 2024–2025 samples at Chatfield and Platteville belong to two arms and are drawn twice). (a) Surface pressure, HRRR (averaged over the same scan hours as in b) against the value supplied with the retrieval. (b) Boundary-layer depth, HRRR against the GEOS-CF height supplied with the retrieval; both are averaged over the UTC hours in which that sample’s valid TEMPO scans fell, so the two are sampled at the same times. Colors denote the arm. The line is 1:1."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig24_seasonal.png",
        "caption": "Figure S5. Agreement by season (main text, Sect. 3.1). (a) Pooled (whole-period, with site-clustered 95% intervals) and day-to-day (within-month anomaly) correlation between surface HCHO and the TEMPO column for 24 h samples; labels give samples or anomaly pairs. (b) Site-season mean surface HCHO against site-season mean column for 24 h sites with at least {{n:seas_min_samples}} matched samples in the season, with the across-site correlation and number of sites; lines are least-squares fits, drawn in every season including winter, where the correlation is not significant."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig21_ceiling_gap.png",
        "caption": "Figure S6. (a) Observed within-month anomaly correlation at each of the {{n:gap_sites}} 24 h sites with a retrieval-noise ceiling (at least 20 successive-scan pairs and 10 anomaly pairs; 3 × 3 block), against that ceiling. The dashed line is equality (E = 1), where agreement would be limited only by retrieval noise, and the dotted line is half the ceiling. Color is the site's median surface HCHO (logarithmic scale). The {{n:nat_sites_ceiling_undefined}} sites at which the noise bound exceeded the anomaly variance have no ceiling and are not shown. (b) The noise-corrected ratio E = r_{obs}/r_{ceiling} against the six site descriptors of Table S6, on their natural scales, with unweighted least-squares fits and their 95% confidence bands drawn in every panel for illustration; the dashed line is E = 1. The Table S6 models are weighted and use the logarithms of surface HCHO, signal-to-noise ratio and scan count."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig17_national_smoke.png",
        "caption": "Figure S7. Pearson correlation between surface HCHO and the TEMPO column by HMS smoke class over the site during the sampling window widened by 3 h on each side (Sect. S5), for the 24 h, 8 h and 3 h sites nationally. Labels are the number of matched samples. Agreement rises with smoke at both well-sampled durations; the 3 h record, with 95 light and 12 medium–heavy samples, is not interpreted."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig25_geography.png",
        "caption": "Figure S8. Within-month anomaly correlation at each of the {{n:geo_sites}} 24 h monitors with a site-level correlation against (a) longitude, (b) geodesic distance to the ocean coastline (Atlantic, Pacific and Gulf of Mexico features of the U.S. Census TIGER/Line coastline file; {{~censuscoast2023}}) and (c) terrain relief across the 5 × 5 block of TEMPO grid cells around the monitor, computed from the TEMPO surface pressure of each cell (main text, Sect. 2.3.2). Orange symbols are monitors within {{n:geo_coast_km}} km of the ocean coastline and blue symbols inland monitors; symbol size is the number of anomaly pairs. The dashed line in (a) marks {{n:geo_west_lon}}° W, and the grey curves are loess fits shown for guidance only. Distance and relief are on logarithmic axes."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig20_dual_duration.png",
        "caption": "Figure S9. Within-month anomaly correlation between surface HCHO and the TEMPO column at the {{n:dd_sites_paired}} monitors with at least {{n:dd_min_pairs}} anomaly pairs in both their 24 h and their 8 h record (primary screening, scans inside the sampling window). Symbol size is the smaller of the two pair counts; the dashed line is equality."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig11_national_lag_curve.png",
        "caption": "Figure S10. Pooled correlation between sub-daily surface HCHO and the mean TEMPO column as a function of the lag of the TEMPO window from the sampling window, for the 3 h and 8 h sites. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site-month means. Labels give the number of samples in each series; the anomaly series can have fewer because site-months with fewer than three samples are dropped. At −3 h the 3 h series holds only the California sites, because no Colorado scan passed screening in that window. Because the sites pooled here sample different windows, a given lag corresponds to different times of day at different sites, which is why the main text reports agreement by window start hour instead."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig12_national_by_start_hour.png",
        "caption": "Figure S11. Correlation between sub-daily surface HCHO and the mean TEMPO column, grouped by the local standard hour at which the sampling window begins, using only scans inside the sampling window. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site-month means computed within each start hour. In the 3 h panel, the windows beginning at 05:00, 12:00 and 16:00 are the two California sites and the window beginning at 06:00 is the two Colorado sites (not joined to the California points); in the 8 h panel each point pools all 40 sites. Start hours with fewer than 12 usable samples or fewer than six anomaly pairs are not shown: in the 8 h panel the dark 20:00 LST block and the off-schedule blocks used briefly at five sites, and in the 3 h panel the dark 23:00 windows and the 08:00 windows (14 usable samples, too few anomaly pairs). Labels give the number of samples in each series; the anomaly series can have fewer because site-months with fewer than three samples are dropped."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig7_threeh_scatter.png",
        "caption": "Figure S12. Three-hour surface HCHO at Chatfield State Park (CHCO, 2024–2025) and Platteville (PVCO, August 2023–July 2025) versus the mean TEMPO column in the sampling window (06:00–09:00 MST) and in windows shifted by +3, +6 and +9 h. The −3 h window is not shown because no scan passed screening in it, and the +9 h row holds only seven Platteville samples. Colors denote season; lines show reduced major axis fits where the Pearson correlation is significant."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig10_threeh_lag_curve.png",
        "caption": "Figure S13. Agreement between 3 h surface HCHO and the mean TEMPO column as a function of the lag between the sampling window (06:00–09:00 MST) and the satellite window, for the whole period and for within-month anomalies. Labels give the number of samples in each series; the +9 h point (15:00–18:00 MST) is seven Platteville samples, which Table S9 omits. Agreement is highest in the window beginning when sampling ends (09:00–12:00 MST), when the median TEMPO boundary layer height has risen from 0.45 to 1.5 km; the pooled curve averages two sites that differ (Table S9)."
      },
      "p": []
    },
    {
      "fig": {
        "file": "figS3_threeh_window_columns.png",
        "caption": "Figure S14. TEMPO columns for the same 3 h samples, measured in the sampling window (06:00–09:00 MST) and three hours later. These are the samples usable in both windows (50 at Chatfield State Park and 52 at Platteville; 42 and 38 anomaly pairs in site-months with at least three such samples), on which the paired comparison of the main text is made: the anomaly correlation with surface HCHO rises from −0.16 in the sampling window to 0.41 three hours later at Chatfield (an increase of {{n:win_chco_diff}}; 95% CI: {{n:win_chco_lo}}, {{n:win_chco_hi}}), from 0.17 to 0.24 at Platteville ({{n:win_pvco_diff}}; {{n:win_pvco_lo}}, {{n:win_pvco_hi}}), and from 0.02 to 0.31 with both sites pooled ({{n:win_all_diff}}; {{n:win_all_lo}}, {{n:win_all_hi}}; intervals resample whole site-months), the pooled value being descriptive because the two sites behave differently. The two columns are only weakly correlated at Chatfield (r = 0.27 over the whole period, 0.01 for within-month anomalies) and more closely at Platteville (0.61 and 0.31); colors denote season; the dashed line is 1:1."
      },
      "p": []
    }
  ],
  "authors": [
    "[[Author list to match the main text; Correspondence to: ...]]"
  ]
};
