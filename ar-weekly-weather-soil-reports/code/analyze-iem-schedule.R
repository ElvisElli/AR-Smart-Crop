# ═══════════════════════════════════════════════════════════════════════════
# ANALYZE IEM AVAILABILITY PATTERN & RECOMMEND SCHEDULING
# ═══════════════════════════════════════════════════════════════════════════
#
# WHAT DOES THIS SCRIPT DO?
# ─────────────────────────
# This script is the ANALYST:
#   1. Reads all the observations we collected over 1-2 weeks
#   2. Looks for PATTERNS in the timing
#   3. Figures out: "What time of day does data typically arrive?"
#   4. Recommends: "Run your simulation at this time!"
#
# WHY RUN THIS?
# ─────────────
# After collecting observations, patterns emerge:
#   - 06:00 UTC: 0% had new data (too early)
#   - 14:00 UTC: 100% had new data (PERFECT!)
#   - 16:00 UTC: 0% had new data (already logged earlier)
#
# This tells us: "Always run simulations at 14:30 UTC for best results"
#
# PREREQUISITES:
# ──────────────
# Before running this, you need data from 7-14 days of checks:
#   1. Run code/00-detect-iem-availability.R at different times
#   2. Collect checks for at least 7 days
#   3. This creates: data/outputs/iem-availability-log.csv
#
# USAGE:
# ──────
#   source("code/00-config.R")
#   source("code/analyze-iem-schedule.R")  # Analyzes what you collected
#
# OUTPUT:
# ───────
#   1. Console: Detailed analysis of patterns
#   2. File: data/outputs/iem-schedule-recommendation.txt
#      (Save this! Use it to set up automated scheduling)
# ═══════════════════════════════════════════════════════════════════════════

cat("\n")
cat(strrep("═", 70), "\n")
cat("IEM AVAILABILITY PATTERN ANALYSIS\n")
cat(strrep("═", 70), "\n\n")

# Try to read the log file we created during collection phase
log_file <- file.path(PATH_OUTPUTS, "iem-availability-log.csv")

# CHECK: Do we have data to analyze?
if (!file.exists(log_file)) {
  # No data! Can't analyze without it
  cat("ERROR: No timing data found.\n")
  cat(sprintf("Expected file: %s\n\n", log_file))
  cat("To collect timing data, run at different times of day:\n")
  cat("  Rscript code/00-detect-iem-availability.R\n\n")
  cat("Collect for 7-14 days to build a reliable pattern.\n")
  quit(save = "no")  # Exit this script
}

# Read all the observations we collected
log_data <- read.csv(log_file, stringsAsFactors = FALSE)

# WARNING: Check if we have enough data
if (nrow(log_data) < 5) {
  cat(sprintf("WARNING: Only %d checks logged.\n", nrow(log_data)))
  cat("Recommend collecting for at least 7 days (50+ checks) for reliable pattern.\n\n")
}

# SUMMARY: How much data do we have?
cat(sprintf("Data points: %d checks\n", nrow(log_data)))
cat(sprintf("Date range: %s to %s\n\n",
           min(log_data$check_date), max(log_data$check_date)))

## ── Analyze data availability by hour of day ────────────────────────────
#
# WHAT: Breaks down observations by hour of day to see patterns
# WHY:  Shows which hours have fresh data available (best for scheduling)
# HOW:  Groups checks by hour (0-23), calculates % new data and average lag
# OUTPUT: Table showing data readiness throughout the day

cat("IEM DATA AVAILABILITY BY HOUR OF DAY\n")
cat(strrep("─", 70), "\n\n")

# Create empty table to fill with hourly statistics
# We'll calculate stats for each hour of day (0=midnight, 12=noon, 23=11 PM)
hourly_stats <- data.frame()

# LOOP THROUGH EACH HOUR OF DAY (0 through 23)
for (hour in 0:23) {
  # Find all checks that happened during THIS HOUR
  # (e.g., for hour=14, find all checks at 14:00-14:59)
  checks_at_hour <- log_data[log_data$check_hour == hour, ]

  # Do we have any data for this hour?
  if (nrow(checks_at_hour) > 0) {
    # YES! Calculate statistics for this hour

    # How many times did we check during this hour?
    n_checks <- nrow(checks_at_hour)

    # What percentage of those checks found NEW data?
    # (This tells us: is data typically fresh at this hour?)
    new_data_pct <- (sum(checks_at_hour$new_data_available == "YES") / n_checks) * 100

    # On average, how many hours behind "now" was the data at this hour?
    # (Lower numbers = fresher data)
    avg_lag_hours <- mean(checks_at_hour$iem_lag_hours, na.rm = TRUE)

    # What were the exact check times for this hour?
    # (e.g., "14:15:32 | 14:23:45 | 14:31:12")
    times_available <- paste(checks_at_hour$check_time_utc, collapse = " | ")

    # Add a row to our table with stats for this hour
    hourly_stats <- rbind(hourly_stats, data.frame(
      hour = hour,                                   # Which hour (0-23)
      n_checks = n_checks,                          # How many times checked in this hour
      new_data_pct = round(new_data_pct, 0),        # % of those checks with new data (rounded)
      avg_lag_hours = round(avg_lag_hours, 1),      # Average lag (hours) for this hour
      times_checked = times_available                # List of exact check times
    ))
  }
}

