# ═══════════════════════════════════════════════════════════════════════════
# Phase 2: Data Processing — Soil Water Metrics Extraction & Aggregation
# ═══════════════════════════════════════════════════════════════════════════
#
# This script processes raw APSIM simulation results (Phase 1 output) and
# extracts soil water holding capacity metrics, aggregated by grid cell.
#
# Input:  data/processed/simulation-results.rds (Phase 1 output)
# Output: data/outputs/soil-water-status-YYYY-WW.csv
#
# ═══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(data.table)
})

## ── Utility functions ───────────────────────────────────────────────────────

.ts <- function() format(Sys.time(), "%H:%M:%S")

## ── Load configuration ──────────────────────────────────────────────────────
cat("\n")
source("code/00-config.R", local = TRUE)

## ─────────────────────────────────────────────────────────────────────────
## Phase 2: DATA PROCESSING
## ─────────────────────────────────────────────────────────────────────────

message(sprintf("[%s] Phase 2: Data Processing started\n", .ts()))

## ── Check Phase 1 results exist ──────────────────────────────────────────
results_file <- file.path(PATH_PROCESSED, "simulation-results.rds")

if (!file.exists(results_file)) {
  stop(sprintf("[ERROR] Phase 1 results not found: %s\n", results_file),
       "  Run Phase 1 first: source('code/01-simulation.R')")
}

message(sprintf("[INPUT] Loading Phase 1 results: %s", results_file))
sim_results <- readRDS(results_file)
message(sprintf("[INPUT] Loaded: %d rows × %d columns", nrow(sim_results), ncol(sim_results)))

# Check for required columns
required_cols <- c("cellid", "x", "y", "date",
                   "swhc_6in", "swhc_12in", "swhc_24in")
missing_cols <- setdiff(required_cols, names(sim_results))

if (length(missing_cols) > 0) {
  stop(sprintf("[ERROR] Missing required columns: %s",
               paste(missing_cols, collapse=", ")))
}

## ── Extract soil water metrics ──────────────────────────────────────────
message(sprintf("[%s] Extracting soil water metrics", .ts()))

soil_water_data <- sim_results %>%
  as.data.table() %>%
  # Convert date column to proper Date if not already
  .[, date := as.Date(date)] %>%
  # Group by cell and calculate statistics
  .[, .(
    swhc_6in_mean   = mean(swhc_6in, na.rm = TRUE),
    swhc_6in_min    = min(swhc_6in, na.rm = TRUE),
    swhc_6in_max    = max(swhc_6in, na.rm = TRUE),
    swhc_12in_mean  = mean(swhc_12in, na.rm = TRUE),
    swhc_12in_min   = min(swhc_12in, na.rm = TRUE),
    swhc_12in_max   = max(swhc_12in, na.rm = TRUE),
    swhc_24in_mean  = mean(swhc_24in, na.rm = TRUE),
    swhc_24in_min   = min(swhc_24in, na.rm = TRUE),
    swhc_24in_max   = max(swhc_24in, na.rm = TRUE),
    n_days          = .N
  ), by = .(cellid, x, y)] %>%
  as.data.frame() %>%
  # Add week identifier
  mutate(
    week_start = min(as.Date(sim_results$date)),
    week_end   = max(as.Date(sim_results$date)),
    year       = format(week_start, "%Y"),
    week       = format(week_start, "%W")
  )

message(sprintf("[PROCESS] Aggregated: %d cells", nrow(soil_water_data)))
message(sprintf("[STATS] Soil water range (6in): %.1f–%.1f mm",
                min(soil_water_data$swhc_6in_min, na.rm=TRUE),
                max(soil_water_data$swhc_6in_max, na.rm=TRUE)))

## ── Format output ──────────────────────────────────────────────────────
# Prepare output with consistent column order
output_data <- soil_water_data %>%
  select(
    year, week, week_start, week_end,
    cellid, x, y, n_days,
    swhc_6in_mean, swhc_6in_min, swhc_6in_max,
    swhc_12in_mean, swhc_12in_min, swhc_12in_max,
    swhc_24in_mean, swhc_24in_min, swhc_24in_max
  ) %>%
  arrange(cellid)

## ── Save to CSV ────────────────────────────────────────────────────────
dir.create(PATH_OUTPUTS, showWarnings = FALSE, recursive = TRUE)

year <- format(min(as.Date(sim_results$date)), "%Y")
week <- format(min(as.Date(sim_results$date)), "%W")
output_file <- file.path(PATH_OUTPUTS, sprintf("soil-water-status-%s-W%s.csv", year, week))

message(sprintf("[%s] Writing output: %s", .ts(), output_file))
write_csv(output_data, output_file)

message(sprintf("[OUTPUT] ✓ Saved: %s", output_file))
message(sprintf("[OUTPUT] Rows: %d cells", nrow(output_data)))
message(sprintf("[OUTPUT] Columns: %d", ncol(output_data)))

## ── Print summary ──────────────────────────────────────────────────────
cat("\n")
cat(strrep("=", 70), "\n")
cat("PHASE 2: DATA PROCESSING COMPLETE\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Input:    %s\n", results_file))
cat(sprintf("Output:   %s\n", output_file))
cat(sprintf("Cells:    %d\n", nrow(output_data)))
cat(sprintf("Week:     %s-%s W%s\n", year, week, week))
cat("\nNext: Review CSV and proceed to Phase 3 (Report Generation)\n")
cat(sprintf("  source('code/03-generate-report.R')\n"))
cat(strrep("=", 70), "\n\n")

message(sprintf("[%s] Phase 2 finished", .ts()))
