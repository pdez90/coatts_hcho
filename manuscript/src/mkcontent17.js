// mkcontent17.js - content_v16.js -> content_v17.js
//
// Reviewer fixes:
//  1. Abstract quoted 0.11 for the Colorado 3 h within-window anomaly
//     correlation, which is the national-arm value from Sect. 4.10 (n = 79);
//     the Colorado arm, Table 3 and the Conclusions all give 0.12 (n = 78).
//     The abstract pairs it with 0.40 from the Colorado arm, so 0.12 is right.
//  2. "the days TEMPO can observe" / "the days it cannot" / "unobservable days"
//     imply a comparison that includes no-granule days, which are excluded.
//     Fixed in the Sect. 4.11 heading, the Conclusions, the short summary and
//     Sect. 5.7. The figure title is fixed in R/15 and rendered into the PNG.
//  3. R/15 now mirrors the pipeline's screening test, scan-validity threshold
//     and scan-to-sample assignment, so the diagnostic reproduces every
//     screened-out sample day and the coverage caveat is gone.
const fs = require("fs");
const path = require("path");
const C = require("./content_v16.js");
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

// The diagnostic now reproduces the pipeline exactly, so the denominators must
// be the screened-out counts quoted in Sect. 4.11 - no shortfall is tolerated.
const TOTAL = { co: 100, na: 2253 };
if (co.screened_out_days !== TOTAL.co || na.screened_out_days !== TOTAL.na) {
  throw new Error("denominator mismatch: the attribution table reports " +
    co.screened_out_days + " Colorado and " + na.screened_out_days +
    " national screened-out days, but Sect. 4.11 states " + TOTAL.co + " and " +
    TOTAL.na + ". Reconcile before building.");
}
const pc = r => Math.round(r.pct_cloud);
const num = n => (n === 0 ? "none" : String(n));

// the share of rejections the cloud threshold alone accounts for, in words -
// Sect. 4.11 uses the complement, Sect. 6 the share itself
function inWords(frac) {
  if (frac < 0.30) return "under a third";
  if (frac < 0.42) return "about a third";
  if (frac < 0.58) return "about half";
  if (frac < 0.72) return "about two thirds";
  if (frac < 0.85) return "about three quarters";
  return "nearly all";
}
const share = (co.pct_cloud + na.pct_cloud) / 200;
const SHARE_WORDS = inWords(share), REST_WORDS = inWords(1 - share);
if (SHARE_WORDS !== "about two thirds") {
  throw new Error("the cloud share is now " + (100 * share).toFixed(0) + " % (" +
    SHARE_WORDS + "); Sect. 6 says \"about two thirds\" and would need editing too.");
}

// ---------------------------------------------------------------- helpers
const ix = t => {
  const i = S.findIndex(s => (s.h1 || s.h2 || "") === t);
  if (i < 0) throw new Error("no section: " + t);
  return i;
};
function setPara(head, j, from, to) {
  const s = S[ix(head)];
  if (!s.p[j].startsWith(from)) {
    throw new Error("paragraph " + j + " of " + head + " does not start with:\n  " +
      from.slice(0, 80) + "\nit starts with:\n  " + s.p[j].slice(0, 80));
  }
  s.p[j] = to;
}
function sub(head, from, to) {
  const s = S[ix(head)];
  let hit = 0;
  s.p = s.p.map(t => { if (t.includes(from)) { hit++; return t.replace(from, to); } return t; });
  if (hit !== 1) throw new Error("expected 1 match in " + head + ", got " + hit + ": " + from.slice(0, 70));
}
// ---------------------------------------------------------------- 1. abstract
const A_FROM = "it was absent during the sampling window (0.11)";
const A_TO   = "it was absent during the sampling window (0.12)";
if (!C.abstract[3].includes(A_FROM)) throw new Error("abstract: not found: " + A_FROM);
C.abstract[3] = C.abstract[3].replace(A_FROM, A_TO);

// ------------------------------------------------- 2. observability wording
const OLD_H = "4.11 Are the days TEMPO can observe representative?";
const NEW_H = "4.11 Are sampling days with a usable TEMPO observation representative?";
S[ix(OLD_H)].h2 = NEW_H;

sub("6 Conclusions",
"The days TEMPO can observe are also not a representative sample of sampling days: at the same monitor and time of year they carry about 25 % more surface HCHO than the days screening removes, with the difference largest in summer.",
"Sampling days with a usable TEMPO observation are also not representative of the days for which granules were available but every scan failed screening: at the same monitor and time of year they carry about 25 % more surface HCHO, with the difference largest in summer.");

sub("5.7 Implications for air toxics monitoring and limitations",
"combining satellite observations with the monitor's own record on unobservable days is necessary",
"combining satellite observations with the monitor's own record on days with no usable retrieval, whether screened out or never observed, is necessary");

sub("5.1 What TEMPO captures at air toxics monitors",
"a monitor whose unobservable days differ most from its observable ones loses a systematically different set of conditions",
"a monitor whose screened-out days differ most from the days it can use loses a systematically different set of conditions");

