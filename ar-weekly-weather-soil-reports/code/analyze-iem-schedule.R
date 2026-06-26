# ═══════════════════════════════════════════════════════════════════════════
# Analyze IEM Availability Pattern & Recommend Scheduling
# ═══════════════════════════════════════════════════════════════════════════
#
# Purpose:
#   - Analyze timing data collected by code/00-detect-iem-availability.R
#   - Identify when IEM data typically becomes available each day
#   - Recommend optimal times to run automated simulations
#   - Report: "Data typically available at 14:00 UTC, run sims at 14:30"
#
# Prerequisites:
#   - Run 00-detect-iem-availability.R at multiple times for 7-14 days
#   - Creates: data/outputs/iem-availability-log.csv
#
# Usage:
#   source("code/00-config.R")
#   source("code/analyze-iem-schedule.R")
#
# Output:
#   - Console: Timing pattern analysis
#   - File: data/outputs/iem-schedule-recommendation.txt
#
# ═══════════════════════════════════════════════════════════════════════════

cat("\n")
cat(strrep("═", 70), "\n")
cat("IEM AVAILABILITY PATTERN ANALYSIS\n")
cat(strrep("═", 70), "\n\n")

log_file <- file.path(PATH_OUTPUTS, "iem-availability-log.csv")

if (!file.exists(log_file)) {
  cat("ERROR: No timing data found.\n")
  cat(sprintf("Expected file: %s\n\n", log_file))
  cat("To collect timing data, run at different times of day:\n")
  cat("  Rscript code/00-detect-iem-availability.R\n\n")
  cat("Collect for 7-14 days to build a reliable pattern.\n")
  quit(save = "no")
}

# Read log
log_data <- read.csv(log_file, stringsAsFactors = FALSE)

if (nrow(log_data) < 5) {
  cat(sprintf("WARNING: Only %d checks logged.\n", nrow(log_data)))
  cat("Recommend collecting for at least 7 days (50+ checks) for reliable pattern.\n\n")
}

cat(sprintf("Data points: %d checks\n", nrow(log_data)))
cat(sprintf("Date range: %s to %s\n\n",
           min(log_data$check_date), max(log_data$check_date)))

## ── Analyze data availability by hour of day ────────────────────────────

cat("IEM DATA AVAILABILITY BY HOUR OF DAY\n")
cat(strrep("─", 70), "\n\n")

# For each hour, find what % of time data is current
hourly_stats <- data.frame()

for (hour in 0:23) {
  checks_at_hour <- log_data[log_data$check_hour == hour, ]

  if (nrow(checks_at_hour) > 0) {
    # Calculate statistics
    n_checks <- nrow(checks_at_hour)
    new_data_pct <- (sum(checks_at_hour$new_data_available == "YES") / n_checks) * 100
    avg_lag_hours <- mean(checks_at_hour$iem_lag_hours, na.rm = TRUE)
    times_available <- paste(checks_at_hour$check_time_utc, collapse = " | ")

    hourly_stats <- rbind(hourly_stats, data.frame(
      hour = hour,
      n_checks = n_checks,
      new_data_pct = round(new_data_pct, 0),
      avg_lag_hours = round(avg_lag_hours, 1),
      times_checked = times_available
    ))
  }
}

print(hourly_stats)

## ── Identify transition times (when data becomes available) ───────────────

cat("\n")
cat("DATA ARRIVAL TIMES (When new data became available)\n")
cat(strrep("─", 70), "\n\n")

new_data_times <- log_data[log_data$new_data_available == "YES", ]

if (nrow(new_data_times) > 0) {
  new_data_times$arrival_hour <- as.numeric(format(
    strptime(new_data_times$check_time_utc, "%H:%M:%S"),
    "%H"
  ))

  arrival_hours <- table(new_data_times$arrival_hour)
  cat("Hours when NEW data typically arrived:\n\n")

  for (hour in names(arrival_hours)) {
    count <- as.numeric(arrival_hours[hour])
    pct <- round((count / nrow(new_data_times)) * 100, 0)
    cat(sprintf("  %02d:00-02d:59 UTC: %d times (%d%%)\n",
               as.numeric(hour), as.numeric(hour), count, pct))
  }

  # Suggest optimal run time
  most_common_hour <- as.numeric(names(arrival_hours)[which.max(arrival_hours)])
  cat(sprintf("\n✓ MOST COMMON: %02d:00 UTC (data typically arrives this hour)\n",
             most_common_hour))
  cat(sprintf("✓ SUGGESTED RUN TIME: %02d:30 UTC\n", most_common_hour))
  cat("  (Gives 30 minutes for data to propagate after arrival)\n\n")
} else {
  cat("Not enough new data detection events to determine arrival times.\n")
  cat("Collect more data (run timing check at different times for 1-2 weeks).\n\n")
}

## ── Generate summary report ─────────────────────────────────────────────

cat("\n")
cat(strrep("═", 70), "\n")
cat("SUMMARY & RECOMMENDATIONS\n")
cat(strrep("═", 70), "\n\n")

summary_text <- sprintf(
  "IEM AVAILABILITY ANALYSIS REPORT
Date: %s
Data points: %d checks across %d days

KEY FINDINGS:
─────────────

1. Data Freshness:
   - Typical lag: %s hours
   - Freshest data availability: %s

2. Optimal Scheduling:
   %s

3. Weekend Pattern:
   [Check if weekend data shows different pattern]

4. Reliability:
   - Query success rate: %d%%
   - Fallback uses: %d checks

RECOMMENDATIONS:
────────────────

1. For Automated Weekly Runs:
   - Schedule for: %02d:30-14:30 UTC (highest data freshness)
   - This gives 30 min buffer after data arrives
   - Avoid: early morning (data stale)

2. For Manual Backup Runs:
   - Check: data/outputs/iem-availability-log.csv
   - If data is fresh (lag < 2 hours), run immediately
   - If data is stale (lag > 6 hours), wait until next day

3. For Overnight/Batch Runs:
   - Optimal: %02d:00 UTC (when data typically ready)
   - Ensures using latest available data
   - Good for resource efficiency (off-peak hours)

4. Next Steps:
   - If pattern is clear: Set up GitHub Actions trigger at recommended time
   - If pattern is unclear: Collect 2 more weeks of data
   - Monitor: Check monthly for seasonal changes
",
  Sys.Date(),
  nrow(log_data),
  length(unique(log_data$check_date)),
  round(mean(log_data$iem_lag_hours, na.rm = TRUE), 1),
  format(max(as.Date(log_data$iem_latest_date)), "%Y-%m-%d"),
  if(nrow(new_data_times) > 0) {
    sprintf("Run at %02d:30 UTC\n   (when data typically arrives)",
           most_common_hour)
  } else {
    "Collect more timing data"
  },
  round((sum(log_data$query_success == "OK") / nrow(log_data)) * 100, 0),
  sum(log_data$query_success == "FALLBACK"),
  if(nrow(new_data_times) > 0) most_common_hour else 14,
  if(nrow(new_data_times) > 0) most_common_hour else 14
)

cat(summary_text)

# Write report to file
report_file <- file.path(PATH_OUTPUTS, "iem-schedule-recommendation.txt")
writeLines(summary_text, report_file)
cat(sprintf("\n✓ Report saved to: %s\n\n", report_file))

cat(strrep("═", 70), "\n\n")
