// mkcontent16.js - content_v15.js -> content_v16.js
//
// Reviewer fixes:
//  1. The screening-failure denominators now match the day-type table. R/15
//     restricts the criterion-relaxation diagnostic to the screened-out 24 h
//     sample days that enter the comparison, and the counts are read here
//     straight out of observability_screen_attribution.csv rather than being
//     transcribed by hand. The diagnostic reaches all 100 Colorado days and
//     2208 of the 2253 national ones; the shortfall is stated in the text.
//  2. The rescue counts are stated to be non-exclusive; "a further" is gone.
//  3. "fail on more than one ground" -> proper wording (the sentence is rewritten).
//  4. The Colorado seven-cluster regression no longer carries its nominal p.
//  5. Sect. 5.1 says "granules available but no scan passed screening" rather
//     than "days it cannot [observe]", which would include no-granule days.
const fs = require("fs");
const path = require("path");
const C = require("./content_v15.js");
const S = C.sections;

// ---------------------------------------------------------------- attribution
const CSV = process.env.HCHO_ATTRIB ||
  path.resolve(__dirname, "../../output/tables/observability_screen_attribution.csv");
if (!fs.existsSync(CSV)) {
  throw new Error("attribution table not found: " + CSV +
    "\n  Run R/15_clear_sky_bias.R first (Rscript R/15_clear_sky_bias.R).");
}
const lines = fs.readFileSync(CSV, "utf8").trim().split(/\r?\n/);
const head = lines[0].split(",");
const rows = lines.slice(1).map(l => {
  const v = l.split(",");
  const o = {};
  head.forEach((h, i) => { const n = Number(v[i]); o[h] = (v[i] !== "" && !isNaN(n)) ? n : v[i]; });
  return o;
});
const pick = arm => {
  const r = rows.find(x => x.arm === arm && x.scope === "comparison (24 h)");
  if (!r) throw new Error('no "comparison (24 h)" row for ' + arm + " in " + CSV +
    "\n  rows present: " + rows.map(x => x.arm + " / " + x.scope).join("; "));
  return r;
};
const co = pick("Colorado (24 h)"), na = pick("National (24 h)");

// The diagnostic assigns each scan to a local date from the site's longitude,
// which is not quite the matching used to build the analysis files, so a few
// national sample days have no cell-level record. Report the coverage rather
// than quietly quoting a smaller denominator; abort if it is not near-complete.
const TOTAL = { co: 100, na: 2253 };            // screened-out days in Sect. 4.11
const cov = { co: co.screened_out_days / TOTAL.co, na: na.screened_out_days / TOTAL.na };
for (const k of ["co", "na"]) {
  if (cov[k] > 1 || cov[k] < 0.95) {
    throw new Error("attribution coverage for " + k + " is " +
      (100 * cov[k]).toFixed(1) + " % (" + (k === "co" ? co : na).screened_out_days +
      " of " + TOTAL[k] + "). Expected 95-100 %. Reconcile before building.");
  }
}
const pc = r => Math.round(r.pct_cloud);
const num = n => (n === 0 ? "none" : String(n));

// coverage clause, stated only for the arm that is short
const shortfall = [];
if (co.screened_out_days < TOTAL.co)
  shortfall.push(co.screened_out_days + " of Colorado's " + TOTAL.co);
if (na.screened_out_days < TOTAL.na)
  shortfall.push(na.screened_out_days + " of the " + TOTAL.na + " national ones (" +
    Math.round(100 * cov.na) + " %)");
const covered =
  (co.screened_out_days === TOTAL.co ? "all " + TOTAL.co + " of Colorado's screened-out sample days"
                                     : co.screened_out_days + " of Colorado's " + TOTAL.co + " screened-out sample days") +
  " and " +
  (na.screened_out_days === TOTAL.na ? "all " + TOTAL.na + " of the national ones"
                                     : na.screened_out_days + " of the " + TOTAL.na + " national ones (" +
                                       Math.round(100 * cov.na) + " %)");
const covSentence = "Cell-level records allow " + covered +
  " to be re-evaluated with one criterion relaxed at a time" +
  (shortfall.length
    ? "; the remainder are sample days whose scans this diagnostic cannot place, because it assigns each scan to a local date from the site's longitude rather than through the matching used to build the analysis files"
    : "") + ". ";

// ---------------------------------------------------------------- helpers
const ix = t => {
  const i = S.findIndex(s => (s.h1 || s.h2 || "") === t);
  if (i < 0) throw new Error("no section: " + t);
  return i;
};
function setPara(head, j, from, to) {      // replace a whole paragraph, checked
  const s = S[ix(head)];
  if (!s.p[j].startsWith(from)) {
    throw new Error("paragraph " + j + " of " + head + " does not start with:\n  " +
      from.slice(0, 80) + "\nit starts with:\n  " + s.p[j].slice(0, 80));
  }
  s.p[j] = to;
}
function sub(head, from, to) {             // replace a fragment, checked
  const s = S[ix(head)];
  let hit = 0;
  s.p = s.p.map(t => { if (t.includes(from)) { hit++; return t.replace(from, to); } return t; });
  if (hit !== 1) throw new Error("expected 1 match in " + head + ", got " + hit + ": " + from.slice(0, 70));
}

