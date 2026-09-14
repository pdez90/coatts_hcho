// mkcontent16.js - content_v15.js -> content_v16.js
//
// Reviewer fixes:
//  1. The screening-failure denominators now match the day-type table. R/15
//     restricts the criterion-relaxation diagnostic to exactly the screened-out
//     24 h sample days that enter the comparison, and the counts are read here
//     straight out of observability_screen_attribution.csv rather than being
//     transcribed by hand.
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

// the denominators must be the screened-out counts already quoted in Sect. 4.11
const EXPECT = { co: 100, na: 2253 };
if (co.screened_out_days !== EXPECT.co || na.screened_out_days !== EXPECT.na) {
  throw new Error("denominator mismatch: the attribution table reports " +
    co.screened_out_days + " Colorado and " + na.screened_out_days +
    " national screened-out days, but Sect. 4.11 states " + EXPECT.co + " and " +
    EXPECT.na + ". Reconcile before building.");
}
const pc = r => Math.round(r.pct_cloud);

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
"These relaxation counts are not mutually exclusive: a sampling period usually contains several scans, and different scans within it can fail different criteria, so one period can be rescued by more than one single relaxation. The analysis uses the 24 h samples of both arms, and the relaxation diagnostic is evaluated on exactly the screened-out 24 h sample days that enter the comparisons, so that it shares their denominator; the corresponding tally over every site-day in the TEMPO extraction, which also covers Colorado's 3 h arm and the 8 h and 3 h national samples, is reported alongside it in the output table. Days with no granule are excluded from the comparisons below, so that gaps in TEMPO's own sampling are not counted as screening.");

// ---------------------------------------------------------------- 2. Sect. 4.11
setPara("4.11 Are the days TEMPO can observe representative?", 1,
"Screening is not a cloud filter alone.",
"Screening is not a cloud filter alone. Re-evaluating the screened-out sample days with one criterion relaxed at a time, the effective cloud fraction threshold on its own would have made at least one scan usable for " +
co.rescued_by_cloud + " of the " + co.screened_out_days + " in Colorado (" + pc(co) + " %) and " +
na.rescued_by_cloud + " of the " + na.screened_out_days + " nationally (" + pc(na) + " %). Snow or ice cover would have rescued " +
co.rescued_by_snow + " and " + na.rescued_by_snow + ", the solar zenith angle limit " +
co.rescued_by_sza + " and " + na.rescued_by_sza + ", and the main data quality flag " +
co.rescued_by_flag + " and " + na.rescued_by_flag + ", while " +
co.rescued_by_none + " and " + na.rescued_by_none +
" would not have been rescued by relaxing any single criterion. These counts are not mutually exclusive: a sampling period usually contains several scans, and different scans within it can fail different criteria, so one period can be rescued by more than one of them. The contrast below is therefore between days TEMPO can and cannot supply a screened observation for — an observability contrast — and not a comparison of clear with cloudy days.");

sub("4.11 Are the days TEMPO can observe representative?",
"0.39 µg m^{-3} (0.17 to 0.60; 15 % of its median; n = 438 at 7 monitors, p = 0.012). Clustering matters for Colorado: with only seven monitors the cluster-robust standard error is 0.109 against 0.093 under independence.",
"0.39 µg m^{-3} (0.17 to 0.60; 15 % of its median; n = 438 at 7 monitors). Cluster-robust inference rests on the number of clusters, and seven monitors are few: the clustered standard error is 0.109 against 0.093 under independence, but its reference distribution is poorly approximated at this few clusters, so we place no weight on the nominal significance of the Colorado regression and rely there on the site-month estimate below, whose interval resamples monitors.");

// ---------------------------------------------------------------- 3. Sect. 5.1
sub("5.1 What TEMPO captures at air toxics monitors",
"days TEMPO can observe carry about 25 % more surface HCHO than days it cannot, at the same monitor and time of year",
"days with a usable TEMPO observation carry about 25 % more surface HCHO than days for which granules were available but no scan passed screening, at the same monitor and time of year");

// ---------------------------------------------------------------- 4. notes
if (C.notes[0].includes("commit 7ce487a")) {
  C.notes[0] = C.notes[0].replace("analysis code at commit 7ce487a",
    "analysis code at the commit recorded in Code availability");
}
C.notes[1] = "Changes from v15: the criterion-relaxation diagnostic in Sect. 4.11 is now computed on exactly the screened-out 24 h sample days that enter the comparison (" +
EXPECT.co + " in Colorado, " + EXPECT.na + " nationally), so its denominator matches the day-type sentence before it; the previous counts came from every site-day in the TEMPO extraction, which also covers Colorado's 3 h arm and the 8 h and 3 h national samples, and that wider tally is still written to output/tables/observability_screen_attribution.csv under scope \"all site-days\". The rescue counts are stated to be non-exclusive, since different scans within one sampling period can fail different criteria. The nominal p of the seven-cluster Colorado regression is removed and the site-month bootstrap carries that arm. Sect. 5.1 now contrasts usable observations with granule-bearing days that failed screening rather than with \"days it cannot [observe]\", which would have included no-granule days. The numbers in Sect. 4.11 are read from the pipeline output by mkcontent16.js rather than transcribed.";

// ---------------------------------------------------------------- write
const out = "// content_v16.js - generated by mkcontent16.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync(path.resolve(__dirname, "content_v16.js"), out);
console.log("attribution, Colorado : " + co.screened_out_days + " screened out; cloud " +
  co.rescued_by_cloud + " (" + pc(co) + " %), snow " + co.rescued_by_snow + ", SZA " +
  co.rescued_by_sza + ", flag " + co.rescued_by_flag + ", none " + co.rescued_by_none);
console.log("attribution, national : " + na.screened_out_days + " screened out; cloud " +
  na.rescued_by_cloud + " (" + pc(na) + " %), snow " + na.rescued_by_snow + ", SZA " +
  na.rescued_by_sza + ", flag " + na.rescued_by_flag + ", none " + na.rescued_by_none);
console.log("wrote content_v16.js:", out.length, "chars");
