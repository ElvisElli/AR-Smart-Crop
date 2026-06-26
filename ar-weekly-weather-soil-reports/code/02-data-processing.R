# Step 02: Data Processing - QA/QC, interpolation, aggregation to uniform grid
# Input: data/processed/raw-weather.rds
# Output: data/processed/current-conditions.rds

source("code/00-config.R")
source("code/utils/data-utils.R")

if (VERBOSE) cat("Loading R packages for data processing...\n")
library(tidyverse)
library(data.table)

# ============================================================================
# 1. Load Raw Weather Data
# ============================================================================

weather_raw <- readRDS(file.path(PATH_PROCESSED_DATA, "raw-weather.rds"))

if (VERBOSE) {
  cat(sprintf("Loaded %d weather records\n", nrow(weather_raw)))
  cat(sprintf("Date range: %s to %s\n", min(weather_raw$date, na.rm = TRUE), max(weather_raw$date, na.rm = TRUE)))
}

# ============================================================================
# 2. Quality Control & Outlier Detection
# ============================================================================

if (VERBOSE) cat("Performing QA/QC checks...\n")

# Remove rows with excessive missing values
weather_clean <- weather_raw %>%
  filter(!is.na(date), !is.na(station)) %>%
  # Reasonable temperature bounds (°C)
  filter(tmin >= -40, tmax <= 60, tmin <= tmax) %>%
  # Reasonable precipitation bounds (mm/day)
  filter(precip >= 0, precip <= 500) %>%
  # Reasonable radiation bounds (MJ/m²/day)
  filter(radn >= 0, radn <= 40, na.rm = TRUE)

if (VERBOSE) {
  cat(sprintf("After QA/QC: %d records (removed %d)\n",
    nrow(weather_clean), nrow(weather_raw) - nrow(weather_clean)
  ))
}

# ============================================================================
# 3. Fill Missing Values (Linear Interpolation)
# ============================================================================

if (VERBOSE) cat("Filling missing values...\n")

weather_clean <- weather_clean %>%
  arrange(station, date) %>%
  group_by(station) %>%
  mutate(
    tmax = zoo::na.approx(tmax, na.rm = FALSE, maxgap = 3),
    tmin = zoo::na.approx(tmin, na.rm = FALSE, maxgap = 3),
    precip = zoo::na.approx(precip, na.rm = FALSE, maxgap = 1),  # More restrictive for precip
    radn = zoo::na.approx(radn, na.rm = FALSE, maxgap = 3)
  ) %>%
  ungroup()

# ============================================================================
# 4. Calculate Derived Variables
# ============================================================================

if (VERBOSE) cat("Calculating derived weather variables...\n")

weather_processed <- weather_clean %>%
  group_by(station) %>%
  mutate(
    # Temperature metrics
    tmean = (tmax + tmin) / 2,
    trange = tmax - tmin,

    # Growing Degree Days (base 50°F = 10°C)
    gdd = pmax(tmean - 10, 0),

    # Cumulative metrics (since start of season: April 1)
    season_start = as.Date(paste0(year(date), "-04-01")),
    days_since_season_start = as.numeric(difftime(date, season_start, units = "days")),
    cum_gdd = cumsum(ifelse(date >= season_start, gdd, 0)),
    cum_precip = cumsum(ifelse(date >= season_start, precip, 0)),

    # Evapotranspiration (simplified Hargreaves equation)
    # ET0 (mm/day) ≈ 0.0023 * Ra * (T_mean + 17.8) * (T_max - T_min)^0.5
    # Ra ≈ radn * 0.408 (converts MJ to mm)
    et_rate = 0.0023 * (radn * 0.408) * (tmean + 17.8) * sqrt(pmax(trange, 0.1))
  ) %>%
  ungroup() %>%
  select(-season_start, -days_since_season_start)

# ============================================================================
# 5. Aggregate to Uniform State Grid (5 km resolution)
# ============================================================================

# Note: This is a placeholder. Full implementation would:
# - Create 5 km grid for Arkansas
# - Interpolate point measurements (stations) to grid cells
# - Use inverse-distance weighting or kriging
# For now, keep station-level aggregates

if (VERBOSE) cat("Aggregating to state grid...\n")

# Station-level summary (daily)
weather_aggregated <- weather_processed %>%
  group_by(station, date) %>%
  summarise(
    tmax = mean(tmax, na.rm = TRUE),
    tmin = mean(tmin, na.rm = TRUE),
    tmean = mean(tmean, na.rm = TRUE),
    precip = sum(precip, na.rm = TRUE),
    radn = mean(radn, na.rm = TRUE),
    gdd = mean(gdd, na.rm = TRUE),
    cum_gdd = max(cum_gdd, na.rm = TRUE),
    cum_precip = max(cum_precip, na.rm = TRUE),
    et_rate = mean(et_rate, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(tmax), !is.na(tmin), !is.na(precip))

# ============================================================================
# 6. Save Processed Data
# ============================================================================

saveRDS(weather_aggregated, file.path(PATH_PROCESSED_DATA, "current-conditions.rds"))

if (VERBOSE) {
  cat("\n=== Step 02 Complete: Data Processing ===\n")
  cat(sprintf("Processed: %d station-days\n", nrow(weather_aggregated)))
  cat(sprintf("Stations: %s\n", paste(unique(weather_aggregated$station), collapse = ", ")))
  cat(sprintf("Date range: %s to %s\n", min(weather_aggregated$date), max(weather_aggregated$date)))
}
