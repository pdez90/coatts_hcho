// content_amt_si.js - the supplement source (Copernicus).
//
// Regenerated 2026-09-27 from the reviewed TEMPO_HCHO_SI_AMT_v2.docx. Tables
// S1-S6 are literal rows verified by check_amt.js; Tables S7-S10 are rendered
// from the step-20 CSVs by tables_amt.js.
module.exports = {
  "title": "Supplement of Hourly Satellite Formaldehyde Columns and Routine Surface Air Toxics Monitoring: Day-to-Day Agreement at 123 United States Sites",
  "abstract": [],
  "sections": [
    {
      "h1": "S1. The Colorado sites",
      "p": [
        "CDPHE operates the Colorado Air Toxics Trends (COATTS) network. The first phase became fully operational on 1 January 2024 and the second on 1 July 2025{{cdpherepo2026}}. Formaldehyde is one of the priority toxic air contaminants monitored under the program{{cdphetac2026}}. Surface HCHO data for all seven COATTS sites were obtained from AQS, the same source used for the national analysis (Table S1, Fig. S1), while CDPHE’s 2024 and 2025 annual data packets provided the method detection limits.",
        "Commerce City (Adams County), La Salle (Weld County), and Grand Junction (Mesa County) operated throughout 2024 and 2025. Colorado Springs (El Paso County), Pueblo (Pueblo County), and Cañon City (Fremont County) began sampling in July 2025, and Wheat Ridge (Jefferson County) began in October 2025. All seven sites collect 24 h integrated samples on a 1-in-6-day schedule under AQS parameter code 43502. AQS reports HCHO in parts per billion carbon; because formaldehyde contains one carbon atom, this is numerically equivalent to parts per billion by volume. We converted these concentrations to mass units at 25 °C and 1 atm using the same procedure as in the national analysis.",
        "AQS records the start time and duration of each sample. At all seven COATTS sites, samples begin at 00:00 local standard time and run for 24 h, confirming midnight-to-midnight sampling on the recorded date{{epaaqs2026}}. All sites use the same method: DNPH-coated silica cartridges with a potassium iodide ozone scrubber, followed by HPLC with ultraviolet detection, consistent with Compendium Method TO-11A{{epato11a1999}}. Grand Junction (08-077-0018) is also designated by AQS as a National Air Toxics Trends Station{{epanatts2025}}.",
        "Colorado also provides two ozone-precursor sites with shorter sampling windows: Chatfield State Park in Douglas County (CHCO) and Platteville in Weld County (PVCO). These sites were part of CDPHE’s COOPs network, which ended in June 2026, although the historical data remain available. Both report 3 h HCHO samples to AQS beginning at 06:00 MST, giving a fixed sampling window of 06:00–09:00 MST. Platteville reported HCHO on this same schedule beginning in August 2023, so its Colorado-specific record extends back to that month; Chatfield has no 2023 HCHO record in AQS.",
        "The 06:00–09:00 window does not shift with daylight saving time. AQS records sample times in local standard time, and for every Colorado sample in this study, the recorded start time is seven hours behind the corresponding GMT timestamp throughout the year. The Colorado 3 h samples therefore represent the same 06:00–09:00 MST interval in both summer and winter. This consistency is important for the lag analysis in Sect. S8, because otherwise seasonal clock changes could be mistaken for differences in satellite-surface timing."
      ]
    },
    {
      "h1": "S2. Quality control",
      "p": [
        "Surface HCHO concentrations were obtained from AQS and screened using the same criteria as the national dataset. Records with an AQS null-data qualifier were excluded because these qualifiers identify invalid measurements or quality-control/quality-assurance samples. Quality-assurance and informational qualifiers were retained, and duplicate records representing the same sampling window were averaged. Because AQS publishes only ambient measurements, the separate quality-control samples listed in CDPHE’s annual data packets do not appear in the AQS record. After screening, the Colorado 24 h dataset contained 453 valid site-days.",
        "The two 3 h sites were processed in the same way. All AQS samples begin at 06:00 MST, so each corresponds unambiguously to the 06:00–09:00 MST sampling window. The final dataset contains 115 samples from Chatfield State Park (8 February 2024–27 December 2025) and 119 from Platteville (4 August 2023–18 July 2025). Platteville has no later 2025 samples because of sampling problems. All 234 valid 3 h samples were included in the analysis."
      ]
    },
    {
      "h1": "S3. TEMPO extraction and the national comparison",
      "p": [
        "TEMPO is an ultraviolet-visible grating spectrometer in geostationary orbit that scans North America from east to west approximately once per hour during daylight{{zoogman2017}}. Level 3 files place the Level 2 retrievals from each scan onto a regular 0.02° × 0.02° grid using area weighting. Each file includes the HCHO vertical column and its uncertainty, a main data-quality flag, effective cloud fraction, snow and ice fraction, solar zenith angle, and, beginning with version 4, planetary boundary-layer height as supporting information{{nasaguide2025}}. This boundary-layer height comes from the GEOS-CF version 2 model; it is not used in the HCHO retrieval itself and should therefore be interpreted as an auxiliary modeled quantity rather than an observation. We use it only as a diagnostic and compare it with an independent meteorological analysis below."
      ]
    },
    {
      "h2": "S3.1 Near-surface meteorology",
      "p": [
        "Temperature and pressure used to convert surface HCHO to number density were taken from the NOAA High-Resolution Rapid Refresh (HRRR) analysis{{dowell2022}} and averaged over the UTC hours spanned by each surface sample. The same HRRR fields were used at every monitor and for every sampling-duration arm. From each hourly HRRR file, we retrieved only 2 m temperature, surface pressure, and boundary-layer height, using byte-range requests so that the full files did not need to be downloaded.",
        "Figure S4 and Table S3 compare HRRR with the meteorological fields supplied with TEMPO. Surface pressure agrees very closely: across 10,465 matched samples, the median difference is −0.6 hPa (r=0.9995). Boundary-layer height agrees less closely. When both products are averaged over the same TEMPO scan hours, the GEOS-CF boundary layer supplied with TEMPO is a median of 155 m deeper than HRRR (r=0.83). The difference increases from +99 m in winter to +178 m in autumn nationally and reaches +326 m at the Colorado 24 h sites. A comparison between TEMPO’s daylight-only mean and HRRR averaged over the full 24 h sampling window would produce a larger difference (+371 m), but that comparison is not like-for-like because the 24 h HRRR average includes nighttime, when the boundary layer is typically shallower. We therefore use the scan-hour comparison reported in Table S3.",
        "For the Colorado analyses, TEMPO granules were identified through NASA’s Common Metadata Repository and assigned to a surface sampling period when the midpoint of the granule’s time coverage fell within that period. For the 24 h samples, this yielded 1582 granules on 146 of 151 sampling dates; no TEMPO granules were available on the remaining five dates. For the 3 h samples, we retrieved scans from 03:00 to 19:00 MST, yielding 988 granules on 146 of 153 sampling dates.",
        "The national analysis uses the same TEMPO product and screening approach but differs in three ways because of its larger scale. First, the extraction is spatially batched. Requesting a separate OPeNDAP subset for each of 123 sites and each scan would have required a very large number of requests, so sites were grouped into 58 geographic clusters, each no larger than 1.25° latitude by 2.5° longitude. One subset was retrieved for each cluster and scan, and the 5 × 5 grid-cell block around each site was then extracted locally. Only scans needed by the surface samples were retrieved: sampling days for 24 h records, and the sampling window plus 3 h on either side for sub-daily records. The resulting extraction contains {{n:n_cluster_scans}} cluster-scans with retrievable data and {{n:n_cell_records_million}} million grid-cell records.",
        "Second, national samples are matched to TEMPO by UTC hour as described in the main text. Nearly all AQS sampling windows begin exactly on the hour. The only exception in this dataset is an 8 h sample at Los Angeles-North Main Street beginning at 08:15; it is assigned to the hour in which the sampling window begins and is documented in the run log. Lagged comparisons are applied only to sub-daily samples, because shifting a 24 h window by a few hours changes little of the period represented. Nationally, lags are limited to ±3 h, matching the extraction padding. The +6 and +9 h comparisons are performed only for the Colorado 3 h sites, where the extraction covers 03:00–19:00 MST.",
        "Third, the national pooled regression uses ordinary least squares with fixed effects for site and calendar month rather than a mixed-effects model, because the analysis includes a large number of sites. Wildfire smoke is classified in both the national and Colorado analyses. For the national arm, sampling windows are taken directly from the AQS start and end times, so they are handled in UTC rather than with a single Colorado-specific time-zone offset."
      ]
    },
    {
      "h1": "S4. Statistical detail",
      "p": [
        "Because both the surface and satellite measurements contain error, we report reduced major axis (RMA) slopes rather than ordinary least-squares slopes. Confidence intervals are obtained by bootstrap resampling: 1000 replicates for most analyses and 200 for the national site-level, state-level, and smoke-class breakdowns and the Colorado site-by-season analysis, where many groups must be fitted. For pooled analyses, sites are resampled with replacement so that repeated observations from the same monitor remain together. If a pooled group contains fewer than five sites, we instead bootstrap individual observations and mark the resulting interval as descriptive. For single-site analyses, that site’s observations are resampled directly. RMA slopes are calculated for every group regardless of statistical significance. When r is close to zero, however, the slope sign is inherently unstable because the RMA slope is the ratio of the two standard deviations with the sign of r; the bootstrap interval reflects that instability. Figures therefore show a fitted line only when the Pearson correlation is significant (p<0.05).",
        "For the Colorado 3 h arm (Table S4), which includes only two sites, the column coefficient is estimated with ordinary least squares including fixed effects for site and calendar month; the 3 h column of Table 1 pools all four 3 h sites with the same estimator. When correlations are reported across many sites, we give both the number significant at the nominal (p<0.05) level and the number that remain significant after a Benjamini-Hochberg false-discovery-rate correction across that family of tests (Table S2). Day-to-day correlations use the permutation p-values described below; whole-period correlations use the standard parametric test. In all cases, the distribution of the correlations is more informative than the number of individually significant sites.",
        "Day-to-day correlations are calculated from within-site-month anomalies and tested by permutation rather than by the standard correlation test. Because each site-month mean is estimated from the same observations that enter the correlation, the usual parametric p-value is too optimistic. We therefore permute one variable within each site × year-month stratum, recompute the pooled correlation 2000 times, and compare the observed |r| with that permutation distribution. Because permutation within a stratum leaves its mean unchanged, the site-month structure that was removed from the data remains fixed. All p-values reported for anomaly correlations are based on this procedure; with 2000 permutations, the smallest possible p-value is 1/2001, or 0.0005. Whole-period correlations, Williams' tests for dependent correlations, and fixed-effects models use their usual parametric tests.",
        "For 8 h and 3 h samples, a site-month can contain more than one sampling window, so the anomaly may still include systematic differences among times of day. We therefore repeated the anomaly calculation after also stratifying by start hour. This gave r=0.38 at the 8 h sites (n=3483, 477 site-month-window strata, permutation p=0.0005) and r=0.33 at the 3 h sites (n=369, 56 strata, p=0.0005), compared with 0.38 and 0.39 when windows were pooled (Table 1). At the 8 h sites, which sample every block on every sampling day, the two approaches give essentially the same result. At the 3 h sites, pooling across windows raises the correlation by 0.06, indicating a modest contribution from systematic diurnal differences. The pooled values are those reported in Table 1.",
        "For each screened TEMPO scan, the reported uncertainty for the spatial block is the root mean square of the uncertainties of the passing grid cells, rather than a propagated uncertainty for their mean. This corresponds to the fully correlated limit: neighboring retrieval errors are assumed to move together, so averaging does not reduce uncertainty by √n, where n is the number of cells. We use this conservative definition deliberately. As shown in Sect. S5, the empirical scan-to-scan variability is more informative for the agreement analysis than the product-reported uncertainty; the fully correlated and independent-error limits are compared there.",
        "When two correlations share the same surface measurement- for example, when surface HCHO is correlated with TEMPO columns from two different time windows- we compare them using Williams' test for dependent correlations{{steiger1980}}, restricted to samples available in both windows. The difference between correlations is also given a bootstrap confidence interval.",
        "We use the spread of TEMPO surface pressure within each averaging block as an index of terrain heterogeneity. At the 24 h sites, where the surface sample spans the full day, we also compare TEMPO columns from 06:00–09:00 and 09:00–12:00 local standard time on the same site-days. The comparison includes only days with at least one valid scan in both windows and is repeated for within-month anomalies in site-months containing at least three such days. Williams' test is used for the paired correlations, and site-level comparisons are made where at least 20 anomaly days are available. Because the same 24 h surface sample is used for both satellite windows, any difference between the correlations reflects the retrieval timing rather than a change in the surface sampling period; this provides the control needed for interpreting the 3 h lag analysis."
      ]
    },
    {
      "h1": "S5. Retrieval-noise estimator",
      "p": [
        "We estimated retrieval noise from pairs of successive valid TEMPO scans of the same site on the same day, separated by no more than 1.6 h. The standard deviation of the differences between successive scans, divided by √2, estimates the random error of a single scan. This should be treated as an upper bound because the atmospheric HCHO column can genuinely change between scans; conversely, the method cannot detect retrieval errors that persist throughout the day.",
        "We then squared this quantity to obtain the single-scan noise variance and divided by the number of valid scans contributing to each daily mean. Because the analysis uses within-site-month anomalies, we additionally scaled this variance by 1–1/n, where n is the number of days contributing to that site-month mean. Comparing the resulting noise variance with the observed variance of the within-month TEMPO anomalies gives the fraction of day-to-day variance attributable to retrieval noise. From that fraction we calculate the maximum correlation that would be expected if retrieval noise were the only source of disagreement, (r_{\\mathrm{ceiling}}=\\sqrt{1-\\text{noise fraction}}).",
        "We applied this estimator to every 24 h site in the national analysis (Fig. S6). A site was included when it had at least 20 successive-scan pairs and 10 anomaly pairs. Of the 97 sites with sufficient 24 h surface samples, 90 met these criteria and had a defined correlation ceiling. At two additional sites, the estimated noise variance exceeded the observed anomaly variance, making the ceiling undefined; these sites were excluded from the site-level ceiling summaries. We computed the same quantity from the uncertainties reported in the product at the Colorado sites, treating the block cells as fully correlated and as independent. Those bounds imply ceilings between 0 and 0.44 depending on the assumption, all below the 0.72 that the empirical estimate gives there, which is why the reported uncertainties are not taken at face value."
      ]
    },
    {
      "h1": "S6. Smoke classification",
      "p": [
        "A sampling period was classified as smoke-affected when a NOAA Hazard Mapping System (HMS) smoke polygon covered the monitoring site and its reported time interval overlapped the sampling window{{rolph2009}}{{brey2018}}. We used daily HMS shapefiles{{noaahms2026}} for all 660 days spanned by the surface sampling periods; all files were successfully retrieved.",
        "HMS smoke polygons are drawn by analysts from discrete satellite images produced at several times each day. As a result, the absence of a polygon at a particular hour does not necessarily mean that smoke was absent: a short sampling window may simply fall between HMS analysis times even when smoke persists through much of the day. To reduce this timing mismatch, we expanded each sampling window by 3 h before and after its recorded start and end times when testing for overlap. We also recorded a broader indicator of whether any HMS smoke polygon covered the site on the relevant day, regardless of its reported time interval.",
        "This adjustment made little difference in Colorado. Strict temporal overlap classified 39 of the 234 three-hour samples as smoke-affected, compared with 41 using the ±3 h window; classifications of the 453 Colorado 24 h samples were unchanged. Nationally, however, the difference was larger: strict overlap classified 4899 of 16,383 sampling windows (29.9%) as smoke-affected, whereas the expanded window classified 6268 (38.3%). This difference arises largely because many 3 h and 8 h sampling windows fall between the discrete HMS analysis times. All smoke results reported in this study therefore use the expanded ±3 h window.",
        "Each sampling period was assigned the highest smoke-density category among the overlapping polygons and grouped as none, light, or medium–heavy. Polygons without a reported density were classified as light. If a polygon’s start or end time could not be parsed, it was treated as applicable to the entire HMS day. These choices reflect the limited temporal precision of HMS and are particularly important when classifying short-duration surface samples."
      ]
    },
    {
      "h1": "S7. Software and reproducibility",
      "p": [
        "All processing was done in R version 4.3.3{{rcore2024}}, using httr2 for data access, ncdf4 for netCDF files, sf for spatial operations{{pebesma2018}}, and lme4 for mixed-effects models{{bates2015}}. Package versions are pinned with renv, so a clean installation restores the same environment. A single script downloads the AQS samples and the CDPHE data packets, queries and subsets TEMPO granules, downloads the HMS shapefiles, and produces every table and figure. The national TEMPO extraction, one OPeNDAP request per cluster and scan ({{n:n_cluster_scans}} returned data), is enabled by a configuration flag (run_aqs_tempo) because it takes days to complete, and the extracted grid cells are cached so that every later step re-runs from them.",
        "The analysis period is fixed, downloaded inputs are cached with MD5 checksums, the exact OPeNDAP constraint expression is recorded, and each run logs its configuration and R session information. The terrain in Fig. S1 comes from the AWS Terrain Tiles on the Registry of Open Data on AWS{{aws}}, retrieved with the elevatr R package{{hollister2023}}, and the state and county boundaries are US Census cartographic boundary files{{census2023}}."
      ]
    },
    {
      "h1": "S8. Further results",
      "p": []
    },
    {
      "h2": "S8.1 Three-hour samples",
      "p": [
        "Under the primary screening, 54 of 115 samples at Chatfield State Park (47%) and 56 of 119 at Platteville (47%) had at least one valid TEMPO scan during the 06:00–09:00 MST sampling window, with a median of two usable scans per sample (Table S4). Coverage improved in the 09:00–12:00 window, to 63% at Chatfield and 61% at Platteville, and then declined to 45% and 54% in the 12:00–15:00 window. No scan passed screening during 03:00–06:00 at either site, and only seven Platteville samples had a valid scan during 15:00–18:00, largely because of the solar-zenith-angle criterion. Consistent with this, 36% of grid cells failed that criterion during the 06:00–09:00 sampling window, compared with only 4% during 09:00–12:00.",
        "The two sites show different timing relationships, and that contrast is the main result. At Chatfield, the TEMPO column during the 06:00–09:00 sampling window contained essentially no day-to-day information about surface HCHO (within-month anomaly r=−0.01, n=47). Agreement increased sharply in the 09:00–12:00 window (r=0.48, n=64, p=0.001) and then weakened again in 12:00–15:00 (r=0.18, n=34, p=0.40). Platteville showed no comparable improvement: the same three windows gave correlations of 0.24 (n=43, p=0.16), 0.15 (n=64, p=0.26), and −0.01 (n=51, p=0.97). Pooled across both sites, the corresponding correlations were 0.12 (n=90, p=0.26), 0.31 (n=128, p=0.0005), and 0.06 (n=85, p=0.62). Whole-period correlations show the same contrast (Figs. S7–S8, Table S4).",
        "Because Platteville contributes 2023 observations whereas Chatfield does not, we repeated the comparison using only 2024–2025 data (Table S6). Chatfield is unchanged. At Platteville, the later window still provides no advantage, but the apparent ordering of the two windows depends on the period examined. Restricting the analysis to 2024–2025 gives nearly identical anomaly correlations during sampling and three hours later (0.25 versus 0.26), whereas including 2023 gives 0.24 versus 0.15. None of the Platteville anomaly correlations are statistically significant in either period. We therefore conclude only that agreement improves substantially after sampling at Chatfield, whereas Platteville shows no such improvement; we do not interpret Platteville as performing better during the sampling window.",
        "Differences in coverage between windows could also affect the comparison, so we repeated it using only samples with valid TEMPO observations in both the 06:00–09:00 and 09:00–12:00 windows. This left 50 samples at Chatfield and 52 at Platteville, reduced to 42 and 38 for the anomaly analysis after requiring at least three observations per site-month. At Chatfield, the anomaly correlation increased by 0.57, from −0.16 during sampling to 0.41 three hours later (Williams' test p=0.008; bootstrap 95% CI: 0.21, 0.88). At Platteville, the increase was only 0.07, from 0.17 to 0.24 (p=0.71; 95% CI: −0.20, 0.35). Pooled across both sites, the increase was 0.29, from 0.02 to 0.31 (Williams' test p=0.045; bootstrap 95% CI: 0.05, 0.52), but we treat that pooled estimate as descriptive because it averages two sites with clearly different behavior.",
        "The timing contrast is also consistent with changes in boundary-layer structure. Across matched scans, the median TEMPO boundary-layer height increased from 0.45 km during sampling to 1.50 km three hours later and 2.21 km six hours later, while the median effective mixing height remained between 0.92 and 0.98 km across the three windows of Table S4. The TEMPO columns themselves also evolved differently at the two sites: columns in the sampling and +3 h windows were only weakly correlated at Chatfield (r=0.27) but more strongly correlated at Platteville (r=0.61; Fig. S9)."
      ]
    },
    {
      "h2": "S8.2 Wildfire smoke",
      "p": [
        "Across the network, 6268 of 16,383 sampling windows (38%) were classified as smoke-affected. Among the 10,017 windows that also had a usable TEMPO observation, 4097 were smoke-affected. Agreement between surface HCHO and the TEMPO column was stronger on smoke-affected days at both well-sampled durations (Table S5, Fig. S10). At the 24 h sites, the correlation increased from 0.29 on smoke-free days (n=3950) to 0.38 under light smoke (n=1854) and {{n:smoke_r_24_heavy}} under medium-heavy smoke (n=302). At the 8 h sites, the corresponding correlations were 0.22 (n=1675), 0.42 (n=1599), and 0.49 (n=235). Excluding smoke-affected days reduced the day-to-day correlation from 0.40 to {{n:smoke_dd_24_nosmoke}} at the 24 h sites (n=5218 to 2645) and from 0.38 to {{n:smoke_dd_8_nosmoke}} at the 8 h sites (n=3509 to 1610).",
        "TEMPO columns were substantially larger on smoke-affected days: at the 24 h sites the median increased from 4.07 to 8.83 × 10^{15} molecules cm^{−2}, and at the 8 h sites from 9.08 to 12.07 × 10^{15} molecules cm^{−2}. Surface HCHO increased proportionately less. This pattern is therefore consistent with the broader concentration dependence described in the main text: when the atmospheric signal is larger, fixed retrieval noise represents a smaller share of the total variation. We therefore do not interpret the higher smoke-day correlations as evidence for a smoke-specific chemical effect. The 3 h record is too sparse for interpretation, with 295, 95, and 12 samples in the three smoke classes.",
        "Checks at the Colorado sites. Three additional analyses support the interpretations used in the main text. First, retrieval-noise ceilings estimated independently in the Colorado analysis agree with the national calculation. La Salle and Cañon City lie close to their estimated ceilings, with noise-corrected day-to-day correlations of 0.84 and 0.85; Commerce City is intermediate at 0.67, and Grand Junction is much lower at 0.29. Terrain variability within the 3 × 3 averaging block does not explain this ordering. The spread in TEMPO surface pressure is smallest at Commerce City (1.8 hPa) and largest at Cañon City (11.5 hPa), which is opposite to the pattern that would be expected if terrain heterogeneity were driving the differences in agreement.",
        "Second, restricting TEMPO observations to 10:00–14:00 MST reduced the pooled whole-period correlation at every spatial scale. Correlations were 0.38, 0.50, and 0.59 for 1 × 1, 3 × 3, and 5 × 5 blocks using only midday scans, compared with 0.47, 0.56, and 0.61 when all valid daylight scans were averaged. For 24 h surface samples, the all-day TEMPO mean therefore provides the better match.",
        "Third, the Colorado smoke pattern differs from the national one. Smoke affected 69 of 453 Colorado 24 h sample days (15%), compared with 38% of national sampling windows. In Colorado, the whole-period correlation was lower on smoke-affected days: 0.46 on smoke-free days (n=276), 0.36 under light smoke (n=48), and 0.37 under medium-heavy smoke (n=14). However, excluding smoke days still reduced the Colorado day-to-day correlation, from 0.30 to 0.23, as in the national analysis. Because the Colorado smoke strata are much smaller than the national ones, particularly for medium-heavy smoke, we place greater weight on the national pattern. Smoke-affected days in Colorado were also not simply clearer days: within season, median cloud fraction differed little between smoke and smoke-free samples (summer: 0.16 versus 0.18, p=0.52; autumn: 0.13 versus 0.13, p=0.82)."
      ]
    },
    {
      "h1": "S9. Why agreement differs",
      "p": [
        "Sect. 2.3.3 of the main text describes four analyses that ask why agreement differs between samples and sites; Sect. 3.6 reports them. This section gives the underlying tables. Table S7 lists the {{n:dd_sites_total}} monitors that report both 24 h and 8 h formaldehyde, with the within-month anomaly correlation at each duration, by 8 h block, and for the 24 h sample against the column restricted to each block's hours; Fig. S12 plots the paired values. Table S8 gives the weighted Fisher-z models of the observed site correlation and of the noise-corrected ratio E = r_{obs}/r_{ceiling} against the six site descriptors, and Fig. S13 the observed correlations against their ceilings and E against each descriptor. Table S9 gives the correlation by tertile of HRRR mixing depth, with the site-clustered bootstrap interval for the difference between the deepest and shallowest tertile, and the interaction coefficients. Table S10 gives the temporal-averaging curve of Fig. 4 by spatial block, with the single-scan noise implied by the variance of the column anomaly against 1/k.",
        "Two details of the mixing-depth analysis deserve mention. The tertiles defined relative to the site-month compare days on which the mixed layer was deeper or shallower than usual for that monitor and month, so that the contrast is not a contrast between climates. The competing-moderator model lets the column–surface slope vary with the number of valid scans (more averaging, less noise) and with the site-month column level (more signal); the mixing-depth interaction that survives that adjustment is what the main text reports as the adjusted value. For 24 h samples the mixing depth is a daily mean over a window that is half night, which is why its effect is weak and does not survive the adjustment."
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
        "notes": "^{a} Matched samples with at least one screened TEMPO scan inside the 06:00–09:00 MST sampling window. Identifiers are AQS site codes. Site names are CDPHE's; AQS records some stations under a different name, Commerce City as Birch Street, Wheat Ridge as Peak Expeditionary School, Pueblo as St. Charles Mesa Water District, Grand Junction as Grand Junction - Pitkin, La Salle as La Salle Tower and Cañon City as Canon City - Harrison School."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S2. Site-level correlations reaching nominal and false-discovery-rate significance, by sample duration. Counts are over site-duration combinations with at least 10 matched samples, at the primary screening and with scans inside the sampling window. The Benjamini-Hochberg correction is applied across all 141 tests in each family. Whole-period counts use the ordinary correlation test; day-to-day counts use the within-site-month permutation test (Sect. S4), which is the stricter of the two - the ordinary test applied to the same anomalies would give 103 and 102 rather than 96 and 93. These counts are reported for completeness; the distribution of the correlations themselves is more informative, and no conclusion in the paper depends on a count.",
        "header": [
          "Duration",
          "Sites",
          "Whole period, p < 0.05",
          "Whole period, BH q < 0.05",
          "Day-to-day, p < 0.05",
          "Day-to-day, BH q < 0.05"
        ],
        "rows": [
          [
            "24 h",
            "97",
            "85",
            "84",
            "61",
            "58"
          ],
          [
            "8 h",
            "40",
            "34",
            "34",
            "33",
            "33"
          ],
          [
            "3 h",
            "4",
            "3",
            "3",
            "2",
            "2"
          ],
          [
            "All",
            "141",
            "122",
            "121",
            "96",
            "93"
          ]
        ]
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S3. The HRRR meteorology compared with the meteorology supplied with the TEMPO retrieval. The difference is the median of the paired differences (TEMPO minus HRRR) and need not equal the difference of the two medians. Boundary-layer depths are averaged over the UTC hours in which each sample's valid TEMPO scans fell; the last row repeats the all-arms comparison with HRRR averaged over the whole sampling window instead, which is not like-for-like because TEMPO observes only in daylight while a 24 h window is half night.",
        "header": [
          "Quantity and arm",
          "n",
          "HRRR",
          "TEMPO",
          "Difference",
          "r"
        ],
        "rows": [
          [
            "Surface pressure (hPa), Colorado 24 h",
            "338",
            "849.5",
            "849.0",
            "−1.6",
            "0.9930"
          ],
          [
            "Surface pressure (hPa), Colorado 3 h",
            "110",
            "841.3",
            "840.8",
            "−1.2",
            "0.9966"
          ],
          [
            "Surface pressure (hPa), national",
            "10,017",
            "998.3",
            "997.3",
            "−0.6",
            "0.9993"
          ],
          [
            "Surface pressure (hPa), all arms",
            "10,465",
            "997.5",
            "996.5",
            "−0.6",
            "0.9995"
          ],
          [
            "Boundary-layer depth (m), Colorado 24 h",
            "338",
            "994",
            "1550",
            "+326",
            "0.77"
          ],
          [
            "Boundary-layer depth (m), Colorado 3 h",
            "110",
            "238",
            "451",
            "+167",
            "0.63"
          ],
          [
            "Boundary-layer depth (m), national",
            "10,017",
            "848",
            "1062",
            "+152",
            "0.83"
          ],
          [
            "Boundary-layer depth (m), all arms",
            "10,465",
            "845",
            "1065",
            "+155",
            "0.83"
          ],
          [
            "Boundary-layer depth (m), all arms, HRRR over the whole sampling window instead",
            "10,465",
            "608",
            "1065",
            "+371",
            "0.77"
          ]
        ]
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S4. Comparison of 3 h surface HCHO at the two Colorado sites (Chatfield 2024–2025, Platteville August 2023–2025) with the mean of valid TEMPO scans in the sampling window (06:00–09:00 MST) and in windows shifted 3 and 6 h later (primary screening, 3 × 3 cells).",
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
            "Median scans per window",
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
        "notes": "Anomaly p-values are within-site-month permutation values (Sect. S4); the smallest attainable is 0.0005. Whole-period p-values are from the ordinary parametric test. The −3 h window (03–06 MST) contained no usable scans; the +9 h window (15–18 MST) yielded seven Platteville samples and is not shown. The column coefficient is in µg m^{−3} per 10^{15} molecules cm^{−2}."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S5. Agreement between surface HCHO and the TEMPO column by HMS smoke class over the site during the sampling window, for every duration in the national comparison, at the primary screening with scans inside the sampling window. Medians are over matched samples. The 3 h medium–heavy class holds too few samples to interpret.",
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
        "notes": "Smoke-affected samples nationally: {{n:smoke_n_affected}} of 10,017 matched samples carrying a classification."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S6. Does the 2023 extension create the difference between the two sites? Both 3 h sites were recomputed on 2024–2025 alone, besides the record as analyzed. Chatfield State Park reported no 2023 formaldehyde, so its values are identical in the two periods and are given once.",
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
        "notes": "Anomaly p-values are within-site-month permutation values (Sect. S4). The later window has no advantage at Platteville in either period, which is the claim made in the text; the apparent preference for the sampling window appears only once 2023 is included, and no Platteville anomaly correlation is significant in either period."
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S7. The 23 monitors reporting both 24 h and 8 h formaldehyde. n and r are the number of within-month anomaly pairs and their correlation (primary screening, 3 × 3 block, scans inside the sampling window); r_{8h} 04:00 and 12:00 use anomalies computed within site, month and start hour; the last two correlations pair the 24 h surface sample with the mean of only those scans falling in the hours of each 8 h block. Usable share is the percentage of samples with TEMPO coverage that had at least one usable scan; scans is the median number of valid scans per usable sample. Two sites have too few 24 h anomaly pairs for a correlation. Paired summaries are in output/tables/diag7_dual_duration_paired.csv.",
        "builder": "dualDurationSites"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S8. Weighted least-squares models of the Fisher-transformed observed within-month correlation (M1) and of the noise-corrected ratio E = r_{obs}/r_{ceiling} (M2, M3) at the {{n:gap_sites}} 24 h sites with a retrieval-noise ceiling. Predictors are standardized (coefficients are per standard deviation, standard errors in parentheses), weights are n − 3 anomaly pairs, and the six descriptors were fixed in advance. E is capped at 0.999 before transformation. Univariate Spearman correlations are in output/tables/diag8_ceiling_gap_univariate.csv.",
        "builder": "ceilingGapModels"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S9. Within-month anomaly correlation by tertile of the HRRR mixing depth averaged over the sampling window. For 8 h samples the anomalies and the relative tertiles are computed within site, month and start hour; for 24 h samples within site and month. The difference between the deepest and shallowest tertile carries a site-clustered bootstrap interval (2000 replicates). The interaction rows give the coefficient of column anomaly × mixing-depth anomaly (both standardized) in a regression of the surface anomaly, with site-clustered standard errors; the adjusted version also lets the column slope depend on the number of valid scans and on the site-month column level.",
        "builder": "pblTertiles"
      },
      "p": []
    },
    {
      "table": {
        "caption": "Table S10. The temporal-averaging experiment of Fig. 4 for each spatial block: {{n:ta_samples}} 24 h samples with at least four valid scans in every block, {{n:ta_draws}} random draws per k, 3434 anomaly pairs in all; the site median is over the 84 sites with at least 10 pairs. The last row of each block is the single-scan noise implied by the slope of the column-anomaly variance against 1/k (R^{2} > 0.99), to be compared with the site medians of the scan-difference estimator: {{n:nc_single_median_11}}, {{n:nc_single_median_33}} and {{n:nc_single_median_55}} × 10^{15} molecules cm^{−2}.",
        "builder": "temporalAveraging"
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig0_site_map.png",
        "caption": "Figure S1. The Colorado sites: seven COATTS sites sampling 24 h integrated formaldehyde (circles) and two COOPs sites sampling 3 h integrated formaldehyde (triangles), over terrain and county boundaries. Inset: the 123 sites across the contiguous United States that reported formaldehyde to AQS in 2024–2025, colored by sample duration, with Colorado outlined. Elevation is from AWS terrain tiles; boundaries are US Census cartographic files."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig16_national_screening_sensitivity.png",
        "caption": "Figure S2. Pooled Spearman correlation between surface HCHO and the mean TEMPO column at every site in the comparison, as a function of the maximum effective cloud fraction and the averaging block (1 x 1, 3 x 3 or 5 x 5 cells), for scans inside the sampling window. Panels are sample duration; symbol size is the number of matched samples. The primary screening used throughout is a cloud fraction of 0.2 with a 3 x 3 block. The Pearson values quoted in the text follow the same ordering."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig8_threeh_sensitivity.png",
        "caption": "Figure S3. Pooled Spearman correlation between 3 h surface HCHO and the window-mean TEMPO column as a function of the maximum effective cloud fraction and the averaging block, for each lag from the sampling window. Symbol size shows the number of matched samples."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig19_met_comparison.png",
        "caption": "Figure S4. The HRRR meteorology used for the number density, compared with the meteorology supplied with the TEMPO retrieval, over the 10,465 matched samples of all three arms. (a) Surface pressure, HRRR against the value supplied with the retrieval. (b) Boundary-layer depth, HRRR against the GEOS-CF height supplied with the retrieval; both are averaged over the UTC hours in which that sample’s valid TEMPO scans fell, so the two are sampled at the same times. Colors denote the arm. The line is 1:1."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig11_national_lag_curve.png",
        "caption": "Figure S5. Pooled correlation between sub-daily surface HCHO and the mean TEMPO column as a function of the lag of the TEMPO window from the sampling window, for the 3 h and 8 h sites. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site-month means. Labels give the number of samples in each series; the anomaly series has fewer because site-months with fewer than three samples are dropped. Because the sites pooled here sample different windows, a given lag corresponds to different times of day at different sites, which is why the main text reports agreement by window start hour instead."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig18_national_noise_ceiling.png",
        "caption": "Figure S6. Observed day-to-day (within-month anomaly) correlation at each 24 h monitor against the ceiling implied by TEMPO scan-to-scan noise alone (3 × 3 block; {{n:nat_sites_scored}} monitors with at least 20 successive-scan pairs and 10 anomaly pairs and a defined ceiling). The dashed line is the ceiling itself: a monitor on it would have its agreement limited only by retrieval noise. {{n:nat_sites_ceiling_undefined}} monitors at which the noise bound exceeded the anomaly variance are not shown."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig7_threeh_scatter.png",
        "caption": "Figure S7. Three-hour surface HCHO at Chatfield State Park (CHCO, 2024–2025) and Platteville (PVCO, August 2023-July 2025) versus the mean TEMPO column in the sampling window (06:00–09:00 MST) and in windows shifted by +3, +6 and +9 h. The −3 h window is not shown because no scan passed screening in it, and the +9 h row holds only seven Platteville samples. Colors denote season; lines show reduced major axis fits where the Pearson correlation is significant."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig10_threeh_lag_curve.png",
        "caption": "Figure S8. Agreement between 3 h surface HCHO and the mean TEMPO column as a function of the lag between the sampling window (06:00–09:00 MST) and the satellite window, for the whole period and for within-month anomalies. Labels give the number of samples in each series. Agreement is highest in the window beginning when sampling ends (09:00–12:00 MST), when the median TEMPO boundary layer height has risen from 0.45 to 1.5 km; the pooled curve averages two sites that differ (Table S4)."
      },
      "p": []
    },
    {
      "fig": {
        "file": "figS3_threeh_window_columns.png",
        "caption": "Figure S9. TEMPO columns for the same 3 h samples, measured in the sampling window (06:00–09:00 MST) and three hours later. The two differ substantially from day to day at Chatfield State Park and agree more closely at Platteville; the dashed line is 1:1."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig17_national_smoke.png",
        "caption": "Figure S10. Pearson correlation between surface HCHO and the TEMPO column by HMS smoke class over the site during the sampling window, for the 24 h, 8 h and 3 h sites nationally. Labels are the number of matched samples. Agreement rises with smoke at both well-sampled durations; the 3 h medium-heavy class holds twelve samples and is not interpreted."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig12_national_by_start_hour.png",
        "caption": "Figure S11. Correlation between sub-daily surface HCHO and the mean TEMPO column, grouped by the local standard hour at which the sampling window begins, using only scans inside the sampling window. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site-month means. In the 3 h panel, the windows beginning at 05:00, 12:00 and 16:00 are the two California sites and the window beginning at 06:00 is the two Colorado sites; in the 8 h panel each point pools all 40 sites, and the 8 h block beginning at 20:00 LST, which is dark, has too few usable scans (fewer than 12) to be shown; the 3 h windows beginning at 23:00 (dark) and 08:00 (14 samples) are not shown either. Labels give the number of samples in each series; the anomaly series has fewer because site-months with fewer than three samples are dropped."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig20_dual_duration.png",
        "caption": "Figure S12. Within-month anomaly correlation between surface HCHO and the TEMPO column at the {{n:dd_sites_paired}} monitors with at least {{n:dd_min_pairs}} anomaly pairs in both their 24 h and their 8 h record (primary screening, scans inside the sampling window). Symbol size is the smaller of the two pair counts; the dashed line is equality."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig21_ceiling_gap.png",
        "caption": "Figure S13. (a) Observed within-month anomaly correlation at each of the {{n:gap_sites}} 24 h sites with a retrieval-noise ceiling, against that ceiling; the dashed line is equality and the dotted line half the ceiling. Color is the site's median surface HCHO. (b) The noise-corrected ratio E = r_{obs}/r_{ceiling} against the six site descriptors of Table S8."
      },
      "p": []
    }
  ],
  "authors": [
    "[[Author list to match the main text; Correspondence to: ...]]"
  ]
};
