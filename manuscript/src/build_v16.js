const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, Table, TableRow, TableCell,
  WidthType, BorderStyle, ImageRun, Footer, PageNumber, LineNumberRestartFormat, ShadingType, PageBreak
} = require("docx");
const C = require("./content_v16.js");

const path = require("path");
// portable: the figures and the built .docx are located relative to this file, so
// the same script runs from a clone anywhere. Override with HCHO_FIG / HCHO_DOCX.
const FIG = process.env.HCHO_FIG || path.resolve(__dirname, "../../output/figures") + path.sep;
const FONT = "Times New Roman";
const CONTENT_W = 9026; // A4 with 1-inch margins, DXA

// ---- inline markup: ^{sup} _{sub} [[highlight]] ----
function runs(text, opts = {}) {
  const parts = text.split(/(\^\{[^}]*\}|_\{[^}]*\}|\[\[[^\]]*\]\])/).filter(s => s.length);
  return parts.map(p => {
    if (p.startsWith("^{")) return new TextRun({ text: p.slice(2, -1), superScript: true, ...opts });
    if (p.startsWith("_{")) return new TextRun({ text: p.slice(2, -1), subScript: true, ...opts });
    if (p.startsWith("[[")) return new TextRun({ text: "[" + p.slice(2, -2) + "]", shading: { type: ShadingType.CLEAR, fill: "FFFF00", color: "auto" }, ...opts });
    return new TextRun({ text: p, ...opts });
  });
}
const P = (text, o = {}) => new Paragraph({ children: runs(text, o.run || {}), spacing: { after: 120, line: 300 }, alignment: o.align || AlignmentType.JUSTIFIED, ...(o.para || {}) });
const H1 = t => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(t)], spacing: { before: 240, after: 120 } });
const H2 = t => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)], spacing: { before: 180, after: 100 } });

// read the PNG's real pixel size, so a regenerated figure never comes out distorted
function pngSize(path) {
  const b = fs.readFileSync(path);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

function figure(file, w, h, caption) {
  const px = pngSize(FIG + file);
  if (px.w !== w || px.h !== h) console.warn("  note: " + file + " is " + px.w + "x" + px.h + ", content says " + w + "x" + h);
  let width = 600, height = Math.round(600 * px.h / px.w);
  if (height > 680) { width = Math.round(width * 680 / height); height = 680; }  // keep tall figures on one page
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 60 },
      children: [new ImageRun({ type: "png", data: fs.readFileSync(FIG + file), transformation: { width, height },
        altText: { title: file, description: caption.slice(0, 200), name: file } })] }),
    new Paragraph({ children: runs(caption, { size: 20 }), spacing: { after: 240, line: 260 }, alignment: AlignmentType.JUSTIFIED })
  ];
}

const border = { style: BorderStyle.SINGLE, size: 4, color: "808080" };
function table(caption, header, rows, widths, notes) {
  const total = widths.reduce((a, b) => a + b, 0);
  const cell = (t, i, isHead) => new TableCell({
    width: { size: widths[i], type: WidthType.DXA },
    borders: { top: border, bottom: border, left: border, right: border },
    shading: isHead ? { fill: "E7E6E6", type: ShadingType.CLEAR, color: "auto" } : undefined,
    margins: { top: 40, bottom: 40, left: 80, right: 80 },
    children: [new Paragraph({ children: runs(t, { size: 18, bold: isHead }), alignment: i === 0 ? AlignmentType.LEFT : AlignmentType.CENTER })]
  });
  const out = [
    new Paragraph({ children: runs(caption, { size: 20 }), spacing: { before: 200, after: 80, line: 260 }, alignment: AlignmentType.JUSTIFIED }),
    new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: widths,
      rows: [new TableRow({ tableHeader: true, children: header.map((t, i) => cell(t, i, true)) }),
             ...rows.map(r => new TableRow({ children: r.map((t, i) => cell(t, i, false)) }))] })
  ];
  if (notes) out.push(new Paragraph({ children: runs(notes, { size: 18 }), spacing: { before: 60, after: 240 } }));
  else out.push(new Paragraph({ children: [], spacing: { after: 160 } }));
  return out;
}

// ---- assemble ----
const children = [];

// drafting notes page
children.push(new Paragraph({ children: [new TextRun({ text: "DRAFTING NOTES — remove before submission", bold: true, color: "C00000" })], spacing: { after: 120 } }));
C.notes.forEach(n => children.push(new Paragraph({ children: runs(n, { size: 20 }), bullet: { level: 0 }, spacing: { after: 60 } })));
children.push(new Paragraph({ children: [new PageBreak()] }));

// title page
children.push(new Paragraph({ alignment: AlignmentType.LEFT, spacing: { after: 240 }, children: runs(C.title, { bold: true, size: 32 }) }));
C.authors.forEach(a => children.push(P(a, { align: AlignmentType.LEFT })));
children.push(new Paragraph({ children: [], spacing: { after: 120 } }));

children.push(H1("Abstract"));
C.abstract.forEach(t => children.push(P(t)));
children.push(H2("Short summary (≤ 500 characters, for submission form)"));
children.push(P(C.shortSummary));

for (const s of C.sections) {
  if (s.h1) children.push(H1(s.h1));
  if (s.h2) children.push(H2(s.h2));
  (s.p || []).forEach(t => children.push(P(t, s.align === "left" ? { align: AlignmentType.LEFT } : {})));
  if (s.table) children.push(...table(s.table.caption, s.table.header, s.table.rows, s.table.widths, s.table.notes));
  if (s.fig) children.push(...figure(s.fig.file, s.fig.w, s.fig.h, s.fig.caption));
}

children.push(H1("References"));
C.references.slice().sort((a, b) => a.localeCompare(b, "en", { sensitivity: "base" }))
  .forEach(r => children.push(new Paragraph({ children: runs(r, { size: 22 }), spacing: { after: 100, line: 260 }, indent: { left: 360, hanging: 360 } })));

children.push(new Paragraph({ children: [new PageBreak()] }));
children.push(H1("Supplementary material (move to the Supplement)"));
C.supplement.forEach(f => {
  if (f.tableS) children.push(...table(f.tableS.caption, f.tableS.header, f.tableS.rows, f.tableS.widths, f.tableS.notes));
  else children.push(...figure(f.file, f.w, f.h, f.caption));
});

const doc = new Document({
  creator: "Draft",
  title: C.title.replace(/\^\{|\}|_\{/g, ""),
  styles: {
    default: { document: { run: { font: FONT, size: 24 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 28, bold: true, font: FONT }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 24, bold: true, font: FONT }, paragraph: { spacing: { before: 180, after: 100 }, outlineLevel: 1 } }
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

Packer.toBuffer(doc).then(buf => {
  const out = process.env.HCHO_DOCX ||
    path.resolve(__dirname, "..", "COATTS_TEMPO_HCHO_AMT_draft_v16.docx");
  fs.writeFileSync(out, buf);
  console.log("wrote", out, buf.length);
});
