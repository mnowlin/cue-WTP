#!/usr/bin/env Rscript

# Model fitting for supplemental-materials.qmd.
# Sources data-setup.R for the data/design/descriptive objects shared with
# cue-WTP.qmd, then refits the same cue condition x political identity
# models as the main text, additionally controlling for concern about the
# cost of electricity (concern.cost, 0-10 scale). This is a robustness check
# on the main-text specification (scripts/manuscript-setup.R), which omits
# this control; coefficients, significance, and substantive conclusions are
# consistent across both specifications.

source("scripts/data-setup.R")

# Demographic + cost-concern controls included in the interaction models but
# excluded from the coefficient plots.
control_vars <- c("concern.cost", "age", "male", "white", "edu", "inc")
control_rhs  <- paste(control_vars, collapse = " + ")

# Regression-table labels (term_labels from data-setup.R plus concern.cost
# and the demographic controls) and display settings, shared by the
# modelsummary() tables below.
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

# ---- Priority scale OLS: cues x political beliefs -----------------------

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
# Same two-part (Cragg) hurdle model for fossil-fuel WTP as the main text
# (see manuscript-setup.R for the rationale); single OLS for renewables.

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

wtp_libDem_renewable         <- get_term(wtp_int_tidy, "libDem", "Renewables")
wtp_climate_libDem_renewable <- get_term(wtp_int_tidy, "climate.cue:libDem", "Renewables")
wtp_conRep_renewable         <- get_term(wtp_int_tidy, "conRep", "Renewables")

# ---- Predicted-value grids, for plots --------------------------------------
# Controls (including concern.cost) held at their survey-weighted means.

control_means <- setNames(
  sapply(control_vars, function(v) unname(coef(svymean(as.formula(paste0("~", v)), design)))),
  control_vars
)

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

# ---- Terms significant at p <= .10, for in-text write-up ------------------

priority_sig <- priority_int_tidy[priority_int_tidy$p.value <= 0.10, ]
priority_sig <- priority_sig[order(priority_sig$p.value), ]
priority_sig_bullets <- sprintf(
  "- %s: b = %.2f, *p* = %.3f",
  priority_sig$term_label, priority_sig$estimate, priority_sig$p.value
)
