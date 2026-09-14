// mkcontent9.js - content_v8.js -> content_v9.js
// Incorporates the papers supplied on 14 Sep 2026. Resolves both retrieval-bias
// placeholders in Sect. 5.3 with the real numbers, and adds three things the
// papers supply that the draft did not have:
//   - Rawat's column-dependent bias, and Boulder as his most biased site
//   - Rawat's finding that TEMPO reproduces the Pandora seasonal amplitude
//     (so our larger column amplitude is not a retrieval artefact)
//   - Nawaz's competing explanation for the morning breakdown in NO2
const fs = require("fs");
const C = require("./content_v8.js");
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

// ============================================================ 5.3: the real bias numbers
sub("5.3 Interpreting the column–surface relationship",
"First, TEMPO HCHO columns have been reported to be biased low by about 30 % relative to FTIR and Pandora observations (Ortega et al., 2026) [[add site-specific Boulder values and Rawat et al. (2026) high-column bias after checking the papers]]; correcting a 30 % low bias would raise the Colorado median H_{eff} from 0.83 km to about 1.2 km, comparable with the median PBL height.",
"First, TEMPO HCHO columns are biased low relative to ground-based column measurements, and the size of that bias is itself uncertain in a way that matters here. Against co-located FTIR, Ortega et al. (2026) report a median relative difference of −38 ± 27 % at Boulder, Colorado, with an orthogonal-distance-regression slope of 0.51 ± 0.01 and a small intercept, so that the underestimate grows with the column; against Pandora at the same site they find −41 % and −48 % for the two instruments. Across 36 Pandonia sites, Rawat et al. (2026) find the bias to depend strongly on column amount: −2 ± 20 % below 1.0 × 10^{16} molecules cm^{-2}, −13 ± 11 % between 1.0 and 1.5 × 10^{16}, and −22 ± 5 % above 1.5 × 10^{16}. Our median columns, 3.5 × 10^{15} in Colorado and 5.5 × 10^{15} nationally, sit in the lowest of those bands, where the network-wide bias is small; but Boulder, the Pandonia site closest to our Colorado monitors, is the most negatively biased site in their network at −44 %. Applying these constraints to the Colorado median gives a bias-corrected H_{eff} of about 0.85 km if the network-wide low-column result holds there and 1.3–1.5 km if the Boulder-specific values do, against a median TEMPO PBL height of 1.55 km. H_{eff} is therefore too uncertain to be read as a physical depth, which is why we treat it as a diagnostic. Both assessments used version 3 of the retrieval; we use version 4, for which no comparable published assessment yet exists.");

// ============================================================ 5.3: seasonal amplitude is real
sub("5.3 Interpreting the column–surface relationship",
"The larger seasonal amplitude of the column than of the surface concentration — 3.0-fold against 1.7-fold from winter to summer — is consistent with deeper summer mixing and a larger free-tropospheric HCHO column in summer.",
"The larger seasonal amplitude of the column than of the surface concentration — 3.0-fold against 1.7-fold from winter to summer — is consistent with deeper summer mixing and a larger free-tropospheric HCHO column in summer, and it is not an artefact of the retrieval: across the Pandonia network TEMPO reproduces the observed seasonal amplitude closely, with winter, spring and autumn medians lower than summer by 62 %, 45 % and 29 % against 66 %, 48 % and 28 % in the co-located Pandora record (Rawat et al., 2026).");

// ============================================================ 5.2: independent support for ~10 km
sub("5.2 Noise and spatial averaging",
"For comparisons with 24 h integrated samples, averaging over roughly 10 km and over all daylight scans is a reasonable default.",
"For comparisons with 24 h integrated samples, averaging over roughly 10 km and over all daylight scans is a reasonable default. Rawat et al. (2026) reach a compatible conclusion from the opposite direction, finding that a 10 km collocation radius reproduces the results that earlier satellite evaluations obtained with 20–40 km.");

// ============================================================ 5.1: the geostationary coverage gain
sub("5.1 What TEMPO captures at air toxics monitors",
"TEMPO HCHO columns reproduced the seasonal cycle and the broad differences among surface air toxics monitors, and a usable observation was available for about seven of every ten 24 h samples nationally and three of every four in Colorado.",
"TEMPO HCHO columns reproduced the seasonal cycle and the broad differences among surface air toxics monitors, and a usable observation was available for about seven of every ten 24 h samples nationally and three of every four in Colorado. That availability is a property of the geostationary orbit rather than of the retrieval: at a Pandonia site in New Jersey, hourly sampling yields a usable observation on about 50 % more days than the early-afternoon overpass alone would (Rawat et al., 2026).");

