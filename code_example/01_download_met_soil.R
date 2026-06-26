## 01_download_met_soil.R
## Parallel download of IEM weather (.met) + SSURGO soil (.rds) for all locations.
## Windows-compatible (PSOCK cluster). Fully resumable — skips existing files.
##
## API rate-limit note: keep N_WORKERS ≤ 15 to avoid IEM/SSURGO throttling.
## Re-run after any interruption; completed files are never re-downloaded.

suppressPackageStartupMessages({
  library(doParallel)
  library(foreach)
  library(apsimx)
  library(sf)
  library(dplyr)
  library(jsonlite)
  library(spData)
})

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
setwd("..")   # repo root
source("scripts/utils.R")

## ── Settings ──────────────────────────────────────────────────────────────────
N_WORKERS  <- 10                              # ≤ 15 recommended for API stability
DATE_RANGE <- c("1985-01-01", "2024-12-31")
NLAYERS    <- 20
SOIL_BOT   <- 400    # cm
MET_DIR    <- normalizePath("outputs/met",    mustWork = FALSE)
RDS_DIR    <- normalizePath("outputs/rds",    mustWork = FALSE)
LOG_FILE   <- "outputs/download_log.csv"

dir.create(MET_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(RDS_DIR, recursive = TRUE, showWarnings = FALSE)

## ── Load locations, skip already done ────────────────────────────────────────
locs <- read.csv("locations/arkansas_cropland_grid.csv")
cat("Total locations:", nrow(locs), "\n")

met_done <- file.exists(file.path(MET_DIR, paste0(locs$location, ".met")))
rds_done <- file.exists(file.path(RDS_DIR, paste0(locs$location, ".rds")))
todo     <- locs[!met_done | !rds_done, ]
cat("Already done:", sum(met_done & rds_done), "| Remaining:", nrow(todo), "\n\n")

if (nrow(todo) == 0) { cat("Nothing to do.\n"); quit(save = "no") }

## ── Parallel download ─────────────────────────────────────────────────────────
cl <- makeCluster(N_WORKERS, type = "PSOCK")
registerDoParallel(cl)

results <- foreach(
  i              = seq_len(nrow(todo)),
  .packages      = c("apsimx", "sf", "jsonlite", "spData"),
  .export        = c("get_iem_fixed", "try_msg",
                     "DATE_RANGE", "MET_DIR", "RDS_DIR", "NLAYERS", "SOIL_BOT"),
  .combine       = rbind,
  .errorhandling = "pass"
) %dopar% {

  ## Stagger workers slightly to reduce simultaneous API hits
  Sys.sleep(runif(1, 0, 2))

  loc      <- todo$location[i]
  lonlat   <- c(todo$lon[i], todo$lat[i])
  met_file <- file.path(MET_DIR, paste0(loc, ".met"))
  rds_file <- file.path(RDS_DIR, paste0(loc, ".rds"))
  met_status <- if (file.exists(met_file)) "skipped" else NA_character_
  rds_status <- if (file.exists(rds_file)) "skipped" else NA_character_

  ## ---- Weather ---------------------------------------------------------------
  if (is.na(met_status)) {
    iem <- try(get_iem_fixed(lonlat   = lonlat,
                             dates    = DATE_RANGE,
                             wrt.dir  = MET_DIR,
                             filename = paste0(loc, ".met")), silent = TRUE)
    if (inherits(iem, "try-error")) {
      met_status <- paste0("ERROR: ", try_msg(iem))
    } else {
      pwr <- try(apsimx::get_power_apsim_met(lonlat = lonlat, dates = DATE_RANGE),
                 silent = TRUE)
      if (inherits(pwr, "try-error")) {
        met_status <- paste0("ERROR (radn): ", try_msg(pwr))
      } else {
        pwr_df   <- data.frame(year = pwr$year, day = pwr$day, radn = pwr$radn)
        iem$radn <- pwr_df$radn[match(paste(iem$year, iem$day),
                                      paste(pwr_df$year, pwr_df$day))]
        iem$radn[is.na(iem$radn)] <- 15
        apsimx::write_apsim_met(iem, wrt.dir = MET_DIR, filename = paste0(loc, ".met"))
        met_status <- "OK"
      }
    }
  }

  ## ---- Soil ------------------------------------------------------------------
  if (is.na(rds_status)) {
    spp <- try(apsimx::get_ssurgo_soil_profile(lonlat      = lonlat,
                                               nlayers     = NLAYERS,
                                               soil.bottom = SOIL_BOT), silent = TRUE)
    if (inherits(spp, "try-error")) {
      rds_status <- paste0("ERROR: ", try_msg(spp))
    } else {
      saveRDS(spp, rds_file)
      rds_status <- "OK"
    }
  }

  data.frame(location = loc, met = met_status, rds = rds_status,
             stringsAsFactors = FALSE)
}

stopCluster(cl)

## ── Save log ──────────────────────────────────────────────────────────────────
write.csv(results, LOG_FILE, row.names = FALSE)

n_met_ok <- sum(results$met %in% c("OK", "skipped"))
n_rds_ok <- sum(results$rds %in% c("OK", "skipped"))
cat(sprintf("Weather OK: %d / %d\n", n_met_ok, nrow(results)))
cat(sprintf("Soil    OK: %d / %d\n", n_rds_ok, nrow(results)))
cat("Log saved to", LOG_FILE, "\n")
cat("\nIf there are errors, re-run this script — it will retry only failed locations.\n")
