# ═══════════════════════════════════════════════════════════════════════════
# AR Weekly Weather & Soil Water Reports — Configuration
# ═══════════════════════════════════════════════════════════════════════════
#
# This file contains ALL user-configurable settings.
# Edit this file to customize pipeline behavior.
# All subsequent scripts source this file at startup.
# ═══════════════════════════════════════════════════════════════════════════

## ─────────────────────────────────────────────────────────────────────────
## 1. SIMULATION MODE & WINDOW
## ─────────────────────────────────────────────────────────────────────────
## Choose simulation mode: "weekly", "historical", or "forecast"
## Format: "YYYY-MM-DD"

SIMULATION_MODE <- "weekly"   # "weekly" | "historical" | "forecast"

# Weekly mode: Current week only (for automated scheduling)
# Use this for: Weekly reports, benchmarking against history
DATE_START <- "2026-01-05"   # Week start (Monday) — UPDATE FOR CURRENT WEEK
DATE_END   <- "2026-01-11"   # Week end (Sunday)

# Historical mode: 1985-2025 baseline (run once)
# Use this for: Generate 40-year benchmark statistics
HISTORICAL_START <- "1985-01-01"
HISTORICAL_END   <- "2025-12-31"
HISTORICAL_AGGREGATION <- "yearly"  # "yearly" | "decadal" | "full-period"

# Forecast mode: Next 7 days with weather forecast
# Use this for: Predict conditions at research stations
FORECAST_START <- "2026-01-12"   # Next week start
FORECAST_END   <- "2026-01-18"   # Next week end
FORECAST_DATA_SOURCE <- NULL     # Path to forecast .met files (if different)

## ─────────────────────────────────────────────────────────────────────────
## 2. PARALLEL PROCESSING
## ─────────────────────────────────────────────────────────────────────────

CHUNK_SIZE <- 50            # Cells per parallel task (50 = moderate)
                            # Lower (25) if memory-constrained
                            # Higher (100) for faster completion

N_CORES <- NA               # NA = auto-detect (detectCores() - 1)
                            # Set to fixed number to override

## ─────────────────────────────────────────────────────────────────────────
## 3. RESUMABILITY & RERUN
## ─────────────────────────────────────────────────────────────────────────

FORCE_RERUN_SIM <- FALSE    # TRUE = delete all checkpoints, run from scratch
                            # FALSE = resume from last completed chunk

DELETE_APSIM_WORK <- TRUE   # TRUE = clean up temp APSIM files after run
                            # FALSE = keep for debugging

## ─────────────────────────────────────────────────────────────────────────
## 4. TEST MODE
## ─────────────────────────────────────────────────────────────────────────
## Run a quick test with subset of cells (for development/debugging)

TEST_RUN <- FALSE           # TRUE = test mode (small dataset)
                            # FALSE = full production run

TEST_N_CELLS <- 5           # Number of cells to test
TEST_N_GRID_CELLS <- 20     # If full grid, use first N cells

## ─────────────────────────────────────────────────────────────────────────
## 4b. NOTIFICATION & LOGGING (moved earlier to avoid forward reference)
## ─────────────────────────────────────────────────────────────────────────

VERBOSE <- TRUE                 # TRUE = detailed console output (must be defined early)

## ─────────────────────────────────────────────────────────────────────────
## 5. DATA PATHS
## ─────────────────────────────────────────────────────────────────────────
## All relative to repo root

PATH_SIM_GRID     <- "data/raw/sim-grid.rds"

# Weather data paths by mode
PATH_WEATHER      <- if (SIMULATION_MODE == "forecast" && !is.null(FORECAST_DATA_SOURCE)) {
                      FORECAST_DATA_SOURCE
                    } else {
                      "data/raw/weather"
                    }

PATH_HISTORICAL_WEATHER <- "data/raw/weather_historical"  # For 1985-2025 baseline
PATH_SOIL         <- "data/raw/soil"
PATH_TEMPLATES    <- "templates"

# Output paths by mode
PATH_CHECKPOINTS  <- sprintf("data/outputs/checkpoints/%s", SIMULATION_MODE)
PATH_PROCESSED    <- sprintf("data/processed/%s", SIMULATION_MODE)
PATH_OUTPUTS      <- "data/outputs"
PATH_BENCHMARK    <- "data/outputs/benchmark"  # For historical statistics

## Optional: Local data cache (faster than network drive)
## Set to NULL to use paths above
## On Windows: "C:/temp/soybean-data" (copy from Box once, reuse)
LOCAL_DATA_CACHE <- NULL

## Sample data for testing (cloud)
## TRUE = use sample weather files (data/raw/weather_sample/)
## FALSE = use full files (data/raw/weather/)
## Auto-detects: TRUE in cloud, FALSE on local Windows
USE_SAMPLE_DATA <- grepl("cloud|lambda|codespaces", tolower(Sys.info()["nodename"]))

if (VERBOSE) {
  cat(sprintf("Sample data mode  : %s\n", if(USE_SAMPLE_DATA) "TRUE (testing)" else "FALSE (production)"))
}

## ─────────────────────────────────────────────────────────────────────────
## 6. APSIM CONFIGURATION
## ─────────────────────────────────────────────────────────────────────────