const SS = C.shortSummary;
C.shortSummary = "Satellites now measure formaldehyde, a cancer-causing air pollutant, every daylight hour over North America. We compared these measurements with every routine surface sample collected at 123 US monitoring sites in 2024-2025. The satellite tracked day-to-day changes at most monitors but at some not at all, depending on the monitor and the sampling time, and surface formaldehyde was higher on days with usable satellite retrievals than on days when all available observations failed screening.";
if (C.shortSummary.length > 500) {
  throw new Error("short summary is " + C.shortSummary.length + " characters, over the 500 limit");
}
if (C.shortSummary === SS) throw new Error("short summary unchanged");

// ---------------------------------------------------------------- 3. Sect. 3.8
sub("3.8 Observability of sample days",
"so that it shares their denominator apart from a small number of national days whose scans it cannot assign to a local date (Sect. 4.11); the corresponding tally over every site-day in the TEMPO extraction, which also covers Colorado's 3 h arm and the 8 h and 3 h national samples, is reported alongside it in the output table.",
"applying the same cell-level screening test, the same scan-validity threshold and the same assignment of scans to sample periods as the main analysis, so that it reproduces every one of those days; a wider tally, over every site-day the extraction can place, is reported alongside it in the output table.");

// ---------------------------------------------------------------- 4. Sect. 4.11
setPara(NEW_H, 1,
"Screening is not a cloud filter alone.",
"Screening is not a cloud filter alone. Re-evaluating each screened-out sample day with one criterion relaxed at a time, the effective cloud fraction threshold on its own would have made at least one scan usable for " +
co.rescued_by_cloud + " of the " + co.screened_out_days + " in Colorado (" + pc(co) + " %) and " +
na.rescued_by_cloud + " of the " + na.screened_out_days + " nationally (" + pc(na) + " %). Snow or ice cover would have rescued " +
num(co.rescued_by_snow) + " and " + num(na.rescued_by_snow) + ", the solar zenith angle limit " +
num(co.rescued_by_sza) + " and " + num(na.rescued_by_sza) + ", and the main data quality flag " +
num(co.rescued_by_flag) + " and " + num(na.rescued_by_flag) + "; " +
co.rescued_by_none + " and " + na.rescued_by_none +
" would not have been rescued by relaxing any single criterion. These counts are not mutually exclusive: a sampling period usually contains several scans, and different scans within it can fail different criteria, so one period can be rescued by more than one of them. " +
REST_WORDS.charAt(0).toUpperCase() + REST_WORDS.slice(1) +
" of the rejections therefore survive the removal of the cloud threshold alone, and the contrast below is between sampling days with a usable observation and sampling days for which TEMPO returned granules but no scan passed — an observability contrast — not a comparison of clear with cloudy days.");

// ---------------------------------------------------------------- 5. figure size
const figSec = S.find(s => s.fig && s.fig.file === "fig14_observability_bias.png");
if (!figSec) throw new Error("fig14 section not found");
figSec.fig.w = 2100; figSec.fig.h = 1380;   // taller: the subtitle is now two lines

// ---------------------------------------------------------------- 6. notes
C.notes[1] = "Changes from v16: the abstract's Colorado 3 h within-window anomaly correlation is corrected from 0.11 to 0.12 - 0.11 is the national-arm value of Sect. 4.10 (n = 79), while the Colorado arm, Table 3 and the Conclusions give 0.12 (n = 78), and the abstract pairs it with 0.40 from the Colorado arm. Wording that implied a wider comparison than was made is fixed: the Sect. 4.11 heading, the Conclusions sentence, the short summary and Sect. 5.7 now distinguish sampling days with a usable observation from days for which granules were returned but no scan passed, and no-granule days remain excluded; Sect. 5.7 is the one place where the wider set is meant, so it says \"whether screened out or never observed\". R/15_clear_sky_bias.R now applies the pipeline's own screening test (a cell needs a vertical column; a missing quality flag, solar zenith angle or snow fraction passes, a missing cloud fraction fails), its scan-validity threshold and its scan-to-sample assignment, so the diagnostic reproduces all " +
TOTAL.co + " Colorado and all " + TOTAL.na + " national screened-out sample days and the v16 coverage caveat is removed. On those days the cloud threshold alone accounts for " +
pc(co) + " % and " + pc(na) + " % of rejections. Figure 13 is regenerated with the corrected title and a subtitle that states the comparison.";

// ---------------------------------------------------------------- write
const out = "// content_v17.js - generated by mkcontent17.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync(path.resolve(__dirname, "content_v17.js"), out);
const line = (t, r) => t + ": " + r.screened_out_days + " screened out; cloud " +
  r.rescued_by_cloud + " (" + pc(r) + " %), snow " + r.rescued_by_snow + ", SZA " +
  r.rescued_by_sza + ", flag " + r.rescued_by_flag + ", none " + r.rescued_by_none;
console.log(line("attribution, Colorado", co));
console.log(line("attribution, national", na));
console.log("cloud share " + (100 * share).toFixed(0) + " % -> \"" + SHARE_WORDS +
  "\"; complement \"" + REST_WORDS + "\"");
console.log("short summary " + C.shortSummary.length + " characters");
console.log("wrote content_v17.js:", out.length, "chars");
