// check_amt.js - every number in the AMT manuscript and supplement must trace
// to the pipeline.
//
// Three kinds of number appear in the rendered documents:
//   derived   - {{n:key}} markers resolved from manuscript_numbers_*.csv, and
//               every cell of a table that tables_amt.js renders from a CSV.
//               These cannot be transcribed wrongly and are not re-checked.
//   verified  - literals in prose, captions and the literal supplement tables
//               (S1, S4, S5, S6). Each must occur in at least one output table, rounded
//               to the precision the text uses; a decimal found in five or more
//               tables is reported as weakly verified.
//   exempt    - physical constants and procedural counts, each pinned to the
//               sentence that names it.
// Citation markers are removed before numbers are harvested, so reference
// years are never mistaken for results.
const fs = require("fs");
const path = require("path");
const N = require("./numbers.js");
const T = require("./tables_amt.js");
const RAW = { C: require("./content_amt.js"), SI: require("./content_amt_si.js") };
const C = N.resolve(RAW.C), SI = N.resolve(RAW.SI);

const norm = s => String(s)
  .replace(/\{\{[@~]?[a-z][A-Za-z0-9_]*\}\}/g, "")   // citations
  .replace(/[   ]/g, " ")             // thin / non-breaking spaces
  .replace(/[‐-―−]/g, "-")            // dashes and minus signs
  .replace(/(\d)[, ](\d{3})(?!\d)/g, "$1$2")         // thousands commas or spaces
  .replace(/\s+/g, " ");

function harvest(doc) {
  const out = [];
  const push = t => { if (typeof t === "string") out.push(norm(t)); };
  (doc.abstract || []).forEach(push);
  [...(doc.sections || []), ...(doc.backmatter || [])].forEach(s => {
    (s.p || []).forEach(push);
    if (s.fig) push(s.fig.caption);
    if (s.table) {
      push(s.table.caption); push(s.table.notes);
      if (!s.table.builder) { s.table.header.forEach(push); s.table.rows.forEach(r => r.forEach(push)); }
    }
  });
  return out;
}

const TABLE_DIR = N.TABLE_DIR;
const tableFiles = fs.readdirSync(TABLE_DIR).filter(f => f.endsWith(".csv"));
const perTable = tableFiles.map(f => [f,
  fs.readFileSync(path.join(TABLE_DIR, f), "utf8").replace(/[  ]/g, "").replace(/-?\d+\.\d+/g, m => {
    const v = Number(m);
    return [v.toFixed(0), v.toFixed(1), v.toFixed(2), v.toFixed(3), v.toFixed(4), m,
            (Math.round(v * 100) / 100).toString(), (Math.round(v * 1000) / 1000).toString()].join(" ");
  })]);
const tableText = perTable.map(x => x[1]).join("  ");
const tablesWith = tok => perTable.filter(x => x[1].includes(tok)).map(x => x[0]);
const WEAK_TABLES = 5;
console.log("  reading " + tableFiles.length + " output tables from " + TABLE_DIR);

const NUM = /(?<![\d.])-?\d+\.\d+|\b\d{2,}\b/g;
const ALLOW = new Map([
  ["2000",   /permutation|bootstrap|replicate/i],
  ["2001",   /permutation/i],
  ["1000",   /bootstrap|resample/i],
  ["24.45",  /mixing ratio|molar volume/i],
  ["30.026", /g mol|molar mass/i],
  ["10.5067", /doi\.org|Science Data Center/i],
  ["0.02",   /grid/i],                                 // the L3 grid spacing in degrees
  ["0.999",  /capped|transformation/i],                // the cap on E before Fisher transformation
]);
const allowed = (tok, para) => ALLOW.has(tok) && ALLOW.get(tok).test(para);

// derived tokens: resolved markers, and every cell of a CSV-rendered table
const derived = new Set();
const map = N.load();
[RAW.C, RAW.SI].forEach(doc => harvest(doc).forEach(t => {
  for (const m of t.matchAll(/\{\{n:([A-Za-z0-9_]+)\}\}/g)) if (map.has(m[1])) derived.add(norm(map.get(m[1])));
}));
T.names.forEach(n => { const t = T.build(n); [...t.header, ...t.rows.flat()].forEach(c => (norm(c).match(NUM) || []).forEach(x => derived.add(x))); });

