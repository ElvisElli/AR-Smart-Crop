# CLAUDE.md — ar-weekly-weather-soil-reports

Development guidance for Claude Code when working in this repository.

## Project Purpose

Generate automated weekly reports on Arkansas soil water status using APSIM Next Generation crop simulations across ~4,650 grid cells. Results benchmarked against historical conditions and published to a professional Quarto website.

**Key difference from soybean-ar-climate-change:** 
- Simplified to **baseline scenario only** (no climate perturbations)
- **Three-mode architecture**: WEEKLY (current), HISTORICAL (baseline generation), FORECAST (research stations)
- **Weekly runs** (current week only, compared to 40-year baseline)
- **Focus on soil water output** (swhc_6in, swhc_12in, swhc_24in)
- **Automated scheduling** with weekly reporting & Quarto website

## Running the Pipeline

### Three-Mode Architecture

The system now supports three distinct simulation modes, configured in `code/00-config.R`:

```r
SIMULATION_MODE <- "weekly"  # "weekly" | "historical" | "forecast"
```

### Mode 1: WEEKLY (Default)
Simulates entire crop season to date (Jan-1 to present), compares to 40-year baseline.

```r
# Every week: Edit code/00-config.R and update:
SIMULATION_MODE <- "weekly"
DATE_START <- "2026-01-01"  # Season start (always Jan-1)
DATE_END   <- "2026-06-26"  # Update to TODAY's date weekly
USE_BENCHMARK <- TRUE       # Enable benchmark comparisons

# Prepare: Download weather data from Jan-1 through present day
# Then run full pipeline:
source("code/04-orchestrate.R")

# Outputs:
#   - data/processed/weekly/simulation-results.rds (full season)
#   - data/outputs/soil-water-status-2026-W26.csv (season-to-date metrics)
#   - data/outputs/weekly-report-2026-W26.html (with benchmark comparisons)
```

**Why season-to-date?** Soil water dynamics depend on entire season history. Weekly reports show how cumulative weather and crop development have affected soil conditions, not just one week's changes.

### Mode 2: HISTORICAL (Setup Only)
Generates 40-year (1985-2025) baseline statistics—run once, then reuse.

```r
# One-time setup: Generate yearly simulations (runs Phase 1 only)
SIMULATION_MODE <- "historical"
source("code/04-orchestrate.R")
# Output: data/processed/historical/simulation-results-1985.rds through 2025.rds

# After all years complete, generate benchmark:
source("code/05-generate-historical-benchmark.R")
# Outputs: data/outputs/benchmark/historical-statistics.rds (40-year stats)
```

### Mode 3: FORECAST (Research Stations - Optional)
Simulates research stations from Jan-1 through +7 days forecast for irrigation planning.

```r
# Edit code/00-config.R:
SIMULATION_MODE <- "forecast"
FORECAST_STATION_CELLS <- c(10, 50, 150)  # Your research station cell IDs
FORECAST_RUN_CONCURRENT <- TRUE           # Run alongside weekly mode

# Prepare forecast weather data (Jan-1 through present + 7 days)
# Then run pipeline:
source("code/04-orchestrate.R")

# Outputs:
#   - data/processed/forecast/simulation-results.rds (selected cells)
#   - data/outputs/soil-water-status-2026-W26.csv (research stations)
#   - data/outputs/forecast-report-2026-W26.html (7-day outlook)
```

**Concurrent execution:** Can run in parallel with weekly mode on separate cluster workers.

## Pipeline Phases (All Modes)

### Phase 1: APSIM Grid Simulation
**All modes**: Runs APSIM across grid cells in parallel
- **WEEKLY**: Full crop season to date (Jan-1 through present day)
- **FORECAST**: Full season to date + 7 days forecast (research stations only if specified)
- **HISTORICAL**: Yearly date ranges (1985-2025), one year per run
- **Files**: `code/01-simulation.R`, `code/00-config.R`
- **Output**: 
  - Weekly/Forecast: `data/processed/[mode]/simulation-results.rds`
  - Historical: `data/processed/historical/simulation-results-YYYY.rds` (per year)

### Phase 2: Data Processing
**Weekly/Forecast only** (Historical is skipped):
- Extracts soil water metrics from APSIM results
- Joins benchmark statistics (weekly mode) for comparison
- **Files**: `code/02-processing.R`
- **Output**: `data/outputs/soil-water-status-YYYY-WW.csv`

