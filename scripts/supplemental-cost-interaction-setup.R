#!/usr/bin/env Rscript

# Model fitting for supplemental-materials.qmd.
# Sources data-setup.R for the data/design/descriptive objects shared with
# cue-WTP.qmd, then extends the demographics-controlled models in
# supplemental-setup.R by interacting concern about the cost of electricity
# (concern.cost, 0-10 scale) with the cue conditions and with political
# identity, on top of the demographic controls (age, male, white, education,
# income). This tests whether the cost-concern effect documented in the
# prior robustness check (where concern.cost enters only additively) itself
# varies by cue condition or political identity.

source("scripts/data-setup.R")

control_vars <- c("age", "male", "white", "edu", "inc")
control_rhs  <- paste(control_vars, collapse = " + ")

# Regression-table labels for this section's modelsummary() tables.
coef_map <- c(
  term_labels,
  "concern.cost"              = "Concern about energy cost",
  "trump.cue:concern.cost"    = "Trump cue × Concern about energy cost",
  "climate.cue:concern.cost"  = "Climate cue × Concern about energy cost",
  "libDem:concern.cost"       = "Concern about energy cost × Liberal Democrat",
  "conRep:concern.cost"       = "Concern about energy cost × Conservative Republican",
  "age"                       = "Age",
  "male"                      = "Male",
  "white"                     = "White",
  "edu"                       = "Education",
  "inc"                       = "Income",
  "(Intercept)"               = "(Intercept)"
)

rhs <- paste(
  "(trump.cue + climate.cue) * (libDem + conRep) +",
  "concern.cost * (trump.cue + climate.cue + libDem + conRep) +",
  control_rhs
)

# ---- Priority scale OLS: cues x political beliefs x concern.cost ----------

m_priority_int <- svyglm(as.formula(paste("priority.scale ~", rhs)), design = design)

# ---- WTP ~ cue condition x political beliefs x concern.cost ---------------
# Same two-part (Cragg) hurdle model for fossil-fuel WTP as the main text
# (see manuscript-setup.R for the rationale); single OLS for renewables.

m_wtp_fossil_participation <- svyglm(
  as.formula(paste("wtp_fossil_pos ~", rhs)),
  design = design, family = quasibinomial()
)

m_wtp_fossil_amount <- svyglm(
  as.formula(paste("wtp.fossil ~", rhs)),
  design = design_fossil_pos
)

m_wtp_renewable_int <- svyglm(
  as.formula(paste("wtp.renewable ~", rhs)),
  design = design
)

# ---- Concern.cost terms, for in-text write-up ------------------------------

priority_tidy    <- tidy(m_priority_int, conf.int = TRUE)
fossil_part_tidy <- tidy(m_wtp_fossil_participation, conf.int = TRUE)
fossil_amt_tidy  <- tidy(m_wtp_fossil_amount, conf.int = TRUE)
renewable_tidy   <- tidy(m_wtp_renewable_int, conf.int = TRUE)

get_term <- function(tidy_df, term_name) {
  row <- tidy_df[tidy_df$term == term_name, ]
  list(
    b     = sprintf("%.2f", row$estimate),
    b_abs = sprintf("%.2f", abs(row$estimate)),
    p     = ifelse(row$p.value < .001, "< .001", sprintf("= %.3f", row$p.value))
  )
}

priority_cost        <- get_term(priority_tidy, "concern.cost")
priority_conRep_cost <- get_term(priority_tidy, "conRep:concern.cost")
priority_libDem_cost <- get_term(priority_tidy, "libDem:concern.cost")

fossil_part_cost        <- get_term(fossil_part_tidy, "concern.cost")
fossil_part_libDem_cost <- get_term(fossil_part_tidy, "libDem:concern.cost")
fossil_part_conRep_cost <- get_term(fossil_part_tidy, "conRep:concern.cost")

fossil_amt_cost       <- get_term(fossil_amt_tidy, "concern.cost")
fossil_amt_trump_cost <- get_term(fossil_amt_tidy, "trump.cue:concern.cost")

# ---- concern.cost terms significant at p <= .10, per model, for write-up --

cost_terms <- c(
  "concern.cost", "trump.cue:concern.cost", "climate.cue:concern.cost",
  "libDem:concern.cost", "conRep:concern.cost"
)

cost_sig_bullets <- function(tidy_df) {
  sig <- tidy_df[tidy_df$term %in% cost_terms & tidy_df$p.value <= 0.10, ]
  sig <- sig[order(sig$p.value), ]
  if (nrow(sig) == 0) return("- None of the concern-about-cost terms were significant at *p* $\\leq$ .10.")
  sig$term_label <- recode(sig$term, !!!coef_map)
  sprintf("- %s: b = %.2f, *p* = %.3f", sig$term_label, sig$estimate, sig$p.value)
}

priority_cost_sig_bullets    <- paste(cost_sig_bullets(priority_tidy), collapse = "\n")
fossil_part_cost_sig_bullets <- paste(cost_sig_bullets(fossil_part_tidy), collapse = "\n")
fossil_amt_cost_sig_bullets  <- paste(cost_sig_bullets(fossil_amt_tidy), collapse = "\n")
renewable_cost_sig_bullets   <- paste(cost_sig_bullets(renewable_tidy), collapse = "\n")
