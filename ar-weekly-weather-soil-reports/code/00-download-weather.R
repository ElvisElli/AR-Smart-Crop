# ═══════════════════════════════════════════════════════════════════════════
# Phase 0: Weather Data Download & Lag Detection
# ═══════════════════════════════════════════════════════════════════════════
#
# Purpose:
#   - Check existing weather data availability
#   - Detect data lag and categorize status
#   - Log all decisions for transparency
#   - Report status to console
#
# Output:
#   - Logs weather status to: data/outputs/weather-log.csv
#   - Reports lag status to console
#
# ═══════════════════════════════════════════════════════════════════════════

if (VERBOSE) {
  cat("\n")
  cat(strrep("─", 70), "\n")
  cat("PHASE 0: Weather Data Check & Lag Detection\n")
  cat(strrep("─", 70), "\n\n")
}

run_start_time <- Sys.time()

## ── Helper: Check weather file availability ──────────────────────────────

check_weather_exists <- function(weather_path) {
  #' Check if weather files exist
  #' Returns: list with $exists, $files, $count

  if (!dir.exists(weather_path)) {
    return(list(exists = FALSE, files = c(), count = 0, path = weather_path,
                latest_date = "unknown", status = "MISSING"))
  }

  met_files <- list.files(weather_path, pattern = "\\.met$", full.names = TRUE)

  list(
    exists = length(met_files) > 0,
    files = met_files,
    count = length(met_files),
    path = weather_path,
    latest_date = if(length(met_files) > 0) {
      tryCatch({
        met_content <- readLines(met_files[1], n = 50)
        date_line <- grep("^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}", met_content, value = TRUE)
        if (length(date_line) > 0) tail(date_line, 1) else "unknown"
      }, error = function(e) "unknown")
    } else {
      "unknown"
    },
    status = if(length(met_files) > 0) "OK" else "NONE"
  )
}

## ── Helper: Detect data lag ──────────────────────────────────────────────

detect_data_lag <- function(date_end) {
  #' Estimate IEM data lag based on current date
  #' Returns: list with $lag_days, $status, $message

  today <- Sys.Date()
  date_end_d <- as.Date(date_end)
  days_back <- as.integer(difftime(today, date_end_d, units = "days"))

  if (days_back <= 1) {
    status <- "CURRENT"
    message_text <- "Data is current (≤ 1 day old)"
  } else if (days_back <= 3) {
    status <- "ACCEPTABLE"
    message_text <- "Data lag is acceptable (1-3 days)"
  } else if (days_back <= 7) {
    status <- "STALE"
    message_text <- "Data lag is significant (3-7 days)"
  } else {
    status <- "CRITICAL"
    message_text <- "Data lag is critical (> 7 days)"
  }

  list(
    lag_days = days_back,
    status = status,
    message = message_text,
    recommendation = if(days_back > 2) {
      "Will use forward-fill + climatology for gaps"
    } else {
      "No gap-fill needed"
    }
  )
}

## ── Main: Check and Report Weather Status ───────────────────────────────

if (VERBOSE) {
  message(sprintf("[WEATHER] Checking weather data availability"))
  message(sprintf("  Date range: %s to %s", DATE_START, DATE_END))
}

# Check existing weather
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

# Detect data lag
lag_info <- detect_data_lag(DATE_END)

if (VERBOSE) {
  message(sprintf("\n[DATA LAG ANALYSIS]"))
  message(sprintf("  Simulation end date: %s", DATE_END))
  message(sprintf("  Days behind today: %d", lag_info$lag_days))
  message(sprintf("  Status: %s", lag_info$status))
  message(sprintf("  Message: %s", lag_info$message))
  message(sprintf("  Recommendation: %s", lag_info$recommendation))
}

# Store for later use
WEATHER_LAG_STATUS <<- lag_info$status
WEATHER_LAG_DAYS <<- lag_info$lag_days
WEATHER_LAG_SOURCE <<- "IEM"
WEATHER_LAG_TIMESTAMP <<- Sys.time()

# Create output directory
if (!dir.exists(PATH_OUTPUTS)) {
  dir.create(PATH_OUTPUTS, recursive = TRUE, showWarnings = FALSE)
}

## ── Log Weather Status ───────────────────────────────────────────────────

log_file <- file.path(PATH_OUTPUTS, "weather-log.csv")

log_entry <- data.frame(
  run_date = Sys.Date(),
  run_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  date_start = DATE_START,
  date_end = DATE_END,
  weather_status = lag_info$status,
  lag_days = lag_info$lag_days,
  data_source = "IEM",
  weather_files_found = weather_check$count,
  weather_file_status = weather_check$status,
  phase_0_completed = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
)

# Append to log
if (file.exists(log_file)) {
  existing_log <- read.csv(log_file, stringsAsFactors = FALSE)
  log_data <- rbind(existing_log, log_entry)
} else {
  log_data <- log_entry
}

write.csv(log_data, log_file, row.names = FALSE)

if (VERBOSE) {
  message(sprintf("\n[LOGGING] Status logged to: %s\n", log_file))

  # Print summary
  cat(strrep("─", 70), "\n")
  cat("WEATHER DATA STATUS SUMMARY\n")
  cat(strrep("─", 70), "\n\n")
  cat(sprintf("Status: %s\n", lag_info$status))
  cat(sprintf("Latest data: %s\n", weather_check$latest_date))
  cat(sprintf("Files available: %d\n", weather_check$count))
  cat(sprintf("Date range: %s to %s\n", DATE_START, DATE_END))
  cat(sprintf("Data lag: %d days\n\n", lag_info$lag_days))

  if (lag_info$lag_days > 7) {
    cat("⚠  WARNING: Data lag > 7 days\n")
  } else if (lag_info$lag_days > 3) {
    cat("⚠  Data lag detected - gaps will be filled\n")
  } else {
    cat("✓ Data is fresh\n")
  }

  cat(strrep("─", 70), "\n\n")
}

## ── Run Timing Analysis ──────────────────────────────────────────────────

source("code/00-timing-analysis.R", local = TRUE)