APSIM_TEMPLATE  <- "baseline.apsimx"  # Template filename in templates/
APSIM_EXE       <- NULL               # NULL = auto-detect
                                      # Or set manually: "C:/Program Files/APSIM2025.3.7681.0/bin/Models.exe"

## Root depth parameters (20 soil layers)
KL_VEC <- c(0.08, 0.08, 0.08, 0.08, 0.07, 0.07, 0.07, 0.07,
            0.06, 0.06, 0.06, 0.06, 0.05, 0.05, 0.04, 0.04,
            0.03, 0.03, 0.02, 0.02)

XF_VEC <- c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0)

## ─────────────────────────────────────────────────────────────────────────
## 7. SIMULATION PARAMETERS
## ─────────────────────────────────────────────────────────────────────────

CULTIVAR     <- "PurcellMG4"    # Soybean cultivar (MG4 = Midwest Group 4)
SOW_DATE     <- "15-May"        # Sowing date (format: "DD-Mon")
ROW_SPACING  <- 750             # Row spacing in cm
CO2_PPM      <- 350             # Atmospheric CO2 (ppm)

## ─────────────────────────────────────────────────────────────────────────
## 8. NOTIFICATION & LOGGING (continued)
## ─────────────────────────────────────────────────────────────────────────

NOTIFY  <- FALSE                # TRUE = send email on completion
                                # Requires Gmail setup (see CLAUDE.md)

LOG_FILE <- "data/outputs/sim-run-log.csv"  # Progress tracking

## ─────────────────────────────────────────────────────────────────────────
## 9. BENCHMARK & COMPARISONS (Weekly mode only)
## ─────────────────────────────────────────────────────────────────────────

USE_BENCHMARK <- TRUE                      # TRUE = compare against historical data
BENCHMARK_FILE <- "data/outputs/benchmark/historical-statistics.rds"  # 40-year stats

# Which benchmark periods to show in reports
BENCHMARK_PERIODS <- c("40-year mean", "decadal mean", "climatology")  # vs. current week

## ─────────────────────────────────────────────────────────────────────────
## 10. REPORTING & WEBSITE
## ─────────────────────────────────────────────────────────────────────────

REPORT_FORMAT <- "html"         # "html" or "pdf"
BUILD_WEBSITE <- TRUE           # TRUE = build Quarto website
PUBLISH_GITHUB_PAGES <- FALSE   # TRUE = deploy to GitHub Pages
INCLUDE_BENCHMARK_TABLES <- (SIMULATION_MODE == "weekly" && USE_BENCHMARK)

## ─────────────────────────────────────────────────────────────────────────
## 11. DIAGNOSTIC MODE
## ─────────────────────────────────────────────────────────────────────────
## For troubleshooting: run single cell with full APSIM output

RUN_DIAGNOSTIC <- FALSE         # TRUE = run single cell, see APSIM output
DIAG_CELL_ID   <- 1             # Which cell to diagnose

## ═══════════════════════════════════════════════════════════════════════════
## END OF CONFIGURATION — Auto-validation
## ═══════════════════════════════════════════════════════════════════════════

# Validate mode selection and set dates accordingly
if (!(SIMULATION_MODE %in% c("weekly", "historical", "forecast"))) {
  stop(sprintf("Invalid SIMULATION_MODE: %s. Use 'weekly', 'historical', or 'forecast'", SIMULATION_MODE))
}

# Set active date range based on mode
ACTIVE_DATE_START <- switch(SIMULATION_MODE,
  "weekly" = DATE_START,
  "historical" = HISTORICAL_START,
  "forecast" = FORECAST_START
)

ACTIVE_DATE_END <- switch(SIMULATION_MODE,
  "weekly" = DATE_END,
  "historical" = HISTORICAL_END,
  "forecast" = FORECAST_END
)

# Create necessary directories
dir.create(dirname(PATH_CHECKPOINTS), showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(PATH_PROCESSED), showWarnings = FALSE, recursive = TRUE)
dir.create(PATH_BENCHMARK, showWarnings = FALSE, recursive = TRUE)

# Print summary
if (VERBOSE) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("AR WEEKLY WEATHER & SOIL WATER REPORTS — Configuration Loaded\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("Simulation mode   : %s\n", toupper(SIMULATION_MODE)))
  cat(sprintf("Date window       : %s to %s\n", ACTIVE_DATE_START, ACTIVE_DATE_END))
  cat(sprintf("Parallel cores    : %s\n", if(is.na(N_CORES)) "auto-detect" else N_CORES))
  cat(sprintf("Chunk size        : %d cells/task\n", CHUNK_SIZE))
  cat(sprintf("Test mode         : %s\n", if(TEST_RUN) sprintf("TRUE (%d cells)", TEST_N_CELLS) else "FALSE"))
  if (SIMULATION_MODE == "weekly") {
    cat(sprintf("Benchmarking      : %s\n", if(USE_BENCHMARK) "YES (vs. 40-year baseline)" else "NO"))
  }
  cat(sprintf("Cultivar          : %s | Sowing: %s\n", CULTIVAR, SOW_DATE))
  cat(sprintf("Template          : %s\n", APSIM_TEMPLATE))
  cat(strrep("=", 70), "\n\n")
}
