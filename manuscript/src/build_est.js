// build_est.js - renders the ES&T main manuscript and its Supporting Information
// as two .docx files from content_est.js and content_est_si.js.
//
// Citations are written in the sources as {{key}} markers. This script numbers
// them by order of first appearance - main text first, then the Supporting
// Information continuing the same sequence, as ES&T requires - and renders them
// as superscript numerals. Nothing is hand-numbered, so inserting a citation
// cannot silently corrupt the order.
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, Table, TableRow, TableCell,
  WidthType, BorderStyle, ImageRun, Footer, PageNumber, LineNumberRestartFormat, ShadingType, PageBreak
} = require("docx");
const N = require("./numbers.js");   // resolves {{n:key}} from the pipeline
const C = N.resolve(require("./content_est.js"));
const SI = N.resolve(require("./content_est_si.js"));

const FIG = process.env.HCHO_FIG || path.resolve(__dirname, "../../output/figures") + path.sep;
const OUTDIR = process.env.HCHO_OUTDIR || path.resolve(__dirname, "..");
const FONT = "Times New Roman";

// ---------------------------------------------------------------- citations
// Walk the content in render order and collect every string, so citation
// numbering follows the order a reader meets them.
function strings(doc) {
  const out = [];
  (doc.abstract || []).forEach(t => out.push(t));
  (doc.sections || []).forEach(s => {
    (s.p || []).forEach(t => out.push(t));
    if (s.table) {
      out.push(s.table.caption);
      s.table.header.forEach(t => out.push(t));
      s.table.rows.forEach(r => r.forEach(t => out.push(t)));
      if (s.table.notes) out.push(s.table.notes);
    }
    if (s.fig) out.push(s.fig.caption);
  });
  return out;
}

const CITE = /\{\{([A-Za-z0-9_]+)\}\}/g;
const order = [];                       // keys, in order of first appearance
const num = {};                         // key -> 1-based number
function register(list) {
  list.forEach(t => {
    if (typeof t !== "string") return;
    let m;
    CITE.lastIndex = 0;
    while ((m = CITE.exec(t)) !== null) {
      if (!(m[1] in num)) { order.push(m[1]); num[m[1]] = order.length; }
    }
  });
}
register(strings(C));
register(strings(SI));

const unknown = order.filter(k => !(k in C.refs));
if (unknown.length) throw new Error("citation keys with no reference: " + unknown.join(", "));
const unused = Object.keys(C.refs).filter(k => !(k in num));
if (unused.length) console.warn("  note: references never cited: " + unused.join(", "));

// collapse runs of adjacent markers into one superscript: {{a}}{{b}} -> ^{1,2}
function cites(text) {
  return text.replace(/(?:\{\{[A-Za-z0-9_]+\}\})+/g, run => {
    const keys = run.match(/[A-Za-z0-9_]+/g);
    return "^{" + keys.map(k => num[k]).join(",") + "}";
  });
}

// ---------------------------------------------------------------- rendering
function runs(text, opts = {}) {
  const parts = cites(text).split(/(\^\{[^}]*\}|_\{[^}]*\}|\[\[[^\]]*\]\])/).filter(s => s.length);
  return parts.map(p => {
    if (p.startsWith("^{")) return new TextRun({ text: p.slice(2, -1), superScript: true, ...opts });
    if (p.startsWith("_{")) return new TextRun({ text: p.slice(2, -1), subScript: true, ...opts });
    if (p.startsWith("[[")) return new TextRun({ text: "[" + p.slice(2, -2) + "]", shading: { type: ShadingType.CLEAR, fill: "FFFF00", color: "auto" }, ...opts });
    return new TextRun({ text: p, ...opts });
  });
}
const P = (text, o = {}) => new Paragraph({ children: runs(text, o.run || {}), spacing: { after: 120, line: 480 }, alignment: o.align || AlignmentType.LEFT, ...(o.para || {}) });
const H1 = t => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(t)], spacing: { before: 240, after: 120 } });
const H2 = t => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)], spacing: { before: 180, after: 100 } });

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
        altText: { title: file, description: caption.slice(0, 200), name: file } })] }),
    new Paragraph({ children: runs(caption, { size: 20 }), spacing: { after: 240, line: 260 }, alignment: AlignmentType.LEFT })
  ];
}

