// build_amt.js - renders the AMT (Copernicus) manuscript and its supplement as
// two .docx files from content_amt.js and content_amt_si.js.
//
// Copernicus style, as against the ES&T build this replaces:
//   * author-year citations. The sources carry {{key}} markers; a run of
//     markers renders as " (Label; Label)", {{@key}} as "Names (year)" in the
//     sentence, {{~key}} as a bare label inside an existing parenthesis.
//   * one alphabetical reference list per document, holding what that document
//     cites; the supplement's list is its own, as Copernicus requires.
//   * no keywords, no graphical abstract; back-matter sections (data and code
//     availability, author contributions, competing interests, ...) before
//     the references.
// Numbers: {{n:key}} markers resolve from output/tables/manuscript_numbers_*.csv
// (numbers.js); Table 1 and Tables S2-S6, S8 and S11 are rendered from pipeline CSVs by
// tables_amt.js. Nothing is hand-numbered.
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, Table, TableRow, TableCell,
  WidthType, BorderStyle, ImageRun, Footer, PageNumber, LineNumberRestartFormat, ShadingType
} = require("docx");
const N = require("./numbers.js");
const T = require("./tables_amt.js");
const C = N.resolve(require("./content_amt.js"));
const SI = N.resolve(require("./content_amt_si.js"));

const FIG = process.env.HCHO_FIG || path.resolve(__dirname, "../../output/figures") + path.sep;
const OUTDIR = process.env.HCHO_OUTDIR || path.resolve(__dirname, "..");
const FONT = "Times New Roman";
const BASE = C.refs;
let REFS = BASE;
// Copernicus letters same-author, same-year references (2026a, 2026b) within one
// reference list. Each document has its own list, so a document that cites only
// one of a pair gets the bare year, in the citation and in the list.
function refsFor(keys) {
  const out = {};
  for (const [k, r] of Object.entries(BASE)) {
    const m = /^(\d{4})[a-z]$/.exec(r.year || "");
    const twin = m && [...keys].some(j => j !== k && BASE[j] && BASE[j].names === r.names && String(BASE[j].year).startsWith(m[1]));
    out[k] = (m && !twin) ? { ...r, year: m[1], label: r.label.replace(r.year, m[1]),
                              text: r.text.replace(new RegExp(r.year + "\\.$"), m[1] + ".") } : r;
  }
  return out;
}

// ---------------------------------------------------------------- text
// Copernicus sets thousands with a thin space from five digits; numbers.js
// writes commas, prose may carry either. One rule, applied at render time.
const thin = s => s.replace(/(\d),(\d{3})(?!\d)/g, "$1\u2009$2")
                   .replace(/(^|[\s(=:;,\u2013])-(?=\d)/g, "$1\u2212");   // minus sign, not hyphen, before a number
const CITE = /\{\{([@~]?)([a-z][A-Za-z0-9_]*)\}\}/g;
function label(k) { if (!(k in REFS)) throw new Error("unknown citation key " + k); return REFS[k].label; }
function cites(text) {
  // narrative and bare forms first, then runs of parenthetical markers
  let out = text.replace(/\{\{@([a-z][A-Za-z0-9_]*)\}\}/g, (m, k) => `${REFS[k].names} (${REFS[k].year})`)
                .replace(/\{\{~([a-z][A-Za-z0-9_]*)\}\}/g, (m, k) => label(k));
  out = out.replace(/(?:\{\{[a-z][A-Za-z0-9_]*\}\})+/g, run => {
    const keys = run.match(/[a-z][A-Za-z0-9_]*/g);
    // collapse same first author: "Millet et al., 2006, 2008"
    const parts = [];
    keys.forEach(k => {
      const last = parts[parts.length - 1];
      if (last && last.names === REFS[k].names) last.years.push(REFS[k].year);
      else parts.push({ names: REFS[k].names, years: [REFS[k].year] });
    });
    return " (" + parts.map(p => `${p.names}, ${p.years.join(", ")}`).join("; ") + ")";
  });
  return out;
}
function keysIn(strings) {
  const s = new Set();
  strings.forEach(t => { if (typeof t !== "string") return; let m; CITE.lastIndex = 0; while ((m = CITE.exec(t)) !== null) s.add(m[2]); });
  return s;
}
function runs(text, opts = {}) {
  const parts = thin(cites(text)).split(/(\^\{[^}]*\}|_\{[^}]*\}|\*\*[^*]+\*\*|\[\[[^\]]*\]\])/).filter(s => s.length);
  return parts.map(p => {
    if (p.startsWith("^{")) return new TextRun({ text: p.slice(2, -1), superScript: true, ...opts });
    if (p.startsWith("_{")) return new TextRun({ text: p.slice(2, -1), subScript: true, ...opts });
    if (p.startsWith("**")) return new TextRun({ text: p.slice(2, -2), bold: true, ...opts });
    if (p.startsWith("[[")) return new TextRun({ text: "[" + p.slice(2, -2) + "]", shading: { type: ShadingType.CLEAR, fill: "FFFF00", color: "auto" }, ...opts });
    return new TextRun({ text: p, ...opts });
  });
}
const P = (text, o = {}) => new Paragraph({ children: runs(text, o.run || {}), spacing: { after: 120, line: 480 }, alignment: o.align || AlignmentType.LEFT });
const H = (t, lvl) => new Paragraph({ heading: [HeadingLevel.HEADING_1, HeadingLevel.HEADING_2, HeadingLevel.HEADING_3][lvl - 1],
                                      children: [new TextRun(t)], spacing: { before: lvl === 1 ? 240 : 180, after: lvl === 1 ? 120 : 100 } });

