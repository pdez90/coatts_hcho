// mkcontent13.js - content_v12.js -> content_v13.js
// Adds the clear-sky representativeness result (R/15_clear_sky_bias.R) as a new
// Sect. 4.11 and Figure 13, with the Goldberg et al. (2025) contrast; fixes the
// Figure 1 caption; and adds citations for the map's data sources.
const fs = require("fs");
const C = require("./content_v12.js");
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

// ---------------------------------------------------------------- 1. Fig. 1 caption
{
  const i = S.findIndex(s => s.fig && s.fig.file === "fig0_site_map.png");
  if (i < 0) throw new Error("site map figure not found");
  S[i].fig.caption = S[i].fig.caption
    .replace("sampling 24 h integrated carbonyls (circles) and two COOPs sites sampling 3 h (triangles)",
             "sampling 24 h integrated formaldehyde (circles) and two COOPs sites sampling 3 h integrated formaldehyde (triangles)");
  if (/integrated carbonyls/.test(S[i].fig.caption)) throw new Error("Fig. 1 caption not updated");
}

// ---------------------------------------------------------------- 2. new Sect. 4.11
const newSec = [
{
  h2: "4.11 Are the days TEMPO can see representative?",
  p: [
"Cloud screening removes about a quarter of sample days, and the question of whether agreement survives a stricter cloud threshold (Sect. 4.4) is not the same as whether the days that survive screening are like the days that do not. We therefore compared surface HCHO on days with and without a usable TEMPO observation. Days divide three ways: usable, screened out (TEMPO observed but no scan passed), and no scan at all. In Colorado 338 of 453 sample days were usable (74.6 %), 100 were screened out (22.1 %) and 15 had no granule (3.3 %); nationally the 8730 24 h samples divide 6106 (69.9 %), 2253 (25.8 %) and 371 (4.2 %). Cloud is what separates the first two: the median effective cloud fraction over the Colorado sites was 0.12 on usable days and 0.57 on screened-out days. The comparison below uses only those two categories, so that gaps in TEMPO's own sampling do not enter it.",
"The days TEMPO cannot see carry systematically less surface HCHO. In a regression with fixed effects for site and calendar month, a day with a usable observation has 0.52 ± 0.04 µg m^{-3} more surface HCHO than a screened-out day at the same site in the same month (n = 8359 at 102 sites, p < 10^{-30}), which is 25 % of the national median. The Colorado case study gives the same sign and a smaller magnitude, 0.39 ± 0.09 µg m^{-3} or 15 % (n = 438, p < 10^{-4}). Taking deviations within each site-month instead, and pairing at the site-month level, gives −0.51 µg m^{-3} nationally over 955 site-months (p < 10^{-37}) and −0.36 µg m^{-3} in Colorado over 49 site-months (p < 10^{-3}) (Fig. 13).",
"The effect follows the seasonal cycle of photochemistry. Nationally the paired difference is −0.16 µg m^{-3} in winter (−8 %, p = 0.02), −0.47 in spring (−22 %), −1.00 in summer (−32 %) and −0.63 in autumn (−23 %, all p < 10^{-11}). It is largest when and where photochemical production of HCHO is strongest, and small in winter when there is little production for cloud to suppress. Colorado's seasonal pattern is noisier on far fewer site-months (spring −0.95, p < 10^{-4}; winter −0.22, p = 0.04; autumn −0.14, p = 0.46; summer has only one qualifying site-month).",
"The direction is the opposite of the corresponding result for nitrogen dioxide. Goldberg et al. (2025) find surface NO_{2} to be 36 % higher on cloudy than on clear days across the AQS network, at 87 % of monitors, and attribute it to the slower photochemistry that removes NO_{2}. For HCHO, whose atmospheric source rather than sink is photochemical, the same meteorology works in reverse. The practical consequence is that TEMPO's usable days are not a random sample of air toxics sampling days: they are biased towards the higher-HCHO end of the distribution at the same site and time of year."
  ]
},
{ fig: { file: "fig14_clear_sky_bias.png", w: 2100, h: 1260,
  caption: "Figure 13. Surface HCHO on days with and without a usable TEMPO observation, as deviations from the site and calendar-month mean, for site-months containing at least one day of each kind. Days on which TEMPO returned no granule at all are excluded, so the contrast is between clear and cloud-screened days. Diamonds are means; axes are truncated at the 1st and 99th percentiles." } }
];
S.splice(byHead("5 Discussion"), 0, ...newSec);

