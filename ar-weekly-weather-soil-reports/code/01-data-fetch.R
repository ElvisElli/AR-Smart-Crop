# Step 01: Data Fetch - Download current weather, forecasts, and soil data
# Input: API endpoints, station coordinates
# Output: data/processed/raw-weather.rds, raw-forecasts.rds, soil-properties.rds

source("code/00-config.R")
source("code/utils/api-utils.R")

if (VERBOSE) cat("Loading R packages for data fetching...\n")
library(tidyverse)
library(data.table)

# ============================================================================
# 1. Load Station Metadata
# ============================================================================

if (!file.exists(PATH_RAW_STATIONS)) {
  stop("Station metadata not found at: ", PATH_RAW_STATIONS)
}

stations_meta <- read_csv(PATH_RAW_STATIONS, show_col_types = FALSE) %>%
  filter(name %in% STATIONS) %>%
  as.data.frame()

if (nrow(stations_meta) == 0) {
  stop("No matching stations found in ", PATH_RAW_STATIONS)
}

if (VERBOSE) {
  cat("Loaded", nrow(stations_meta), "stations:\n")
  cat(paste("  -", stations_meta$name, collapse = "\n"), "\n")
}

# ============================================================================
# 2. Fetch Current Weather Data
# ============================================================================

if (VERBOSE) cat("\nFetching current weather data...\n")

# Try to get data from configured API
if (WEATHER_API == "iemaps") {
  weather_list <- list()
  for (i in seq_len(nrow(stations_meta))) {
    if (VERBOSE) cat(sprintf("  [%d/%d] %s\n", i, nrow(stations_meta), stations_meta$name[i]))

    # Example: fetch from IEM API
    # In production, use iem::get_iem_apsim_met() or similar
    weather_list[[i]] <- fetch_weather_iem(
      lon = stations_meta$longitude[i],
      lat = stations_meta$latitude[i],
      start_date = REPORT_DATE - 30,  # Last 30 days
      end_date = REPORT_DATE,
      api_delay = API_DELAY_SECONDS
    )

    if (!is.null(weather_list[[i]])) {
      weather_list[[i]]$station <- stations_meta$name[i]
    }
  }
} else if (WEATHER_API == "openmeteo") {
  weather_list <- list()
  for (i in seq_len(nrow(stations_meta))) {
    if (VERBOSE) cat(sprintf("  [%d/%d] %s\n", i, nrow(stations_meta), stations_meta$name[i]))

    weather_list[[i]] <- fetch_weather_openmeteo(
      lon = stations_meta$longitude[i],
      lat = stations_meta$latitude[i],
      start_date = REPORT_DATE - 30,
      end_date = REPORT_DATE,
      api_delay = API_DELAY_SECONDS
    )

    if (!is.null(weather_list[[i]])) {
      weather_list[[i]]$station <- stations_meta$name[i]
    }
  }
}

# Combine all weather data
weather_data <- bind_rows(weather_list) %>%
  mutate(date = as.Date(date)) %>%
  filter(!is.na(date))

if (nrow(weather_data) == 0) {
  warning("No weather data fetched; check API connectivity")
}

# Save checkpoint
saveRDS(weather_data, file.path(PATH_PROCESSED_DATA, "raw-weather.rds"))
if (VERBOSE) cat(sprintf("Saved weather data: %d records\n", nrow(weather_data)))

# ============================================================================
# 3. Fetch Weather Forecasts (7–10 day)
# ============================================================================

if (VERBOSE) cat("\nFetching weather forecasts...\n")

forecasts_list <- list()
for (i in seq_len(nrow(stations_meta))) {
  if (VERBOSE) cat(sprintf("  [%d/%d] %s\n", i, nrow(stations_meta), stations_meta$name[i]))

  forecasts_list[[i]] <- fetch_forecast_openmeteo(
    lon = stations_meta$longitude[i],
    lat = stations_meta$latitude[i],
    days_ahead = FORECAST_DAYS,
    api_delay = API_DELAY_SECONDS
  )

  if (!is.null(forecasts_list[[i]])) {
    forecasts_list[[i]]$station <- stations_meta$name[i]
  }
}

forecasts_data <- bind_rows(forecasts_list) %>%
  mutate(forecast_date = as.Date(forecast_date)) %>%
  filter(!is.na(forecast_date))

if (nrow(forecasts_data) == 0) {
  warning("No forecast data fetched; check API connectivity")
}

saveRDS(forecasts_data, file.path(PATH_PROCESSED_DATA, "raw-forecasts.rds"))
if (VERBOSE) cat(sprintf("Saved forecast data: %d records\n", nrow(forecasts_data)))

# ============================================================================
# 4. Load Soil Properties (cached locally)
# ============================================================================

if (VERBOSE) cat("\nLoading soil properties...\n")

soil_data <- data.frame(
  station = character(),
  awc = numeric(),
  depth_m = numeric(),
  texture = character(),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(stations_meta))) {
  soil_file <- file.path(PATH_RAW_SOIL, paste0(tolower(gsub(" ", "-", stations_meta$name[i])), ".rds"))

  if (file.exists(soil_file)) {
    soil_profile <- readRDS(soil_file)
    soil_data <- bind_rows(soil_data, data.frame(
      station = stations_meta$name[i],
      awc = ifelse(!is.null(soil_profile$awc), soil_profile$awc, AWC_DEFAULT),
      depth_m = ifelse(!is.null(soil_profile$depth_m), soil_profile$depth_m, 1.2),
      texture = ifelse(!is.null(soil_profile$texture), soil_profile$texture, "loam")
    ))
  } else {
    # Use default if file not found
    soil_data <- bind_rows(soil_data, data.frame(
      station = stations_meta$name[i],
      awc = AWC_DEFAULT,
      depth_m = 1.2,
      texture = "loam"
    ))
  }
}

saveRDS(soil_data, file.path(PATH_PROCESSED_DATA, "soil-properties.rds"))
if (VERBOSE) cat(sprintf("Loaded soil data for %d stations\n", nrow(soil_data)))

# ============================================================================
# Summary
# ============================================================================

if (VERBOSE) {
  cat("\n=== Step 01 Complete: Data Fetch ===\n")
  cat(sprintf("Weather records: %d\n", nrow(weather_data)))
  cat(sprintf("Forecast records: %d\n", nrow(forecasts_data)))
  cat(sprintf("Soil stations: %d\n", nrow(soil_data)))
  cat("Checkpoints saved to data/processed/\n")
}
