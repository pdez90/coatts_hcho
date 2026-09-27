# Manuscript build (Atmospheric Measurement Techniques)

The paper is written as data and rendered; nothing in the documents is typed
twice. Six files, plus the numbers and tables the pipeline wrote.

| File | Role |
| --- | --- |
| `content_amt.js` | the main text as data: abstract, sections, back matter (data availability, author contributions, ...), the figure files and captions, and the reference entries in Copernicus form |
| `content_amt_si.js` | the supplement the same way: S1-S9, Tables S1-S6 (literal rows), Tables S7-S10 (rendered from CSVs), Figures S1-S13 |
| `numbers.js` | resolves `{{n:key}}` against `output/tables/manuscript_numbers_*.csv` and refuses to build if a key is missing |
| `tables_amt.js` | renders the display tables that come straight from pipeline CSVs: Table 1 (`manuscript_table1.csv`, written by `R/21`), Tables S7-S10 (the step-20 outputs) |
| `build_amt.js` | renders both documents to `../TEMPO_HCHO_AMT_manuscript.docx` and `../TEMPO_HCHO_AMT_supplement.docx`, reading figures from `../../output/figures` |
| `check_amt.js` | verifies that every number in both documents is derived from the pipeline or found in an output table, and that every figure and table is cited and exists |

`build_est.js`, `check_est.js`, `content_est.js` and `content_est_si.js` are the
superseded ES&T (numbered-citation) chain, kept for the record.

To rebuild after re-running the pipeline:

    Rscript R/20_agreement_diagnostics.R     # figures 20-23, tables S7-S10, manuscript_numbers_20.csv
    Rscript R/21_manuscript_tables.R         # Table 1
    cd manuscript/src
    npm install                              # once
    node check_amt.js                        # must end "Every number is derived from the pipeline or verified ..."
    node build_amt.js

## How numbers reach the page

Three routes, and `check_amt.js` treats them differently:

* **derived** - `{{n:key}}` markers, resolved from the `manuscript_numbers_*.csv`
  files each R step writes, and every cell of a table `tables_amt.js` renders
  from a CSV. These cannot be transcribed wrongly; the check does not re-test
  them. All of Sect. 3.6, the abstract's new sentences, Table 1 and Tables S7-S10
  are on this route.
* **verified** - a literal in prose, a caption or Tables S1-S6 must occur, at
  the precision printed, in at least one CSV in `output/tables/`. A decimal that
  matches five or more tables is counted as weakly verified (set
  `HCHO_SHOW_WEAK=1` to list them); the cure is to derive it instead.
* **exempt** - physical constants and procedural counts (2000 permutations,
  the 0.02° grid, ...), each pinned to the sentence that names it.

A marker carries no meaning beyond its value, so a marker in the wrong sentence
renders correctly whenever two values coincide. When reviewing, compare each
marker's **name** against the claim around it. The step-20 markers were placed
by explicit sentence-level substitution for exactly this reason; matching values
within a key family put correct values under wrong keys four times in a trial.

## Citations

References live in `content_amt.js` under `refs`, keyed (`souri2023`), each
with its author-year `label`, the `names` used in a narrative citation, its
`year`, a `sort` key and the Copernicus-format `text`. In the prose:

| Marker | Renders as |
| --- | --- |
| `{{souri2023}}` | ` (Souri et al., 2023)` - adjacent markers share one parenthesis, same first author collapses to `2006, 2008` |
| `{{@souri2023}}` | `Souri et al. (2023)` |
| `{{~souri2023}}` | `Souri et al., 2023` bare, inside a parenthesis the sentence already has |

Each document lists, alphabetically, only what it cites, as Copernicus requires
of a supplement.

## Inline markup

`^{superscript}`, `_{subscript}`, `**bold**`, `[[highlighted note]]`.
Thousands separators are set at render time (thin space from five digits), and
a hyphen before a number becomes a minus sign.

## History

The ES&T chain (`*_est.js`) was regenerated from the edited Word manuscript on
2026-09-22; the AMT chain was regenerated from the reviewed
`TEMPO_HCHO_AMT_v2.docx` on 2026-09-27, when the target journal changed. Drafts
`v4`-`v19` were removed on 2026-09-23 and remain in git history.
