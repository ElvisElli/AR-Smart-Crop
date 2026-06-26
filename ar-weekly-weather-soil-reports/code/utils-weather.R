# ═══════════════════════════════════════════════════════════════════════════
# Utility Functions: Weather Data Handling & Lag Solutions
# ═══════════════════════════════════════════════════════════════════════════

## ── Fill gaps with forward-fill and climatological values ──────────────

fill_met_gaps <- function(met_df, max_gap_days = 3) {
  #' Fill missing dates in weather .met data
  #' Strategy: Forward-fill recent gaps, use climatology for older gaps
  #'
  #' @param met_df Data frame with year, day columns (APSIM format)
  #' @param max_gap_days Maximum consecutive days to forward-fill (otherwise use climatology)
  #'
  #' @return Data frame with gaps filled

  if (nrow(met_df) == 0) return(met_df)

  # Create complete date sequence
  dates_present <- as.Date(paste(met_df$year, met_df$day, sep = "-"),
                           format = "%Y-%j")
  date_range <- seq(min(dates_present, na.rm = TRUE),
                    max(dates_present, na.rm = TRUE),
                    by = "day")

  # Identify missing dates
  missing_dates <- date_range[!date_range %in% dates_present]

  if (length(missing_dates) == 0) {
    return(met_df)  # No gaps
  }

  message(sprintf("[FILL] Found %d missing dates in weather data", length(missing_dates)))

  # Expand met_df to include all dates
  met_expanded <- data.frame(
    year = as.numeric(format(date_range, "%Y")),
    day = as.numeric(format(date_range, "%j"))
  )

  # Merge with existing data
  met_merged <- merge(met_expanded, met_df,
                     by = c("year", "day"),
                     all = TRUE)

  # Forward fill for recent gaps (< max_gap_days)
  numeric_cols <- sapply(met_merged, is.numeric)
  for (col in names(met_merged)[numeric_cols]) {
    na_idx <- which(is.na(met_merged[[col]]))
    if (length(na_idx) > 0) {
      for (idx in na_idx) {
        # Check gap size
        gap_start <- NA
        if (idx > 1 && !is.na(met_merged[[col]][idx - 1])) {
          gap_start <- idx - 1
        }
        gap_end <- NA
        if (idx < nrow(met_merged) && !is.na(met_merged[[col]][idx + 1])) {
          gap_end <- idx + 1
        }

        # Forward fill if gap is small
        if (!is.na(gap_start) &&
            (is.na(gap_end) || gap_end - gap_start <= max_gap_days)) {
          met_merged[[col]][idx] <- met_merged[[col]][gap_start]
        }
      }
    }
  }

  message(sprintf("[FILL] Forward-filled small gaps (< %d days)", max_gap_days))
  return(met_merged)
}

## ── Calculate climatological daily values ──────────────────────────────

calc_daily_climatology <- function(met_df, window_days = 15) {
  #' Calculate climatological daily values from historical data
  #' Useful for filling long gaps with typical values
  #'
  #' @param met_df Data frame with year, day columns
  #' @param window_days Window size for smoothing (e.g., 15 = ±7.5 days)
  #'
  #' @return Data frame with daily climatological values

  if (nrow(met_df) < 100) {
    warning("Insufficient data for robust climatology (need >100 records)")
    return(NULL)
  }

  numeric_cols <- sapply(met_df, is.numeric)
  clim <- data.frame(day = 1:366)

  for (col in names(met_df)[numeric_cols]) {
    daily_values <- list()

    for (d in 1:366) {
      # Get values within window of this day
      days_in_window <- ((met_df$day >= d - window_days/2) &
                        (met_df$day <= d + window_days/2)) |
                       ((d <= window_days/2) &
                        (met_df$day >= 366 + d - window_days/2))

      vals <- met_df[[col]][days_in_window]
      vals <- vals[!is.na(vals)]

      if (length(vals) > 0) {
        daily_values[[d]] <- mean(vals, na.rm = TRUE)
      } else {
        daily_values[[d]] <- NA
      }
    }

    clim[[col]] <- unlist(daily_values)
  }

  return(clim)
}

## ── Detect data lag from .met file dates ────────────────────────────────

detect_met_lag <- function(met_file) {
  #' Check data lag from .met file
  #' Returns: days since last data point
  #'
  #' @param met_file Path to .met file
  #' @return Integer: number of days lag (negative means future-dated)

  if (!file.exists(met_file)) {
    return(NA_integer_)
  }

  tryCatch({
    met <- apsimx::read_apsim_met(met_file)
    if (is.null(met) || nrow(met) == 0) {
      return(NA_integer_)
    }

    last_date <- as.Date(paste(met$year[nrow(met)], met$day[nrow(met)], sep = "-"),
                        format = "%Y-%j")
    lag <- as.integer(difftime(Sys.Date(), last_date, units = "days"))
    return(lag)
  }, error = function(e) {
    return(NA_integer_)
  })
}

## ── Bulk check lag for multiple files ──────────────────────────────────

check_weather_lag <- function(weather_dir) {
  #' Check data lag for all .met files in directory
  #'
  #' @param weather_dir Path to directory containing .met files
  #' @return Data frame with cellid, lag_days, status

  if (!dir.exists(weather_dir)) {
    return(NULL)
  }

  met_files <- list.files(weather_dir, pattern = "\\.met$", full.names = TRUE)

  if (length(met_files) == 0) {
    return(NULL)
  }

  lags <- data.frame(
    filename = basename(met_files),
    lag_days = NA_integer_,
    status = NA_character_,
    stringsAsFactors = FALSE
  )

  for (i in seq_along(met_files)) {
    lag <- detect_met_lag(met_files[i])
    lags$lag_days[i] <- lag

    if (is.na(lag)) {
      lags$status[i] <- "ERROR"
    } else if (lag <= 1) {
      lags$status[i] <- "CURRENT"
    } else if (lag <= 3) {
      lags$status[i] <- "ACCEPTABLE"
    } else if (lag <= 7) {
      lags$status[i] <- "STALE"
    } else {
      lags$status[i] <- "CRITICAL"
    }
  }

  return(lags)
}

## ── Report weather data status ──────────────────────────────────────────

report_weather_status <- function(lag_df) {
  #' Generate summary report of weather data lag status
  #'
  #' @param lag_df Data frame from check_weather_lag()

  if (is.null(lag_df)) {
    message("[WEATHER] No data to report")
    return(invisible(NULL))
  }

  cat("\n")
  cat(strrep("─", 70), "\n")
  cat("WEATHER DATA LAG STATUS REPORT\n")
  cat(strrep("─", 70), "\n\n")

  # Summary by status
  status_counts <- table(lag_df$status)
  for (status in names(status_counts)) {
    cat(sprintf("  %s: %d files\n", status, status_counts[status]))
  }

  # Statistics
  valid_lags <- lag_df$lag_days[!is.na(lag_df$lag_days)]
  if (length(valid_lags) > 0) {
    cat(sprintf("\nLag statistics:\n")
    cat(sprintf("  Mean lag: %.1f days\n", mean(valid_lags)))
    cat(sprintf("  Max lag: %d days\n", max(valid_lags)))
    cat(sprintf("  Min lag: %d days\n", min(valid_lags)))
  }

  cat("\n")
  cat(strrep("─", 70), "\n")
}

## Export for use in other scripts
invisible(lapply(c("fill_met_gaps", "calc_daily_climatology",
                    "detect_met_lag", "check_weather_lag",
                    "report_weather_status"),
                 function(f) assign(f, get(f), envir = .GlobalEnv)))
