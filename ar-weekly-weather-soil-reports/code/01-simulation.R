# ═══════════════════════════════════════════════════════════════════════════
# Phase 1: APSIM Grid Simulations
# ═══════════════════════════════════════════════════════════════════════════
#
# Runs APSIM baseline scenario across ~4,650 grid cells in parallel.
# Resumable via per-chunk checkpoints. Auto-detects Windows/Linux/cloud.
#
# Adapted from: ElvisElli/soybean-ar-climate-change code/01-simulation.R
# Simplified: baseline only, weekly (not 40-year), focus on soil water
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
       "Current dir: ", getwd(), "\n",
       "Run from RStudio with script open, or: Rscript code/01-simulation.R")
}

## ── Load configuration ───────────────────────────────────────────────────
source("code/00-config.R")

suppressPackageStartupMessages({
  library(apsimx)
  library(doParallel)
  library(foreach)
  library(dplyr)
  library(readr)
  library(parallel)
  library(data.table)
})

## ── Helper: time stamp ──────────────────────────────────────────────────
.ts <- function() format(Sys.time(), "%H:%M:%S")
cat(sprintf("[%s] Phase 1: APSIM Grid Simulation started\n\n", .ts()))

## ── Environment detection ───────────────────────────────────────────────
detect_env <- function() {
  host <- tolower(Sys.info()[["nodename"]])
  os   <- .Platform$OS.type

  if (os == "windows") {
    local_app  <- Sys.getenv("LOCALAPPDATA",
                              file.path(Sys.getenv("USERPROFILE"), "AppData", "Local"))
    apsim_search <- c(file.path(local_app, "Programs"),
                      "C:/Program Files", "C:/Program Files (x86)")
    apsim_dirs <- sort(grep("APSIM",
                             unlist(lapply(apsim_search, function(d) {
                               if (dir.exists(d)) list.dirs(d, recursive = FALSE) else character(0)
                             })),
                             value = TRUE, ignore.case = TRUE))
    if (length(apsim_dirs) == 0) {
      stop("[ERROR] APSIM not found in: ", paste(apsim_search, collapse = ", "))
    }
    apsim_exe <- utils::shortPathName(file.path(tail(apsim_dirs, 1), "bin", "Models.exe"))
    n_cores <- max(1L, parallel::detectCores(logical = FALSE) - 1L)

    message("[ENV] Windows machine: ", host)
    message("[ENV] APSIM exe: ", apsim_exe)
    message("[ENV] Cores: ", n_cores)

    list(apsim_exe  = apsim_exe,
         cores_use  = n_cores,
         is_windows = TRUE)
  } else {
    # Linux / cloud
    apsim_bin <- Sys.which("Models")
    if (nchar(apsim_bin) == 0) {
      candidate <- "/usr/local/lib/apsim/2025.3.7681.0/bin/Models"
      apsim_bin <- if (file.exists(candidate)) candidate else ""
    }
    if (nchar(apsim_bin) == 0) {
      stop("[ERROR] APSIM not found. Install APSIM or set APSIM_EXE in 00-config.R")
    }

    message("[ENV] Linux/cloud: ", host)
    message("[ENV] APSIM: ", apsim_bin)

    list(apsim_exe  = apsim_bin,
         cores_use  = max(1L, parallel::detectCores(logical = FALSE) - 1L),
         is_windows = FALSE)
  }
}

ENV <- detect_env()

if (!is.null(APSIM_EXE)) {
  ENV$apsim_exe <- APSIM_EXE
  message("[CONFIG] APSIM exe override: ", APSIM_EXE)
}

if (!file.exists(ENV$apsim_exe)) {
  stop("[ERROR] APSIM exe not found at: ", ENV$apsim_exe)
}

apsimx_options(exe.path = ENV$apsim_exe)

