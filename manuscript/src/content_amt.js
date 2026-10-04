// content_amt.js - the AMT (Copernicus) manuscript source.
//
// Regenerated 2026-09-27 from the reviewed TEMPO_HCHO_AMT_v2.docx, so that the
// build chain is again the source of truth. Citations are {{key}} markers
// (author-year, rendered by build_amt.js; {{@key}} narrative, {{~key}} bare);
// numbers are {{n:key}} markers where the pipeline names the value, and
// literals verified by check_amt.js elsewhere; Table 1 is rendered from
// output/tables/manuscript_table1.csv (R/21) by tables_amt.js.
module.exports = {
  "title": "Hourly Satellite Formaldehyde Columns and Routine Surface Air Toxics Monitoring: Day-to-Day Agreement at 123 United States Sites",
  "abstract": [
    "Formaldehyde (HCHO) is a carcinogenic hazardous air pollutant and a leading contributor to estimated cancer risk from U.S. outdoor air toxics. The geostationary Tropospheric Emissions: Monitoring of Pollution (TEMPO) instrument retrieves HCHO columns hourly over North America, but published TEMPO HCHO evaluations have compared them only with other column measurements. We compared TEMPO Level 3 version 4 HCHO columns with 16,383 valid integrated formaldehyde samples reported to the Air Quality System by 123 monitors in 36 states and Washington, DC, over 24, 8, and 3 h. A sample was observable when at least one TEMPO scan during its sampling window passed screening; 70% of 24 h samples were observable. For 24 h samples, the pooled correlation with surface HCHO was 0.42 and 0.40 for within-month anomalies. This pooled result obscured substantial site-to-site variation: day-to-day correlations at individual 24 h monitors ranged from {{n:site_dd_min_24}} to {{n:site_dd_max_24}} (median {{n:site_dd_median_24}}), and in the states with four or more such monitors only {{n:pct_between_states}}% of the variance among them was attributable to differences between states. Across 90 24 h monitors, six site descriptors explained about a fifth to a quarter of the variation in day-to-day agreement, mainly through signal-to-noise ratio and smoke prevalence; the remaining heterogeneity was not explained by the measured site characteristics. Among 24 h samples with at least four valid scans, averaging more scans raised the pooled day-to-day correlation from {{n:ta_r1_33}} for one randomly chosen scan to {{n:ta_rall_33}} for all scans, and at the {{n:dd_sites_paired}} monitors with sufficient paired 24 h and 8 h records the two durations showed no detectable difference in agreement with TEMPO. Agreement also varied with modelled mixing depth: for 8 h samples beginning at 04:00 LST, the correlation rose from {{n:pbl_8h4_r_low}} in the shallowest tertile of modelled mixing depth to {{n:pbl_8h4_r_high}} in the deepest, a gradient about half as large on smoke-free days. Observable days were also unrepresentative, with surface HCHO 0.52 µg m^{−3} (25% of the median concentration) higher than on days when all available scans were screened out. For 3 h samples, the temporal match differed across sites. At one site in Colorado, the correlation increased from −0.01 during the 06:00–09:00 MST sampling period to 0.48 in the following three hours; another showed little day-to-day agreement in either window, while the two California sites, taken together, agreed as well during their morning sampling window as at midday."
  ],
  "sections": [
    {
      "h1": "1 Introduction",
      "p": [
        "Formaldehyde (HCHO) is one of the largest contributors to estimated cancer risk from ambient air toxics in the United States{{zhu2017}}. Unlike most air toxics, ambient HCHO is predominantly secondary, produced by the oxidation of biogenic and anthropogenic volatile organic compounds (VOCs), with smaller primary contributions from combustion and industrial sources. For example, research has shown that downwind of Houston-area petrochemical facilities, secondary production accounted for 92 ± 4% of HCHO compared with 4 ± 2% from primary emissions{{parrish2012}}. Surface HCHO trends across the United States track temperature-dependent biogenic precursor emissions and are influenced by wildfires{{liu2026}}. Studies have shown HCHO is produced within aging wildfire plumes{{liao2021}}.",
        "HCHO has characteristic absorption features in the ultraviolet. By measuring the attenuation of backscattered sunlight at these wavelengths, satellite spectrometers can retrieve the vertically integrated abundance of HCHO in the atmosphere. Such retrievals extend back to 1996 with the Global Ozone Monitoring Experiment (GOME; {{~desmedt2008}}) and to 2004 with the Ozone Monitoring Instrument (OMI; {{~levelt2006}}), whose nadir footprint is 13 × 24 km. Because HCHO has a short atmospheric lifetime of only a few hours, the observed column is typically dominated by recent, nearby production within the boundary layer and therefore contains information about surface concentrations.",
        "That reasoning underlies the principal historical use of satellite HCHO, as a top-down constraint on emissions of short-lived VOCs{{streets2013}}. GOME, SCIAMACHY and OMI columns were used to map isoprene emissions over North America{{palmer2003}}{{millet2006}}{{millet2008}} and the tropics{{barkley2013}}, temporal oversampling of OMI revealed anthropogenic plumes over Houston and other Texas cities{{zhu2014}} and multi-year VOC trends in Asian cities{{bauwens2022}}, and TROPOMI columns have been used to constrain VOC emissions for ozone simulations{{feng2024}}. Paired with NO_{2}, the column HCHO/NO_{2} ratio has also served as an indicator of whether ozone production is limited by NO_{x} or by VOCs{{martin2004}}{{duncan2010}}.",
        "Less often, satellite HCHO has been used to map surface concentrations and infer cancer risks across the United States{{zhu2017}}, although converting a column measurement to a surface concentration necessarily requires assumptions about the vertical distribution of HCHO. Those assumptions can fail. In a modeled sea-breeze event on the U.S. east coast, clean marine air undercut polluted continental air, HCHO increased with altitude, and the total column was negatively correlated with the surface concentration; a global model that missed the circulation assigned 40–150% too much of the column to the surface layer{{souri2023}}. A column can therefore fail to track the surface even when it is retrieved accurately.",
        "TEMPO, launched into geostationary orbit in 2023, measures HCHO hourly during daylight over North America at a spatial resolution of a few kilometers{{zoogman2017}}. Because HCHO is produced largely through VOC oxidation, its abundance responds to the same processes that shape ozone-NO_{x}-VOC photochemistry over the course of the day, including changes in sunlight-driven production and loss, precursor emissions, and boundary-layer mixing. Hourly TEMPO observations can thus track the diurnal evolution of HCHO and its underlying photochemical environment{{jin2025}}. Column-based indicators inherit the same column-to-surface ambiguity, however: in aircraft profiles from DISCOVER-AQ over Colorado, Maryland, and Houston, uneven vertical mixing in the lower troposphere made the column HCHO/NO_{2} ratio a much weaker indicator of near-surface ozone sensitivity than the same ratio measured in situ{{schroeder2017}}.",
        "Evaluation of satellite HCHO has relied on aircraft profiles and ground-based column instruments. Aircraft profiles over the southeast United States showed six retrievals from four satellites to agree with one another in day-to-day variability (r = 0.5–0.8) but to be biased low in the mean by 20–51%{{zhu2016}}, and a synthesis of 12 campaigns found the OMI product biased low by 22–45% under polluted conditions and high at low columns{{zhu2020}}. Ground-based direct-sun spectrometers offer a second route. Pandora instruments, developed for NO_{2}{{herman2009}}, were first evaluated for HCHO during KORUS-AQ, where columns reconstructed from surface measurements and a ceilometer mixed-layer height matched the Pandora columns (slope 1.03) once the lower atmosphere was assumed to be well mixed{{spinei2018}}. For TEMPO, comparisons with the Pandonia Global Network characterized the retrieval's spatiotemporal performance{{rawat2026}}, and comparisons with Fourier transform infrared (FTIR) and Pandora spectrometers found a low bias of about 30%, while diurnal and seasonal variability were captured{{ortega2026}}. The TEMPO validation team’s baseline assessment collects these and other comparisons for the version 3 trace gas products{{nasaval2026}}.",
        "Comparisons with routine surface HCHO measurements remain rare, in part because the monitoring network is sparse and relies largely on intermittently collected integrated samples. {{@wang2022}} compared OMI columns from 2006–2015 with seasonal mean surface HCHO at 45 sites reporting to the Air Quality System (AQS), EPA’s repository for ambient monitoring data. They found regional correlations of 0.56–0.87 in summer, weak or negative correlations in winter, and seasonal variability that was 20–100% larger in the satellite column than at the surface. The analysis used seasonal rather than monthly averages to preserve geographic coverage. Only 37 sites had at least one measurement in every month, whereas requiring six surface samples per season retained 45 sites. The contrast with NO_{2} illustrates how strongly the surface network constrains the kind of satellite evaluation that is possible: dense, hourly regulatory NO_{2} measurements have supported direct comparisons of routine surface observations with both TROPOMI and, more recently, TEMPO{{acker2025}}{{nawaz2025}}. Those comparisons found that collocated satellite values reproduce the distribution of surface NO_{2} closely away from major roads, with TEMPO matching or improving on TROPOMI{{acker2025}}, and that monthly-mean hourly TEMPO columns explain 42% of the variance in surface NO_{2} at 454 monitors, rising to 61% for annual-mean hourly values away from roads and falling to 23% at 06:00 local time{{nawaz2025}}. Both papers, however, compared distributions or temporal averages rather than individual days: Acker et al. compared frequency distributions because they capture the variability and extremes relevant to air quality standards and monitor siting, and Nawaz et al. averaged the hourly columns over each month to reduce single-scan retrieval uncertainty and to match the long-term exposures that matter for chronic health effects.",
        "TEMPO’s hourly geostationary sampling makes multiple HCHO measurements within a single day, allowing satellite columns to be matched to the actual hours covered by 24, 8, and 3 h integrated samples rather than to a single overpass. This makes it possible to evaluate satellite-surface agreement at individual sampling periods and to test how agreement varies by time of day.",
        "Here we compare TEMPO Level 3 version 4 HCHO columns with surface HCHO measured in 2024–2025 at 123 U.S. monitors reporting to AQS across 36 states and the District of Columbia, including National Air Toxics Trends Stations, NCore multipollutant sites, and Photochemical Assessment Monitoring Stations. Because these routine networks were designed for long-term air toxics monitoring rather than satellite validation, we ask (1) how often a usable TEMPO observation is available for a surface sample, (2) how well TEMPO tracks day-to-day variation in surface HCHO at individual monitors, (3) how that agreement varies among sites, and (4) whether days with usable retrievals are representative of days that are screened out.",
        "TEMPO’s repeated observations also allow us to examine what contributes to variation in satellite-surface agreement. First, we estimate retrieval noise from differences between consecutive scans, on the assumption that the atmospheric HCHO column changes relatively little over approximately one hour and that much of the scan-to-scan difference therefore reflects retrieval noise. We then use this estimate to determine how strongly retrieval noise constrains the maximum correlation TEMPO could achieve with surface HCHO. Second, we test whether agreement depends on the hours used for the satellite comparison. Two Colorado monitors provide the cleanest test of temporal matching because they are the only 3 h sites that consistently sample a single fixed early-morning window, from 06:00 to 09:00 MST. This allows us to hold the surface measurement period constant while comparing TEMPO columns observed during sampling with those observed in the non-overlapping three hours that follow. The other sub-daily monitors sample at several times of day and are used to examine how satellite–surface agreement varies with sampling time more broadly."
      ]
    },
    {
      "h1": "2 Data and Methods",
      "p": []
    },
    {
      "h2": "2.1 Surface Measurements",
      "p": [
        "HCHO is measured across the United States by state, local, and tribal agencies and reported to EPA’s Air Quality System (AQS) under parameter code 43502{{epaaqs2026}}. Nearly all measurements in this study use EPA Compendium Method TO-11A{{epato11a1999}}, in which air is collected on a 2,4-dinitrophenylhydrazine-coated cartridge and the resulting derivative is quantified by high-performance liquid chromatography. Of the samples analyzed here, {{n:pct_method_ki}}% were collected with a potassium-iodide ozone scrubber, {{n:pct_method_bare}}% with a bare silica cartridge, and {{n:pct_method_denuder}}% downstream of a heated ozone denuder.",
        "For the national analysis, we used EPA's AQS data to identify sites in the contiguous United States whose monitors together reported at least 20 HCHO samples at a single collection duration over calendar years 2024 and 2025. We then retrieved all samples from those sites, retaining every sampling duration reported at each qualifying site. This, for example, retains one 10-sample 24 h record at a site that qualified on its 8 h record. Six sites fell short of 20 samples at every duration and were excluded, removing 48 samples. Records carrying an AQS null data qualifier were then removed, and where more than one record (instrument or method) at a site covered the same sampling window, their values were averaged. The final dataset contains 16,383 valid samples from 123 sites in 36 states and the District of Columbia, spanning 1 January 2024 to 31 December 2025. AQS reports HCHO in parts per billion carbon, which for this one-carbon molecule is numerically equivalent to parts per billion by volume; we converted concentrations to mass units at 25 °C and 1 atm.",
        "Samples were collected over 24, 8, or 3 h. Twenty-three sites reported both a 24 h and an 8 h record, so the site counts by duration overlap. The 24 h record comprised 8730 samples at 102 sites; 97% began at midnight local standard time and the remaining 273 at 23:00 LST, all of them during daylight saving time (that is, at local midnight by the clock) at four Philadelphia monitors and once in Florida. Most were collected on a one-in-six or one-in-twelve day schedule. The 8 h record comprised 6972 samples at 40 sites; 99% began at 04:00, 12:00, or 20:00 LST, the remaining 55 falling on alternative eight-hour grids used briefly at five sites. The 3 h record comprised 681 samples at four sites: two Colorado ozone-precursor monitors sampled exclusively from 06:00 to 09:00 MST, whereas two sites in California's San Joaquin Valley sampled several times a day, principally beginning at 05:00, 12:00, 16:00 and 23:00 LST, with 14 samples beginning at 08:00.",
        "The Colorado monitors support two additional analyses. First, six of the seven Colorado air-toxics monitors reporting 24 h samples are included in the national comparison. Treating them as a single state-level cluster allows the national observability (Sect. 3.4), smoke and retrieval-noise results (Sect. S6) to be evaluated within one relatively dense regional network. Wheat Ridge, which has only 15 samples and therefore falls below the national inclusion threshold, is retained in this Colorado-specific analysis.",
        "Second, two Colorado ozone-precursor monitors provide 3 h samples. Only four monitors nationally report 3 h formaldehyde, and the two Colorado sites are the only pair that sample the same fixed window, 06:00–09:00 MST, on every sampling day; the two California monitors instead sample at several start times on each sampling day. The fixed Colorado window holds the surface sampling period constant while the satellite observation window is shifted, allowing TEMPO columns measured during sampling to be compared directly with those observed in subsequent hours. All four 3 h sites are included, with the California pair providing a complementary test in which the surface sampling window itself varies.",
        "Platteville, one of the two Colorado 3 h sites, began reporting HCHO to AQS in August 2023, coinciding with the start of TEMPO observations, so its Colorado-specific record is extended back to that month. The national comparison begins in 2024, and the second Colorado 3 h site has no 2023 HCHO record. Site descriptions, quality-control procedures, and a map are provided in the Supplement (Fig. S1, Table S1)."
      ]
    },
    {
      "h2": "2.2 TEMPO Columns and Matching",
      "p": [
        "We used the provisional TEMPO Level 3 version 4 HCHO product{{tempol3v4}}, which maps retrievals from each TEMPO scan onto a 0.02° × 0.02° grid, approximately 2.2 km × 1.7 km at 39.5° N. As in earlier ultraviolet retrievals, the fitted slant column is converted to a vertical column with an air mass factor that depends on clouds, surface reflectivity, viewing geometry, and an assumed vertical profile of HCHO{{millet2006}}{{zhu2016}}; clouds dominate the resulting error{{millet2006}}, and the assumed profile means that every reported column already embeds an assumption about how HCHO is distributed with height. Each scan is distributed by NASA as a separate data file, or granule. We identified the files covering each monitoring site and sampling period through NASA’s Common Metadata Repository and downloaded a 5 × 5 block of grid cells surrounding each site through NASA’s OPeNDAP service. We downloaded these cells without quality screening so that screening criteria and spatial averaging windows could be varied after extraction.",
        "We retained a grid cell when the main data quality flag was 0, effective cloud fraction was ≤0.2, solar zenith angle was ≤70°, and snow and ice fraction was zero. Following the product user guide{{nasaguide2025}}, we retained negative HCHO columns. For the primary analysis, we averaged the screened cells within the central 3 × 3 block, approximately 6.7 km × 5.1 km, to obtain one HCHO column for each scan. A scan was considered valid (usable) when at least half of its block's cells passed the screening criteria, five of the nine for the 3 × 3 block.",
        "We assigned a TEMPO scan to a sampling window when the hour containing the scan midpoint fell within that window. Because TEMPO observes locations sequentially during each scan, the midpoint timestamp can differ from the actual observation time at an individual site by tens of minutes.",
        "The surface sample and the TEMPO column may not represent the same vertical distribution of HCHO, particularly in the early morning when the boundary layer is shallow or decoupled. As mixing develops, the surface concentration may become more representative of a larger fraction of the atmospheric column. We therefore repeated the sub-daily comparisons after shifting the TEMPO window by −3 and +3 h. These shifts correspond to the additional three hours retrieved on either side of each sampling window in the national extraction. For the Colorado 3 h sites, the wider 03:00–19:00 MST extraction also allowed comparisons at +6 and +9 h. The −3 h window for these sites, 03:00–06:00 MST, precedes TEMPO's usable daylight observations: only 3 of the 234 samples had any scan in it, and none passed screening.",
        "We tested sensitivity to effective cloud-fraction thresholds of 0.1, 0.2, and 0.3 and to spatial averages based on 1 × 1, 3 × 3, and 5 × 5 grid-cell blocks for the pooled correlations (Figs. S2–S3); unless stated otherwise, other results use a threshold of 0.2 and the 3 × 3 block. At the Colorado 24 h sites, we additionally compared columns averaged over all usable daytime scans with those restricted to midday (Sect. S6)."
      ]
    },
    {
      "h2": "2.3 Statistics",
      "p": [
        "We report Pearson (r) and Spearman (ρ) correlations by site, by season, and pooled. Because surface HCHO and the column share a strong seasonal cycle, we also computed within-month anomalies by subtracting each site's mean for that month of that year from both variables, retaining site-months with at least three matched samples; correlations of these anomalies measure day-to-day covariation and are the quantity we rely on. Site-level correlations are reported for monitors with at least 10 matched samples and at least 10 within-month anomaly pairs, the minimum for every site-level correlation in the national analysis (the noise ceiling and the time-of-day comparison add requirements of their own, stated where they are used). Seasonal comparisons use 24 h samples and three statistics: the pooled and day-to-day correlations within each season and, following {{@wang2022}}, the correlation across sites between site-season means of the column and of the surface concentration, for sites with at least {{n:seas_min_samples}} matched samples in the season.",
        "For 8 h and 3 h samples, each site-month combines all sampling windows used at that site. As a result, the site-month anomaly can still reflect systematic differences among sampling windows. The start-hour comparison in the Results avoids this problem by comparing observations within the same start hour, while Sect. S3 reports an additional analysis in which anomalies are calculated separately for each sampling window.",
        "Because each site-month mean is calculated from the same observations subsequently used to estimate the anomaly correlation, standard correlation tests would produce p-values that are too small. We therefore test anomaly correlations by permuting one variable within site × year-month strata (2000 permutations; Sect. S3). We summarize multiplicity across site-level tests using the Benjamini-Hochberg procedure (Table S2). All anomaly-correlation p-values reported here are permutation-based, except those of Williams' tests, which are parametric; regression coefficients estimated from repeated samples carry site-clustered standard errors, and paired site-level differences are tested with the Wilcoxon signed-rank test. We emphasize the overall distribution of site-level correlations rather than the number of individual sites reaching statistical significance.",
        "For the pooled analysis, we regress surface HCHO concentration on the TEMPO column using ordinary least squares with site and calendar-month fixed effects. Reduced major axis slopes, Williams' test for dependent correlations{{steiger1980}}, and the retrieval-noise estimator are described in the Supplement. Retrieval noise and time-of-day variation are evaluated at every 24 h site with enough data."
      ]
    },
    {
      "h3": "2.3.1 Effective Mixing Height",
      "p": [
        "To relate the TEMPO column to the surface measurement, we converted the surface HCHO mass concentration to a number density, n_{s}, and defined an effective mixing height, H_{eff} = Ω/n_{s}, where Ω is the TEMPO column. H_{eff} is therefore the depth of a hypothetical uniform layer at the measured surface concentration that would contain the observed column. The same well-mixed-layer construction, run in the opposite direction with a ceilometer mixed-layer height, reproduced Pandora HCHO columns from surface measurements during KORUS-AQ{{spinei2018}}.",
        "We treat H_{eff} as a diagnostic and not as a physical boundary layer depth because it reflects not only the vertical distribution of HCHO, but also biases in the satellite retrieval and surface measurement and the temporal mismatch between the surface sampling period and daytime TEMPO observations. Because concentrations are expressed in mass units at 25 °C and 1 atm (Sect. 2.1), we first converted concentration (C) back to a mixing ratio, χ = C × 24.45/M, where M = 30.026 g mol^{−1}, and then converted χ to a number density at ambient conditions as n_{s} = 10^{−15} χ p/(k_{B}T), with p in Pa and T in K. The factor 10^{−15} combines the definition of a part per billion (10^{−9}) with the conversion from molecules m^{−3} to molecules cm^{−3} (10^{−6}).",
        "Ambient T and p come from the NOAA High-Resolution Rapid Refresh (HRRR) analysis, a 3 km hourly data-assimilation model{{dowell2022}}, and are averaged over the hours spanned by each surface sample. The same HRRR fields were used for every monitor and sampling duration. A single fixed temperature would not be adequate, because H_{eff} is proportional to T and HRRR temperatures span −33.8 to +{{n:hrrr_temp_max}} °C over the site-hours sampled. The fixed 15 °C used in earlier versions of this analysis would understate H_{eff} by about 7% on a 35 °C day, overstate it by about 12% at −15 °C, and compress the seasonal contrast by roughly 19 percentage points. HRRR surface pressure agrees closely with the surface pressure supplied with the TEMPO retrieval (median TEMPO − HRRR difference {{n:met_press_tempo_minus_hrrr}} hPa, r = {{n:met_press_tempo_hrrr_r}}, n = {{n:met_press_n}} distinct samples; Fig. S4, Table S3)."
      ]
    },
    {
      "h3": "2.3.2 Observability of Sample Days",
      "p": [
        "A sample day is classified as observable if at least one TEMPO scan over the site passes all screening criteria. It is classified as screened out if TEMPO returned one or more granules over the site, but none passed screening, and as no-granule if TEMPO returned no granules for that day. We exclude no-granule days from the observability comparison so that missing TEMPO coverage is not counted as a screening failure.",
        "To identify which criteria drive screening losses, we re-evaluated every screened-out sample day after relaxing one criterion at a time. These counts are not mutually exclusive because a sampling period can contain several scans, and different scans can fail different criteria.",
        "We estimate the difference in surface HCHO between observable and screened-out days in two ways, with both estimates defined as observable minus screened-out. First, we fit",
        "HCHO_{it} = α_{i} + γ_{m} + β·observable_{it} + ε_{it}, where α_{i }and γ_{m }are monitor i and calendar month m fixed effects. The coefficient, β, therefore represents the adjusted difference in surface HCHO between observable and screened-out days; standard errors are clustered by monitor.",
        "Second, we remove each observation’s site-month mean, calculate the average observable-versus-screened difference within each site-month, and then average those paired differences across site-months. Confidence intervals are obtained by bootstrapping monitors with 2000 replicates. In this comparison we do not report a bootstrap interval for strata containing fewer than five monitors, because with so few monitoring sites the resampling distribution becomes too limited to provide a meaningful interval."
      ]
    },
    {
      "h3": "2.3.3 Why Agreement Differs",
      "p": [
        "Four further analyses ask why agreement differs rather than how large it is. First, at the {{n:dd_sites_total}} monitors that report both 24 h and 8 h samples, we computed the within-month anomaly correlation separately for each duration and took the paired difference across sites, so that sample duration is compared within the same monitor rather than across networks. The 24 h surface sample was also correlated with TEMPO columns restricted to the hours of each 8 h block (04:00–12:00 and 12:00–20:00 LST), which separates the effect of restricting the column from that of restricting the sample.",
        "Second, for the {{n:gap_sites}} 24 h sites with a retrieval-noise ceiling (Sect. 3.3), we modelled the Fisher-transformed site correlation, and the Fisher-transformed noise-corrected ratio E = r_{obs}/r_{ceiling} (capped at 0.999), against six pre-specified descriptors of each site: the logarithms of the median surface HCHO, of the signal-to-noise ratio (the standard deviation of the column anomalies divided by the estimated noise in the daily mean) and of the median number of valid scans; the share of samples with a usable scan; the mean HRRR mixing depth (the HRRR planetary boundary-layer height); and the share of samples affected by smoke. Predictors were standardized, fits were weighted by n − 3, and no variable selection was performed.",
        "Third, for the {{n:ta_samples}} 24 h samples with at least four valid scans in every spatial block, we drew k = 1, 2, 3 and 4 scans at random per sample, averaged them, and recomputed the pooled within-month anomaly correlation, repeating each draw {{n:ta_draws}} times. Because the variance of the column anomaly should equal a signal term plus the single-scan noise variance divided by k, the slope of that variance against 1/k gives an estimate of the single-scan noise that does not use the scan-difference estimator.",
        "Fourth, we asked whether the coupling between column and surface depends on the state of the boundary layer, using the HRRR mixing depth averaged over the sampling window rather than H_{eff}, which contains the surface concentration itself. Within each 8 h start hour (04:00 and 12:00 LST), so that time of day is held fixed, observations were split into tertiles of mixing depth, both absolute and relative to the site-month mean, and the anomaly correlation in the deepest tertile was compared with that in the shallowest using a site-clustered bootstrap. A regression of the surface anomaly on the column anomaly, the mixing-depth anomaly and their interaction, with site-clustered standard errors, gives the same test in continuous form; a second version lets the column–surface slope depend also on the number of valid scans and on the site-month column level, so that a signal-to-noise effect cannot masquerade as a mixing effect. The tertile contrast was repeated on smoke-free days, with all anomalies recomputed from those days alone, and the tertile contrast and both regressions were also computed for 24 h samples.",
        "All processing was done in R version 4.3.3{{rcore2024}} with httr2, ncdf4, sf{{pebesma2018}} and lme4{{bates2015}}, with package versions pinned by renv; a single script downloads every input and produces all tables and figures (see Code and data availability)."
      ]
    },
    {
      "h1": "3 Results and Discussion",
      "p": []
    },
    {
      "h2": "3.1 Availability and Pooled Agreement",
      "p": [
        "A screened TEMPO observation was available for 70% of the 8730 national 24 h samples, with a median of six usable scans per sample. Availability varied substantially among sites, from about 90% in Arizona, southern California, and along the Texas Gulf Coast to near or below 50% in Oregon, Vermont, upstate New York, and Seattle. The lowest coverage occurred at Tualatin (37%) and Portland-Helensview (39%), Oregon, and Proctor Maple Research Center, Vermont (40%).",
        "This relatively high overall availability largely reflects TEMPO’s ability to observe the same location repeatedly throughout the day. At a Pandora site in New Jersey, for example, hourly sampling provides a usable observation on about 50% more days than would a single early-afternoon overpass{{rawat2026}}. Similarly, modeled cloud fields suggest that 68–93% of days have at least one clear-sky opportunity during daylight hours, compared with only 33–69% at a fixed early-afternoon overpass{{goldberg2025}}.",
        "Across the 24 h sites, the daily mean TEMPO column was moderately correlated with the corresponding surface HCHO concentration (r = 0.42, ρ = 0.48, n = 6106). The association remained similar after removing each site-month mean, which isolates day-to-day variation within sites and months (r = 0.40, n = 5218 observations in 1262 site-months).",
        "The regression of surface concentration on the column, with fixed effects for site and calendar month, gave {{n:colcoef_24}} ± {{n:colcoef_se_cl_24}} µg m^{−3} per 10^{15} molecules cm^{−2} for 24 h samples (± site-clustered standard error). Table 1 summarizes the comparison by sample duration. Median H_{eff} over the matched 24 h samples with a positive column was 1.10 km against a median TEMPO planetary boundary layer height of 1.04 km; the agreement of the two medians is not by itself evidence of a well-mixed profile, since H_{eff} also absorbs retrieval bias, the free-tropospheric column, and the mismatch between a 24 h sample and daytime satellite sampling.",
        "Agreement also depended on season. For 24 h samples, the pooled correlation was {{n:seas_r_24_djf}} in winter (95% CI: {{n:seas_rlo_24_djf}}, {{n:seas_rhi_24_djf}}; n = {{n:seas_n_24_djf}}), against {{n:seas_r_24_mam}}, {{n:seas_r_24_jja}} and {{n:seas_r_24_son}} in spring, summer and autumn, and the day-to-day correlation was also lowest in winter ({{n:seas_dd_24_djf}}, against {{n:seas_dd_24_jja}} in summer) but positive in every season (Table S4, Fig. S5). Across sites, seasonal mean columns and surface concentrations were not significantly related in winter (r = {{n:seas_sp_djf}}, p = {{n:seas_spp_djf}}, {{n:seas_spn_djf}} sites) and positively related in spring, summer and autumn (r = {{n:seas_sp_mam}}, {{n:seas_sp_jja}} and {{n:seas_sp_son}}). The column's seasonal cycle was larger than the surface's: at the {{n:seas_amp_sites}} sites with at least {{n:seas_min_samples}} matched samples in every season, the range of its four seasonal means, relative to their mean, was a median {{n:seas_amp_ratio_median}} times that of the surface (interquartile range {{n:seas_amp_ratio_q25}}–{{n:seas_amp_ratio_q75}}), and the median summer-to-winter ratio was {{n:seas_jja_djf_column}} for the column against {{n:seas_jja_djf_surface}} at the surface."
      ]
    },
    {
      "table": {
        "caption": "Table 1. The national comparison by sample duration. Sites and samples are those reported to AQS for 2024–2025; matched counts and correlations use the primary screening (effective cloud fraction ≤ 0.2, 3 × 3 cell block) with scans inside the sampling window. Anomaly correlations use deviations from site-month means (each month of each year). Usable scans are those passing the screen, over samples with at least one. Median anomaly r by site is computed over sites with at least 10 matched samples and 10 anomaly pairs. Median concentrations, columns, H_{eff} and TEMPO boundary-layer heights are over samples with a usable scan (H_{eff} over those with a positive column). The column coefficient is given ± its standard error clustered by site; with four 3 h sites that interval is descriptive. Start hours are those covering most samples: 97% of 24 h samples begin at 00 and the remainder at 23; 99% of 8 h samples begin at 04, 12, or 20, the rest spread over nine other start hours, mostly at Rocky Flats, Colorado (three weeks in June 2025) and Livermore, California (June 2024).",
        "builder": "table1",
        "notes": "^{a} Deviations from site-month means; for 8 h and 3 h samples, these pool a site's sampling windows and so include the difference between windows (Sect. S3 provides the window-stratified values)."
      },
      "p": []
    },
    {
      "h2": "3.2 Day-to-Day Correlations Are Highly Site Dependent",
      "p": [
        "Agreement was positive at most individual monitors, but varied widely across the network (Fig. 1). The result is therefore better characterized by the distribution of site-level correlations than by the number of sites reaching statistical significance. Among the {{n:n_sites_24}} 24 h sites with a site-level correlation, the median correlation was {{n:site_r_median_24}} (interquartile range {{n:site_r_q25_24}}–{{n:site_r_q75_24}}), and the median day-to-day correlation after removing site-month means was {{n:site_dd_median_24}} ({{n:site_dd_q25_24}}–{{n:site_dd_q75_24}}). Day-to-day correlations were highest at Fresno ({{n:site_dd_max_24}}), Stockton (0.79) and Bakersfield, California (0.77). At the other extreme, seven sites had correlations within 0.1 of zero, and St. Charles Mesa, Colorado (the Pueblo monitor of Table S1) had a correlation of {{n:site_dd_min_24}}. The {{n:n_sites_8}} sites with 8 h samples showed a similar pattern, with a median within-month anomaly correlation of {{n:site_dd_median_8}} when each site’s sampling blocks were pooled.",
        "The national pooled correlation of 0.42 was substantially lower than the median site-level correlation of {{n:site_r_median_24}}. Pooling across monitors therefore weakens, rather than inflates, the apparent agreement: TEMPO captures variation over time at a given monitor better than it captures differences among monitors, whose column-to-surface relationships vary with factors such as climate, mixing depth, and free-tropospheric HCHO. How much seasonal and between-site variation contributes to the pooled correlation can be quantified directly. Nationally the net contribution is close to zero: the pooled correlation is 0.42 and the day-to-day correlation 0.40. The near-balance hides two opposing effects: the seasonal cycle shared by column and surface raises the pooled correlation, while differences among monitors lower it, so that within any one season the pooled correlation is lower still ({{n:seas_r_24_djf}} in winter to {{n:seas_r_24_jja}} in summer and {{n:seas_r_24_son}} in autumn; Table S4). Across the {{n:n_multi_site_states}} states with at least four 24 h monitors that have a site-level correlation, the difference between pooled and day-to-day correlations had a median of {{n:pooling_gain_median}} and ranged from −0.12 to 0.25. The pooled correlation was below the day-to-day correlation in three states, while the largest gain occurred in Colorado (pooled 0.57 against day-to-day 0.32). Thus, an evaluation conducted in a single state could not reveal whether its result was typical of the broader network.",
        "This heterogeneity is primarily local rather than regional. Across those {{n:n_multi_site_states}} states, only {{n:pct_between_states}}% of the variance in site-level day-to-day agreement occurred between states; the remaining {{n:pct_within_states}}% occurred among monitors within the same state (Fig. 2). Part of that within-state spread is sampling error: the highest and lowest site correlations (Fresno, Stockton and Bakersfield; St. Charles Mesa and Colorado Springs) all rest on 18–23 anomaly pairs. Within-state consistency also varied markedly. Iowa’s five monitors ranged only from 0.58 to 0.68, whereas Colorado’s six ranged from −0.24 to 0.61 and California’s fourteen from −0.05 to 0.85. TEMPO therefore provides useful day-to-day information at most routine air-toxics monitors, but little or none at some sites. A single network-wide satellite-to-surface relationship cannot be assumed to apply at an individual monitor without local evaluation. For programs considering TEMPO as a supplement to surface monitoring, Figs. 1 and 2 provide a more informative basis for expectations than the national average alone."
      ]
    },
    {
      "fig": {
        "file": "fig13_national_site_map.png",
        "caption": "Figure 1. Day-to-day agreement (within-month anomaly correlation) between TEMPO HCHO columns and surface HCHO at each site, by sample duration, for scans inside the sampling window. Color shows the correlation (scale capped at ±0.8) and symbol size the number of anomaly pairs. Sites with fewer than 10 matched samples or 10 anomaly pairs are not shown."
      },
      "p": []
    },
    {
      "fig": {
        "file": "fig15_state_heterogeneity.png",
        "caption": "Figure 2. Day-to-day agreement (within-month anomaly correlation) at each 24 h monitor, grouped by state, for the {{n:n_multi_site_states}} states with at least four monitors with a site-level correlation. Each point is one monitor, sized by the number of anomaly pairs; the red bar is the state's pooled day-to-day correlation, computed over all its monitors' anomalies together. States are ordered by their median; the bar pools the anomalies of every 24 h monitor in the state, including those with too few samples or anomaly pairs to be plotted. Only {{n:pct_between_states}}% of the variance between monitors lies between states."
      },
      "p": []
    },
    {
      "h2": "3.3 What Limits Agreement: Retrieval Noise and Spatial Averaging",
      "p": [
        "Agreement improved as TEMPO observations were averaged over larger spatial areas. Across the national 24 h sites, the pooled Pearson correlation increased from 0.39 for a single grid cell to 0.42 for a 3 × 3 block and 0.43 for a 5 × 5 block. Tightening the cloud threshold from 0.2 to 0.1 increased the 3 × 3 correlation slightly, to 0.44, but removed 9% of the matched samples. By itself, however, this improvement does not explain why spatial averaging helps. Larger blocks could either reduce random retrieval noise or better represent the air sampled by the surface monitor.",
        "TEMPO’s repeated scans allow these two explanations to be separated. We estimated scan-to-scan retrieval noise from successive valid observations of the same site on the same day, no more than 1.6 h apart. Pooled over all scan pairs at the 24 h sites, the implied single-scan noise for a single grid cell was 4.6 × 10^{15} molecules cm^{−2}. After averaging the 3 × 3 block across all valid scans in a day and removing site-month means, the estimated noise fell to 1.2 × 10^{15} molecules cm^{−2}. Across the 24 h sites, this noise accounted for about 22% of the variance in the within-month TEMPO anomalies. If retrieval noise were the only source of disagreement, the maximum attainable day-to-day correlation would therefore be about 0.88, compared with the observed 0.40.",
        "This ceiling should be interpreted cautiously. The atmospheric column can genuinely change between successive scans, so the scan-to-scan calculation likely overestimates random retrieval noise and therefore underestimates the true correlation ceiling. It also cannot detect errors that persist throughout the day.",
        "The spatial-averaging pattern nevertheless becomes informative once this estimated noise is taken into account. The observed day-to-day correlations were 0.35, 0.40, and 0.42 for 1 × 1, 3 × 3, and 5 × 5 blocks, respectively. After dividing each correlation by its estimated noise ceiling, the corresponding values were 0.46, 0.45, and 0.46. In other words, the apparent improvement with larger spatial blocks disappears after accounting for retrieval noise. This suggests that spatial averaging improves agreement mainly by reducing random retrieval noise, rather than because larger blocks better represent the surface monitor. Section 3.6 shows independently, by averaging in time instead of space, that reducing retrieval noise raises agreement.",
        "Surface concentration gives a weaker and less consistent signal. When the 24 h sites were grouped at the tertiles of their median surface concentration (35, 26 and 31 sites, unequal because several sites share the same median), the median day-to-day correlation was {{n:tert_low_r}} in the lowest group ({{n:tert_low_lo}}–{{n:tert_low_hi}} µg m^{−3}), {{n:tert_mid_r}} in the middle group, and {{n:tert_high_r}} in the highest. A roughly fixed retrieval noise should matter most where HCHO concentrations are low, because noise then represents a larger fraction of the total signal, and this could explain the increase from the lowest to the middle group. The decline in the highest group shows that other factors also matter, greater near-source spatial heterogeneity at the most polluted sites being one possibility, and in the site model of Sect. 3.6 median surface concentration adds nothing once the column's signal-to-noise ratio is included.",
        "Agreement also differed with wildfire smoke. Smoke was identified from NOAA Hazard Mapping System polygons overlapping each sampling window{{rolph2009}}{{brey2018}}. Of the 10,017 matched samples with a smoke classification, {{n:smoke_n_affected}} were smoke-affected. At the 24 h sites, the pooled correlation between TEMPO and surface HCHO increased from 0.29 on smoke-free days to {{n:smoke_r_24_light}} under light smoke and {{n:smoke_r_24_heavy}} under medium or heavy smoke. At the 8 h sites, it increased from 0.22 to {{n:smoke_r_8_light}} and 0.49, respectively (Table S5, Fig. S6). Excluding smoke-affected days reduced the national day-to-day correlation from 0.40 to 0.24 for 24 h samples and from 0.38 to 0.27 for 8 h samples. For 24 h samples part of this contrast reflects season: {{n:smoke_pct_24_jja}}% of usable summer samples were smoke-affected against {{n:smoke_pct_24_djf}}% in winter, when day-to-day agreement is lowest (Table S4). The 8 h records, nearly all from summer, show a similar drop, so season is not the whole explanation.",
        "For this analysis, smoke polygons were matched to sampling windows widened by 3 h (Sect. S5), classifying 38% of national windows as smoke-affected compared with 30% under strict temporal overlap. The simplest interpretation is again a signal-to-noise effect. At the 24 h sites, the median TEMPO column increased from {{n:smoke_col_24_none}} × 10^{15} molecules cm^{−2} on smoke-free days to {{n:smoke_col_24_light}} under light and {{n:smoke_col_24_heavy}} under medium or heavy smoke, while surface HCHO increased proportionately less. For comparison, the long-term surface record shows a 53% average enhancement of surface HCHO under smoke{{liu2026}}. A roughly fixed retrieval noise therefore becomes a smaller fraction of the satellite signal, allowing the observed correlation to move closer to its ceiling. On this interpretation, the smoke result is another expression of the signal-to-noise effect. It may not be the whole explanation: across sites, the share of smoke-affected samples remained associated with day-to-day agreement after allowing for signal-to-noise ratio (Sect. 3.6), and the seven Colorado monitors show the opposite whole-period pattern, although they include far fewer smoke days (Sect. S6). The 3 h record is too sparse to interpret, with only 295, 95, and 12 samples in the three smoke categories.",
        "Retrieval noise explains only part of why agreement differs so much among monitors. Among the 90 24 h sites with at least 20 successive-scan pairs and 10 anomaly pairs (at {{n:nat_sites_ceiling_undefined}} more the noise bound exceeded the anomaly variance, so no ceiling was defined), the ceiling was high and relatively similar across sites, with a median of {{n:nat_site_ceiling_median}} (interquartile range {{n:nat_site_ceiling_q25}}–{{n:nat_site_ceiling_q75}}). The observed correlations at those sites, by contrast, ranged from {{n:nat_site_obs_min}} to {{n:nat_site_obs_max}} (Fig. S7a). After dividing each site’s observed correlation by its own estimated ceiling, the median noise-corrected value was {{n:nat_site_rcorr_median}} ({{n:nat_site_rcorr_q25}}–{{n:nat_site_rcorr_q75}}). Eleven sites were within 20% of their ceiling (two slightly exceeded it), whereas 37 achieved less than half of it.",
        "Where agreement remains far below the estimated ceiling, other factors must contribute. These could include spatial representativeness, vertical HCHO structure, retrieval biases that persist through the day, or error in the surface measurements; this analysis cannot distinguish among them. Vertical structure alone can be decisive: in the sea-breeze case of {{@souri2023}}, HCHO increasing with altitude made the column negatively correlated with the surface concentration, and the vertical shapes from GEOS-CF, the model that also supplies the boundary-layer height distributed with the TEMPO product, differed enough from a finer regional simulation to change the air mass factor by 20–30%. At the Colorado sites, terrain variability within the TEMPO block, represented by the spread in TEMPO surface pressure, showed no consistent relation to site-level agreement among the four Colorado sites compared in Sect. S6. The uncertainty values reported with individual TEMPO grid cells are larger still and, where evaluated (Sect. S4), would in most formulations leave little or no room for correlations as high as those we observe. They therefore appear to overstate the random error of the scans assigned the largest uncertainties.",
        "For comparisons with 24 h integrated surface samples, averaging TEMPO over a block of a few grid cells (here 3 × 3, about 7 × 5 km) and across all available daylight scans appears to be a reasonable default. {{@rawat2026}} reach a compatible conclusion from the opposite direction, finding that a 10 km collocation radius reproduces results obtained in earlier evaluations using 20–40 km radii. Blocks of this size are smaller than a single OMI nadir pixel of 13 × 24 km{{levelt2006}}, whose effective field of view is broader still and overlaps its neighbors{{degraaf2016}}, so choices of this kind only became testable with TEMPO's finer grid. Larger averaging areas are not always preferable, however: near strong local sources they can dilute local enhancements. The appropriate spatial scale therefore depends on whether the application is intended to represent regional background conditions or near-source concentrations."
      ]
    },
    {
      "h2": "3.4 Days TEMPO Can Use Are Not Representative",
      "p": [
        "Whether a stricter cloud threshold changes the satellite–surface correlation is a separate question from whether the days that pass TEMPO screening are representative of those that do not. Among the 8730 national 24 h samples, 6106 (69.9%) were observable, meaning that at least one TEMPO scan passed all screening criteria. Another 2253 (25.8%) had TEMPO coverage, but no scan passed screening, and 371 (4.2%) had no TEMPO granule at all.",
        "Clouds were the most common reason for screening, but not the only one. When each screening criterion was relaxed one at a time, removing the cloud-fraction threshold would have made at least one scan usable for 1547 of the 2253 screened-out sample days (69%). Relaxing the snow/ice criterion would have rescued 394 days, the solar-zenith-angle limit 189, and the main data-quality flag 8. Another 312 days would still have had no usable scan after relaxing any single criterion. These categories overlap because a sampling period can contain several scans, and different scans can fail different criteria. Thus, the comparison is not simply between clear and cloudy days. It is between days with at least one usable TEMPO observation and days when TEMPO observed the site but every available scan failed screening.",
        "Surface HCHO was systematically higher on observable days (Fig. 3). After controlling for monitor and calendar month, observable days had surface HCHO concentrations 0.52 µg m^{−3} higher than screened-out days (95% CI: 0.43, 0.61; n = 8359 observations at 102 monitors). This difference is about 25% of the national median concentration for the days included in the comparison. A second analysis based on deviations from each site-month mean gave almost the same result: 0.51 µg m^{−3} (95% CI: 0.42, 0.60; 955 site-months at 100 monitors).",
        "The Colorado sites showed the same pattern, although the difference was nominally smaller: 0.38 µg m^{−3} in the regression analysis and 0.36 µg m^{−3} in the site-month analysis (95% CI: 0.13, 0.48). Because this comparison includes only seven monitor clusters, we do not interpret the nominal significance of the cluster-robust regression statistic.",
        "The observability difference was also strongly seasonal. Nationally, surface HCHO on observable days exceeded that on screened-out days by 0.16 µg m^{−3} in winter (95% CI: 0.01, 0.31), 0.47 in spring (95% CI: 0.33, 0.60), 1.00 in summer (95% CI: 0.82, 1.19), and 0.63 in autumn (95% CI: 0.45, 0.80). Relative to the seasonal median concentration, these differences correspond to approximately 10%, 25%, 34%, and 30%, respectively; the winter interval only just excludes zero.",
        "This pattern is opposite to what has been reported for surface NO_{2}. {{@goldberg2025}} found higher NO_{2 }concentrations on cloudy than on clear days at most AQS monitors and attributed part of that difference to slower photochemical loss. For HCHO, higher concentrations on observable days are consistent with stronger production under sunnier and generally warmer conditions, particularly in summer. Temperature alone accounts for about half of the variability in U.S. surface HCHO, with a dependence that resembles biogenic precursor emissions rather than reaction rates{{liu2026}}, so selecting warm days would by itself raise surface HCHO on observable days. However, cloudiness is also related to temperature, biogenic emissions, transport, and boundary-layer structure, and some days fail screening for reasons unrelated to clouds. We therefore interpret this result as an observability-related selection effect, rather than evidence for a single atmospheric mechanism.",
        "The practical implication is that TEMPO-observable days are not a random subset of all monitored days. A surface-HCHO mean calculated only for days with usable TEMPO retrievals would be higher than the corresponding mean over all days with TEMPO coverage. Therefore, if the goal is to estimate a long-term mean rather than a mean conditional on satellite observability, the satellite record should be combined with the surface monitor record for days without a usable TEMPO retrieval."
      ]
    },
    {
      "fig": {
        "file": "fig14_observability_bias.png",
        "caption": "Figure 3. Surface HCHO on days with a usable TEMPO observation and on days for which TEMPO returned granules but no scan passed the full screening criteria, as deviations from the site-month mean, for site-months with at least three sample days containing at least one day of each kind. Days for which TEMPO returned no granule are excluded. Left, the seven Colorado 24 h monitors; right, all 24 h sites in the national comparison. Diamonds are means; the site-month paired difference (the second estimate of Sect. 2.3.2) and its site-cluster bootstrap interval are given in each panel; the vertical axis runs from the 1st percentile to 1.25 times the 99th percentile."
      },
      "p": []
    },
    {
      "h2": "3.5 The Hour of Sampling Matters, but No Single Lag Is Best",
      "p": [
        "Sub-daily samples allow TEMPO observations to be matched more closely to the hours actually covered by the surface sample, but two cautions are important. First, pooling lag curves across sites that sample at different times of day can be misleading. A −3 h shift, for example, moves a 05:00 sample into the middle of the night but a 12:00 sample into mid-morning. We therefore report pooled lag curves only in the Supplement (Fig. S8) and focus here on comparisons by sample start time. Second, shifting an 8 h sample by 3 h still leaves five hours of overlap with the original window, so large changes are not expected. Consistent with that, the 8 h within-month anomaly correlations changed little with lag (0.31, 0.38, and 0.35 at −3, 0, and +3 h), the sampling window itself giving the highest. The more informative comparison is therefore by the hour at which sampling begins (Fig. S9).",
        "When grouped by start time, the pattern across the four 3 h sites differs from what the two Colorado sites alone would suggest. At the two California sites, the 3 h window beginning at 05:00 LST performed about as well as the midday window beginning at 12:00: the day-to-day correlations were 0.43 (n = 99) and 0.41 (n = 100), respectively. By contrast, the late-afternoon window beginning at 16:00 showed little agreement (r = 0.17, n = 91, p = 0.11). The Colorado window beginning at 06:00 MST was the weakest of these four windows (r = 0.11, n = 79, p = 0.38).",
        "The Colorado sites are useful because both sample the same fixed 06:00–09:00 MST window on every sampling day, allowing a direct comparison between TEMPO observations during sampling and those in the hours that follow. In the separate Colorado 3 h analysis, which independently reconstructs the samples and extends Platteville back to August 2023, the two sites behave quite differently (Table S6, Figs. S10–S11). At Chatfield State Park, the TEMPO column during the sampling window shows essentially no day-to-day agreement with surface HCHO (r = −0.01, n = 47), whereas the window three hours later shows substantially stronger agreement (r = 0.48, n = 64). At Platteville, neither the sampling window nor the +3 h window shows clear day-to-day agreement (r = 0.24 and 0.15, or 0.25 and 0.26 without the 2023 samples; Table S7). When the comparison is restricted to days with usable TEMPO observations in both windows (Fig. S12), the correlation increases by 0.57 at Chatfield (Williams' test, p = 0.008) but by only 0.07 at Platteville (p = 0.71). Pooling the two sites gives an increase of 0.29 (p = 0.045), but we do not place much weight on that pooled estimate because the two monitors, 78 km apart, behave differently.",
        "The 8 h sites point the same way, although the difference between their blocks was not tested formally. Across the 40 sites, the block beginning at 12:00 LST had a day-to-day correlation of 0.42 (n = 1754), compared with 0.34 (n = 1698) for the block beginning at 04:00, which spans the morning transition. Because nearly all 8 h samples use the same three sampling blocks, this comparison holds the sampling schedule constant and varies only the time of day.",
        "At the two California sites, morning sampling was not inherently difficult to match to a satellite column. One possible explanation for weaker early-morning agreement is reduced satellite sensitivity to near-surface pollution. {{@nawaz2025}} found that TEMPO NO_{2} agreement was weakest in the early morning, with R^{2} = 0.23 at 06:00 and 0.35 at 07:00 local time, and attributed this partly to the longer light path and weaker sensitivity near the surface. The same mechanism could affect HCHO. Our results suggest, however, that it cannot explain the full pattern. The California sites begin sampling even earlier, yet their morning windows agree well with the surface measurements. At the 24 h sites, TEMPO columns from 06:00–09:00 local standard time carry only slightly less day-to-day information than those from 09:00–12:00: the within-month anomaly correlations are {{n:nat_tod_r_0609}} and {{n:nat_tod_r_0912}}, respectively, across {{n:nat_tod_n}} site-days with valid observations in both windows, in site-months with at least three such days (Williams' test, p = {{n:nat_tod_p}}). Among the {{n:nat_tod_sites}} sites with at least 20 such days, the later window had the higher correlation at {{n:nat_tod_sites_late_better}} sites, significantly so at {{nw:nat_tod_sites_sig}}, while the morning window was significantly higher at {{nw:nat_tod_sites_sig_lower}}. This modest morning penalty is too small to explain the much larger contrast at Chatfield.",
        "Changes in boundary-layer structure provide another plausible explanation, although we treat this as a hypothesis rather than a demonstrated mechanism. As the morning mixed layer deepens, the surface measurement may become representative of a larger fraction of the atmospheric column, increasing agreement with TEMPO. In the Colorado 3 h record, the median TEMPO boundary-layer height rises from 0.45 km during sampling to 1.50 km three hours later, while H_{eff} changes little, from 0.98 to 0.93 km. This is consistent with a change in vertical distribution without a similar change in the total column. The columns of the two windows were themselves only weakly correlated at Chatfield (r = 0.27 over the whole period and 0.01 for within-month anomalies) but more strongly at Platteville (r = 0.61 and 0.31; Fig. S12). The site-level pattern also fits this interpretation: Chatfield State Park, near the Front Range where strong morning stability and drainage flows are plausible, shows almost no agreement during sampling but much stronger agreement three hours later, whereas Platteville, on the open plains of the Denver-Julesburg Basin, shows no comparable improvement. Uneven vertical mixing of this kind is what degraded the column HCHO/NO_{2} ratio as a surface indicator in the DISCOVER-AQ profiles, which included the Colorado Front Range{{schroeder2017}}. That the best window should differ between sites is consistent with the TEMPO record itself: across 1.2 million observations from the 2024 growing season, the daylight evolution of HCHO took several regionally distinct forms, from steady accumulation over the northeastern forests to midday maxima over oil, gas, and agricultural regions{{souri2026}}. With only four 3 h sites, however, two of them 178 km apart in a single California air basin, these data cannot establish the mechanism. Co-located boundary-layer observations or lag analyses stratified by atmospheric stability would be needed to test it directly. Section 3.6 provides an indirect test across the 8 h network, using modelled mixing depth.",
        "The practical implication is not that satellite observations should always be matched exactly to the sampling window, nor that they should always be shifted by three hours. Rather, the most appropriate timing should be evaluated rather than assumed. For 24 h samples, averaging across all available daylight scans is a reasonable compromise. For programs designing sub-daily carbonyl sampling, a window centered closer to midday is a more robust starting point, although the optimal timing is likely to remain site-specific. Accurate sampling metadata are therefore essential: without the start times recorded in AQS, the Colorado sampling window would have been assigned incorrectly, and the best-fitting satellite window could have been mistaken for the actual sampling period."
      ]
    },
    {
      "h2": "3.6 Why Agreement Differs: Duration, Noise, Averaging, and Mixing Depth",
      "p": [
        "Sample duration. At the {{n:dd_sites_paired}} dual-duration monitors with at least {{n:dd_min_pairs}} anomaly pairs at both durations, the 8 h and 24 h records showed no detectable difference in agreement with TEMPO. The 8 h records come almost entirely from the summer ozone season, whereas the 24 h records span the year. The median within-month correlation was {{n:dd_median_r_24}} at 24 h and {{n:dd_median_r_8}} at 8 h, the paired difference (8 h minus 24 h) had a median of {{n:dd_diff_median}} (mean {{n:dd_diff_mean}}, 95% CI: {{n:dd_diff_lo}}, {{n:dd_diff_hi}}; {{n:dd_diff_positive}} of {{n:dd_sites_paired}} sites positive; Wilcoxon p = {{n:dd_diff_p}}), and neither the 12:00 block nor the 04:00 block alone differed from the 24 h record (medians {{n:dd_diff12_median}} and {{n:dd_diff4_median}}; Fig. S13, Table S8). Restricting the 24 h anomalies to the site-months in which the same monitor also reported 8 h samples left the comparison unchanged: at the {{n:dd_sm_sites}} monitors with at least {{n:dd_min_pairs}} pairs in both records, the paired difference had a median of {{n:dd_sm_diff_median}} (mean {{n:dd_sm_diff_mean}}, 95% CI: {{n:dd_sm_lo}}, {{n:dd_sm_hi}}; Wilcoxon p = {{n:dd_sm_p}}). The anomaly slopes did not differ either. Restricting the column rather than the sample was slightly harmful: correlating the 24 h surface sample with only the scans between 12:00 and 20:00 LST changed its correlation by {{n:dd_col12_mean}} on average (95% CI: {{n:dd_col12_lo}}, {{n:dd_col12_hi}}), and using only the 04:00–12:00 scans by {{n:dd_col4_mean}} ({{n:dd_col4_lo}}, {{n:dd_col4_hi}}), consistent with fewer scans being averaged. Against the same restricted column, the 8 h sample agreed slightly better than the 24 h sample (means {{n:dd_same12_mean}} and {{n:dd_same4_mean}}, neither distinguishable from zero). Sample duration itself therefore explains little of the difference between the 24 h and 8 h columns of Table 1; which sites report each duration, and how many scans are averaged, matter more.",
        "Site heterogeneity and the noise ceiling. Across the {{n:gap_sites}} 24 h sites with a ceiling, the median E was {{n:gap_median_E}} (interquartile range {{n:gap_E_iqr_lo}}–{{n:gap_E_iqr_hi}}). The six site descriptors together explained {{n:gap_m1_r2_pct}}% of the variance in the Fisher-transformed observed correlation (adjusted R^{2} 0.18), largely through the signal-to-noise ratio ({{n:gap_m1_snr_coef}} per standard deviation, p = {{n:gap_m1_snr_p}}; Spearman ρ = {{n:gap_uni_r_snr_rho}}), with an additional association with smoke prevalence ({{n:gap_m1_smoke_coef}}, p = {{n:gap_m1_smoke_p}}); median concentration, scan count, usable share and mixing depth added nothing once these were included. For E the same descriptors explained only {{n:gap_m2_r2_pct}}% of the variance and no coefficient was distinguishable from zero (Table S9, Fig. S7b). Beyond the signal-to-noise ratio and the smoke-affected share, the descriptors therefore explain little of the site-to-site spread. None of them detectably predicted how close a monitor came to its ceiling, which points to unmeasured local factors, such as how representative the monitor is of a 7 km block, the vertical distribution of HCHO, or measurement error at the monitor; which of these matters cannot be resolved with a national dataset.",
        "Temporal averaging. The noise-averaging explanation of Sect. 3.3 can be tested directly. Among the {{n:ta_samples}} 24 h samples with at least four valid scans in every block, a single randomly chosen 3 × 3 scan gave a pooled within-month correlation of {{n:ta_r1_33}} (95% range over draws: {{n:ta_r1_33_lo}}, {{n:ta_r1_33_hi}}); two scans gave {{n:ta_r2_33}}, three {{n:ta_r3_33}}, four {{n:ta_r4_33}}, and all scans (median seven) {{n:ta_rall_33}} (Fig. 4, Table S10). The same curve ran from {{n:ta_r1_11}} to {{n:ta_rall_11}} for a single grid cell and from {{n:ta_r1_55}} to {{n:ta_rall_55}} for the 5 × 5 block, so one scan of the largest block was worth about as much as three to four scans of the smallest: averaging in time and averaging in space can partly substitute for one another in reducing retrieval noise. The median site-level correlation, over the {{n:ta_sites}} sites with at least 10 anomaly pairs, rose from {{n:ta_siter1_33}} to {{n:ta_siterall_33}} at the 3 × 3 block. The standard deviation of the column anomaly fell from {{n:ta_sd1_33}} to {{n:ta_sdall_33}} × 10^{15} molecules cm^{−2} between one scan and all scans, and its variance was linear in 1/k (R^{2} > 0.99), consistent with a dominant, approximately independent scan-level noise component. The slope implies a single-scan noise of {{n:ta_noise_11}}, {{n:ta_noise_33}} and {{n:ta_noise_55}} × 10^{15} molecules cm^{−2} for the 1 × 1, 3 × 3 and 5 × 5 blocks, against site medians of {{n:nc_single_median_11}}, {{n:nc_single_median_33}} and {{n:nc_single_median_55}} from the scan-difference estimator. The two estimates, derived in different ways, agree closely, which supports the noise term behind the ceiling of Sect. 3.3; both, however, count real within-day change in the column as noise, so neither can separate it from retrieval error."
      ]
    },
    {
      "fig": {
        "file": "fig22_temporal_averaging.png",
        "caption": "Figure 4. Pooled within-month anomaly correlation between surface HCHO and the TEMPO column as a function of the number of scans averaged per 24 h sample, for the {{n:ta_samples}} samples with at least four valid scans in every spatial block ({{n:ta_pairs}} within-month anomaly pairs). For k = 1 to 4 the scans are drawn at random without replacement and the band is the 2.5–97.5% range over {{n:ta_draws}} draws; \"all\" uses every valid scan (median seven for the 1 × 1 and 3 × 3 blocks, eight for the 5 × 5; Table S10)."
      },
      "p": []
    },
    {
      "p": [
        "Mixing depth. Agreement varied with modelled mixing depth in both 8 h blocks to a similar degree; on smoke-free days the gradient fell to {{n:pbl_8h4_sf_diff}} in the morning block and {{n:pbl_8h12_sf_diff}} at midday, and only in the morning block did it stay monotonic, with an interval just excluding zero. For the 8 h block beginning at 04:00 LST, which spans the morning transition, the anomaly correlation rose from {{n:pbl_8h4_r_low}} in the shallowest tertile of HRRR mixing depth (median {{n:pbl_8h4_km_low}} km) to {{n:pbl_8h4_r_mid}} in the middle tertile and {{n:pbl_8h4_r_high}} in the deepest ({{n:pbl_8h4_km_high}} km; difference {{n:pbl_8h4_diff}}, 95% CI: {{n:pbl_8h4_lo}}, {{n:pbl_8h4_hi}}; n = {{n:pbl_8h4_n}} at {{n:pbl_8h4_sites}} sites; Fig. 5, Table S11). Defining the tertiles relative to each site-month gave {{n:pbl_8h4_rel_r_low}}, {{n:pbl_8h4_rel_r_mid}} and {{n:pbl_8h4_rel_r_high}} (difference {{n:pbl_8h4_rel_diff}}; 95% CI: {{n:pbl_8h4_rel_lo}}, {{n:pbl_8h4_rel_hi}}), and on smoke-free days, with the anomalies recomputed from those days alone, {{n:pbl_8h4_sf_r_low}}, {{n:pbl_8h4_sf_r_mid}} and {{n:pbl_8h4_sf_r_high}} (difference {{n:pbl_8h4_sf_diff}}; 95% CI: {{n:pbl_8h4_sf_lo}}, {{n:pbl_8h4_sf_hi}}): the gradient persists without smoke but is about half as large, and the lower bound of its interval is close to zero. The standard deviation of the column anomalies was no larger in the deep tertile ({{n:pbl_8h4_sdcol_high}} against {{n:pbl_8h4_sdcol_low}} × 10^{15} molecules cm^{−2}), so the gradient does not come from larger column variability in the deep tertile; because that tertile also averaged slightly more scans, the scan-adjusted interaction below is the firmer test. In the interaction model the column–surface slope, in µg m^{−3} per standard deviation of the column anomaly, increased by {{n:pbl_int_8h4}} per standard deviation of the mixing-depth anomaly (cluster-robust {{n:pbl_int_8h4_ptxt}}), and by {{n:pbl_int_adj_8h4}} ({{n:pbl_int_adj_8h4_ptxt}}) once the slope was also allowed to depend on the number of valid scans and on the column level. The midday block showed a similar gradient ({{n:pbl_8h12_r_low}}, {{n:pbl_8h12_r_mid}} and {{n:pbl_8h12_r_high}}; difference {{n:pbl_8h12_diff}}, 95% CI: {{n:pbl_8h12_lo}}, {{n:pbl_8h12_hi}}; adjusted interaction {{n:pbl_int_adj_8h12}}, {{n:pbl_int_adj_8h12_ptxt}}), but it was not monotonic on smoke-free days ({{n:pbl_8h12_sf_r_low}}, {{n:pbl_8h12_sf_r_mid}} and {{n:pbl_8h12_sf_r_high}}; difference {{n:pbl_8h12_sf_diff}}, 95% CI: {{n:pbl_8h12_sf_lo}}, {{n:pbl_8h12_sf_hi}}), so part of the midday pattern depends on smoke-affected days. For 24 h samples the gradient was weaker ({{n:pbl_24_r_low}} to {{n:pbl_24_r_high}} by absolute tertile; {{n:pbl_24_rel_r_low}} to {{n:pbl_24_rel_r_high}} relative to the site-month, difference {{n:pbl_24_rel_diff}}, 95% CI: {{n:pbl_24_rel_lo}}, {{n:pbl_24_rel_hi}}; interaction {{n:pbl_int_24}}, {{n:pbl_int_24_ptxt}}) and disappeared once scan count and column level were allowed for (interaction {{n:pbl_int_adj_24}}, {{n:pbl_int_adj_24_ptxt}}) and on smoke-free days ({{n:pbl_24_sf_r_low}}, {{n:pbl_24_sf_r_mid}} and {{n:pbl_24_sf_r_high}}).",
        "Mixing depth is therefore associated with coupling in both 8 h blocks, and the association is somewhat more robust to smoke in the 04:00 block, whose window spans the growth of the mixed layer; whether the same process explains the Colorado 06:00–09:00 contrast remains a hypothesis (Sect. 3.5). For a daily mean the gradient is largely accounted for by scan count, column level and smoke. The 8 h association is consistent with the modelled decoupling described by {{@souri2023}}: when the surface is decoupled from the column above it, an accurate column carries little information about the surface. It also suggests a practical screen. A meteorological analysis, available everywhere and independent of both measurements, can help identify the sub-daily samples for which a column-to-surface comparison is likely to be informative."
      ]
    },
    {
      "fig": {
        "file": "fig23_pbl_tertiles.png",
        "caption": "Figure 5. Within-month anomaly correlation between surface HCHO and the TEMPO column by tertile of the HRRR mixing depth averaged over the sampling window, for 8 h samples beginning at 04:00 and 12:00 LST and for 24 h samples. Tertiles are defined on the absolute mixing depth, on its deviation from the site-month mean, and on that deviation with the anomalies recomputed from smoke-free days only. Anomalies are computed within site, month and start hour."
      },
      "p": []
    },
    {
      "h2": "3.7 Implications and Limitations",
      "p": [
        "TEMPO provides useful seasonal and episodic context for air-toxics monitoring across the United States and substantially extends earlier national surface-satellite HCHO comparisons, which used long-term means: {{@zhu2017}} found summertime OMI-derived surface concentrations, converted to annual means, a factor of 1.9 below the annual means of the EPA network, and {{@wang2022}} compared seasonal means at 45 AQS sites with OMI columns and found agreement in summer but not winter, with seasonal variability 20–100% larger in the column than at the surface. TEMPO reproduces both of Wang et al.'s findings: across sites, seasonal mean columns were weakly but significantly related to surface concentrations in spring, summer and autumn but not in winter, and the column's seasonal amplitude was a median {{n:seas_amp_ratio_median}} times the surface's (Sect. 3.1). Winter agreement is weak but not absent from day to day ({{n:seas_dd_24_djf}}), and TEMPO’s repeated daytime sampling makes it possible to move beyond seasonal averages: 70% of individual 24 h surface samples now have at least one usable satellite observation. The distinction between column and surface also matters for applications framed in terms of surface conditions, from emission inversions{{palmer2003}}{{millet2008}}{{zhu2014}} to ozone-sensitivity indicators built on the column HCHO/NO_{2} ratio{{martin2004}}{{duncan2010}}: at a given monitor, weak day-to-day agreement need not mean a poor retrieval and can instead reflect real vertical structure{{schroeder2017}}{{souri2023}}.",
        "Taken together, Sects. 3.3 and 3.6 give a three-part account of agreement: retrieval noise sets an upper bound on it; spatial and temporal averaging raise that bound by reducing the noise; and, for sub-daily samples, the vertical coupling between the surface and the column, as indexed by modelled mixing depth, appears to modulate how closely the two track each other. The ability of TEMPO to track day-to-day surface variation is strongest when satellite observations are averaged spatially, when the column's day-to-day signal is large relative to retrieval noise, and when satellite observations are matched to times of day when the surface and column are most closely coupled. The mixing-depth dependence of Sect. 3.6 suggests that this coupling can be partly diagnosed from a meteorological analysis rather than assumed. Importantly, these conditions can now be evaluated at individual monitors rather than assumed from a network-wide average. Future comparisons would benefit from pairing satellite observations with time-resolved surface measurements, preserving accurate sample start and end times, and, where program objectives allow, favoring sampling windows centered closer to midday.",
        "Several limitations should temper these conclusions. The study covers only two years. The sub-daily analysis includes 40 sites with a common 8 h sampling schedule but only four sites with 3 h samples, two of them in Colorado. Evidence that early-morning sampling can perform well therefore comes largely from two California sites in the same air basin. Sample duration and time of day are also partly confounded because different sampling durations are used by different sites and monitoring programs. We therefore compare sampling windows only among observations of the same duration. Of the {{n:dd_sites_total}} sites that report both durations, {{n:dd_sites_paired}} had at least 10 anomaly pairs at both durations for the within-site comparison in Sect. 3.6, which found no systematic effect of duration.",
        "The surface measurements also carry uncertainty. Integrated DNPH samples are subject to sampling artifacts and calibration differences. Ozone can cause a negative interference{{arnts1989}}, which would lower measured surface HCHO and increase H_{eff}. Calibration differences among HCHO measurement techniques can also be substantial{{jeong2026}}.",
        "TEMPO observes only during daylight, whereas a 24 h surface sample integrates daytime and nighttime HCHO. Whenever the day-to-day variation of nighttime concentrations differs from that of daytime concentrations, the two quantities will disagree even if the daytime retrieval were perfect; this temporal representativeness error cannot be removed by improving the satellite product, and it is the temporal analogue of the vertical representativeness problem of Sect. 3.6. The paired comparison of Sect. 3.6 suggests, however, that it is not the dominant limitation: at monitors reporting both durations, day-to-day agreement with TEMPO was not detectably different between 24 h and 8 h samples (median r = {{n:dd_median_r_24}} at 24 h and {{n:dd_median_r_8}} at 8 h, with a paired difference near zero also when the 24 h record was restricted to the months of the 8 h record), the 12:00–20:00 LST block, which has the greatest overlap with TEMPO's daylight observing period, did no better than the 24 h record (median difference {{n:dd_diff12_median}}), and restricting the 24 h comparison to daylight sub-windows lowered agreement, consistent with fewer scans being averaged. The timing analyses are limited by TEMPO coverage. The solar-zenith-angle screen restricts the usable hours, and the national extraction extends only 3 h before and after each sampling window. The 20:00 LST 8 h sampling block, for example, falls largely outside daylight TEMPO coverage. TEMPO V04 HCHO is also provisional, and scans were assigned to surface sampling periods using the granule midpoint rather than the exact observation time over each site.",
        "The boundary-layer and smoke diagnostics should likewise be interpreted cautiously. TEMPO boundary-layer height comes from the GEOS-CF model supplied with the retrieval rather than from direct observations; during TEMPO observing hours it is a median {{n:met_pbl_tempo_minus_hrrr}} m, or about {{n:met_pbl_pct_deeper}}%, deeper than the corresponding HRRR estimate (Table S3). Hazard Mapping System smoke classification is qualitative and column-based{{brey2018}}, so a smoke flag indicates that a plume was present overhead, not how much smoke reached the surface.",
        "Finally, the permutation procedure accounts for the way anomalies are constructed within site-months but does not capture every form of temporal dependence. For that reason, the overall distribution of site-level correlations remains more informative than the number of individual monitors reaching nominal statistical significance."
      ]
    }
  ],
  "backmatter": [
    {
      "h1": "Code and data availability",
      "p": [
        "The R code used for data retrieval, processing, statistics and figures is available at https://github.com/pdez90/coatts_hcho [archive a release on Zenodo and cite its DOI here]. National formaldehyde samples, sample times and monitor metadata are from the U.S. EPA Air Quality System{{epaaqs2026}}. The code also downloads CDPHE's annual formaldehyde data packets from the CDPHE Air Toxics and Ozone Precursor Data Repository{{cdpherepo2026}}, for ancillary fields on which no reported result depends. TEMPO Level 3 V04 HCHO data are available from the NASA Langley Atmospheric Science Data Center (https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004; {{~tempol3v4}}). NOAA Hazard Mapping System smoke polygons are available from {{@noaahms2026}}. HRRR analyses were read from the NOAA Open Data Dissemination HRRR archive on Amazon Web Services (https://noaa-hrrr-bdp-pds.s3.amazonaws.com/). [Decide whether to deposit the matched site–scan dataset with a DOI.]"
      ]
    },
    {
      "h1": "Supplement",
      "p": [
        "The supplement related to this article is available online at: [DOI assigned by Copernicus]. It contains the Colorado site descriptions and quality control, the extraction and statistical methods, the retrieval-noise estimator, the smoke classification, checks at the Colorado sites, Figs. S1–S13 and Tables S1–S11."
      ]
    },
    {
      "h1": "Author contributions",
      "p": [
        "[To be completed: e.g. PdS designed the study, performed the analysis and wrote the manuscript; … All authors reviewed and edited the manuscript.]"
      ]
    },
    {
      "h1": "Competing interests",
      "p": [
        "The authors declare that they have no conflict of interest. [Confirm; Copernicus also asks whether any author is a member of the AMT editorial board.]"
      ]
    },
    {
      "h1": "Acknowledgements",
      "p": [
        "We thank the CDPHE Air Pollution Control Division Air Toxics and Ozone Precursors programme for collecting and publishing the monitoring data and for answering our questions about it [names, with permission], the TEMPO science team and the NASA Atmospheric Science Data Center for the TEMPO products, and NOAA Hazard Mapping System analysts for the smoke analyses."
      ]
    },
    {
      "h1": "Financial support",
      "p": [
        "[Funding to be completed, in the Copernicus form: This research has been supported by the … (grant no. …).]"
      ]
    }
  ],
  "authors": [
    "[[Author list, affiliations and corresponding author to be completed.]]"
  ],
  "refs": {
    "zhu2017": {
      "label": "Zhu et al., 2017",
      "names": "Zhu et al.",
      "year": "2017",
      "sort": "zhu 2 2017 formaldehyde (hcho) as a hazardous air pollutant: mapping surface air concentrations from satellite and inferring cancer risks in the united states",
      "text": "Zhu, L., Jacob, D. J., Keutsch, F. N., Mickley, L. J., Scheffe, R., Strum, M., González Abad, G., Chance, K., Yang, K., Rappenglück, B., Millet, D. B., Baasandorj, M., Jaeglé, L., and Shah, V.: Formaldehyde (HCHO) as a hazardous air pollutant: mapping surface air concentrations from satellite and inferring cancer risks in the United States, Environ. Sci. Technol., 51, 5650–5657, https://doi.org/10.1021/acs.est.7b01356, 2017."
    },
    "parrish2012": {
      "label": "Parrish et al., 2012",
      "names": "Parrish et al.",
      "year": "2012",
      "sort": "parrish 2 2012 primary and secondary sources of formaldehyde in urban atmospheres: houston texas region",
      "text": "Parrish, D. D., Ryerson, T. B., Mellqvist, J., Johansson, J., Fried, A., Richter, D., Walega, J. G., Washenfelder, R. A., de Gouw, J. A., Peischl, J., Aikin, K. C., McKeen, S. A., Frost, G. J., Fehsenfeld, F. C., and Herndon, S. C.: Primary and secondary sources of formaldehyde in urban atmospheres: Houston Texas region, Atmos. Chem. Phys., 12, 3273–3288, https://doi.org/10.5194/acp-12-3273-2012, 2012."
    },
    "liu2026": {
      "label": "Liu and Jaffe, 2026",
      "names": "Liu and Jaffe",
      "year": "2026",
      "sort": "liu 1 2026 surface atmospheric formaldehyde trends in the u.s. driven by temperature-dependent biogenic precursor emissions and influenced by wildfires",
      "text": "Liu, S. and Jaffe, D. A.: Surface atmospheric formaldehyde trends in the U.S. driven by temperature-dependent biogenic precursor emissions and influenced by wildfires, ACS ES&T Air, 3, 1167–1175, https://doi.org/10.1021/acsestair.6c00010, 2026."
    },
    "liao2021": {
      "label": "Liao et al., 2021",
      "names": "Liao et al.",
      "year": "2021",
      "sort": "liao 2 2021 formaldehyde evolution in us wildfire plumes during the fire influence on regional to global environments and air quality experiment (firex-aq)",
      "text": "Liao, J., Wolfe, G. M., Hannun, R. A., St. Clair, J. M., Hanisco, T. F., Gilman, J. B., Lamplugh, A., Selimovic, V., Diskin, G. S., Nowak, J. B., Halliday, H. S., DiGangi, J. P., Hall, S. R., Ullmann, K., Holmes, C. D., Fite, C. H., Agastra, A., Ryerson, T. B., Peischl, J., Bourgeois, I., Warneke, C., Coggon, M. M., Gkatzelis, G. I., Sekimoto, K., Fried, A., Richter, D., Weibring, P., Apel, E. C., Hornbrook, R. S., Brown, S. S., Womack, C. C., Robinson, M. A., Washenfelder, R. A., Veres, P. R., and Neuman, J. A.: Formaldehyde evolution in US wildfire plumes during the Fire Influence on Regional to Global Environments and Air Quality experiment (FIREX-AQ), Atmos. Chem. Phys., 21, 18319–18331, https://doi.org/10.5194/acp-21-18319-2021, 2021."
    },
    "desmedt2008": {
      "label": "De Smedt et al., 2008",
      "names": "De Smedt et al.",
      "year": "2008",
      "sort": "de smedt 2 2008 twelve years of global observations of formaldehyde in the troposphere using gome and sciamachy sensors",
      "text": "De Smedt, I., Müller, J.-F., Stavrakou, T., van der A, R., Eskes, H., and Van Roozendael, M.: Twelve years of global observations of formaldehyde in the troposphere using GOME and SCIAMACHY sensors, Atmos. Chem. Phys., 8, 4947–4963, https://doi.org/10.5194/acp-8-4947-2008, 2008."
    },
    "levelt2006": {
      "label": "Levelt et al., 2006",
      "names": "Levelt et al.",
      "year": "2006",
      "sort": "levelt 2 2006 the ozone monitoring instrument",
      "text": "Levelt, P. F., van den Oord, G. H. J., Dobber, M. R., Mälkki, A., Visser, H., de Vries, J., Stammes, P., Lundell, J. O. V., and Saari, H.: The Ozone Monitoring Instrument, IEEE Trans. Geosci. Remote Sens., 44, 1093–1101, https://doi.org/10.1109/TGRS.2006.872333, 2006."
    },
    "streets2013": {
      "label": "Streets et al., 2013",
      "names": "Streets et al.",
      "year": "2013",
      "sort": "streets 2 2013 emissions estimation from satellite retrievals: a review of current capability",
      "text": "Streets, D. G., Canty, T., Carmichael, G. R., de Foy, B., Dickerson, R. R., Duncan, B. N., Edwards, D. P., Haynes, J. A., Henze, D. K., Houyoux, M. R., Jacob, D. J., Krotkov, N. A., Lamsal, L. N., Liu, Y., Lu, Z., Martin, R. V., Pfister, G. G., Pinder, R. W., Salawitch, R. J., and Wecht, K. J.: Emissions estimation from satellite retrievals: a review of current capability, Atmos. Environ., 77, 1011–1042, https://doi.org/10.1016/j.atmosenv.2013.05.051, 2013."
    },
    "palmer2003": {
      "label": "Palmer et al., 2003",
      "names": "Palmer et al.",
      "year": "2003",
      "sort": "palmer 2 2003 mapping isoprene emissions over north america using formaldehyde column observations from space",
      "text": "Palmer, P. I., Jacob, D. J., Fiore, A. M., Martin, R. V., Chance, K., and Kurosu, T. P.: Mapping isoprene emissions over North America using formaldehyde column observations from space, J. Geophys. Res., 108, 4180, https://doi.org/10.1029/2002JD002153, 2003."
    },
    "millet2006": {
      "label": "Millet et al., 2006",
      "names": "Millet et al.",
      "year": "2006",
      "sort": "millet 2 2006 formaldehyde distribution over north america: implications for satellite retrievals of formaldehyde columns and isoprene emission",
      "text": "Millet, D. B., Jacob, D. J., Turquety, S., Hudman, R. C., Wu, S., Fried, A., Walega, J., Heikes, B. G., Blake, D. R., Singh, H. B., Anderson, B. E., and Clarke, A. D.: Formaldehyde distribution over North America: implications for satellite retrievals of formaldehyde columns and isoprene emission, J. Geophys. Res., 111, D24S02, https://doi.org/10.1029/2005JD006853, 2006."
    },
    "millet2008": {
      "label": "Millet et al., 2008",
      "names": "Millet et al.",
      "year": "2008",
      "sort": "millet 2 2008 spatial distribution of isoprene emissions from north america derived from formaldehyde column measurements by the omi satellite sensor",
      "text": "Millet, D. B., Jacob, D. J., Boersma, K. F., Fu, T.-M., Kurosu, T. P., Chance, K., Heald, C. L., and Guenther, A.: Spatial distribution of isoprene emissions from North America derived from formaldehyde column measurements by the OMI satellite sensor, J. Geophys. Res., 113, D02307, https://doi.org/10.1029/2007JD008950, 2008."
    },
    "barkley2013": {
      "label": "Barkley et al., 2013",
      "names": "Barkley et al.",
      "year": "2013",
      "sort": "barkley 2 2013 top-down isoprene emissions over tropical south america inferred from sciamachy and omi formaldehyde columns",
      "text": "Barkley, M. P., De Smedt, I., Van Roozendael, M., Kurosu, T. P., Chance, K., Arneth, A., Hagberg, D., Guenther, A., Paulot, F., Marais, E., and Mao, J.: Top-down isoprene emissions over tropical South America inferred from SCIAMACHY and OMI formaldehyde columns, J. Geophys. Res. Atmos., 118, 6849–6868, https://doi.org/10.1002/jgrd.50552, 2013."
    },
    "zhu2014": {
      "label": "Zhu et al., 2014",
      "names": "Zhu et al.",
      "year": "2014",
      "sort": "zhu 2 2014 anthropogenic emissions of highly reactive volatile organic compounds in eastern texas inferred from oversampling of satellite (omi) measurements of hcho columns",
      "text": "Zhu, L., Jacob, D. J., Mickley, L. J., Marais, E. A., Cohan, D. S., Yoshida, Y., Duncan, B. N., González Abad, G., and Chance, K. V.: Anthropogenic emissions of highly reactive volatile organic compounds in eastern Texas inferred from oversampling of satellite (OMI) measurements of HCHO columns, Environ. Res. Lett., 9, 114004, https://doi.org/10.1088/1748-9326/9/11/114004, 2014."
    },
    "bauwens2022": {
      "label": "Bauwens et al., 2022",
      "names": "Bauwens et al.",
      "year": "2022",
      "sort": "bauwens 2 2022 spaceborne evidence for significant anthropogenic voc trends in asian cities over 2005-2019",
      "text": "Bauwens, M., Verreyken, B., Stavrakou, T., Müller, J.-F., and De Smedt, I.: Spaceborne evidence for significant anthropogenic VOC trends in Asian cities over 2005-2019, Environ. Res. Lett., 17, 015008, https://doi.org/10.1088/1748-9326/ac46eb, 2022."
    },
    "feng2024": {
      "label": "Feng et al., 2024",
      "names": "Feng et al.",
      "year": "2024",
      "sort": "feng 2 2024 constraining non-methane voc emissions with tropomi hcho observations: impact on summertime ozone simulation in august 2022 in china",
      "text": "Feng, S., Jiang, F., Qian, T., Wang, N., Jia, M., Zheng, S., Chen, J., Ying, F., and Ju, W.: Constraining non-methane VOC emissions with TROPOMI HCHO observations: impact on summertime ozone simulation in August 2022 in China, Atmos. Chem. Phys., 24, 7481–7498, https://doi.org/10.5194/acp-24-7481-2024, 2024."
    },
    "martin2004": {
      "label": "Martin et al., 2004",
      "names": "Martin et al.",
      "year": "2004",
      "sort": "martin 2 2004 space-based diagnosis of surface ozone sensitivity to anthropogenic emissions",
      "text": "Martin, R. V., Fiore, A. M., and Van Donkelaar, A.: Space-based diagnosis of surface ozone sensitivity to anthropogenic emissions, Geophys. Res. Lett., 31, L06120, https://doi.org/10.1029/2004GL019416, 2004."
    },
    "duncan2010": {
      "label": "Duncan et al., 2010",
      "names": "Duncan et al.",
      "year": "2010",
      "sort": "duncan 2 2010 application of omi observations to a space-based indicator of nox and voc controls on surface ozone formation",
      "text": "Duncan, B. N., Yoshida, Y., Olson, J. R., Sillman, S., Martin, R. V., Lamsal, L., Hu, Y., Pickering, K. E., Retscher, C., Allen, D. J., and Crawford, J. H.: Application of OMI observations to a space-based indicator of NOx and VOC controls on surface ozone formation, Atmos. Environ., 44, 2213–2223, https://doi.org/10.1016/j.atmosenv.2010.03.010, 2010."
    },
    "souri2023": {
      "label": "Souri et al., 2023",
      "names": "Souri et al.",
      "year": "2023",
      "sort": "souri 2 2023 decoupling in the vertical shape of hcho during a sea breeze event: the effect on trace gas satellite retrievals and column-to-surface translation",
      "text": "Souri, A. H., Kumar, R., Chong, H., Golbazi, M., Knowland, K. E., Geddes, J., and Johnson, M. S.: Decoupling in the vertical shape of HCHO during a sea breeze event: the effect on trace gas satellite retrievals and column-to-surface translation, Atmos. Environ., 309, 119929, https://doi.org/10.1016/j.atmosenv.2023.119929, 2023."
    },
    "zoogman2017": {
      "label": "Zoogman et al., 2017",
      "names": "Zoogman et al.",
      "year": "2017",
      "sort": "zoogman 2 2017 tropospheric emissions: monitoring of pollution (tempo)",
      "text": "Zoogman, P., Liu, X., Suleiman, R. M., Pennington, W. F., Flittner, D. E., Al-Saadi, J. A., Hilton, B. B., Nicks, D. K., Newchurch, M. J., Carr, J. L., Janz, S. J., Andraschko, M. R., Arola, A., Baker, B. D., Canova, B. P., Chan Miller, C., Cohen, R. C., Davis, J. E., Dussault, M. E., Edwards, D. P., Fishman, J., Ghulam, A., González Abad, G., Grutter, M., Herman, J. R., Houck, J., Jacob, D. J., Joiner, J., Kerridge, B. J., Kim, J., Krotkov, N. A., Lamsal, L., Li, C., Lindfors, A., Martin, R. V., McElroy, C. T., McLinden, C., Natraj, V., Neil, D. O., Nowlan, C. R., O'Sullivan, E. J., Palmer, P. I., Pierce, R. B., Pippin, M. R., Saiz-Lopez, A., Spurr, R. J. D., Szykman, J. J., Torres, O., Veefkind, J. P., Veihelmann, B., Wang, H., Wang, J., and Chance, K.: Tropospheric emissions: Monitoring of pollution (TEMPO), J. Quant. Spectrosc. Radiat. Transfer, 186, 17–39, https://doi.org/10.1016/j.jqsrt.2016.05.008, 2017."
    },
    "jin2025": {
      "label": "Jin et al., 2025",
      "names": "Jin et al.",
      "year": "2025",
      "sort": "jin 2 2025 observing the diurnal variations of ozone-no_{x}-voc chemistry over the u.s. from the geostationary tempo instrument",
      "text": "Jin, X., Yang, Y., González Abad, G., Nowlan, C., and Liu, X.: Observing the diurnal variations of ozone-NO_{x}-VOC chemistry over the U.S. from the geostationary TEMPO instrument, Geophys. Res. Lett., 52, e2025GL116394, https://doi.org/10.1029/2025GL116394, 2025."
    },
    "schroeder2017": {
      "label": "Schroeder et al., 2017",
      "names": "Schroeder et al.",
      "year": "2017",
      "sort": "schroeder 2 2017 new insights into the column ch2o/no2 ratio as an indicator of near-surface ozone sensitivity",
      "text": "Schroeder, J. R., Crawford, J. H., Fried, A., Walega, J., Weinheimer, A., Wisthaler, A., Müller, M., Mikoviny, T., Chen, G., Shook, M., Blake, D. R., and Tonnesen, G. S.: New insights into the column CH2O/NO2 ratio as an indicator of near-surface ozone sensitivity, J. Geophys. Res. Atmos., 122, 8885–8907, https://doi.org/10.1002/2017JD026781, 2017."
    },
    "zhu2016": {
      "label": "Zhu et al., 2016",
      "names": "Zhu et al.",
      "year": "2016",
      "sort": "zhu 2 2016 observing atmospheric formaldehyde (hcho) from space: validation and intercomparison of six retrievals from four satellites (omi, gome2a, gome2b, omps) with seac4rs aircraft observations over the southeast us",
      "text": "Zhu, L., Jacob, D. J., Kim, P. S., Fisher, J. A., Yu, K., Travis, K. R., Mickley, L. J., Yantosca, R. M., Sulprizio, M. P., De Smedt, I., González Abad, G., Chance, K., Li, C., Ferrare, R., Fried, A., Hair, J. W., Hanisco, T. F., Richter, D., Scarino, A. J., Walega, J., Weibring, P., and Wolfe, G. M.: Observing atmospheric formaldehyde (HCHO) from space: validation and intercomparison of six retrievals from four satellites (OMI, GOME2A, GOME2B, OMPS) with SEAC4RS aircraft observations over the southeast US, Atmos. Chem. Phys., 16, 13477–13490, https://doi.org/10.5194/acp-16-13477-2016, 2016."
    },
    "zhu2020": {
      "label": "Zhu et al., 2020",
      "names": "Zhu et al.",
      "year": "2020",
      "sort": "zhu 2 2020 validation of satellite formaldehyde (hcho) retrievals using observations from 12 aircraft campaigns",
      "text": "Zhu, L., González Abad, G., Nowlan, C. R., Chan Miller, C., Chance, K., Apel, E. C., DiGangi, J. P., Fried, A., Hanisco, T. F., Hornbrook, R. S., Hu, L., Kaiser, J., Keutsch, F. N., Permar, W., St. Clair, J. M., and Wolfe, G. M.: Validation of satellite formaldehyde (HCHO) retrievals using observations from 12 aircraft campaigns, Atmos. Chem. Phys., 20, 12329–12345, https://doi.org/10.5194/acp-20-12329-2020, 2020."
    },
    "herman2009": {
      "label": "Herman et al., 2009",
      "names": "Herman et al.",
      "year": "2009",
      "sort": "herman 2 2009 no2 column amounts from ground-based pandora and mfdoas spectrometers using the direct-sun doas technique: intercomparisons and application to omi validation",
      "text": "Herman, J., Cede, A., Spinei, E., Mount, G., Tzortziou, M., and Abuhassan, N.: NO2 column amounts from ground-based Pandora and MFDOAS spectrometers using the direct-sun DOAS technique: intercomparisons and application to OMI validation, J. Geophys. Res., 114, D13307, https://doi.org/10.1029/2009JD011848, 2009."
    },
    "spinei2018": {
      "label": "Spinei et al., 2018",
      "names": "Spinei et al.",
      "year": "2018",
      "sort": "spinei 2 2018 the first evaluation of formaldehyde column observations by improved pandora spectrometers during the korus-aq field study",
      "text": "Spinei, E., Whitehill, A., Fried, A., Tiefengraber, M., Knepp, T. N., Herndon, S., Herman, J. R., Müller, M., Abuhassan, N., Cede, A., Richter, D., Walega, J., Crawford, J., Szykman, J., Valin, L., Williams, D. J., Long, R., Swap, R. J., Lee, Y., Nowak, N., and Poche, B.: The first evaluation of formaldehyde column observations by improved Pandora spectrometers during the KORUS-AQ field study, Atmos. Meas. Tech., 11, 4943–4961, https://doi.org/10.5194/amt-11-4943-2018, 2018."
    },
    "rawat2026": {
      "label": "Rawat et al., 2026",
      "names": "Rawat et al.",
      "year": "2026",
      "sort": "rawat 2 2026 spatiotemporal assessment of the tempo formaldehyde column retrieval using the pandonia global network",
      "text": "Rawat, P., Travis, K. R., Henderson, B., Crawford, J. H., Judd, L. M., Demetillo, M. A. G., Lee, T. C., Flittner, D. E., Szykman, J. J., Valin, L. C., Whitehill, A., Baumann, E., Hanisco, T. F., Pandey, A., González Abad, G., Nowlan, C. R., Liu, X., and Chance, K.: Spatiotemporal assessment of the TEMPO formaldehyde column retrieval using the Pandonia Global Network, J. Geophys. Res. Atmos., 131, e2025JD044788, https://doi.org/10.1029/2025JD044788, 2026."
    },
    "ortega2026": {
      "label": "Ortega et al., 2026",
      "names": "Ortega et al.",
      "year": "2026",
      "sort": "ortega 2 2026 evaluating tempo formaldehyde retrievals with co-located ground-based ftir and pandora observations",
      "text": "Ortega, I., Hannigan, J. W., Edwards, D., Stremme, W., Grutter, M., Cadena-Caicedo, A., Strong, K., Flood, V., Zhao, X., González Abad, G., and Nowlan, C. R.: Evaluating TEMPO formaldehyde retrievals with co-located ground-based FTIR and Pandora observations, J. Geophys. Res. Atmos., 131, e2026JD046497, https://doi.org/10.1029/2026JD046497, 2026."
    },
    "nasaval2026": {
      "label": "TEMPO Validation Team, 2025",
      "names": "TEMPO Validation Team",
      "year": "2025",
      "sort": "tempo validation team",
      "text": "TEMPO Validation Team and TEMPO Ad-hoc Validation Working Group: Validation and Quality Assessment of the TEMPO Level-2 Trace Gas Products, Baseline (Version 03), Smithsonian Astrophysical Observatory, https://asdc.larc.nasa.gov/documents/tempo/TEMPO_validation_report_baseline_draft.pdf (last access: 20 September 2026), 2025."
    },
    "wang2022": {
      "label": "Wang et al., 2022",
      "names": "Wang et al.",
      "year": "2022",
      "sort": "wang 2 2022 ambient formaldehyde over the united states from ground-based (aqs) and satellite (omi) observations",
      "text": "Wang, P., Holloway, T., Bindl, M., Harkey, M., and De Smedt, I.: Ambient formaldehyde over the United States from ground-based (AQS) and satellite (OMI) observations, Remote Sens., 14, 2191, https://doi.org/10.3390/rs14092191, 2022."
    },
    "acker2025": {
      "label": "Acker et al., 2025",
      "names": "Acker et al.",
      "year": "2025",
      "sort": "acker 2 2025 satellite detection of no_{2} distributions using tropomi and tempo and comparison with ground-based concentration measurements",
      "text": "Acker, S., Holloway, T., and Harkey, M.: Satellite detection of NO_{2} distributions using TROPOMI and TEMPO and comparison with ground-based concentration measurements, Atmos. Chem. Phys., 25, 8271–8288, https://doi.org/10.5194/acp-25-8271-2025, 2025."
    },
    "nawaz2025": {
      "label": "Nawaz et al., 2025",
      "names": "Nawaz et al.",
      "year": "2025",
      "sort": "nawaz 2 2025 a comparative analysis of tempo no_{2} remote sensing with surface-level monitoring through diurnal and seasonal trends, meteorology, and monitor characteristics",
      "text": "Nawaz, M. O., Huber, D. E., Kerr, G. H., Judd, L. M., Acker, S. J., and Goldberg, D. L.: A comparative analysis of TEMPO NO_{2} remote sensing with surface-level monitoring through diurnal and seasonal trends, meteorology, and monitor characteristics, J. Geophys. Res. Atmos., 130, e2025JD043923, https://doi.org/10.1029/2025JD043923, 2025."
    },
    "epaaqs2026": {
      "label": "U.S. EPA, 2026a",
      "names": "U.S. EPA",
      "year": "2026a",
      "sort": "u.s. epa 2026a",
      "text": "U.S. EPA (U.S. Environmental Protection Agency): Air Quality System (AQS) API and pre-generated data files, https://aqs.epa.gov/aqsweb/documents/data_api.html (last access: 20 September 2026), 2026a."
    },
    "epato11a1999": {
      "label": "U.S. EPA, 1999",
      "names": "U.S. EPA",
      "year": "1999",
      "sort": "u.s. epa 1999",
      "text": "U.S. EPA (U.S. Environmental Protection Agency): Compendium Method TO-11A: Determination of formaldehyde in ambient air using adsorbent cartridge followed by high performance liquid chromatography (HPLC), in: Compendium of Methods for the Determination of Toxic Organic Compounds in Ambient Air, 2nd edn., EPA/625/R-96/010b, U.S. EPA, Cincinnati, OH, USA, 1999."
    },
    "tempol3v4": {
      "label": "NASA ASDC, 2025",
      "names": "NASA ASDC",
      "year": "2025",
      "sort": "nasa asdc 2025",
      "text": "NASA ASDC (NASA Atmospheric Science Data Center): TEMPO gridded formaldehyde total column V04 (PROVISIONAL), NASA Langley Atmospheric Science Data Center DAAC [data set], https://doi.org/10.5067/IS-40e/TEMPO/HCHO_L3.004, 2025."
    },
    "nasaguide2025": {
      "label": "NASA ASDC, 2026",
      "names": "NASA ASDC",
      "year": "2026",
      "sort": "nasa asdc 2026",
      "text": "NASA ASDC (NASA Atmospheric Science Data Center): TEMPO Level 2/3 trace gas and cloud products user guide, version 2.1, https://asdc.larc.nasa.gov/documents/tempo/guide/TEMPO_Level-2-3_trace_gas_clouds_user_guide_V2.1.pdf (last access: 20 September 2026), 2026."
    },
    "steiger1980": {
      "label": "Steiger, 1980",
      "names": "Steiger",
      "year": "1980",
      "sort": "steiger 0 1980 tests for comparing elements of a correlation matrix",
      "text": "Steiger, J. H.: Tests for comparing elements of a correlation matrix, Psychol. Bull., 87, 245–251, https://doi.org/10.1037/0033-2909.87.2.245, 1980."
    },
    "dowell2022": {
      "label": "Dowell et al., 2022",
      "names": "Dowell et al.",
      "year": "2022",
      "sort": "dowell 2 2022 the high-resolution rapid refresh (hrrr): an hourly updating convection-allowing forecast model. part i: motivation and system description",
      "text": "Dowell, D. C., Alexander, C. R., James, E. P., Weygandt, S. S., Benjamin, S. G., Manikin, G. S., Blake, B. T., Brown, J. M., Olson, J. B., Hu, M., Smirnova, T. G., Ladwig, T., Kenyon, J. S., Ahmadov, R., Turner, D. D., Duda, J. D., and Alcott, T. I.: The High-Resolution Rapid Refresh (HRRR): An Hourly Updating Convection-Allowing Forecast Model. Part I: Motivation and System Description, Weather Forecast., 37, 1371–1395, https://doi.org/10.1175/WAF-D-21-0151.1, 2022."
    },
    "rcore2024": {
      "label": "R Core Team, 2024",
      "names": "R Core Team",
      "year": "2024",
      "sort": "r core team",
      "text": "R Core Team: R: A language and environment for statistical computing, R Foundation for Statistical Computing, Vienna, Austria, https://www.R-project.org/ (last access: 20 September 2026), 2024."
    },
    "goldberg2025": {
      "label": "Goldberg et al., 2025",
      "names": "Goldberg et al.",
      "year": "2025",
      "sort": "goldberg 2 2025 clear-sky and cloudy-sky differences in no_{2} concentrations over the united states: implications for satellite measurement applications",
      "text": "Goldberg, D. L., Nawaz, M. O., Lyu, C., He, J., Carlton, A. G., Kondragunta, S., and Anenberg, S. C.: Clear-sky and cloudy-sky differences in NO_{2} concentrations over the United States: implications for satellite measurement applications, Atmos. Chem. Phys., 25, 16287–16302, https://doi.org/10.5194/acp-25-16287-2025, 2025."
    },
    "rolph2009": {
      "label": "Rolph et al., 2009",
      "names": "Rolph et al.",
      "year": "2009",
      "sort": "rolph 2 2009 description and verification of the noaa smoke forecasting system: the 2007 fire season",
      "text": "Rolph, G. D., Draxler, R. R., Stein, A. F., Taylor, A., Ruminski, M. G., Kondragunta, S., Zeng, J., Huang, H.-C., Manikin, G., McQueen, J. T., and Davidson, P. M.: Description and verification of the NOAA Smoke Forecasting System: the 2007 fire season, Weather Forecast., 24, 361–378, https://doi.org/10.1175/2008WAF2222165.1, 2009."
    },
    "brey2018": {
      "label": "Brey et al., 2018",
      "names": "Brey et al.",
      "year": "2018",
      "sort": "brey 2 2018 connecting smoke plumes to sources using hazard mapping system (hms) smoke and fire location data over north america",
      "text": "Brey, S. J., Ruminski, M., Atwood, S. A., and Fischer, E. V.: Connecting smoke plumes to sources using Hazard Mapping System (HMS) smoke and fire location data over North America, Atmos. Chem. Phys., 18, 1745–1761, https://doi.org/10.5194/acp-18-1745-2018, 2018."
    },
    "degraaf2016": {
      "label": "de Graaf et al., 2016",
      "names": "de Graaf et al.",
      "year": "2016",
      "sort": "de graaf 2 2016 how big is an omi pixel?",
      "text": "de Graaf, M., Sihler, H., Tilstra, L. G., and Stammes, P.: How big is an OMI pixel?, Atmos. Meas. Tech., 9, 3607–3618, https://doi.org/10.5194/amt-9-3607-2016, 2016."
    },
    "souri2026": {
      "label": "Souri et al., 2026",
      "names": "Souri et al.",
      "year": "2026",
      "sort": "souri 2 2026 tempo exposes systematic deficiencies in simulating daylight formaldehyde variability during the 2024 growing season: a classification-based evaluation of wrf-cmaq",
      "text": "Souri, A. H., Strode, S. A., Liu, J., González Abad, G., and Duncan, B. N.: TEMPO exposes systematic deficiencies in simulating daylight formaldehyde variability during the 2024 growing season: a classification-based evaluation of WRF-CMAQ, J. Geophys. Res. Atmos., 131, e2026JD047766, https://doi.org/10.1029/2026JD047766, 2026."
    },
    "arnts1989": {
      "label": "Arnts and Tejada, 1989",
      "names": "Arnts and Tejada",
      "year": "1989",
      "sort": "arnts 1 1989 2,4-dinitrophenylhydrazine-coated silica gel cartridge method for determination of formaldehyde in air: identification of an ozone interference",
      "text": "Arnts, R. R. and Tejada, S. B.: 2,4-Dinitrophenylhydrazine-coated silica gel cartridge method for determination of formaldehyde in air: identification of an ozone interference, Environ. Sci. Technol., 23, 1428–1430, https://doi.org/10.1021/es00069a018, 1989."
    },
    "jeong2026": {
      "label": "Jeong et al., 2026",
      "names": "Jeong et al.",
      "year": "2026",
      "sort": "jeong 2 2026 trace organic gas analyzer time-of-flight mass spectrometer (toga-tof) system for airborne observations of formaldehyde",
      "text": "Jeong, D., Hornbrook, R. S., Hills, A. J., Diskin, G., Halliday, H. S., DiGangi, J. P., Fried, A., Richter, D., Walega, J., Weibring, P., Hanisco, T. F., Wolfe, G. M., St. Clair, J., Peischl, J., Wisthaler, A., Mikoviny, T., Nowak, J. B., Piel, F., Tomsche, L., Holmes, C. D., Soja, A., Gargulinski, E., Crawford, J. H., Dibb, J., Warneke, C., Schwarz, J., and Apel, E. C.: Trace Organic Gas Analyzer Time-of-Flight mass spectrometer (TOGA-TOF) system for airborne observations of formaldehyde, Atmos. Meas. Tech., 19, 2985–3000, https://doi.org/10.5194/amt-19-2985-2026, 2026."
    },
    "cdpherepo2026": {
      "label": "CDPHE, 2026a",
      "names": "CDPHE",
      "year": "2026a",
      "sort": "cdphe 2026a",
      "text": "CDPHE (Colorado Department of Public Health and Environment): Air Toxics and Ozone Precursor Data Repository, https://www.colorado.gov/airquality/air_toxics_repo.aspx (last access: 20 September 2026), 2026a."
    },
    "cdphetac2026": {
      "label": "CDPHE, 2026b",
      "names": "CDPHE",
      "year": "2026b",
      "sort": "cdphe 2026b",
      "text": "CDPHE (Colorado Department of Public Health and Environment): Priority toxic air contaminants, https://cdphe.colorado.gov/air-toxics/priority-toxic-air-contaminants (last access: 20 September 2026), 2026b."
    },
    "epanatts2025": {
      "label": "U.S. EPA, 2026b",
      "names": "U.S. EPA",
      "year": "2026b",
      "sort": "u.s. epa 2026b",
      "text": "U.S. EPA (U.S. Environmental Protection Agency): Air Toxics Ambient Monitoring, Ambient Monitoring Technology Information Center, https://www.epa.gov/amtic/air-toxics-ambient-monitoring (last access: 20 September 2026), 2026b."
    },
    "noaahms2026": {
      "label": "NOAA OSPO, 2026",
      "names": "NOAA OSPO",
      "year": "2026",
      "sort": "noaa ospo",
      "text": "NOAA OSPO (NOAA Office of Satellite and Product Operations): Hazard Mapping System smoke polygons, https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/Shapefile/ (last access: 20 September 2026), 2026."
    },
    "pebesma2018": {
      "label": "Pebesma, 2018",
      "names": "Pebesma",
      "year": "2018",
      "sort": "pebesma 0 2018 simple features for r: standardized support for spatial vector data",
      "text": "Pebesma, E.: Simple features for R: standardized support for spatial vector data, R J., 10, 439–446, https://doi.org/10.32614/RJ-2018-009, 2018."
    },
    "bates2015": {
      "label": "Bates et al., 2015",
      "names": "Bates et al.",
      "year": "2015",
      "sort": "bates 2 2015 fitting linear mixed-effects models using lme4",
      "text": "Bates, D., Mächler, M., Bolker, B., and Walker, S.: Fitting linear mixed-effects models using lme4, J. Stat. Softw., 67, 1–48, https://doi.org/10.18637/jss.v067.i01, 2015."
    },
    "aws": {
      "label": "Amazon Web Services, 2026",
      "names": "Amazon Web Services",
      "year": "2026",
      "sort": "amazon web services",
      "text": "Amazon Web Services: Terrain Tiles, Registry of Open Data on AWS, https://registry.opendata.aws/terrain-tiles/ (last access: 20 September 2026), 2026."
    },
    "hollister2023": {
      "label": "Hollister et al., 2023",
      "names": "Hollister et al.",
      "year": "2023",
      "sort": "hollister 2023",
      "text": "Hollister, J. W., Shah, T., Nowosad, J., Robitaille, A. L., Beck, M. W., and Johnson, M.: elevatr: Access Elevation Data from Various APIs, R package version 0.99.0, Zenodo [code], https://doi.org/10.5281/zenodo.8335450, 2023."
    },
    "census2023": {
      "label": "U.S. Census Bureau, 2023",
      "names": "U.S. Census Bureau",
      "year": "2023",
      "sort": "u.s. census bureau",
      "text": "U.S. Census Bureau: Cartographic boundary files, https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html (last access: 20 September 2026), 2023."
    }
  }
};
