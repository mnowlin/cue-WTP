# Cues, Partisanship, and Willingness-to-Pay for Energy

Manuscript and reproducible analysis examining how partisan (Trump) and
climate change cues shape the US public's priority for fossil fuels versus
renewables, and their willingness-to-pay (WTP) for each, and whether these
cue effects vary by political identity (liberal Democrats vs. conservative
Republicans).

The data come from a Cloud Research survey experiment (weighted to match US
Census demographics) in which respondents were randomly assigned to a Trump
cue, a climate change cue, or a no-cue control condition. The analysis fits
survey-weighted OLS regressions (`survey` package) and reproduces the
coefficient plots reported in the manuscript.

## Layout

```
cue-WTP.qmd                          Manuscript source (renders to HTML, PDF, DOCX)
_quarto.yaml                         Quarto project config
_output/                             Rendered HTML/PDF/DOCX (tracked in git)
title-metadata.html                  HTML author-metadata partial
custom-reference-doc.docx            Word reference template used for the DOCX output
scripts/
  manuscript-setup.R                 Sourced by the qmd: loads data, builds the
                                       survey design, fits the weighted OLS models,
                                       and builds the tidy/plot-ready objects
  export-cited-refs.R                Pre-render step: trims the master .bib to cited keys
data/
  cueWTPDataWeighted.csv             Survey data with post-stratification weights
lit-review/                          Background literature memo
```

## Reproducing the analysis

Requires R with: `survey`, `dplyr`, `ggplot2`, `broom`.

- **Manuscript:** `quarto render` → outputs to `_output/`
  (HTML, PDF, and DOCX; the DOCX uses `custom-reference-doc.docx`)
- **Models only:** `Rscript scripts/manuscript-setup.R` builds the survey
  design and fits the models without rendering the manuscript.

## Data

`data/cueWTPDataWeighted.csv` — Cloud Research survey responses (N = 3,113),
weighted to match US Census demographics (age, gender, race/ethnicity).
Includes the cue-condition assignment (`trump.cue`, `climate.cue`,
`control`), the outcome variables (`priority.scale`, `wtp.fossil`,
`wtp.renewable`), political-identity indicators (`libDem`, `conRep`), and
controls (`concern.cost`, `age`, `male`, `white`, `edu`, `inc`).

## Notes

- `references.bib` and the local `.csl` are generated at render time by the
  pre-render step (`export-cited-refs.R`) from the master bibliography, so
  they are git-ignored.
- `_output/` **is tracked in git** (unlike most build artifacts) so the
  rendered manuscript is available without re-running R/Quarto. Re-render
  (`quarto render`) after any change to `cue-WTP.qmd` or
  `scripts/manuscript-setup.R` and commit the updated files in `_output/`
  alongside the source change.
- Quarto's freeze cache (`_freeze/`) is enabled (`execute: freeze: auto` in
  `_quarto.yaml`), so code chunks are only re-executed when the qmd or its
  upstream R sources change.
