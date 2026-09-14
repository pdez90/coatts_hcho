// mkcontent14.js - content_v13.js -> content_v14.js
// Review response on the observability result:
//  1. recast as observability/screening selection, with the screening attribution
//     that justifies it (cloud alone explains only about half the rejections)
//  2. causal mechanism removed; the covariates of cloudiness are named instead
//  3. the analysis specified in Methods (new Sect. 3.8)
//  4. site-clustered inference reported
//  5. sign and denominator stated for every contrast
//  6. Figure 13 relabelled and its file renamed
//  7. abstract cut from 717 to ~400 words around four findings
const fs = require("fs");
const C = require("./content_v13.js");
const S = C.sections;

const byHead = (t) => {
  const i = S.findIndex(s => (s.h1 || s.h2 || "") === t);
  if (i < 0) throw new Error("no section: " + t);
  return i;
};
function sub(head, from, to) {
  const s = S[byHead(head)];
  let hit = 0;
  s.p = s.p.map(t => { if (t.includes(from)) { hit++; return t.replace(from, to); } return t; });
  if (!hit) throw new Error("not found in " + head + ": " + from.slice(0, 70));
}
const setP = (head, ps) => { S[byHead(head)].p = ps; };

// ============================================================ 7. abstract, ~400 words
C.abstract = [
"Formaldehyde (HCHO) is a carcinogenic hazardous air pollutant and a leading contributor to estimated cancer risk from outdoor air toxics in the United States. The geostationary Tropospheric Emissions: Monitoring of Pollution (TEMPO) instrument retrieves HCHO columns hourly over North America, but evaluations of these retrievals have relied on column measurements, and comparisons with routine surface monitoring have been limited to seasonal means from polar-orbiting instruments. We compare TEMPO Level 3 version 4 HCHO columns with all valid integrated formaldehyde samples reported to the United States Air Quality System in 2024–2025 — 16 383 samples at 123 sites in 37 states, sampling over 24, 8 and 3 h — with Colorado's air toxics network as a case study.",
"A screened observation was available for 70 % of 24 h samples. The pooled correlation with 24 h surface HCHO was 0.42 (n = 6106), and 0.40 after removing site and calendar-month means. How unevenly that skill is distributed is the central result: at individual monitors the day-to-day correlation had a median of 0.48, an interquartile range of 0.27–0.59 and a range from −0.24 to 0.89. There is useful day-to-day information at most routine monitors and none at some, and no single satellite-to-surface relationship can safely be assumed at a monitor that has not been checked.",
"Availability is not the same as representativeness. Holding monitor and calendar month fixed, days with a usable observation carried 0.52 µg m^{-3} more surface HCHO than days on which TEMPO observed but no scan passed screening (95 % confidence interval 0.43–0.61, clustered by monitor; 25 % of the median), so the observable subset is weighted towards higher concentrations. Agreement improved with spatial averaging; in Colorado, successive-scan differences bound the random retrieval noise at about half the day-to-day variance of a 3 × 3 daily column, and correcting for it leaves the correlation unchanged across block sizes, so averaging appears to help mainly by reducing noise.",
"For sub-daily samples the hour of collection materially affected agreement, among samples of the same duration. At two California sites sampling five 3 h windows a day, day-to-day agreement was as strong in the 05:00–08:00 window (r = 0.44) as at midday (0.41) and absent in the late afternoon (0.17); at Colorado's two 3 h sites, sampling only 06:00–09:00 MST, it was absent during the sampling window (0.11) and strongest three hours after it (0.40). Across 40 sites sampling 8 h blocks the midday block outperformed the morning block (0.42 against 0.34). There is therefore no universal lag between sampling and the best-matching satellite window. TEMPO captures the seasonal cycle and regional episodes seen by air toxics monitors nationwide; its day-to-day skill at an individual monitor is moderate, strongly site dependent, and drawn from a non-representative subset of days."
];

C.shortSummary =
"Satellites now measure formaldehyde, a cancer-causing air pollutant, every daylight hour over North America. We compared these measurements with every routine surface sample collected across the United States in 2024-2025, at 123 sites. The satellite tracked day-to-day changes at most monitors but at some not at all; how well depended on where the monitor was and what time of day the sample was collected, and the days the satellite can observe carry more formaldehyde than the days it cannot.";

