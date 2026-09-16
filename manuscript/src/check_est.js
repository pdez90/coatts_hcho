// check_est.js - guards the condensation.
//
// Every statistic in the ES&T main text and Supporting Information should trace
// to something the analysis produced: either content_v19.js, the AMT-length
// draft the ES&T version was condensed from, or - for the parts that have moved
// on since, notably the 3 h arm now reaching back to August 2023 - the pipeline
// output tables themselves. This extracts the numeric tokens from both ES&T
// documents and reports any that appear in neither.
// Tokens that are genuinely new to the ES&T version (section numbers, the
// journal's own limits) are listed in ALLOW with the reason.
const fs   = require("fs");
const path = require("path");
const V19  = require("./content_v19.js");
const C   = require("./content_est.js");
const SI  = require("./content_est_si.js");

const norm = s => s
  .replace(/[   ]/g, " ")      // thin / non-breaking spaces
  .replace(/[‐-―−]/g, "-")     // dashes and minus signs
  .replace(/\s+/g, " ");

function harvest(doc) {
  const out = [];
  const push = t => { if (typeof t === "string") out.push(norm(t)); };
  (doc.abstract || []).forEach(push);
  push(doc.shortSummary);
  (doc.sections || []).forEach(s => {
    (s.p || []).forEach(push);
    if (s.fig) push(s.fig.caption);
    if (s.table) { push(s.table.caption); s.table.header.forEach(push); s.table.rows.forEach(r => r.forEach(push)); push(s.table.notes); }
  });
  (doc.supplement || []).forEach(f => {
    push(f.caption);
    if (f.tableS) { push(f.tableS.caption); f.tableS.header.forEach(push); f.tableS.rows.forEach(r => r.forEach(push)); push(f.tableS.notes); }
  });
  return out;
}

// The AMT draft is no longer the sole reference: the 3 h arm now extends to
// August 2023, so its numbers postdate content_v19.js. Pipeline output tables
// are therefore part of the haystack too - which is the better authority
// anyway, since it is what the analysis actually produced.
const TABLE_DIR = process.env.HCHO_TABLES ||
  path.resolve(__dirname, "../../output/tables");
const TABLES = [
  "threeh_coverage.csv", "threeh_stats_by_site.csv",
  "threeh_stats_within_month_anomalies.csv", "threeh_month_effects_lm.csv",
  "threeh_inventory.csv", "threeh_stats_by_smoke.csv",
  "diag2_threeh_window_vs_after.csv", "diag1_threeh_window_columns.csv",
  "observability_screen_attribution.csv", "national_stats_by_duration_lag.csv",
  "check_2023_workbook_vs_aqs.csv"
];
const tableText = TABLES.map(f => {
  const full = path.join(TABLE_DIR, f);
  if (!fs.existsSync(full)) { console.warn("  note: table not found, skipped: " + f); return ""; }
  // round every number to the precision the manuscript quotes, so "0.4904742"
  // in the CSV matches "0.49" in the text
  return fs.readFileSync(full, "utf8").replace(/-?\d+\.\d+/g, m => {
    const v = Number(m);
    return [v.toFixed(0), v.toFixed(1), v.toFixed(2), v.toFixed(3), m].join(" ");
  });
}).join("  ");

const haystack = harvest(V19).join("  ") + "  " + tableText;

// numbers worth checking: decimals, and integers of three digits or more
const NUM = /-?\d+\.\d+|\b\d{3,}\b/g;

const ALLOW = new Set([
  "7000",   // the ES&T word limit, quoted in the drafting notes
  "150",    // ES&T abstract limits, drafting notes
  "200",
  "2000",   // bootstrap replicates, phrased differently in v19
  "1000"    // RMA bootstrap resamples
]);

function check(doc, label) {
  const misses = [];
  harvest(doc).forEach(t => {
    const m = t.match(NUM) || [];
    m.forEach(tok => {
      if (ALLOW.has(tok)) return;
      if (!haystack.includes(tok)) misses.push({ tok, ctx: t.slice(Math.max(0, t.indexOf(tok) - 60), t.indexOf(tok) + 60) });
    });
  });
  const seen = new Set();
  const uniq = misses.filter(x => (seen.has(x.tok) ? false : (seen.add(x.tok), true)));
  console.log(label + ": " + uniq.length + " numeric token(s) not found in the reference sources");
  uniq.forEach(x => console.log("   " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  return uniq.length;
}

let bad = 0;
bad += check(C, "main text");
bad += check(SI, "supporting information");

// cross-reference sanity: every Figure/Table S-number cited must exist
const siFigs = SI.sections.filter(s => s.fig).length;
const siTabs = SI.sections.filter(s => s.table).length;
const cited = new Set();
harvest(C).concat(harvest(SI)).forEach(t => {
  (t.match(/Figures? S(\d+)(?:\s*-\s*S?(\d+))?/g) || []).forEach(m => {
    const n = m.match(/\d+/g).map(Number);
    if (n.length === 2) { for (let i = n[0]; i <= n[1]; i++) cited.add("F" + i); } else cited.add("F" + n[0]);
  });
  (t.match(/Tables? S(\d+)(?:\s*(?:-|and)\s*S?(\d+))?/g) || []).forEach(m => {
    const n = m.match(/\d+/g).map(Number);
    if (n.length === 2) { for (let i = n[0]; i <= n[1]; i++) cited.add("T" + i); } else cited.add("T" + n[0]);
  });
});
const missingF = [...Array(siFigs).keys()].map(i => "F" + (i + 1)).filter(k => !cited.has(k));
const missingT = [...Array(siTabs).keys()].map(i => "T" + (i + 1)).filter(k => !cited.has(k));
const overF = [...cited].filter(k => k[0] === "F" && Number(k.slice(1)) > siFigs);
const overT = [...cited].filter(k => k[0] === "T" && Number(k.slice(1)) > siTabs);
console.log("SI cross-references: " + siFigs + " figures, " + siTabs + " tables;" +
  (missingF.length ? " never cited: " + missingF.join(",") : " all figures cited;") +
  (missingT.length ? " tables never cited: " + missingT.join(",") : " all tables cited;") +
  (overF.length + overT.length ? " CITED BUT ABSENT: " + overF.concat(overT).join(",") : " no dangling citations"));

if (bad) { console.log("\nReview the tokens above before submitting."); process.exit(1); }
console.log("\nEvery number in the ES&T version appears in content_v19.js or the pipeline tables.");
