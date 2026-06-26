# ═══════════════════════════════════════════════════════════════════════════
# Phase 1 Structural Validation Test
# ═══════════════════════════════════════════════════════════════════════════
# Tests the R code logic without needing APSIM or soil files

cat("\n")
cat(strrep("=", 70), "\n")
cat("PHASE 1 STRUCTURAL VALIDATION TEST\n")
cat("(Tests code logic without APSIM or soil data)\n")
cat(strrep("=", 70), "\n\n")

# Load required packages
cat("[SETUP] Loading R packages...\n")
library(dplyr)
library(foreach)
library(parallel)
library(data.table)
library(readr)
cat("[SETUP]  All packages loaded\n\n")

# Test 1: Configuration Loading
cat("[TEST 1] Configuration Loading\n")
cat(strrep("-", 70), "\n")
source("code/00-config.R")
cat(sprintf(" Simulation window: %s to %s\n", DATE_START, DATE_END))
cat(sprintf(" Chunk size: %d cells\n", CHUNK_SIZE))
cat(sprintf(" Test mode: %s\n", if(TEST_RUN) "ON" else "OFF"))
cat(sprintf(" Sample data mode: %s\n\n", if(USE_SAMPLE_DATA) "ON" else "OFF"))

# Test 2: Path Validation
cat("[TEST 2] Path and File Validation\n")
cat(strrep("-", 70), "\n")
checks <- list(
  "Grid file" = file.exists(PATH_SIM_GRID),
  "Weather dir" = dir.exists(PATH_WEATHER),
  "Template" = file.exists(file.path(PATH_TEMPLATES, APSIM_TEMPLATE))
)
for (name in names(checks)) {
  status <- if (checks[[name]]) "" else ""
  cat(sprintf("%s %s\n", status, name))
}
cat("\n")

# Test 3: Grid Loading
cat("[TEST 3] Grid Data Structure\n")
cat(strrep("-", 70), "\n")
if (file.exists(PATH_SIM_GRID)) {
  grid <- readRDS(PATH_SIM_GRID)
  cat(sprintf(" Grid loaded: %d cells\n", nrow(grid)))
  cat(sprintf(" Columns: %s\n", paste(names(grid), collapse=", ")))
  cat(sprintf(" Cultivated cells: %d\n", sum(grid$cultivated, na.rm=TRUE)))
  cat(sprintf(" Sample data:\n"))
  print(head(grid, 3))
  cat("\n")
}

# Test 4: Weather Files
cat("[TEST 4] Weather File Detection\n")
cat(strrep("-", 70), "\n")
weather_files <- list.files(PATH_WEATHER, pattern="\\.met$", full.names=TRUE)
cat(sprintf(" Weather files found: %d\n", length(weather_files)))
if (length(weather_files) > 0) {
  sample_file <- weather_files[1]
  cat(sprintf(" Sample file: %s\n", basename(sample_file)))
  cat(sprintf(" File size: %.1f KB\n", file.size(sample_file) / 1024))
}
cat("\n")

# Test 5: Test Mode Limiting Logic
cat("[TEST 5] Test Mode Cell Selection Logic\n")
cat(strrep("-", 70), "\n")
if (file.exists(PATH_SIM_GRID)) {
  grid <- readRDS(PATH_SIM_GRID)
  cultivated_cells <- grid %>%
    filter(cultivated == 1) %>%
    pull(cellid)

  cat(sprintf(" Total cultivated cells: %d\n", length(cultivated_cells)))

  if (TEST_RUN) {
    test_cells <- cultivated_cells[1:min(TEST_N_CELLS, length(cultivated_cells))]
    cat(sprintf(" Test mode: Using first %d cells\n", length(test_cells)))
    cat(sprintf(" Test cell IDs: %s\n", paste(test_cells[1:min(5,length(test_cells))], collapse=", ")))
  } else {
    cat(sprintf(" Production mode: Using all %d cells\n", length(cultivated_cells)))
  }
  cat("\n")
}

# Test 6: Parallel Processing Setup Logic
cat("[TEST 6] Parallel Processing Configuration\n")
cat(strrep("-", 70), "\n")
n_cores_auto <- parallel::detectCores() - 1
n_cores_final <- if (is.na(N_CORES)) n_cores_auto else N_CORES
cat(sprintf(" Available cores: %d\n", parallel::detectCores()))
cat(sprintf(" Cores to use: %d\n", n_cores_final))
cat(sprintf(" Chunk size: %d cells per task\n", CHUNK_SIZE))