// ============================================================ 5.4: engage the competing explanation
sub("5.4 Sampling time, mixing, and why the lag that matters is site dependent",
"The simplest alternative, that early-morning retrievals are too poor to be useful, does not survive the California result: an early-morning window that carries no day-to-day information at two Colorado sites carries as much as a midday window at two Californian ones, which begin sampling an hour earlier still. The 24 h control and the scan-noise comparison (Sect. 4.8) point the same way.",
"The obvious alternative is that early-morning retrievals are simply less informative about the surface. This is not a straw man: Nawaz et al. (2025) compared TEMPO NO_{2} columns with AQS monitors and found the weakest agreement in the early morning — R^{2} of 0.23 at 06:00 and 0.35 at 07:00 local time — which they attribute to the satellite being less sensitive to near-surface pollution when the light path through the atmosphere is long. The same mechanism would apply to HCHO. Three things argue that it is not the whole explanation here. The California result is the strongest: an early-morning window that carries no day-to-day information at two Colorado sites carries as much as a midday window at two Californian ones, which begin sampling an hour earlier still and therefore at solar zenith angles no more favourable. The 24 h control, in which early scans track the surface as well as later ones, and the scan-noise comparison (Sect. 4.8) point the same way. A sensitivity effect that depends only on solar geometry cannot produce a result that differs between two regions at similar latitude; a mechanism that depends on how quickly the local boundary layer develops can. The two explanations are not exclusive, and both may contribute.");

// ============================================================ references
C.references.push(
"Sun, K., Saju, J. A., Nowlan, C. R., González Abad, G., and Liu, X.: Hourly nitrogen oxides emissions estimated from TEMPO and comparison with facility-level monitoring data, J. Geophys. Res.-Atmos., 130, e2025JD044565, https://doi.org/10.1029/2025JD044565, 2025."
);
C.references.sort((a, b) => a.localeCompare(b, "en"));

// ============================================================ notes
C.notes[1] = "Changes from v8, from the papers supplied on 14 September 2026: both retrieval-bias placeholders in Sect. 5.3 are resolved with the published numbers. Ortega et al. (2026) give Boulder-specific values (median difference -38 +/- 27 % against FTIR, ODR slope 0.51, and -41 %/-48 % against the two Pandora instruments); Rawat et al. (2026) give the column-dependent bias (-2 +/- 20 % below 1e16, -13 +/- 11 % from 1.0-1.5e16, -22 +/- 5 % above 1.5e16) and identify Boulder as the most negatively biased site in their network (-44 %). Our columns sit in the low-bias band while the Colorado-adjacent site is the most biased, so Sect. 5.3 now gives the bias-corrected H_{eff} as a range (0.85 km to 1.3-1.5 km against a 1.55 km PBL) and says plainly that H_{eff} cannot be read as a physical depth. Both assessments used retrieval version 3; we use version 4, which is now stated. Three further additions: Rawat's finding that TEMPO reproduces the Pandora seasonal amplitude (so our larger column amplitude is not a retrieval artefact, Sect. 5.3); Rawat's result that a 10 km collocation radius suffices, supporting our block-size choice (Sect. 5.2); and Rawat's ~50 % gain in usable days over an early-afternoon overpass (Sect. 5.1). Sect. 5.4 now engages Nawaz et al. (2025), who found the same early-morning breakdown for TEMPO NO_{2} against AQS monitors and attributed it to reduced sensitivity at long light paths - a serious competing explanation that the California result argues against but does not exclude.";
C.notes.splice(3, 0,
"Screened and found NOT to conflict with the novelty claim: the NASA DEVELOP Hampton Roads Health & Air Quality II report (Fall 2024) compares TEMPO and TROPOMI HCHO with Pandora columns and uses EPA AQS data for NO_{2} only, with no surface HCHO; Radkevich et al. (EGU 2025 poster and the ASDC presentation) compare TEMPO and Pandora columns; Sun et al. (2025) compare TEMPO NO_{x} emissions with stack monitoring; Wei et al. (2023) is an HCHO source-apportionment study in the Pearl River Delta with no satellite comparison. The ChemSusChem paper concerns the TEMPO nitroxyl radical and is a name collision.");

const out = "// content_v9.js - generated by mkcontent9.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync("content_v9.js", out);
console.log("wrote content_v9.js:", out.length, "chars; refs:", C.references.length);
