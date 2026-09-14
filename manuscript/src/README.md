# Manuscript build

`content_v4.js` holds the manuscript text, tables and figure list as data;
`build_v4.js` renders it to `../COATTS_TEMPO_HCHO_AMT_draft_v4.docx` using
docx-js, reading the figures from `../../output/figures`.

`mkcontent4.js` is the diff that produced `content_v4.js` from the v3 content;
it is kept for provenance. `content_v4.js` is the file to edit from here on.

To rebuild after re-running the pipeline:

    cd manuscript/src
    npm install docx          # once
    node build_v4.js

Inline markup in the text: `^{superscript}`, `_{subscript}`, `[[highlight]]`
(rendered as yellow-highlighted square brackets — drafting notes to resolve).