## ── Data paths ──────────────────────────────────────────────────────────
if (!is.null(LOCAL_DATA_CACHE) && dir.exists(LOCAL_DATA_CACHE)) {
  weather_path <- normalizePath(file.path(LOCAL_DATA_CACHE, "weather"), mustWork = FALSE)
  soil_path    <- normalizePath(file.path(LOCAL_DATA_CACHE, "soil"),    mustWork = FALSE)
  message("[PATHS] Using local cache: ", LOCAL_DATA_CACHE)
} else if (USE_SAMPLE_DATA) {
  # Use sample data for testing (cloud environment)
  weather_path <- normalizePath("data/raw/weather_sample", mustWork = FALSE)
  soil_path    <- normalizePath(PATH_SOIL, mustWork = FALSE)
  message("[PATHS] Using SAMPLE weather data (testing mode)")
  TEST_RUN <- TRUE  # Auto-enable test mode with samples
} else {
  # Use full production data
  weather_path <- normalizePath(PATH_WEATHER, mustWork = FALSE)
  soil_path    <- normalizePath(PATH_SOIL,    mustWork = FALSE)
  message("[PATHS] Using FULL production data")
}

checkpoint_dir <- normalizePath(PATH_CHECKPOINTS, mustWork = FALSE)
processed_dir  <- normalizePath(PATH_PROCESSED,  mustWork = FALSE)

dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir,  recursive = TRUE, showWarnings = FALSE)

message("[PATHS] Weather: ", weather_path)
message("[PATHS] Soil: ", soil_path)
message("[PATHS] Checkpoints: ", checkpoint_dir)

if (!dir.exists(weather_path)) stop("[ERROR] Weather path not found: ", weather_path)
if (!dir.exists(soil_path))    stop("[ERROR] Soil path not found: ", soil_path)

n_met <- length(list.files(weather_path, "\\.met$"))
n_rds <- length(list.files(soil_path,    "\\.rds$"))
message(sprintf("[CHECK] Weather files: %d | Soil files: %d\n", n_met, n_rds))

## ── Load grid ───────────────────────────────────────────────────────────
if (!file.exists(PATH_SIM_GRID)) {
  stop("[ERROR] Grid file not found: ", PATH_SIM_GRID)
}

sim.grid <- readRDS(PATH_SIM_GRID)

# Only create cellid if it doesn't exist (preserve existing cellids)
if (!"cellid" %in% names(sim.grid)) {
  sim.grid$cellid <- seq_len(nrow(sim.grid))
}

sim.grid1 <- dplyr::filter(sim.grid, !is.na(cultivated))

message(sprintf("[INFO] Grid cells: %d total | %d cultivated",
                nrow(sim.grid), nrow(sim.grid1)))

## ── Apply test limits ────────────────────────────────────────────────────
if (TEST_RUN) {
  set.seed(42)
  # Find cells with both weather and soil files
  met_ids  <- as.integer(sub("\\.met$", "", list.files(weather_path, "\\.met$")))
  soil_ids <- as.integer(sub("\\.rds$", "", list.files(soil_path,    "\\.rds$")))
  avail    <- intersect(met_ids, soil_ids)

  if (length(avail) == 0) {
    stop("[TEST] No cells with both weather and soil files found.")
  }

  sim.grid1 <- sim.grid1[sim.grid1$cellid %in% avail, ]
  sim.grid1 <- sim.grid1[sample(nrow(sim.grid1), min(TEST_N_CELLS, nrow(sim.grid1))), ]

  cat(sprintf("[TEST] %d cells available | using %d\n", length(avail), nrow(sim.grid1)))
  cat(sprintf("[TEST] Chunk size: %d (adjusted for test)\n\n", max(1L, ceiling(nrow(sim.grid1) / 2L))))
  CHUNK_SIZE <- max(1L, ceiling(nrow(sim.grid1) / 2L))
}

message(sprintf("[CONFIG] Cells to simulate: %d", nrow(sim.grid1)))
message(sprintf("[CONFIG] Chunks: %d (size %d each)",
                ceiling(nrow(sim.grid1) / CHUNK_SIZE), CHUNK_SIZE))

## ── APSIM working directory ─────────────────────────────────────────────
template_path <- normalizePath(file.path(PATH_TEMPLATES, APSIM_TEMPLATE),
                               mustWork = FALSE)
if (!file.exists(template_path)) {
  stop("[ERROR] APSIM template not found: ", template_path)
}

apsim_dir <- normalizePath("data/outputs/apsim-work", mustWork = FALSE)
dir.create(apsim_dir, recursive = TRUE, showWarnings = FALSE)
message("[PATHS] APSIM work: ", apsim_dir)

## ── Root parameters ─────────────────────────────────────────────────────
message(sprintf("[CONFIG] KL vector: %s ...", paste(head(KL_VEC, 3), collapse=", ")))
message(sprintf("[CONFIG] XF vector: %s ...", paste(head(XF_VEC, 3), collapse=", ")))

