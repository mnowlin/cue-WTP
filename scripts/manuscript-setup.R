#!/usr/bin/env Rscript

# Data prep and model fitting for cue-WTP.qmd.
# Loads the weighted survey data, builds the survey design, and fits every
# model referenced in the manuscript. The qmd file draws on the objects
# created here to render tables and plots with knitr::kable()/ggplot2.

library(survey)
library(dplyr)
library(tidyr)
library(ggplot2)
library(broom)

# ---- Data -------------------------------------------------------------

d <- read.csv("data/cueWTPDataWeighted.csv")

# Simple weighted design: CloudResearch/Census post-stratification weights,
# no clustering or stratification variables in the data.
design <- svydesign(ids = ~1, weights = ~weight, data = d)

# Demographic/attitudinal controls included in the interaction models but
# excluded from the coefficient plots.
control_vars <- c("concern.cost", "age", "male", "white", "edu", "inc")
control_rhs  <- paste(control_vars, collapse = " + ")

# Shared term labels for coefficient plots.
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

# ---- Priority scale OLS: cues x political beliefs -----------------------
# Does the cue effect on priority.scale differ for liberal Democrats and
# conservative Republicans (vs. other/moderate), relative to control?

m_priority_int <- svyglm(
  as.formula(paste(
    "priority.scale ~ (trump.cue + climate.cue) * (libDem + conRep) +",
    control_rhs
  )),
  design = design
)

priority_int_tidy <- tidy(m_priority_int, conf.int = TRUE) |>
  filter(!term %in% c("(Intercept)", control_vars)) |>
  mutate(term_label = recode(term, !!!term_labels), term_type = term_type(term))

# ---- WTP ~ cue condition x political beliefs ------------------------------
# Conservative Republicans in the Trump cue / liberal Democrats in the
# climate cue expected to diverge most from control on WTP.

m_wtp_fossil_int <- svyglm(
  as.formula(paste(
    "wtp.fossil ~ (trump.cue + climate.cue) * (libDem + conRep) +",
    control_rhs
  )),
  design = design
)

m_wtp_renewable_int <- svyglm(
  as.formula(paste(
    "wtp.renewable ~ (trump.cue + climate.cue) * (libDem + conRep) +",
    control_rhs
  )),
  design = design
)

wtp_int_tidy <- bind_rows(
  tidy(m_wtp_fossil_int, conf.int = TRUE)    |> mutate(outcome = "WTP: Fossil fuels"),
  tidy(m_wtp_renewable_int, conf.int = TRUE) |> mutate(outcome = "WTP: Renewables")
) |>
  filter(!term %in% c("(Intercept)", control_vars)) |>
  mutate(term_label = recode(term, !!!term_labels), term_type = term_type(term))

# ---- Terms significant at p <= .10, for in-text write-up ------------------

priority_sig <- priority_int_tidy[priority_int_tidy$p.value <= 0.10, ]
priority_sig <- priority_sig[order(priority_sig$p.value), ]
priority_sig_bullets <- sprintf(
  "- %s: b = %.2f, *p* = %.3f",
  priority_sig$term_label, priority_sig$estimate, priority_sig$p.value
)

wtp_sig <- wtp_int_tidy[wtp_int_tidy$p.value <= 0.10, ]
wtp_sig <- wtp_sig[order(wtp_sig$p.value), ]
wtp_sig_bullets <- sprintf(
  "- %s, %s: b = %.2f, *p* = %.3f",
  wtp_sig$term_label, wtp_sig$outcome, wtp_sig$estimate, wtp_sig$p.value
)

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
