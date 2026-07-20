# Session Log — cue-WTP Project

Paper title: **"Cues, Partisanship, and Willingness-to-Pay for Energy"**

This log records what has been done in each working session. Update it at the end of each session.

---

## Project Overview

A survey experiment examining how a Trump cue and a climate change cue affect the US public's priority for fossil fuels vs. renewables and their willingness-to-pay (WTP) for each, and whether these cue effects vary by political identity (liberal Democrats vs. conservative Republicans). Data from Cloud Research, weighted to match US Census demographics (age, gender, race/ethnicity).

**Key files:**
- `cue-WTP.qmd` — main manuscript (renders to HTML, PDF, DOCX)
- `scripts/manuscript-setup.R` — data loading, survey design, model fitting, and tidy/plot-ready objects sourced by the manuscript
- `scripts/export-cited-refs.R` — pre-render step that trims the master `.bib` to cited keys
- `data/cueWTPDataWeighted.csv` — weighted survey data (N = 3,113)
- `README.md` — project structure and reproduction instructions

---

## Session History

### Session 1 — 2026-07-15 (Initial analysis, manuscript setup, README)
**Commits:** none yet (repo has no commits as of session end)

- Reviewed `cue-WTP.qmd`'s hypothesis notes and confirmed the intended model specs with the user (cue × political-identity interaction structure for the WTP models; simple weighted `svydesign` with no clustering/strata).
- Built `scripts/manuscript-setup.R`: loads `data/cueWTPDataWeighted.csv`, constructs a `svydesign(ids = ~1, weights = ~weight)`, and originally fit five models — a one-way ANOVA (`priority.scale ~ cue.condition`), an OLS interaction model (`priority.scale ~ cues * political identity`), weighted mean/t-test comparisons of WTP by cue condition, a cue-only WTP model, and a cue × political-identity WTP model.
- Added executable code chunks with captions to `cue-WTP.qmd` (tables via `knitr::kable()`, coefficient plots via `ggplot2`, using `broom::tidy()` on the `svyglm` objects).
- Fixed three pre-existing project issues blocking render: a `NULL`-write bug in `export-cited-refs.R` when no citations exist yet, a missing `\usepackage{ulem}` for the PDF's `\normalem` command, and missing `title-metadata.html`/`custom-reference-doc.docx` template files (copied from the `cc-behave` project per user's choice). Added `execute: echo: false` / `warning: false` to `_quarto.yaml` so R source code doesn't print in the rendered manuscript.
- Iterated per user edits to `cue-WTP.qmd`:
  - Added `concern.cost`, `age`, `male`, `white`, `edu`, and `inc` as controls to the `priority.scale` and WTP interaction models, filtered out of the coefficient plots and tidy tables.
  - Removed the ANOVA table, the in-text WTP mean/t-test paragraph, and the cue-only WTP figure — dropped the corresponding now-unused objects (`m_anova`, `anova_test`, `wtp_means`, `svyttest` calls, `m_wtp_fossil_cue`/`m_wtp_renewable_cue`, `cue.condition`/`pol.group` factors) from `manuscript-setup.R`.
  - Replaced full coefficient tables with bullet lists of terms significant at *p* ≤ .10 (coefficient + p-value), generated via an `output: asis` chunk.
  - After the user pasted the rendered bullet-list text into the manuscript as static prose, removed the two `asis` chunks from the qmd and moved the equivalent filtering/formatting logic into `manuscript-setup.R` (`priority_sig`, `wtp_sig`, `priority_sig_bullets`, `wtp_sig_bullets`) so it stays reproducible without re-printing into the document.
