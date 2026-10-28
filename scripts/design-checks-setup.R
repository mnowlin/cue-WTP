#!/usr/bin/env Rscript

# Design checks and additional estimates for cue-WTP.qmd and
# supplemental-materials.qmd. Sourced at the end of manuscript-setup.R, so it
# relies on the data, design, main-text models, coef_map, and helper
# functions defined there and in data-setup.R. Covers:
#   1. Cue-only models (average cue effects, without identity interactions)
#   2. Covariate balance across cue conditions, and whether the
#      political-identity shares (measured after treatment) differ by arm
#   3. Minimum detectable effects for the cue x identity interactions
#   4. Censored-normal (Tobit) models of WTP for both sources
#   5. Unweighted versions of the main-text models, and party-only vs.
#      demographic-only weights
#   6. Within-respondent renewables vs. fossil WTP among conservative
#      Republicans in the Trump cue

fmt_p <- function(p) ifelse(p < .001, "< .001", sub("0.", ".", sprintf("= %.3f", p), fixed = TRUE))

# ---- 1. Cue-only models ----------------------------------------------------
# With cue x identity interactions in the model, the cue coefficients are
# effects among the independent reference group only. The average effect
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
# condition. Party was asked after the outcomes, so the identity
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
  "democrat"     = "Democrat (post-treatment)",
  "republican"   = "Republican (post-treatment)"
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
  d$democrat == 1 ~ "Democrat",
  d$republican == 1 ~ "Republican",
  TRUE          ~ "Independent"
)
identity_arm_test <- chisq.test(table(d$identity3, d$cue_condition))
identity_arm_chi2 <- sprintf("%.2f", unname(identity_arm_test$statistic))
identity_arm_df   <- unname(identity_arm_test$parameter)
identity_arm_p    <- fmt_p(identity_arm_test$p.value)

# ---- 3. Minimum detectable effects -------------------------------------------
# The 16 cue x identity interaction terms across the four main-text models.
# MDE at 80% power, two-sided alpha = .05, is (1.96 + 0.84) x SE.

interaction_terms <- c("trump.cue:democrat", "climate.cue:democrat", "trump.cue:republican", "climate.cue:republican")

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
  mutate(mde = (qnorm(.975) + qnorm(.80)) * std.error)

n_interaction_tests <- nrow(interaction_tests)

interaction_tests_table <- interaction_tests |>
  transmute(
    Model      = model,
    Term       = recode(term, !!!term_labels),
    b          = sprintf("%.2f", estimate),
    SE         = sprintf("%.2f", std.error),
    p          = sprintf("%.3f", p.value),
    MDE        = sprintf("%.2f", mde)
  )

mde_range <- function(model_name, digits = 2) {
  x <- interaction_tests$mde[interaction_tests$model == model_name]
  paste0(sprintf(paste0("%.", digits, "f"), min(x)), " to ", sprintf(paste0("%.", digits, "f"), max(x)))
}
mde_priority  <- mde_range(names(main_models)[1])
mde_fossil    <- mde_range(names(main_models)[3])
mde_renewable <- mde_range(names(main_models)[4])

# ---- 4. Censored-normal (Tobit) WTP models ---------------------------------
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
  Surv(fossil_lo, fossil_hi, type = "interval2") ~ (trump.cue + climate.cue) * (democrat + republican),
  design = design_tobit, dist = "gaussian"
)
m_tobit_renewable <- svysurvreg(
  Surv(renewable_lo, renewable_hi, type = "interval2") ~ (trump.cue + climate.cue) * (democrat + republican),
  design = design_tobit, dist = "gaussian"
)

tobit_tidy <- bind_rows(
  tidy(m_tobit_fossil) |> mutate(outcome = "Fossil fuels"),
  tidy(m_tobit_renewable) |> mutate(outcome = "Renewables")
) |>
  filter(!term %in% c("(Intercept)", "Log(scale)"))

tobit_fossil_trump            <- get_term(tobit_tidy, "trump.cue", "Fossil fuels")
tobit_fossil_climate          <- get_term(tobit_tidy, "climate.cue", "Fossil fuels")
tobit_fossil_trump_republican <- get_term(tobit_tidy, "trump.cue:republican", "Fossil fuels")
tobit_renewable_sig_n         <- sum(tobit_tidy$outcome == "Renewables" &
                                   tobit_tidy$term %in% interaction_terms &
                                   tobit_tidy$p.value < .05)

