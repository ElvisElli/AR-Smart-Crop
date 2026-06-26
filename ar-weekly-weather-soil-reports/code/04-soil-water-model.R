# Step 04: Soil Water Model - Calculate relative soil water status (bucket model)
# Input: data/processed/current-conditions.rds, soil-properties.rds
# Output: data/processed/soil-water-status.rds

source("code/00-config.R")
source("code/utils/soil-utils.R")

if (VERBOSE) cat("Step 04: Soil Water Modeling\n")

conditions <- readRDS(file.path(PATH_PROCESSED_DATA, "current-conditions.rds"))
soil_props <- readRDS(file.path(PATH_PROCESSED_DATA, "soil-properties.rds"))

library(tidyverse)

# ============================================================================
# Simple Bucket Model: Soil Water = Current + Precip - ET
# ============================================================================

# TODO: Implement bucket model
# - Initialize with INITIAL_SOIL_MOISTURE
# - For each day: sw_t = sw_t-1 + precip - et_rate
# - Clip to [0, AWC] (wilting point to field capacity)
# - Calculate relative soil water as fraction of AWC
# - Flag stress days when relative_sw < STRESS_THRESHOLD

soil_water <- conditions %>%
  left_join(soil_props, by = "station") %>%
  arrange(station, date) %>%
  group_by(station) %>%
  mutate(
    # Simplified: assume daily ET = 0.2 * (radn/100)
    et_daily = pmax(0.2 * (radn / 100), 0.5),

    # Bucket model (simplified)
    soil_water = INITIAL_SOIL_MOISTURE * awc,
    soil_water = soil_water + precip - et_daily,
    soil_water = pmax(0, pmin(soil_water, awc)),  # Clip to [0, AWC]

    # Relative soil water (fraction)
    rel_soil_water = soil_water / awc,

    # Stress indicator (1 if stressed, 0 otherwise)
    stress_day = ifelse(rel_soil_water < STRESS_THRESHOLD, 1, 0)
  ) %>%
  ungroup() %>%
  select(station, date, soil_water, rel_soil_water, stress_day)

saveRDS(soil_water, file.path(PATH_PROCESSED_DATA, "soil-water-status.rds"))

if (VERBOSE) {
  cat("✓ Soil water model completed (simplified bucket)\n")
  cat("  Records:", nrow(soil_water), "\n")
  cat("  Avg stress days:", mean(soil_water$stress_day, na.rm = TRUE), "\n")
}