### Phase 3: Report Generation
**Weekly/Forecast only** (Historical is skipped):
- Renders professional Quarto HTML report with maps, plots, benchmark tables
- **Files**: `code/03-generate-report.R`, `reports/weekly-report-template.qmd`
- **Output**: `data/outputs/weekly-report-YYYY-WW.html`

### Phase 4: Orchestration
**All modes**: Routes through appropriate phases based on mode
- **Files**: `code/04-orchestrate.R`
- **Logic**: 
  - HISTORICAL: Phase 1 only → prompt Phase 5
  - WEEKLY/FORECAST: Phases 1 → 2 → 3 → done

### Phase 5: Benchmark Generation (Historical Only)
**Historical mode only** (run after all yearly simulations):
- Aggregates 40-year results into single benchmark file
- Calculates per-cell statistics: means, SD, percentiles (P10, P25, P75, P90)
- Computes decadal averages (1985-1994, 1995-2004, etc.)
- **Files**: `code/05-generate-historical-benchmark.R`
- **Input**: `data/processed/historical/simulation-results-YYYY.rds` (all years)
- **Output**: `data/outputs/benchmark/historical-statistics.rds`

## Key Configuration

File: `code/00-config.R`

### Mode Selection

```r
# Choose simulation mode
SIMULATION_MODE <- "weekly"   # "weekly" | "historical" | "forecast"

# Weekly mode: Season-to-date (Jan-1 through present)
# UPDATE DATE_END TO TODAY'S DATE EACH WEEK
DATE_START <- "2026-01-01"    # Always Jan-1 (season start)
DATE_END   <- "2026-06-26"    # Today's date (update weekly)

# Historical mode: 1985-2025 baseline (one-time setup)
HISTORICAL_START <- "1985-01-01"
HISTORICAL_END   <- "2025-12-31"
HISTORICAL_AGGREGATION <- "yearly"  # Process by year

# Forecast mode: Season-to-date + 7 days forecast
FORECAST_START <- "2026-01-01"      # Season start (like weekly)
FORECAST_END   <- "2026-07-03"      # Present + 7 days forecast
FORECAST_DATA_SOURCE <- NULL        # Path to forecast .met files
```

### Forecast Mode Configuration

```r
# Research station cell IDs (optional subset for faster forecast runs)
FORECAST_STATION_CELLS <- c()      # Empty = all cells
                                   # Example: c(10, 50, 100)

# Run forecast concurrently with weekly mode (separate cluster)
FORECAST_RUN_CONCURRENT <- TRUE
```

### Parallel Processing

```r
CHUNK_SIZE <- 50            # cells per parallel task (50 = moderate)
N_CORES <- NA               # NA = auto-detect; set to fixed number to override
FORCE_RERUN_SIM <- FALSE    # TRUE = delete checkpoints, re-run all
```

### Benchmarking (Weekly Mode Only)

```r
USE_BENCHMARK <- TRUE                      # Enable 40-year comparisons
BENCHMARK_FILE <- "data/outputs/benchmark/historical-statistics.rds"
INCLUDE_BENCHMARK_TABLES <- (SIMULATION_MODE == "weekly" && USE_BENCHMARK)
```

### Test Mode

```r
TEST_RUN <- FALSE           # TRUE = run only 20 cells for quick test
TEST_N_CELLS <- 20
```

## Data Requirements

For Phase 1 testing, you need:
- `data/raw/sim-grid.rds` — Grid of cells with (x, y, cellid)
- `data/raw/weather/` — Weather .met files (cell-indexed: 1.met, 2.met, ..., 4651.met)
- `data/raw/soil/` — Soil profiles (cell-indexed: 1.rds, 2.rds, ..., 4651.rds)
- `templates/baseline.apsimx` — APSIM template (MG4, baseline scenario)

**For testing with sample data:**
- Sample weather files exist at: `/home/user/soybean-ar-climate-change/data/raw/weather_sample/`
- Can use subset of ~10-20 cells for testing

## Testing the Three-Mode Architecture