## ── Helper: prepare soil profile ────────────────────────────────────────
prepare_soil <- function(soil_rds_path, KL_VEC, XF_VEC) {
  soil.result <- tryCatch(readRDS(soil_rds_path), error = function(e) NULL)
  if (is.null(soil.result) ||
      !is.list(soil.result[[1]]) ||
      !inherits(soil.result[[1]][[1]], "soil_profile")) {
    return(NULL)
  }

  soils <- soil.result[[1]][[1]]
  KS_max <- max(soils$soil$KS, na.rm = TRUE)
  soils$soil$KS <- KS_max * exp(seq(0, log(1e-4), length.out = length(soils$soil$KS)))

  soils <- apsimx:::fix_apsimx_soil_profile(soils, verbose = FALSE)
  soils$initialwater <- initialwater_parms(
    Depth = soils$soil$Depth,
    Thickness = soils$soil$Thickness,
    InitialValues = soils$soil$DUL)
  soils$crops <- c("Soybean", "Wheat", "Maize")

  n_lay <- nrow(soils$soil)
  list(soils = soils,
       KL    = KL_VEC[seq_len(min(n_lay, length(KL_VEC)))],
       XF    = XF_VEC[seq_len(min(n_lay, length(XF_VEC)))])
}

## ── Helper: extract results ─────────────────────────────────────────────
extract_results <- function(sim, grid_row) {
  if (is.null(sim) || nrow(sim) == 0) return(NULL)

  keep_cols <- c("Date",
                 "Yield_kgha", "biomass_kgha",
                 "swhc_6in", "swhc_12in", "swhc_24in",
                 "Crop_ET", "WDrainage", "WRunoff")

  sim_cols <- sim[, intersect(names(sim), keep_cols), drop = FALSE]

  # Merge with grid row
  n <- nrow(sim)
  cbind(grid_row[rep(1L, n), , drop = FALSE],
        cultivar = rep(CULTIVAR, n),
        sowing = rep(SOW_DATE, n),
        sim_cols,
        row.names = NULL)
}

## ── Start cluster ───────────────────────────────────────────────────────
n_workers <- if (is.na(N_CORES)) ENV$cores_use else N_CORES
n_workers <- min(n_workers, nrow(sim.grid1))

cat(sprintf("\n[%s] Starting %d parallel workers\n", .ts(), n_workers))
cl <- makeCluster(n_workers, type = "PSOCK", outfile = "")

