# Step 03: Historical Benchmark - Compare current to 20+ year normals
# Input: data/processed/current-conditions.rds, historical data
# Output: data/processed/historical-stats.rds

source("code/00-config.R")

if (VERBOSE) cat("Step 03: Historical Benchmark\n")

# Placeholder: Load processed conditions
conditions <- readRDS(file.path(PATH_PROCESSED_DATA, "current-conditions.rds"))

# TODO: Load historical daily data for BASELINE_START:BASELINE_END from local cache
# TODO: Calculate percentiles for current week's metrics (tmax, tmin, precip)
# TODO: Identify anomalies (above/below normal range)
# TODO: Calculate historical extremes (record high/low, wettest/driest)

# For now, create placeholder output
historical_stats <- data.frame(
  station = unique(conditions$station),
  week = format(REPORT_DATE, "%Y-W%U"),
  tmax_pctl = 50,      # Placeholder: 50th percentile
  tmin_pctl = 50,
  precip_pctl = 50,
  tmax_anomaly = 0,    # Placeholder: 0°C deviation from normal
  tmin_anomaly = 0,
  precip_anomaly = 0
)

saveRDS(historical_stats, file.path(PATH_PROCESSED_DATA, "historical-stats.rds"))

if (VERBOSE) {
  cat("✓ Historical benchmark completed (placeholder)\n")
  cat("  Stations:", nrow(historical_stats), "\n")
}
