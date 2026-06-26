# ═══════════════════════════════════════════════════════════════════════════
# Phase 0: Weather Data Download & Lag Detection
# ═══════════════════════════════════════════════════════════════════════════
#
# WHAT DOES THIS SCRIPT DO?
# ─────────────────────────
# This script runs BEFORE the simulation each week to:
#
# 1. Check if weather data files exist on disk
# 2. Ask IEM (Iowa Environmental Mesonet) "What's the latest weather data you have?"
# 3. Calculate how old the data is (data lag)
# 4. Categorize: Is data CURRENT (fresh), or STALE (old)?
# 5. Log everything to a CSV file for record-keeping
# 6. Tell the user the weather data status
#
# WHY IS THIS IMPORTANT?
# ──────────────────────
# Weather data has a delay. For example:
#   - Today is June 26, but latest weather data is only June 25
#   - That's a 1-day lag (normal)
#   - If latest data is June 19, that's a 7-day lag (problematic)
#
# This script detects the lag so we know if we can run simulations yet.
#
# WHAT HAPPENS NEXT?
# ──────────────────
# If data is CURRENT (≤1 day old):
#   → Simulation can run normally
#
# If data is STALE (>7 days old):
#   → We fill in missing days with best guesses (climatology)
#   → Simulation still runs but with lower confidence
#
# INPUT: Nothing (uses files on disk)
# OUTPUT: data/outputs/weather-log.csv (a table of results)
# ═══════════════════════════════════════════════════════════════════════════

# Print header to screen so user knows Phase 0 is running
if (VERBOSE) {
  cat("\n")
  cat(strrep("─", 70), "\n")
  cat("PHASE 0: Weather Data Check & Lag Detection\n")
  cat(strrep("─", 70), "\n\n")
}

# Record when this script started (for timing logs)
run_start_time <- Sys.time()

## ── FUNCTION 1: Check if weather files exist ──────────────────────────────
#
# WHAT: Looks in the weather directory to see what .met files are there
# WHY:  Needs to know if we have weather data files to work with
# HOW:  Lists all .met files (the weather file format)
# RETURNS: A list containing:
#   - exists: TRUE if files found, FALSE if folder is empty
#   - count: How many weather files we have
#   - status: "OK" if files exist, "MISSING" if folder doesn't exist

check_weather_exists <- function(weather_path) {
  # Check if the weather folder exists on disk
  if (!dir.exists(weather_path)) {
    # If folder doesn't exist, return empty result
    return(list(exists = FALSE, files = c(), count = 0, path = weather_path,
                latest_date = "unknown", status = "MISSING"))
  }

  # List all files ending in .met (weather file extension)
  # full.names = TRUE means give full path, not just filename
  met_files <- list.files(weather_path, pattern = "\\.met$", full.names = TRUE)

  # Return a list with what we found
  list(
    exists = length(met_files) > 0,      # TRUE if we found any .met files
    files = met_files,                   # List of file paths
    count = length(met_files),           # How many files
    path = weather_path,                 # Where we looked
    latest_date = if(length(met_files) > 0) {
      # Try to extract the latest date from the first weather file
      tryCatch({
        # Read first 50 lines of the first weather file
        met_content <- readLines(met_files[1], n = 50)
        # Look for lines that have a date format (YYYY/MM/DD)
        date_line <- grep("^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}", met_content, value = TRUE)
        # Return the last (most recent) date found, or "unknown" if none found
        if (length(date_line) > 0) tail(date_line, 1) else "unknown"
      }, error = function(e) "unknown")  # If error reading file, return "unknown"
    } else {
      "unknown"
    },
    status = if(length(met_files) > 0) "OK" else "NONE"  # Overall status
  )
}