### Setup (All Modes)
- [ ] Copy production data: weather, soil, sim-grid files
- [ ] Copy APSIM template to `templates/baseline.apsimx`
- [ ] Edit `code/00-config.R` with current dates

### Test 1: Weekly Mode (Current Week Report)
- [ ] Set `SIMULATION_MODE <- "weekly"`
- [ ] Set `DATE_START` and `DATE_END` to current week
- [ ] Set `USE_BENCHMARK <- TRUE` (if 40-year baseline ready)
- [ ] Run: `source("code/04-orchestrate.R")`
- [ ] Verify: `data/processed/weekly/simulation-results.rds`
- [ ] Verify: `data/outputs/soil-water-status-YYYY-WW.csv`
- [ ] Verify: `data/outputs/weekly-report-YYYY-WW.html` with benchmark tables
- [ ] Open HTML in browser and check:
  - Spatial maps (6in, 12in, 24in depths)
  - Depth comparison chart
  - Benchmark comparison section (if baseline available)

### Test 2: Historical Mode (40-Year Baseline Generation)
- [ ] **First time only**: Set `SIMULATION_MODE <- "historical"`
- [ ] Set `HISTORICAL_START` and `HISTORICAL_END` to 1985-2025
- [ ] Run Phase 1: `source("code/01-simulation.R")`
- [ ] Verify yearly results in: `data/processed/historical/simulation-results-*.rds`
- [ ] After all years complete, run Phase 5:
  ```r
  source("code/05-generate-historical-benchmark.R")
  ```
- [ ] Verify benchmark file: `data/outputs/benchmark/historical-statistics.rds`
- [ ] Check benchmark contains 40-year stats per cell

### Test 3: Forecast Mode (Research Station Predictions)
- [ ] Set `SIMULATION_MODE <- "forecast"`
- [ ] Set `FORECAST_START` and `FORECAST_END` to next week
- [ ] Prepare forecast weather files in `data/raw/forecast/`
- [ ] Set `PATH_WEATHER <- "data/raw/forecast"` (or use FORECAST_DATA_SOURCE)
- [ ] Run: `source("code/04-orchestrate.R")`
- [ ] Verify: `data/processed/forecast/simulation-results.rds`
- [ ] Verify: `data/outputs/soil-water-status-YYYY-WW.csv`
- [ ] Verify: `data/outputs/forecast-report-YYYY-WW.html` for 7-day outlook

### Full Automated Pipeline
- [ ] Verify orchestrator works: `source("code/04-orchestrate.R")`
- [ ] Check Phase routing (all modes should skip/run appropriate phases)
- [ ] Schedule via GitHub Actions for weekly runs
- [ ] Build Quarto website: `quarto render`
- [ ] Verify: `_site/` contains website with all reports

## Environment Detection

The code auto-detects:
- **Windows:** APSIM path from `%LOCALAPPDATA%\Programs\APSIM*`
- **Linux/Cloud:** APSIM at `/usr/local/lib/apsim/*/bin/Models`
- **Cores:** Automatically uses `detectCores() - 1` (leaves 1 free)

## Common Issues