tryCatch({
  registerDoParallel(cl)

  clusterExport(cl,
    c("ENV", "KL_VEC", "XF_VEC", "DATE_START", "DATE_END",
      "CULTIVAR", "SOW_DATE", "ROW_SPACING", "CO2_PPM",
      "prepare_soil", "extract_results",
      "apsim_dir", "weather_path", "soil_path", "template_path"),
    envir = environment())

  clusterEvalQ(cl, {
    suppressPackageStartupMessages({
      library(apsimx)
      library(dplyr)
    })
  })

  ## ── Main parallel loop ────────────────────────────────────────────────
  cat(sprintf("[%s] Beginning parallel simulations\n", .ts()))

  # Create chunks of cells
  n_chunks <- ceiling(nrow(sim.grid1) / CHUNK_SIZE)
  chunks <- split(1:nrow(sim.grid1),
                  rep(1:n_chunks, each = CHUNK_SIZE, length.out = nrow(sim.grid1)))

  total_results <- list()
  log_data <- data.frame()

  for (chunk_idx in seq_along(chunks)) {
    chunk_rows <- chunks[[chunk_idx]]
    chunk_cells <- sim.grid1[chunk_rows, ]

    # Check for checkpoint
    checkpoint_file <- file.path(checkpoint_dir,
                                 sprintf("chunk_%03d.rds", chunk_idx))

    if (file.exists(checkpoint_file)) {
      cat(sprintf("[%s] Chunk %d/%d: SKIPPING (checkpoint exists)\n",
                  .ts(), chunk_idx, n_chunks))
      total_results[[chunk_idx]] <- readRDS(checkpoint_file)
      next
    }

    cat(sprintf("[%s] Chunk %d/%d: %d cells...\n",
                .ts(), chunk_idx, n_chunks, nrow(chunk_cells)))

    # Parallel processing within chunk
    chunk_results <- foreach(
      i = seq_len(nrow(chunk_cells)),
      .combine = "rbind",
      .packages = c("apsimx", "dplyr")
    ) %dopar% {

      cell_row <- chunk_cells[i, ]
      cellid   <- cell_row$cellid

      # Paths
      weather_file <- file.path(weather_path, paste0(cellid, ".met"))
      soil_file    <- file.path(soil_path,    paste0(cellid, ".rds"))

      if (!file.exists(weather_file)) return(NULL)
      if (!file.exists(soil_file))    return(NULL)

      tryCatch({
        # Copy template to temp file
        temp_file <- file.path(apsim_dir, paste0("sim-", cellid, "-", Sys.getpid(), ".apsimx"))
        file.copy(template_path, temp_file, overwrite = TRUE)

        # Set Clock dates
        edit_apsimx(file = basename(temp_file), src.dir = dirname(temp_file),
                    wrt.dir = dirname(temp_file),
                    node = "Clock", parm = "Start", value = DATE_START,
                    overwrite = TRUE, verbose = FALSE)

        edit_apsimx(file = basename(temp_file), src.dir = dirname(temp_file),
                    wrt.dir = dirname(temp_file),
                    node = "Clock", parm = "End", value = DATE_END,
                    overwrite = TRUE, verbose = FALSE)

        # Set weather file
        edit_apsimx(file = basename(temp_file), src.dir = dirname(temp_file),
                    wrt.dir = dirname(temp_file),
                    node = "Weather", value = weather_file,
                    overwrite = TRUE, verbose = FALSE)

        # Set soil profile
        sp <- prepare_soil(soil_file, KL_VEC, XF_VEC)
        if (is.null(sp)) return(NULL)

        edit_apsimx_replace_soil_profile(
          file = basename(temp_file), src.dir = dirname(temp_file),
          wrt.dir = dirname(temp_file),
          soil.profile = sp$soils, verbose = FALSE, overwrite = TRUE)

        edit_apsimx(file = basename(temp_file), src.dir = dirname(temp_file),
                    wrt.dir = dirname(temp_file),
                    node = "Soil", soil.child = "Physical",
                    parm = "KL", value = sp$KL,
                    verbose = FALSE, overwrite = TRUE)

        edit_apsimx(file = basename(temp_file), src.dir = dirname(temp_file),
                    wrt.dir = dirname(temp_file),
                    node = "Soil", soil.child = "Physical",
                    parm = "XF", value = sp$XF,
                    verbose = FALSE, overwrite = TRUE)

        # Run APSIM
        sim <- apsimx(file = basename(temp_file), src.dir = dirname(temp_file),
                      cleanup = TRUE)

        # Extract results
        result <- extract_results(sim, cell_row)

        # Clean up temp file
        tryCatch(file.remove(temp_file), error = function(e) NULL)

        return(result)

      }, error = function(e) {
        # Log error but continue
        message(sprintf("[ERROR] Cell %d: %s", cellid, e$message))
        return(NULL)
      })
    }

    # Save checkpoint
    saveRDS(chunk_results, checkpoint_file)
    total_results[[chunk_idx]] <- chunk_results

    n_ok <- sum(!sapply(chunk_results, is.null))
    cat(sprintf("[%s] Chunk %d complete: %d/%d cells successful\n",
                .ts(), chunk_idx, n_ok, nrow(chunk_cells)))
  }

  # Combine all results
  all_results <- do.call(rbind, total_results)
  all_results <- all_results[!is.na(all_results$cellid), ]

  # Save results
  result_file <- file.path(processed_dir, "simulation-results.rds")
  saveRDS(all_results, result_file)

  cat(sprintf("\n[%s] Simulations COMPLETE\n", .ts()))
  cat(sprintf("  Total records: %d\n", nrow(all_results)))
  cat(sprintf("  Date range: %s to %s\n",
              min(all_results$Date, na.rm=TRUE), max(all_results$Date, na.rm=TRUE)))
  cat(sprintf("  Saved to: %s\n", result_file))
  cat(sprintf("  Checkpoints: %s/\n\n", checkpoint_dir))

}, error = function(e) {
  cat(sprintf("[%s] ERROR: %s\n", .ts(), e$message))
  stop("Simulation failed", call. = FALSE)

}, finally = {
  stopCluster(cl)
})

cat(sprintf("[%s] Phase 1 finished\n\n", .ts()))
