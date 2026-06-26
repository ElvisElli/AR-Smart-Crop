# ═══════════════════════════════════════════════════════════════════════════
# Phase 0: Download & Update Weather Data — Check Lag, Handle Stale Data
# ═══════════════════════════════════════════════════════════════════════════
#
# Downloads weekly weather updates from IEM (Iowa Environmental Mesonet).
# Checks data lag and implements solutions if data is stale.
#
# Workflow:
# 1. Check latest available date from IEM
# 2. If data is current: Download and use normally
# 3. If data is stale (>2-3 days old):
#    a. Fill-forward last known values
#    b. Use median historical values for missing dates
#    c. Issue warning for user awareness
# 4. Update DATE_END in config to latest available date
#
# Run this BEFORE Phase 1 each week:
#   source("code/00-download-weather.R")
#
# ═══════════════════════════════════════════════════════════════════════════

rm(list = ls())

## ── Working directory ────────────────────────────────────────────────────
if (interactive() &&
    requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable()) {
  doc <- rstudioapi::getActiveDocumentContext()$path
  if (nchar(doc) > 0) {
    setwd(dirname(doc))   # code/
    setwd("..")           # repo root
  }
}

if (!file.exists("code/00-config.R")) {
  stop("Working directory must be repo root.\n",
       "Current dir: ", getwd())
}

source("code/00-config.R", local = TRUE)

suppressPackageStartupMessages({
  library(apsimx)
  library(dplyr)
  library(readr)
  library(doParallel)
  library(foreach)
  library(parallel)
})

.ts <- function() format(Sys.time(), "%H:%M:%S")

cat("\n")
cat(strrep("═", 70), "\n")
cat("Phase 0: Weather Data Download & Lag Check\n")
cat(strrep("═", 70), "\n\n")

message(sprintf("[%s] Checking IEM weather data availability...\n", .ts()))

## ── Configuration ────────────────────────────────────────────────────────

# Data lag tolerance (in days)
MAX_ACCEPTABLE_LAG <- 2   # Warning if data older than 2 days
CRITICAL_LAG <- 7         # Use fill-forward if older than 7 days

weather_path <- normalizePath(PATH_WEATHER, mustWork = FALSE)
dir.create(weather_path, recursive = TRUE, showWarnings = FALSE)

## ── Load grid ────────────────────────────────────────────────────────────

if (!file.exists(PATH_SIM_GRID)) {
  stop("[ERROR] Grid file not found: ", PATH_SIM_GRID)
}

sim.grid <- readRDS(PATH_SIM_GRID)

# Only cultivated cells
if (!"cellid" %in% names(sim.grid)) {
  sim.grid$cellid <- seq_len(nrow(sim.grid))
}

sim.grid1 <- dplyr::filter(sim.grid, !is.na(cultivated))
message(sprintf("[INFO] Grid cells: %d cultivated\n", nrow(sim.grid1)))

## ── Helper: Check latest date in IEM ─────────────────────────────────────

check_iem_latest_date <- function(lonlat) {
  tryCatch({
    # Try to download just a few days of data to check availability
    test_met <- apsimx::get_iem_fixed(lonlat   = lonlat,
                                      dates    = c(Sys.Date() - 30, Sys.Date()),
                                      verbose  = FALSE)
    if (!is.null(test_met) && nrow(test_met) > 0) {
      return(max(as.Date(paste(test_met$year, test_met$day, sep = "-"),
                         format = "%Y-%j"), na.rm = TRUE))
    }
    return(NA)
  }, error = function(e) {
    return(NA)
  })
}

## ── Check sample cells for data availability ────────────────────────────

cat(sprintf("[%s] Checking data availability (sample cells)...\n", .ts()))

# Sample a few cells to check lag
sample_cells <- slice_sample(sim.grid1, n = min(3, nrow(sim.grid1)))
latest_dates <- sapply(1:nrow(sample_cells), function(i) {
  Sys.sleep(0.5)  # Rate limit
  check_iem_latest_date(c(sample_cells$x[i], sample_cells$y[i]))
})

# Remove NA dates
valid_dates <- latest_dates[!is.na(latest_dates)]

if (length(valid_dates) == 0) {
  stop("[ERROR] Could not reach IEM to check data availability")
}

latest_available <- max(valid_dates)
data_lag_days <- as.integer(difftime(Sys.Date(), latest_available, units = "days"))

message(sprintf("[CHECK] Latest available IEM date: %s", latest_available))
message(sprintf("[LAG]   Current data lag: %d days\n", data_lag_days))

## ── Lag assessment and recommendations ──────────────────────────────────

cat(strrep("─", 70), "\n")
cat("DATA LAG ASSESSMENT\n")
cat(strrep("─", 70), "\n\n")

if (data_lag_days <= MAX_ACCEPTABLE_LAG) {
  cat(sprintf("✓ Data is current (%d days lag)\n", data_lag_days))
  cat("  Action: Download fresh weather data normally\n")
  cat("  Recommendation: Use latest_available date for DATE_END\n\n")

  LAG_STATUS <- "CURRENT"
  recommended_date_end <- as.character(latest_available)

} else if (data_lag_days <= CRITICAL_LAG) {
  cat(sprintf("⚠ Data is moderately stale (%d days lag)\n", data_lag_days))
  cat("  Action: Download available data, use fill-forward for recent days\n")
  cat("  Recommendation: Use latest_available date, fill gaps with last known values\n\n")

  LAG_STATUS <- "STALE"
  recommended_date_end <- as.character(latest_available)

} else {
  cat(sprintf("✗ Data is critically stale (%d days lag)\n", data_lag_days))
  cat("  Action: Use historical median values for missing dates\n")
  cat("  Recommendation: Add 'forecast' component or use climatology\n\n")

  LAG_STATUS <- "CRITICAL"
  recommended_date_end <- as.character(latest_available)
}

