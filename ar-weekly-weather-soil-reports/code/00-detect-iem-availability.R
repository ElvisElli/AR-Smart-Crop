# ═══════════════════════════════════════════════════════════════════════════
# IEM DATA AVAILABILITY DETECTION
# ═══════════════════════════════════════════════════════════════════════════
#
# WHAT DOES THIS SCRIPT DO?
# ─────────────────────────
# This script is the DETECTIVE for weather data timing:
#   1. Checks what time it is (e.g., 14:30 UTC)
#   2. Asks IEM "What's your latest weather data date?"
#   3. Records the time + the result
#   4. Detects if NEW data just arrived
#
# WHY RUN THIS?
# ─────────────
# When you run this at many different times (7-14 days worth),
# a pattern emerges:
#   - 06:00 UTC: old data (yesterday)
#   - 14:00 UTC: NEW DATA ARRIVES! ← This is what we're looking for
#   - 20:00 UTC: still fresh data
#
# HOW TO USE IT:
# ──────────────
# OPTION 1: Manual testing
#   Run manually at different times to understand the pattern
#   source("code/00-config.R")
#   source("code/00-detect-iem-availability.R")
#
# OPTION 2: Automated collection (Linux cron or GitHub Actions)
#   Schedule this to run every 2-4 hours for 1-2 weeks
#   Then analyze results with: source("code/analyze-iem-schedule.R")
#
# OUTPUT:
# ───────
# - data/outputs/iem-availability-log.csv: Records observations over time
#   Columns: check_time, iem_latest_date, data_lag_hours, new_data_available
#
# NEXT STEP:
# ──────────
# After collecting 7-14 days of data:
#   source("code/analyze-iem-schedule.R")  # Shows patterns & recommendations
# ═══════════════════════════════════════════════════════════════════════════

cat("\n")
cat(strrep("─", 70), "\n")
cat("IEM DATA AVAILABILITY CHECK\n")
cat(strrep("─", 70), "\n\n")

# Record the EXACT time we are checking
check_time_utc <- Sys.time()
# Extract just the hour (for grouping results later)
check_hour_utc <- as.numeric(format(check_time_utc, "%H"))

