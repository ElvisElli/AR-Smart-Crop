# ═══════════════════════════════════════════════════════════════════════════
# TIMING ANALYSIS: When Does Weather Data Become Available?
# ═══════════════════════════════════════════════════════════════════════════
#
# WHAT DOES THIS SCRIPT DO?
# ─────────────────────────
# This script tracks WHEN during the day IEM data becomes available.
# It logs the time of day we checked and whether new data arrived.
#
# WHY IS THIS USEFUL?
# ───────────────────
# If we know data arrives at 14:00 UTC every day, we can:
#   1. Schedule the simulation to run at 14:30 UTC
#   2. Guarantee it uses the freshest data possible
#   3. Avoid running at times when data isn't ready yet
#
# HOW TO USE IT?
# ──────────────
# Run this script at different times (automated or manually):
#   - 06:00 UTC: check if data is ready
#   - 14:00 UTC: check if data is ready
#   - 20:00 UTC: check if data is ready
#
# After 7-14 days of collection, patterns emerge. Analyze with:
#   source("code/analyze-iem-schedule.R")
#
# OUTPUTS:
# ────────
# - data/outputs/timing-analysis.csv: Records what we found at each check
# - Console messages: Shows when new data is detected
# ═══════════════════════════════════════════════════════════════════════════

if (VERBOSE) {
  cat("\n")
  cat(strrep("─", 70), "\n")
  cat("TIMING ANALYSIS: When Does Weather Data Become Available?\n")
  cat(strrep("─", 70), "\n\n")
}

# ─────────────────────────────────────────────────────────────────────────
# TYPICAL IEM AVAILABILITY PATTERNS
# ─────────────────────────────────────────────────────────────────────────
# Based on historical IEM operational patterns:
#   - Early morning (06-09 UTC): Yesterday's data available
#   - Afternoon (14-16 UTC): TODAY'S data starts arriving (typical)
#   - Evening (18-20 UTC): Full day data + quality checks complete
#   - Weekends: May have delays or extended times to process

# Create a list of TYPICAL availability patterns
# This helps us understand what times are best
iem_timing_patterns <- list(
  # What time is it now? (in UTC)
  current_utc = format(Sys.time(), "%H:%M UTC"),

  # Typical availability by time of day
  typical_availability = list(
    # Morning: older data
    morning_run = list(
      time = "08:00 UTC",
      description = "Yesterday's data typically available",
      data_lag = "1-2 days",
      readiness = "50-70%"  # Data is old, but available
    ),
    # Afternoon: fresh data arrives
    afternoon_run = list(
      time = "16:00 UTC",
      description = "Current day observations available",
      data_lag = "0-1 days",
      readiness = "90-95%"  # BEST TIME - data is very fresh
    ),
    # Evening: data is fully processed
    evening_run = list(
      time = "20:00 UTC",
      description = "Full day data complete + QA/QC",
      data_lag = "< 1 day",
      readiness = "95-98%"  # Excellent quality
    )
  ),

  # Different days of week have different patterns
  day_of_week_patterns = list(
    monday = "Full day data (weekend backlog possible)",
    tuesday_friday = "Current data typically available by 16 UTC",  # BEST DAYS
    saturday = "May have 1-2 day additional lag",
    sunday = "May have 2-3 day additional lag"
  ),

  # Recommended times to schedule automated runs
  recommended_run_schedule = list(
    automated_weekly = "Tuesday-Friday 16:00 UTC (best for current week)",
    manual_override = "Monday 20:00 UTC (catch up from weekend)",
    forecast_mode = "Any time (uses weather predictions)"
  )
)

# ─────────────────────────────────────────────────────────────────────────
# RECORD THIS OBSERVATION
# ─────────────────────────────────────────────────────────────────────────
# Create one row of data to add to our timing log
# This row records: what time, what day, what weather status

timing_entry <- data.frame(
  timestamp_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC"),     # Exact time we checked
  current_hour_utc = as.numeric(format(Sys.time(), "%H")),        # Hour of day (0-23)
  current_dow = format(Sys.time(), "%A"),                         # Day of week (Monday, Tuesday, etc)
  weather_lag_status = if(exists("WEATHER_LAG_STATUS")) WEATHER_LAG_STATUS else "UNKNOWN",  # Status from Phase 0
  weather_lag_days = if(exists("WEATHER_LAG_DAYS")) WEATHER_LAG_DAYS else NA,              # How old (days)
  estimated_data_availability = if(exists("WEATHER_LAG_STATUS")) {
    # Convert status to availability for easy understanding
    if(WEATHER_LAG_STATUS == "CURRENT") "AVAILABLE"
    else if(WEATHER_LAG_STATUS == "ACCEPTABLE") "MOSTLY_AVAILABLE"
    else if(WEATHER_LAG_STATUS == "STALE") "PARTIALLY_AVAILABLE"
    else "DELAYED"
  } else {
    "UNKNOWN"
  },
  notes = ""  # Free space for any comments
)

# ─────────────────────────────────────────────────────────────────────────
# APPEND TO TIMING LOG FILE
# ─────────────────────────────────────────────────────────────────────────
# This creates a running record of observations over time

timing_log_file <- file.path(PATH_OUTPUTS, "timing-analysis.csv")

if (file.exists(timing_log_file)) {
  # If log exists, read it and add our new observation
  existing_timing <- read.csv(timing_log_file, stringsAsFactors = FALSE)
  timing_data <- rbind(existing_timing, timing_entry)  # Combine old + new
} else {
  # If log doesn't exist yet, this is the first entry
  timing_data <- timing_entry
}

# Write the combined data back to the CSV file
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