function pngSize(p) { const b = fs.readFileSync(p); return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) }; }
function figure(file, caption) {
  const full = FIG + file;
  if (!fs.existsSync(full)) throw new Error("figure not found: " + full);
  const px = pngSize(full);
  let width = 600, height = Math.round(600 * px.h / px.w);
  if (height > 680) { width = Math.round(width * 680 / height); height = 680; }
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 60 },
      children: [new ImageRun({ type: "png", data: fs.readFileSync(full), transformation: { width, height },
        altText: { title: file, description: thin(cites(caption)).slice(0, 200), name: file } })] }),
    new Paragraph({ children: runs(caption, { size: 20 }), spacing: { after: 240, line: 260 }, alignment: AlignmentType.LEFT })
  ];
}

const border = { style: BorderStyle.SINGLE, size: 4, color: "808080" };
function table(t) {
  const spec = t.builder ? T.build(t.builder) : t;
  const header = spec.header, rows = spec.rows;
  const widths = spec.widths || header.map(() => Math.floor(9026 / header.length));
  const total = widths.reduce((a, b) => a + b, 0);
  const cell = (txt, i, isHead) => new TableCell({
    width: { size: widths[i], type: WidthType.DXA },
    borders: { top: border, bottom: border, left: border, right: border },
    shading: isHead ? { fill: "E7E6E6", type: ShadingType.CLEAR, color: "auto" } : undefined,
    margins: { top: 40, bottom: 40, left: 80, right: 80 },
    children: [new Paragraph({ children: runs(String(txt), { size: 18, bold: isHead }), alignment: i === 0 ? AlignmentType.LEFT : AlignmentType.CENTER })]
  });
  const out = [
    new Paragraph({ children: runs(t.caption, { size: 20 }), spacing: { before: 200, after: 80, line: 260 }, alignment: AlignmentType.LEFT }),
    new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: widths,
      rows: [new TableRow({ tableHeader: true, children: header.map((x, i) => cell(x, i, true)) }),
             ...rows.map(r => new TableRow({ children: r.map((x, i) => cell(x, i, false)) }))] })
  ];
  out.push(t.notes ? new Paragraph({ children: runs(t.notes, { size: 18 }), spacing: { before: 60, after: 240 } })
                   : new Paragraph({ children: [], spacing: { after: 160 } }));
  return out;
}

