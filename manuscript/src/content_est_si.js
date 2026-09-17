// content_est_si.js - Supporting Information for the ES&T version.
//
// Everything moved out of the main text: the detailed data descriptions and
// methods, the Colorado case-study results, and 14 figures and 5 tables.
// Numbering follows order of first citation in the main text:
//   Figure S1        Methods, surface measurements
//   Figures S2, S3   Methods, TEMPO matching (sensitivity)
//   Figure S4        Results, sampling time (pooled lag curves)
//   Figures S5-S14   Results, Colorado case study
//   Tables S1, S2    Methods, surface measurements
//   Table S3         Methods, statistics
//   Tables S4, S5    Results, Colorado case study
module.exports = {
  title: "Supporting Information for: Hourly Satellite Formaldehyde Columns and Routine Surface Air Toxics Monitoring: Day-to-Day Agreement at 123 United States Sites",

  authors: ["[[Author list to match the main text.]]"],

  contents: "Contents: Supporting text S1-S7; Figures S1-S14; Tables S1-S5. 20 pages.",

  sections: [
    { h1: "S1. Colorado case-study networks", p: [
      "CDPHE operates the Colorado Air Toxics Trends (COATTS) network, whose first phase became fully operational on 1 January 2024 and second phase on 1 July 2025{{cdpherepo2026}}. We used formaldehyde from the 2024 and 2025 annual data packets for seven sites (Table S1, Figure S1). Commerce City (Adams County), La Salle (Weld County) and Grand Junction (Mesa County) sampled throughout both years; Colorado Springs (El Paso County), Pueblo (Pueblo County) and Cañon City (Fremont County) began in July 2025; and Wheat Ridge (Jefferson County) began in October 2025. Samples are 24 h integrated collections on a 1-in-6 day schedule reported in µg m^{-3}, identified in the packets by AQS parameter code 43502 and method code 202, at standard conditions (25 °C, 1 atm).",

      "The same samples are archived in AQS{{epaaqs2026}}, which records the time each sample began. For all seven sites this is 00:00 local standard time with a 24 h duration, confirming midnight-to-midnight sampling on the stamped date. AQS gives the method as DNPH-coated silica cartridges with a potassium iodide ozone scrubber, analysed by HPLC with ultraviolet detection, following Compendium Method TO-11A{{epato11a1999}}; the same method is used at every site. AQS identifies Grand Junction (08-077-0018) as a National Air Toxics Trends Station{{epanatts2025}}.",

      "Two ozone-precursor sites, Chatfield State Park in Douglas County (CHCO) and Platteville in Weld County (PVCO), belong to CDPHE's COOPs network [[expand acronym]], discontinued at the end of June 2026; its historical data remain available. Both report formaldehyde as 3 h samples, time-stamped 09:00 in the data packets. AQS holds the same samples with a start time of 06:00 MST and a duration of 3 h, so the packet stamp is the end of sampling and the sampling window is 06:00-09:00 MST. The 2025 packets give the duration explicitly (10 800 s); the 2024 packets do not, but CDPHE confirmed that they contain the same 3 h samples [[decide how to cite CDPHE's answers]]. Platteville also reported formaldehyde to AQS through 2023, on the same 06:00 start and 3 h duration; those samples are taken from AQS rather than from CDPHE's 2023 ozone-precursor summary workbook, because AQS carries the sample start time and the workbook carries only the 09:00 end stamp. Across the 25 sample days the two sources agree, with a median ratio of 1.002. Chatfield reported no 2023 formaldehyde to AQS and none appears in the workbook. The window does not move with daylight saving: AQS records sample times in local standard time, and for every Colorado sample in this study the recorded start is seven hours behind the corresponding GMT stamp in all twelve months, so the 06:00-09:00 window is the same clock interval in summer as in winter. This matters for the lag analysis of Sect. 4, which would otherwise compare a summer window with a winter one displaced by an hour."
    ]},

    { h1: "S2. Quality control of the Colorado data packets", p: [
      "The 2025 packets list quality-control (QC) samples on the same dates as ambient samples, distinguished by the QC code of CDPHE's AQDx data format: code 0 for ambient samples and code 8 for QC samples, which carry qualifiers such as AY (\"Q C Control Points (zero/span)\") and are typically near 0.05 µg m^{-3}. Following CDPHE guidance we kept ambient samples only and excluded any record carrying an AQS null data qualifier, which marks a value as invalid or as a QC/QA measurement; the list of null data qualifiers was read from each data packet. This removed the 59 QC rows in the 2025 packets and one 2024 record without a concentration (qualifier AV, power failure); no ambient formaldehyde record with a reported concentration carried a null data qualifier. Averaging the QC rows with same-day ambient samples would have biased roughly one sample per site per month low by about half. Quality assurance and informational qualifiers were retained, and duplicate ambient samples on the same date were averaged. The resulting record contains 453 site-days with valid concentrations.",

      "For the 3 h sites, QC samples and records carrying null data qualifiers were removed in the same way (25 QC rows in the 2025 packets; the 2024 packets report QC samples on a separate sheet). Two 2025 samples, one at each site on 12 June 2025, carry a 23:59 stamp in the packets; AQS holds no such stamps, so we treat them as a packet artefact and exclude them. The resulting record contains 115 samples at Chatfield State Park (8 February 2024-27 December 2025) and 119 at Platteville (4 August 2023-18 July 2025; later 2025 samples were not collected because of sampling problems), of which 114 and 117 enter the analysis: one sample at each site carries the 23:59 stamp described above, and one Platteville record has no concentration."
    ]},

    { h1: "S3. TEMPO extraction and the national comparison", p: [
      "TEMPO is an ultraviolet-visible grating spectrometer in geostationary orbit that scans North America from east to west approximately hourly during daylight{{zoogman2017}}. Level 3 files grid Level 2 retrievals from each scan to a regular 0.02° × 0.02° grid using area weighting. Each file provides the HCHO vertical column and its uncertainty, a main data quality flag, effective cloud fraction, snow and ice fraction, solar zenith angle and, new in version 4, a planetary boundary layer height as support data{{nasaguide2025}} [[check source of the PBL height field]].",

      "For the Colorado case study, granules were identified with NASA's Common Metadata Repository and assigned to a sampling period when the midpoint of the scan's time coverage fell within it. For the 24 h samples this gave 1582 granules on 146 of the 151 sampling dates; no TEMPO observations were available on the other five. For the 3 h samples, scans between 03:00 and 19:00 MST were retrieved (982 granules on 146 of the 153 sampling dates).",

      "The national arm repeats the analysis at every AQS site with three differences forced by its scale. First, extraction: requesting a separate OPeNDAP subset for each of 123 sites would multiply the number of requests by the number of sites, so sites were grouped into 50 clusters of at most 1.25° latitude by 2.5° longitude, one subset was requested per cluster and scan, and the 5 × 5 cell block around each site was cut from it afterwards. Only scans a cluster's samples actually require were retrieved: the days a site sampled, and for sub-daily samples the sampling window padded by 3 h on each side. This produced 88 622 cluster-scans and 3.97 million cell records. Second, matching is by UTC hour set as described in the main text; because every AQS sampling window begins on the hour, the assignment is unambiguous at hourly resolution. Lags are applied only to sub-daily samples, since a 24 h window shifted by a few hours is almost the same window. Third, the pooled regression uses ordinary least squares with fixed effects for site and calendar month rather than a mixed model, because the number of sites is large. Wildfire smoke is not classified in the national arm."
    ]},

    { h1: "S4. Statistical detail", p: [
      "Because both variables contain measurement error, we report reduced major axis (RMA) regression slopes with 95 % confidence intervals from 1000 bootstrap resamples. Slopes are given for every group in the tables whether or not the correlation is significant; where r is near zero the RMA slope, being the ratio of standard deviations carrying the sign of r, has an unstable sign, and the bootstrap interval shows that directly. The figures draw a fitted line only where the Pearson correlation reaches p < 0.05, so as not to suggest a relationship the data do not support. Intervals for pooled slopes resample sites with replacement, because the same monitors contribute many samples each; intervals for a single site resample that site's own samples and are descriptive, the 1-in-6 day schedule leaving little day-to-day dependence to preserve. For the Colorado case study we fitted linear mixed-effects models{{bates2015}} with surface HCHO as the response, the column as a fixed effect, a random intercept for site and fixed effects for either season or calendar month. For the 3 h samples, with only two sites, we used ordinary least squares with fixed effects for site and calendar month. Where correlations are reported for many sites at once we give both the number significant at a nominal p < 0.05 and the number surviving a Benjamini-Hochberg false-discovery-rate correction applied across that family of tests (Table S3), using the permutation p-values described below for day-to-day correlations and the ordinary test for whole-period ones; the distribution of the correlations themselves is more informative than either count.",

      "Correlations between within-site-month anomalies are tested by permutation rather than by the ordinary correlation test. The site-month means are estimated from the same observations that then enter the correlation, so the parametric p-value spends degrees of freedom it does not have and is optimistic. We permute one variable within each site × year-month stratum and recompute the pooled correlation 2000 times, comparing the observed |r| with the permutation distribution; because a permutation leaves a stratum's mean unchanged, this holds the removed structure fixed rather than assuming it away. Every anomaly p-value reported here is such a permutation value, and the smallest attainable with 2000 permutations is 1/2001 = 0.0005. Whole-period correlations, Williams' tests for dependent correlations and the fixed-effects models use their usual parametric tests.",

      "The uncertainty attached to a screened scan is the root mean square of the reported uncertainties of the passing cells in the block, not a propagated uncertainty for their mean. This is the fully correlated limit: it assumes neighbouring retrieval errors move together and so takes no √n reduction from averaging. We adopt it deliberately, as the conservative choice, and because the noise analysis (Text S5, Figure S10) shows that the empirical scan-to-scan spread, not the reported uncertainty, is what limits agreement; both the correlated and independent limits of the reported uncertainty are given there for comparison.",

      "Where two correlations share a variable — for example the surface concentration correlated with the column in two different windows — we compare them with Williams' test for dependent correlations{{steiger1980}} on the samples usable in both, with a bootstrap confidence interval for the difference. We use the spread of TEMPO surface pressure across each averaging block as an index of terrain heterogeneity. As a control for the 3 h lag analysis we repeat the window comparison at the 24 h sites, where the sample spans every window, so that any difference between windows reflects the retrievals rather than the sampling time."
    ]},

    { h1: "S5. Retrieval-noise estimator", p: [
      "Differences between successive valid scans of the same site and day, divided by the square root of two, give an empirical noise standard deviation for a single scan. This is an upper bound, because the column genuinely changes between scans, and it is blind to errors that persist through a day. Squaring this quantity gives a single-scan noise variance, and dividing that variance by the number of valid scans estimates the noise variance of the daily mean; comparing it with the variance of the within-month anomalies gives the share of that variance which is noise and the correlation ceiling that noise alone implies, the square root of one minus the noise share. We computed the same quantity from the uncertainties reported in the product, with block cells treated as fully correlated and as independent (Figure S10)."
    ]},

    { h1: "S6. Smoke classification", p: [
      "A sampling period was classified as smoke-affected when a NOAA Hazard Mapping System polygon covered the site and the polygon's start-end interval overlapped the sampling window{{rolph2009}}{{brey2018}}. We used the daily HMS shapefiles{{noaahms2026}} for all 324 days touched by the sampling windows; none were missing. Over the study sites, HMS polygon start-end intervals clustered in the early morning (roughly 11:00-15:00 UTC) and the afternoon (roughly 18:00-24:00 UTC). HMS polygons are analyst delineations from discrete visible satellite imagery, so an hour not covered by any polygon interval is not thereby established as free of smoke, and a short sampling window can fall between analysis times on a day when smoke was present throughout. We consequently widened each sampling window by 3 h on either side before testing temporal overlap, and also recorded whether any polygon covered the site on the relevant HMS days regardless of time. This had negligible influence on classification: strict temporal overlap identified 39 of the 233 three-hour sampling windows as smoke-affected against 41 with the widened window, and the 453 24 h samples were classified identically. Each period was assigned the highest density class of the overlapping polygons and grouped as none, light or medium-heavy. Classifications of short sampling periods using HMS should allow for the discrete times at which the analyses are made."
    ]},

    { h1: "S7. Software and reproducibility", p: [
      "All processing was done in R version 4.3.3{{rcore2024}}, using httr2 for data access, ncdf4 for netCDF files, sf for spatial operations{{pebesma2018}} and lme4 for mixed-effects models{{bates2015}}. A single script downloads the CDPHE data packets, queries and subsets TEMPO granules, downloads HMS shapefiles, and produces all tables and figures. The analysis period is fixed, downloaded inputs are cached with MD5 checksums, the exact OPeNDAP constraint expression is recorded, and each run logs its configuration and R session information. The terrain in Figure S1 comes from the AWS Terrain Tiles on the Registry of Open Data on AWS{{aws}}, retrieved with the elevatr R package{{hollister2025}}, and the state and county boundaries are US Census cartographic boundary files{{census2023}}."
    ]},

    { h1: "S8. Colorado case-study results", p: [
      "Availability. Of the 453 site-days with valid 24 h samples, 338 (74.6 %) had at least one valid TEMPO scan under the primary screening, and 15 had no TEMPO granules (Table S1). Coverage ranged from 63.6 % at La Salle to 85.4 % at Grand Junction, with a median of 4-5 valid scans per sample day at all sites except Wheat Ridge (2). Coverage was lowest in winter: 52.1 % of December-February sample days were matched, against 76.7 % in spring, 90.2 % in summer and 81.1 % in autumn (Figure S5, Table S5).",

      "Agreement. Surface HCHO and TEMPO columns followed the same seasonal cycle, with summer maxima at all sites with year-round records (Figure S6). Across all sites, daily mean columns correlated with surface HCHO at r = 0.56 (ρ = 0.57, n = 338; Table S2, Figure S7). The RMA slope was 0.39 (0.35-0.44) µg m^{-3} per 10^{15} molecules cm^{-2} with an intercept of 1.26 µg m^{-3}; median values were 2.66 µg m^{-3} at the surface and 3.50 × 10^{15} molecules cm^{-2} in the column. Correlations were significant at five sites, from 0.49 at Pueblo to 0.74 at La Salle and 0.83 at Cañon City, and not significant at Colorado Springs (0.29, n = 23) or Wheat Ridge (-0.13, n = 10). Within individual seasons pooled correlations were weaker: 0.24 in winter (p = 0.06), 0.21 in spring (p = 0.07), 0.26 in summer (p = 0.02) and 0.52 in autumn (p < 0.001). In the mixed-effects model with season effects the column coefficient was 0.140 ± 0.020 µg m^{-3} per 10^{15} molecules cm^{-2} (t = 7.1); with calendar-month effects it decreased to 0.096 ± 0.022 (t = 4.3), confirming that part of the whole-period association is seasonal.",

      "After removing site and calendar-month means the pooled day-to-day correlation was 0.30 (n = 305 in 70 site-months, p = 0.0005; Figure S8), with an ordinary least squares slope of 0.098 µg m^{-3} per 10^{15} molecules cm^{-2}. Day-to-day agreement was strongest at La Salle (0.62, n = 56) and Commerce City (0.48, n = 74), both significant under the permutation test (p = 0.0005), and weaker at Grand Junction (0.21, n = 101). Neither Grand Junction (p = 0.10) nor Cañon City (0.55 on only 20 samples, p = 0.16) is significant once the estimation of the site-month means is accounted for, although both would be under the ordinary test; that gap is a caution about short records rather than a finding. At Colorado Springs, Pueblo and Wheat Ridge, where records cover at most six months, anomaly correlations were negative and not significant.",

      "Sensitivity. Spatial averaging had the largest effect (Figure S2). With a cloud fraction threshold of 0.2 and all daylight scans, the pooled Pearson correlation increased from 0.47 for the single cell containing the site to 0.56 for a 3 × 3 block and 0.61 for a 5 × 5 block. Restricting scans to 10:00-14:00 MST lowered correlations for every block size (0.38, 0.50 and 0.59). Changing the cloud fraction threshold between 0.1 and 0.3 changed all-day correlations by at most 0.03 for a given block size, and midday correlations by up to 0.06, with the strictest threshold giving the highest values. The number of matched site-days ranged from 294 to 355 across these choices.",

      "Column-surface relationship. From winter to summer, median surface HCHO on matched days increased from 2.12 to 3.51 µg m^{-3} (1.7-fold), whereas the median column increased from 2.18 to 6.63 × 10^{15} molecules cm^{-2} (3.0-fold). Median H_{eff} increased from 0.62 km in winter and 0.65 km in spring to 1.06 km in summer, and was 0.83 km in autumn (Figure S9). Across all matched days median H_{eff} was 0.83 km against a median TEMPO PBL height of 1.55 km, with the two closest in winter (0.62 against 0.64 km). By site, median H_{eff} ranged from 0.72 km at Grand Junction and 0.76 km at Commerce City to 1.06 km at Colorado Springs and 1.13 km at Cañon City. Why Colorado's H_{eff} is low relative to the national value we can only suggest: its monitors sit at high elevation in semi-arid terrain, where the modelled boundary layer is deep in summer while HCHO may remain concentrated near its sources [[hypothesis - not tested here]]. The larger seasonal amplitude of the column is unlikely to arise solely from retrieval seasonality: across the Pandonia network TEMPO reproduces the observed seasonal amplitude closely, with winter, spring and autumn medians lower than summer by 62 %, 45 % and 29 % against 66 %, 48 % and 28 % in the co-located Pandora record{{rawat2026}}.",

      "Three-hour samples. Under the primary screening, 54 of 114 samples at Chatfield State Park (47 %) and 54 of 117 at Platteville (46 %) had a valid scan inside the 06:00-09:00 MST sampling window, with a median of two scans per window (Table S4). Windows shifted later had better coverage: 63 % and 60 % for 09:00-12:00, and 45 % and 54 % for 12:00-15:00. No scan passed screening in the 03:00-06:00 window, and only seven Platteville samples in 15:00-18:00, because of the solar zenith angle limit. Inside the sampling window, 37 % of block cells failed the solar zenith angle criterion, against 4 % three hours later.",

      "The two sites behave differently, and that difference is the result. At Chatfield State Park the sampling window carries almost no day-to-day information (within-month anomaly r = 0.01, n = 46) while the window three hours later carries a good deal (0.48, n = 63, p < 0.001) and the window after that little (0.24, n = 31, p = 0.25). At Platteville the same three windows give 0.25 (n = 43, p = 0.13), 0.16 (n = 58, p = 0.24) and -0.02 (n = 51, p = 0.92): none of them significant, and no advantage for the later window. Pooled over both sites the values are 0.14 (n = 89, p = 0.21), 0.32 (n = 121, p = 0.002) and 0.07 (n = 82, p = 0.60). Whole-period correlations show the same split: 0.22 and 0.57 at Chatfield, 0.48 and 0.36 at Platteville (Figures S11 and S12, Table S4).",

      "The 2023 extension adds samples at Platteville and none at Chatfield, and Platteville is the site whose ordering between the two windows differs, so we recomputed both sites on 2024-2025 alone (Table S6). Chatfield is unchanged, having no 2023 record. At Platteville the later window has no advantage in either period, which is what we claim; but the apparent preference for the sampling window is period-dependent. On 2024-2025 alone the two windows are indistinguishable (anomalies 0.26 on 32 samples against 0.28 on 45), whereas with 2023 the sampling window is nominally ahead (0.25 on 43 against 0.16 on 58). No Platteville anomaly correlation is significant in either period. We therefore claim only that Chatfield gains substantially from the later window and Platteville does not, and not that Platteville does better during sampling.",

      "Because coverage differs between windows we repeated the comparison on the samples usable in both, 50 at each site. On within-month anomalies the gain from waiting three hours is 0.55 at Chatfield (from -0.15 to 0.39; Williams' test p = 0.011, bootstrap interval 0.23 to 0.85) and 0.07 at Platteville (0.17 to 0.24; p = 0.73, interval -0.22 to 0.35). Pooled over both sites it is 0.27 (0.03 to 0.30; Williams' test p = 0.057, bootstrap interval 0.04 to 0.50). We report the pooled value for completeness and rest nothing on it: it averages two monitors that disagree, and the test and the interval do not agree about it either.",

      "The median TEMPO boundary layer height over the matched scans was 0.47 km during sampling, 1.50 km three hours later and 2.21 km six hours later, while the median effective mixing height stayed between 0.94 and 0.99 km at every lag; the columns themselves differ substantially from day to day at Chatfield State Park (r = 0.26 between the two windows) and agree more closely at Platteville (0.60) (Figure S13).",

      "Wildfire smoke. HMS smoke covered the sites during 69 of 453 24 h sample days (15 %): 55 light and 14 medium-heavy, mainly in summer (51) and autumn (13) and most often at Commerce City (25), La Salle (19) and Grand Junction (12). For the 3 h samples, 41 of 233 sampling windows were smoke-affected. TEMPO coverage was not reduced on smoke days; the apparent difference across the year largely reflects the absence of smoke in winter (Table S5). Within season, smoke days had higher surface HCHO and higher columns: in summer, median surface HCHO was 3.29, 3.57 and 4.36 µg m^{-3} and the median column 6.26, 7.04 and 7.31 × 10^{15} molecules cm^{-2} on smoke-free, light and medium-heavy days. Correlations between surface HCHO and the column were 0.46 on smoke-free days (n = 276), 0.36 on light-smoke days (n = 48, p = 0.01) and 0.36 on medium-heavy days (n = 14, p = 0.21; ρ = 0.60, p = 0.02) (Figure S14). Excluding smoke days reduced the day-to-day correlation from 0.30 (n = 305) to 0.23 (n = 222 in 54 site-months). For the 3 h samples, smoke mattered most in the window three hours after sampling, where the correlation was 0.55 in smoke-affected windows (n = 35) against 0.37 without smoke (n = 107). Smoke-flagged days are not simply clear days: within season the median cloud fraction was the same on smoke and smoke-free days (0.16 against 0.19 in summer, p = 0.52; 0.13 against 0.13 in autumn, p = 0.82).",

      "Site differences. Noise does not explain the differences between Colorado sites (Figure S10). Nor is Grand Junction's weakness a winter effect: its day-to-day correlation is 0.38 in winter, 0.25 in spring, 0.29 in summer and -0.06 in autumn, none of them significant, and pooled across sites the day-to-day correlation is similar in every season (0.30, 0.34, 0.25 and 0.31). The strongest anomaly correlations were at La Salle and Commerce City on the northern Front Range and the weakest among long records at Grand Junction, a valley setting where persistent winter inversions could decouple surface concentrations from the column [[hypothesis - consider meteorological analysis]]. The records at Colorado Springs, Pueblo, Cañon City and Wheat Ridge are too short to characterise day-to-day skill."
    ]},

    // ------------------------------------------------------------- tables
    { table: {
      caption: "Table S1. Colorado case-study monitoring sites, periods and sample counts. Matched days are samples with at least one TEMPO scan passing the primary screening. Medians are for all valid samples in each year.",
      header: ["Site (code)", "AQS ID", "County", "Lat (°N)", "Lon (°E)", "Period", "Samples", "Matched", "Median HCHO (µg m^{-3})"],
      widths: [1500, 1150, 800, 620, 700, 1050, 620, 620, 1966],
      rows: [
        ["24 h COATTS samples", "", "", "", "", "", "", "", ""],
        ["Grand Junction (GPCO)", "08-077-0017/0018", "Mesa", "39.064", "−108.562", "2024–2025", "123", "105", "2.36 (2024), 2.69 (2025)"],
        ["Cañon City (CNCO)", "08-043-0004", "Fremont", "38.469", "−105.208", "Jul–Dec 2025", "26", "21", "1.46"],
        ["Wheat Ridge (JFCO)", "08-059-0015", "Jefferson", "39.781", "−105.108", "Oct–Dec 2025", "15", "10", "2.69"],
        ["Commerce City (ADCO)", "08-001-0010", "Adams", "39.828", "−104.936", "2024–2025", "120", "84", "2.93 (2024), 3.33 (2025)"],
        ["Colorado Springs (COCO)", "08-041-0017", "El Paso", "38.848", "−104.829", "Jul–Dec 2025", "29", "23", "2.41"],
        ["La Salle (LSCO)", "08-123-0015", "Weld", "40.261", "−104.706", "2024–2025", "110", "70", "2.06 (2024), 2.22 (2025)"],
        ["Pueblo (POCO)", "08-101-0017", "Pueblo", "38.236", "−104.581", "Jul–Dec 2025", "30", "25", "2.51"],
        ["3 h COOPs ozone-precursor samples", "", "", "", "", "", "", "", ""],
        ["Chatfield State Park (CHCO)", "08-035-0004", "Douglas", "39.534", "−105.070", "Feb 2024–Dec 2025", "114", "54^{a}", "1.96 (2024), 2.92 (2025)"],
        ["Platteville (PVCO)", "08-123-0008", "Weld", "40.209", "−104.824", "Jan 2024–Jul 2025", "92", "42^{a}", "2.66 (2024), 2.96 (2025)"]
      ],
      notes: "^{a} Matched samples with at least one screened TEMPO scan inside the 06:00-09:00 MST sampling window. Site names and AQS identifiers are as recorded in AQS."
    }},

    { table: {
      caption: "Table S2. Agreement between daily mean TEMPO HCHO columns and 24 h surface HCHO by Colorado site (primary screening). RMA slopes (µg m^{-3} per 10^{15} molecules cm^{-2}, bootstrap 95 % confidence interval) are shown where the Pearson correlation is significant. Anomalies are deviations from site and calendar-month means (site-months with ≥ 3 samples).",
      header: ["Site", "n", "r", "ρ", "RMA slope", "Anomaly n", "Anomaly r"],
      widths: [2400, 800, 900, 900, 1826, 1100, 1100],
      rows: [
        ["Grand Junction", "105", "0.53", "0.51", "0.34 (0.27–0.43)", "101", "0.21"],
        ["Cañon City", "21", "0.83", "0.71", "0.43 (0.33–0.60)", "20", "0.55"],
        ["Wheat Ridge", "10", "−0.13^{*}", "0.09^{*}", "–", "8", "−0.41^{*}"],
        ["Commerce City", "84", "0.63", "0.60", "0.45 (0.39–0.53)", "74", "0.48"],
        ["Colorado Springs", "23", "0.29^{*}", "0.41^{*}", "–", "23", "−0.24^{*}"],
        ["La Salle", "70", "0.74", "0.76", "0.31 (0.25–0.38)", "56", "0.62"],
        ["Pueblo", "25", "0.49", "0.58", "0.28 (0.20–0.38)", "23", "−0.23^{*}"],
        ["All sites", "338", "0.56", "0.57", "0.39 (0.35–0.44)", "305", "0.30"]
      ],
      notes: "^{*} Not significant (p ≥ 0.05). Anomaly p-values are optimistic (Supporting text S4)."
    }},

    { table: {
      caption: "Table S3. Site-level correlations reaching nominal and false-discovery-rate significance, by sample duration. Counts are over site-duration combinations with at least 10 matched samples, at the primary screening and with scans inside the sampling window. The Benjamini-Hochberg correction is applied across all 141 tests in each family. Whole-period counts use the ordinary correlation test; day-to-day counts use the within-site-month permutation test (Text S3), which is the stricter of the two - the ordinary test applied to the same anomalies would give 103 and 102 rather than 96 and 93. These counts are reported for completeness; the distribution of the correlations themselves is more informative, and no conclusion in the paper depends on a count.",
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
      caption: "Table S4. Comparison of 3 h surface HCHO at the two Colorado sites (Chatfield 2024-2025, Platteville August 2023-2025) with the mean of valid TEMPO scans in the sampling window (06:00-09:00 MST) and in windows shifted 3 and 6 h later (primary screening, 3 × 3 cells).",
      header: ["", "Sampling window (06-09 MST)", "+3 h (09-12 MST)", "+6 h (12-15 MST)"],
      widths: [3200, 1975, 1925, 1926],
      rows: [
        ["Matched samples, Chatfield State Park", "54 of 114 (47 %)", "72 of 114 (63 %)", "51 of 114 (45 %)"],
        ["Matched samples, Platteville", "54 of 117 (46 %)", "70 of 117 (60 %)", "63 of 117 (54 %)"],
        ["Median scans per window", "2", "3", "1"],
        ["Pearson r, both sites", "0.35 (n = 108, p < 0.001)", "0.49 (n = 142, p < 0.001)", "0.18 (n = 114, p = 0.06)"],
        ["Pearson r, Chatfield State Park", "0.22 (n = 54, p = 0.10)", "0.57 (n = 72, p < 0.001)", "0.10 (n = 51, p = 0.48)"],
        ["Pearson r, Platteville", "0.48 (n = 54, p < 0.001)", "0.36 (n = 70, p = 0.002)", "0.23 (n = 63, p = 0.07)"],
        ["Within-month anomaly r, both sites", "0.14 (n = 89, p = 0.21)", "0.32 (n = 121, p = 0.002)", "0.07 (n = 82, p = 0.60)"],
        ["Within-month anomaly r, Chatfield State Park", "0.01 (n = 46, p = 0.97)", "0.48 (n = 63, p < 0.001)", "0.24 (n = 31, p = 0.25)"],
        ["Within-month anomaly r, Platteville", "0.25 (n = 43, p = 0.13)", "0.16 (n = 58, p = 0.24)", "-0.02 (n = 51, p = 0.92)"],
        ["Column coefficient with site and month effects", "0.033 ± 0.036 (p = 0.36)", "0.127 ± 0.036 (p < 0.001)", "-0.015 ± 0.030 (p = 0.62)"],
        ["Median H_{eff} / median TEMPO PBL height (km)", "0.99 / 0.47", "0.95 / 1.50", "0.94 / 2.21"]
      ],
      notes: "Anomaly p-values are within-site-month permutation values (Text S3); the smallest attainable is 0.0005. Whole-period p-values are the ordinary parametric test. The -3 h window (03-06 MST) contained no usable scans; the +9 h window (15-18 MST) yielded seven Platteville samples and is not shown. The column coefficient is in µg m^{-3} per 10^{15} molecules cm^{-2}."
    }},

    { table: {
      caption: "Table S5. TEMPO coverage, surface HCHO, TEMPO column and effective mixing height by season and HMS smoke class for the Colorado 24 h samples. Surface medians are for all sample days; column and H_{eff} medians are for matched days.",
      header: ["Season", "Smoke class", "Sample days", "Matched (%)", "Surface HCHO (µg m^{-3})", "Column (10^{15} molecules cm^{-2})", "H_{eff} (km)"],
      widths: [1000, 1500, 1200, 1200, 1500, 1600, 1026],
      rows: [
        ["DJF", "none", "121", "52.1", "2.01", "2.18", "0.62"],
        ["MAM", "none", "90", "76.7", "2.13", "2.71", "0.65"],
        ["MAM", "light", "5", "100", "2.73", "3.59", "0.72"],
        ["JJA", "none", "41", "90.2", "3.29", "6.26", "1.06"],
        ["JJA", "light", "42", "83.3", "3.57", "7.04", "1.12"],
        ["JJA", "medium–heavy", "9", "100", "4.36", "7.31", "0.96"],
        ["SON", "none", "132", "81.1", "2.54", "3.21", "0.80"],
        ["SON", "light", "8", "100", "3.47", "5.59", "0.98"],
        ["SON", "medium–heavy", "5", "100", "3.71", "6.18", "1.02"]
      ]
    }},

    { table: {
      caption: "Table S6. Does the 2023 extension create the difference between the two sites? Both 3 h sites recomputed on 2024-2025 alone, beside the record as analysed. Chatfield State Park reported no 2023 formaldehyde, so its values are identical in the two periods and are given once.",
      header: ["", "Sampling window (06-09 MST)", "+3 h (09-12 MST)", "+6 h (12-15 MST)"],
      widths: [2700, 2100, 2100, 2126],
      rows: [
        ["Platteville, whole-period r, 2024-2025 only", "0.55 (n = 42)", "0.46 (n = 54)", "0.24 (n = 50)"],
        ["Platteville, whole-period r, with 2023", "0.48 (n = 54)", "0.36 (n = 70)", "0.23 (n = 63)"],
        ["Platteville, anomaly r, 2024-2025 only", "0.26 (n = 32, p = 0.20)", "0.28 (n = 45, p = 0.07)", "-0.11 (n = 40, p = 0.57)"],
        ["Platteville, anomaly r, with 2023", "0.25 (n = 43, p = 0.13)", "0.16 (n = 58, p = 0.24)", "-0.02 (n = 51, p = 0.92)"],
        ["Chatfield State Park, anomaly r (no 2023 record)", "0.01 (n = 46, p = 0.97)", "0.48 (n = 63, p < 0.001)", "0.24 (n = 31, p = 0.25)"]
      ],
      notes: "Anomaly p-values are within-site-month permutation values (Text S3). The later window has no advantage at Platteville in either period, which is the claim made in the text; the apparent preference for the sampling window appears only once 2023 is included, and no Platteville anomaly correlation is significant in either period."
    }},

    // ------------------------------------------------------------- figures
    { fig: { file: "fig0_site_map.png",
      caption: "Figure S1. The Colorado case-study sites: seven COATTS sites sampling 24 h integrated formaldehyde (circles) and two COOPs sites sampling 3 h integrated formaldehyde (triangles), over terrain and county boundaries. Inset: the 123 sites across the contiguous United States that reported formaldehyde to AQS in 2024-2025, coloured by sample duration, with Colorado outlined. Elevation is from AWS terrain tiles; boundaries are US Census cartographic files." }},

    { fig: { file: "fig5_sensitivity.png",
      caption: "Figure S2. Pooled Spearman correlation between Colorado surface HCHO and the daily mean TEMPO column as a function of the maximum effective cloud fraction, averaging block (1 × 1, 3 × 3 or 5 × 5 cells) and daily window (all daylight scans or 10:00-14:00 MST). Symbol size shows the number of matched site-days." }},

    { fig: { file: "fig8_threeh_sensitivity.png",
      caption: "Figure S3. Pooled Spearman correlation between 3 h surface HCHO and the window-mean TEMPO column as a function of the maximum effective cloud fraction and the averaging block, for each lag from the sampling window. Symbol size shows the number of matched samples." }},

    { fig: { file: "fig11_national_lag_curve.png",
      caption: "Figure S4. Pooled correlation between sub-daily surface HCHO and the mean TEMPO column as a function of the lag of the TEMPO window from the sampling window, for the 3 h and 8 h sites. \"Whole\" uses the concentrations as measured; \"anomalies\" uses deviations from site and calendar-month means. Labels give the number of matched samples. Because the sites pooled here sample different windows, a given lag corresponds to different times of day at different sites, which is why the main text reports agreement by window start hour instead." }},

    { fig: { file: "fig4_coverage.png",
      caption: "Figure S5. Monthly counts of Colorado 24 h sample days by site with a matched TEMPO value, with scans that all failed screening, and with no TEMPO scan." }},

    { fig: { file: "fig1_timeseries.png",
      caption: "Figure S6. Time series of 24 h surface HCHO (top row, µg m^{-3}) and same-day TEMPO HCHO columns (bottom row, 10^{15} molecules cm^{-2}; mean of valid scans between 00:00 and 24:00 MST in a 3 × 3 cell block) at the seven COATTS sites, ordered from west to east." }},

    { fig: { file: "fig2_scatter_by_site.png",
      caption: "Figure S7. Colorado surface HCHO versus daily mean TEMPO column by site. Colours denote season. Lines show reduced major axis fits where the Pearson correlation is significant; n, Pearson r and Spearman ρ are given in each panel." }},

    { fig: { file: "fig6_within_month_anomalies.png",
      caption: "Figure S8. Deviations of Colorado surface HCHO and daily mean TEMPO column from their site and calendar-month means (site-months with ≥ 3 matched samples). The line is an ordinary least squares fit with its 95 % confidence band." }},

    { fig: { file: "fig3_effective_height_by_month.png",
      caption: "Figure S9. Monthly distributions of the effective mixing height H_{eff} on matched days by Colorado site. Orange diamonds show the median TEMPO PBL height on the same days. The vertical axis is truncated at the 98th percentile." }},

    { fig: { file: "figS4_noise_ceiling.png",
      caption: "Figure S10. Observed day-to-day (within-month anomaly) correlation at each Colorado 24 h site, with the ceiling implied by TEMPO retrieval noise alone, estimated from differences between successive scans and from the uncertainties reported in the product (3 × 3 blocks)." }},

    { fig: { file: "fig7_threeh_scatter.png",
      caption: "Figure S11. Three-hour surface HCHO (2024-2025) at Chatfield State Park (CHCO) and Platteville (PVCO) versus the mean TEMPO column in the sampling window (06:00-09:00 MST) and in windows shifted by -3, +3, +6 and +9 h. The -3 h row is empty because no scan passed screening, and the +9 h row holds only seven Platteville samples. Colours denote season; lines show reduced major axis fits where the Pearson correlation is significant." }},

    { fig: { file: "fig10_threeh_lag_curve.png",
      caption: "Figure S12. Agreement between 3 h surface HCHO and the mean TEMPO column as a function of the lag between the sampling window (06:00-09:00 MST) and the satellite window, for the whole period and for within-month anomalies. Labels give the number of matched samples. Agreement peaks three hours after sampling ends, when the median TEMPO boundary layer height has risen from 0.5 to 1.6 km." }},

    { fig: { file: "figS3_threeh_window_columns.png",
      caption: "Figure S13. TEMPO columns for the same 3 h samples, measured in the sampling window (06:00-09:00 MST) and three hours later. The two differ substantially from day to day at Chatfield State Park and agree more closely at Platteville; the dashed line is 1:1." }},

    { fig: { file: "fig9_smoke_stratified.png",
      caption: "Figure S14. Colorado surface HCHO versus daily mean TEMPO column by HMS smoke class on the sample day (none, light, medium-heavy). Colours denote site; lines are ordinary least squares fits; n and Pearson r are given in each panel." }}
  ]
};