// cross-reference from the coverage section
sub("4.1 Availability of TEMPO observations",
"Figure S1 shows coverage by site and month.",
"Figure S1 shows coverage by site and month. Whether the days that pass screening are representative of all sample days is taken up in Sect. 4.11.");

// ---------------------------------------------------------------- 3. Discussion 5.1
sub("5.1 What TEMPO captures at air toxics monitors",
"That availability primarily reflects the repeated sampling the geostationary orbit allows, rather than any property of the retrieval itself: at a Pandonia site in New Jersey, hourly sampling yields a usable observation on about 50 % more days than the early-afternoon overpass alone would (Rawat et al., 2026). Whether a given scan is usable still depends on cloud, solar zenith angle, retrieval success and the screening applied.",
"That availability primarily reflects the repeated sampling the geostationary orbit allows, rather than any property of the retrieval itself: at a Pandonia site in New Jersey, hourly sampling yields a usable observation on about 50 % more days than the early-afternoon overpass alone would (Rawat et al., 2026), and modelled cloud fields over the contiguous United States imply that 68–93 % of days contain a clear-sky opportunity at some daylight hour against 33–69 % at a fixed early-afternoon overpass (Goldberg et al., 2025). Whether a given scan is usable still depends on cloud, solar zenith angle, retrieval success and the screening applied.");

sub("5.1 What TEMPO captures at air toxics monitors",
"The national distribution gives one clue: agreement is weakest at the lowest-concentration sites (Sect. 4.9), which is what a fixed retrieval noise predicts.",
"The national distribution gives one clue: agreement is weakest at the lowest-concentration sites (Sect. 4.9), which is what a fixed retrieval noise predicts. Cloud climatology is a second candidate we have not pursued: which days a monitor loses to screening varies regionally (Goldberg et al., 2025), and a site whose cloudy days differ most from its clear ones loses the widest range of conditions, which can only affect the correlation that remains.");

// availability is not the same as representativeness
sub("5.1 What TEMPO captures at air toxics monitors",
"This is the central practical result.",
"This is the central practical result. Availability is also not the same as representativeness: the days TEMPO can see carry about 25 % more surface HCHO than the days it cannot, at the same site and time of year (Sect. 4.11), so a climatology built from clear-sky observations alone would sit above the concentration a monitor actually records.");

// ---------------------------------------------------------------- 4. Discussion 5.2
sub("5.2 Noise and spatial averaging",
"The cloud fraction threshold mattered much less than block size, particularly for all-day means, suggesting that residual cloud contamination is not the dominant error source for daily means, although stricter screening helped when fewer (midday) scans were averaged.",
"The cloud fraction threshold mattered much less than block size, particularly for all-day means, suggesting that residual cloud contamination is not the dominant error source for daily means, although stricter screening helped when fewer (midday) scans were averaged. That statement is about agreement among the scans TEMPO returns, and should not be read more widely: it says nothing about the days screening removes, which differ systematically from those it keeps (Sect. 4.11).");

sub("5.2 Noise and spatial averaging",
"Near strong local sources, however, larger blocks dilute local enhancements, so the appropriate averaging scale depends on whether the application targets regional or near-source concentrations.",
"Near strong local sources, however, larger blocks dilute local enhancements, so the appropriate averaging scale depends on whether the application targets regional or near-source concentrations. The same tension appears in satellite comparisons for other species: Goldberg et al. (2025) exclude near-road NO_{2} monitors from their primary analysis on the grounds that a monitor sited metres from a roadway cannot represent a satellite pixel. Air toxics monitors are not sited to that brief, so we have not excluded any, but monitor siting is one of the candidate explanations for the site-to-site spread in Sect. 4.9.");

// ---------------------------------------------------------------- 5. Discussion 5.5
sub("5.5 Wildfire smoke",
"Classifications of short sampling periods using HMS should account for this.",
"Classifications of short sampling periods using HMS should account for this. Fire-related enhancements can also remain aloft and be seen in the column without a proportionate surface signal (Goldberg et al., 2025), which is a further reason to read the HMS analysis as episode classification rather than vertical or source attribution; that both surface and column HCHO rose together on smoke days is what makes the comparison informative here.");

// ---------------------------------------------------------------- 6. limitations
sub("5.7 Implications for air toxics monitoring and limitations",
"A programme considering satellite data as a supplement can estimate what to expect at its own sites from the site-level results reported here (Fig. 10) rather than from a network average.",
"A programme considering satellite data as a supplement can estimate what to expect at its own sites from the site-level results reported here (Fig. 10) rather than from a network average, and should treat the clear-sky subset as an upwardly biased sample of days rather than a representative one (Sect. 4.11): combining satellite observations with the monitor's own record on cloudy days is necessary if the target is a long-term mean rather than a clear-day one.");

