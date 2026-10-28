# Priorities Versus Payment: Partisan Cues and Public Preferences for Fossil Fuels and Renewables

**Status:** Under peer review.

Manuscript and reproducible analysis examining how partisan (Trump) and
climate change cues shape the US public's priority for fossil fuels versus
renewables, and their willingness-to-pay (WTP) for each, and whether these
cue effects vary by partisanship (Democrats and Republicans, with leaners
assigned to a party, vs. independents).

The data come from a Cloud Research survey experiment (raked to 2023 ACS
demographics and Pew NPORS 2025 party identification) in which respondents were randomly assigned to a Trump
cue, a climate change cue, or a baseline condition (the same argument for
fossil fuels attributed to "some" rather than to President Trump). The analysis fits
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
filters/left-align-tables.lua        Lua filter (DOCX only) that left-aligns table text
LOG.md                               Running session log (newest entry first)
scripts/
  make-dataset.R                     Builds data/cueWTPDataWeighted.csv from the raw
                                       merged survey file: recodes and raking weights
                                       (ACS 2023 demographics + Pew NPORS party ID)
  data-setup.R                       Shared by both documents: loads data, builds the
                                       survey design, and computes descriptive
                                       stats/tables (sample sizes, WTP medians/means,
                                       WTP distribution table)
  manuscript-setup.R                 Sourced by cue-WTP.qmd: fits the main-text models
                                       with no additional controls and builds the
                                       tidy/plot-ready objects; sources
                                       design-checks-setup.R at the end
  design-checks-setup.R              Cue-only (average-effect) models, covariate
                                       balance by condition, minimum detectable
                                       effects for the interactions, censored-normal (Tobit) WTP models,
                                       unweighted versions of the main models, and a
                                       party-only vs. demographic-only weights comparison
  supplemental-demo-setup.R          Sourced by supplemental-materials.qmd: refits the
                                       same models controlling for demographics (age,
                                       male, white, education, income), for the first
                                       robustness check
  supplemental-setup.R               Sourced by supplemental-materials.qmd: refits the
                                       same models controlling for demographics plus
                                       concern about energy cost, for the second
                                       robustness check
  supplemental-cost-interaction-setup.R
                                      Sourced by supplemental-materials.qmd: refits the
                                       same models with concern about energy cost
                                       interacted with the cues and with political
                                       identity (plus demographic controls), for the
                                       third robustness check
  render-anonymous.R                 Renders a blinded copy of cue-WTP.qmd (no author
                                       blocks or Statements and Declarations) to
                                       submission-files/ (NOT in git)
  export-cited-refs.R                Pre-render step: trims the master .bib to cited
                                       keys cited in either .qmd file
data/                                Survey data (NOT in git -- see below)
  merged-all-three.csv               Raw merged survey responses (contains respondent
                                       metadata; never shared)
  cueWTPDataWeighted.csv             Analysis data with raking weights (built by
                                       scripts/make-dataset.R)
literature/                          Background literature memos (NOT in git -- local only)
nowlin-style-profile.md              Author writing-style profile, used to draft prose
                                       in the user's voice (NOT in git -- local only)
```

## Reproducing the analysis

Package versions are managed with `renv` (R 4.6.0; see `renv.lock`). Opening R in the project root activates the project library via `.Rprofile`; run `renv::restore()` once to install the recorded versions. Main packages: `survey` (and `survival`), `dplyr`, `tidyr`, `ggplot2`, `broom`, `marginaleffects`, `modelsummary`, `performance`, `tidyverse`.

- **Analysis dataset:** `Rscript scripts/make-dataset.R` rebuilds
  `data/cueWTPDataWeighted.csv` from `data/merged-all-three.csv`. It pulls ACS
  targets with `tidycensus`, so a Census API key must be set in the
  `CENSUS_API_KEY` environment variable. Raking uses `anesrake`.
- **Manuscript + supplemental materials:** `quarto render` → outputs both
  `cue-WTP` and `supplemental-materials` to `_output/`
  (HTML, PDF, and DOCX; the DOCX uses `custom-reference-doc.docx`)
- **Models only:** `Rscript scripts/manuscript-setup.R` (main-text
  specification, no controls), `Rscript scripts/supplemental-demo-setup.R`
  (demographics-only robustness check), `Rscript scripts/supplemental-setup.R`
  (demographics + cost-concern robustness check), or
  `Rscript scripts/supplemental-cost-interaction-setup.R` (demographics +
  cost-concern interacted with cues/identity robustness check) builds the
  survey design and fits the models without rendering either document. All
  four source `scripts/data-setup.R` first.

## Data

The `data/` folder is **not tracked in git**. Restore it before rendering:

- `data/cueWTPDataWeighted.csv` — Cloud Research survey responses (N = 3,113),
  raked to 2023 ACS margins (age, gender, white non-Hispanic, college degree)
  and Pew NPORS 2025 party identification (leaners assigned to a party).
  Includes the cue-condition assignment (`trump.cue`, `climate.cue`,
  `control`), the outcome variables (`priority.scale`, `wtp.fossil`,
  `wtp.renewable`), party indicators (`democrat`, `republican`; leaners
  included), and
  controls (`concern.cost`, `age`, `male`, `white`, `edu`, `inc`).

## Notes

- The main text (`cue-WTP.qmd`) uses no additional controls. Three robustness
  checks are reported in `supplemental-materials.qmd`: one adding demographic
  controls (age, male, white, education, income), one adding those
  demographics plus concern about the cost of electricity (`concern.cost`),
  and one further interacting `concern.cost` with the cues and with political
  identity; the main-text cue x political-identity effects are consistent
  across all four specifications. Concern about energy cost itself has a
  significant, partisanship- and (for fossil-fuel WTP amount) cue-moderated
  relationship with fossil-fuel outcomes, but not with renewable WTP.
- The supplement also reports covariate balance by condition, cue-only
  (average-effect) models, minimum detectable
  effects for the cue x identity interactions, Tobit models of WTP for both
  sources (censored at $0 and $46), unweighted models, and a comparison of
  party-only and demographic-only weights (the weight-sensitive interactions
  depend on the demographic weights; party weights leave them unchanged). Party ID was
  asked after the outcomes; leaners are coded as partisans, and pure
  independents are the reference group.
- Regression tables report **Adj. R2** for the OLS (gaussian) models and
  **McFadden's pseudo R2** for the logit (fossil-participation) model, as
  separate labeled rows, via a `glance_custom.svyglm()` method in
  `scripts/data-setup.R` (modelsummary's default single "R2" row would
  otherwise conflate the two, unlabeled).
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
