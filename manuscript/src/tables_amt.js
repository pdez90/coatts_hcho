// tables_amt.js - display tables rendered from pipeline CSVs, by name.
//
// A table cell that is typed can be typed wrongly; one that is read from the
// CSV the analysis wrote cannot differ from it. Each builder returns
// { header, rows, widths?, align? } for build_amt.js, and check_amt.js treats
// every number these produce as derived rather than transcribed.
const fs = require("fs");
const path = require("path");
const TABLE_DIR = process.env.HCHO_TABLES || path.resolve(__dirname, "../../output/tables");

function csv(name) {
  const text = fs.readFileSync(path.join(TABLE_DIR, name), "utf8").replace(/^﻿/, "");
  const rows = [];
  let row = [], cell = "", q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (c === '"') q = false;
      else cell += c;
    } else if (c === '"') q = true;
    else if (c === ",") { row.push(cell); cell = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(cell); rows.push(row); row = []; cell = "";
    } else cell += c;
  }
  if (cell.length || row.length) { row.push(cell); rows.push(row); }
  const head = rows.shift();
  return rows.filter(r => r.length === head.length && r.some(x => x !== ""))
             .map(r => Object.fromEntries(head.map((h, i) => [h, r[i]])));
}
const num = v => (v === "" || v === "NA" || v === undefined) ? NaN : Number(v);
const f0 = v => Number.isFinite(num(v)) ? num(v).toFixed(0) : "–";
const f2 = v => Number.isFinite(num(v)) ? num(v).toFixed(2) : "–";
const f3 = v => Number.isFinite(num(v)) ? num(v).toFixed(3) : "–";
const sgn = (v, d) => Number.isFinite(num(v)) ? (num(v) >= 0 ? "+" : "") + num(v).toFixed(d) : "–";
// minus signs and en dashes as Copernicus sets them
const typo = s => String(s).replace(/(^|[\s(=:,])-(?=\d)/g, "$1−").replace(/(\d)-(\d)/g, "$1–$2");

const builders = {
  // Table 1: written cell by cell by R/21_manuscript_tables.R
  table1() {
    const rows = csv("manuscript_table1.csv");
    return { header: ["", "24 h", "8 h", "3 h"],
             rows: rows.map(r => [r.row_label, r["24 h"], r["8 h"], r["3 h"]]),
             widths: [3400, 1875, 1875, 1876] };
  },
  // Table S7: the dual-duration monitors (R/20, diag7_dual_duration_sites.csv)
  dualDurationSites() {
    const rows = csv("diag7_dual_duration_sites.csv").sort((a, b) => (a.state + a.site).localeCompare(b.state + b.site));
    return {
      header: ["Site (state)", "AQS ID", "n_{24h}", "r_{24h}", "n_{8h}", "r_{8h}", "r_{8h} 04:00", "r_{8h} 12:00",
               "r_{24h} vs 04–12 column", "r_{24h} vs 12–20 column", "usable % 24 h / 8 h", "scans 24 h / 8 h"],
      rows: rows.map(r => [`${r.site_name} (${r.state})`, r.site, f0(r.anom_n_24h), typo(f2(r.anom_r_24h)), f0(r.anom_n_8h), typo(f2(r.anom_r_8h)),
                           typo(f2(r.r_8h_start4)), typo(f2(r.r_8h_start12)), typo(f2(r.r_24h_col_start4)), typo(f2(r.r_24h_col_start12)),
                           `${f0(r.usable_pct_24h)} / ${f0(r.usable_pct_8h)}`, `${f0(r.median_valid_scans_24h)} / ${f0(r.median_valid_scans_8h)}`]),
      widths: [1700, 900, 500, 550, 500, 550, 650, 650, 800, 800, 800, 750]
    };
  },
  // Table S8: the weighted Fisher-z models (R/20, diag8_ceiling_gap_models.csv)
  ceilingGapModels() {
    const rows = csv("diag8_ceiling_gap_models.csv");
    const labels = { "(Intercept)": "Intercept", log_surface: "log median surface HCHO", log_snr: "log signal-to-noise ratio",
                     log_scans: "log median valid scans", usable_pct: "usable share", pbl_hrrr_km: "HRRR mixing depth", smoke_share: "smoke-affected share" };
    const models = [...new Set(rows.map(r => r.model))];
    const out = [];
    for (const term of Object.keys(labels)) {
      out.push([labels[term], ...models.map(m => {
        const x = rows.find(r => r.model === m && r.term === term);
        return x ? typo(`${sgn(x.estimate_per_sd, 3)} (${f3(x.se)}), p = ${f3(x.p)}`) : "–";
      })]);
    }
    out.push(["R^{2} (adjusted)", ...models.map(m => { const x = rows.find(r => r.model === m); return `${f2(x.r2)} (${f2(x.adj_r2)})`; })]);
    out.push(["Sites", ...models.map(m => f0(rows.find(r => r.model === m).n_sites))]);
    return { header: ["Term (per SD)", "M1: z(r_{obs}), six descriptors", "M2: z(E), six descriptors", "M3: z(E), without the noise terms"],
             rows: out, widths: [2300, 2250, 2250, 2250] };
  },
  // Table S9: mixing-depth tertiles and interaction models (R/20, diag10_*.csv)
  pblTertiles() {
    const te = csv("diag10_pbl_tertiles.csv"), it = csv("diag10_pbl_interaction.csv");
    const strat = { "absolute HRRR mixing depth": "absolute", "mixing depth relative to site-month": "relative to site-month",
                    "relative to site-month, smoke-free days only": "relative, smoke-free days" };
    const out = [];
    for (const s of ["8 h, start 04:00 LST", "8 h, start 12:00 LST", "24 h"]) {
      for (const [st, sl] of Object.entries(strat)) {
        const d = te.filter(r => r.sample === s && r.stratification === st).sort((a, b) => num(a.tert) - num(b.tert));
        if (!d.length) continue;
        out.push([s, sl, d.map(r => f0(r.n)).join(" / "), d.map(r => f2(r.pbl_median_km)).join(" / "),
                  typo(d.map(r => f2(r.r)).join(" / ")), d.map(r => f2(r.sd_column_anom_1e15)).join(" / "),
                  typo(`${f2(d[0].diff_top_minus_bottom)} (${f2(d[0].diff_ci_lo)}, ${f2(d[0].diff_ci_hi)})`)]);
      }
      for (const [m, ml] of [["mixing depth only", "interaction, mixing depth only"],
                             ["mixing depth, with valid-scan count and column level as competing moderators", "interaction, adjusted"]]) {
        const x = it.find(r => r.sample === s && r.model === m && r.term === "col_std:pbl_std");
        out.push([s, ml, `${f0(x.n)} (${f0(x.n_sites)} sites)`, "", "", "", typo(`${sgn(x.estimate, 3)} (SE ${f3(x.se_cluster)}), p = ${f3(x.p)}`)]);
      }
    }
    return { header: ["Samples", "Stratification", "n (shallow / middle / deep)", "median mixing depth, km", "anomaly r",
                      "SD of column anomaly, 10^{15} molecules cm^{−2}", "deep minus shallow (95% CI) or interaction"],
             rows: out, widths: [1300, 1600, 1250, 1150, 1100, 1250, 1400] };
  },
  // Table S10: the temporal-averaging curve (R/20, diag9_*.csv)
  temporalAveraging() {
    const ta = csv("diag9_temporal_averaging.csv"), nf = csv("diag9_temporal_averaging_noise.csv");
    const out = [];
    for (const b of ["1x1", "3x3", "5x5"]) {
      for (const k of ["1", "2", "3", "4", "all"]) {
        const x = ta.find(r => r.block === b && r.k_scans === k);
        const rng = k !== "all" ? ` (${f2(x.r_pooled_lo)}, ${f2(x.r_pooled_hi)})` : "";
        out.push([b.replace("x", " × "), k !== "all" ? k : `all (median ${f0(x.median_valid_scans_all)})`,
                  `${f2(x.r_pooled)}${rng}`, f2(x.median_site_r), f2(x.sd_column_anom_1e15)]);
      }
      const y = nf.find(r => r.block === b);
      out.push([b.replace("x", " × "), "noise from var(1/k)", "", "", `${f2(y.single_scan_noise_sd_1e15)} (single scan)`]);
    }
    return { header: ["Block", "Scans averaged", "pooled anomaly r (2.5–97.5% of draws)", "median site r", "SD of column anomaly, 10^{15} molecules cm^{−2}"],
             rows: out, widths: [900, 1700, 2400, 1500, 2500] };
  }
};

function build(name) {
  if (!builders[name]) throw new Error("no table builder named " + name);
  return builders[name]();
}
module.exports = { build, csv, TABLE_DIR, names: Object.keys(builders) };