**Issue: "APSIM not found"**
- Windows: Check `%LOCALAPPDATA%\Programs\` for APSIM folder
- Linux: Run `which Models` to verify installation
- Fix: Edit `code/01-simulation.R` to set `APSIM_EXE` manually

**Issue: "Weather directory not found"**
- Check `data/raw/weather/` exists with `.met` files
- File names should match cell IDs (e.g., `1.met`, `2.met`)
- Or use `TEST_RUN <- TRUE` to use sample files

**Issue: "Simulation crashes mid-run"**
- Checkpoints auto-save in `data/outputs/checkpoints/`
- Re-run to resume from last completed chunk
- To force re-run: Set `FORCE_RERUN_SIM <- TRUE`

**Issue: "Memory errors with large grids"**
- Reduce `CHUNK_SIZE` (e.g., 25 instead of 50)
- Use fewer cores: Set `N_CORES <- 2` manually
- Run on machine with more RAM

## Architecture Notes

### Three-Mode Design

The system now supports three distinct operational modes without code duplication:

**Mode Routing in Phase 1 (code/01-simulation.R):**
- Detects `SIMULATION_MODE` from config
- For **historical**: Wraps chunk processing in year-loop (1985-2025)
  - Saves yearly checkpoints: `chunk_YYYY_CCC.rds`
  - Outputs yearly results: `simulation-results-YYYY.rds`
- For **weekly/forecast**: Single date range processing
  - Standard per-chunk checkpoints: `chunk_CCC.rds`
  - Single output file: `simulation-results.rds`

**Mode Routing in Phases 2-3:**
- Phase 2 detects historical mode → exits early (no processing needed)
- Phase 3 detects historical mode → exits early (no reporting needed)
- Phases 2-3 run normally for weekly/forecast modes

**Benchmark Integration (Weekly Only):**
- Phase 2 optionally loads 40-year benchmark statistics
- Joins benchmark columns to CSV output
- Report template conditionally renders comparison tables

### Adapted from soybean-ar-climate-change

This project reuses key patterns:
1. **Environment auto-detection** — Windows/Linux/cloud detection
2. **Parallel chunking** — PSOCK cluster architecture
3. **Checkpointing** — Per-chunk RDS files for resumability
4. **APSIM editing** — apsimx parameter modification approach
5. **Mode-aware configuration** — Dynamic date range selection

### Enhanced for Three-Mode Operation

New features beyond soybean-ar-climate-change:
- **No scenarios loop** — Baseline only (no climate perturbations)
- **Multi-mode routing** — Historical baseline, weekly reports, forecast
- **Yearly aggregation** — Historical mode processes year-by-year
- **Benchmark generation** — Phase 5 creates 40-year statistics
- **Benchmark comparison** — Weekly reports show current vs. historical
- **Dynamic directories** — Mode-specific checkpoints and output paths

## Implementation Guide

### First Time Setup: Generate 40-Year Baseline

```r
# 1. Prepare historical weather and soil data (1985-2025)
# 2. Edit code/00-config.R:
SIMULATION_MODE <- "historical"
HISTORICAL_START <- "1985-01-01"
HISTORICAL_END <- "2025-12-31"
TEST_RUN <- FALSE  # Use full grid for accurate baseline

# 3. Run Phase 1 (generates yearly results)
source("code/01-simulation.R")
# Output: data/processed/historical/simulation-results-1985.rds ... simulation-results-2025.rds

# 4. Generate 40-year benchmark statistics
source("code/05-generate-historical-benchmark.R")
# Output: data/outputs/benchmark/historical-statistics.rds
```

### Weekly Automated Reports

```r
# 1. Prepare current week weather data
# 2. Edit code/00-config.R:
SIMULATION_MODE <- "weekly"
DATE_START <- "2026-01-05"  # Current week start
DATE_END <- "2026-01-11"    # Current week end
USE_BENCHMARK <- TRUE       # Use 40-year baseline

# 3. Run full pipeline
source("code/04-orchestrate.R")
# Outputs:
#   - data/processed/weekly/simulation-results.rds
#   - data/outputs/soil-water-status-2026-W01.csv
#   - data/outputs/weekly-report-2026-W01.html (with benchmark tables)
```

### Research Station Forecasts (Optional)

```r
# 1. Prepare 7-day forecast weather data
# 2. Edit code/00-config.R:
SIMULATION_MODE <- "forecast"
FORECAST_START <- "2026-01-12"
FORECAST_END <- "2026-01-18"
PATH_WEATHER <- "data/raw/forecast"  # Forecast .met files

# 3. Run pipeline for next week prediction
source("code/04-orchestrate.R")
# Outputs:
#   - data/outputs/soil-water-status-2026-W02.csv
#   - data/outputs/forecast-report-2026-W02.html
```

### Schedule Automated Weekly Runs

Setup GitHub Actions workflow in `.github/workflows/weekly-report.yml`:
- Trigger: Weekly schedule (Mondays at 00:00 UTC)
- Environment: Cloud runner with production data
- Steps:
  1. Load weather data for current week
  2. Set `SIMULATION_MODE <- "weekly"`
  3. Run `source("code/04-orchestrate.R")`
  4. Build website: `quarto render`
  5. Deploy to GitHub Pages

See: `schedule/github-actions-workflow.yml` for example template

## Contact

**Questions about development?** See inline comments in each script.  
**Issues with APSIM?** Check APSIM GUI documentation or contact APSIM support.  
**Project lead:** eelli@uark.edu
