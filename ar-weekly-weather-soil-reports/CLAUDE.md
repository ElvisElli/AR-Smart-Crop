# CLAUDE.md — ar-weekly-weather-soil-reports

Development guidance for Claude Code when working in this repository.

## Project Purpose

Generate automated weekly reports on Arkansas soil water status using APSIM Next Generation crop simulations across ~4,650 grid cells. Results benchmarked against historical conditions and published to a professional Quarto website.

**Key difference from soybean-ar-climate-change:** 
- Simplified to **baseline scenario only** (no climate perturbations)
- **Weekly runs** (current week only, not 40-year simulations)
- **Focus on soil water output** (swhc_6in, swhc_12in, swhc_24in)
- **Automated scheduling** with weekly reporting & Quarto website

## Running the Pipeline

### Full Pipeline (All Steps)
```bash
cd /path/to/ar-weekly-weather-soil-reports
Rscript code/00-master.R
```

### Individual Steps (Development)
```r
# Test APSIM simulations only
source("code/01-simulation.R")

# After sim works, test processing
source("code/02-processing.R")

# Then test reporting
source("code/03-generate-report.R")
```

## Build Phases (Iterative)

### ✅ Phase 1: Core APSIM Simulation (CURRENT)
**Goal:** Verify APSIM grid simulations work with sample data  
**Files:** 
- `code/00-config.R` - Configuration
- `code/01-simulation.R` - APSIM parallel grid simulations
**Test:** Run with sample weather files, verify checkpoints created

### Phase 2: Data Processing (NEXT)
**Goal:** Extract soil water values from APSIM results  
**Files:**
- `code/02-processing.R` - Aggregate soil water metrics
**Output:** `data/outputs/soil-water-status-YYYY-WW.csv`

### Phase 3: Report Generation (THEN)
**Goal:** Generate HTML weekly report  
**Files:**
- `code/03-generate-report.R` - Render Quarto/Rmarkdown
- `reports/weekly-report-template.qmd` - Report template
**Output:** `data/outputs/weekly-report-YYYY-WW.html`

### Phase 4: Orchestration & Website (FINAL)
**Goal:** Automate scheduling and Quarto website  
**Files:**
- `code/00-master.R` - Orchestrates phases 1-3
- `_quarto.yml`, `index.qmd` - Website structure
- `schedule/github-actions-workflow.yml` - Cloud automation

## Key Configuration

File: `code/00-config.R`

```r
# Simulation window (weekly)
DATE_START <- "2025-06-16"
DATE_END   <- "2025-06-22"

# Parallel processing
CHUNK_SIZE <- 50            # cells per parallel task
FORCE_RERUN_SIM <- FALSE    # TRUE = delete checkpoints, re-run all

# Test mode
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

## Development Checklist

### Phase 1 Testing
- [ ] Copy sample weather files to `data/raw/weather/`
- [ ] Copy corresponding soil files to `data/raw/soil/`
- [ ] Copy/create sim-grid.rds with test cells
- [ ] Copy APSIM template to `templates/baseline.apsimx`
- [ ] Set `TEST_RUN <- TRUE` in 00-config.R
- [ ] Run: `source("code/01-simulation.R")`
- [ ] Verify: Checkpoints created in `data/outputs/checkpoints/`
- [ ] Verify: Results in `data/processed/simulation-results.rds`

### Phase 2 Testing
- [ ] Run: `source("code/02-processing.R")`
- [ ] Verify: `data/outputs/soil-water-status-*.csv` created
- [ ] Check CSV has columns: cellid, date, swhc_6in, swhc_12in, swhc_24in

### Phase 3 Testing
- [ ] Create report template: `reports/weekly-report-template.qmd`
- [ ] Run: `source("code/03-generate-report.R")`
- [ ] Verify: `data/outputs/weekly-report-*.html` created
- [ ] Open in browser and check rendering

### Phase 4 Testing
- [ ] Create `code/00-master.R` orchestrator
- [ ] Run: `source("code/00-master.R")`
- [ ] Verify all phases run in sequence
- [ ] Build Quarto website: `quarto render`
- [ ] Verify: `_site/` contains website

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

### Adapted from soybean-ar-climate-change

This project reuses key patterns from soybean-ar-climate-change:
1. **Environment auto-detection** — Same Windows/Linux/cloud detection
2. **Parallel chunking** — Same PSOCK cluster architecture
3. **Checkpointing** — Per-chunk RDS files for resumability
4. **APSIM editing** — Same apsimx parameter modification approach
5. **Progress logging** — Same sim-run-log.csv pattern

### Simplified for Weekly Use

Compared to soybean-ar-climate-change:
- **No scenarios loop** — Just baseline (no climate change scenarios)
- **No chunking across scenarios** — Single scenario, chunk only grid cells
- **Weekly dates** — DATE_START/END for current week only
- **Faster turnaround** — Minutes instead of hours
- **Focus on soil water** — Extract only swhc_* and water balance columns

## Next Steps

1. **Prepare test data:**
   ```bash
   cp /home/user/soybean-ar-climate-change/data/raw/weather_sample/* \
      ar-weekly-weather-soil-reports/data/raw/weather/
   # Copy corresponding soil files
   # Create sim-grid.rds with matching cells
   ```

2. **Set TEST_RUN mode:**
   ```r
   # In code/00-config.R:
   TEST_RUN <- TRUE
   TEST_N_CELLS <- 10  # Start small
   ```

3. **Test Phase 1:**
   ```r
   source("code/01-simulation.R")
   ```

4. **Verify output:**
   ```r
   # Check if results exist
   list.files("data/outputs/checkpoints/")
   readRDS("data/processed/simulation-results.rds") %>% head()
   ```

5. **Proceed to Phase 2** once Phase 1 passes all checks

## Contact

**Questions about development?** See inline comments in each script.  
**Issues with APSIM?** Check APSIM GUI documentation or contact APSIM support.  
**Project lead:** eelli@uark.edu
