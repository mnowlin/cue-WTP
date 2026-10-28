#!/usr/bin/env Rscript

# Builds data/cueWTPDataWeighted.csv, the analysis dataset for cue-WTP.qmd and
# supplemental-materials.qmd, from the merged raw survey file for all three
# conditions (data/merged-all-three.csv, not shared because it contains
# respondent metadata).
#
# Recodes the variables used in this project and computes raking weights to
# ACS demographic margins (age, sex, white non-Hispanic, college) and NPORS
# party identification (leaners assigned to a party). Adapted from the
# shared make-datasets.R for the energy preferences survey, keeping only the
# steps needed for this dataset; the weights are computed on the full sample,
# so they are identical to that script's.
#
# Requires a Census API key in the CENSUS_API_KEY environment variable
# (see tidycensus::census_api_key()).
#
# Run from the project root: Rscript scripts/make-dataset.R

library(dplyr)
library(tidyr)
library(anesrake)
library(tidycensus)

# ---- 1. Load data -----------------------------------------------------------

energyPrefs <- read.csv("data/merged-all-three.csv")

# ---- 2. Recodes -------------------------------------------------------------

energyPrefs[energyPrefs == "0 (Not at all concerned)"] <- 0
energyPrefs[energyPrefs == "10 (Extremely concerned)"] <- 10

energyPrefs[energyPrefs == "1 (Prioritize fossil fuels)"] <- 1
energyPrefs[energyPrefs == "4 (Prioritize fossil fuels and renewable sources equally)"] <- 4
energyPrefs[energyPrefs == "7 (Prioritize renewable sources)"] <- 7

energyPrefs[energyPrefs == "Strongly disapprove"] <- 1
energyPrefs[energyPrefs == "Disapprove"] <- 2
energyPrefs[energyPrefs == "Neither approve nor disapprove"] <- 3
energyPrefs[energyPrefs == "Approve"] <- 4
energyPrefs[energyPrefs == "Strongly approve"] <- 5

energyPrefs[energyPrefs == "Strongly liberal"] <- 1
energyPrefs[energyPrefs == "Liberal"] <- 2
energyPrefs[energyPrefs == "Slightly liberal"] <- 3
energyPrefs[energyPrefs == "Middle of the road"] <- 4
energyPrefs[energyPrefs == "Slightly conservative"] <- 5
energyPrefs[energyPrefs == "Conservative"] <- 6
energyPrefs[energyPrefs == "Strongly conservative"] <- 7

# Party identification, with leaners assigned to a party
energyPrefs$democrat <- ifelse(energyPrefs$party.id == "Democratic Party" | energyPrefs$party.lean == "Democratic Party", 1, 0)
energyPrefs$republican <- ifelse(energyPrefs$party.id == "Republican Party (or GOP)" | energyPrefs$party.lean == "Republican Party (or GOP)", 1, 0)

energyPrefs$libDem <- ifelse(
  (energyPrefs$party.id == "Democratic Party" | energyPrefs$party.lean == "Democratic Party") &
    energyPrefs$ideology %in% c(1, 2, 3),
  1, 0
)

energyPrefs$conRep <- ifelse(
  (energyPrefs$party.id == "Republican Party (or GOP)" | energyPrefs$party.lean == "Republican Party (or GOP)") &
    energyPrefs$ideology %in% c(5, 6, 7),
  1, 0
)

energyPrefs$male <- ifelse(energyPrefs$sex == "Male", 1, 0)
energyPrefs$white <- ifelse(energyPrefs$race == "Caucasian or White", 1, 0)

energyPrefs$edu[energyPrefs$education == "High school"] <- 1
energyPrefs$edu[energyPrefs$education == "Some college"] <- 2
energyPrefs$edu[energyPrefs$education == "Trade/vocational/technical"] <- 3
energyPrefs$edu[energyPrefs$education == "Associates"] <- 4
energyPrefs$edu[energyPrefs$education == "Bachelors"] <- 5
energyPrefs$edu[energyPrefs$education == "Masters"] <- 6
energyPrefs$edu[energyPrefs$education == "Professional"] <- 7
energyPrefs$edu[energyPrefs$education == "Doctorate"] <- 8

energyPrefs$college <- ifelse(energyPrefs$edu >= 5, 1, 0)

# Respondents who rejected the $1 minimum have no accepted amount: WTP = $0
energyPrefs$wtp.fossil[is.na(energyPrefs$wtp.fossil)] <- 0
energyPrefs$wtp.renewable[is.na(energyPrefs$wtp.renewable)] <- 0

