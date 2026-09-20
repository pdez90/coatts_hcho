// content_est_si.js - Supporting Information for the ES&T version.
//
// Everything moved out of the main text: the detailed data descriptions and
// methods, the Colorado results, and 11 figures and 5 tables.
// Numbering follows order of first citation in the main text:
//   Figure S1        Methods, surface measurements
//   Figures S2, S3   Methods, TEMPO matching (sensitivity)
//   Figure S4        Results, sampling time (pooled lag curves)
//   Figures S5-S10   Results, the Colorado sites
//   Tables S1, S2    Methods, surface measurements
//   Table S2         Methods, statistics
//   Tables S3, S4    Results, the Colorado sites
module.exports = {
  title: "Supporting Information for: Hourly Satellite Formaldehyde Columns and Routine Surface Air Toxics Monitoring: Day-to-Day Agreement at 123 United States Sites",

  authors: ["[[Author list to match the main text.]]"],

  contents: "Contents: Supporting text S1-S8; Figures S1-S11; Tables S1-S5. 20 pages.",

  sections: [
    { h1: "S1. The Colorado sites", p: [
      "CDPHE operates the Colorado Air Toxics Trends (COATTS) network, whose first phase became fully operational on 1 January 2024 and second phase on 1 July 2025{{cdpherepo2026}}. Surface formaldehyde for all seven sites comes from AQS, the same source as the national comparison (Table S1, Figure S1). CDPHE's 2024 and 2025 annual data packets supply the method detection limit and the sampling temperature and pressure, neither of which AQS publishes; the temperature and pressure, recorded for 118 of the 326 matched sample days, are what allow the effective mixing height at these sites to be computed close to the conditions of the sample; where absent, the site's monthly median temperature and TEMPO's surface pressure are used. Commerce City (Adams County), La Salle (Weld County) and Grand Junction (Mesa County) sampled throughout both years; Colorado Springs (El Paso County), Pueblo (Pueblo County) and Cañon City (Fremont County) began in July 2025; and Wheat Ridge (Jefferson County) began in October 2025. Samples are 24 h integrated collections on a 1-in-6 day schedule, identified by AQS parameter code 43502. AQS reports them in parts per billion carbon, which for a one-carbon molecule equals parts per billion by volume; we converted to mass concentration at 25 °C and 1 atm, exactly as for the rest of the network.",

      "AQS{{epaaqs2026}} records the time each sample began. For all seven sites this is 00:00 local standard time with a 24 h duration, confirming midnight-to-midnight sampling on the stamped date. AQS gives the method as DNPH-coated silica cartridges with a potassium iodide ozone scrubber, analysed by HPLC with ultraviolet detection, following Compendium Method TO-11A{{epato11a1999}}; the same method is used at every site. AQS identifies Grand Junction (08-077-0018) as a National Air Toxics Trends Station{{epanatts2025}}.",

      "Two ozone-precursor sites, Chatfield State Park in Douglas County (CHCO) and Platteville in Weld County (PVCO), belong to CDPHE's COOPs network [[expand acronym]], discontinued at the end of June 2026; its historical data remain available. Both report formaldehyde to AQS as 3 h samples beginning at 06:00 MST, so the sampling window is 06:00-09:00 MST; CDPHE's own packets stamp these samples 09:00, the end of sampling, and confirm the 3 h duration [[decide how to cite CDPHE's answers]]. Platteville also reported formaldehyde to AQS through 2023 on the same start time and duration, so its record extends back to August 2023; Chatfield reported no 2023 formaldehyde to AQS. The window does not move with daylight saving: AQS records sample times in local standard time, and for every Colorado sample in this study the recorded start is seven hours behind the corresponding GMT stamp in all twelve months, so the 06:00-09:00 window is the same clock interval in summer as in winter. This matters for the lag analysis of S8, which would otherwise compare a summer window with a winter one displaced by an hour."
    ]},

    { h1: "S2. Quality control", p: [
      "Concentrations come from AQS, and the screen is the one applied throughout the study: records carrying an AQS null data qualifier, which marks a value as invalid or as a quality-control or quality-assurance measurement, are excluded; quality-assurance and informational qualifiers are retained; and duplicate records of the same sampling window are averaged. AQS publishes ambient samples only, so the quality-control samples that CDPHE's own packets list alongside them do not arise. The resulting Colorado record contains 453 site-days with valid concentrations.",

      "The 3 h sites are screened identically. Every AQS sample begins at 06:00 MST, so no sampling window is ambiguous. The resulting record contains 115 samples at Chatfield State Park (8 February 2024-27 December 2025) and 119 at Platteville (4 August 2023-18 July 2025; later 2025 samples were not collected because of sampling problems), all of which enter the analysis."
    ]},

    { h1: "S3. TEMPO extraction and the national comparison", p: [
      "TEMPO is an ultraviolet-visible grating spectrometer in geostationary orbit that scans North America from east to west approximately hourly during daylight{{zoogman2017}}. Level 3 files grid Level 2 retrievals from each scan to a regular 0.02° × 0.02° grid using area weighting. Each file provides the HCHO vertical column and its uncertainty, a main data quality flag, effective cloud fraction, snow and ice fraction, solar zenith angle and, new in version 4, a planetary boundary layer height as support data{{nasaguide2025}}. That height is taken from the GEOS-CF version 2 model, is not used in the retrieval itself, and is supplied for interpretation; it is a modelled quantity, and the comparisons with H_{eff} below should be read with that in mind.",

      "For the Colorado sites, granules were identified with NASA's Common Metadata Repository and assigned to a sampling period when the midpoint of the scan's time coverage fell within it. For the 24 h samples this gave {{n:co_granules}} granules on {{n:co_granule_dates}} of the {{n:co_sampling_dates}} sampling dates; no TEMPO observations were available on the other {{n:co_nogranule_dates}}. For the 3 h samples, scans between 03:00 and 19:00 MST were retrieved ({{n:th_granules}} granules on {{n:th_granule_dates}} of the {{n:th_sampling_dates}} sampling dates).",

      "The national arm repeats the analysis at every AQS site with three differences forced by its scale. First, extraction: requesting a separate OPeNDAP subset for each of 123 sites would multiply the number of requests by the number of sites, so sites were grouped into {{n:n_clusters}} clusters of at most 1.25° latitude by 2.5° longitude, one subset was requested per cluster and scan, and the 5 × 5 cell block around each site was cut from it afterwards. Only scans a cluster's samples actually require were retrieved: the days a site sampled, and for sub-daily samples the sampling window padded by 3 h on each side. The extraction holds {{n:n_cluster_scans}} cluster-scans with retrievable cells and {{n:n_cell_records_million}} million cell records. Second, matching is by UTC hour set as described in the main text; nearly every AQS sampling window begins on the hour, and the one exception in this record, an 8 h sample at Los Angeles-North Main Street beginning at 08:15, is assigned to the hour its window begins in and named in the run log. Lags are applied only to sub-daily samples, since a 24 h window shifted by a few hours is almost the same window, and only to ±3 h, the padding the extraction retrieved; the +6 and +9 h windows are evaluated only for the Colorado 3 h sites, whose extraction covers 03:00-19:00 MST. Third, the pooled regression uses ordinary least squares with fixed effects for site and calendar month rather than a mixed model, because the number of sites is large. Wildfire smoke is classified for the national arm as well as the Colorado one; the national sampling windows come from AQS start and end times, so unlike the Colorado arms they carry no single time-zone offset."
    ]},

    { h1: "S4. Statistical detail", p: [
      "Because both variables contain measurement error, we report reduced major axis (RMA) regression slopes with 95 % confidence intervals from 1000 bootstrap resamples, except 200 for the national site-level, state-level and smoke-class breakdowns and the Colorado site-by-season breakdown, where many groups are fitted. A pooled group with fewer than five sites falls back to a row bootstrap and is marked descriptive in the tables. Slopes are given for every group in the tables whether or not the correlation is significant; where r is near zero the RMA slope, being the ratio of standard deviations carrying the sign of r, has an unstable sign, and the bootstrap interval shows that directly. The figures draw a fitted line only where the Pearson correlation reaches p < 0.05, so as not to suggest a relationship the data do not support. Intervals for pooled slopes resample sites with replacement, because the same monitors contribute many samples each; intervals for a single site resample that site's own samples and are descriptive, the 1-in-6 day schedule leaving little day-to-day dependence to preserve. For the Colorado sites we fitted linear mixed-effects models{{bates2015}} with surface HCHO as the response, the column as a fixed effect, a random intercept for site and fixed effects for either season or calendar month. For the 3 h samples, with only two sites, we used ordinary least squares with fixed effects for site and calendar month. Where correlations are reported for many sites at once we give both the number significant at a nominal p < 0.05 and the number surviving a Benjamini-Hochberg false-discovery-rate correction applied across that family of tests (Table S2), using the permutation p-values described below for day-to-day correlations and the ordinary test for whole-period ones; the distribution of the correlations themselves is more informative than either count.",

      "Correlations between within-site-month anomalies are tested by permutation rather than by the ordinary correlation test. The site-month means are estimated from the same observations that then enter the correlation, so the parametric p-value spends degrees of freedom it does not have and is optimistic. We permute one variable within each site × year-month stratum and recompute the pooled correlation 2000 times, comparing the observed |r| with the permutation distribution; because a permutation leaves a stratum's mean unchanged, this holds the removed structure fixed rather than assuming it away. Every anomaly p-value reported here is such a permutation value, and the smallest attainable with 2000 permutations is 1/2001 = 0.0005. Whole-period correlations, Williams' tests for dependent correlations and the fixed-effects models use their usual parametric tests.",

      "The uncertainty attached to a screened scan is the root mean square of the reported uncertainties of the passing cells in the block, not a propagated uncertainty for their mean. This is the fully correlated limit: it assumes neighbouring retrieval errors move together and so takes no √n reduction from averaging. We adopt it deliberately, as the conservative choice, and because the noise analysis (Text S5, Figure S6) shows that the empirical scan-to-scan spread, not the reported uncertainty, is what limits agreement; both the correlated and independent limits of the reported uncertainty are given there for comparison.",

      "Where two correlations share a variable — for example the surface concentration correlated with the column in two different windows — we compare them with Williams' test for dependent correlations{{steiger1980}} on the samples usable in both, with a bootstrap confidence interval for the difference. We use the spread of TEMPO surface pressure across each averaging block as an index of terrain heterogeneity. As a control for the 3 h lag analysis we repeat the window comparison at the 24 h sites, where the sample spans every window, so that any difference between windows reflects the retrievals rather than the sampling time."
    ]},

    { h1: "S5. Retrieval-noise estimator", p: [
      "Differences between successive valid scans of the same site and day, divided by the square root of two, give an empirical noise standard deviation for a single scan. This is an upper bound, because the column genuinely changes between scans, and it is blind to errors that persist through a day. Squaring this quantity gives a single-scan noise variance, and dividing that variance by the number of valid scans estimates the noise variance of the daily mean; comparing it with the variance of the within-month anomalies gives the share of that variance which is noise and the correlation ceiling that noise alone implies, the square root of one minus the noise share. We computed the same quantity from the uncertainties reported in the product, with block cells treated as fully correlated and as independent (Figure S6)."
    ]},

    { h1: "S6. Smoke classification", p: [
      "A sampling period was classified as smoke-affected when a NOAA Hazard Mapping System polygon covered the site and the polygon's start-end interval overlapped the sampling window{{rolph2009}}{{brey2018}}. We used the daily HMS shapefiles{{noaahms2026}} for all {{n:hms_days_needed}} days touched by the sampling windows, of which {{n:hms_days_missing}} could not be downloaded. HMS polygons are analyst delineations from discrete visible satellite imagery issued at a few analysis times a day, so an hour not covered by any polygon interval is not thereby established as free of smoke, and a short sampling window can fall between analysis times on a day when smoke was present throughout. We consequently widened each sampling window by 3 h on either side before testing temporal overlap, and also recorded whether any polygon covered the site on the relevant HMS days regardless of time. For the Colorado arms this had little influence: strict temporal overlap identified 39 of the 234 three-hour sampling windows as smoke-affected against 41 with the widened window, and the 453 24 h samples were classified identically. Nationally it matters more: strict overlap flags 4899 of the 16 383 windows (29.9 %) against 6268 (38.3 %) with the widened window, because 8 h and 3 h windows elsewhere often fall between HMS analysis times; every smoke result reported uses the widened window. Each period was assigned the highest density class of the overlapping polygons and grouped as none, light or medium-heavy; a polygon without a density attribute counts as light, and a polygon whose start or end time cannot be parsed counts for the whole HMS day. Classifications of short sampling periods using HMS should allow for the discrete times at which the analyses are made."
    ]},

    { h1: "S7. Software and reproducibility", p: [
      "All processing was done in R version {{n:r_version}}{{rcore2024}}, using httr2 for data access, ncdf4 for netCDF files, sf for spatial operations{{pebesma2018}} and lme4 for mixed-effects models{{bates2015}}. A single script downloads the AQS samples and the CDPHE data packets, queries and subsets TEMPO granules, downloads HMS shapefiles, and produces all tables and figures. The analysis period is fixed, downloaded inputs are cached with MD5 checksums, the exact OPeNDAP constraint expression is recorded, and each run logs its configuration and R session information. The terrain in Figure S1 comes from the AWS Terrain Tiles on the Registry of Open Data on AWS{{aws}}, retrieved with the elevatr R package{{hollister2023}}, and the state and county boundaries are US Census cartographic boundary files{{census2023}}."
    ]},

    { h1: "S8. Colorado results", p: [
      "Availability. Of the 453 site-days with valid 24 h samples, 338 (74.6 %) had at least one valid TEMPO scan under the primary screening, and 15 had no TEMPO granules (Table S1). Coverage ranged from 63.6 % at La Salle to 85.4 % at Grand Junction, with a median of 4-5 valid scans per sample day at all sites except Wheat Ridge (2). Coverage was lowest in winter: {{n:cov_DJF}} % of December-February sample days were matched, against {{n:cov_MAM}} % in spring, {{n:cov_JJA}} % in summer and {{n:cov_SON}} % in autumn.",

      "Agreement. Surface HCHO and TEMPO columns followed the same seasonal cycle, with summer maxima at all sites with year-round records. Across all sites, daily mean columns correlated with surface HCHO at r = 0.56 (ρ = 0.57, n = 338). The RMA slope was 0.39 (0.28-0.48) µg m^{-3} per 10^{15} molecules cm^{-2} with an intercept of 1.26 µg m^{-3}; median values were 2.70 µg m^{-3} at the surface and 3.50 × 10^{15} molecules cm^{-2} in the column. Correlations were significant at five sites, from 0.48 at Pueblo to 0.74 at La Salle and 0.83 at Cañon City, and not significant at Colorado Springs (0.31, n = 23) or Wheat Ridge (-0.11, n = 10). Within individual seasons pooled correlations were weaker: 0.24 in winter (p = 0.06), 0.22 in spring (p = 0.06), 0.26 in summer (p = 0.02) and 0.51 in autumn (p < 0.001). In the mixed-effects model with season effects the column coefficient was 0.140 ± 0.020 µg m^{-3} per 10^{15} molecules cm^{-2} (t = 7.1); with calendar-month effects it decreased to 0.096 ± 0.022 (t = 4.3), confirming that part of the whole-period association is seasonal.",

      "After removing site and calendar-month means the pooled day-to-day correlation was 0.30 (n = 305 in 70 site-months, p = 0.0005), with an ordinary least squares slope of 0.097 µg m^{-3} per 10^{15} molecules cm^{-2}. Day-to-day agreement was strongest at La Salle (0.61, n = 56) and Commerce City (0.48, n = 74), both significant under the permutation test (p = 0.002 and 0.0005 respectively), and weaker at Grand Junction (0.22, n = 101). Neither Grand Junction (p = 0.07) nor Cañon City (0.52 on only 20 samples, p = 0.22) is significant once the estimation of the site-month means is accounted for, although both would be under the ordinary test; that gap is a caution about short records rather than a finding. At Colorado Springs, Pueblo and Wheat Ridge, where records cover at most six months, anomaly correlations were negative and not significant.",

      "Sensitivity. Across the whole network, spatial averaging had the largest effect of any screening choice and the cloud threshold the smallest (Figure S2): pooled over the 24 h sites the Pearson correlation rises from 0.39 for single cells to 0.42 for 3 × 3 blocks and 0.43 for 5 × 5 blocks, and a stricter cloud threshold of 0.1 helps slightly (0.44 at 3 × 3) at the cost of 9 % of the samples. At the Colorado sites alone the gradient with block size is steeper, from 0.47 for the single cell to 0.56 for a 3 × 3 block and 0.61 for a 5 × 5 block, and restricting scans to 10:00-14:00 MST lowered correlations for every block size (0.38, 0.50 and 0.59).",

      "Column-surface relationship. From winter to summer, median surface HCHO on matched days increased from 2.09 to 3.56 µg m^{-3} (1.7-fold), whereas the median column increased from 2.18 to 6.63 × 10^{15} molecules cm^{-2} (3.0-fold). Median H_{eff} increased from 0.61 km in winter and 0.65 km in spring to 1.07 km in summer, and was 0.83 km in autumn (Figure S5). Across all matched days median H_{eff} was 0.82 km against a median TEMPO PBL height of 1.55 km, with the two closest in winter (0.61 against 0.64 km). By site, median H_{eff} ranged from 0.71 km at Grand Junction and 0.77 km at Commerce City to 1.06 km at Colorado Springs and 1.16 km at Cañon City, with 0.49 km at Wheat Ridge on its 10 matched days. Why Colorado's H_{eff} is low relative to the national value we can only suggest: its monitors sit at high elevation in semi-arid terrain, where the modelled boundary layer is deep in summer while HCHO may remain concentrated near its sources [[hypothesis - not tested here]]. The larger seasonal amplitude of the column is unlikely to arise solely from retrieval seasonality: across the Pandonia network TEMPO reproduces the observed seasonal amplitude closely, with winter, spring and autumn medians lower than summer by 62 %, 45 % and 29 % against 66 %, 48 % and 28 % in the co-located Pandora record{{rawat2026}}.",

      "Three-hour samples. Under the primary screening, 54 of 115 samples at Chatfield State Park (47 %) and 56 of 119 at Platteville (47 %) had a valid scan inside the 06:00-09:00 MST sampling window, with a median of two scans per window (Table S3). The window beginning when sampling ends had better coverage, 63 % and 60 % for 09:00-12:00; 12:00-15:00 gave 45 % and 54 %. No scan passed screening in the 03:00-06:00 window, and only seven Platteville samples in 15:00-18:00, because of the solar zenith angle limit. Inside the sampling window, 36 % of block cells failed the solar zenith angle criterion, against 4 % three hours later.",

      "The two sites behave differently, and that difference is the result. At Chatfield State Park the sampling window carries almost no day-to-day information (within-month anomaly r = -0.01, n = 47) while the window three hours later carries a good deal (0.48, n = 64, p = 0.001) and the window after that little (0.18, n = 34, p = 0.40). At Platteville the same three windows give 0.24 (n = 43, p = 0.16), 0.15 (n = 64, p = 0.26) and -0.01 (n = 51, p = 0.97): none of them significant, and no advantage for the later window. Pooled over both sites the values are 0.12 (n = 90, p = 0.26), 0.31 (n = 128, p = 0.0005) and 0.06 (n = 85, p = 0.62). Whole-period correlations show the same split: 0.24 and 0.56 at Chatfield, 0.48 and 0.36 at Platteville (Figures S7 and S8, Table S3).",

      "The 2023 extension adds samples at Platteville and none at Chatfield, and Platteville is the site whose ordering between the two windows differs, so we recomputed both sites on 2024-2025 alone (Table S5). Chatfield is unchanged, having no 2023 record. At Platteville the later window has no advantage in either period, which is what we claim; but the apparent preference for the sampling window is period-dependent. On 2024-2025 alone the two windows are indistinguishable (anomalies 0.25 on 32 samples against 0.26 on 51), whereas with 2023 the sampling window is nominally ahead (0.24 on 43 against 0.15 on 64). No Platteville anomaly correlation is significant in either period. We therefore claim only that Chatfield gains substantially from the later window and Platteville does not, and not that Platteville does better during sampling.",

      "Because coverage differs between windows we repeated the comparison on the samples usable in both, 50 at Chatfield and 52 at Platteville (42 and 38 once site-months with fewer than three samples are dropped for the anomalies). On within-month anomalies the gain from waiting three hours is 0.57 at Chatfield (from -0.16 to 0.41; Williams' test p = 0.008, bootstrap interval 0.21 to 0.88) and 0.07 at Platteville (0.17 to 0.24; p = 0.71, interval -0.20 to 0.35). Pooled over both sites it is 0.29 (0.02 to 0.31; Williams' test p = 0.045, bootstrap interval 0.05 to 0.52). We report the pooled value for completeness and rest nothing on it: it averages two monitors that disagree.",

      "The median TEMPO boundary layer height over the matched scans was 0.45 km during sampling, 1.50 km three hours later and 2.21 km six hours later, while the median effective mixing height stayed between 0.93 and 0.97 km at every lag; the columns themselves differ substantially from day to day at Chatfield State Park (r = 0.27 between the two windows) and agree more closely at Platteville (0.61) (Figure S9).",

      "Wildfire smoke. Across the network, 6268 of 16 383 sampling windows (38 %) were flagged smoke-affected, and {{n:smoke_n_affected}} of the {{n:smoke_n_flagged}} that also carried a usable TEMPO observation. Agreement was higher on smoke days at both well-sampled durations (Table S4, Figure S10). At the 24 h sites the correlation between surface HCHO and the column was {{n:smoke_r_24_none}} on smoke-free days (n = 3950), {{n:smoke_r_24_light}} under light smoke (n = 1854) and {{n:smoke_r_24_heavy}} under medium-heavy smoke (n = 302); at the 8 h sites it was {{n:smoke_r_8_none}} (n = 1675), {{n:smoke_r_8_light}} (n = 1599) and {{n:smoke_r_8_heavy}} (n = 235). Excluding smoke days lowered the day-to-day correlation from {{n:smoke_dd_24_all}} to {{n:smoke_dd_24_nosmoke}} at the 24 h sites (n = 5218 to 2645) and from {{n:smoke_dd_8_all}} to {{n:smoke_dd_8_nosmoke}} at the 8 h sites (n = 3509 to 1610). Median columns under smoke were roughly double those without, 4.07 against 8.83 \u00d7 10^{15} molecules cm^{-2} at the 24 h sites and 9.08 against 12.07 at the 8 h sites, while surface concentrations rose proportionately less; the improvement therefore follows the concentration dependence described above rather than anything specific to smoke chemistry. The 3 h classes hold 295, 95 and 12 samples and are not interpreted. The Colorado sites are not representative here either. Smoke covered 69 of their 453 24 h sample days (15 %) against 38 % of national windows, mainly in summer (51) and autumn (13) and most often at Commerce City (25), La Salle (19) and Grand Junction (12). Their whole-period correlation was lower on smoke days, 0.46 smoke-free (n = 276) against 0.36 under light smoke (n = 48) and 0.37 under medium-heavy smoke (n = 14), the opposite of the national pattern, although the day-to-day effect had the same sign, falling from 0.30 (n = 305) to 0.23 (n = 222 in 54 site-months) when smoke days were excluded. With 276 smoke-free samples against 3950, the national estimate is the better powered of the two. Smoke-flagged days are not simply clear days: within season the median cloud fraction was the same on smoke and smoke-free days (0.16 against 0.18 in summer, p = 0.52; 0.13 against 0.13 in autumn, p = 0.82).",

      "Site differences. Noise does not explain the differences between Colorado sites (Figure S6). Nor is Grand Junction's weakness a winter effect: its day-to-day correlation is 0.36 in winter, 0.27 in spring, 0.31 in summer and -0.07 in autumn, none of them significant, and pooled across sites the day-to-day correlation is similar in every season (0.29, 0.35, 0.26 and 0.31). Among the long records the strongest anomaly correlations were at La Salle and Commerce City on the northern Front Range and the weakest among long records at Grand Junction, a valley setting where persistent winter inversions could decouple surface concentrations from the column [[hypothesis - consider meteorological analysis]]. The records at Colorado Springs, Pueblo, Cañon City and Wheat Ridge are too short to characterise day-to-day skill."
    ]},

    // ------------------------------------------------------------- tables
    { table: {
      caption: "Table S1. Colorado monitoring sites, periods and sample counts. Matched days are samples with at least one TEMPO scan passing the primary screening. Medians are for all valid samples in each year.",
      header: ["Site (code)", "AQS ID", "County", "Lat (°N)", "Lon (°E)", "Period", "Samples", "Matched", "Median HCHO (µg m^{-3})"],
      widths: [1500, 1150, 800, 620, 700, 1050, 620, 620, 1966],
      rows: [
        ["24 h COATTS samples", "", "", "", "", "", "", "", ""],
        ["Grand Junction (GPCO)", "08-077-0018", "Mesa", "39.064", "−108.562", "2024–2025", "123", "105", "2.33 (2024), 2.70 (2025)"],
        ["Cañon City (CNCO)", "08-043-0004", "Fremont", "38.469", "−105.208", "Jul–Dec 2025", "26", "21", "1.41"],
        ["Wheat Ridge (JFCO)", "08-059-0015", "Jefferson", "39.781", "−105.108", "Oct–Dec 2025", "15", "10", "2.70"],
        ["Commerce City (ADCO)", "08-001-0010", "Adams", "39.828", "−104.936", "2024–2025", "120", "84", "2.95 (2024), 3.32 (2025)"],
        ["Colorado Springs (COCO)", "08-041-0017", "El Paso", "38.848", "−104.829", "Jul–Dec 2025", "29", "23", "2.46"],
        ["La Salle (LSCO)", "08-123-0015", "Weld", "40.261", "−104.706", "2024–2025", "110", "70", "2.09 (2024), 2.21 (2025)"],
        ["Pueblo (POCO)", "08-101-0017", "Pueblo", "38.236", "−104.581", "Jul–Dec 2025", "30", "25", "2.46"],
        ["3 h COOPs ozone-precursor samples", "", "", "", "", "", "", "", ""],
        ["Chatfield State Park (CHCO)", "08-035-0004", "Douglas", "39.534", "−105.070", "Feb 2024–Dec 2025", "115", "54^{a}", "1.96 (2024), 2.95 (2025)"],
        ["Platteville (PVCO)", "08-123-0008", "Weld", "40.209", "−104.824", "Aug 2023–Jul 2025", "119", "56^{a}", "2.58 (2023), 2.70 (2024), 2.95 (2025)"]
      ],
      notes: "^{a} Matched samples with at least one screened TEMPO scan inside the 06:00-09:00 MST sampling window. Identifiers are AQS site codes. Site names are CDPHE's; AQS records some stations under a different name, Wheat Ridge as Peak Expeditionary School and Pueblo as St. Charles Mesa Water District."
    }},

    
    { table: {
      caption: "Table S2. Site-level correlations reaching nominal and false-discovery-rate significance, by sample duration. Counts are over site-duration combinations with at least 10 matched samples, at the primary screening and with scans inside the sampling window. The Benjamini-Hochberg correction is applied across all 141 tests in each family. Whole-period counts use the ordinary correlation test; day-to-day counts use the within-site-month permutation test (Text S4), which is the stricter of the two - the ordinary test applied to the same anomalies would give 103 and 102 rather than 96 and 93. These counts are reported for completeness; the distribution of the correlations themselves is more informative, and no conclusion in the paper depends on a count.",
      header: ["Duration", "Sites", "Whole period, p < 0.05", "Whole period, BH q < 0.05", "Day-to-day, p < 0.05", "Day-to-day, BH q < 0.05"],
      widths: [1300, 1100, 1700, 1700, 1600, 1626],
      rows: [
        ["24 h", "97", "85", "84", "61", "58"],
        ["8 h", "40", "34", "34", "33", "33"],
        ["3 h", "4", "3", "3", "2", "2"],
        ["All", "141", "122", "121", "96", "93"]
      ]
    }},

    { table: {
      caption: "Table S3. Comparison of 3 h surface HCHO at the two Colorado sites (Chatfield 2024-2025, Platteville August 2023-2025) with the mean of valid TEMPO scans in the sampling window (06:00-09:00 MST) and in windows shifted 3 and 6 h later (primary screening, 3 × 3 cells).",
      header: ["", "Sampling window (06-09 MST)", "+3 h (09-12 MST)", "+6 h (12-15 MST)"],
      widths: [3200, 1975, 1925, 1926],
      rows: [
        ["Matched samples, Chatfield State Park", "54 of 115 (47 %)", "72 of 115 (63 %)", "52 of 115 (45 %)"],
        ["Matched samples, Platteville", "56 of 119 (47 %)", "72 of 119 (60 %)", "64 of 119 (54 %)"],
        ["Median scans per window", "2", "3", "1"],
        ["Pearson r, both sites", "0.36 (n = 110, p < 0.001)", "0.49 (n = 144, p < 0.001)", "0.18 (n = 116, p = 0.048)"],
        ["Pearson r, Chatfield State Park", "0.24 (n = 54, p = 0.08)", "0.56 (n = 72, p < 0.001)", "0.11 (n = 52, p = 0.44)"],
        ["Pearson r, Platteville", "0.48 (n = 56, p < 0.001)", "0.36 (n = 72, p = 0.002)", "0.24 (n = 64, p = 0.06)"],
        ["Within-month anomaly r, both sites", "0.12 (n = 90, p = 0.26)", "0.31 (n = 128, p = 0.0005)", "0.06 (n = 85, p = 0.62)"],
        ["Within-month anomaly r, Chatfield State Park", "-0.01 (n = 47, p = 0.93)", "0.48 (n = 64, p = 0.001)", "0.18 (n = 34, p = 0.40)"],
        ["Within-month anomaly r, Platteville", "0.24 (n = 43, p = 0.16)", "0.15 (n = 64, p = 0.26)", "-0.01 (n = 51, p = 0.97)"],
        ["Column coefficient with site and month effects", "0.035 ± 0.036 (p = 0.33)", "0.121 ± 0.036 (p = 0.001)", "-0.011 ± 0.029 (p = 0.71)"],
        ["Median H_{eff} / median TEMPO PBL height (km)", "0.97 / 0.45", "0.95 / 1.50", "0.93 / 2.21"]
      ],
      notes: "Anomaly p-values are within-site-month permutation values (Text S4); the smallest attainable is 0.0005. Whole-period p-values are the ordinary parametric test. The -3 h window (03-06 MST) contained no usable scans; the +9 h window (15-18 MST) yielded seven Platteville samples and is not shown. The column coefficient is in µg m^{-3} per 10^{15} molecules cm^{-2}."
    }},

    { table: {
      caption: "Table S4. Agreement between surface HCHO and the TEMPO column by HMS smoke class over the site during the sampling window, for every duration in the national comparison, at the primary screening with scans inside the sampling window. Medians are over matched samples. The 3 h medium–heavy class holds too few samples to interpret.",
      header: ["Duration", "Smoke class", "Matched samples", "Pearson r", "Surface HCHO (µg m^{-3})", "Column (10^{15} molecules cm^{-2})", "H_{eff} (km)"],
      rows: [
        ["24 h", "none", "3950", "0.29", "2.09", "4.07", "0.93"],
        ["24 h", "light", "1854", "0.38", "3.19", "8.83", "1.35"],
        ["24 h", "medium–heavy", "302", "0.47", "3.41", "8.52", "1.28"],
        ["8 h", "none", "1675", "0.22", "3.93", "9.08", "1.19"],
        ["8 h", "light", "1599", "0.42", "4.42", "12.07", "1.33"],
        ["8 h", "medium–heavy", "235", "0.49", "4.18", "11.11", "1.28"],
        ["3 h", "none", "295", "0.47", "3.81", "8.20", "0.99"],
        ["3 h", "light", "95", "0.34", "4.05", "10.98", "1.18"],
        ["3 h", "medium–heavy", "12", "0.70", "3.93", "9.82", "1.00"]
      ],
      notes: "Smoke-affected samples nationally: {{n:smoke_n_affected}} of {{n:smoke_n_flagged}} matched samples carrying a classification."
    }},

    { table: {
      caption: "Table S5. Does the 2023 extension create the difference between the two sites? Both 3 h sites recomputed on 2024-2025 alone, beside the record as analysed. Chatfield State Park reported no 2023 formaldehyde, so its values are identical in the two periods and are given once.",
      header: ["", "Sampling window (06-09 MST)", "+3 h (09-12 MST)", "+6 h (12-15 MST)"],
      widths: [2700, 2100, 2100, 2126],
      rows: [
        ["Platteville, whole-period r, 2024-2025 only", "0.54 (n = 44)", "0.46 (n = 56)", "0.25 (n = 51)"],
        ["Platteville, whole-period r, with 2023", "0.48 (n = 56)", "0.36 (n = 72)", "0.24 (n = 64)"],
        ["Platteville, anomaly r, 2024-2025 only", "0.25 (n = 32, p = 0.23)", "0.26 (n = 51, p = 0.07)", "-0.09 (n = 40, p = 0.60)"],
        ["Platteville, anomaly r, with 2023", "0.24 (n = 43, p = 0.16)", "0.15 (n = 64, p = 0.26)", "-0.01 (n = 51, p = 0.97)"],
        ["Chatfield State Park, anomaly r (no 2023 record)", "-0.01 (n = 47, p = 0.93)", "0.48 (n = 64, p = 0.001)", "0.18 (n = 34, p = 0.40)"]
      ],
      notes: "Anomaly p-values are within-site-month permutation values (Text S4). The later window has no advantage at Platteville in either period, which is the claim made in the text; the apparent preference for the sampling window appears only once 2023 is included, and no Platteville anomaly correlation is significant in either period."
    }},

    // ------------------------------------------------------------- figures
    { fig: { file: "fig0_site_map.png",
      caption: "Figure S1. The Colorado sites: seven COATTS sites sampling 24 h integrated formaldehyde (circles) and two COOPs sites sampling 3 h integrated formaldehyde (triangles), over terrain and county boundaries. Inset: the 123 sites across the contiguous United States that reported formaldehyde to AQS in 2024-2025, coloured by sample duration, with Colorado outlined. Elevation is from AWS terrain tiles; boundaries are US Census cartographic files." }},

    { fig: { file: "fig16_national_screening_sensitivity.png",
      caption: "Figure S2. Pooled Spearman correlation between surface HCHO and the mean TEMPO column at every site in the comparison, as a function of the maximum effective cloud fraction and the averaging block (1 x 1, 3 x 3 or 5 x 5 cells), for scans inside the sampling window. Panels are sample duration; symbol size is the number of matched samples. The primary screening used throughout is a cloud fraction of 0.2 with a 3 x 3 block." }},

    { fig: { file: "fig8_threeh_sensitivity.png",
      caption: "Figure S3. Pooled Spearman correlation between 3 h surface HCHO and the window-mean TEMPO column as a function of the maximum effective cloud fraction and the averaging block, for each lag from the sampling window. Symbol size shows the number of matched samples." }},

    { fig: { file: "fig11_national_lag_curve.png",
      caption: "Figure S4. Pooled correlation between sub-daily surface HCHO and the mean TEMPO column as a function of the lag of the TEMPO window from the sampling window, for the 3 h and 8 h sites. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site-month means. Labels give the number of matched samples. Because the sites pooled here sample different windows, a given lag corresponds to different times of day at different sites, which is why the main text reports agreement by window start hour instead." }},

    
    
    
    
    { fig: { file: "fig3_effective_height_by_month.png",
      caption: "Figure S5. Monthly distributions of the effective mixing height H_{eff} on matched days by Colorado site. Orange diamonds show the median TEMPO PBL height on the same days. The vertical axis is truncated at the 98th percentile." }},

    { fig: { file: "figS4_noise_ceiling.png",
      caption: "Figure S6. Observed day-to-day (within-month anomaly) correlation at each Colorado 24 h site, with the ceiling implied by TEMPO retrieval noise alone, estimated from differences between successive scans and from the uncertainties reported in the product (3 × 3 blocks)." }},

    { fig: { file: "fig7_threeh_scatter.png",
      caption: "Figure S7. Three-hour surface HCHO at Chatfield State Park (CHCO, 2024-2025) and Platteville (PVCO, August 2023-July 2025) versus the mean TEMPO column in the sampling window (06:00-09:00 MST) and in windows shifted by -3, +3, +6 and +9 h. The -3 h row is empty because no scan passed screening, and the +9 h row holds only seven Platteville samples. Colours denote season; lines show reduced major axis fits where the Pearson correlation is significant." }},

    { fig: { file: "fig10_threeh_lag_curve.png",
      caption: "Figure S8. Agreement between 3 h surface HCHO and the mean TEMPO column as a function of the lag between the sampling window (06:00-09:00 MST) and the satellite window, for the whole period and for within-month anomalies. Labels give the number of matched samples. Agreement is highest in the window beginning when sampling ends (09:00-12:00 MST), when the median TEMPO boundary layer height has risen from 0.5 to 1.5 km; the pooled curve averages two sites that differ (Table S3)." }},

    { fig: { file: "figS3_threeh_window_columns.png",
      caption: "Figure S9. TEMPO columns for the same 3 h samples, measured in the sampling window (06:00-09:00 MST) and three hours later. The two differ substantially from day to day at Chatfield State Park and agree more closely at Platteville; the dashed line is 1:1." }},

    { fig: { file: "fig17_national_smoke.png",
      caption: "Figure S10. Pearson correlation between surface HCHO and the TEMPO column by HMS smoke class over the site during the sampling window, for the 24 h, 8 h and 3 h sites nationally. Labels are the number of matched samples. Agreement rises with smoke at both well-sampled durations; the 3 h medium–heavy class holds twelve samples and is not interpreted." }},

    { fig: { file: "fig12_national_by_start_hour.png",
      caption: "Figure S11. Correlation between sub-daily surface HCHO and the mean TEMPO column, grouped by the local standard hour at which the sampling window begins, using only scans inside the sampling window. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site-month means. In the 3 h panel, the windows beginning at 05:00, 12:00 and 16:00 are the two California sites and the window beginning at 06:00 is the two Colorado sites; in the 8 h panel each point pools all 40 sites. Labels give the number of matched samples." }}
  ]
};
