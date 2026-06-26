# ═══════════════════════════════════════════════════════════════════════════
# Phase 5: Historical Baseline Generation (40-Year Benchmark)
# ═══════════════════════════════════════════════════════════════════════════
#
# Generates comprehensive 40-year (1985-2025) baseline statistics for benchmarking
# weekly reports against historical conditions.
#
# Input:  1985-2025 weather data + soil profiles
# Output: data/outputs/benchmark/historical-statistics.rds
#         - Yearly aggregated soil water metrics
#         - Decadal statistics (1985-1994, 1995-2004, etc.)
#         - 40-year mean/std/percentiles
#
# Note: Run this ONCE to generate baseline. Rerun yearly when new data available.
#
# ═══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(data.table)
})

.ts <- function() format(Sys.time(), "%H:%M:%S")

## ── Load configuration ──────────────────────────────────────────────────────

cat("\n")
source("code/00-config.R", local = TRUE)

# Override mode to historical
SIMULATION_MODE <- "historical"

message(sprintf("[%s] HISTORICAL BASELINE GENERATION started\n", .ts()))
message(sprintf("[INFO] Generating 40-year benchmark (1985-2025)\n"))

## ── Check prerequisites ────────────────────────────────────────────────────

benchmark_file <- file.path(PATH_BENCHMARK, "historical-statistics.rds")
results_dir <- file.path(PATH_PROCESSED, "historical")

message(sprintf("[INPUT] Loading Phase 1 results from: %s/", results_dir))

# Check if historical results exist
if (!dir.exists(results_dir)) {
  message(sprintf("[ERROR] Historical results not found in %s", results_dir))
  message(sprintf("[ACTION] Run Phase 1 in HISTORICAL mode first:"))
  message(sprintf("        SIMULATION_MODE <- 'historical'"))
  message(sprintf("        source('code/01-simulation.R')\n"))
  stop("Cannot generate benchmark without Phase 1 historical results")
}

# Load all yearly results from Phase 1 historical mode
yearly_files <- list.files(results_dir, pattern = "simulation-results-.*\\.rds$")

if (length(yearly_files) == 0) {
  stop(sprintf("[ERROR] No yearly simulation files found in %s", results_dir))
}

message(sprintf("[INPUT] Found %d years of results\n", length(yearly_files)))

## ── Aggregate historical results ────────────────────────────────────────────

message(sprintf("[%s] Aggregating yearly results", .ts()))

all_results <- data.frame()

for (file in sort(yearly_files)) {
  year <- as.numeric(gsub("simulation-results-|.rds", "", file))
  filepath <- file.path(results_dir, file)

  yearly_data <- readRDS(filepath)
  if (nrow(yearly_data) > 0) {
    all_results <- rbind(all_results, yearly_data)
  }
}

message(sprintf("[PROCESS] Aggregated: %d rows × %d columns",
               nrow(all_results), ncol(all_results)))

## ── Calculate benchmark statistics ──────────────────────────────────────────

message(sprintf("[%s] Calculating benchmark statistics\n", .ts()))

