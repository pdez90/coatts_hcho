// mkcontent6.js - content_v5.js -> content_v6.js, second review pass
// 1. drop "mattered more than its length" (duration and hour are not independently varied)
// 2. "governed by" -> partial explanation, in the abstract
// 3. "direct evidence" -> "strong evidence ... primarily"
// 4. remaining declarative Front Range meteorology -> an interpretation
// 5. "must lie with representativeness or vertical structure" -> additional factors must contribute
// 6. significance counts demoted so no claim rests on them; the fixed-effects regression
//    carries the inferential weight instead
// 7. "hours in which the sampled air is well mixed" -> empirical surface-column correspondence
const fs = require("fs");
const C = require("./content_v5.js");
const S = C.sections;

const byHead = (t) => {
  const i = S.findIndex(s => (s.h1 || s.h2 || "") === t);
  if (i < 0) throw new Error("no section: " + t);
  return i;
};
function sub(head, from, to) {
  const s = S[byHead(head)];
  let hit = 0;
  s.p = s.p.map(t => { if (t.includes(from)) { hit++; return t.replace(from, to); } return t; });
  if (!hit) throw new Error("not found in " + head + ": " + from.slice(0, 70));
}
const setP = (head, ps) => { S[byHead(head)].p = ps; };

// ---------------------------------------------------------------- 1 + 2: abstract
C.abstract[3] = C.abstract[3].replace(
"The hour at which a sample is collected mattered more than its length.",
"For sub-daily samples, the hour at which sampling occurred materially affected agreement, among samples of the same duration."
);
C.abstract[3] = C.abstract[3].replace(
"TEMPO captures the seasonal cycle and regional episodes seen by surface air toxics monitors across the country; its day-to-day skill at an individual monitor is moderate, strongly site dependent, and governed by retrieval noise and by when the satellite looks relative to when the air was sampled.",
"TEMPO captures the seasonal cycle and regional episodes seen by surface air toxics monitors across the country; its day-to-day skill at individual monitors is moderate and strongly site dependent. Retrieval noise explains part of that variation, and the sub-daily observations show that temporal matching can also matter substantially, but we do not account for the full spread between monitors."
);

// ---------------------------------------------------------------- 6: counts demoted in 4.9
sub("4.9 Agreement across the national network",
"Agreement is significant at most individual sites but far from uniform (Fig. 9). Of 141 site–duration combinations with at least 10 matched samples, 122 had a positive correlation significant at a nominal p < 0.05, and 121 survive a Benjamini-Hochberg correction across the 141 tests; for the day-to-day correlations the counts are 103 and 102. The counts are robust to the correction, but the distribution is the more informative quantity. At the 97 sites",
"Agreement is positive at most individual sites but far from uniform (Fig. 9), and it is the distribution rather than any count of significant sites that carries the result. At the 97 sites");

sub("4.9 Agreement across the national network",
"Colorado's six 24 h AQS sites had a median day-to-day correlation of 0.35, below the national median of 0.48 and below the medians for Iowa (0.59), Michigan (0.59), Pennsylvania (0.54) and California (0.40), and above New York (0.33).",
"Colorado's six 24 h AQS sites had a median day-to-day correlation of 0.35, below the national median of 0.48 and below the medians for Iowa (0.59), Michigan (0.59), Pennsylvania (0.54) and California (0.40), and above New York (0.33). For reference, 122 of the 141 site–duration correlations reach a nominal p < 0.05 and 121 survive a Benjamini-Hochberg correction across the family; for the day-to-day correlations the counts are 103 and 102 (Table S1). We report these for completeness and rest nothing on them: the anomaly p-values do not account for the degrees of freedom spent on the site-month means (Sect. 3.3), so they are optimistic in a way no multiplicity correction repairs. The pooled regression with site and calendar-month fixed effects, which does not have that defect, is the inferential statement we rely on.");

// ---------------------------------------------------------------- 3 + 5: section 5.2
sub("5.2 Noise and spatial averaging",
"That invariance is the direct evidence that averaging helps by reducing noise rather than by capturing a more representative area.",
"That invariance is strong evidence that the improvement with averaging is driven primarily by reduced retrieval noise rather than by improved spatial representativeness.");

sub("5.2 Noise and spatial averaging",
"Where agreement stays far below the noise ceiling, as at Grand Junction, the explanation must lie with the monitor's representativeness or with the vertical structure above it rather than with retrieval noise; neither terrain inside the block nor a winter effect accounts for it, and identifying what does would need meteorological analysis beyond this study.",
"Where agreement stays far below the noise ceiling, as at Grand Junction, factors beyond random retrieval noise must contribute — spatial representativeness, vertical structure, retrieval biases that persist through a day, or error in the surface measurement are all candidates, and our diagnostic cannot separate them. Neither terrain inside the block nor a winter effect accounts for it, and identifying what does would need analysis beyond this study.");