// ============================================================ 3. Methods
S.splice(byHead("4 Results"), 0, {
  h2: "3.8 Observability of sample days",
  p: [
"A sample day is observable when at least one TEMPO scan passes the screening of Sect. 3.1; it is screened out when TEMPO returned granules covering the site but no scan passed; and it has no granule when TEMPO returned none. Screening removes days for several reasons — effective cloud fraction, the main data quality flag, solar zenith angle and snow or ice cover — so to establish what drives the rejections we re-evaluate every screened-out site-day with one criterion relaxed at a time, and record which single relaxation would have made the day observable. This analysis uses the 24 h samples of both arms; days with no granule are excluded from the comparisons below, so that gaps in TEMPO's own sampling are not counted as screening.",
"Two estimates of the difference in surface HCHO between observable and screened-out days are reported, both signed as observable minus screened out, so that a positive value means more surface HCHO on days TEMPO can use. The first is the coefficient β in HCHO_{it} = α_{i} + γ_{m} + β·observable_{it} + ε_{it}, with α_{i} a fixed effect for monitor i and γ_{m} a fixed effect for calendar month m (January to December, pooled across years); screened-out days are the reference category. Because repeated observations at a monitor are not independent, standard errors are cluster-robust by monitor (CR1). The second takes deviations from the mean of each site-month, restricted to site-months containing at least three samples and at least one day of each kind, averages those deviations within each site-month to a single paired difference, and averages across site-months; its confidence interval comes from a bootstrap that resamples monitors, with 2000 replicates. Because a bootstrap over few clusters is degenerate rather than merely wide, no interval is reported for a stratum with fewer than five monitors. Percentages accompanying either estimate are relative to the median surface HCHO of the days entering that comparison."
  ]
});

// ============================================================ 1, 2, 4, 5. Sect. 4.11
S[byHead("4.11 Are the days TEMPO can see representative?")].h2 =
  "4.11 Are the days TEMPO can observe representative?";
setP("4.11 Are the days TEMPO can observe representative?", [
"Whether agreement survives a stricter cloud threshold (Sect. 4.4) is a different question from whether the days that survive screening resemble the days that do not. Sample days divide three ways (Sect. 3.8): in Colorado 338 of 453 were observable (74.6 %), 100 were screened out (22.1 %) and 15 had no granule (3.3 %); nationally the 8730 24 h samples divide 6106 (69.9 %), 2253 (25.8 %) and 371 (4.2 %).",
"Screening is not a cloud filter alone. Relaxing one criterion at a time across the screened-out site-days, the effective cloud fraction threshold on its own accounts for about half of the rejections — 118 of 218 in Colorado (54 %) and 2375 of 4631 nationally (51 %). Snow or ice cover would rescue a further 53 and 518, the solar zenith angle limit 12 and 701, and the quality flag 1 and 25, while 47 and 1285 are rescued by no single relaxation because they fail on more than one ground. The contrast below is therefore between days TEMPO can and cannot supply a screened observation for — an observability contrast — and not a comparison of clear with cloudy days.",
"Observable days carry more surface HCHO. With fixed effects for monitor and calendar month, a day with a usable observation has 0.52 µg m^{-3} more surface HCHO than a screened-out day at the same monitor in the same month (95 % confidence interval 0.43 to 0.61 with standard errors clustered by monitor; n = 8359 at 102 monitors), which is 25 % of the national median of the days compared. The Colorado case study gives the same sign and a smaller magnitude, 0.39 µg m^{-3} (0.17 to 0.60; 15 % of its median; n = 438 at 7 monitors, p = 0.012). Clustering matters for Colorado: with only seven monitors the cluster-robust standard error is 0.109 against 0.093 under independence. Taking deviations within each site-month instead, and bootstrapping over monitors, gives 0.51 µg m^{-3} nationally (0.42 to 0.61; 955 site-months at 100 monitors) and 0.36 µg m^{-3} in Colorado (0.14 to 0.49; 49 site-months) (Fig. 13).",
"The difference grows through the warm season. Nationally the paired difference is 0.16 µg m^{-3} in winter (10 % of the seasonal median; 0.01 to 0.30), 0.47 in spring (26 %; 0.33 to 0.60), 1.00 in summer (34 %; 0.82 to 1.18) and 0.63 in autumn (30 %; 0.46 to 0.80). The Colorado seasonal strata rest on too few monitors to carry intervals of their own and are not interpreted here.",
"The direction is the opposite of the corresponding result for nitrogen dioxide. Goldberg et al. (2025) found surface NO_{2} to be higher on cloudy than on clear days at most AQS monitors and interpreted this partly in terms of slower photochemical loss. For HCHO, the higher concentrations on observable days are consistent with greater net production under sunnier and generally warmer conditions, particularly in summer. Cloudiness also covaries with temperature, biogenic emissions, transport and boundary layer structure, however, and screening removes days for reasons unrelated to cloud at all, so this comparison identifies an observability-related selection effect rather than the process responsible for it."
]);

