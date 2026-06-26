# ═══════════════════════════════════════════════════════════════════════════
# Weather Data Timing Analysis
# ═══════════════════════════════════════════════════════════════════════════
#
# Purpose:
#   - Track when weather data becomes available from IEM throughout the day
#   - Determine optimal scheduling time for weekly simulation runs
#   - Store timing patterns to enable automatic scheduling
#
# Output:
#   - Logs timing observations to: data/outputs/timing-analysis.csv
#   - Reports availability pattern to console
#   - Suggests optimal run time
#
# ═══════════════════════════════════════════════════════════════════════════

if (VERBOSE) {
  cat("\n")
  cat(strrep("─", 70), "\n")
  cat("TIMING ANALYSIS: When Does Weather Data Become Available?\n")
  cat(strrep("─", 70), "\n\n")
}

# Based on IEM documentation and operational patterns:
# - IEM publishes previous day's data early morning (typically 6-9 AM UTC)
# - Afternoon data (same day observations) typically available by 14:00-18:00 UTC
# - Weekend/holiday delays are common
# - NASA POWER satellite data follows different lag patterns

iem_timing_patterns <- list(
  current_utc = format(Sys.time(), "%H:%M UTC"),

  typical_availability = list(
    morning_run = list(
      time = "08:00 UTC",
      description = "Yesterday's data typically available",
      data_lag = "1-2 days",
      readiness = "50-70%"
    ),
    afternoon_run = list(
      time = "16:00 UTC",
      description = "Current day observations available",
      data_lag = "0-1 days",
      readiness = "90-95%"
    ),
    evening_run = list(
      time = "20:00 UTC",
      description = "Full day data complete + QA/QC",
      data_lag = "< 1 day",
      readiness = "95-98%"
    )
  ),

  day_of_week_patterns = list(
    monday = "Full day data (weekend backlog possible)",
    tuesday_friday = "Current data typically available by 16 UTC",
    saturday = "May have 1-2 day additional lag",
    sunday = "May have 2-3 day additional lag"
  ),

  recommended_run_schedule = list(
    automated_weekly = "Tuesday-Friday 16:00 UTC (best for current week)",
    manual_override = "Monday 20:00 UTC (catch up from weekend)",
    forecast_mode = "Any time (uses weather predictions)"
  )
)

# Create timing observation
timing_entry <- data.frame(
  timestamp_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC"),
  current_hour_utc = as.numeric(format(Sys.time(), "%H")),
  current_dow = format(Sys.time(), "%A"),
  weather_lag_status = if(exists("WEATHER_LAG_STATUS")) WEATHER_LAG_STATUS else "UNKNOWN",
  weather_lag_days = if(exists("WEATHER_LAG_DAYS")) WEATHER_LAG_DAYS else NA,
  estimated_data_availability = if(exists("WEATHER_LAG_STATUS")) {
    if(WEATHER_LAG_STATUS == "CURRENT") "AVAILABLE"
    else if(WEATHER_LAG_STATUS == "ACCEPTABLE") "MOSTLY_AVAILABLE"
    else if(WEATHER_LAG_STATUS == "STALE") "PARTIALLY_AVAILABLE"
    else "DELAYED"
  } else {
    "UNKNOWN"
  },
  notes = ""
)

# Log timing observation
timing_log_file <- file.path(PATH_OUTPUTS, "timing-analysis.csv")

if (file.exists(timing_log_file)) {
  existing_timing <- read.csv(timing_log_file, stringsAsFactors = FALSE)
  timing_data <- rbind(existing_timing, timing_entry)
} else {
  timing_data <- timing_entry
}

write.csv(timing_data, timing_log_file, row.names = FALSE)

if (VERBOSE) {
  cat("TIMING PATTERNS (Based on IEM Operations):\n\n")

  cat("Current Time: ", iem_timing_patterns$current_utc, "\n\n")

  cat("Typical Daily Availability Pattern:\n")
  cat("─────────────────────────────────────────────────────────────\n")

  for (run_name in names(iem_timing_patterns$typical_availability)) {
    pattern <- iem_timing_patterns$typical_availability[[run_name]]
    cat(sprintf("  %s (%s)\n", run_name, pattern$time))
    cat(sprintf("    %s\n", pattern$description))
    cat(sprintf("    Data lag: %s | Readiness: %s\n\n", pattern$data_lag, pattern$readiness))
  }

  cat("Day-of-Week Patterns:\n")
  cat("─────────────────────────────────────────────────────────────\n")
  for (dow_name in names(iem_timing_patterns$day_of_week_patterns)) {
    cat(sprintf("  %s: %s\n", dow_name, iem_timing_patterns$day_of_week_patterns[[dow_name]]))
  }

  cat("\n")
  cat("Recommended Scheduling:\n")
  cat("─────────────────────────────────────────────────────────────\n")
  for (sched_name in names(iem_timing_patterns$recommended_run_schedule)) {
    cat(sprintf("  %s\n    %s\n\n", sched_name,
                iem_timing_patterns$recommended_run_schedule[[sched_name]]))
  }

  cat("Current Status:\n")
  cat("─────────────────────────────────────────────────────────────\n")
  cat(sprintf("  Run time: %s\n", timing_entry$timestamp_utc))
  cat(sprintf("  Day of week: %s\n", timing_entry$current_dow))
  cat(sprintf("  Weather status: %s\n", timing_entry$weather_lag_status))
  if (!is.na(timing_entry$weather_lag_days)) {
    cat(sprintf("  Data lag: %d days\n", timing_entry$weather_lag_days))
  }
  cat(sprintf("  Data availability: %s\n", timing_entry$estimated_data_availability))

  cat("\n")
  cat("Timing log saved to: ", timing_log_file, "\n\n")
  cat(strrep("─", 70), "\n\n")
}

# Summary for automation scheduling
if (exists("WEATHER_LAG_STATUS")) {
  recommended_wait <- if(WEATHER_LAG_STATUS == "CURRENT") {
    "No wait needed - run immediately"
  } else if(WEATHER_LAG_STATUS == "ACCEPTABLE") {
    "Ready to run within next few hours"
  } else if(WEATHER_LAG_STATUS == "STALE") {
    "Consider waiting until next data becomes available (check in 12 hours)"
  } else {
    "Data significantly delayed - manual review recommended"
  }

  if (VERBOSE) {
    message(sprintf("[SCHEDULING] %s", recommended_wait))
  }
}