function body(sections) {
  const kids = [];
  (sections || []).forEach(s => {
    if (s.h1) kids.push(H(s.h1, 1));
    if (s.h2) kids.push(H(s.h2, 2));
    if (s.h3) kids.push(H(s.h3, 3));
    (s.p || []).forEach(t => kids.push(P(t)));
    if (s.table) kids.push(...table(s.table));
    if (s.fig) kids.push(...figure(s.fig.file, s.fig.caption));
  });
  return kids;
}
// every string a document renders, for citation collection and checks
function strings(doc) {
  const out = [];
  (doc.abstract || []).forEach(t => out.push(t));
  [...(doc.sections || []), ...(doc.backmatter || [])].forEach(s => {
    (s.p || []).forEach(t => out.push(t));
    if (s.table) { out.push(s.table.caption); if (s.table.notes) out.push(s.table.notes);
      if (!s.table.builder) { s.table.header.forEach(t => out.push(t)); s.table.rows.forEach(r => r.forEach(t => out.push(String(t)))); } }
    if (s.fig) out.push(s.fig.caption);
  });
  return out;
}
function refList(keys) {
  return [...keys].sort((a, b) => REFS[a].sort.localeCompare(REFS[b].sort))
    .map(k => new Paragraph({ children: runs(REFS[k].text, { size: 22 }), spacing: { after: 100, line: 260 }, indent: { left: 360, hanging: 360 } }));
}
function makeDoc(children, title) {
  return new Document({
    creator: "Draft", title,
    styles: {
      default: { document: { run: { font: FONT, size: 24 } } },
      paragraphStyles: [
        { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 26, bold: true, font: FONT }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 0 } },
        { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 24, bold: true, italics: true, font: FONT }, paragraph: { spacing: { before: 180, after: 100 }, outlineLevel: 1 } },
        { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 24, italics: true, font: FONT }, paragraph: { spacing: { before: 120, after: 80 }, outlineLevel: 2 } }
      ]
    },
    sections: [{
      properties: { page: { margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } },
                    lineNumbers: { countBy: 1, restart: LineNumberRestartFormat.CONTINUOUS } },
      footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: [PageNumber.CURRENT], size: 20 })] })] }) },
      children
    }]
  });
}

// ---------------------------------------------------------------- checks on the sources
const allKeys = new Set([...keysIn(strings(C)), ...keysIn(strings(SI))]);
const unknown = [...allKeys].filter(k => !(k in REFS));
if (unknown.length) throw new Error("citation keys with no reference: " + unknown.join(", "));
const unused = Object.keys(REFS).filter(k => !allKeys.has(k));
if (unused.length) console.warn("  note: references never cited: " + unused.join(", "));

// ---------------------------------------------------------------- main text
REFS = refsFor(keysIn(strings(C)));
const main = [];
main.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 240 }, children: runs(C.title, { bold: true, size: 30 }) }));
C.authors.forEach(a => main.push(P(a)));
main.push(H("Abstract", 1));
C.abstract.forEach(t => main.push(P(t)));
main.push(...body(C.sections));
main.push(...body(C.backmatter));
main.push(H("References", 1));
main.push(...refList(keysIn(strings(C))));

// ---------------------------------------------------------------- supplement
REFS = refsFor(keysIn(strings(SI)));
const si = [];
si.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 120 }, children: runs("Supplement of", { bold: true, size: 26 }) }));
si.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 240 }, children: runs(SI.title.replace(/^Supplement of\s*/, ""), { bold: true, size: 28 }) }));
SI.authors.forEach(a => si.push(P(a)));
si.push(...body(SI.sections));
si.push(H("References", 1));
si.push(...refList(keysIn(strings(SI))));

// ---------------------------------------------------------------- write
const mainPath = path.join(OUTDIR, "TEMPO_HCHO_AMT_manuscript.docx");
const siPath = path.join(OUTDIR, "TEMPO_HCHO_AMT_supplement.docx");
const words = doc => (doc.sections || []).reduce((n, s) => n + (s.p || []).reduce((m, t) => m + cites(t).trim().split(/\s+/).length, 0), 0);
console.log("references       :", keysIn(strings(C)).size, "in the main text,", keysIn(strings(SI)).size, "in the supplement,", allKeys.size, "distinct");
console.log("abstract words   :", C.abstract.join(" ").trim().split(/\s+/).length);
console.log("main body words  :", words(C));
console.log("display items    :", C.sections.filter(s => s.fig).length, "figures,", C.sections.filter(s => s.table).length, "table(s) in the main text;",
            SI.sections.filter(s => s.fig).length, "figures,", SI.sections.filter(s => s.table).length, "tables in the supplement");
Promise.all([
  Packer.toBuffer(makeDoc(main, C.title)).then(b => { fs.writeFileSync(mainPath, b); console.log("wrote", mainPath, b.length); }),
  Packer.toBuffer(makeDoc(si, SI.title)).then(b => { fs.writeFileSync(siPath, b); console.log("wrote", siPath, b.length); })
]).catch(e => { console.error(e); process.exit(1); });
