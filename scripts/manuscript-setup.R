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
wtp_median_diff       <- wtp_renewable_median - wtp_fossil_median

wtp_means <- svymean(~wtp.fossil + wtp.renewable, design)
wtp_fossil_mean    <- round(coef(wtp_means)["wtp.fossil"], 2)
wtp_renewable_mean <- round(coef(wtp_means)["wtp.renewable"], 2)

# Survey-weighted paired (within-subject) comparison of fossil vs. renewable
# WTP: one-sample t-test on the per-respondent difference against zero.
wtp_diff_test <- svyttest(wtp_diff ~ 0, design)
wtp_diff_t    <- round(unname(wtp_diff_test$statistic), 2)
wtp_diff_df   <- unname(wtp_diff_test$parameter)
wtp_diff_p    <- ifelse(
  wtp_diff_test$p.value < .001, "< .001", sprintf("= %.3f", wtp_diff_test$p.value)
)

# Concern about the cost of electricity (0-10 scale).
concern_cost_mean <- round(coef(svymean(~concern.cost, design)), 2)

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

# Regression-table labels (term_labels above plus the demographic/attitudinal
# controls) and display settings, shared by the modelsummary() tables below.
coef_map <- c(
  term_labels,
  "concern.cost" = "Concern about energy cost",
  "age"          = "Age",
  "male"         = "Male",
  "white"        = "White",
  "edu"          = "Education",
  "inc"          = "Income",
  "(Intercept)"  = "(Intercept)"
)
gof_omit_pattern <- "R2|IC|Log|Adj|F|RMSE"
stars_map         <- c("*" = .1, "**" = .05, "***" = .01)

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

# ---- WTP ~ cue condition x political beliefs -------------------------------
# Conservative Republicans in the Trump cue / liberal Democrats in the
# climate cue expected to diverge most from control on WTP.
#
# Fossil-fuel WTP has a large mass of respondents at $0 (see wtp_dist_table:
# ~47% pay nothing extra), which makes a single OLS conditional-mean estimate
# hard to interpret — the floor at $0 dominates the outcome. A two-part
# (Cragg) hurdle model separates the question into (1) whether a respondent
# has any positive WTP at all (survey-weighted logit) and (2) how much
# they're willing to pay, among those who are willing to pay something
# (survey-weighted OLS on the WTP > $0 subsample). Renewables have much less
# mass at $0 (~14%) and a roughly normal distribution otherwise, so a single
# OLS model remains appropriate there, consistent with the priority-scale
# model above.

m_wtp_fossil_participation <- svyglm(
  as.formula(paste(
    "wtp_fossil_pos ~ (trump.cue + climate.cue) * (libDem + conRep) +",
    control_rhs
  )),
  design = design, family = quasibinomial()
)

m_wtp_fossil_amount <- svyglm(
  as.formula(paste(
    "wtp.fossil ~ (trump.cue + climate.cue) * (libDem + conRep) +",
    control_rhs
  )),
  design = design_fossil_pos
)

m_wtp_renewable_int <- svyglm(
  as.formula(paste(
    "wtp.renewable ~ (trump.cue + climate.cue) * (libDem + conRep) +",
    control_rhs
  )),
  design = design
)

# Participation (logit) kept out of wtp_int_tidy: it's plotted separately
# since its log-odds scale isn't comparable to the dollar-scale OLS models.
fossil_participation_tidy <- tidy(m_wtp_fossil_participation, conf.int = TRUE) |>
  filter(!term %in% c("(Intercept)", control_vars)) |>
  mutate(term_label = recode(term, !!!term_labels), term_type = term_type(term))

wtp_int_tidy <- bind_rows(
  tidy(m_wtp_fossil_amount, conf.int = TRUE) |>
    mutate(outcome = "Fossil fuels"),
  tidy(m_wtp_renewable_int, conf.int = TRUE) |>
    mutate(outcome = "Renewables")
) |>
  filter(!term %in% c("(Intercept)", control_vars)) |>
  mutate(term_label = recode(term, !!!term_labels), term_type = term_type(term))

# ---- Specific model terms, for in-text write-up ---------------------------
# Pulls a single term's estimate/p-value out of a tidy() model data frame so
# specific coefficients can be cited by name in the manuscript prose.

get_term <- function(tidy_df, term_name, outcome_name = NULL) {
  if (!is.null(outcome_name)) {
    tidy_df <- tidy_df[tidy_df$outcome == outcome_name, ]
  }
  row <- tidy_df[tidy_df$term == term_name, ]
  list(
    b = sprintf("%.2f", row$estimate),
    b_abs = sprintf("%.2f", abs(row$estimate)),
    p = ifelse(row$p.value < .001, "< .001", sprintf("= %.3f", row$p.value))
  )
}

priority_conRep         <- get_term(priority_int_tidy, "conRep")
priority_libDem         <- get_term(priority_int_tidy, "libDem")
priority_trump_conRep   <- get_term(priority_int_tidy, "trump.cue:conRep")
priority_climate_libDem <- get_term(priority_int_tidy, "climate.cue:libDem")

