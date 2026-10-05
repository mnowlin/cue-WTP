#!/usr/bin/env Rscript

# Design checks and additional estimates for cue-WTP.qmd and
# supplemental-materials.qmd. Sourced at the end of manuscript-setup.R, so it
# relies on the data, design, main-text models, coef_map, and helper
# functions defined there and in data-setup.R. Covers:
#   1. Cue-only models (average cue effects, without identity interactions)
#   2. Covariate balance across cue conditions, and whether the
#      political-identity shares (measured after treatment) differ by arm
#   3. Holm-adjusted p-values for the cue x identity interactions
#   4. Minimum detectable effects for the cue x identity interactions
#   5. Censored-normal (Tobit) models of WTP for both sources
#   6. Unweighted versions of the main-text models
#   7. Within-respondent renewables vs. fossil WTP among conservative
#      Republicans in the Trump cue

fmt_p <- function(p) ifelse(p < .001, "< .001", sprintf("= %.3f", p))

# ---- 1. Cue-only models ----------------------------------------------------
# With cue x identity interactions in the model, the cue coefficients are
# effects among the other/moderate reference group only. The average effect
# of each cue on the full sample comes from these models instead.

m_priority_cue <- svyglm(priority.scale ~ trump.cue + climate.cue, design = design)
m_wtp_fossil_participation_cue <- svyglm(
  wtp_fossil_pos ~ trump.cue + climate.cue,
  design = design, family = quasibinomial()
)
m_wtp_fossil_amount_cue <- svyglm(wtp.fossil ~ trump.cue + climate.cue, design = design_fossil_pos)
m_wtp_renewable_cue <- svyglm(wtp.renewable ~ trump.cue + climate.cue, design = design)

cue_only_models <- list(
  "Priority scale (OLS)"                    = m_priority_cue,
  "Fossil fuels: Any WTP (logit)"           = m_wtp_fossil_participation_cue,
  "Fossil fuels: Amount, if WTP > $0 (OLS)" = m_wtp_fossil_amount_cue,
  "Renewables: Amount (OLS)"                = m_wtp_renewable_cue
)

cue_only_tidy <- bind_rows(lapply(names(cue_only_models), function(n) {
  tidy(cue_only_models[[n]]) |> mutate(model = n)
})) |>
  filter(term != "(Intercept)")

# Smallest p-value among the eight cue-only coefficients, for the in-text
# statement that no cue had a significant average effect.
cue_only_min_p <- fmt_p(min(cue_only_tidy$p.value))

avg_priority_trump   <- get_term(cue_only_tidy[cue_only_tidy$model == names(cue_only_models)[1], ], "trump.cue")
avg_priority_climate <- get_term(cue_only_tidy[cue_only_tidy$model == names(cue_only_models)[1], ], "climate.cue")
avg_renew_trump      <- get_term(cue_only_tidy[cue_only_tidy$model == names(cue_only_models)[4], ], "trump.cue")
avg_renew_climate    <- get_term(cue_only_tidy[cue_only_tidy$model == names(cue_only_models)[4], ], "climate.cue")

# ---- 2. Balance across cue conditions ---------------------------------------
# Unweighted means by condition (randomization is checked on the unweighted
# sample) with the p-value from a one-way F-test of each variable on
# condition. Party and ideology were asked after the outcomes, so the identity
# rows also check whether the cues shifted how respondents identified.

d$cue_condition <- factor(
  case_when(
    d$control     == 1 ~ "Baseline",
    d$trump.cue   == 1 ~ "Trump cue",
    d$climate.cue == 1 ~ "Climate cue"
  ),
  levels = cue_levels
)

balance_vars <- c(
  "age"          = "Age",
  "male"         = "Male",
  "white"        = "White",
  "college"      = "College degree",
  "inc"          = "Income (1-11)",
  "concern.cost" = "Concern about electricity cost (0-10)",
  "libDem"       = "Liberal Democrat (post-treatment)",
  "conRep"       = "Conservative Republican (post-treatment)"
)