// ---------------------------------------------------------------- 4: section 5.4 meteorology
sub("5.4 Sampling time, mixing, and why the lag that matters is site dependent",
"On the Front Range between 06:00 and 09:00 the surface layer is shallow, so a surface sample reflects overnight accumulation in a thin layer while the column at that hour is dominated by the residual layer and the free troposphere; by 09:00–12:00 the median TEMPO boundary layer height has tripled and agreement is at its strongest; by 12:00–15:00, with the mixed layer deeper still, agreement is lost again, which photochemical production, entrainment and horizontal transport could each explain.",
"One possible reading of the Colorado result is that Front Range sites experience a shallow surface layer in the early morning, so that a 06:00–09:00 sample reflects near-surface accumulation while a larger fraction of the column lies above it; that by 09:00–12:00, when the median modelled boundary layer height has tripled and agreement is at its strongest, more of the column is coupled to the surface; and that by 12:00–15:00 agreement is lost again, which photochemical production, entrainment and horizontal transport could each explain.");

// ---------------------------------------------------------------- 1 + 7: conclusions
sub("6 Conclusions",
"The hour at which a sample is collected matters more than its length or the precision of the match.",
"For sub-daily samples, the hour at which sampling occurs materially affects agreement, among samples of the same duration.");

sub("6 Conclusions",
"and when the satellite is matched to the hours in which the sampled air is well mixed. Which of those conditions hold, and which matching window is best, are now questions that can be answered monitor by monitor rather than assumed from a network average.",
"and when satellite observations are matched to the periods of the day in which surface–column correspondence is strongest — plausibly, though not demonstrably here, after sufficient boundary layer development. Which of those conditions hold, and which matching window is best, are now questions that can be answered monitor by monitor rather than assumed from a network average.");

// also in 5.7, the same formulation
sub("5.7 Implications for air toxics monitoring and limitations",
"Pairing satellite observations with time-resolved surface samples, recording sampling start and end times, and preferring midday sampling windows where the science allows would all make better use of hourly retrievals.",
"Pairing satellite observations with time-resolved surface samples, recording sampling start and end times, and — where the science allows — preferring midday sampling windows would all make better use of hourly retrievals.");

// ---------------------------------------------------------------- Table S1 for the demoted counts
{
  const i = byHead("4.10 Sampling window and time of day across the network");
  C.supplement.unshift({ tableS: {
    caption: "Table S1. Site-level correlations reaching nominal and false-discovery-rate significance, by sample duration. Counts are over site–duration combinations with at least 10 matched samples, at the primary screening and with scans inside the sampling window. The Benjamini-Hochberg correction is applied across all 141 tests in each family. These counts are reported for completeness; the anomaly p-values are optimistic (Sect. 3.3) and no conclusion in the paper depends on them.",
    header: ["Duration", "Sites", "Whole period, p < 0.05", "Whole period, BH q < 0.05", "Day-to-day, p < 0.05", "Day-to-day, BH q < 0.05"],
    widths: [1300, 900, 1700, 1800, 1600, 1726],
    rows: [
      ["24 h", "97", "85", "84", "67", "66"],
      ["8 h", "40", "34", "34", "34", "34"],
      ["3 h", "4", "3", "3", "2", "2"],
      ["All", "141", "122", "121", "103", "102"]
    ]
  }});
  void i;
}

// ---------------------------------------------------------------- notes
C.notes[1] = "Changes from v5, all in response to the second review pass: \"the hour a sample is collected mattered more than its length\" removed from the abstract and Conclusions, since duration and time of day are not varied independently across a common set of sites - the claim is now confined to time of day among samples of the same duration; \"governed by retrieval noise and by when the satellite looks\" replaced with a partial-explanation formulation that states we do not account for the full spread between monitors; \"direct evidence\" softened to \"strong evidence ... driven primarily by\" (Sect. 5.2); the remaining declarative Front Range meteorology in Sect. 5.4 rewritten as one possible reading; \"the explanation must lie with representativeness or vertical structure\" replaced with a list of candidate factors the diagnostic cannot separate (Sect. 5.2); the site-level significance counts moved out of the result sentence into a closing note and a new Table S1, with an explicit statement that nothing rests on them and that the fixed-effects regression carries the inference; and \"the hours in which the sampled air is well mixed\" replaced with an empirical surface-column-correspondence formulation (Conclusions).";
C.notes[0] = "Numbers come from the pipeline runs of 11-14 September 2026, analysis code at commit 7ce487a (github.com/pdez90/coatts_hcho). The Benjamini-Hochberg counts in Table S1 are printed by R/13_national_analysis.R and were confirmed against the run of 13 September 2026. Later commits change manuscript text only and no number.";

const out = "// content_v6.js - generated by mkcontent6.js; do not edit by hand\n" +
  "module.exports = " + JSON.stringify(C, null, 1) + ";\n";
fs.writeFileSync("content_v6.js", out);
console.log("wrote content_v6.js:", out.length, "chars");
