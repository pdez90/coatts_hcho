// check_amt.js - every number in the AMT manuscript and supplement must trace
// to the pipeline.
//
// Three kinds of number appear in the rendered documents:
//   derived   - {{n:key}} markers resolved from manuscript_numbers_*.csv, and
//               every cell of a table that tables_amt.js renders from a CSV.
//               These cannot be transcribed wrongly and are not re-checked.
//   verified  - literals in prose, captions and the literal supplement tables
//               (S1, S5, S6, S7). Each must equal a whole number in at least one output table, rounded
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
// Whole numbers only: a literal is found when it is one of a table's numbers (or
// that number rounded as the text prints it), never as a fragment of a longer one.
perTable.forEach(x => { x[1] = new Set(x[1].match(/-?\d+(?:\.\d+)?/g) || []); });
const inTables = tok => perTable.some(x => x[1].has(tok));
const tablesWith = tok => perTable.filter(x => x[1].has(tok)).map(x => x[0]);
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
  ["43502",  /parameter code/i],                       // the AQS parameter code for formaldehyde
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
    // URLs and AQS site identifiers (08-077-0018) are structure, not results
    const spans = [...t.matchAll(/https?:\/\/\S+|\b\d\d-\d{3}-\d{4}\b/g)].map(m => [m.index, m.index + m[0].length]);
    for (const mt of t.matchAll(NUM)) {
      let tok = mt[0], i = mt.index;
      if (spans.some(([a, b]) => i >= a && i < b)) continue;
      const before = t.slice(Math.max(0, i - 12), i), after = t.slice(i + tok.length, i + tok.length + 8);
      // the second number of a range ("0.35-0.70") is not negative
      if (tok.startsWith("-") && /\d$/.test(before)) { tok = tok.slice(1); i += 1; }
      if (allowed(tok, t) || derived.has(tok)) continue;
      // times (06:00), dates (2024-01), section and figure numbers, AQS identifiers and years are structure, not results
      if (/:$/.test(before) || /^:\d/.test(after) || /\d{4}-$/.test(before) || /^-\d\d(?!\d)/.test(after) && /^(19|20)\d\d$/.test(tok) ||
          /\d\d-\d{3}-$/.test(before) || /^-\d{3}-\d{4}/.test(after) || /^\d\d-\d{3}$/.test(tok) ||
          /(Sect\.|Section|Fig\.|Figure|Figs\.|Table|version|Level|V0?)\s*S?$/i.test(before)) continue;
      if (/^(19|20)\d\d$/.test(tok) && !/(n ?= ?|r ?= ?|p ?= ?)$/.test(before)) continue;
      const ctx = t.slice(Math.max(0, i - 70), i + 70);
      if (inTables(tok)) {
        if (/\./.test(tok) && tablesWith(tok).length >= WEAK_TABLES) weak.push({ tok, ctx, n: tablesWith(tok).length });
        continue;
      }
      misses.push({ tok, ctx });
    }
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
// Supplement references, in reading order. "Tables S4 and S6" is two items,
// "Figs. S7-S9" three; a caption's own label ("Table S5.") is not a citation.
function siRefs(t) {
  const out = [];
  for (const m of t.matchAll(/\b(Figs?\.|Tables?)\s+((?:S\d+[a-z]?(?:\s*(?:-|,\s*and|,|and)\s*)?)+)/g)) {
    const kind = m[1][0] === "F" ? "SF" : "ST";
    for (const part of m[2].split(/\s*(?:,\s*and|,|and)\s*/)) {
      const r = part.match(/S(\d+)[a-z]?(?:\s*-\s*S?(\d+))?/); if (!r) continue;
      const a = +r[1], b = r[2] ? +r[2] : a; for (let i = a; i <= b; i++) out.push(kind + i);
    }
  }
  return out;
}
const ownLabel = t => t.replace(/^(Table|Figure) S?\d+\.\s*/, "");
const reading = harvest(C).map(ownLabel).concat(harvest(SI).map(ownLabel));
const cited = new Set();
reading.forEach(t => {
  siRefs(t).forEach(k => cited.add(k));
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
// numbering follows first citation: main text first, then the supplement
const first = { SF: [], ST: [] };
reading.forEach(t => siRefs(t).forEach(k => { const kind = k.slice(0, 2), n = +k.slice(2); if (!first[kind].includes(n)) first[kind].push(n); }));
for (const [kind, name] of [["SF", "Fig. S"], ["ST", "Table S"]]) {
  if (first[kind].some((n, i) => n !== i + 1)) gaps.push(name + " numbers are not in order of first citation (first cited: " + first[kind].map(n => name + n).join(", ") + ")");
}
SI.sections.filter(s => s.fig).forEach((s, i) => { if (!s.fig.caption.startsWith("Figure S" + (i + 1) + ".")) gaps.push("figure " + (i + 1) + " of the supplement is captioned " + s.fig.caption.slice(0, 12)); });
SI.sections.filter(s => s.table).forEach((s, i) => { if (!s.table.caption.startsWith("Table S" + (i + 1) + ".")) gaps.push("table " + (i + 1) + " of the supplement is captioned " + s.table.caption.slice(0, 11)); });
const mainFirst = [];
harvest(C).forEach(t => { for (const m of t.matchAll(/\bFigs?\.\s+(\d+)(?:\s*(?:-|and|,)\s*(\d+))?(?![\d:])/g)) { const a = +m[1], b = m[2] ? +m[2] : a; for (let i = a; i <= b; i++) if (!mainFirst.includes(i)) mainFirst.push(i); } });
if (mainFirst.some((n, i) => n !== i + 1)) gaps.push("main-text figures are not in order of first citation (" + mainFirst.join(", ") + ")");
// p-values printed from the pipeline must read "p < 0.001", never "p = 0.000"
harvest(C).concat(harvest(SI)).forEach(t => { const m = t.match(/\bp ?= ?(?:<|p\b|0\.0+(?![\d]))/); if (m) gaps.push("malformed p-value: ..." + t.slice(Math.max(0, m.index - 40), m.index + 20) + "..."); });

console.log("\ncross-references: main " + mainFigs + " figures / " + mainTabs + " table; supplement " + siFigs + " figures / " + siTabs + " tables; " +
            (gaps.length ? gaps.join("; ") : "all cited, none dangling"));

if (bad || gaps.length) { console.log("\nFix the items above before building for submission."); process.exit(1); }
console.log("\nEvery number is derived from the pipeline or verified against an output table.");