if (VERBOSE) {
  cat(sprintf("Check time: %s UTC\n", format(check_time_utc, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("Hour of day: %02d:00 UTC\n\n", check_hour_utc))
}

## ── FUNCTION: Query IEM ──────────────────────────────────────────────────
#
# WHAT: Asks IEM "What's the latest weather data you have?"
# WHY:  Need to know the exact latest date available right now
# HOW:  Uses apsimx to query, with fallback estimate
# RETURNS: List with latest_date, lag_hours, method used

query_iem_for_timing <- function() {
  # Record the exact time we are making this check
  # This timestamp will be used to calculate data lag (hours behind now)
  check_time <- Sys.time()

  # Wrap everything in error handling so a network failure won't crash the script
  tryCatch({
    # Check if apsimx package is available
    # apsimx is what we use to talk to the IEM weather service
    if (requireNamespace("apsimx", quietly = TRUE)) {
      # TRY TO GET ACTUAL IEM DATA
      # Query IEM for the last 5 days of weather observations
      # This tells us what the latest available date is
      iem_data <- tryCatch({
        # Request last 5 days of data from Arkansas center location
        # coordinates: -92.5 (longitude), 34.5 (latitude) - center of Arkansas
        # This will return all weather data IEM has for that location in that date range
        apsimx::get_iem(
          lonlat = c(-92.5, 34.5),  # Arkansas coordinates
          dates = c(Sys.Date() - 5, Sys.Date())  # Last 5 days
        )
      }, error = function(e) NULL)  # If query fails, return NULL and continue

      # CHECK: Did we get valid data back?
      if (!is.null(iem_data) && nrow(iem_data) > 0) {
        # SUCCESS! IEM returned data. Extract the latest date from what we got.
        latest_date <- max(iem_data$date, na.rm = TRUE)

        # CALCULATE LAG: How many hours behind now is the data?
        # We assume data from each date is complete by 23:59:00 that day
        # So if today is June 26 @ 14:30 UTC, and latest data is June 25,
        # then lag = 14:30 hours (it's 38.5 hours behind, but we count from yesterday's end)
        lag_hours <- as.numeric(difftime(check_time,
                                         as.POSIXct(paste(latest_date, "23:59:00")),
                                         units = "hours"))
        # Return successful query results
        list(
          latest_date = latest_date,        # The most recent date IEM has data for
          check_time = check_time,          # When we made this check
          lag_hours = max(0, lag_hours),    # Hours behind now (never negative)
          method = "apsimx_get_iem",        # We successfully queried IEM
          success = TRUE                    # Success flag
        )
      } else {
        # NO DATA RETURNED: IEM query ran but returned empty/NULL
        # Use safe estimate: assume data is from yesterday (typical IEM lag)
        list(
          latest_date = Sys.Date() - 1,                           # Estimate: yesterday
          check_time = check_time,
          lag_hours = 24 + as.numeric(format(check_time, "%H")), # Estimate: ~24 hours
          method = "fallback_estimate",                           # We're estimating
          success = FALSE                                         # This is not confirmed data
        )
      }
    } else {
      # APSIMX NOT INSTALLED: Can't query IEM at all
      # Use safe estimate instead
      list(
        latest_date = Sys.Date() - 1,                           # Estimate: yesterday
        check_time = check_time,
        lag_hours = 24 + as.numeric(format(check_time, "%H")), # Estimate: ~24 hours
        method = "no_apsimx",                                   # apsimx package not available
        success = FALSE                                         # This is an estimate, not real data
      )
    }
  }, error = function(e) {
    # CATCH ANY UNEXPECTED ERROR: Network timeout, etc.
    # Return safe estimate so script doesn't crash
    list(
      latest_date = Sys.Date() - 1,                 # Estimate: yesterday
      check_time = Sys.time(),
      lag_hours = NA,                               # Unknown lag
      method = "error",                             # Something went wrong
      success = FALSE,                              # This is an estimate
      error_msg = e$message                         # Save error details for logging
    )
  })
}

## ── Check if new data has become available ────────────────────────────────
#
# WHAT: Compares current check to previous checks to detect NEW data arrivals
# WHY:  We want to mark the MOMENT when data becomes available (important for timing)
# HOW:  Reads log file and compares latest date from this check to last check
# RETURNS: TRUE if new data detected, FALSE if same as last check

check_for_new_data <- function(latest_date) {
  # Get path to log file (where we record observations over time)
  log_file <- file.path(PATH_OUTPUTS, "iem-availability-log.csv")

  # Check if log file exists yet
  if (!file.exists(log_file)) {
    # First time running this script - no previous checks to compare to
    # Always return TRUE to mark the first observation
    return(TRUE)  # "New data" for the very first check
  }

  # COMPARE WITH PREVIOUS CHECK
  # Read the log file to see what date we found last time
  tryCatch({
    # Load the entire log history
    existing_log <- read.csv(log_file, stringsAsFactors = FALSE)

    # Make sure we have data to compare
    if (nrow(existing_log) > 0) {
      # Get the most recent check's date (last row)
      last_date <- tail(existing_log$iem_latest_date, 1)

      # Compare: Is today's latest date NEWER than the last check's latest date?
      # If yes, that means NEW DATA just became available!
      return(as.Date(latest_date) > as.Date(last_date))
    } else {
      # Log file exists but is empty - treat as new data
      return(TRUE)
    }
  }, error = function(e) {
    # If we can't read the log, play it safe and return TRUE (assume new data)
    TRUE
  })
}

## ── Main: Query and Log ───────────────────────────────────────────────────
#
# STEP 1: CALL QUERY FUNCTION TO ASK IEM "WHAT'S YOUR LATEST DATA?"

# Query IEM for the latest available data date
result <- query_iem_for_timing()

# Show the results on screen if VERBOSE mode is enabled
if (VERBOSE) {
  cat(sprintf("Query result:\n"))
  cat(sprintf("  Method: %s\n", result$method))           # How we got the data
  cat(sprintf("  Latest IEM data: %s\n", result$latest_date))  # What date did we find?
  cat(sprintf("  Lag: %.1f hours\n", result$lag_hours))   # How old is it?
  cat(sprintf("  Success: %s\n\n", if(result$success) "YES" else "NO (fallback)"))  # Real data or estimate?
}

# STEP 2: CHECK IF THIS IS NEW DATA (DIFFERENT FROM LAST CHECK)
# This is important for timing - we want to know WHEN data became available
is_new <- check_for_new_data(result$latest_date)

# STEP 3: BUILD A LOG ENTRY (ONE ROW OF DATA TO SAVE)
# This creates a record of: what time we checked, what data we found, whether it was new
log_entry <- data.frame(
  check_date = as.Date(check_time_utc),                   # Date of this check
  check_time_utc = format(check_time_utc, "%H:%M:%S"),   # Exact time (HH:MM:SS)
  check_hour = check_hour_utc,                            # Hour of day (0-23) for grouping
  iem_latest_date = format(result$latest_date, "%Y-%m-%d"),  # What date's data does IEM have?
  iem_lag_hours = round(result$lag_hours, 1),            # How many hours behind now?
  new_data_available = if(is_new) "YES" else "NO",       # Is this NEW compared to last check?
  query_method = result$method,                           # How did we get this data?
  query_success = if(result$success) "OK" else "FALLBACK" # Real query or estimate?
)

# STEP 4: APPEND TO LOG FILE
# This creates a running record over many days of observation

log_file <- file.path(PATH_OUTPUTS, "iem-availability-log.csv")

# Check if log file already exists
if (file.exists(log_file)) {
  # LOG EXISTS: Read the old data and add our new entry
  existing_log <- read.csv(log_file, stringsAsFactors = FALSE)

  # Handle case where we added new columns to the CSV format
  # (e.g., if this version has more columns than an old run)
  # Make sure old rows have NA values for any new columns
  for (col in names(log_entry)) {
    if (!col %in% names(existing_log)) {
      existing_log[[col]] <- NA  # Fill new column with blanks for old rows
    }
  }

  # Combine old log + new entry
  log_data <- rbind(existing_log, log_entry)
} else {
  # LOG DOESN'T EXIST YET: This is the first check
  log_data <- log_entry
}

# Write the combined log back to file
write.csv(log_data, log_file, row.names = FALSE)

# PRINT SUMMARY TO SCREEN (if VERBOSE mode enabled)
if (VERBOSE) {
  cat(sprintf("✓ Logged to: %s\n", log_file))                     # Show where it was saved
  cat(sprintf("  Check time: %s UTC\n", log_entry$check_time_utc)) # What time did we check?
  cat(sprintf("  Latest data: %s\n", log_entry$iem_latest_date))   # What date did IEM have?
  cat(sprintf("  Lag: %.1f hours\n", log_entry$iem_lag_hours))     # How far behind now?
  cat(sprintf("  New data: %s\n", log_entry$new_data_available))   # Was this new?

  # HIGHLIGHT IF NEW DATA DETECTED
  # This is the key moment - when data arrives!
  if (is_new) {
    cat("\n⭐ NEW DATA DETECTED!\n")  # Eye-catching marker for new data
    cat(sprintf("   Data for %s became available at %s UTC\n",
               result$latest_date, log_entry$check_time_utc))
    cat("   This is an optimal time to run simulations.\n")
    cat("   → Use this timestamp to configure your automated scheduler!\n")
  }

  cat("\n")
}

# PRINT FINAL SUMMARY AND INSTRUCTIONS
cat(strrep("─", 70), "\n")
cat(sprintf("Total checks logged: %d\n", nrow(log_data)))         # How many times have we checked?
cat("\n")
cat("NEXT STEPS:\n")
cat("─────────────\n")
cat("To discover WHEN data becomes available each day:\n")
cat("  1. Run this script at many different times (every 2-4 hours)\n")
cat("  2. Collect observations for 7-14 days (build a pattern)\n")
cat("  3. Analyze results with: source('code/analyze-iem-schedule.R')\n\n")
cat("This will show you the optimal time to schedule your simulations!\n")
cat(strrep("─", 70), "\n\n")