# Within-group shift for Republicans (Trump cue vs. control) in
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
tobit_shift_fossil_trump_republican <- tobit_shift(m_tobit_fossil, "trump.cue", "republican")
tobit_fossil_climate_republican       <- get_term(tobit_tidy, "climate.cue:republican", "Fossil fuels")
tobit_shift_fossil_climate_republican <- tobit_shift(m_tobit_fossil, "climate.cue", "republican")
tobit_renewable_climate_democrat      <- get_term(tobit_tidy, "climate.cue:democrat", "Renewables")

# ---- 5. Unweighted main-text models ----------------------------------------
# The weights raise the share of Republicans from 29 to 46 percent, so the
# main-text models are re-estimated with equal weights.

d$unit_weight <- 1
design_unw <- svydesign(ids = ~1, weights = ~unit_weight, data = d)
design_unw_fossil_pos <- subset(design_unw, wtp_fossil_pos == 1)

m_priority_unw <- svyglm(
  priority.scale ~ (trump.cue + climate.cue) * (democrat + republican),
  design = design_unw
)
m_wtp_fossil_participation_unw <- svyglm(
  wtp_fossil_pos ~ (trump.cue + climate.cue) * (democrat + republican),
  design = design_unw, family = quasibinomial()
)
m_wtp_fossil_amount_unw <- svyglm(
  wtp.fossil ~ (trump.cue + climate.cue) * (democrat + republican),
  design = design_unw_fossil_pos
)
m_wtp_renewable_unw <- svyglm(
  wtp.renewable ~ (trump.cue + climate.cue) * (democrat + republican),
  design = design_unw
)

unw_tidy                      <- tidy(m_priority_unw)
unw_priority_trump_republican <- get_term(unw_tidy, "trump.cue:republican")
unw_priority_climate_democrat <- get_term(unw_tidy, "climate.cue:democrat")

# Cue x party interactions significant at p <= .10 in the unweighted WTP
# models, for the in-text list in the supplemental materials.
unw_wtp_sig <- bind_rows(
  tidy(m_wtp_fossil_participation_unw) |> mutate(model = "Fossil fuels, any WTP (logit)"),
  tidy(m_wtp_fossil_amount_unw) |> mutate(model = "Fossil fuels, amount if WTP > $0"),
  tidy(m_wtp_renewable_unw) |> mutate(model = "Renewables, amount")
) |>
  filter(term %in% interaction_terms, p.value <= 0.10)
unw_wtp_sig_bullets <- paste(sprintf(
  "- %s, %s: b = %.2f, *p* = %s",
  recode(unw_wtp_sig$term, !!!term_labels), unw_wtp_sig$model, unw_wtp_sig$estimate, sub("^0", "", sprintf("%.3f", unw_wtp_sig$p.value))
), collapse = "\n")

# ---- 5b. Party-only vs. demographic-only weights ---------------------------
# The full weights rake to ACS demographics and NPORS party ID. To see which
# part drives the weighted/unweighted differences, the unweighted sample is
# raked separately to (a) the NPORS party targets only and (b) the
# demographic margins only. The raking script and ACS targets are not in
# this repo, so the demographic targets are the margins the full weights
# produce for age group, gender, race, and education. Because the models
# fully interact the cues with party ID, party-only weights (constant within
# party) leave the interaction estimates unchanged from the unweighted ones.

d$party_cat <- factor(ifelse(d$democrat == 1, "Dem", ifelse(d$republican == 1, "Rep", "Ind")))
d$age_cat   <- cut(d$age, c(17, 29, 44, 64, Inf))
d$male_cat  <- factor(d$male)
d$white_cat <- factor(d$white)
d$edu_cat   <- factor(d$edu)

full_margin <- function(v) {
  t <- tapply(d$weight, d[[v]], sum)
  data.frame(setNames(list(names(t)), v), Freq = nrow(d) * as.numeric(t) / sum(t))
}

design_base <- svydesign(ids = ~1, weights = ~unit_weight, data = d)
party_pop <- data.frame(
  party_cat = names(pid_target_pct),
  Freq      = nrow(d) * unname(pid_target_pct) / sum(pid_target_pct)
)
d$party_weight <- weights(rake(design_base, list(~party_cat), list(party_pop)))
demo_vars <- c("age_cat", "male_cat", "white_cat", "edu_cat")
d$demo_weight <- weights(rake(
  design_base,
  lapply(demo_vars, function(v) as.formula(paste0("~", v))),
  lapply(demo_vars, full_margin),
  control = list(maxit = 100)
))

weight_schemes <- c(
  "Full weights"      = "weight",
  "Party only"        = "party_weight",
  "Demographics only" = "demo_weight",
  "Unweighted"        = "unit_weight"
)

