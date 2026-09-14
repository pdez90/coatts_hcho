// mkcontent18.js - content_v17.js -> content_v18.js
//
// Reviewer fixes, all wording:
//  1. The noise-corrected correlations are 0.40, 0.41 and 0.47 at 1x1, 3x3 and
//     5x5. That is an attenuated gradient, not a flat one, so "unchanged",
//     "the same at every block size", "invariance" and "almost entirely" are
//     all too strong. Five places softened, and the numbers put in the text so
//     the reader can judge.
//  2. Sect. 5.1 inferred a mean "across all monitoring days" from a comparison
//     that excludes no-granule days. Narrowed to days with granules.
//  3. Sect. 3.6 said "dividing by the number of valid scans gives the noise of
//     a daily mean", which reads as dividing an SD by n. It is the variance
//     that is divided by n; the reported 4e15 -> 1.2e15 is consistent with that.
//  4. Sect. 4.10 now says in parentheses that the Colorado case-study analysis
//     gives 0.12 on 78 samples, so the deliberate 0.11/0.12 difference survives
//     the removal of the drafting notes.
//  5. The bracketed query asking CDPHE to confirm the 24 h sampling period is dropped:
//     Sect. 2.1 already establishes midnight-to-midnight sampling from the AQS
//     00:00 start and 24 h duration.
const fs = require("fs");
const path = require("path");
const C = require("./content_v17.js");
const S = C.sections;

const ix = t => {
  const i = S.findIndex(s => (s.h1 || s.h2 || "") === t);
  if (i < 0) throw new Error("no section: " + t);
  return i;
};
function sub(head, from, to) {             // replace a fragment, checked
  const s = S[ix(head)];
  let hit = 0;
  s.p = s.p.map(t => { if (t.includes(from)) { hit++; return t.replace(from, to); } return t; });
  if (hit !== 1) throw new Error("expected 1 match in " + head + ", got " + hit + ": " + from.slice(0, 70));
}
function subAbstract(from, to) {
  let hit = 0;
  C.abstract = C.abstract.map(t => { if (t.includes(from)) { hit++; return t.replace(from, to); } return t; });
  if (hit !== 1) throw new Error("expected 1 abstract match, got " + hit + ": " + from.slice(0, 70));
}

// ------------------------------------------------- 1. the block-size claim
// 0.40 / 0.41 / 0.47 at 1x1 / 3x3 / 5x5.
subAbstract(
"and correcting for it leaves the correlation unchanged across block sizes, so averaging appears to help mainly by reducing noise.",
"and after correcting for it the correlations are much more similar across block sizes (0.40-0.47), so averaging appears to help mainly by reducing noise.");

sub("4.8 What limits day-to-day agreement",
"In other words, the improvement from larger averaging blocks (Sect. 4.4) is almost entirely the averaging down of noise, not a gain in representativeness.",
"The block-size gradient is therefore greatly attenuated once the estimated noise is accounted for, which suggests that much of the improvement from larger averaging blocks (Sect. 4.4) is the averaging down of noise rather than a gain in representativeness; the residual rise at 5 × 5 leaves room for a smaller gain in representativeness as well.");

sub("4.9 Agreement across the national network",
"what distinguishes the two is the Colorado noise analysis (Sect. 4.8), in which the noise-corrected correlation is the same at every block size.",
"what distinguishes the two is the Colorado noise analysis (Sect. 4.8), in which the noise-corrected correlations are much more similar across block sizes (0.40-0.47) than the uncorrected ones.");

sub("5.2 Noise and spatial averaging",
"and the noise-corrected correlation is then the same at every block size. That invariance is strong evidence that the improvement with averaging is driven primarily by reduced retrieval noise rather than by improved spatial representativeness.",
"and the noise-corrected correlations are then much more similar across block sizes (0.40, 0.41 and 0.47 for 1 × 1, 3 × 3 and 5 × 5). That attenuation indicates that much of the improvement with averaging reflects reduced retrieval noise rather than improved spatial representativeness, although the residual rise at 5 × 5 leaves room for a smaller representativeness gain.");

sub("6 Conclusions",
"correcting for it leaves the correlation unchanged across block sizes, which indicates that averaging helps mainly by reducing noise rather than by improving spatial representativeness.",
"correcting for it leaves the correlations much more similar across block sizes (0.40-0.47), which indicates that much of the improvement with averaging reflects reduced noise rather than improved spatial representativeness.");

// ------------------------------------------------- 2. Sect. 5.1 inference
sub("5.1 What TEMPO captures at air toxics monitors",
"A surface-HCHO mean calculated only for TEMPO-observable days would therefore exceed the corresponding mean across all monitoring days.",
"A surface-HCHO mean calculated only for TEMPO-observable days would therefore exceed the corresponding mean over days for which TEMPO returned granules.");

// ------------------------------------------------- 3. Sect. 3.6 noise algebra
sub("3.6 Diagnostic tests",
"Dividing by the number of valid scans gives the noise of a daily mean, and comparing it with the variance of the within-month anomalies gives",
"Squaring this quantity gives a single-scan noise variance, and dividing that variance by the number of valid scans estimates the noise variance of the daily mean; comparing it with the variance of the within-month anomalies gives");

// ------------------------------------------------- 4. the 0.11 / 0.12 difference
sub("4.10 Sampling window and time of day across the network",
"The Colorado window beginning at 06:00 MST is the outlier: 0.11 (n = 79, p = 0.35), against 0.40",
"The Colorado window beginning at 06:00 MST is the outlier: 0.11 (n = 79, p = 0.35; the Colorado case study of Sect. 4.6, which assembles its samples independently of the national extraction, gives 0.12 on 78 samples), against 0.40");

// ------------------------------------------------- 5. the CDPHE query
sub("3.1 Screening and temporal matching",
"on the sample date [[confirm the 24 h sampling period with CDPHE]];",
"on the sample date;");

// ------------------------------------------------- 6. notes
C.notes[1] = "Changes from v17: the noise-corrected block-size claim is softened wherever it appeared. The values are 0.40, 0.41 and 0.47 at 1 × 1, 3 × 3 and 5 × 5, which is an attenuated gradient rather than a flat one, so \"unchanged\", \"the same at every block size\", \"invariance\" and \"almost entirely\" are replaced by \"much more similar\" with the numbers given, and the residual rise at 5 × 5 is acknowledged as room for a smaller representativeness gain; the abstract, Sects. 4.8, 4.9, 5.2 and 6 all carried a version of the claim. Sect. 5.1 no longer infers a mean over all monitoring days from a comparison that excludes no-granule days. Sect. 3.6 now says the single-scan noise variance is divided by the number of valid scans, rather than implying an SD divided by n. Sect. 4.10 states in parentheses that the Colorado case study gives 0.12 on 78 samples where the national extraction gives 0.11 on 79, so the deliberate difference is visible once these notes are removed. The bracketed query asking CDPHE to confirm the 24 h sampling period is dropped because Sect. 2.1 already establishes midnight-to-midnight sampling from the AQS 00:00 start and 24 h duration.";

// ------------------------------------------------- write
const out = "// content_v18.js - generated by mkcontent18.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync(path.resolve(__dirname, "content_v18.js"), out);
console.log("abstract words:", C.abstract.join(" ").split(/\s+/).length);
console.log("wrote content_v18.js:", out.length, "chars");
