# Global configuration for AR weekly weather & soil water reports
# Edit this file to customize pipeline behavior

# ============================================================================
# 1. RESEARCH STATIONS & GRID COVERAGE
# ============================================================================

# Primary research stations (update from data/raw/research-stations.csv)
STATIONS <- c(
  "Fayetteville",
  "Marianna",
  "Pine Bluff",
  "Rohwer",
  "Hope"
)

# Grid coverage
GRID_RESOLUTION_KM <- 5         # 5 km spatial resolution for state grid
GRID_CRS <- 4326                # WGS84 (lat/lon)

# ============================================================================
# 2. WEATHER DATA SOURCES
# ============================================================================

# Current/historical weather API
WEATHER_API <- "iemaps"         # Options: "iemaps" (IEM), "openmeteo"

# Weather forecast API
FORECAST_API <- "openmeteo"     # Options: "openmeteo" (required)
FORECAST_DAYS <- 7              # Days ahead to forecast (1-10)

# API rate limiting
API_DELAY_SECONDS <- 2          # Delay between API requests (avoid rate limits)
API_TIMEOUT_SECONDS <- 30       # Max wait per request

# ============================================================================
# 3. SOIL WATER MODEL PARAMETERS
# ============================================================================

# Bucket model configuration
SOIL_MODEL_TYPE <- "bucket"     # Options: "bucket", "richards" (future)

# Available Water Capacity (fraction of soil depth that plants can use)
# Typical range: 0.15–0.30 depending on soil type
AWC_DEFAULT <- 0.20             # 20% (medium loam, typical for Arkansas)

# Starting soil moisture (as fraction of AWC at model start)
# 0.5 = field capacity, 1.0 = saturated, 0 = wilting point
INITIAL_SOIL_MOISTURE <- 0.5

# Wilting point (soil water stress threshold)
# Relative soil water below this triggers crop stress alert
STRESS_THRESHOLD <- 0.5         # Stress when <50% available water

# Evapotranspiration (ET) method
ET_METHOD <- "hargreaves"       # Options: "hargreaves", "penman-monteith"
ET_CROP_COEFFICIENT <- 1.0      # Adjustment for current crop stage

# ============================================================================
# 4. HISTORICAL BASELINE STATISTICS
# ============================================================================

# Years used to compute "normal" conditions
BASELINE_START <- 1995
BASELINE_END <- 2020

# Percentile thresholds for anomaly classification
PERCENTILE_THRESHOLDS <- list(
  wet = 75,      # Above 75th percentile = "wet"
  normal_wet = 50,
  normal_dry = 50,
  dry = 25       # Below 25th percentile = "dry"
)

# ============================================================================
# 5. REPORT GENERATION
# ============================================================================

# Report date (set to Sys.Date() for current week, or override)
REPORT_DATE <- Sys.Date()

# Report timezone (for date labels, formatting)
REPORT_TIMEZONE <- "America/Chicago"

# Report format
REPORT_FORMAT <- "html"         # Options: "html" (recommended), "pdf"

# Include detailed station pages?
INCLUDE_STATION_PAGES <- TRUE

# Number of historical days to show in station detail
STATION_DETAIL_DAYS <- 30

# ============================================================================
# 6. OUTPUT PATHS
# ============================================================================

# All paths are relative to repo root
PATH_RAW_STATIONS <- "data/raw/research-stations.csv"
PATH_RAW_SOIL <- "data/raw/soil-properties"
PATH_RAW_HISTORICAL <- "data/raw/historical-weather"

PATH_PROCESSED_DATA <- "data/processed"
PATH_OUTPUT_REPORTS <- "data/outputs/reports"
PATH_OUTPUT_DATASETS <- "data/outputs/datasets"

# Cache directory (for API responses, historical data)
PATH_CACHE <- "data/cache"

# ============================================================================
# 7. LOGGING & DEBUG
# ============================================================================

# Verbose logging?
VERBOSE <- TRUE

# Log file (set to NULL to print to console only)
LOG_FILE <- "data/logs/pipeline.log"

# Save intermediate plots for debugging?
DEBUG_PLOTS <- FALSE

# ============================================================================
# 8. PERFORMANCE & SCALING
# ============================================================================

# Number of parallel cores to use (NA = auto-detect, leave 2 free)
N_CORES <- NA

# Batch size for grid cell processing
BATCH_SIZE <- 50

# Resume from checkpoint? (if TRUE, skips completed steps)
RESUME_FROM_CHECKPOINT <- TRUE

# ============================================================================
# 9. FEATURE FLAGS (experimental features)
# ============================================================================

# Include fire weather index?
INCLUDE_FIRE_WEATHER <- FALSE

# Include agricultural drought monitor integration?
INCLUDE_DROUGHT_MONITOR <- FALSE

# Include phenology predictions (crop development stage)?
INCLUDE_PHENOLOGY <- FALSE

# Generate datasets for machine learning models?
INCLUDE_ML_DATASETS <- FALSE

# ============================================================================
# 10. QUARTO WEBSITE INTEGRATION
# ============================================================================

# Build Quarto website with report?
BUILD_QUARTO_WEBSITE <- TRUE

# Quarto website directory (relative to repo root)
PATH_QUARTO_SITE <- "_site"

# Publish to GitHub Pages?
PUBLISH_TO_GITHUB_PAGES <- FALSE

# ============================================================================
# END OF CONFIGURATION
# ============================================================================

# Save config summary
cat("\n=== AR Weekly Weather & Soil Water Reports ===\n")
cat("Report date:", format(REPORT_DATE, "%Y-%m-%d"), "\n")
cat("Stations:", paste(STATIONS, collapse = ", "), "\n")
cat("Weather API:", WEATHER_API, "\n")
cat("Soil model:", SOIL_MODEL_TYPE, "| AWC:", AWC_DEFAULT, "\n")
cat("Baseline:", BASELINE_START, "–", BASELINE_END, "\n")
cat("Output:", PATH_OUTPUT_REPORTS, "\n\n")
