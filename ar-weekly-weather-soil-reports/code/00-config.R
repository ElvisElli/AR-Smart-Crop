# ═══════════════════════════════════════════════════════════════════════════
# AR Weekly Weather & Soil Water Reports — Configuration
# ═══════════════════════════════════════════════════════════════════════════
#
# This file contains ALL user-configurable settings.
# Edit this file to customize pipeline behavior.
# All subsequent scripts source this file at startup.
# ═══════════════════════════════════════════════════════════════════════════

## ─────────────────────────────────────────────────────────────────────────
## 1. SIMULATION WINDOW
## ─────────────────────────────────────────────────────────────────────────
## Set dates for the week to simulate
## Format: "YYYY-MM-DD"

DATE_START <- "2025-06-16"   # Week start (Monday)
DATE_END   <- "2025-06-22"   # Week end (Sunday)

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

TEST_RUN <- TRUE            # TRUE = test mode (small dataset)
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
PATH_WEATHER      <- "data/raw/weather"

# Soil path: use soil_sample if available (for testing), else soil (production)
PATH_SOIL         <- if (dir.exists("data/raw/soil_sample")) "data/raw/soil_sample" else "data/raw/soil"
PATH_TEMPLATES    <- "templates"
PATH_CHECKPOINTS  <- "data/outputs/checkpoints"
PATH_PROCESSED    <- "data/processed"
PATH_OUTPUTS      <- "data/outputs"

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
## 9. REPORTING & WEBSITE
## ─────────────────────────────────────────────────────────────────────────

REPORT_FORMAT <- "html"         # "html" or "pdf"
BUILD_WEBSITE <- TRUE           # TRUE = build Quarto website
PUBLISH_GITHUB_PAGES <- FALSE   # TRUE = deploy to GitHub Pages

## ─────────────────────────────────────────────────────────────────────────
## 10. DIAGNOSTIC MODE
## ─────────────────────────────────────────────────────────────────────────
## For troubleshooting: run single cell with full APSIM output

RUN_DIAGNOSTIC <- FALSE         # TRUE = run single cell, see APSIM output
DIAG_CELL_ID   <- 1             # Which cell to diagnose

## ═══════════════════════════════════════════════════════════════════════════
## END OF CONFIGURATION
## ═══════════════════════════════════════════════════════════════════════════

# Print summary
if (VERBOSE) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("AR WEEKLY WEATHER & SOIL WATER REPORTS — Configuration Loaded\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("Simulation window : %s to %s\n", DATE_START, DATE_END))
  cat(sprintf("Parallel cores    : %s\n", if(is.na(N_CORES)) "auto-detect" else N_CORES))
  cat(sprintf("Chunk size        : %d cells/task\n", CHUNK_SIZE))
  cat(sprintf("Test mode         : %s\n", if(TEST_RUN) sprintf("TRUE (%d cells)", TEST_N_CELLS) else "FALSE"))
  cat(sprintf("Cultivar          : %s | Sowing: %s\n", CULTIVAR, SOW_DATE))
  cat(sprintf("Template          : %s\n", APSIM_TEMPLATE))
  cat(strrep("=", 70), "\n\n")
}
