# Phase 1: Core APSIM Simulation - Checklist

## Created Files

✅ `code/00-config.R` — Central configuration hub  
✅ `code/01-simulation.R` — APSIM parallel grid simulations  
✅ `CLAUDE.md` — Development guide  
✅ `README.md` — User guide  
✅ `.gitignore` — Git ignore rules  
✅ `TESTING.md` — Detailed testing instructions  

## Phase 1 Architecture

```
code/01-simulation.R (main script)
├─ Detect environment (Windows/Linux/cloud)
├─ Load configuration (code/00-config.R)
├─ Auto-detect APSIM installation
├─ Load sim grid from data/raw/sim-grid.rds
├─ Use sample or full weather/soil data
├─ Parallel chunk processing
│  ├─ Check for checkpoint (resumable)
│  ├─ For each cell in chunk:
│  │  ├─ Load weather (.met) and soil (.rds)
│  │  ├─ Edit APSIM template with parameters
│  │  ├─ Run APSIM simulation
│  │  └─ Extract soil water results
│  └─ Save checkpoint (resume point)
└─ Output: data/processed/simulation-results.rds
```

## What Phase 1 Does

**Input:**
- APSIM template (`templates/baseline.apsimx`)
- Weather data (`data/raw/weather/` or `weather_sample/`)
- Soil profiles (`data/raw/soil/`)
- Grid metadata (`data/raw/sim-grid.rds`)

**Process:**
- Parallel APSIM simulations across grid cells
- One scenario: baseline (MG4, May 15 sowing, current climate)
- Date range: Configurable (default: current week)
- Resumable via checkpoints

**Output:**
- `data/processed/simulation-results.rds` — Full results
- `data/outputs/checkpoints/chunk_*.rds` — Per-chunk checkpoints
- `data/outputs/sim-run-log.csv` — Progress log

## Ready to Test?

### Option A: Cloud Testing (Recommended First)
Fastest way to verify Phase 1 works:

```bash
# 1. Copy this repo to cloud environment
cd /path/to/ar-weekly-weather-soil-reports

# 2. Install R packages & APSIM
apt-get install r-base
Rscript -e "install.packages(c('apsimx', 'dplyr', 'doParallel', 'foreach', 'parallel', 'data.table', 'readr'))"
apt-get install apsim

# 3. Prepare sample data (already in soybean repo)
mkdir -p data/raw/weather data/raw/soil
cp /home/user/soybean-ar-climate-change/data/raw/weather_sample/*.met data/raw/weather/
cp /home/user/soybean-ar-climate-change/data/raw/soil/*.rds data/raw/soil/  # Copy matching cell IDs

# 4. Create sim-grid.rds (see TESTING.md Step 3)

# 5. Run test
Rscript code/01-simulation.R
```

### Option B: Local Testing (Windows/Linux)
If you want to test on your machine first:

```r
# 1. Open RStudio in repo root

# 2. Install packages
install.packages(c("apsimx", "dplyr", "doParallel", "foreach", "parallel", "data.table", "readr"))

# 3. Prepare data (copy from soybean-ar-climate-change)
# See TESTING.md Steps 1-4

# 4. Edit code/00-config.R
# - Set: USE_SAMPLE_DATA <- FALSE (use full data)
# - Set: TEST_RUN <- FALSE (full run if ready)
# - Or: TEST_RUN <- TRUE (test with subset)

# 5. Run
source("code/01-simulation.R")
```

## Testing Checkpoints

### Quick Validation (~5 min)
```r
# In 00-config.R:
TEST_RUN <- TRUE
TEST_N_CELLS <- 5
USE_SAMPLE_DATA <- TRUE

# Run:
source("code/01-simulation.R")

# Check output:
file.exists("data/processed/simulation-results.rds")
nrow(readRDS("data/processed/simulation-results.rds"))  # Should be >0
```

