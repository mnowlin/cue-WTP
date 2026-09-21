# Cues, Partisanship, and Willingness-to-Pay for Energy

Manuscript and reproducible analysis examining how partisan (Trump) and
climate change cues shape the US public's priority for fossil fuels versus
renewables, and their willingness-to-pay (WTP) for each, and whether these
cue effects vary by political identity (liberal Democrats vs. conservative
Republicans).

The data come from a Cloud Research survey experiment (weighted to match US
Census demographics) in which respondents were randomly assigned to a Trump
cue, a climate change cue, or a no-cue control condition. The analysis fits
survey-weighted regressions (`survey` package) and reproduces the regression
tables and predicted-value plots reported in the manuscript.

## Layout

```
cue-WTP.qmd                          Main manuscript (renders to HTML, PDF, DOCX)
supplemental-materials.qmd           Robustness-check appendix (renders to HTML, PDF, DOCX)
_quarto.yaml                         Quarto project config (renders both .qmd files)
_output/                             Rendered HTML/PDF/DOCX (tracked in git)
title-metadata.html                  HTML author-metadata partial
custom-reference-doc.docx            Word reference template used for the DOCX output
LOG.md                               Running session log (newest entry first)
scripts/
  data-setup.R                       Shared by both documents: loads data, builds the
                                       survey design, and computes descriptive
                                       stats/tables (sample sizes, WTP medians/means,
                                       WTP distribution table)
  manuscript-setup.R                 Sourced by cue-WTP.qmd: fits the main-text models
                                       with no additional controls and builds the
                                       tidy/plot-ready objects
  supplemental-demo-setup.R          Sourced by supplemental-materials.qmd: refits the
                                       same models controlling for demographics (age,
                                       male, white, education, income), for the first
                                       robustness check
  supplemental-setup.R               Sourced by supplemental-materials.qmd: refits the
                                       same models controlling for demographics plus
                                       concern about energy cost, for the second
                                       robustness check
  export-cited-refs.R                Pre-render step: trims the master .bib to cited
                                       keys cited in either .qmd file
data/                                Survey data (NOT in git -- see below)
  cueWTPDataWeighted.csv             Survey data with post-stratification weights
literature/                          Background literature memos (NOT in git -- local only)
nowlin-style-profile.md              Author writing-style profile, used to draft prose
                                       in the user's voice (NOT in git -- local only)
```

## Reproducing the analysis

Requires R with: `survey`, `dplyr`, `tidyr`, `ggplot2`, `broom`, `marginaleffects`, `modelsummary`.

- **Manuscript + supplemental materials:** `quarto render` → outputs both
  `cue-WTP` and `supplemental-materials` to `_output/`
  (HTML, PDF, and DOCX; the DOCX uses `custom-reference-doc.docx`)
- **Models only:** `Rscript scripts/manuscript-setup.R` (main-text
  specification, no controls), `Rscript scripts/supplemental-demo-setup.R`
  (demographics-only robustness check), or `Rscript scripts/supplemental-setup.R`
  (demographics + cost-concern robustness check) builds the survey design and
  fits the models without rendering either document. All three source
  `scripts/data-setup.R` first.

## Data

The `data/` folder is **not tracked in git**. Restore it before rendering:

- `data/cueWTPDataWeighted.csv` — Cloud Research survey responses (N = 3,113),
  weighted to match US Census demographics (age, gender, race/ethnicity).
  Includes the cue-condition assignment (`trump.cue`, `climate.cue`,
  `control`), the outcome variables (`priority.scale`, `wtp.fossil`,
  `wtp.renewable`), political-identity indicators (`libDem`, `conRep`), and
  controls (`concern.cost`, `age`, `male`, `white`, `edu`, `inc`).

## Notes

- The main text (`cue-WTP.qmd`) uses no additional controls. Two robustness
  checks are reported in `supplemental-materials.qmd`: one adding demographic
  controls (age, male, white, education, income), and one adding those
  demographics plus concern about the cost of electricity (`concern.cost`);
  results are consistent across all three specifications.
- `references.bib` and the local `.csl` are generated at render time by the
  pre-render step (`export-cited-refs.R`) from the master bibliography, so
  they are git-ignored.
- `_output/` **is tracked in git** (unlike most build artifacts) so the
  rendered manuscript is available without re-running R/Quarto. Re-render
  (`quarto render`) after any change to either `.qmd` file or the `scripts/`
  R sources, and commit the updated files in `_output/` alongside the
  source change.
- Quarto's freeze cache (`_freeze/`) is enabled (`execute: freeze: auto` in
  `_quarto.yaml`), so code chunks are only re-executed when a qmd or its
  upstream R sources change.
- `literature/` and `nowlin-style-profile.md` are git-ignored (kept local
  only).
- `LOG.md` records what changed and why for each work session; add a new
  entry at the top rather than editing manuscript prose notes into commit
  messages.