const border = { style: BorderStyle.SINGLE, size: 4, color: "808080" };
function table(t) {
  const total = t.widths.reduce((a, b) => a + b, 0);
  const cell = (txt, i, isHead) => new TableCell({
    width: { size: t.widths[i], type: WidthType.DXA },
    borders: { top: border, bottom: border, left: border, right: border },
    shading: isHead ? { fill: "E7E6E6", type: ShadingType.CLEAR, color: "auto" } : undefined,
    margins: { top: 40, bottom: 40, left: 80, right: 80 },
    children: [new Paragraph({ children: runs(txt, { size: 18, bold: isHead }), alignment: i === 0 ? AlignmentType.LEFT : AlignmentType.CENTER })]
  });
  const out = [
    new Paragraph({ children: runs(t.caption, { size: 20 }), spacing: { before: 200, after: 80, line: 260 }, alignment: AlignmentType.LEFT }),
    new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: t.widths,
      rows: [new TableRow({ tableHeader: true, children: t.header.map((x, i) => cell(x, i, true)) }),
             ...t.rows.map(r => new TableRow({ children: r.map((x, i) => cell(x, i, false)) }))] })
  ];
  out.push(t.notes ? new Paragraph({ children: runs(t.notes, { size: 18 }), spacing: { before: 60, after: 240 } })
                   : new Paragraph({ children: [], spacing: { after: 160 } }));
  return out;
}

function body(doc) {
  const kids = [];
  (doc.sections || []).forEach(s => {
    if (s.h1) kids.push(H1(s.h1));
    if (s.h2) kids.push(H2(s.h2));
    (s.p || []).forEach(t => kids.push(P(t)));
    if (s.table) kids.push(...table(s.table));
    if (s.fig) kids.push(...figure(s.fig.file, s.fig.caption));
  });
  return kids;
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
          run: { size: 24, bold: true, italics: true, font: FONT }, paragraph: { spacing: { before: 180, after: 100 }, outlineLevel: 1 } }
      ]
    },
    sections: [{
      properties: {
        page: { margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } },
        lineNumbers: { countBy: 1, restart: LineNumberRestartFormat.CONTINUOUS }
      },
      footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: [PageNumber.CURRENT], size: 20 })] })] }) },
      children
    }]
  });
}

// ---------------------------------------------------------------- main text
const main = [];
if (C.notes && C.notes.length) {
  main.push(new Paragraph({ children: [new TextRun({ text: "DRAFTING NOTES — remove before submission", bold: true, color: "C00000" })], spacing: { after: 120 } }));
  C.notes.forEach(n => main.push(new Paragraph({ children: runs(n, { size: 20 }), bullet: { level: 0 }, spacing: { after: 60 } })));
  main.push(new Paragraph({ children: [new PageBreak()] }));
}
main.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 240 }, children: runs(C.title, { bold: true, size: 30 }) }));
C.authors.forEach(a => main.push(P(a)));
// TOC graphic: embed it once R/16_toc_graphic.R has produced it, at the 3.25 in
// width ACS specifies, so what the reviewer sees is the size it will be used at.
const tocFile = FIG + "toc_graphic.png";
if (fs.existsSync(tocFile)) {
  const px = pngSize(tocFile);
  const w = Math.round(3.25 * 96), h = Math.round(w * px.h / px.w);
  main.push(new Paragraph({ children: runs("For Table of Contents use only", { size: 20, bold: true }), spacing: { before: 120, after: 60 } }));
  main.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 60 },
    children: [new ImageRun({ type: "png", data: fs.readFileSync(tocFile), transformation: { width: w, height: h },
      altText: { title: "TOC graphic", description: "Day-to-day agreement between TEMPO HCHO columns and surface monitors", name: "toc_graphic.png" } })] }));
  main.push(new Paragraph({ children: runs("Submitted separately as toc_graphic.tiff (300 dpi, 3.25 × 1.75 in).", { size: 18 }), spacing: { after: 200 } }));
} else {
  main.push(new Paragraph({ children: runs(C.tocNote, { size: 20 }), spacing: { after: 200 } }));
}
main.push(H1("Abstract"));
C.abstract.forEach(t => main.push(P(t)));
main.push(P("Keywords: " + C.keywords.join("; ")));
main.push(...body(C));
// The main reference list holds only what the main text cites. Because the main
// text is registered first, those keys occupy 1..N contiguously; references
// first cited in the SI continue the sequence and are listed there instead.
const mainText = strings(C).join("  ");
const mainCited = order.filter(k => mainText.includes("{{" + k + "}}"));
mainCited.forEach((k, i) => {
  if (num[k] !== i + 1) throw new Error("main-text citation numbering is not contiguous at " + k +
    " (expected " + (i + 1) + ", got " + num[k] + ")");
});
main.push(H1("References"));
mainCited.forEach(k => main.push(new Paragraph({
  children: runs(num[k] + ". " + C.refs[k], { size: 22 }),
  spacing: { after: 100, line: 260 }, indent: { left: 360, hanging: 360 }
})));