balance_table <- bind_rows(lapply(names(balance_vars), function(v) {
  means <- tapply(d[[v]], d$cue_condition, mean, na.rm = TRUE)
  f_p   <- anova(lm(d[[v]] ~ d$cue_condition))[["Pr(>F)"]][1]
  tibble::tibble(
    Variable      = balance_vars[[v]],
    Baseline      = means[["Baseline"]],
    `Trump cue`   = means[["Trump cue"]],
    `Climate cue` = means[["Climate cue"]],
    p             = sprintf("%.3f", f_p)
  )
}))

# Joint test of the three-category political identity by condition.
d$identity3 <- case_when(
  d$libDem == 1 ~ "Liberal Democrat",
  d$conRep == 1 ~ "Conservative Republican",
  TRUE          ~ "Other/moderate"
)
identity_arm_test <- chisq.test(table(d$identity3, d$cue_condition))
identity_arm_chi2 <- sprintf("%.2f", unname(identity_arm_test$statistic))
identity_arm_df   <- unname(identity_arm_test$parameter)
identity_arm_p    <- fmt_p(identity_arm_test$p.value)

# ---- 3 and 4. Multiple comparisons and minimum detectable effects ----------
# The 16 cue x identity interaction terms across the four main-text models.
# Holm adjustment across all 16; MDE at 80% power, two-sided alpha = .05,
# is (1.96 + 0.84) x SE.

interaction_terms <- c("trump.cue:libDem", "climate.cue:libDem", "trump.cue:conRep", "climate.cue:conRep")

main_models <- list(
  "Priority scale (OLS)"                    = m_priority_int,
  "Fossil fuels: Any WTP (logit)"           = m_wtp_fossil_participation,
  "Fossil fuels: Amount, if WTP > $0 (OLS)" = m_wtp_fossil_amount,
  "Renewables: Amount (OLS)"                = m_wtp_renewable_int
)

interaction_tests <- bind_rows(lapply(names(main_models), function(n) {
  tidy(main_models[[n]]) |>
    filter(term %in% interaction_terms) |>
    mutate(model = n)
})) |>
  mutate(
    holm = p.adjust(p.value, method = "holm"),
    mde  = (qnorm(.975) + qnorm(.80)) * std.error
  )

n_interaction_tests <- nrow(interaction_tests)

interaction_tests_table <- interaction_tests |>
  transmute(
    Model      = model,
    Term       = recode(term, !!!term_labels),
    b          = sprintf("%.2f", estimate),
    SE         = sprintf("%.2f", std.error),
    p          = sprintf("%.3f", p.value),
    `Holm p`   = sprintf("%.3f", holm),
    MDE        = sprintf("%.2f", mde)
  )

holm_priority_trump_conRep   <- sprintf("%.2f", interaction_tests$holm[interaction_tests$model == names(main_models)[1] & interaction_tests$term == "trump.cue:conRep"])
holm_priority_climate_libDem <- sprintf("%.2f", interaction_tests$holm[interaction_tests$model == names(main_models)[1] & interaction_tests$term == "climate.cue:libDem"])

mde_range <- function(model_name, digits = 2) {
  x <- interaction_tests$mde[interaction_tests$model == model_name]
  paste0(sprintf(paste0("%.", digits, "f"), min(x)), " to ", sprintf(paste0("%.", digits, "f"), max(x)))
}
mde_priority  <- mde_range(names(main_models)[1])
mde_fossil    <- mde_range(names(main_models)[3])
mde_renewable <- mde_range(names(main_models)[4])

# ---- 5. Censored-normal (Tobit) WTP models ---------------------------------
# The Gabor-Granger bids cap WTP at $0 (rejected the $1 bid) and $46
# (accepted the highest bid). The starting bid and the follow-up bids were
# random and not recorded, so the upper bound for an interior response is
# unknown. Interior values are treated as observed, $0 as left-censored, and
# $46 as right-censored, using the same model for both sources.

censor_bounds <- function(y) {
  list(lo = ifelse(y == 0, NA, y), hi = ifelse(y == 46, NA, y))
}
fossil_bounds    <- censor_bounds(d$wtp.fossil)
renewable_bounds <- censor_bounds(d$wtp.renewable)

design_tobit <- update(
  design,
  fossil_lo = fossil_bounds$lo, fossil_hi = fossil_bounds$hi,
  renewable_lo = renewable_bounds$lo, renewable_hi = renewable_bounds$hi
)