// ---------------------------------------------------------------- 7. abstract and conclusions
C.abstract[1] = C.abstract[1].replace(
"There is useful day-to-day information at most routine monitors and none at some, and no single satellite-to-surface relationship that can safely be assumed at a site that has not been checked.",
"There is useful day-to-day information at most routine monitors and none at some, and no single satellite-to-surface relationship that can safely be assumed at a site that has not been checked. Availability is not the same as representativeness: at the same site and time of year, days with a usable observation carry 0.52 ± 0.04 µg m^{-3} more surface HCHO than days cloud screening removes, about 25 % of the median, so the clear-sky subset is biased towards higher concentrations — the opposite sign to the corresponding result for nitrogen dioxide, whose photochemical sink rather than source is suppressed by cloud.");
if (!/Availability is not the same as representativeness/.test(C.abstract[1])) throw new Error("abstract not updated");

sub("6 Conclusions",
"Agreement was weakest where concentrations were lowest and improved with spatial averaging everywhere.",
"The days TEMPO can see are also not a representative sample of sampling days: at the same site and time of year they carry about 25 % more surface HCHO than the days cloud screening removes, with the difference largest in summer, when photochemical production of HCHO is strongest. Agreement was weakest where concentrations were lowest and improved with spatial averaging everywhere.");

// ---------------------------------------------------------------- 8. references and availability
C.references.push(
"Goldberg, D. L., Nawaz, M. O., Lyu, C., He, J., Carlton, A. G., Kondragunta, S., and Anenberg, S. C.: NO_{2} concentration differences under clear versus cloudy skies and implications for applications of satellite measurements, EGUsphere [preprint], https://doi.org/10.5194/egusphere-2025-1350, 2025. [[check whether the peer-reviewed version has appeared before submission]]",
"Amazon Web Services: Terrain Tiles, Registry of Open Data on AWS, https://registry.opendata.aws/terrain-tiles/, last access: 14 September 2026.",
"Hollister, J. W.: elevatr: access elevation data from various APIs, R package version 0.99.0, https://CRAN.R-project.org/package=elevatr, 2025. [[confirm the version used and whether a Zenodo DOI should be cited instead]]",
"U.S. Census Bureau: Cartographic boundary files, U.S. Census Bureau [data set], https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html, last access: 14 September 2026, 2023."
);
C.references.sort((a, b) => a.localeCompare(b, "en"));

sub("Data availability",
"NOAA HMS smoke polygons are available from https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/Shapefile/.",
"NOAA HMS smoke polygons are available from https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/Shapefile/. The terrain in Fig. 1 comes from the AWS Terrain Tiles on the Registry of Open Data on AWS, retrieved with the elevatr R package (Hollister, 2025), and the state and county boundaries are US Census cartographic boundary files (U.S. Census Bureau, 2023); both are downloaded and cached by the analysis code.");

// ---------------------------------------------------------------- 9. notes
C.notes[1] = "Changes from v12: a new Sect. 4.11 and Fig. 13 report whether the days TEMPO can see are representative of all sample days, prompted by Goldberg et al. (2025), who found the corresponding effect for NO_{2}. They are not: with fixed effects for site and calendar month, a day with a usable observation carries 0.52 +/- 0.04 ug/m3 more surface HCHO nationally (+25 %) and 0.39 +/- 0.09 in Colorado (+15 %), the difference is largest in summer, and the sign is the opposite of the NO_{2} result because HCHO's photochemical link is through its source rather than its sink. The result is computed by R/15_clear_sky_bias.R. Sect. 5.2's cloud-threshold statement is explicitly narrowed to agreement among returned scans; Sect. 5.1 adds Goldberg's clear-sky day fractions beside Rawat's coverage gain and names regional cloud climatology as a further candidate for site heterogeneity; Sect. 5.5 adds the plumes-aloft caveat; Sect. 5.7 adds the practical implication. The Fig. 1 caption now says \"integrated formaldehyde\" rather than \"carbonyls\", and the map's data sources (AWS Terrain Tiles, elevatr, US Census cartographic boundaries) are cited and listed under Data availability.";

const out = "// content_v13.js - generated by mkcontent13.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync("content_v13.js", out);
console.log("wrote content_v13.js:", out.length, "chars; refs:", C.references.length);
