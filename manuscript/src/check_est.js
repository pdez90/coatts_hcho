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
const N    = require("./numbers.js");   // resolves {{n:key}} from the pipeline
const C    = N.resolve(require("./content_est.js"));
const SI   = N.resolve(require("./content_est_si.js"));

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
// One rounded text per table, kept separate so a match can be attributed to the
// table(s) it came from. A token that matches many tables is barely verified:
// "0.42" is in a dozen files and would pass whatever it was meant to be.
const perTable = tableFiles.map(f => [f,
  // round every number to the precision the manuscript might quote, so
  // "0.4904742" in the CSV matches "0.49" in the text
  fs.readFileSync(path.join(TABLE_DIR, f), "utf8").replace(/-?\d+\.\d+/g, m => {
    const v = Number(m);
    return [v.toFixed(0), v.toFixed(1), v.toFixed(2), v.toFixed(3), v.toFixed(4), m].join(" ");
  })]);
const tableText = perTable.map(x => x[1]).join("  ");
const tablesWith = tok => perTable.filter(x => x[1].includes(tok)).map(x => x[0]);
// A literal that matches this many tables is treated as unverified by this
// check, not as verified. Values the text derives by {{n:...}} are exempt: they
// come from a named cell and cannot be wrong in this way.
const WEAK_TABLES = 5;
console.log("  reading " + tableFiles.length + " output tables from " + TABLE_DIR);

const draftText = harvest(V19).join("  ");

// Decimals, and integers of two digits or more. Two-digit integers matter:
// Table S1 carried "92 samples, 42 matched" for Platteville through the 2023
// extension because the old threshold of three digits never looked at them.
// Years and section numbers are the cost, and they land in the review list.
const NUM = /-?\d+\.\d+|\b\d{2,}\b/g;

const ALLOW = new Set([
  "7000",   // the ES&T word limit, quoted in the drafting notes
  "150",    // ES&T abstract limits, drafting notes
  "200",
  "2000",   // bootstrap replicates / permutations, phrased differently in v19
  "2001",   // the permutation p-value denominator
  "1000"    // RMA bootstrap resamples
]);

// Tokens that arrived through a {{n:key}} marker are derived, not transcribed;
// they are recorded before resolution so the collision report can skip them.
const derivedTokens = new Set();
(function collect() {
  const raw = [require("./content_est.js"), require("./content_est_si.js")];
  const map = N.load();
  raw.forEach(doc => harvest(doc).forEach(t => {
    for (const m of t.matchAll(/\{\{n:([A-Za-z0-9_]+)\}\}/g)) if (map.has(m[1])) derivedTokens.add(map.get(m[1]));
  }));
})();

function check(doc, label) {
  const misses = [], stale = [], weak = [];
  harvest(doc).forEach(t => {
    (t.match(NUM) || []).forEach(tok => {
      if (ALLOW.has(tok)) return;
      const ctx = t.slice(Math.max(0, t.indexOf(tok) - 70), t.indexOf(tok) + 70);
      if (tableText.includes(tok)) {
        if (!derivedTokens.has(tok) && /\./.test(tok)) {
          const hits = tablesWith(tok);
          if (hits.length >= WEAK_TABLES) weak.push({ tok, ctx, n: hits.length });
        }
        return;
      }
      (draftText.includes(tok) ? stale : misses).push({ tok, ctx });
    });
  });
  const uniq = a => { const seen = new Set(); return a.filter(x => seen.has(x.tok) ? false : (seen.add(x.tok), true)); };
  const m = uniq(misses), s = uniq(stale), w = uniq(weak);
  console.log("\n" + label + ": " + m.length + " token(s) in no source, " +
              s.length + " token(s) only in the AMT draft, " +
              w.length + " literal decimal(s) matching " + WEAK_TABLES + "+ tables (weakly verified)");
  m.forEach(x => console.log("   MISSING  " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  s.forEach(x => console.log("   REVIEW   " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  if (process.env.HCHO_SHOW_WEAK) w.forEach(x => console.log("   WEAK(" + x.n + ")  " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
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
console.log("\nEvery number traces to a pipeline table, or is listed above for review.\n" +
            "Weakly verified literals are counted above; set HCHO_SHOW_WEAK=1 to list them, or derive them with {{n:...}}.");
