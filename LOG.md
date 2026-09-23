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

### Session 9 — 2026-09-23 (Literature search on cues and WTP, intro/lit review revision)

- **Consensus literature search** on cues and WTP for energy, extended to partisan cues in consumer and economic behavior generally. Six searches: partisan cues and WTP for renewables; climate framing and WTP; elite/party cues and energy policy; environmental labeling and ideology; partisan cues and consumer WTP; partisanship and costs of fossil fuels.
  - Most relevant energy sources not yet cited: Gromet et al. 2013 (environmental label reduces conservatives' purchase of efficient bulbs), Gustafson et al. 2020, Crowe 2020, Marlow et al. 2022, Mayer 2019 and 2021, Rinscheid et al. 2020, Fielding et al. 2019, Ehret et al. 2018, Druckman et al. 2013, Ciuk & Yost 2016, Goldfarb et al. 2021.
  - Broader sources: McConnell et al. 2017, Panagopoulos et al. 2020, Erlandsson et al. 2024, Lenk et al. 2025, Pink et al. 2021, Peterson 2018.
  - Checked against Zotero (`zotero.sqlite`): **not in Zotero** as of this session: Mayer 2021 (10.1016/j.exis.2021.101038), Rinscheid et al. 2020 (10.1017/bpp.2020.43), Ehret et al. 2018 (10.1177/1948550618758709; since added to the master bib), Goldfarb et al. 2021 (10.1016/j.enpol.2020.112098).
  - Apparent gap: no study found that randomizes both partisan and climate cues and measures stated WTP for specific fossil and renewable sources.
- **User revised Introduction and literature review** in `cue-WTP.qmd`: merged the cues and WTP sections into "Cues, Public Opinion, and the Public's Willingness-to-Pay for Energy," added an "Expectations" subsection, and added citations to Ehret et al. 2018 and Gromet et al. 2013. Noted the intended outlet (Energy Policy, research note, 4,500-word limit) as a comment in the manuscript.
- Re-ran `scripts/export-cited-refs.R` (26/26 cited keys matched) so the project-local `references.bib` includes the new citations.

### Session 8 — 2026-09-22 (Fit-stat fix, cost-concern x cue/identity robustness check)

- **Fixed missing model fit statistics.** `gof_omit_pattern` in `scripts/data-setup.R` was omitting every goodness-of-fit stat including R2, leaving only `Num.Obs.` in `tbl-priority-ols` and `tbl-wtp-models`. Per user instruction, replaced the single ambiguous "R2" row with two properly-labeled ones:
  - Added `glance_custom.svyglm()` to `data-setup.R`: returns **Adj. R2** (`performance::r2()$R2_adjusted`) for the gaussian (OLS) models and **McFadden's pseudo R2** (`performance::r2()$R2`) for the (quasi)binomial logit model, as differently-named columns so modelsummary renders them as separate rows (blank on the model they don't apply to) instead of conflating adjusted-OLS-R2 with pseudo-R2 under one label.
  - Debugging note: `family(x)$family` for an `svyglm(family = quasibinomial())` model returns `"quasibinomial"`, not `"binomial"` — the branch condition had to use `grepl("binomial", ...)` to catch it.
  - `gof_omit_pattern` tightened to exact-match anchors (`^R2$`, `^R2 Adj\\.$`, etc.) so it drops modelsummary's defaults without also matching the new custom labels (which contain "R2" as a substring).
  - `glance_custom` values bypass modelsummary's default `fmt` rounding, so they're rounded to 3 decimals explicitly inside `glance_custom.svyglm()` to match the rest of the table.
- **New robustness check: concern about energy cost interacted with cues and political identity.** Per user request ("try interacting concern.cost with political beliefs and the cues for each model"), explored this in a throwaway scratch script first, confirmed real/interpretable effects, then formalized it into the project:
  - Added `scripts/supplemental-cost-interaction-setup.R`: refits all four models (priority scale, fossil participation, fossil amount, renewables) with `concern.cost * (trump.cue + climate.cue + libDem + conRep)` added on top of the demographic controls, plus `get_term()`/`cost_sig_bullets()` helpers scoped to just the concern.cost-related terms.
  - Added a third robustness section to `supplemental-materials.qmd` ("Concern about Energy Cost Interacted with Cues and Political Identity") with two tables and write-up prose, matching the structure of the existing two robustness sections.
  - **Findings:** concern about energy cost has a significant, *partisanship-moderated* relationship with fossil-fuel prioritization and WTP — the cost-concern penalty on fossil-fuel WTP is significantly weaker for conservative Republicans (priority scale) and for both liberal Democrats and conservative Republicans (fossil participation), and is significantly offset under the Trump cue (fossil amount, among those with positive WTP). No concern.cost interaction reached significance for renewables. Main-text cue x identity effects are unaffected by this specification.
- Re-rendered HTML, PDF, and DOCX for both `cue-WTP.qmd` and `supplemental-materials.qmd`; all six outputs build cleanly with the corrected fit statistics and new section.

