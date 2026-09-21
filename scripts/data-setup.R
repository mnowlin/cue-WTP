#!/usr/bin/env Rscript

# Shared data prep for cue-WTP.qmd and supplemental-materials.qmd.
# Loads the weighted survey data, builds the survey design, and computes the
# descriptive stats/tables referenced by both documents. Sourced by
# manuscript-setup.R, supplemental-demo-setup.R, and supplemental-setup.R,
# which each go on to fit the interaction models with a different set of
# controls (the manuscript uses none; the supplemental materials add
# demographics, and separately demographics plus concern.cost, as robustness
# checks).

library(survey)
library(dplyr)
library(tidyr)
library(ggplot2)
library(broom)
library(marginaleffects)
library(modelsummary)

# ---- Data -------------------------------------------------------------

d <- read.csv("data/cueWTPDataWeighted.csv")
d$wtp_diff <- d$wtp.renewable - d$wtp.fossil
d$wtp_fossil_pos <- as.numeric(d$wtp.fossil > 0)

# Simple weighted design: CloudResearch/Census post-stratification weights,
# no clustering or stratification variables in the data.
design <- svydesign(ids = ~1, weights = ~weight, data = d)

# Subsample of respondents with any positive fossil-fuel WTP, for the
# "amount | WTP > $0" part of the fossil hurdle model below.
design_fossil_pos <- subset(design, wtp_fossil_pos == 1)

# ---- Sample sizes and descriptive WTP stats, for in-text reporting --------
# All descriptive WTP stats are survey-weighted, for consistency with the
# svyglm models used throughout the rest of the analysis.

n_total   <- nrow(d)
n_trump   <- sum(d$trump.cue)
n_climate <- sum(d$climate.cue)
n_control <- sum(d$control)

# Energy-priority scale: 1 = prioritize fossil fuels, 4 = equal priority,
# 7 = prioritize renewables.
priority_scale_mean <- round(coef(svymean(~priority.scale, design)), 2)
priority_scale_label <- case_when(
  priority_scale_mean > 4 ~ "renewables",
  priority_scale_mean < 4 ~ "fossil fuels",
  TRUE                    ~ "fossil fuels and renewables equally"
)

wtp_medians <- svyquantile(
  ~wtp.fossil + wtp.renewable, design, quantiles = 0.5, ci = FALSE
)
wtp_fossil_median    <- wtp_medians$wtp.fossil[1, 1]
wtp_renewable_median <- wtp_medians$wtp.renewable[1, 1]
wtp_median_diff     <- wtp_renewable_median - wtp_fossil_median
wtp_median_diff_val <- unname(wtp_median_diff)

wtp_means <- svymean(~wtp.fossil + wtp.renewable, design)
wtp_fossil_mean    <- round(coef(wtp_means)["wtp.fossil"], 2)
wtp_renewable_mean <- round(coef(wtp_means)["wtp.renewable"], 2)

# Survey-weighted paired (within-subject) comparison of fossil vs. renewable
# WTP: one-sample t-test on the per-respondent difference against zero.
wtp_diff_test <- svyttest(wtp_diff ~ 0, design)
wtp_diff_mean <- round(unname(wtp_diff_test$estimate), 2)
wtp_diff_t    <- round(unname(wtp_diff_test$statistic), 2)
wtp_diff_df   <- unname(wtp_diff_test$parameter)
wtp_diff_p    <- ifelse(
  wtp_diff_test$p.value < .001, "< .001", sprintf("= %.3f", wtp_diff_test$p.value)
)

# Concern about the cost of electricity (0-10 scale). Reported as descriptive
# context in the manuscript; used as an additional model control only in the
# supplemental-materials robustness check (see supplemental-setup.R).
concern_cost_mean <- round(coef(svymean(~concern.cost, design)), 2)

# Shared term labels for coefficient plots/tables.
term_labels <- c(
  "trump.cue"           = "Trump cue",
  "climate.cue"         = "Climate cue",
  "libDem"              = "Liberal Democrat",
  "conRep"              = "Conservative Republican",
  "trump.cue:libDem"    = "Trump cue × Liberal Democrat",
  "climate.cue:libDem"  = "Climate cue × Liberal Democrat",
  "trump.cue:conRep"    = "Trump cue × Conservative Republican",
  "climate.cue:conRep"  = "Climate cue × Conservative Republican"
)

