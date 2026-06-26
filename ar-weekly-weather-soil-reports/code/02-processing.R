# ═══════════════════════════════════════════════════════════════════════════
# Phase 2: Data Processing — Soil Water Metrics Extraction & Aggregation
# ═══════════════════════════════════════════════════════════════════════════
#
# Processes raw APSIM simulation results and extracts soil water metrics.
# Supports three modes:
#   - WEEKLY: Aggregates current week, compares to 40-year benchmark
#   - HISTORICAL: Skipped (Phase 5 generates benchmark directly)
#   - FORECAST: Aggregates forecast week normally
#
# Input:  data/processed/{mode}/simulation-results.rds or simulation-results-YYYY.rds
# Output: data/outputs/soil-water-status-YYYY-WW.csv (weekly/forecast)
#         or skipped (historical mode)
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

## ── Mode check: Historical mode skips processing ──────────────────────────
if (SIMULATION_MODE == "historical") {
  message("[%s] Historical mode detected: Phase 2 skipped\n", .ts()))
  message("[INFO] Benchmark generation happens in Phase 5: code/05-generate-historical-benchmark.R\n")
  message("[INFO] Run Phase 5 after all historical years complete\n")
  quit(save = "no")
}

## ─────────────────────────────────────────────────────────────────────────
## Phase 2: DATA PROCESSING (Weekly & Forecast modes)
## ─────────────────────────────────────────────────────────────────────────

message(sprintf("[%s] Phase 2: Data Processing started (%s mode)\n",
                .ts(), toupper(SIMULATION_MODE)))

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

## ── Load benchmark (weekly mode only) ────────────────────────────────────
if (SIMULATION_MODE == "weekly" && USE_BENCHMARK && file.exists(BENCHMARK_FILE)) {
  message(sprintf("[%s] Loading benchmark statistics from: %s",
                  .ts(), BENCHMARK_FILE))
  benchmark <- readRDS(BENCHMARK_FILE)
  baseline_40yr <- benchmark$baseline_40yr

  # Join benchmark data
  soil_water_data <- soil_water_data %>%
    left_join(
      baseline_40yr %>% select(cellid, starts_with("swhc_")),
      by = "cellid"
    )

  message(sprintf("[BENCHMARK] Joined 40-year baseline for %d cells",
                  sum(!is.na(soil_water_data$swhc_6in_40yr_mean))))
} else if (SIMULATION_MODE == "weekly") {
  message("[WARNING] Weekly mode but benchmark not available")
  message("[INFO] Run Phase 5 after generating historical baseline:")
  message("       source('code/05-generate-historical-benchmark.R')")
}

## ── Format output ──────────────────────────────────────────────────────
# Prepare output with consistent column order
base_cols <- c(
  "year", "week", "week_start", "week_end",
  "cellid", "x", "y", "n_days",
  "swhc_6in_mean", "swhc_6in_min", "swhc_6in_max",
  "swhc_12in_mean", "swhc_12in_min", "swhc_12in_max",
  "swhc_24in_mean", "swhc_24in_min", "swhc_24in_max"
)

# Add benchmark columns if available (weekly mode)
if (SIMULATION_MODE == "weekly" && USE_BENCHMARK) {
  benchmark_cols <- setdiff(names(soil_water_data), base_cols)
  output_data <- soil_water_data %>%
    select(all_of(base_cols), all_of(benchmark_cols[benchmark_cols != ""]))
} else {
  output_data <- soil_water_data %>%
    select(all_of(intersect(base_cols, names(soil_water_data))))
}

output_data <- output_data %>% arrange(cellid)

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
cat(sprintf("Mode:     %s\n", toupper(SIMULATION_MODE)))
cat(sprintf("Input:    %s\n", results_file))
cat(sprintf("Output:   %s\n", output_file))
cat(sprintf("Cells:    %d\n", nrow(output_data)))
cat(sprintf("Week:     %s W%s\n", year, week))

if (SIMULATION_MODE == "weekly" && USE_BENCHMARK) {
  n_benchmark <- sum(!is.na(output_data$swhc_6in_40yr_mean))
  cat(sprintf("Benchmark: %d cells with 40-year comparison\n", n_benchmark))
}

cat("\nNext: Proceed to Phase 3 (Report Generation)\n")
cat(sprintf("  source('code/03-generate-report.R')\n"))
cat(strrep("=", 70), "\n\n")

message(sprintf("[%s] Phase 2 finished", .ts()))