// ---------------------------------------------------------------- SI
const si = [];
si.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 240 }, children: runs(SI.title, { bold: true, size: 28 }) }));
SI.authors.forEach(a => si.push(P(a)));
si.push(P(SI.contents));
si.push(...body(SI));
si.push(H1("References cited in the Supporting Information"));
const siText = strings(SI).join("  ");
order.filter(k => siText.includes("{{" + k + "}}")).forEach(k => si.push(new Paragraph({
  children: runs(num[k] + ". " + C.refs[k], { size: 22 }),
  spacing: { after: 100, line: 260 }, indent: { left: 360, hanging: 360 }
})));

// ---------------------------------------------------------------- write
const mainPath = path.join(OUTDIR, "COATTS_TEMPO_HCHO_EST_manuscript.docx");
const siPath   = path.join(OUTDIR, "COATTS_TEMPO_HCHO_EST_supporting_information.docx");

function words(doc) {
  let n = 0;
  (doc.sections || []).forEach(s => (s.p || []).forEach(t => {
    n += cites(t).replace(/\[\[[^\]]*\]\]/g, "").trim().split(/\s+/).filter(Boolean).length;
  }));
  return n;
}
const mainCitedCount = mainCited.length;
const abstractWords = C.abstract.join(" ").trim().split(/\s+/).length;
const mainWords = words(C);
const figs = C.sections.filter(s => s.fig).length;
const tabs = C.sections.filter(s => s.table).length;

console.log("citations numbered:", order.length);
console.log("abstract words   :", abstractWords, abstractWords >= 150 && abstractWords <= 200 ? "(within ES&T 150-200)" : "*** OUTSIDE ES&T 150-200 ***");
console.log("main body words  :", mainWords, mainWords <= 7000 ? "(within the 7000-word limit)" : "*** OVER 7000 ***");
console.log("display items    :", figs, "figures +", tabs, "tables =", figs + tabs, figs + tabs <= 4 ? "(within 4)" : "*** OVER 4 ***");
console.log("references       :", mainCitedCount, "in the main text,", order.length, "in total");
console.log("SI               :", SI.sections.filter(s => s.fig).length, "figures,", SI.sections.filter(s => s.table).length, "tables");

Promise.all([
  Packer.toBuffer(makeDoc(main, C.title)).then(b => { fs.writeFileSync(mainPath, b); console.log("wrote", mainPath, b.length); }),
  Packer.toBuffer(makeDoc(si, SI.title)).then(b => { fs.writeFileSync(siPath, b); console.log("wrote", siPath, b.length); })
]).catch(e => { console.error(e); process.exit(1); });
