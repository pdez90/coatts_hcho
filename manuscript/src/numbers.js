// numbers.js - resolve {{n:key}} markers from numbers the pipeline computed.
//
// A statistic quoted in the manuscript should be the one the analysis produced,
// not a transcription of it. Transcription is how "12 %" came to appear in the
// abstract, the Results and a figure caption when the pipeline had computed 14:
// the value had been worked out by hand with state medians where the code used
// state means, and nothing could tell the two apart afterwards.
//
// The R steps write output/tables/manuscript_numbers_*.csv as key,value,source.
// The sources write {{n:key}}. This resolves them, and refuses to resolve a key
// nothing produced rather than leaving a marker in a submitted document.
const fs = require("fs");
const path = require("path");

const TABLE_DIR = process.env.HCHO_TABLES ||
  path.resolve(__dirname, "../../output/tables");

function load() {
  const map = new Map();
  let files = [];
  try {
    files = fs.readdirSync(TABLE_DIR).filter(f => /^manuscript_numbers.*\.csv$/.test(f));
  } catch (e) { return map; }
  for (const f of files) {
    const lines = fs.readFileSync(path.join(TABLE_DIR, f), "utf8").trim().split(/\r?\n/);
    const head = lines.shift().split(",").map(s => s.trim().replace(/^"|"$/g, ""));
    const ki = head.indexOf("key"), vi = head.indexOf("value");
    if (ki < 0 || vi < 0) continue;
    for (const ln of lines) {
      const cells = ln.split(",").map(s => s.trim().replace(/^"|"$/g, ""));
      // A key whose value is NA, NaN, Inf or empty is not a number the text
      // may quote: leave it out, so the marker stays unresolved and the build
      // refuses, instead of printing "NA" into the manuscript.
      if (cells[ki] && cells[vi] !== undefined &&
          !/^(NA|NaN|-?Inf|)$/.test(cells[vi].trim())) map.set(cells[ki], cells[vi]);
    }
  }
  return map;
}

const MARK = /\{\{n:([A-Za-z0-9_]+)\}\}/g;

// Deep-walk a content object, substituting in every string.
function resolve(doc, opts) {
  const map = (opts && opts.map) || load();
  const missing = new Set();
  // ES&T style: a comma every three digits from five digits up; four-digit
// integers take no separator. The pipeline writes some counts with a space
// separator and some bare, so normalise here rather than in the R step.
function thousands(v) {
  const t = String(v).replace(/[\u0020\u2009\u00a0](?=\d{3}\b)/g, "");
  if (!/^-?\d+$/.test(t)) return v;
  const digits = t.replace("-", "");
  if (digits.length < 5) return t;
  return t.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

const sub = s => s.replace(MARK, (m, k) => {
    if (map.has(k)) return thousands(map.get(k));
    missing.add(k);
    return m;
  });
  const walk = x => {
    if (typeof x === "string") return sub(x);
    if (Array.isArray(x)) return x.map(walk);
    if (x && typeof x === "object") {
      const o = {};
      for (const k of Object.keys(x)) o[k] = walk(x[k]);
      return o;
    }
    return x;
  };
  const out = walk(doc);
  if (missing.size && !(opts && opts.quiet)) {
    console.error("  UNRESOLVED {{n:...}} markers: " + [...missing].join(", ") +
                  "\n  (no manuscript_numbers_*.csv in " + TABLE_DIR + " defines them; " +
                  "re-run the pipeline, or fix the key)");
    if (!(opts && opts.soft)) process.exitCode = 1;
  }
  return out;
}

module.exports = { load, resolve, TABLE_DIR };
