# Manuscript build

Four files, plus the numbers the pipeline wrote.

| File | Role |
| --- | --- |
| `content_est.js` | the main text as data: abstract, sections, Table 1, the three figures, and the reference list |
| `content_est_si.js` | the Supporting Information, the same way: S1-S8, Tables S1-S6, Figures S1-S11 |
| `numbers.js` | resolves `{{n:key}}` against `output/tables/manuscript_numbers_*.csv`, and formats thousands separators |
| `build_est.js` | renders both to `../COATTS_TEMPO_HCHO_EST_manuscript.docx` and `..._supporting_information.docx`, reading figures from `../../output/figures` |
| `check_est.js` | verifies every number in both documents traces to a pipeline table, and that SI cross-references resolve |

Edit `content_est.js` and `content_est_si.js`. Nothing else holds manuscript
text, and the `.docx` files are build products - they are gitignored and any
edit made in Word is lost on the next build.

To rebuild after re-running the pipeline:

    cd manuscript/src
    npm install          # once
    node build_est.js
    node check_est.js    # should report no unsourced tokens and no dangling cross-references

## Writing numbers

Any quantity the pipeline computes should be written as `{{n:key}}` rather than
typed, so it cannot drift when the pipeline is re-run. `check_est.js` reports a
typed decimal that matches five or more output tables as only weakly verified,
because a number like `0.42` appears in a dozen files and would pass whatever it
was meant to be.

A token carries no meaning beyond its value, so a token placed in the wrong
sentence renders correctly whenever the two values coincide. Four such errors
were found on 2026-09-22 - among them `R^{2}` that had become a citation, and
`{{n:pct_method_bare}},383` standing in for `16,383`. When checking, compare
each token's **name** against the claim around it; comparing values cannot catch
this.

## Inline markup

`^{superscript}`, `_{subscript}`, `{{citekey}}` for a reference (numbered by
order of first appearance across the main text then the SI), `{{n:key}}` for a
pipeline number.

## History

Drafts `v4`-`v19`, including the longer AMT-length version, were removed on
2026-09-23. They remain in git history; `git log --diff-filter=D --name-only`
finds them.