# Group by cell and year
yearly_stats <- all_results %>%
  group_by(cellid, x, y, year = as.numeric(format(date, "%Y"))) %>%
  summarise(
    swhc_6in_mean = mean(swhc_6in, na.rm = TRUE),
    swhc_12in_mean = mean(swhc_12in, na.rm = TRUE),
    swhc_24in_mean = mean(swhc_24in, na.rm = TRUE),
    swhc_6in_sd = sd(swhc_6in, na.rm = TRUE),
    swhc_12in_sd = sd(swhc_12in, na.rm = TRUE),
    swhc_24in_sd = sd(swhc_24in, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  )

# Calculate 40-year statistics for each cell
baseline_40yr <- yearly_stats %>%
  group_by(cellid, x, y) %>%
  summarise(
    # 40-year means
    swhc_6in_40yr_mean = mean(swhc_6in_mean, na.rm = TRUE),
    swhc_12in_40yr_mean = mean(swhc_12in_mean, na.rm = TRUE),
    swhc_24in_40yr_mean = mean(swhc_24in_mean, na.rm = TRUE),
    # Standard deviations across years
    swhc_6in_40yr_sd = sd(swhc_6in_mean, na.rm = TRUE),
    swhc_12in_40yr_sd = sd(swhc_12in_mean, na.rm = TRUE),
    swhc_24in_40yr_sd = sd(swhc_24in_mean, na.rm = TRUE),
    # Percentiles
    swhc_6in_p10 = quantile(swhc_6in_mean, 0.10, na.rm = TRUE),
    swhc_6in_p25 = quantile(swhc_6in_mean, 0.25, na.rm = TRUE),
    swhc_6in_p75 = quantile(swhc_6in_mean, 0.75, na.rm = TRUE),
    swhc_6in_p90 = quantile(swhc_6in_mean, 0.90, na.rm = TRUE),
    swhc_12in_p10 = quantile(swhc_12in_mean, 0.10, na.rm = TRUE),
    swhc_12in_p25 = quantile(swhc_12in_mean, 0.25, na.rm = TRUE),
    swhc_12in_p75 = quantile(swhc_12in_mean, 0.75, na.rm = TRUE),
    swhc_12in_p90 = quantile(swhc_12in_mean, 0.90, na.rm = TRUE),
    swhc_24in_p10 = quantile(swhc_24in_mean, 0.10, na.rm = TRUE),
    swhc_24in_p25 = quantile(swhc_24in_mean, 0.25, na.rm = TRUE),
    swhc_24in_p75 = quantile(swhc_24in_mean, 0.75, na.rm = TRUE),
    swhc_24in_p90 = quantile(swhc_24in_mean, 0.90, na.rm = TRUE),
    n_years = n(),
    .groups = "drop"
  )

# Calculate decadal statistics
decadal_stats <- yearly_stats %>%
  mutate(decade = floor(year / 10) * 10) %>%
  group_by(cellid, x, y, decade) %>%
  summarise(
    swhc_6in_mean = mean(swhc_6in_mean, na.rm = TRUE),
    swhc_12in_mean = mean(swhc_12in_mean, na.rm = TRUE),
    swhc_24in_mean = mean(swhc_24in_mean, na.rm = TRUE),
    n_years = n(),
    .groups = "drop"
  )

message(sprintf("[STATS] 40-year baseline: %d cells", nrow(baseline_40yr)))
message(sprintf("[STATS] Decadal stats: %d cell-decade combinations", nrow(decadal_stats)))

## ── Package and save benchmark ──────────────────────────────────────────────

benchmark <- list(
  generated_date = Sys.Date(),
  period = "1985-2025",
  n_cells = nrow(baseline_40yr),
  n_years = 40,

  # Main benchmark: 40-year statistics per cell
  baseline_40yr = baseline_40yr,

  # Supporting: Yearly breakdown
  yearly_stats = yearly_stats,

  # Supporting: Decadal means
  decadal_stats = decadal_stats,

  # Metadata
  metadata = list(
    description = "40-year (1985-2025) soil water holding capacity baseline",
    variables = c("swhc_6in", "swhc_12in", "swhc_24in"),
    depths = "6-inch, 12-inch, 24-inch",
    cultivar = CULTIVAR,
    sowing_date = SOW_DATE
  )
)

message(sprintf("[%s] Saving benchmark: %s", .ts(), benchmark_file))
dir.create(dirname(benchmark_file), showWarnings = FALSE, recursive = TRUE)
saveRDS(benchmark, benchmark_file)

message(sprintf("[OUTPUT] ✓ Benchmark saved: %s", benchmark_file))
message(sprintf("[OUTPUT] File size: %.2f MB", file.size(benchmark_file) / (1024^2)))

## ── Print summary ──────────────────────────────────────────────────────────

cat("\n")
cat(strrep("=", 70), "\n")
cat("HISTORICAL BASELINE GENERATION COMPLETE\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Period:     1985-2025 (40 years)\n"))
cat(sprintf("Cells:      %d\n", nrow(baseline_40yr)))
cat(sprintf("Output:     %s\n", benchmark_file))
cat("\nBenchmark statistics available:\n")
cat("  - 40-year means & standard deviations\n")
cat("  - 10th, 25th, 75th, 90th percentiles\n")
cat("  - Decadal aggregations (1985-1994, etc.)\n")
cat("  - Yearly breakdown for custom analysis\n")
cat("\nUsage in Weekly mode:\n")
cat("  Weekly reports will compare current conditions vs. this baseline\n")
cat("  UPDATE reports/weekly-report-template.qmd to add benchmark tables\n\n")

cat(strrep("=", 70), "\n\n")

message(sprintf("[%s] Historical baseline generation finished", .ts()))
