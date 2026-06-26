# Phase 1 Testing Guide

## Objective
Verify APSIM grid simulations work correctly with sample data before proceeding to Phase 2 (data processing).

## Prerequisites

### 1. Install R Packages
```r
# In R/RStudio:
install.packages(c("apsimx", "dplyr", "doParallel", "foreach", "parallel", "data.table", "readr"))
```

### 2. Install APSIM Next Generation
- **Windows:** Download from https://www.apsim.info/
- **Linux/Cloud:** 
  ```bash
  sudo apt-get install apsim
  # Or specify path in 00-config.R APSIM_EXE
  ```
- Verify: `which Models` (Linux) or check `%LOCALAPPDATA%\Programs\` (Windows)

### 3. Install Quarto (for later phases)
```bash
# https://quarto.org/docs/get-started/
```

## Step-by-Step Testing

### Step 1: Prepare Test Data

Copy sample weather files from soybean-ar-climate-change repo:

```bash
# From repo root
mkdir -p data/raw/weather_sample
cp /home/user/soybean-ar-climate-change/data/raw/weather_sample/*.met data/raw/weather_sample/
```

**Expected:** ~15-20 `.met` files in `data/raw/weather_sample/`

### Step 2: Copy Corresponding Soil Files

Get soil profiles matching the weather files:

```bash
# From soybean-ar-climate-change, get soil files for same cell IDs
mkdir -p data/raw/soil
# Copy matching RDS files (e.g., 503.rds, 504.rds, 506.rds, etc.)
cp /home/user/soybean-ar-climate-change/data/raw/soil/503.rds data/raw/soil/
# ... repeat for each weather file cell ID
```

**Check cell IDs match:**
```bash
# List weather file cell IDs
ls data/raw/weather_sample/ | sed 's/.met//' | sort

# List soil file cell IDs  
ls data/raw/soil/ | sed 's/.rds//' | sort

# They should match!
```

### Step 3: Create Simulation Grid

Create a minimal `sim-grid.rds` with test cells:

```r
# In R console at repo root:

# Get cell IDs from weather files
weather_files <- list.files("data/raw/weather_sample", "\\.met$")
cellids <- as.integer(sub("\\.met$", "", weather_files))

# Create minimal grid (use fake coordinates)
sim.grid <- data.frame(
  x = runif(length(cellids), -95, -89),  # Arkansas longitude range
  y = runif(length(cellids), 33, 37),    # Arkansas latitude range
  cellid = cellids,
  cultivated = 1
)

# Save
dir.create("data/raw", showWarnings = FALSE)
saveRDS(sim.grid, "data/raw/sim-grid.rds")

# Verify
head(sim.grid)
# Should show: x, y, cellid, cultivated
```

### Step 4: Copy APSIM Template

Copy the APSIM template from soybean-ar-climate-change:

```bash
mkdir -p templates
cp /home/user/soybean-ar-climate-change/templates/soybean-mg4-baseline.apsimx \
   templates/baseline.apsimx
```

**Verify:** 
```bash
ls -lh templates/baseline.apsimx
# Should show ~400 KB file
```

### Step 5: Configure for Test Mode

Edit `code/00-config.R`:

```r
# Set test mode
TEST_RUN <- TRUE
TEST_N_CELLS <- 5              # Start with just 5 cells

# Set simulation window (this week)
DATE_START <- "2025-06-16"
DATE_END   <- "2025-06-22"

# Enable sample data mode (auto on cloud)
USE_SAMPLE_DATA <- TRUE

# Keep other settings default
```

### Step 6: Run Phase 1 Simulation

```r
# In RStudio or command line:
cd /path/to/ar-weekly-weather-soil-reports
Rscript code/01-simulation.R

# Or in RStudio:
source("code/01-simulation.R")
```

**Expected output:**
```
[HH:MM:SS] Phase 1: APSIM Grid Simulation started

[ENV] Linux/cloud: codespaces-xyz
[ENV] APSIM: /usr/bin/Models
[PATHS] Weather: .../data/raw/weather_sample
[PATHS] Soil: .../data/raw/soil
[CHECK] Weather files: 15 | Soil files: 15

[INFO] Grid cells: 15 total | 15 cultivated
[TEST] 15 cells available | using 5

[CONFIG] Cells to simulate: 5
[CONFIG] Chunks: 1 (size 5 each)

[HH:MM:SS] Starting 2 parallel workers
[HH:MM:SS] Beginning parallel simulations
[HH:MM:SS] Chunk 1/1: 5 cells...
[HH:MM:SS] Chunk 1 complete: 5/5 cells successful

[HH:MM:SS] Simulations COMPLETE
  Total records: 168  (24 days × 7 cells)
  Date range: 2025-06-16 to 2025-06-22
  Saved to: .../data/processed/simulation-results.rds
```

### Step 7: Verify Output

Check that simulation results were created:

```bash
# List generated files
ls -lh data/processed/
ls -lh data/outputs/checkpoints/

# Expected:
# data/processed/simulation-results.rds      (~100 KB for test run)
# data/outputs/checkpoints/chunk_001.rds     (~100 KB checkpoint)
```

Inspect results in R:

```r
results <- readRDS("data/processed/simulation-results.rds")
head(results)

# Expected columns:
# x, y, cellid, cultivated, cultivar, sowing, Date,
# Yield_kgha, biomass_kgha, swhc_6in, swhc_12in, swhc_24in, Crop_ET, WDrainage, WRunoff

# Expected rows: ~120-168 rows (5 cells × 24-33 days depending on simulation)

# Check soil water values (should be between 0 and 100 mm typically)
summary(results$swhc_6in)
summary(results$swhc_12in)
summary(results$swhc_24in)
```

### Step 8: Test Resumability

Test that re-running skips completed chunks:

```r
# Run again (should skip checkpoint)
source("code/01-simulation.R")

# Expected: "[HH:MM:SS] Chunk 1/1: SKIPPING (checkpoint exists)"
```

### Step 9: Test Force Re-run

Test that deleting checkpoint forces re-simulation:

```r
# Delete checkpoint
unlink("data/outputs/checkpoints/chunk_001.rds")

# Set force re-run
# In 00-config.R: FORCE_RERUN_SIM <- TRUE

# Run again (should re-simulate)
source("code/01-simulation.R")

# Expected: New checkpoint file created, simulation runs fresh
```

## Troubleshooting

### Issue: "APSIM not found"

**Windows:**
```r
# Check if APSIM is installed
dir("C:/Users/*/AppData/Local/Programs/")  # Should show APSIM folder
```

**Linux:**
```bash
which Models
# If not found, install: sudo apt-get install apsim
```

**Fix:** Set manually in `code/00-config.R`:
```r
APSIM_EXE <- "C:/Program Files/APSIM2025.3.7681.0/bin/Models.exe"  # Windows
# Or
APSIM_EXE <- "/usr/bin/Models"  # Linux
```

### Issue: "Weather directory not found"

```bash
# Check paths
ls data/raw/weather_sample/
ls data/raw/soil/