weight_comparison <- bind_rows(lapply(names(weight_schemes), function(s) {
  des <- svydesign(ids = ~1, weights = as.formula(paste0("~", weight_schemes[[s]])), data = d)
  models <- list(
    "Priority scale (OLS)" = svyglm(
      priority.scale ~ (trump.cue + climate.cue) * (democrat + republican), design = des
    ),
    "Fossil fuels: Any WTP (logit)" = svyglm(
      wtp_fossil_pos ~ (trump.cue + climate.cue) * (democrat + republican),
      design = des, family = quasibinomial()
    ),
    "Fossil fuels: Amount, if WTP > $0 (OLS)" = svyglm(
      wtp.fossil ~ (trump.cue + climate.cue) * (democrat + republican),
      design = subset(des, wtp_fossil_pos == 1)
    ),
    "Renewables: Amount (OLS)" = svyglm(
      wtp.renewable ~ (trump.cue + climate.cue) * (democrat + republican), design = des
    )
  )
  bind_rows(lapply(names(models), function(n) {
    tidy(models[[n]]) |>
      filter(term %in% interaction_terms) |>
      mutate(model = n, scheme = s)
  }))
}))

# Short labels so the six-column table fits the page width.
weight_comparison_table <- weight_comparison |>
  mutate(
    cell   = sprintf("%.2f (%.3f)", estimate, p.value),
    # Non-breaking spaces (\u00a0) keep each term label on one line in the PDF.
    Term   = recode(term,
      "trump.cue:democrat"     = "Trump\u00a0×\u00a0Dem",
      "trump.cue:republican"   = "Trump\u00a0×\u00a0Rep",
      "climate.cue:democrat"   = "Climate\u00a0×\u00a0Dem",
      "climate.cue:republican" = "Climate\u00a0×\u00a0Rep"
    ),
    model  = recode(model,
      "Priority scale (OLS)"                    = "Priority",
      "Fossil fuels: Any WTP (logit)"           = "Fossil: any",
      "Fossil fuels: Amount, if WTP > $0 (OLS)" = "Fossil: amount",
      "Renewables: Amount (OLS)"                = "Renewables"
    ),
    scheme = recode(scheme,
      "Full weights"      = "Full",
      "Party only"        = "Party",
      "Demographics only" = "Demog.",
      "Unweighted"        = "None"
    )
  ) |>
  select(Model = model, Term, scheme, cell) |>
  tidyr::pivot_wider(names_from = scheme, values_from = cell)

weight_term <- function(scheme, model_n, term) {
  r <- weight_comparison[weight_comparison$scheme == scheme &
                           weight_comparison$model == names(main_models)[model_n] &
                           weight_comparison$term == term, ]
  list(b = sprintf("%.2f", r$estimate), p = fmt_p(r$p.value))
}
demo_priority_trump_republican  <- weight_term("Demographics only", 1, "trump.cue:republican")
party_priority_trump_republican <- weight_term("Party only", 1, "trump.cue:republican")

# ---- 6. Renewables vs. fossil WTP, Republicans in Trump cue ----
# Survey-weighted paired comparison within the subgroup.

republican_trump_diff_test <- svyttest(wtp_diff ~ 0, subset(design, republican == 1 & trump.cue == 1))
republican_trump_diff_b <- sprintf("%.2f", unname(republican_trump_diff_test$estimate))
republican_trump_diff_p <- fmt_p(republican_trump_diff_test$p.value)

# ---- 7. Cost concern by cue, within party ------------------------------------
# Does the cue weaken the effect of concern about electricity cost among the
# cue-congruent party? Estimated separately for Republicans (Trump cue,
# fossil-fuel WTP amount among those with WTP > $0) and Democrats (climate
# cue, renewables WTP), with cost concern interacted with both cues and
# demographic controls. Reported in a footnote to the cost discussion.

cost_slopes <- function(des, y, cue) {
  m <- svyglm(
    as.formula(paste(y, "~ (trump.cue + climate.cue) * concern.cost + age + male + white + edu + inc")),
    design = des
  )
  b <- coef(m)
  slope <- function(terms) {
    L <- setNames(rep(0, length(b)), names(b))
    L[terms] <- 1
    est <- sum(L * b)
    se  <- sqrt(as.numeric(t(L) %*% vcov(m) %*% L))
    list(b = sprintf("%.2f", est), p = fmt_p(2 * pt(-abs(est / se), df = m$df.residual)))
  }
  list(
    baseline = slope("concern.cost"),
    cue      = slope(c("concern.cost", paste0(cue, ":concern.cost"))),
    diff     = slope(paste0(cue, ":concern.cost"))
  )
}

cost_slopes_rep_fossil <- cost_slopes(subset(design_fossil_pos, republican == 1), "wtp.fossil", "trump.cue")
cost_slopes_dem_renew  <- cost_slopes(subset(design, democrat == 1), "wtp.renewable", "climate.cue")
