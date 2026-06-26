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

## ── Helper: Query IEM for latest available date ──────────────────────────

query_iem_latest_date <- function(lonlat) {
  #' Query IEM to find latest available data date
  #' Uses apsimx if available, else returns TODAY (safe estimate)
  #' Returns: list with $latest_date, $lag_days, $method, $error

  tryCatch({
    # Try using apsimx to query IEM
    if (requireNamespace("apsimx", quietly = TRUE)) {
      message(sprintf("[IEM] Querying latest available data via apsimx..."))

      # Try different apsimx functions to get latest data
      result <- tryCatch({
        # First try: use check_iem_status if available
        iem_data <- tryCatch({
          apsimx::check_iem_status(lonlat = lonlat)
        }, error = function(e) NULL)

        if (!is.null(iem_data)) {
          # Extract latest date from status
          list(
            latest_date = as.Date(iem_data$date),
            method = "apsimx_status",
            error = NULL
          )
        } else {
          # Fallback: query last 30 days and find latest
          iem_data <- apsimx::get_iem(
            lonlat = lonlat,
            dates = c(Sys.Date() - 30, Sys.Date())
          )

          if (!is.null(iem_data) && nrow(iem_data) > 0) {
            latest_date_in_data <- max(iem_data$date, na.rm = TRUE)
            list(
              latest_date = latest_date_in_data,
              method = "apsimx_get_iem",
              error = NULL
            )
          } else {
            list(
              latest_date = Sys.Date() - 1,
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

## ── Helper: Detect data lag ──────────────────────────────────────────────

detect_data_lag <- function(latest_available_date) {
  #' Calculate IEM data lag from actual latest available date
  #' Returns: list with $lag_days, $status, $message

  today <- Sys.Date()
  latest_d <- as.Date(latest_available_date)
  days_lag <- as.integer(difftime(today, latest_d, units = "days"))

  if (days_lag <= 1) {
    status <- "CURRENT"
    message_text <- "Data is current (≤ 1 day old)"
  } else if (days_lag <= 3) {
    status <- "ACCEPTABLE"
    message_text <- "Data lag is acceptable (1-3 days)"
  } else if (days_lag <= 7) {
    status <- "STALE"
    message_text <- "Data lag is significant (3-7 days)"
  } else {
    status <- "CRITICAL"
    message_text <- "Data lag is critical (> 7 days)"
  }

  list(
    latest_date = latest_d,
    lag_days = days_lag,
    status = status,
    message = message_text,
    recommendation = if(days_lag > 2) {
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

# Query IEM for latest available date
if (VERBOSE) {
  message(sprintf("\n[IEM QUERY] Detecting actual data lag from IEM..."))
}

iem_query <- query_iem_latest_date(c(-92.5, 34.5))

if (VERBOSE) {
  message(sprintf("  Method: %s", iem_query$method))
  message(sprintf("  Latest available: %s", iem_query$latest_date))
  if (!is.null(iem_query$error)) {
    message(sprintf("  Note: %s", iem_query$error))
  }
}

# Detect data lag based on actual latest available date
lag_info <- detect_data_lag(iem_query$latest_date)

if (VERBOSE) {
  message(sprintf("\n[DATA LAG ANALYSIS]"))
  message(sprintf("  Latest data from IEM: %s", lag_info$latest_date))
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
  iem_latest_date = format(lag_info$latest_date, "%Y-%m-%d"),
  weather_status = lag_info$status,
  lag_days = lag_info$lag_days,
  data_source = "IEM",
  query_method = iem_query$method,
  weather_files_found = weather_check$count,
  weather_file_status = weather_check$status,
  phase_0_completed = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
)

# Append to log (with column matching for new fields)
if (file.exists(log_file)) {
  existing_log <- read.csv(log_file, stringsAsFactors = FALSE)

  # Add missing columns to existing_log if this is first time with new schema
  for (col in names(log_entry)) {
    if (!col %in% names(existing_log)) {
      existing_log[[col]] <- NA
    }
  }

  # Ensure column order matches
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
