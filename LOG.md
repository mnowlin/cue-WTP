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

---

## Analysis Architecture (as of Session 1)

All analysis is centralized in `scripts/manuscript-setup.R`, sourced at the top of `cue-WTP.qmd`. The script handles:

- Data loading (`data/cueWTPDataWeighted.csv`) and survey design creation (`svydesign`)
- Two `svyglm` interaction models: `priority.scale ~ (trump.cue + climate.cue) * (libDem + conRep) + controls` and the same specification for `wtp.fossil`/`wtp.renewable`
- `broom::tidy()` output filtered to drop the intercept and control terms, with human-readable term labels and a `term_type` grouping (Cue / Political identity / Interaction) for plot coloring
- Convenience objects for in-text reporting of terms significant at *p* ≤ .10 (`priority_sig_bullets`, `wtp_sig_bullets`)

## Key Analytical Decisions

- **Survey weights**: simple weighted design (`svydesign(ids = ~1, weights = ~weight)`) — CloudResearch/Census post-stratification weights, no clustering or stratification variables in the data.
- **Reference categories**: control condition (vs. Trump cue / climate cue) and other/moderate identity (vs. liberal Democrat / conservative Republican) are the excluded referents throughout.
- **Controls**: `concern.cost`, `age`, `male`, `white`, `edu`, `inc` included additively in both interaction models but excluded from coefficient plots and prose reporting.
- **Significance threshold for prose reporting**: *p* ≤ .10, reported as coefficient + p-value bullet lists rather than full tables.

## Key Findings (as of Session 1)

- `priority.scale` model: political identity has strong main effects (conservative Republican *b* = −1.22, *p* < .001; liberal Democrat *b* = 0.65, *p* < .001). Two interaction terms are marginal: climate cue × liberal Democrat (*b* = 0.35, *p* = .042) and Trump cue × conservative Republican (*b* = −0.41, *p* = .076). Neither cue main effect reaches significance on its own.
- WTP models: political identity again dominates for renewables (conservative Republican *b* = −6.82, *p* < .001; liberal Democrat *b* = 5.30, *p* = .001). Trump cue reduces fossil-fuel WTP at the significance threshold (*b* = −2.56, *p* = .050); climate cue × liberal Democrat (*b* = 3.66, *p* = .092) and Trump cue × conservative Republican (*b* = 3.23, *p* = .097) on fossil-fuel/renewable WTP are marginal.
- Overall: political identity is the dominant predictor across all outcomes; cue effects and cue × identity interactions are mostly marginal (.05 ≤ *p* ≤ .10), worth flagging when writing up the Results/Discussion.