function check(doc, label) {
  const misses = [], weak = [];
  harvest(doc).forEach(t => {
    (t.match(NUM) || []).forEach(tok => {
      if (allowed(tok, t) || derived.has(tok)) return;
      // times (06:00), dates, section and figure numbers, AQS identifiers and years are structure, not results
      const i = t.indexOf(tok);
      const before = t.slice(Math.max(0, i - 12), i), after = t.slice(i + tok.length, i + tok.length + 8);
      if (/[:\-]$/.test(before) || /^[:\-]\d/.test(after) || /(Sect\.|Section|Fig\.|Figure|Figs\.|Table|version|Level|V0?)\s*S?$/i.test(before)) return;
      if (/^(19|20)\d\d$/.test(tok) && !/(n ?= ?|r ?= ?|p ?= ?)$/.test(before)) return;
      const ctx = t.slice(Math.max(0, i - 70), i + 70);
      if (tableText.includes(tok)) {
        if (/\./.test(tok) && tablesWith(tok).length >= WEAK_TABLES) weak.push({ tok, ctx, n: tablesWith(tok).length });
        return;
      }
      misses.push({ tok, ctx });
    });
  });
  const uniq = a => { const seen = new Set(); return a.filter(x => seen.has(x.tok + x.ctx) ? false : (seen.add(x.tok + x.ctx), true)); };
  const m = uniq(misses), w = uniq(weak);
  console.log("\n" + label + ": " + m.length + " literal(s) in no output table, " + w.length + " literal decimal(s) matching " + WEAK_TABLES + "+ tables");
  m.forEach(x => console.log("   MISSING  " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  if (process.env.HCHO_SHOW_WEAK) w.forEach(x => console.log("   WEAK(" + x.n + ")  " + x.tok + "   ...(" + x.ctx.trim() + ")..."));
  return m.length;
}

let bad = 0;
bad += check(C, "main text");
bad += check(SI, "supplement");

// cross-references: every Fig./Table S-number cited exists, and each exists is cited
const siFigs = SI.sections.filter(s => s.fig).length, siTabs = SI.sections.filter(s => s.table).length;
const mainFigs = C.sections.filter(s => s.fig).length, mainTabs = C.sections.filter(s => s.table).length;
const cited = new Set();
harvest(C).concat(harvest(SI)).forEach(t => {
  for (const m of t.matchAll(/Figs?\.?\s*S(\d+)(?:\s*(?:-|and|,)\s*S?(\d+))?/g)) { const a = +m[1], b = m[2] ? +m[2] : a; for (let i = a; i <= b; i++) cited.add("SF" + i); }
  for (const m of t.matchAll(/Tables?\s*S(\d+)(?:\s*(?:-|and|,)\s*S?(\d+))?/g)) { const a = +m[1], b = m[2] ? +m[2] : a; for (let i = a; i <= b; i++) cited.add("ST" + i); }
  for (const m of t.matchAll(/Figs?\.?\s*(\d+)(?:\s*(?:-|and|,)\s*(\d+))?(?![\d:])/g)) { const a = +m[1], b = m[2] ? +m[2] : a; for (let i = a; i <= b; i++) cited.add("F" + i); }
  for (const m of t.matchAll(/Table\s*(\d+)(?!\d)/g)) cited.add("T" + m[1]);
});
const gaps = [];
for (let i = 1; i <= siFigs; i++) if (!cited.has("SF" + i)) gaps.push("Fig. S" + i + " never cited");
for (let i = 1; i <= siTabs; i++) if (!cited.has("ST" + i)) gaps.push("Table S" + i + " never cited");
for (let i = 1; i <= mainFigs; i++) if (!cited.has("F" + i)) gaps.push("Fig. " + i + " never cited");
for (let i = 1; i <= mainTabs; i++) if (!cited.has("T" + i)) gaps.push("Table " + i + " never cited");
[...cited].forEach(k => {
  const n = +k.replace(/\D/g, "");
  if (k.startsWith("SF") && n > siFigs) gaps.push("Fig. S" + n + " cited but absent");
  else if (k.startsWith("ST") && n > siTabs) gaps.push("Table S" + n + " cited but absent");
  else if (k.startsWith("F") && n > mainFigs) gaps.push("Fig. " + n + " cited but absent");
  else if (k.startsWith("T") && n > mainTabs) gaps.push("Table " + n + " cited but absent");
});
console.log("\ncross-references: main " + mainFigs + " figures / " + mainTabs + " table; supplement " + siFigs + " figures / " + siTabs + " tables; " +
            (gaps.length ? gaps.join("; ") : "all cited, none dangling"));

if (bad || gaps.length) { console.log("\nFix the items above before building for submission."); process.exit(1); }
console.log("\nEvery number is derived from the pipeline or verified against an output table.");