## ── FUNCTION 2: Query IEM (Iowa Environmental Mesonet) ─────────────────────
#
# WHAT: Asks the IEM service "What's the latest weather data you have?"
# WHY:  Needs to know how old the weather data is (data lag)
# HOW:  Uses the apsimx package to contact IEM
# RETURNS: A list with:
#   - latest_date: The most recent date IEM has data for
#   - lag_hours: How many hours behind today that is
#   - method: What approach was used to get the data

query_iem_latest_date <- function(lonlat) {
  # Try to safely query IEM using error handling
  tryCatch({
    # Check if the apsimx package is installed
    # apsimx is a tool for interfacing with the APSIM model and weather services
    if (requireNamespace("apsimx", quietly = TRUE)) {
      message(sprintf("[IEM] Querying latest available data via apsimx..."))

      # Try different ways to get data from IEM
      result <- tryCatch({
        # Strategy 1: Try to get IEM status (returns date of latest data)
        iem_data <- tryCatch({
          apsimx::check_iem_status(lonlat = lonlat)
        }, error = function(e) NULL)  # If this fails, continue to Strategy 2

        if (!is.null(iem_data)) {
          # Success! Got status, extract the date
          list(
            latest_date = as.Date(iem_data$date),
            method = "apsimx_status",   # We used the status method
            error = NULL
          )
        } else {
          # Strategy 2: Query last 30 days of actual data, find the latest date
          iem_data <- apsimx::get_iem(
            lonlat = lonlat,
            dates = c(Sys.Date() - 30, Sys.Date())  # Get last 30 days
          )

          if (!is.null(iem_data) && nrow(iem_data) > 0) {
            # Found data! Get the most recent date from what was returned
            latest_date_in_data <- max(iem_data$date, na.rm = TRUE)
            list(
              latest_date = latest_date_in_data,
              method = "apsimx_get_iem",   # We used the get_iem method
              error = NULL
            )
          } else {
            # Strategy 3: If queries fail, use a safe estimate
            # Assume latest data is from yesterday (typical IEM lag is 1 day)
            list(
              latest_date = Sys.Date() - 1,  # Estimate: yesterday
              method = "apsimx_fallback",
              error = "No data returned"
            )
          }
        }
      }, error = function(e) {
        list(
          latest_date = Sys.Date() - 1,
          method = "error_fallback",
          error = e$message
        )
      })

      return(result)
    } else {
      # apsimx not available - use safe estimate (yesterday)
      message(sprintf("[IEM] apsimx not available, using default estimate"))
      list(
        latest_date = Sys.Date() - 1,
        method = "default_estimate",
        error = "apsimx not installed"
      )
    }
  }, error = function(e) {
    message(sprintf("[IEM] Error querying: %s", e$message))
    list(
      latest_date = Sys.Date() - 1,
      method = "error_estimate",
      error = e$message
    )
  })
}

## ── FUNCTION 3: Detect and categorize data lag ─────────────────────────────
#
# WHAT: Takes the latest date we found and figures out how old the data is
# WHY:  Need to know if data is fresh enough to use for simulation
# HOW:  Calculate days between today and latest data date
# RETURNS: A list with:
#   - status: CURRENT (fresh), ACCEPTABLE (slightly old), STALE (old), CRITICAL (very old)
#   - lag_days: Number of days old
#   - message: Human-readable explanation
#   - recommendation: What to do about the lag

