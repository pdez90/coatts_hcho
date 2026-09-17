// check_est.js - guards the condensation.
//
// Every statistic in the ES&T main text and Supporting Information should trace
// to something the analysis produced. There are two possible sources and they
// are NOT equivalent:
//
//   1. the pipeline output tables - what the analysis produces today. This is
//      the authority.
//   2. content_v19.js, the AMT-length draft the ES&T version was condensed
//      from - a historical record. A number that matches only here was true of
//      an earlier run and may since have moved.
//
// An earlier version of this script pooled the two, and that is exactly how a
// set of stale smoke statistics survived the 2023 extension: "0.66 (n = 31)"
// was no longer anywhere in the pipeline output, but it was still in the AMT
// draft, so the check passed. The two are now separated and anything resting on
// the draft alone is listed for review.
const fs   = require("fs");
const path = require("path");
const V19  = require("./content_v19.js");
const C    = require("./content_est.js");
const SI   = require("./content_est_si.js");

const norm = s => s
  .replace(/[   ]/g, " ")      // thin / non-breaking spaces
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

// Every CSV in the output directory, rather than a hand-kept list: a list has to
// be remembered when a step starts writing a new table, and it will not be.
const TABLE_DIR = process.env.HCHO_TABLES ||
  path.resolve(__dirname, "../../output/tables");
let tableFiles = [];
try { tableFiles = fs.readdirSync(TABLE_DIR).filter(f => f.endsWith(".csv")); }
catch (e) { console.warn("  note: cannot read " + TABLE_DIR + " - checking against the AMT draft only"); }
const tableText = tableFiles.map(f =>
  // round every number to the precision the manuscript might quote, so
  // "0.4904742" in the CSV matches "0.49" in the text
  fs.readFileSync(path.join(TABLE_DIR, f), "utf8").replace(/-?\d+\.\d+/g, m => {
    const v = Number(m);
    return [v.toFixed(0), v.toFixed(1), v.toFixed(2), v.toFixed(3), v.toFixed(4), m].join(" ");
  })
).join("  ");
console.log("  reading " + tableFiles.length + " output tables from " + TABLE_DIR);

const draftText = harvest(V19).join("  ");

// numbers worth checking: decimals, and integers of three digits or more
const NUM = /-?\d+\.\d+|\b\d{3,}\b/g;

const ALLOW = new Set([
  "7000",   // the ES&T word limit, quoted in the drafting notes
  "150",    // ES&T abstract limits, drafting notes
  "200",
  "2000",   // bootstrap replicates / permutations, phrased differently in v19
  "2001",   // the permutation p-value denominator
  "1000"    // RMA bootstrap resamples
]);

function check(doc, label) {
  const misses = [], stale = [];
  harvest(doc).forEach(t => {
    (t.match(NUM) || []).forEach(tok => {
      if (ALLOW.has(tok)) return;
      const ctx = t.slice(Math.max(0, t.indexOf(tok) - 70), t.indexOf(tok) + 70);
      if (tableText.includes(tok)) return;
      (draftText.includes(tok) ? stale : misses).push({ tok, ctx });
    });
  });
  const uniq = a => { const seen = new Set(); return a.filter(x => seen.has(x.tok) ? false : (seen.add(x.tok), true)); };
  const m = uniq(misses), s = uniq(stale);
  console.log("\n" + label + ": " + m.length + " token(s) in no source, " +
              s.length + " token(s) only in the AMT draft");
  m.forEach(x => console.log("   MISSING  " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  s.forEach(x => console.log("   REVIEW   " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  return m.length;
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
console.log("\nSI cross-references: " + siFigs + " figures, " + siTabs + " tables;" +
  (missingF.length ? " never cited: " + missingF.join(",") : " all figures cited;") +
  (missingT.length ? " tables never cited: " + missingT.join(",") : " all tables cited;") +
  (overF.length + overT.length ? " CITED BUT ABSENT: " + overF.concat(overT).join(",") : " no dangling citations"));

if (bad) { console.log("\nMISSING tokens appear in no source at all. Fix before submitting."); process.exit(1); }
console.log("\nEvery number traces to a pipeline table, or is listed above for review.");