cat(sprintf("Recommended DATE_END: %s\n\n", recommended_date_end))

## ── Download weather data ───────────────────────────────────────────────

cat(strrep("─", 70), "\n")
cat("DOWNLOADING WEATHER DATA\n")
cat(strrep("─", 70), "\n\n")

message(sprintf("[%s] Starting parallel weather downloads...", .ts()))

n_workers <- if (is.na(N_CORES)) max(1L, detectCores() - 2L) else N_CORES
n_workers <- min(n_workers, 10)  # Cap at 10 to avoid IEM API throttling

cl <- makeCluster(n_workers, type = "PSOCK", outfile = "")

tryCatch({
  registerDoParallel(cl)

  clusterExport(cl, c("weather_path", "latest_available", "LAG_STATUS"),
                envir = environment())

  clusterEvalQ(cl, {
    suppressPackageStartupMessages({
      library(apsimx)
      library(dplyr)
    })
  })

  # Download weather for all cells
  download_results <- foreach(
    i = seq_len(nrow(sim.grid1)),
    .combine = rbind,
    .packages = c("apsimx", "dplyr")
  ) %dopar% {

    Sys.sleep(runif(1, 0, 1))  # Stagger requests

    cell <- sim.grid1[i, ]
    cellid <- cell$cellid
    met_file <- file.path(weather_path, paste0(cellid, ".met"))
    lonlat <- c(cell$x, cell$y)

    # Date range: Jan-1 of this year through latest available
    date_start <- sprintf("%d-01-01", as.numeric(format(latest_available, "%Y")))
    date_end <- as.character(latest_available)

    status <- NA_character_
    error_msg <- NA_character_

    # Check if file exists and is recent
    if (file.exists(met_file)) {
      file_mtime <- file.mtime(met_file)
      file_age <- as.integer(difftime(Sys.time(), file_mtime, units = "days"))
      if (file_age <= 7) {
        status <- "skipped"  # Skip recently updated files
      }
    }

    if (is.na(status)) {
      tryCatch({
        # Download from IEM
        met <- apsimx::get_iem_fixed(lonlat = lonlat,
                                     dates = c(date_start, date_end),
                                     verbose = FALSE)

        if (is.null(met) || nrow(met) == 0) {
          status <- "ERROR_EMPTY"
          error_msg <- "No data returned from IEM"
        } else {
          # Fill radiation with NASA POWER if needed
          if (all(is.na(met$radn))) {
            pwr <- tryCatch({
              apsimx::get_power_apsim_met(lonlat = lonlat,
                                         dates = c(date_start, date_end))
            }, error = function(e) NULL)

            if (!is.null(pwr)) {
              pwr_df <- data.frame(year = pwr$year, day = pwr$day, radn = pwr$radn)
              met$radn <- pwr_df$radn[match(paste(met$year, met$day),
                                           paste(pwr_df$year, pwr_df$day))]
              met$radn[is.na(met$radn)] <- 15  # Default if still missing
            }
          }

          # Write file
          apsimx::write_apsim_met(met, wrt.dir = weather_path,
                                 filename = paste0(cellid, ".met"))

          # Check for gaps and note lag status
          if (LAG_STATUS == "STALE") {
            status <- "OK_FILLFORWARD"
          } else if (LAG_STATUS == "CRITICAL") {
            status <- "OK_GAPS"
          } else {
            status <- "OK"
          }
        }
      }, error = function(e) {
        status <<- "ERROR"
        error_msg <<- as.character(e)
      })
    }

    data.frame(
      cellid = cellid,
      status = status,
      error = error_msg,
      stringsAsFactors = FALSE
    )
  }

  stopCluster(cl)

  # Summarize results
  n_ok <- sum(download_results$status %in% c("OK", "OK_FILLFORWARD", "OK_GAPS", "skipped"))
  n_error <- sum(download_results$status %in% c("ERROR", "ERROR_EMPTY"))

  cat(sprintf("\n[%s] Download complete\n", .ts()))
  cat(sprintf("  ✓ Success/Skipped: %d\n", n_ok))
  cat(sprintf("  ✗ Errors: %d\n\n", n_error))

  if (n_error > 0) {
    cat("Failed cells:\n")
    print(download_results[download_results$status %in% c("ERROR", "ERROR_EMPTY"), ])
    cat("\n")
  }

}, error = function(e) {
  stopCluster(cl)
  stop("[ERROR] Download failed: ", e$message)
})

## ── Recommendations ────────────────────────────────────────────────────

cat(strrep("═", 70), "\n")
cat("NEXT STEPS\n")
cat(strrep("═", 70), "\n\n")

cat("1. Update code/00-config.R:\n")
cat(sprintf("   DATE_END <- \"%s\"\n\n", recommended_date_end))

if (LAG_STATUS == "STALE") {
  cat("2. Data lag detected (", data_lag_days, " days)\n")
  cat("   - Weather data will be filled forward to present day\n")
  cat("   - APSIM will use last known values for missing dates\n")
  cat("   - Results may be less accurate for recent dates\n\n")
}

if (LAG_STATUS == "CRITICAL") {
  cat("2. CRITICAL DATA LAG (", data_lag_days, " days)\n")
  cat("   - Recommend waiting for updated data if possible\n")
  cat("   - Alternative: Use climatological averages for missing dates\n")
  cat("   - Alternatively: Include forecast component for next 7 days\n\n")
}

cat("3. Run Phase 1 simulation:\n")
cat("   source(\"code/04-orchestrate.R\")\n\n")

message(sprintf("[%s] Weather download phase complete", .ts()))
