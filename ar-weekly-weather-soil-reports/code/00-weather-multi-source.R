# ═══════════════════════════════════════════════════════════════════════════
# Weather Data: Multi-Source Strategy (IEM + NASA POWER + CHIRPS + Climatology)
# ═══════════════════════════════════════════════════════════════════════════
#
# Strategy for handling data lag using multiple complementary sources:
#
# TIER 1 (Primary): IEM (Iowa Environmental Mesonet)
#   - Temperature, Rain, Wind
#   - Lag: 1-2 days typical
#   - Best for: Temperature, wind extremes
#
# TIER 2 (Radiation): NASA POWER
#   - Solar radiation
#   - Lag: 1-7 days
#   - Fallback: Compute from clear-sky model
#
# TIER 3 (Rain Enhancement): CHIRPS (via Google Earth Engine)
#   - High-resolution rainfall (0.05 degrees ~ 5km)
#   - Lag: 1-3 days
#   - Better spatial coverage than IEM stations
#   - Requires: Google Earth Engine account + Python/ee package
#
# TIER 4 (Fallback): Climatological Averages
#   - Use when all real-time sources are stale (>7 days)
#   - Compute from 40-year baseline
#   - Acceptable for near-climatological analysis
#
# ═══════════════════════════════════════════════════════════════════════════

## ── Data Lag Thresholds ────────────────────────────────────────────────────

DATA_LAG_THRESHOLDS <- list(
  CURRENT = 1,        # 1 day: Use as-is
  ACCEPTABLE = 3,     # 3 days: Use, minor gap-fill
  STALE = 7,          # 7 days: Use fill-forward + climatology
  CRITICAL = 14       # 14 days: Use climatology primarily
)

## ── Tier 1: IEM Data (Temperature, Rain, Wind) ──────────────────────────

get_iem_weather <- function(lonlat, date_start, date_end) {
  #' Download weather from IEM
  #' Returns: data.frame with year, day, tmax, tmin, rain, wind
  #' Or NULL if download fails

  tryCatch({
    message(sprintf("[IEM] Attempting download: %s to %s", date_start, date_end))

    # Note: Actual implementation depends on available apsimx functions
    # Options:
    # 1. apsimx::get_iem_fixed() if available
    # 2. Direct REST API call to IEM
    # 3. Fall back to backup service

    # For now, return NULL with instructions
    message("[IEM] Requires: apsimx::get_iem_fixed() or IEM REST API")
    return(NULL)
  }, error = function(e) {
    message(sprintf("[IEM] Download failed: %s", e$message))
    return(NULL)
  })
}

## ── Tier 2: NASA POWER (Radiation) ─────────────────────────────────────

get_power_radiation <- function(lonlat, date_start, date_end) {
  #' Download radiation from NASA POWER
  #' Returns: data.frame with year, day, radn
  #' Or NULL if download fails

  tryCatch({
    message(sprintf("[POWER] Attempting radiation download: %s to %s",
                   date_start, date_end))

    # Requires nasapower package
    # pwr <- apsimx::get_power_apsim_met(lonlat = lonlat,
    #                                    dates = c(date_start, date_end))

    message("[POWER] Requires: nasapower package")
    return(NULL)
  }, error = function(e) {
    message(sprintf("[POWER] Download failed: %s", e$message))
    return(NULL)
  })
}

## ── Tier 3: CHIRPS (High-Resolution Rainfall) ───────────────────────────

get_chirps_rainfall <- function(lonlat, date_start, date_end) {
  #' Download rainfall from CHIRPS (via Google Earth Engine)
  #' Returns: data.frame with date, rainfall_mm
  #' Or NULL if unavailable
  #'
  #' CHIRPS: Climate Hazards Group IR Precipitation with Stations
  #' - 0.05 degree resolution (~5 km)
  #' - Blends satellite + station data
  #' - Updated daily, ~1-3 day lag
  #'
  #' Access requires: Python + ee package (Google Earth Engine)
  #' Alternative: Download pre-processed CHIRPS data if available

  message("[CHIRPS] Rainfall enhancement (requires Google Earth Engine)")
  message("         To enable: Set up Python + ee authentication")
  message("         Python script: code/get_chirps_rainfall.py")

  # Placeholder for future CHIRPS integration
  return(NULL)
}

## ── Tier 4: Climatology (Ultimate Fallback) ────────────────────────────

compute_climatology <- function(met_historical, target_date) {
  #' Compute climatological values for a specific date
  #' Uses surrounding ±7 days from historical record
  #'
  #' Args:
  #'   met_historical: Data frame with year, day, tmax, tmin, rain, radn, wind
  #'   target_date: Date to estimate
  #'
  #' Returns: Single row data frame with climatological values

  target_doy <- as.numeric(format(target_date, "%j"))

  # Get historical values for this day-of-year (within ±7 days)
  doy_window <- (target_doy + (-7:7)) %% 366
  doy_window[doy_window == 0] <- 366  # Handle year boundary

  similar_days <- met_historical[met_historical$day %in% doy_window, ]

  if (nrow(similar_days) == 0) {
    message(sprintf("[CLIM] No historical data for DOY %d", target_doy))
    return(NULL)
  }

  # Compute means
  result <- data.frame(
    date = target_date,
    year = NA,
    day = target_doy,
    tmax = mean(similar_days$tmax, na.rm = TRUE),
    tmin = mean(similar_days$tmin, na.rm = TRUE),
    rain = mean(similar_days$rain, na.rm = TRUE),
    radn = mean(similar_days$radn, na.rm = TRUE),
    wind = mean(similar_days$wind, na.rm = TRUE),
    source = "climatology"
  )

  return(result)
}