// figure: new file, neutral labels
{
  const i = S.findIndex(s => s.fig && s.fig.file === "fig14_clear_sky_bias.png");
  if (i < 0) throw new Error("observability figure not found");
  S[i].fig = { file: "fig14_observability_bias.png", w: 2100, h: 1320,
    caption: "Figure 13. Surface HCHO on days with a usable TEMPO observation and on days for which TEMPO returned granules but no scan passed the full screening criteria, as deviations from the site and calendar-month mean, for site-months containing at least one day of each kind. Days for which TEMPO returned no granule are excluded. Diamonds are means; the adjusted paired difference and its site-cluster bootstrap interval are given above each panel; axes are truncated near the 1st and 99th percentiles." };
}

sub("4.1 Availability of TEMPO observations",
"Whether the days that pass screening are representative of all sample days is taken up in Sect. 4.11.",
"Whether the days that pass screening are representative of all sample days is taken up in Sect. 4.11.");

// ============================================================ narrowed Discussion claims
sub("5.1 What TEMPO captures at air toxics monitors",
"Availability is also not the same as representativeness: the days TEMPO can see carry about 25 % more surface HCHO than the days it cannot, at the same site and time of year (Sect. 4.11), so a climatology built from clear-sky observations alone would sit above the concentration a monitor actually records.",
"Availability is also not the same as representativeness: days TEMPO can observe carry about 25 % more surface HCHO than days it cannot, at the same monitor and time of year (Sect. 4.11). A surface-HCHO mean calculated only for TEMPO-observable days would therefore exceed the corresponding mean across all monitoring days.");

sub("5.1 What TEMPO captures at air toxics monitors",
"and a site whose cloudy days differ most from its clear ones loses the widest range of conditions, which can only affect the correlation that remains.",
"and a monitor whose unobservable days differ most from its observable ones loses a systematically different set of conditions, which may affect both the variance retained and the resulting correlation.");

sub("5.2 Noise and spatial averaging",
"That statement is about agreement among the scans TEMPO returns, and should not be read more widely: it says nothing about the days screening removes, which differ systematically from those it keeps (Sect. 4.11).",
"That statement is about agreement among the scans TEMPO returns, and should not be read more widely: it says nothing about the days screening removes, which differ systematically from those it keeps (Sect. 4.11).");

sub("5.7 Implications for air toxics monitoring and limitations",
"and should treat the clear-sky subset as an upwardly biased sample of days rather than a representative one (Sect. 4.11): combining satellite observations with the monitor's own record on cloudy days is necessary if the target is a long-term mean rather than a clear-day one.",
"and should recognise that the TEMPO-observable subset is weighted towards higher-HCHO sampling days (Sect. 4.11): combining satellite observations with the monitor's own record on unobservable days is necessary if the target is a long-term mean rather than one conditioned on observability.");

// Conclusions
sub("6 Conclusions",
"The days TEMPO can see are also not a representative sample of sampling days: at the same site and time of year they carry about 25 % more surface HCHO than the days cloud screening removes, with the difference largest in summer, when photochemical production of HCHO is strongest.",
"The days TEMPO can observe are also not a representative sample of sampling days: at the same monitor and time of year they carry about 25 % more surface HCHO than the days screening removes, with the difference largest in summer. Screening rejects days for several reasons and the cloud threshold alone accounts for only about half of them, so this is a selection effect tied to observability rather than a measured consequence of cloud.");

// ============================================================ notes
C.notes[1] = "Changes from v13, all in response to review of the new section. The result is recast as OBSERVABILITY rather than clear sky: relaxing one screening criterion at a time shows the cloud threshold alone accounts for only 54 % of screened-out site-days in Colorado and 51 % nationally, with snow/ice, solar zenith angle and multi-criterion failures making up the rest, so \"clear\" and \"cloudy\" are gone from Sect. 4.11, Fig. 13 and the abstract. The causal claim that cloud suppresses HCHO production and reverses the NO_{2} mechanism is removed; the covariates of cloudiness are named instead and the comparison is described as a selection effect, not a process. A new Sect. 3.8 specifies the classification, the estimand, the reference category, the site-month construction and the tests. Inference is now cluster-robust by monitor (CR1) for the regression and a 2000-replicate monitor bootstrap for the paired difference - which matters for Colorado, where p moves from 5e-5 to 0.012 on seven monitors; no bootstrap interval is reported below five monitors, so the Colorado seasonal strata are no longer interpreted. Every contrast is signed observable minus screened out with the denominator stated. Fig. 13 is relabelled \"TEMPO usable\" and \"screened out\" and now prints the adjusted difference and interval; its file is fig14_observability_bias.png. The abstract is cut from 717 to about 400 words around four findings, with the H_{eff}, smoke and packets-versus-AQS detail left to the body.";

const out = "// content_v14.js - generated by mkcontent14.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync("content_v14.js", out);
console.log("wrote content_v14.js:", out.length, "chars; abstract words:",
  C.abstract.join(" ").split(/\s+/).length);