### Full Validation (~30-60 min)
```r
# In 00-config.R:
TEST_RUN <- FALSE
USE_SAMPLE_DATA <- FALSE  # Use full data
FORCE_RERUN_SIM <- FALSE  # Resume from checkpoint

# Run:
source("code/01-simulation.R")

# Verify:
results <- readRDS("data/processed/simulation-results.rds")
nrow(results)  # Should be thousands
summary(results$swhc_6in)  # Check soil water values
```

## Success Criteria

**Phase 1 is COMPLETE when:**

- [ ] APSIM simulations run without errors
- [ ] Results saved to `data/processed/simulation-results.rds`
- [ ] Checkpoints created in `data/outputs/checkpoints/`
- [ ] Results contain columns: cellid, date, swhc_6in, swhc_12in, swhc_24in, Crop_ET, WDrainage, WRunoff, Yield_kgha
- [ ] Soil water values are realistic (e.g., 0-100 mm)
- [ ] Test mode runs in <10 minutes
- [ ] Full run (if needed) completes without crashes
- [ ] Resumability works (re-running skips completed chunks)

## Known Limitations (Phase 1)

❌ **NOT** included in Phase 1:
- No processing/aggregation of results (Phase 2)
- No report generation (Phase 3)
- No website (Phase 4)
- No scheduled automation (Phase 4)
- No historical benchmarking (Phase 2/3)

✅ **Phase 1 focuses on:** Getting APSIM simulations running reliably

## Next Steps After Phase 1

Once Phase 1 passes all checks:

1. **Phase 2:** Create `code/02-processing.R`
   - Extract soil water metrics
   - Aggregate by grid cell
   - Output CSV: `soil-water-status-YYYY-WW.csv`

2. **Phase 3:** Create `code/03-generate-report.R`
   - Render Quarto/Rmarkdown report template
   - Generate HTML: `weekly-report-YYYY-WW.html`
   - Export CSV datasets

3. **Phase 4:** Create `code/00-master.R` + Website
   - Orchestrate phases 1-3
   - Build Quarto website (`_site/`)
   - GitHub Actions automation

## Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| APSIM not found | Install APSIM or set `APSIM_EXE` in 00-config.R |
| Weather files missing | Copy to `data/raw/weather/` |
| Soil files missing | Copy to `data/raw/soil/` (matching cell IDs) |
| Grid not found | Create `data/raw/sim-grid.rds` (see TESTING.md) |
| Template not found | Copy to `templates/baseline.apsimx` |
| Simulation crashes | Reduce CHUNK_SIZE, N_CORES, or enable RUN_DIAGNOSTIC |

See `TESTING.md` for detailed troubleshooting.

## Files Structure Ready

```
ar-weekly-weather-soil-reports/
├── code/
│   ├── 00-config.R            ✅ Configuration
│   └── 01-simulation.R        ✅ APSIM grid sims
├── data/
│   ├── raw/
│   │   ├── sim-grid.rds       (📥 create)
│   │   ├── weather/           (📥 populate)
│   │   └── soil/              (📥 populate)
│   ├── processed/             ✅ (auto-created)
│   └── outputs/               ✅ (auto-created)
├── templates/
│   └── baseline.apsimx        (📥 copy)
├── README.md                  ✅
├── CLAUDE.md                  ✅
├── TESTING.md                 ✅
├── .gitignore                 ✅
└── PHASE-1-CHECKLIST.md       ✅

Legend: ✅ = Ready | 📥 = Need to populate
```

## Ready to Proceed?

**To test Phase 1:**

1. Follow steps in `TESTING.md`
2. Run `code/01-simulation.R`
3. Verify `data/processed/simulation-results.rds` created
4. Once all checks pass, signal ready for Phase 2

**Estimated Phase 1 testing time:**
- Quick test: 5-10 minutes
- Full validation: 30-60 minutes (depending on data size)

---

**Questions?** See `TESTING.md` or `CLAUDE.md`

**Ready to start testing?** Confirm and provide feedback on:
- ✅ Do you have the sample weather files available?
- ✅ Do you have the soil profile files?
- ✅ Can you create a sim-grid.rds with test cells?
- ✅ Is APSIM already installed in your cloud environment?