term_type <- function(term) {
  case_when(
    grepl(":", term)                        ~ "Interaction",
    term %in% c("trump.cue", "climate.cue") ~ "Cue",
    TRUE                                    ~ "Political identity"
  )
}

gof_omit_pattern <- "R2|IC|Log|Adj|F|RMSE"
stars_map         <- c("*" = .1, "**" = .05, "***" = .01)

# Cue/identity levels for predicted-value grids, shared by both documents.
cue_levels      <- c("Control", "Trump cue", "Climate cue")
identity_levels <- c("Other/moderate", "Liberal Democrat", "Conservative Republican")

# ---- WTP distribution, overall (in-text table) -----------------------------
# Weighted share of respondents choosing each Gabor-Granger bid amount
# (0-46), for fossil fuels and renewables, pooled across cue conditions.

wtp_dist_table <- d |>
  select(weight, wtp.fossil, wtp.renewable) |>
  pivot_longer(
    cols = c(wtp.fossil, wtp.renewable),
    names_to = "outcome", values_to = "wtp"
  ) |>
  group_by(outcome, wtp) |>
  summarise(n = sum(weight), .groups = "drop_last") |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup() |>
  select(outcome, wtp, pct) |>
  pivot_wider(names_from = outcome, values_from = pct) |>
  arrange(wtp) |>
  rename(
    `WTP ($)`         = wtp,
    `Fossil fuels (%)` = wtp.fossil,
    `Renewables (%)`   = wtp.renewable
  )

# Share of respondents at the two ends of the bid range, for in-text
# reporting (nearly half pay nothing extra for fossil fuels; a much smaller
# share max out their WTP for renewables).
wtp_fossil_zero_pct   <- wtp_dist_table$`Fossil fuels (%)`[wtp_dist_table$`WTP ($)` == 0]
wtp_renewable_max_pct <- wtp_dist_table$`Renewables (%)`[wtp_dist_table$`WTP ($)` == 46]

# ---- WTP distribution by cue condition (descriptive figure) ---------------
# Weighted share of respondents choosing each Gabor-Granger bid amount
# (0-46), split by fossil/renewable outcome and cue condition.

cue_labels <- c("Control" = "Control", "Trump cue" = "Trump cue", "Climate cue" = "Climate cue")

wtp_dist <- d |>
  mutate(
    cue_condition = case_when(
      control     == 1 ~ "Control",
      trump.cue   == 1 ~ "Trump cue",
      climate.cue == 1 ~ "Climate cue"
    ),
    cue_condition = factor(cue_condition, levels = names(cue_labels))
  ) |>
  select(cue_condition, weight, wtp.fossil, wtp.renewable) |>
  pivot_longer(
    cols = c(wtp.fossil, wtp.renewable),
    names_to = "outcome", values_to = "wtp"
  ) |>
  mutate(
    outcome = recode(outcome,
      "wtp.fossil"    = "WTP: Fossil fuels",
      "wtp.renewable" = "WTP: Renewables"
    )
  ) |>
  group_by(outcome, cue_condition, wtp) |>
  summarise(n = sum(weight), .groups = "drop_last") |>
  mutate(pct = 100 * n / sum(n)) |>
  ungroup()

# Not currently included in either document; kept here in case the figure is
# reinstated. To use again, add a chunk that prints wtp_dist_plot (fig-cap:
# "Distribution of willingness-to-pay for fossil fuel and renewable
# electricity, by cue condition (weighted percent of respondents choosing
# each bid amount)").
wtp_dist_plot <- wtp_dist |>
  ggplot(aes(x = wtp, y = pct, color = cue_condition, linetype = cue_condition)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.8) +
  facet_wrap(~outcome) +
  scale_x_continuous(limits = c(0, 46), breaks = c(0, 1, 6, 11, 16, 21, 26, 31, 36, 41, 46)) +
  scale_color_manual(values = c("Control" = "#000000", "Trump cue" = "#D55E00", "Climate cue" = "#009E73")) +
  scale_linetype_manual(values = c("Control" = "solid", "Trump cue" = "dashed", "Climate cue" = "dotted")) +
  labs(x = "Willingness to pay ($)", y = "Percent of respondents", color = NULL, linetype = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom")
