# ═══════════════════════════════════════════════════════════════════════════
# IEM Data Availability Detection
# ═══════════════════════════════════════════════════════════════════════════
#
# Purpose:
#   - Run throughout the day to detect when IEM data becomes available
#   - Build a timeline showing latest available date at each check time
#   - Identify optimal scheduling windows for automated runs
#   - Can be run manually or via scheduled tasks (cron, GitHub Actions)
#
# Usage:
#   # Run once and log result
#   Rscript code/00-detect-iem-availability.R
#
#   # Or from within R
#   source("code/00-config.R")
#   source("code/00-detect-iem-availability.R")
#
# Output:
#   - Appends to: data/outputs/iem-availability-log.csv
#   - Shows: check_time, iem_latest_date, data_lag_hours, new_data_available
#
# Analysis:
#   - After 7-14 days of collection, run code/analyze-iem-schedule.R
#   - Shows when data typically becomes available each day
#   - Recommends optimal run times
#
# ═══════════════════════════════════════════════════════════════════════════

cat("\n")
cat(strrep("─", 70), "\n")
cat("IEM DATA AVAILABILITY CHECK\n")
cat(strrep("─", 70), "\n\n")

check_time_utc <- Sys.time()
check_hour_utc <- as.numeric(format(check_time_utc, "%H"))

if (VERBOSE) {
  cat(sprintf("Check time: %s UTC\n", format(check_time_utc, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("Hour of day: %02d:00 UTC\n\n", check_hour_utc))
}

## ── Query IEM for latest available date ───────────────────────────────────

query_iem_for_timing <- function() {
  #' Query IEM and return both latest date and time of query
  #' Returns: list with $latest_date, $check_time, $lag_hours, $is_new

  check_time <- Sys.time()

  tryCatch({
    # Try apsimx query
    if (requireNamespace("apsimx", quietly = TRUE)) {
      iem_data <- tryCatch({
        # Query last 5 days to see what's available
        apsimx::get_iem(
          lonlat = c(-92.5, 34.5),
          dates = c(Sys.Date() - 5, Sys.Date())
        )
      }, error = function(e) NULL)

      if (!is.null(iem_data) && nrow(iem_data) > 0) {
        latest_date <- max(iem_data$date, na.rm = TRUE)
        lag_hours <- as.numeric(difftime(check_time,
                                         as.POSIXct(paste(latest_date, "23:59:00")),
                                         units = "hours"))
        list(
          latest_date = latest_date,
          check_time = check_time,
          lag_hours = max(0, lag_hours),  # Don't go negative
          method = "apsimx_get_iem",
          success = TRUE
        )
      } else {
        # Fallback estimate
        list(
          latest_date = Sys.Date() - 1,
          check_time = check_time,
          lag_hours = 24 + as.numeric(format(check_time, "%H")),
          method = "fallback_estimate",
          success = FALSE
        )
      }
    } else {
      list(
        latest_date = Sys.Date() - 1,
        check_time = check_time,
        lag_hours = 24 + as.numeric(format(check_time, "%H")),
        method = "no_apsimx",
        success = FALSE
      )
    }
  }, error = function(e) {
    list(
      latest_date = Sys.Date() - 1,
      check_time = Sys.time(),
      lag_hours = NA,
      method = "error",
      success = FALSE,
      error_msg = e$message
    )
  })
}

## ── Check if new data has become available ────────────────────────────────

check_for_new_data <- function(latest_date) {
  #' Compare with previous check to see if new data became available
  #' Returns: TRUE if new data, FALSE if same as last check

  log_file <- file.path(PATH_OUTPUTS, "iem-availability-log.csv")

  if (!file.exists(log_file)) {
    return(TRUE)  # First check, always "new"
  }

  # Read last entry
  tryCatch({
    existing_log <- read.csv(log_file, stringsAsFactors = FALSE)
    if (nrow(existing_log) > 0) {
      last_date <- tail(existing_log$iem_latest_date, 1)
      return(as.Date(latest_date) > as.Date(last_date))
    } else {
      return(TRUE)
    }
  }, error = function(e) TRUE)
}

## ── Main: Query and Log ───────────────────────────────────────────────────

# Query IEM
result <- query_iem_for_timing()

if (VERBOSE) {
  cat(sprintf("Query result:\n"))
  cat(sprintf("  Method: %s\n", result$method))
  cat(sprintf("  Latest IEM data: %s\n", result$latest_date))
  cat(sprintf("  Lag: %.1f hours\n", result$lag_hours))
  cat(sprintf("  Success: %s\n\n", if(result$success) "YES" else "NO (fallback)"))
}

# Check if new data
is_new <- check_for_new_data(result$latest_date)

# Create log entry
log_entry <- data.frame(
  check_date = as.Date(check_time_utc),
  check_time_utc = format(check_time_utc, "%H:%M:%S"),
  check_hour = check_hour_utc,
  iem_latest_date = format(result$latest_date, "%Y-%m-%d"),
  iem_lag_hours = round(result$lag_hours, 1),
  new_data_available = if(is_new) "YES" else "NO",
  query_method = result$method,
  query_success = if(result$success) "OK" else "FALLBACK"
)

# Append to log
log_file <- file.path(PATH_OUTPUTS, "iem-availability-log.csv")

if (file.exists(log_file)) {
  existing_log <- read.csv(log_file, stringsAsFactors = FALSE)

  # Handle schema changes
  for (col in names(log_entry)) {
    if (!col %in% names(existing_log)) {
      existing_log[[col]] <- NA
    }
  }

  log_data <- rbind(existing_log, log_entry)
} else {
  log_data <- log_entry
}

write.csv(log_data, log_file, row.names = FALSE)

if (VERBOSE) {
  cat(sprintf("✓ Logged to: %s\n", log_file))
  cat(sprintf("  Check time: %s UTC\n", log_entry$check_time_utc))
  cat(sprintf("  Latest data: %s\n", log_entry$iem_latest_date))
  cat(sprintf("  Lag: %.1f hours\n", log_entry$iem_lag_hours))
  cat(sprintf("  New data: %s\n", log_entry$new_data_available))

  if (is_new) {
    cat("\n⭐ NEW DATA DETECTED!\n")
    cat(sprintf("   Data for %s became available at %s UTC\n",
               result$latest_date, log_entry$check_time_utc))
    cat("   This is an optimal time to run simulations.\n")
  }

  cat("\n")
}

cat(strrep("─", 70), "\n")
cat(sprintf("Total checks logged: %d\n", nrow(log_data)))
cat("Run this script at different times of day to build a pattern.\n")
cat("After 7-14 days, analyze with: source('code/analyze-iem-schedule.R')\n")
cat(strrep("─", 70), "\n\n")
