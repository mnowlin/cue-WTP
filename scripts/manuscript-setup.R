#!/usr/bin/env Rscript

# Model fitting for cue-WTP.qmd.
# Sources data-setup.R for the data/design/descriptive objects shared with
# supplemental-materials.qmd, then fits the main-text models: cue condition x
# political identity, controlling for demographics only. A parallel
# specification that additionally controls for concern about the cost of
# electricity is reported in Supplemental Materials as a robustness check
# (see scripts/supplemental-setup.R); the substantive results are consistent
# across both specifications.

source("scripts/data-setup.R")

# Demographic controls included in the interaction models but excluded from
# the coefficient plots.
control_vars <- c("age", "male", "white", "edu", "inc")
control_rhs  <- paste(control_vars, collapse = " + ")

# Regression-table labels (term_labels from data-setup.R plus the
# demographic controls) and display settings, shared by the modelsummary()
# tables below.
coef_map <- c(
  term_labels,
  "age"          = "Age",
  "male"         = "Male",
  "white"        = "White",
  "edu"          = "Education",
  "inc"          = "Income",
  "(Intercept)"  = "(Intercept)"
)

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
# Predictions hold the demographic controls at their survey-weighted means
# and vary only the cue and political-identity indicators referenced in the
# write-up.

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

# Predicted priority-scale values for specific cue/identity combinations,
# for in-text reporting alongside the coefficients above.
priority_conRep_control_pred <- predict_wtp(m_priority_int, conRep = 1)
priority_conRep_trump_pred   <- predict_wtp(m_priority_int, trump = 1, conRep = 1)
priority_libDem_control_pred <- predict_wtp(m_priority_int, libDem = 1)
priority_libDem_climate_pred <- predict_wtp(m_priority_int, climate = 1, libDem = 1)

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
