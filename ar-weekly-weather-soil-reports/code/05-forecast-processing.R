# Step 05: Forecast Processing - Extract crop stress signals and trends
# Input: data/processed/raw-forecasts.rds
# Output: data/processed/forecast-trends.rds

source("code/00-config.R")

if (VERBOSE) cat("Step 05: Forecast Processing\n")

forecasts <- readRDS(file.path(PATH_PROCESSED_DATA, "raw-forecasts.rds"))

library(tidyverse)

# ============================================================================
# Extract Crop-Relevant Forecast Signals
# ============================================================================

# TODO: Calculate 7-day temperature trends
# TODO: Estimate rainfall probability (combine precip_forecast + precip_prob)
# TODO: Identify frost risk dates (tmin < 0°C)
# TODO: Project cumulative GDD over 7 days
# TODO: Estimate water stress days (high temp + low precip probability)

forecast_signals <- forecasts %>%
  arrange(station, forecast_date) %>%
  group_by(station) %>%
  mutate(
    # Temperature trend (°C/day slope)
    temp_trend = (tmax_forecast - first(tmax_forecast)) / (as.numeric(row_number() - 1) + 0.01),

    # Frost risk (1 if tmin < 0°C)
    frost_risk = ifelse(tmin_forecast < 0, 1, 0),

    # Precipitation risk (combine forecast amount + probability)
    precip_risk = precip_forecast * (precip_prob / 100),

    # GDD accumulation
    gdd_forecast = pmax((tmax_forecast + tmin_forecast) / 2 - 10, 0),

    # Stress indicator (high temp + low precip risk)
    stress_signal = ifelse(tmax_forecast > 32 & precip_risk < 2, 1, 0)
  ) %>%
  ungroup() %>%
  select(station, forecast_date, tmax_forecast, tmin_forecast, precip_forecast,
    temp_trend, frost_risk, precip_risk, gdd_forecast, stress_signal
  )

saveRDS(forecast_signals, file.path(PATH_PROCESSED_DATA, "forecast-trends.rds"))

if (VERBOSE) {
  cat("✓ Forecast processing completed\n")
  cat("  Records:", nrow(forecast_signals), "\n")
  cat("  Forecast days:", as.numeric(max(forecast_signals$forecast_date) - min(forecast_signals$forecast_date)) + 1, "\n")
}