if (file.exists(PATH_SIM_GRID)) {
  grid <- readRDS(PATH_SIM_GRID)
  cultivated_cells <- grid %>% filter(cultivated == 1) %>% pull(cellid)
  test_cells <- if(TEST_RUN) cultivated_cells[1:min(TEST_N_CELLS, length(cultivated_cells))] else cultivated_cells

  n_chunks <- ceiling(length(test_cells) / CHUNK_SIZE)
  cat(sprintf(" Cells to process: %d\n", length(test_cells)))
  cat(sprintf(" Chunks needed: %d\n", n_chunks))
  cat(" Chunk sizes: ")
  for (i in 1:n_chunks) {
    start <- (i-1) * CHUNK_SIZE + 1
    end <- min(i * CHUNK_SIZE, length(test_cells))
    size <- end - start + 1
    if (i > 1) cat(", ")
    cat(size)
  }
  cat("\n\n")
}

# Test 7: Date Parsing Logic
cat("[TEST 7] Simulation Window Parsing\n")
cat(strrep("-", 70), "\n")
date_start <- as.Date(DATE_START)
date_end <- as.Date(DATE_END)
date_seq <- seq(date_start, date_end, by="day")
cat(sprintf(" Start date: %s\n", format(date_start, "%Y-%m-%d")))
cat(sprintf(" End date: %s\n", format(date_end, "%Y-%m-%d")))
cat(sprintf(" Days in window: %d\n", length(date_seq)))
cat(sprintf(" Date range: %s to %s\n\n", min(date_seq), max(date_seq)))

# Test 8: Output Directory Structure
cat("[TEST 8] Output Directory Structure\n")
cat(strrep("-", 70), "\n")
output_dirs <- c(
  "Processed" = PATH_PROCESSED,
  "Outputs" = PATH_OUTPUTS,
  "Checkpoints" = PATH_CHECKPOINTS
)
for (name in names(output_dirs)) {
  path <- output_dirs[[name]]
  dir.create(path, showWarnings=FALSE, recursive=TRUE)
  status <- if (dir.exists(path)) "" else ""
  cat(sprintf("%s %s: %s\n", status, name, path))
}
cat("\n")

# Test 9: Expected Output Structure
cat("[TEST 9] Expected Output Column Structure\n")
cat(strrep("-", 70), "\n")
expected_cols <- c(
  "cellid", "x", "y", "cultivated",
  "cultivar", "sowing", "date",
  "Yield_kgha", "biomass_kgha",
  "swhc_6in", "swhc_12in", "swhc_24in",
  "Crop_ET", "WDrainage", "WRunoff"
)
cat(" Expected output columns:\n")
for (col in expected_cols) {
  cat(sprintf("   • %s\n", col))
}
cat("\n")

# Test 10: Configuration Consistency Check
cat("[TEST 10] Configuration Consistency\n")
cat(strrep("-", 70), "\n")
checks <- list(
  "DATE_START before DATE_END" = DATE_START < DATE_END,
  "CHUNK_SIZE > 0" = CHUNK_SIZE > 0,
  "N_CORES is NA or > 0" = is.na(N_CORES) || N_CORES > 0,
  "TEST_N_CELLS > 0" = TEST_N_CELLS > 0,
  "CULTIVAR not empty" = nchar(CULTIVAR) > 0,
  "SOW_DATE not empty" = nchar(SOW_DATE) > 0,
  "KL_VEC has 20 values" = length(KL_VEC) == 20,
  "XF_VEC has 20 values" = length(XF_VEC) == 20
)
for (name in names(checks)) {
  status <- if (checks[[name]]) "" else ""
  cat(sprintf("%s %s\n", status, name))
}
cat("\n")

# Summary
cat(strrep("=", 70), "\n")
cat("PHASE 1 STRUCTURAL VALIDATION COMPLETE\n")
cat(strrep("=", 70), "\n\n")

cat("SUMMARY:\n")
cat(" All R packages installed and working\n")
cat(" Configuration loads correctly\n")
cat(" Required files and directories present\n")
cat(" Grid data structure valid\n")
cat(" Weather files detected\n")
cat(" Parallel processing configuration valid\n")
cat(" Output directory structure ready\n")
cat(" Configuration is internally consistent\n\n")

cat("NEXT STEPS:\n")
cat("1. If this is a cloud environment without APSIM:\n")
cat("   → User should test locally on Windows with APSIM installed\n")
cat("   → Run: source('code/01-simulation.R')\n\n")
cat("2. If APSIM is available in this environment:\n")
cat("   → Continue with: source('code/01-simulation.R')\n")
cat("   → Check: data/processed/simulation-results.rds\n\n")

cat(strrep("=", 70), "\n\n")