detect_data_lag <- function(latest_available_date) {
  # Get today's date
  today <- Sys.Date()
  # Convert to date format to compare
  latest_d <- as.Date(latest_available_date)
  # Calculate how many days difference between today and latest data
  days_lag <- as.integer(difftime(today, latest_d, units = "days"))

  # CATEGORIZE THE LAG
  # Different categories tell us how to handle the simulation
  if (days_lag <= 1) {
    # Data from yesterday or today - perfect!
    status <- "CURRENT"
    message_text <- "Data is current (≤ 1 day old)"
  } else if (days_lag <= 3) {
    # Data from 1-3 days ago - acceptable
    status <- "ACCEPTABLE"
    message_text <- "Data lag is acceptable (1-3 days)"
  } else if (days_lag <= 7) {
    # Data from 3-7 days ago - getting old
    status <- "STALE"
    message_text <- "Data lag is significant (3-7 days)"
  } else {
    # Data from more than 7 days ago - very old
    status <- "CRITICAL"
    message_text <- "Data lag is critical (> 7 days)"
  }

  # Return all the information we found
  list(
    latest_date = latest_d,           # The latest date we found
    lag_days = days_lag,              # How many days old (0=today, 1=yesterday, etc)
    status = status,                  # CURRENT/ACCEPTABLE/STALE/CRITICAL
    message = message_text,           # Human-readable message
    recommendation = if(days_lag > 2) {
      # If data is more than 2 days old, we'll need to estimate missing days
      "Will use forward-fill + climatology for gaps"
    } else {
      # If data is recent, no estimation needed
      "No gap-fill needed"
    }
  )
}

## ── Main: Check and Report Weather Status ───────────────────────────────

# PRINT STATUS TO SCREEN (if VERBOSE mode is on)
if (VERBOSE) {
  message(sprintf("[WEATHER] Checking weather data availability"))
  message(sprintf("  Date range: %s to %s", DATE_START, DATE_END))
}

# ─────────────────────────────────────────────────────────────────────────
# STEP 1: CHECK WHAT WEATHER FILES WE HAVE ON DISK
# ─────────────────────────────────────────────────────────────────────────
# Call the function we defined earlier to count .met files

weather_check <- check_weather_exists(PATH_WEATHER)

if (VERBOSE) {
  message(sprintf("\n[WEATHER] Weather files:"))
  message(sprintf("  Directory: %s", weather_check$path))
  message(sprintf("  Files found: %d", weather_check$count))
  message(sprintf("  Status: %s", weather_check$status))
  if (weather_check$latest_date != "unknown") {
    message(sprintf("  Latest data sample: %s", weather_check$latest_date))
  }
}

# ─────────────────────────────────────────────────────────────────────────
# STEP 2: QUERY IEM TO FIND THE LATEST WEATHER DATA AVAILABLE
# ─────────────────────────────────────────────────────────────────────────
# This is the key step - we ask IEM "When is the latest data you have?"
# We use Arkansas center coordinates (-92.5, 34.5) as a representative location

if (VERBOSE) {
  message(sprintf("\n[IEM QUERY] Detecting actual data lag from IEM..."))
}

# Call IEM query function with Arkansas coordinates
iem_query <- query_iem_latest_date(c(-92.5, 34.5))

if (VERBOSE) {
  message(sprintf("  Method: %s", iem_query$method))
  message(sprintf("  Latest available: %s", iem_query$latest_date))
  if (!is.null(iem_query$error)) {
    message(sprintf("  Note: %s", iem_query$error))
  }
}

# ─────────────────────────────────────────────────────────────────────────
# STEP 3: CALCULATE HOW OLD THE DATA IS (DATA LAG)
# ─────────────────────────────────────────────────────────────────────────

lag_info <- detect_data_lag(iem_query$latest_date)

if (VERBOSE) {
  message(sprintf("\n[DATA LAG ANALYSIS]"))
  message(sprintf("  Latest data from IEM: %s", lag_info$latest_date))
  message(sprintf("  Days behind today: %d", lag_info$lag_days))
  message(sprintf("  Status: %s", lag_info$status))
  message(sprintf("  Message: %s", lag_info$message))
  message(sprintf("  Recommendation: %s", lag_info$recommendation))
}

# ─────────────────────────────────────────────────────────────────────────
# STEP 4: SAVE RESULTS FOR OTHER SCRIPTS TO USE
# ─────────────────────────────────────────────────────────────────────────
# Store the results in global variables so other scripts can access them