## ── Smart Fill Strategy ──────────────────────────────────────────────────

smart_fill_gaps <- function(met_df, met_historical, target_end_date) {
  #' Fill gaps in weather data using tiered approach
  #'
  #' Strategy:
  #' 1. Identify missing dates
  #' 2. For each missing date, try sources in order:
  #'    a. Carry forward (last known value)
  #'    b. Use climatology
  #'    c. Use median (if climatology also missing)

  if (nrow(met_df) == 0) {
    message("[FILL] No data to fill")
    return(NULL)
  }

  dates_present <- as.Date(paste(met_df$year, met_df$day, sep = "-"),
                          format = "%Y-%j")
  date_range <- seq(min(dates_present), target_end_date, by = "day")

  missing_dates <- date_range[!date_range %in% dates_present]

  if (length(missing_dates) == 0) {
    message("[FILL] No gaps detected")
    return(met_df)
  }

  message(sprintf("[FILL] Found %d missing dates", length(missing_dates)))

  # Expand and fill
  filled_list <- list()
  filled_list[[1]] <- met_df

  for (missing_date in missing_dates) {
    # Try carry-forward (last value)
    last_idx <- which(dates_present < missing_date)
    if (length(last_idx) > 0) {
      last_row <- met_df[max(last_idx), ]
      new_row <- last_row
      new_row$date <- missing_date
      new_row$year <- as.numeric(format(missing_date, "%Y"))
      new_row$day <- as.numeric(format(missing_date, "%j"))
      new_row$source <- "forward_fill"
      filled_list[[length(filled_list) + 1]] <- new_row

      message(sprintf("[FILL] %s: forward-fill from %s",
                     missing_date, tail(dates_present, 1)))
    } else {
      # Try climatology
      clim_row <- compute_climatology(met_historical, missing_date)
      if (!is.null(clim_row)) {
        filled_list[[length(filled_list) + 1]] <- clim_row
        message(sprintf("[FILL] %s: climatology", missing_date))
      }
    }
  }

  filled_met <- do.call(rbind, filled_list)
  return(filled_met)
}

## ── Report Data Lag Status ──────────────────────────────────────────────

report_lag_status <- function(latest_date) {
  #' Report current data lag and recommended actions

  lag_days <- as.integer(difftime(Sys.Date(), latest_date, units = "days"))

  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("WEATHER DATA LAG STATUS\n")
  cat(strrep("=", 70), "\n\n")

  cat(sprintf("Latest available date: %s\n", latest_date))
  cat(sprintf("Data lag: %d days\n\n", lag_days))

  if (lag_days <= DATA_LAG_THRESHOLDS$CURRENT) {
    cat("STATUS: CURRENT DATA\n")
    cat("  Action: Use data as-is\n")
    cat("  Quality: High (real-time)\n")
    status <- "CURRENT"

  } else if (lag_days <= DATA_LAG_THRESHOLDS$ACCEPTABLE) {
    cat("STATUS: ACCEPTABLE DATA\n")
    cat("  Action: Use with minor gap-fill\n")
    cat("  Gap fill: Forward-fill last 1-2 days\n")
    cat("  Quality: High (near-current)\n")
    status <- "ACCEPTABLE"

  } else if (lag_days <= DATA_LAG_THRESHOLDS$STALE) {
    cat("STATUS: STALE DATA\n")
    cat(sprintf("  Action: Fill %d-day gap intelligently\n", lag_days))
    cat("  Gap fill strategy:\n")
    cat("    1. Forward-fill recent values (Tier 1)\n")
    cat("    2. Use climatology for longer gaps (Tier 4)\n")
    cat("  Quality: Medium (requires fill)\n")
    cat("  Recommendation: Monitor data quality\n")
    status <- "STALE"

  } else {
    cat("STATUS: CRITICALLY STALE DATA\n")
    cat(sprintf("  Action: Use climatology primarily\n"))
    cat("  Gap fill strategy:\n")
    cat("    1. Use climatological averages (Tier 4)\n")
    cat("    2. Consider using forecast data instead\n")
    cat("  Quality: Low (historical average)\n")
    cat("  Recommendation: Wait for fresher data or use forecast mode\n")
    status <- "CRITICAL"
  }

  cat("\n")
  cat(strrep("=", 70), "\n\n")

  return(status)
}

## ── Export utility functions ────────────────────────────────────────────

# Make functions available globally
invisible(lapply(c("get_iem_weather", "get_power_radiation", "get_chirps_rainfall",
                   "compute_climatology", "smart_fill_gaps", "report_lag_status"),
                function(f) assign(f, get(f), envir = .GlobalEnv)))