# PRINT THE HOURLY STATISTICS TABLE
print(hourly_stats)

## ── Identify transition times (when data becomes available) ───────────────
#
# WHAT: Finds the moments when NEW data arrived (not old data)
# WHY:  Shows the exact hours when data transitions from stale to fresh
# HOW:  Extracts hour from each "new data detected" entry, tallies by hour
# OUTPUT: List of hours when data became available + recommended run time

cat("\n")
cat("DATA ARRIVAL TIMES (When new data became available)\n")
cat(strrep("─", 70), "\n\n")

# FILTER TO ONLY THE CHECKS WHERE WE DETECTED NEW DATA
# (These are the important ones - when data transitioned from old → fresh)
new_data_times <- log_data[log_data$new_data_available == "YES", ]

# Do we have any new data detection events?
if (nrow(new_data_times) > 0) {
  # YES! We detected new data at least once. Extract the hour from each detection.
  # Convert check times (HH:MM:SS format) to just the hour (0-23)
  new_data_times$arrival_hour <- as.numeric(format(
    strptime(new_data_times$check_time_utc, "%H:%M:%S"),  # Parse time string
    "%H"  # Extract just the hour
  ))

  # Count how many times we detected new data in each hour
  # e.g., {14:5, 15:2} means: 5 times data arrived during 14:xx, 2 times during 15:xx
  arrival_hours <- table(new_data_times$arrival_hour)

  cat("Hours when NEW data typically arrived:\n\n")

  # PRINT A SUMMARY FOR EACH HOUR
  for (hour in names(arrival_hours)) {
    # How many times did new data arrive in this hour?
    count <- as.numeric(arrival_hours[hour])

    # What % of all new data arrivals was this hour?
    # (e.g., if 5 out of 7 new arrivals were at 14:xx, that's 71%)
    pct <- round((count / nrow(new_data_times)) * 100, 0)

    # Print summary for this hour
    cat(sprintf("  %02d:00-%02d:59 UTC: %d times (%d%%)\n",
               as.numeric(hour), as.numeric(hour), count, pct))
  }

  # FIND THE MOST COMMON HOUR FOR DATA ARRIVAL
  # This is the hour when new data is MOST LIKELY to become available
  most_common_hour <- as.numeric(names(arrival_hours)[which.max(arrival_hours)])

  # SUGGEST OPTIMAL RUN TIME
  cat(sprintf("\n✓ MOST COMMON: %02d:00 UTC (data typically arrives this hour)\n",
             most_common_hour))
  cat(sprintf("✓ SUGGESTED RUN TIME: %02d:30 UTC\n", most_common_hour))
  cat("  (Gives 30 minutes after data arrives for it to propagate through IEM servers)\n\n")
} else {
  # NO NEW DATA DETECTED: We haven't captured the moment when data transitions from old → fresh
  cat("Not enough new data detection events to determine arrival times.\n")
  cat("Collect more data:\n")
  cat("  1. Run timing check at different times of day (e.g., every 2-4 hours)\n")
  cat("  2. Collect for at least 7-14 days\n")
  cat("  3. This will capture the moment when data arrives\n\n")
}

## ── Generate summary report ─────────────────────────────────────────────
#
# WHAT: Compiles all findings into a professional summary report
# WHY:  Provides clear recommendations for setting up automated scheduling
# HOW:  Formats analysis results into human-readable text document
# OUTPUT: Prints to screen + saves to file for reference

cat("\n")
cat(strrep("═", 70), "\n")
cat("SUMMARY & RECOMMENDATIONS\n")
cat(strrep("═", 70), "\n\n")

# BUILD THE SUMMARY REPORT TEXT
# This creates a nicely formatted document with all the analysis results
# The sprintf function allows us to insert calculated values into the template
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
   - Schedule for: %02d:30 UTC (highest data freshness)
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
  Sys.Date(),                                    # Today's date
  nrow(log_data),                               # How many checks total?
  length(unique(log_data$check_date)),          # How many different days?
  round(mean(log_data$iem_lag_hours, na.rm = TRUE), 1),  # Average lag in hours
  format(max(as.Date(log_data$iem_latest_date)), "%Y-%m-%d"),  # Most recent data date
  # Scheduling recommendation (changes based on whether we detected new data)
  if(nrow(new_data_times) > 0) {
    sprintf("Run at %02d:30 UTC\n   (when data typically arrives)",
           most_common_hour)
  } else {
    "Collect more timing data"
  },
  # Success rate: % of checks that used actual IEM query (not fallback estimate)
  round((sum(log_data$query_success == "OK") / nrow(log_data)) * 100, 0),
  # Fallback count: how many times did we have to estimate (query failed)?
  sum(log_data$query_success == "FALLBACK"),
  # Recommended run hour for daily automation
  if(nrow(new_data_times) > 0) most_common_hour else 14,
  # Recommended overnight hour
  if(nrow(new_data_times) > 0) most_common_hour else 14
)

# PRINT THE REPORT TO SCREEN
cat(summary_text)

# SAVE REPORT TO FILE (for future reference and documentation)
# This is useful to keep as a record of when/how data becomes available
report_file <- file.path(PATH_OUTPUTS, "iem-schedule-recommendation.txt")
writeLines(summary_text, report_file)
cat(sprintf("\n✓ Report saved to: %s\n\n", report_file))

cat(strrep("═", 70), "\n\n")