- Re-rendered HTML, PDF, and DOCX multiple times over the session to verify each change; all three formats build cleanly.
- Created `README.md` documenting the project layout, reproduction steps, and data description, adapted from the `cc-behave` project's template.
- Updated `.gitignore` to exclude the generated `references.bib` and local `.csl` (consistent with the README's documented convention).

### Session 2 — 2026-07-15 (WTP distribution figure)

- Added a descriptive figure (`fig-wtp-distribution`) showing the weighted percent of respondents choosing each Gabor-Granger bid amount ($0–46) for `wtp.fossil` and `wtp.renewable`, faceted side-by-side, with one line per cue condition (Control, Trump cue, Climate cue).
- Added `wtp_dist` to `scripts/manuscript-setup.R`: reshapes `wtp.fossil`/`wtp.renewable` to long format, computes weighted percentages per outcome × cue condition × bid amount. Added `library(tidyr)` for the pivot.
- Styled the plot for print robustness: colorblind-safe colors (black/orange/green) plus redundant linetypes (solid/dashed/dotted) so conditions stay distinguishable in grayscale.
- Replaced the "Willingness to pay plot" placeholder text in `cue-WTP.qmd` with the new chunk.
- Re-rendered HTML, PDF, and DOCX to confirm the figure builds cleanly in all three formats.

### Session 3 — 2026-07-16 (Drop WTP distribution figure from manuscript, prose revisions)

- Removed the `fig-wtp-distribution` chunk from `cue-WTP.qmd`; the plotting code now lives in `scripts/manuscript-setup.R` as `wtp_dist_plot` (built from the existing `wtp_dist` data prep) with a comment on how to reinstate it — add a chunk in the qmd that prints `wtp_dist_plot`. Not currently used in the manuscript, kept for possible later use.
- User rewrote the abstract/intro prose in `cue-WTP.qmd` (expanded framing on climate change vs. energy-source polarization and Trump's rhetoric) and moved the Cloud Research/Census sampling paragraph out of the intro and into the "Online Methods" section.

### Session 4 — 2026-07-17 to 2026-07-20 (In-text stats, p-value convention, WTP model overhaul)

- Filled in the manuscript's remaining prose placeholders (`...`) with inline R referencing new objects added to `manuscript-setup.R`: sample sizes by cue condition (`n_total`, `n_trump`, `n_climate`, `n_control`), the energy-priority scale mean (`priority_scale_mean`/`_label`), concern-about-cost mean (`concern_cost_mean`), and specific model coefficients/p-values pulled via a new `get_term()` helper (e.g., `priority_conRep`, `wtp_trump_fossil`).
- Corrected the WTP descriptive stats (median/mean/paired-difference test) and priority-scale mean to use the survey-weighted design (`svyquantile`, `svymean`, `svyttest`) instead of unweighted base R functions — this changed several reported values materially (e.g., fossil-fuel median WTP $0 → $1 weighted).
- Added `predict_wtp()`/`predict_newdata()` helpers to generate model-predicted WTP for specific cue × political-identity combinations (controls held at survey-weighted means), used throughout the in-text results paragraphs.
- Established and applied a p-value reporting convention per user instruction: report *p* only when .05 ≤ *p* < .10 (marginal); omit it when the conventional .05 threshold is clearly met or clearly missed, since "significant"/predicted-value language already carries the finding.
- Added `wtp_dist_table` (weighted % of respondents at each Gabor-Granger bid amount, fossil vs. renewables) and briefly included it as `@tbl-wtp-dist`; later dropped from the manuscript to save a display item for the brief-communication format, but **the R code is kept in `manuscript-setup.R`** (unused in the qmd) in case the paper goes to a venue without that constraint. The two data points it made visible (~47% at $0 for fossil, 18.3% at $46 max for renewables) were folded into text instead.
- **WTP model iteration** (fossil-fuel WTP has a large mass at $0 — ~47% of respondents):
  1. Tried survey-weighted median (quantile) regression (`quantreg::rq`, τ = 0.5, weighted bootstrap SEs) for both fossil and renewable WTP. Fossil results were degenerate (many exact-zero/exact-multiple-of-$5 coefficients) because of the $0 floor; flagged this to the user.
  2. Switched fossil fuels to a two-part (Cragg) hurdle model: a survey-weighted logit for whether a respondent has any positive WTP (`m_wtp_fossil_participation`), plus a survey-weighted OLS on the dollar amount among those with positive WTP (`m_wtp_fossil_amount`, fit on `design_fossil_pos`, a `subset()` of the survey design). This is deterministic (no bootstrap) and well-behaved.
  3. Per user instruction, reverted renewables back to plain survey-weighted OLS (`m_wtp_renewable_int` via `svyglm`) for consistency with the priority-scale model, since the renewable WTP distribution doesn't have the same floor problem. Removed the `quantreg` dependency entirely.
- Per user instruction, split the fossil-fuel participation (logit, log-odds scale) coefficient plot into its own figure (`fig-wtp-fossil-participation`) rather than faceting it with the dollar-scale OLS models; `fig-wtp-interaction` now shows only the two comparable dollar-scale models (fossil amount|positive, renewables).
- Flagged (but did not silently resolve) a case where a model change reversed a substantive claim: under the quantile-regression attempt, the concluding paragraph's claim that conservative Republicans in the Trump cue have higher WTP for renewables than fossil fuels no longer held numerically. This reversal did not survive into the final hurdle-model + OLS specification — the concluding paragraph's numbers are consistent again ($11.90 renewables vs. $10.30 expected fossil WTP for that group) — but is a good example of a spec-dependent finding to watch if the model changes further.
- Re-rendered HTML, PDF, and DOCX repeatedly to confirm each change; all three formats build cleanly. Main text word count is currently ~1,435 words (journal brief-communication limit: 1,000–1,500), with 3 display items (`fig-priority-coef`, `fig-wtp-fossil-participation`, `fig-wtp-interaction`).

---

## Analysis Architecture (as of Session 1)

All analysis is centralized in `scripts/manuscript-setup.R`, sourced at the top of `cue-WTP.qmd`. The script handles:

- Data loading (`data/cueWTPDataWeighted.csv`) and survey design creation (`svydesign`)
- `svyglm` interaction model for `priority.scale ~ (trump.cue + climate.cue) * (libDem + conRep) + controls`
- Fossil-fuel WTP: two-part hurdle model — `svyglm(..., family = quasibinomial())` for whether WTP > $0 (`m_wtp_fossil_participation`), plus `svyglm()` for the dollar amount among `wtp.fossil > 0` respondents only (`m_wtp_fossil_amount`, fit on `design_fossil_pos`)
- Renewable WTP: `svyglm` interaction model, same RHS as `priority.scale` (`m_wtp_renewable_int`)
- `broom::tidy()` output filtered to drop the intercept and control terms, with human-readable term labels and a `term_type` grouping (Cue / Political identity / Interaction) for plot coloring. The fossil participation model is tidied separately (`fossil_participation_tidy`, log-odds scale) from the dollar-scale models (`wtp_int_tidy`: fossil amount + renewables) so they're never plotted together.
- `get_term()` helper pulls a single term's estimate/p-value out of a tidy data frame for in-text citation; `predict_wtp()`/`predict_prob()`/`predict_newdata()` generate model-predicted WTP/probabilities for specific cue × identity combinations (controls held at survey-weighted means).
- Convenience objects for in-text reporting of terms significant at *p* ≤ .10 (`priority_sig_bullets`, `wtp_sig_bullets`) — largely superseded by the more targeted `get_term()`-based reporting, but still computed.

## Key Analytical Decisions

- **Survey weights**: simple weighted design (`svydesign(ids = ~1, weights = ~weight)`) — CloudResearch/Census post-stratification weights, no clustering or stratification variables in the data. All descriptive stats (medians, means, t-tests) use `svyquantile`/`svymean`/`svyttest`, not unweighted base R equivalents.
- **Reference categories**: control condition (vs. Trump cue / climate cue) and other/moderate identity (vs. liberal Democrat / conservative Republican) are the excluded referents throughout.
- **Controls**: `concern.cost`, `age`, `male`, `white`, `edu`, `inc` included additively in all interaction models but excluded from coefficient plots and prose reporting.
- **Fossil-fuel WTP is a two-part hurdle model, not OLS or quantile regression**: ~47% of respondents report $0 WTP for fossil fuels, which made a single OLS or median-regression estimate hard to interpret (floor effects). The hurdle model (logit for participation + OLS for the amount among payers) was more stable and interpretable than median regression, which produced degenerate estimates at this specification. Renewables (~14% at $0) don't have this problem and use plain OLS.
- **p-value reporting in prose**: report *p* only when .05 ≤ *p* < .10; omit it when the finding is clearly significant (*p* < .05, the "significant"/predicted-value language already covers it) or clearly not (*p* ≥ .10).

## Key Findings (as of Session 4, 2026-07-20)

- `priority.scale` model (unchanged since Session 1): political identity has strong main effects (conservative Republican *b* = −1.22, *p* < .001; liberal Democrat *b* = 0.65, *p* < .001). Two interaction terms are marginal: climate cue × liberal Democrat (*b* = 0.35, *p* = .042) and Trump cue × conservative Republican (*b* = −0.41, *p* = .076). Neither cue main effect reaches significance on its own.
- Fossil-fuel WTP (hurdle model): conservative Republicans are significantly more likely to have any positive WTP (*b* = 0.74 log-odds, *p* < .001; predicted 68.3% vs. 41.6% for liberal Democrats, *p* = .050). Neither the Trump cue nor its interaction with conservative Republican identity significantly predicts participation or the conditional dollar amount — this null result held up across both the hurdle-model and quantile-regression specifications, unlike the original OLS model, which had shown a marginal Trump cue main effect (*b* = −2.56, *p* = .050) and a marginal Trump cue × conservative Republican interaction (*b* = 3.23, *p* = .097).
- Renewable WTP (OLS, reverted from quantile regression): political identity dominates (conservative Republican *b* = −6.82, *p* < .001; liberal Democrat *b* = 5.30, *p* < .001); climate cue × liberal Democrat is marginal (*b* = 3.66, *p* = .092).
- Overall: political identity is the dominant predictor across all outcomes. The Trump cue's effect on fossil-fuel WTP specifically turned out to be sensitive to model specification — significant/marginal under plain OLS, but null under both quantile regression and the hurdle model, which better handle the $0 floor. Worth keeping in mind if reviewers ask about robustness.