energyPrefs$inc[energyPrefs$income == "Less than $19,999"] <- 1
energyPrefs$inc[energyPrefs$income == "$20,000 to $39,999"] <- 2
energyPrefs$inc[energyPrefs$income == "$40,000 to $59,999"] <- 3
energyPrefs$inc[energyPrefs$income == "$60,000 to $79,999"] <- 4
energyPrefs$inc[energyPrefs$income == "$80,000 to $99,999"] <- 5
energyPrefs$inc[energyPrefs$income == "$100,000 to $119,999"] <- 6
energyPrefs$inc[energyPrefs$income == "$120,000 to $139,999"] <- 7
energyPrefs$inc[energyPrefs$income == "$140,000 to $159,999"] <- 8
energyPrefs$inc[energyPrefs$income == "$160,000 to $179,999"] <- 9
energyPrefs$inc[energyPrefs$income == "$180,000 to $199,999"] <- 10
energyPrefs$inc[energyPrefs$income == "Above $200,000"] <- 11

energyPrefs <- energyPrefs %>%
  mutate(across(c(concern.cost, priority.scale, trump.approval, ideology, libDem, conRep,
                  male, white, edu, college, wtp.fossil, wtp.renewable), as.numeric))

# anesrake loads Hmisc, which masks summarize(), so dplyr verbs are
# namespaced below.

# ---- 3. Population targets --------------------------------------------------
# Weighting for age, race, gender, college education, and partisanship

ACS_YEAR   <- 2023      # most recent 1-year ACS available
ACS_SURVEY <- "acs1"
GEOGRAPHY  <- "us"

# ----- 3a. Age x sex, adults 18+ (Table B01001) -----
# Male age bands 18+:   B01001_007 through _025
# Female age bands 18+: B01001_031 through _049
male_vars <- sprintf("B01001_%03d",  7:25)
fem_vars  <- sprintf("B01001_%03d", 31:49)

age_sex_raw <- get_acs(
  geography = GEOGRAPHY,
  variables = c(male_vars, fem_vars),
  year      = ACS_YEAR,
  survey    = ACS_SURVEY
)

bands <- c("18-19","20","21","22-24","25-29","30-34","35-39","40-44",
           "45-49","50-54","55-59","60-61","62-64","65-66","67-69",
           "70-74","75-79","80-84","85+")

var_lookup <- c(setNames(rep("Male",   length(male_vars)), male_vars),
                setNames(rep("Female", length(fem_vars)),  fem_vars))
band_lookup <- c(setNames(bands, male_vars),
                 setNames(bands, fem_vars))

age_sex <- age_sex_raw %>%
  mutate(sex  = var_lookup[variable],
         band = band_lookup[variable]) %>%
  select(sex, band, estimate)

# Collapse to 4 age categories
band_to_cat <- c(
  "18-19"="18-29","20"="18-29","21"="18-29","22-24"="18-29","25-29"="18-29",
  "30-34"="30-44","35-39"="30-44","40-44"="30-44",
  "45-49"="45-64","50-54"="45-64","55-59"="45-64",
  "60-61"="45-64","62-64"="45-64",
  "65-66"="65+","67-69"="65+","70-74"="65+",
  "75-79"="65+","80-84"="65+","85+"="65+"
)

age_sex <- age_sex %>%
  dplyr::mutate(age_cat = band_to_cat[band]) %>%
  dplyr::group_by(sex, age_cat) %>%
  dplyr::summarize(n = sum(estimate), .groups = "drop")

total_adult <- sum(age_sex$n)

age_target <- age_sex %>%
  dplyr::group_by(age_cat) %>%
  dplyr::summarize(p = sum(n) / total_adult, .groups = "drop")
age_target_vec <- setNames(age_target$p, age_target$age_cat)
age_target_vec <- age_target_vec[c("18-29","30-44","45-64","65+")]

sex_target <- age_sex %>%
  dplyr::group_by(sex) %>%
  dplyr::summarize(p = sum(n) / total_adult, .groups = "drop")
male_target_vec <- c(
  "0" = sex_target$p[sex_target$sex == "Female"],
  "1" = sex_target$p[sex_target$sex == "Male"]
)

# ----- 3b. White non-Hispanic, adults 18+ (Table B01001H) -----
# Adult bands in B01001H: male _007-_016, female _022-_031
wnh_male <- sprintf("B01001H_%03d",  7:16)
wnh_fem  <- sprintf("B01001H_%03d", 22:31)

wnh_raw <- get_acs(
  geography = GEOGRAPHY,
  variables = c(wnh_male, wnh_fem),
  year      = ACS_YEAR,
  survey    = ACS_SURVEY
)
wnh_total <- sum(wnh_raw$estimate)

white_target_vec <- c(
  "0" = 1 - wnh_total / total_adult,
  "1" =     wnh_total / total_adult
)