m_tobit_fossil <- svysurvreg(
  Surv(fossil_lo, fossil_hi, type = "interval2") ~ (trump.cue + climate.cue) * (libDem + conRep),
  design = design_tobit, dist = "gaussian"
)
m_tobit_renewable <- svysurvreg(
  Surv(renewable_lo, renewable_hi, type = "interval2") ~ (trump.cue + climate.cue) * (libDem + conRep),
  design = design_tobit, dist = "gaussian"
)

tobit_tidy <- bind_rows(
  tidy(m_tobit_fossil) |> mutate(outcome = "Fossil fuels"),
  tidy(m_tobit_renewable) |> mutate(outcome = "Renewables")
) |>
  filter(!term %in% c("(Intercept)", "Log(scale)"))

tobit_fossil_trump        <- get_term(tobit_tidy, "trump.cue", "Fossil fuels")
tobit_fossil_trump_conRep <- get_term(tobit_tidy, "trump.cue:conRep", "Fossil fuels")
tobit_renewable_sig_n     <- sum(tobit_tidy$outcome == "Renewables" &
                                   tobit_tidy$term %in% interaction_terms &
                                   tobit_tidy$p.value < .05)

# Within-group shift for conservative Republicans (Trump cue vs. control) in
# the fossil Tobit, using a normal reference distribution.
tobit_shift <- function(model, cue, identity) {
  b <- coef(model)
  L <- setNames(rep(0, length(b)), names(b))
  L[c(cue, paste0(cue, ":", identity))] <- 1
  V <- vcov(model)[names(b), names(b)]
  est <- sum(L * b)
  se  <- sqrt(as.numeric(t(L) %*% V %*% L))
  list(b = sprintf("%.2f", est), p = fmt_p(2 * pnorm(-abs(est / se))))
}
tobit_shift_fossil_trump_conRep <- tobit_shift(m_tobit_fossil, "trump.cue", "conRep")

# Holm-adjusted p for the fossil Tobit interaction, adjusting across the 16
# main-text interaction tests plus this one.
tobit_fossil_trump_conRep_holm <- sprintf(
  "%.2f",
  tail(p.adjust(c(interaction_tests$p.value,
                  tobit_tidy$p.value[tobit_tidy$outcome == "Fossil fuels" & tobit_tidy$term == "trump.cue:conRep"]),
                method = "holm"), 1)
)

# ---- 6. Unweighted main-text models ----------------------------------------
# The weights roughly double the share of conservative Republicans, so the
# main-text models are re-estimated with equal weights.

d$unit_weight <- 1
design_unw <- svydesign(ids = ~1, weights = ~unit_weight, data = d)
design_unw_fossil_pos <- subset(design_unw, wtp_fossil_pos == 1)

m_priority_unw <- svyglm(
  priority.scale ~ (trump.cue + climate.cue) * (libDem + conRep),
  design = design_unw
)
m_wtp_fossil_participation_unw <- svyglm(
  wtp_fossil_pos ~ (trump.cue + climate.cue) * (libDem + conRep),
  design = design_unw, family = quasibinomial()
)
m_wtp_fossil_amount_unw <- svyglm(
  wtp.fossil ~ (trump.cue + climate.cue) * (libDem + conRep),
  design = design_unw_fossil_pos
)
m_wtp_renewable_unw <- svyglm(
  wtp.renewable ~ (trump.cue + climate.cue) * (libDem + conRep),
  design = design_unw
)

unw_tidy <- tidy(m_priority_unw)
unw_priority_trump_conRep   <- get_term(unw_tidy, "trump.cue:conRep")
unw_priority_climate_libDem <- get_term(unw_tidy, "climate.cue:libDem")

# ---- 7. Renewables vs. fossil WTP, conservative Republicans in Trump cue ----
# Survey-weighted paired comparison within the subgroup.

conRep_trump_diff_test <- svyttest(wtp_diff ~ 0, subset(design, conRep == 1 & trump.cue == 1))
conRep_trump_diff_b <- sprintf("%.2f", unname(conRep_trump_diff_test$estimate))
conRep_trump_diff_p <- fmt_p(conRep_trump_diff_test$p.value)