### Session 7 — 2026-09-21 (Gabor-Granger citations, Conclusion draft, no-controls main spec)

- **Gabor-Granger method justification:** used Consensus to find supporting citations, then added two sentences after the existing Gabor-Granger mention in `cue-WTP.qmd` (Methods) justifying the method's use, citing Jones (1975), Wedel & Leeflang (1998), and Lipovetsky, Magnan & Zanetti-Polzi (2011), alongside the already-cited Breidert et al. review.
  - Added the three missing sources to Zotero via its local connector API (`POST http://127.0.0.1:23119/connector/saveItems`), using CrossRef-verified metadata (title, authors, journal, DOI) so the generated Better BibTeX citekeys matched the manuscript's citations. Confirmed Better BibTeX auto-export synced them into the master bib, then re-ran `export-cited-refs.R` to refresh the project-local `references.bib`.
- **Drafted the "Conclusion and Policy Implications" section** (previously empty) at the user's request, despite this project's `CLAUDE.md` normally reserving manuscript prose for the user — confirmed with the user first that they wanted full drafted prose here. Four paragraphs (summary, uneven cue effects, three policy implications, limitations/future research), written in the `nowlin-style-profile.md` voice and using only numbers already computed in `manuscript-setup.R`.
- **Robustness check: no controls at all.** Per user request, refit the three main-text models (priority scale, fossil-fuel hurdle model, renewable WTP) with every demographic control dropped, via a throwaway comparison script (`scripts/robustness-nodemo-setup.R`, deleted at end of session). Coefficients kept the same sign and significance pattern as the demographics-controlled specification throughout, with only trivial magnitude shifts.
- **Swapped the main specification** based on that check, per user request ("keep the results with no controls in the manuscript and add the results with controls to the supplemental materials file"):
  - `scripts/manuscript-setup.R` now fits the main-text models with **no controls at all** (previously demographics-only).
  - Added `scripts/supplemental-demo-setup.R` (a copy of the former `manuscript-setup.R`, i.e. the demographics-only specification) as a new first robustness-check section in `supplemental-materials.qmd`, ahead of the existing demographics + cost-concern section (retitled "Controlling for Demographics and Concern about Energy Cost" for clarity now that it's the second, more elaborate check).
  - Updated the Methods paragraph, table/figure captions, and one Results sentence in `cue-WTP.qmd` to match (removed "controlling for demographics" language; softened "was significant" to "were marginally significant" for the priority-scale cue × identity interactions, since both borderline terms, p ≈ .05–.06, no longer clear conventional significance without the demographic controls).
  - Updated `README.md` and code comments in `scripts/data-setup.R` / `scripts/supplemental-setup.R` to describe the new three-specification structure.
  - Verified via rendered HTML output that all in-text values updated correctly and the two supplemental sections don't clobber each other's model objects (each is sourced immediately before its own section).
- Re-rendered HTML, PDF, and DOCX for both `cue-WTP.qmd` and `supplemental-materials.qmd`; all six outputs build cleanly.

### Session 6 — 2026-09-21 (Cost-concern robustness check, supplemental materials, literature review, placeholder fills)

- **Robustness check:** re-ran the priority-scale and WTP interaction models without `concern.cost` as a control (previously included in all main-text models). Coefficients, significance, and substantive conclusions were essentially unchanged (one marginal term, climate cue × liberal Democrat on renewable WTP, moved from *p* = .092 to *p* = .109 — same sign, similar magnitude).
- **Split the analysis into main text vs. supplemental materials** based on that check:
  - Added `scripts/data-setup.R`: factored out the data loading, survey design, and descriptive stats/tables shared by both documents (previously all in `manuscript-setup.R`).
  - `scripts/manuscript-setup.R` now fits the main-text models **without** `concern.cost` as a control.
  - Added `scripts/supplemental-setup.R`: refits the same models **with** `concern.cost` added back, for the robustness appendix.
  - Added `supplemental-materials.qmd`: a standalone Quarto document (same author/format YAML as the main manuscript) reporting the cost-concern-controlled regression tables/figures and a short write-up of the comparison.
  - Updated `_quarto.yaml` (renders both `.qmd` files) and `scripts/export-cited-refs.R` (scans both for citation keys).
  - Updated the Methods paragraph and figure captions in `cue-WTP.qmd` to reflect the demographics-only main-text specification and point to the supplemental robustness check.
- **Literature review:** used Consensus (via the `claude.ai Consensus` MCP tool) to search for WTP-for-energy and partisan-cue literature, then drafted the previously-empty `# Cues and Public Opinion` and `# The Public's Willingness-to-Pay for Energy` sections (~900 words combined) in the user's voice, guided by `nowlin-style-profile.md` (copied into this project directory from `project-files/`; **git-ignored, not committed**). Cited only sources with clean entries in the master `.bib`.
  - Cross-checked all 20 Consensus-surfaced papers against the user's Zotero library (via a read-only copy of `~/Zotero/zotero.sqlite`, matched by DOI and title). Found 11 missing. The user then manually added 10 of them to Zotero via the browser connector, organized into "Climate Public Opinion" and "Energy Public Opinion" collections. Added the last one (Ma et al. 2015, meta-regression analysis of renewable WTP) programmatically via Zotero's local connector API (`POST http://127.0.0.1:23119/connector/saveItems`), using CrossRef for metadata.
  - **Known cleanup item, not yet resolved:** while testing the connector API, accidentally created a duplicate Zotero item for Scheuch (2024) (`Price and party...`, key `DEUENJWL`). Zotero's local API doesn't support item deletion over HTTP, so this needs to be trashed manually in the Zotero app — the correct copy (key `BJUHYCN7`) is already filed in "Climate Public Opinion".
  - Extended "The Public's Willingness-to-Pay for Energy" with two more directly-relevant sources once available in Zotero: Bakkensen & Schuler (2020, Vietnam coal-vs-renewable WTP) and Walter, Thacher & Chermak (2023, New Mexico fossil-vs-renewable choice experiment) — the two closest design analogs to this study found in the search.
- **Filled in the remaining Results prose placeholders** (`...`) with real computed values:
  - Added `priority_conRep_control_pred`/`_trump_pred`/`priority_libDem_control_pred`/`_climate_pred` to `manuscript-setup.R` (predicted priority-scale values by cue × identity, via the existing `predict_wtp()` helper).
  - Added `wtp_fossil_zero_pct` (47%) and `wtp_renewable_max_pct` (18.3%) to `data-setup.R` (share of respondents at the bid-range floor/ceiling).
  - Added `wtp_median_diff_val` (\$10) and `wtp_diff_mean` (\$9.88, from the existing paired t-test object) to `data-setup.R`. Note: the median difference is reported descriptively only — the only significance test in the pipeline (`svyttest`) tests the *mean* paired difference, not the median, so no significance claim is attached to the median figure.
- Re-rendered HTML, PDF, and DOCX for both `cue-WTP.qmd` and `supplemental-materials.qmd` repeatedly; all six outputs build cleanly with no warnings.
- **Housekeeping:** fixed a gitignore gap from this session — `nowlin-style-profile.md` was copied into the project but not yet git-ignored; also the existing `/lit-review/` ignore rule didn't match this project's actual `literature/` directory (a naming mismatch from an earlier project setup). Corrected both. Removed a stray `tmp-pdfcrop-*.tex` artifact left behind by a PDF render.

### Session 5 — 2026-07-21 (Article format switch, display-item overhaul)

- User decided to submit to a venue with an article format (3,000-word main text, up to 6 display items) rather than the brief-communication format used through Session 4.
- Completed an in-progress `@tbl-` reference by adding `tbl-wtp-dist` back into the manuscript: weighted percent of respondents choosing each Gabor-Granger bid amount, fossil fuels vs. renewables (the `wtp_dist_table` object already existed in `manuscript-setup.R` from Session 4 but wasn't rendered).
- Per user request, replaced all three coefficient plots (`fig-priority-coef`, `fig-wtp-fossil-participation`, `fig-wtp-interaction`) with two full regression tables and three predicted-value plots:
  - `tbl-priority-ols` and `tbl-wtp-models` — `modelsummary()` tables (new dependency, alongside `marginaleffects`) showing every model coefficient, including the demographic/attitudinal controls previously omitted from the plots. `tbl-wtp-models` combines the fossil-fuel logit, fossil-fuel amount OLS, and renewables OLS in one table.
  - `fig-priority-predicted`, `fig-wtp-fossil-predicted`, `fig-wtp-renewable-predicted` — point-range plots of model-predicted values (95% CIs) over a 3 (cue condition) × 3 (political identity) grid, via a new `predict_grid()` helper (`marginaleffects::predictions()`, controls held at survey-weighted means). Replaces reading effects off coefficients with reading them off predicted outcomes directly.
  - Added shared table-display objects to `manuscript-setup.R`: `coef_map` (term labels for all coefficients including controls), `gof_omit_pattern`, `stars_map`.
  - Manuscript is now at 6 display items (3 tables, 3 figures) — the article format's limit.
- Caught and fixed a mid-edit slip: a paragraph of the user's authored prose (conservative Republicans' fossil-fuel participation results) was accidentally deleted while removing the old `fig-wtp-fossil-participation` figure it sat next to; restored it after the fact. Flagged to the user as a reminder to review the diff on multi-figure restructuring requests.
- User reorganized the manuscript into full-article sections (`# Introduction`, `# Methodology and Data`, `# Results and Discussion`, `# Conclusion and Policy Implications`), dropping the brief-communication framing (bolded abstract lead-in, headless body, separate `# Online Methods` section) used through Session 4.
- Added a "Close out" workflow to `CLAUDE.md` (update log → update README → commit → push), triggered by the phrase "close out".
- Re-rendered HTML, PDF, and DOCX repeatedly; all three formats build cleanly throughout.

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