# ----- 3c. College education, adults 25+ (Table B15002) -----
# College+ = Bachelor's, Master's, Professional, Doctorate
# Male:   _015, _016, _017, _018  (total male 25+ = _002)
# Female: _032, _033, _034, _035  (total female 25+ = _019)
educ_vars <- c("B15002_015","B15002_016","B15002_017","B15002_018",
               "B15002_032","B15002_033","B15002_034","B15002_035",
               "B15002_002","B15002_019")

educ_raw <- get_acs(
  geography = GEOGRAPHY,
  variables = educ_vars,
  year      = ACS_YEAR,
  survey    = ACS_SURVEY
)

educ_wide <- educ_raw %>%
  select(variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate)

college_plus <- with(educ_wide,
                     B15002_015 + B15002_016 + B15002_017 + B15002_018 +
                       B15002_032 + B15002_033 + B15002_034 + B15002_035)
total_25plus <- with(educ_wide, B15002_002 + B15002_019)

# ACS reports educational attainment only for 25+; the 25+ college rate is
# applied to the whole sample.
college_target_vec <- c(
  "0" = 1 - college_plus / total_25plus,
  "1" =     college_plus / total_25plus
)

# ----- 3d. Party ID, from Pew NPORS 2025 (leaners assigned to a party) -----
# https://www.pewresearch.org/politics/fact-sheet/party-affiliation-fact-sheet-npors/
pid_target_vec <- c("Dem" = 0.45, "Rep" = 0.46, "Ind" = 0.09)

rake_targets <- list(
  age_cat   = age_target_vec,
  white_f   = white_target_vec,
  male_f    = male_target_vec,
  college_f = college_target_vec,
  pid3      = pid_target_vec
)

# ---- 4. Recode for weighting ------------------------------------------------

energyPrefsWeighted <- energyPrefs %>%
  mutate(
    age_cat = cut(age, breaks = c(18, 30, 45, 65, Inf),
                  labels = c("18-29", "30-44", "45-64", "65+"),
                  right = FALSE, include.lowest = TRUE),
    white_f   = factor(white,   levels = c(0, 1)),
    male_f    = factor(male,    levels = c(0, 1)),
    college_f = factor(college, levels = c(0, 1)),
    pid3 = factor(
      case_when(
        democrat == 1   ~ "Dem",
        republican == 1 ~ "Rep",
        TRUE            ~ "Ind"
      ),
      levels = c("Dem", "Rep", "Ind")
    )
  )

stopifnot(!any(is.na(energyPrefsWeighted$age_cat)),
          !any(is.na(energyPrefsWeighted$white_f)),
          !any(is.na(energyPrefsWeighted$male_f)),
          !any(is.na(energyPrefsWeighted$college_f)),
          !any(is.na(energyPrefsWeighted$pid3)))

# ---- 5. Rake ----------------------------------------------------------------

energyPrefsWeighted$caseid <- seq_len(nrow(energyPrefsWeighted))

raked <- anesrake(
  inputter     = rake_targets,
  dataframe    = energyPrefsWeighted,
  caseid       = energyPrefsWeighted$caseid,
  cap          = 5,
  choosemethod = "total",
  type         = "pctlim",
  pctlim       = 0.05,
  nlim         = 5,
  iterate      = TRUE,
  force1       = TRUE
)

energyPrefsWeighted$weight <- raked$weightvec

# ---- 6. Weight diagnostics --------------------------------------------------

weighted_prop <- function(var, w) {
  tab <- tapply(w, var, sum)
  tab / sum(tab)
}

for (v in names(rake_targets)) {
  cat("\n--", v, "--\n")
  print(round(cbind(
    Unweighted = prop.table(table(energyPrefsWeighted[[v]])),
    Weighted   = weighted_prop(energyPrefsWeighted[[v]], energyPrefsWeighted$weight),
    Target     = rake_targets[[v]][levels(energyPrefsWeighted[[v]])]
  ), 3))
}

w   <- energyPrefsWeighted$weight
ess <- sum(w)^2 / sum(w^2)
cat(sprintf("\nN = %d, effective N (Kish) = %.0f, design effect = %.2f\n",
            length(w), ess, length(w) / ess))

# ---- 7. Export --------------------------------------------------------------

cueWTPDataWeighted <- energyPrefsWeighted[, c("priority.scale","wtp.fossil","wtp.renewable","concern.cost","trump.approval",
                                              "democrat","republican","libDem","conRep","age","male","white","edu","college","inc",
                                              "trump.cue","climate.cue","control","weight")]

write.csv(cueWTPDataWeighted, "data/cueWTPDataWeighted.csv", row.names = FALSE)
