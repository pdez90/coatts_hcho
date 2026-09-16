// check_est.js - guards the condensation.
//
// Every statistic in the ES&T main text and Supporting Information should have
// been carried over unchanged from content_v19.js. This extracts the numeric
// tokens from both ES&T documents and reports any that do not appear anywhere
// in v19, so a number altered while rewriting is caught rather than published.
// Tokens that are genuinely new to the ES&T version (section numbers, the
// journal's own limits) are listed in ALLOW with the reason.
const V19 = require("./content_v19.js");
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

const haystack = harvest(V19).join("  ");

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
  console.log(label + ": " + uniq.length + " numeric token(s) not found in content_v19.js");
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
console.log("\nEvery number in the ES&T version appears in content_v19.js.");