// ---------------------------------------------------------------- 1. Sect. 3.8
sub("3.8 Observability of sample days",
"This analysis uses the 24 h samples of both arms; days with no granule are excluded from the comparisons below, so that gaps in TEMPO's own sampling are not counted as screening.",
"These relaxation counts are not mutually exclusive: a sampling period usually contains several scans, and different scans within it can fail different criteria, so one period can be rescued by more than one single relaxation. The analysis uses the 24 h samples of both arms, and the relaxation diagnostic is evaluated on the screened-out 24 h sample days that enter the comparisons, so that it shares their denominator apart from a small number of national days whose scans it cannot assign to a local date (Sect. 4.11); the corresponding tally over every site-day in the TEMPO extraction, which also covers Colorado's 3 h arm and the 8 h and 3 h national samples, is reported alongside it in the output table. Days with no granule are excluded from the comparisons below, so that gaps in TEMPO's own sampling are not counted as screening.");

// ---------------------------------------------------------------- 2. Sect. 4.11
setPara("4.11 Are the days TEMPO can observe representative?", 1,
"Screening is not a cloud filter alone.",
"Screening is not a cloud filter alone. " + covSentence +
"The effective cloud fraction threshold on its own would have made at least one scan usable for " +
co.rescued_by_cloud + " of the Colorado days (" + pc(co) + " %) and " +
na.rescued_by_cloud + " of the national days (" + pc(na) + " %). Snow or ice cover would have rescued " +
num(co.rescued_by_snow) + " and " + num(na.rescued_by_snow) + ", the solar zenith angle limit " +
num(co.rescued_by_sza) + " and " + num(na.rescued_by_sza) + ", and the main data quality flag " +
num(co.rescued_by_flag) + " and " + num(na.rescued_by_flag) + "; " +
co.rescued_by_none + " and " + na.rescued_by_none +
" would not have been rescued by relaxing any single criterion. These counts are not mutually exclusive: a sampling period usually contains several scans, and different scans within it can fail different criteria, so one period can be rescued by more than one of them. About a third of the rejections therefore survive the removal of the cloud threshold alone, and the contrast below is between days TEMPO can and cannot supply a screened observation for — an observability contrast — not a comparison of clear with cloudy days.");

sub("4.11 Are the days TEMPO can observe representative?",
"0.39 µg m^{-3} (0.17 to 0.60; 15 % of its median; n = 438 at 7 monitors, p = 0.012). Clustering matters for Colorado: with only seven monitors the cluster-robust standard error is 0.109 against 0.093 under independence.",
"0.39 µg m^{-3} (0.17 to 0.60; 15 % of its median; n = 438 at 7 monitors). Cluster-robust inference rests on the number of clusters, and seven monitors are few: the clustered standard error is 0.109 against 0.093 under independence, but its reference distribution is poorly approximated at this few clusters, so we place no weight on the nominal significance of the Colorado regression and rely there on the site-month estimate below, whose interval resamples monitors.");

// ------------------------------------------------------- 2b. Conclusions
// On the comparison days the cloud threshold accounts for about two thirds of
// the rejections, not about half as the all-site-days tally implied.
sub("6 Conclusions",
"Screening rejects days for several reasons and the cloud threshold alone accounts for only about half of them,",
"Screening rejects days for several reasons and the cloud threshold alone accounts for about two thirds of them,");

// ---------------------------------------------------------------- 3. Sect. 5.1
sub("5.1 What TEMPO captures at air toxics monitors",
"days TEMPO can observe carry about 25 % more surface HCHO than days it cannot, at the same monitor and time of year",
"days with a usable TEMPO observation carry about 25 % more surface HCHO than days for which granules were available but no scan passed screening, at the same monitor and time of year");

// ---------------------------------------------------------------- 4. notes
if (C.notes[0].includes("commit 7ce487a")) {
  C.notes[0] = C.notes[0].replace("analysis code at commit 7ce487a",
    "analysis code at the commit recorded in Code availability");
}
C.notes[1] = "Changes from v15: the criterion-relaxation diagnostic in Sect. 4.11 is now computed on the screened-out 24 h sample days that enter the comparison rather than on every site-day in the TEMPO extraction, which also covered Colorado's 3 h arm and the 8 h and 3 h national samples. The denominators are therefore " +
TOTAL.co + " and " + TOTAL.na + " as stated in the sentence before, of which the diagnostic reaches " +
co.screened_out_days + " and " + na.screened_out_days + "; the " + (TOTAL.na - na.screened_out_days) +
" national days it cannot place are days whose scans it assigns to a local date from longitude rather than through the pipeline's own matching, and the text says so. On the comparison days the cloud threshold alone accounts for " +
pc(co) + " % and " + pc(na) + " % of rejections, against 54 % and 51 % over all site-days, so the text now says about two thirds rather than about half; the wider tally is still written to output/tables/observability_screen_attribution.csv under scope \"all site-days\". The rescue counts are stated to be non-exclusive, since different scans within one sampling period can fail different criteria. The nominal p of the seven-cluster Colorado regression is removed and the site-month bootstrap carries that arm. Sect. 5.1 now contrasts usable observations with granule-bearing days that failed screening rather than with \"days it cannot [observe]\", which would have included no-granule days. The numbers in Sect. 4.11 are read from the pipeline output by mkcontent16.js rather than transcribed.";

// ---------------------------------------------------------------- write
const out = "// content_v16.js - generated by mkcontent16.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync(path.resolve(__dirname, "content_v16.js"), out);
const line = (t, r) => t + ": " + r.screened_out_days + " screened out; cloud " +
  r.rescued_by_cloud + " (" + pc(r) + " %), snow " + r.rescued_by_snow + ", SZA " +
  r.rescued_by_sza + ", flag " + r.rescued_by_flag + ", none " + r.rescued_by_none;
console.log(line("attribution, Colorado", co) + "  [coverage " + (100 * cov.co).toFixed(0) + " %]");
console.log(line("attribution, national", na) + "  [coverage " + (100 * cov.na).toFixed(0) + " %]");
console.log("wrote content_v16.js:", out.length, "chars");