fossil_part_conRep       <- get_term(fossil_participation_tidy, "conRep")
fossil_part_libDem       <- get_term(fossil_participation_tidy, "libDem")
fossil_part_trump        <- get_term(fossil_participation_tidy, "trump.cue")
fossil_part_trump_conRep <- get_term(fossil_participation_tidy, "trump.cue:conRep")

fossil_amt_trump        <- get_term(wtp_int_tidy, "trump.cue", "Fossil fuels")
fossil_amt_trump_conRep <- get_term(wtp_int_tidy, "trump.cue:conRep", "Fossil fuels")

wtp_libDem_renewable    <- get_term(wtp_int_tidy, "libDem", "Renewables")
wtp_climate_libDem_renewable <- get_term(wtp_int_tidy, "climate.cue:libDem", "Renewables")
wtp_conRep_renewable    <- get_term(wtp_int_tidy, "conRep", "Renewables")

# ---- Predicted WTP for specific cue/identity combinations, for in-text ----
# Predictions hold the demographic/attitudinal controls at their
# survey-weighted means and vary only the cue and political-identity
# indicators referenced in the write-up.

control_means <- setNames(
  sapply(control_vars, function(v) unname(coef(svymean(as.formula(paste0("~", v)), design)))),
  control_vars
)

predict_newdata <- function(trump = 0, climate = 0, libDem = 0, conRep = 0) {
  newdata <- as.data.frame(as.list(control_means))
  newdata$trump.cue   <- trump
  newdata$climate.cue <- climate
  newdata$libDem      <- libDem
  newdata$conRep      <- conRep
  newdata
}

predict_wtp <- function(model, ...) {
  sprintf("%.2f", as.numeric(predict(model, newdata = predict_newdata(...), type = "response")))
}

# ---- Predicted-value grids, for plots --------------------------------------
# Same cue x political-identity combinations as predict_newdata() above, but
# every combination at once with confidence intervals, for point-range plots.
# Controls held at their survey-weighted means throughout.

cue_levels      <- c("Control", "Trump cue", "Climate cue")
identity_levels <- c("Other/moderate", "Liberal Democrat", "Conservative Republican")

predict_grid <- function(model) {
  grid <- expand.grid(
    cue_condition = cue_levels, identity = identity_levels,
    stringsAsFactors = FALSE
  )
  grid$trump.cue   <- as.numeric(grid$cue_condition == "Trump cue")
  grid$climate.cue <- as.numeric(grid$cue_condition == "Climate cue")
  grid$libDem      <- as.numeric(grid$identity == "Liberal Democrat")
  grid$conRep      <- as.numeric(grid$identity == "Conservative Republican")
  newdata <- cbind(grid, as.data.frame(as.list(control_means)))

  preds <- as.data.frame(marginaleffects::predictions(model, newdata = newdata))
  preds$cue_condition <- factor(preds$cue_condition, levels = cue_levels)
  preds$identity      <- factor(preds$identity, levels = identity_levels)
  preds
}

priority_pred   <- predict_grid(m_priority_int)
fossil_amt_pred <- predict_grid(m_wtp_fossil_amount)
renewable_pred  <- predict_grid(m_wtp_renewable_int)

# Predicted probability of any positive fossil-fuel WTP (part 1 of the
# hurdle model), as a percent.
predict_prob <- function(model, ...) {
  p <- as.numeric(predict(model, newdata = predict_newdata(...), type = "response"))
  sprintf("%.1f%%", 100 * p)
}

fossil_prob_conRep_control <- predict_prob(m_wtp_fossil_participation, conRep = 1)
fossil_prob_conRep_trump   <- predict_prob(m_wtp_fossil_participation, trump = 1, conRep = 1)
fossil_prob_libDem_control <- predict_prob(m_wtp_fossil_participation, libDem = 1)

fossil_amt_conRep_control <- predict_wtp(m_wtp_fossil_amount, conRep = 1)
fossil_amt_conRep_trump   <- predict_wtp(m_wtp_fossil_amount, trump = 1, conRep = 1)
fossil_amt_libDem_control <- predict_wtp(m_wtp_fossil_amount, libDem = 1)

# Unconditional expected fossil-fuel WTP = P(WTP > $0) x E[WTP | WTP > $0],
# for comparison against the renewables median prediction in the concluding
# paragraph.
predict_expected_fossil <- function(...) {
  p   <- as.numeric(predict(m_wtp_fossil_participation, newdata = predict_newdata(...), type = "response"))
  amt <- as.numeric(predict(m_wtp_fossil_amount, newdata = predict_newdata(...), type = "response"))
  sprintf("%.2f", p * amt)
}
wtp_fossil_conRep_trump <- predict_expected_fossil(trump = 1, conRep = 1)

wtp_renewable_libDem_climate <- predict_wtp(m_wtp_renewable_int, climate = 1, libDem = 1)
wtp_renewable_conRep_control <- predict_wtp(m_wtp_renewable_int, conRep = 1)

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

# Not currently included in the manuscript; kept here in case the figure is
# reinstated. To use again, add a chunk in the qmd that prints wtp_dist_plot
# (fig-cap: "Distribution of willingness-to-pay for fossil fuel and renewable
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