# Both should exist and have matching file counts
```

### Issue: "Grid file not found"

Create `data/raw/sim-grid.rds` as shown in Step 3.

### Issue: "Template not found"

```bash
ls templates/
# Should show: baseline.apsimx
```

### Issue: Simulation times out or crashes

**Possible causes:**
- Cluster communication issues
- Memory exhausted
- APSIM crash

**Debug:**
1. Reduce `CHUNK_SIZE` (e.g., 10 instead of 50)
2. Reduce `N_CORES` (e.g., 2 instead of auto)
3. Check APSIM GUI with diagnostic mode:
   ```r
   # In 00-config.R:
   RUN_DIAGNOSTIC <- TRUE
   DIAG_CELL_ID <- 503  # A specific cell
   
   source("code/01-simulation.R")  # See detailed APSIM output
   ```

## Success Criteria

Phase 1 testing is **SUCCESSFUL** if all of the following pass:

✅ APSIM simulations run on test data (5+ cells)  
✅ Results saved to `data/processed/simulation-results.rds`  
✅ Checkpoint created in `data/outputs/checkpoints/`  
✅ Results contain soil water columns (swhc_6in, swhc_12in, swhc_24in)  
✅ Soil water values are realistic (0–100 mm range typically)  
✅ Re-running skips checkpoints (resumability works)  
✅ Force re-run re-simulates (cleanup works)  

## Next: Phase 2 Testing

Once Phase 1 passes all checks, proceed to Phase 2 (data processing):

```bash
# Create 02-processing.R script
# Run: source("code/02-processing.R")
# Verify: data/outputs/soil-water-status-*.csv created
```

---

**Questions?** Check inline comments in `code/01-simulation.R` or `CLAUDE.md`

**Report issues:** Include output from:
```r
sessionInfo()
apsimx_version()
```
