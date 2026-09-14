// mkcontent10.js - content_v9.js -> content_v10.js
// Claim-calibration pass. Every change narrows a statement to what the evidence
// supports; none changes a number or an analysis.
//  1. H_eff corrections framed as sensitivity scenarios, not uncertainty bounds
//  2. "not an artefact of the retrieval" -> "unlikely to arise solely from retrieval seasonality"
//  3. the Nawaz rebuttal softened in 5.4 and 5.6 (California does not rule out
//     a regionally varying retrieval-sensitivity contribution)
//  4. three sentences where the mixing hypothesis had slipped back into fact
//  5. the geostationary-coverage claim qualified
//  6. 5.1 "significant at most monitors" -> the coefficient distribution
const fs = require("fs");
const C = require("./content_v9.js");
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

// ---------------------------------------------------------------- 1. scenarios, not bounds
sub("5.3 Interpreting the column–surface relationship",
"Applying these constraints to the Colorado median gives a bias-corrected H_{eff} of about 0.85 km if the network-wide low-column result holds there and 1.3–1.5 km if the Boulder-specific values do, against a median TEMPO PBL height of 1.55 km. H_{eff} is therefore too uncertain to be read as a physical depth, which is why we treat it as a diagnostic. Both assessments used version 3 of the retrieval; we use version 4, for which no comparable published assessment yet exists.",
"Illustrative corrections give a Colorado median H_{eff} of about 0.85 km under the network-wide low-column estimate and 1.3–1.5 km under the Boulder-specific estimates, against a median TEMPO PBL height of 1.55 km. These are sensitivity scenarios rather than uncertainty bounds: the two estimates come from different comparisons, Boulder's exceptional bias may reflect conditions that do not characterise our seven sites, a single factor cannot strictly be applied to a median that pools sites, seasons and column amounts, and neither assessment characterises version 4, which is the product used here. What the scenarios establish is that plausible corrections span most of the distance to the modelled boundary layer depth, so H_{eff} cannot be read as a physical depth — which is why we treat it as a diagnostic.");

// ---------------------------------------------------------------- 2. seasonal amplitude
sub("5.3 Interpreting the column–surface relationship",
"and it is not an artefact of the retrieval: across the Pandonia network TEMPO reproduces the observed seasonal amplitude closely, with winter, spring and autumn medians lower than summer by 62 %, 45 % and 29 % against 66 %, 48 % and 28 % in the co-located Pandora record (Rawat et al., 2026).",
"and it is unlikely to arise solely from retrieval seasonality: across the Pandonia network TEMPO reproduces the observed seasonal amplitude closely, with winter, spring and autumn medians lower than summer by 62 %, 45 % and 29 % against 66 %, 48 % and 28 % in the co-located Pandora record (Rawat et al., 2026). That fidelity is network-wide and does not by itself fix the retrieval's behaviour at our sites, where the bias depends on column amount (above).");

// ---------------------------------------------------------------- 3. the Nawaz rebuttal
sub("5.4 Sampling time, mixing, and why the lag that matters is site dependent",
"A sensitivity effect that depends only on solar geometry cannot produce a result that differs between two regions at similar latitude; a mechanism that depends on how quickly the local boundary layer develops can. The two explanations are not exclusive, and both may contribute.",
"The California results show that early-morning retrievals are not universally incapable of tracking surface variability. Because the two regions are at broadly comparable latitudes, solar geometry alone is unlikely to explain the full regional contrast, although retrieval sensitivity that varies regionally — with cloud, aerosol, surface albedo and profile shape as well as geometry — may still contribute. The two explanations are not exclusive, and both may be at work.");

sub("5.6 Colorado in national context, and what a national comparison adds",
"and a set of monitors whose morning samples do track the column, which is what rules out morning retrievals being the problem (Sect. 5.4).",
"and a set of monitors whose morning samples do track the column, showing that poor early-morning agreement is not universal and cannot automatically be attributed to the retrieval (Sect. 5.4).");

// ---------------------------------------------------------------- 4. hypothesis back as fact
sub("5.4 Sampling time, mixing, and why the lag that matters is site dependent",
"The midday block, wholly within the well-mixed afternoon, agrees better than the 04:00 block, which spends its first hours in the stable morning layer;",
"The midday block, which falls later in the day's boundary layer development, agrees better than the 04:00 block, which begins before dawn;");

sub("5.5 Wildfire smoke",
"(0.66 against 0.40) - the same window in which the sampled air has been mixed into the column.",
"(0.66 against 0.40) - the same post-sampling window in which surface–column agreement was strongest.");

// ---------------------------------------------------------------- 5. coverage claim
sub("5.1 What TEMPO captures at air toxics monitors",
"That availability is a property of the geostationary orbit rather than of the retrieval: at a Pandonia site in New Jersey, hourly sampling yields a usable observation on about 50 % more days than the early-afternoon overpass alone would (Rawat et al., 2026).",
"That availability primarily reflects the repeated sampling the geostationary orbit allows, rather than any property of the retrieval itself: at a Pandonia site in New Jersey, hourly sampling yields a usable observation on about 50 % more days than the early-afternoon overpass alone would (Rawat et al., 2026). Whether a given scan is usable still depends on cloud, solar zenith angle, retrieval success and the screening applied.");

// ---------------------------------------------------------------- 6. 5.1 significance -> distribution
sub("5.1 What TEMPO captures at air toxics monitors",
"Day-to-day agreement was weaker and strongly site dependent: significant at most monitors, with a median correlation near 0.5 at 24 h sites, but ranging from 0.9 to zero.",
"Day-to-day agreement was weaker and strongly site dependent: positive at most monitors, with a median correlation near 0.5 at 24 h sites, but ranging from −0.24 to 0.89.");

// ---------------------------------------------------------------- notes
C.notes[1] = "Changes from v9, a claim-calibration pass in response to review; no number and no analysis changed. The corrected H_{eff} values in Sect. 5.3 are now presented as sensitivity scenarios rather than uncertainty bounds, with the four reasons they are not bounds stated (different comparisons, Boulder's exceptional bias, a single factor applied to a pooled median, and version 3 versus version 4). \"Not an artefact of the retrieval\" is narrowed to \"unlikely to arise solely from retrieval seasonality\", with a note that network-wide seasonal fidelity does not fix the retrieval's behaviour at our sites. The rebuttal to Nawaz et al. (2025) in Sect. 5.4 no longer claims that solar geometry \"cannot\" produce the regional contrast, only that it is unlikely to explain all of it, since retrieval sensitivity varies with cloud, aerosol, albedo and profile shape as well as geometry; Sect. 5.6 likewise no longer says the California sites \"rule out\" a retrieval explanation. Three sentences in which the mixing hypothesis had slipped back into stated fact are rewritten (the 8 h midday block, the smoke window in Sect. 5.5, and the Sect. 5.6 claim). The geostationary-coverage statement is qualified. Sect. 5.1 now reports the distribution of site correlations instead of calling them significant, removing an internal tension with Sect. 4.9.";

const out = "// content_v10.js - generated by mkcontent10.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync("content_v10.js", out);
console.log("wrote content_v10.js:", out.length, "chars");