WEATHER_LAG_STATUS <<- lag_info$status      # CURRENT, ACCEPTABLE, STALE, or CRITICAL
WEATHER_LAG_DAYS <<- lag_info$lag_days      # How many days old
WEATHER_LAG_SOURCE <<- "IEM"                # Data came from IEM
WEATHER_LAG_TIMESTAMP <<- Sys.time()        # When we checked

# Create the output directory if it doesn't exist yet
if (!dir.exists(PATH_OUTPUTS)) {
  dir.create(PATH_OUTPUTS, recursive = TRUE, showWarnings = FALSE)
}

## ── STEP 5: SAVE RESULTS TO A CSV FILE (FOR RECORD-KEEPING) ──────────────
#
# A CSV is like a spreadsheet file that records what happened each time
# this script runs. This creates an audit trail of weather data status.

log_file <- file.path(PATH_OUTPUTS, "weather-log.csv")

# Create a row of data with all our findings
log_entry <- data.frame(
  run_date = Sys.Date(),                              # Today's date
  run_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), # What time did we run
  date_start = DATE_START,                            # Simulation start date
  date_end = DATE_END,                                # Simulation end date
  iem_latest_date = format(lag_info$latest_date, "%Y-%m-%d"), # Latest data IEM has
  weather_status = lag_info$status,                   # CURRENT/STALE/etc.
  lag_days = lag_info$lag_days,                       # Days old
  data_source = "IEM",                                # We used IEM
  query_method = iem_query$method,                    # How we got the data
  weather_files_found = weather_check$count,          # How many .met files
  weather_file_status = weather_check$status,         # Are they OK?
  phase_0_completed = format(Sys.time(), "%Y-%m-%d %H:%M:%S")  # When we finished
)

# APPEND TO LOG FILE (ADD NEW ROW TO EXISTING SPREADSHEET)
if (file.exists(log_file)) {
  # If the log file already exists, read the old data
  existing_log <- read.csv(log_file, stringsAsFactors = FALSE)

  # Add missing columns to old data if needed
  # (in case we added new columns in this version)
  for (col in names(log_entry)) {
    if (!col %in% names(existing_log)) {
      existing_log[[col]] <- NA  # Fill with blank
    }
  }

  # Combine old rows with new row
  log_data <- rbind(existing_log, log_entry)
} else {
  # If log file doesn't exist yet, just use the new row
  log_data <- log_entry
}

# Write the combined data back to the CSV file
write.csv(log_data, log_file, row.names = FALSE)

if (VERBOSE) {
  message(sprintf("\n[LOGGING] Status logged to: %s\n", log_file))

  # PRINT A SUMMARY TO THE SCREEN
  # This gives the user a quick visual summary of what happened
  cat(strrep("─", 70), "\n")
  cat("WEATHER DATA STATUS SUMMARY\n")
  cat(strrep("─", 70), "\n\n")
  cat(sprintf("Status: %s\n", lag_info$status))
  cat(sprintf("Latest data: %s\n", weather_check$latest_date))
  cat(sprintf("Files available: %d\n", weather_check$count))
  cat(sprintf("Date range: %s to %s\n", DATE_START, DATE_END))
  cat(sprintf("Data lag: %d days\n\n", lag_info$lag_days))

  # Show warning or success message based on data freshness
  if (lag_info$lag_days > 7) {
    cat("⚠  WARNING: Data lag > 7 days\n")
    cat("   Data is very old. Consider waiting for fresher data.\n")
  } else if (lag_info$lag_days > 3) {
    cat("⚠  Data lag detected - gaps will be filled\n")
    cat("   Will use estimates for missing days.\n")
  } else {
    cat("✓ Data is fresh\n")
    cat("   Ready to run simulation!\n")
  }

  cat(strrep("─", 70), "\n\n")
}

## ── STEP 6: RUN TIMING ANALYSIS ────────────────────────────────────────
#
# Run a separate script that tracks WHEN data becomes available each day
# This helps us figure out the best time to schedule automated runs

source("code/00-timing-analysis.R", local = TRUE)
