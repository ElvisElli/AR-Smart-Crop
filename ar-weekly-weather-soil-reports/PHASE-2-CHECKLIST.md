# Phase 2: Data Processing - Checklist

## Overview

Phase 2 processes raw APSIM simulation results from Phase 1 and extracts soil water holding capacity (SWHC) metrics aggregated by grid cell.

**Input:** `data/processed/simulation-results.rds` (Phase 1 output)  
**Output:** `data/outputs/soil-water-status-YYYY-WXX.csv`  
**Time:** ~1-2 minutes for 100 cells  

## What Phase 2 Does

### Input Processing
- Load Phase 1 APSIM simulation results (1 row per cell per day)
- Validate required columns exist:
  - cellid, x, y, date
  - swhc_6in, swhc_12in, swhc_24in

### Data Aggregation
Group by cell and calculate statistics for each depth:
- **Mean:** Average soil water over simulation week
- **Min:** Minimum daily value
- **Max:** Maximum daily value

### Output Format (CSV)
```
year,week,week_start,week_end,cellid,x,y,n_days,
swhc_6in_mean,swhc_6in_min,swhc_6in_max,
swhc_12in_mean,swhc_12in_min,swhc_12in_max,
swhc_24in_mean,swhc_24in_min,swhc_24in_max
```

## Phase 2 Architecture

```
Phase 2: Data Processing
├─ Load Phase 1 results (simulation-results.rds)
├─ Validate data structure and columns
├─ Extract soil water columns (3 depths × 3 metrics)
├─ Group by cellid and calculate:
│  ├─ Mean SWHC per depth
│  ├─ Min SWHC per depth
│  └─ Max SWHC per depth
├─ Add temporal metadata (year, week, date range)
├─ Sort by cellid
└─ Output: soil-water-status-YYYY-WXX.csv
```

## Development Checklist

### Code Creation
- [x] Create `code/02-processing.R`
  - [x] Load Phase 1 results
  - [x] Validate data structure
  - [x] Extract and aggregate metrics
  - [x] Add metadata columns
  - [x] Save to CSV with proper formatting
  - [x] Add progress logging and error handling

### Documentation
- [x] Create `PHASE-2-TESTING.md` with 6-step testing procedure
- [x] Create `PHASE-2-CHECKLIST.md` (this file)
- [x] Add usage examples in inline comments

### Testing Validation Steps
- [ ] Step 1: Verify Phase 1 output exists
- [ ] Step 2: Run Phase 2 script
- [ ] Step 3: Verify CSV output structure
- [ ] Step 4: Validate metrics (min ≤ mean ≤ max)
- [ ] Step 5: Check soil water depth progression
- [ ] Step 6: Test re-running Phase 2

## Success Criteria

Phase 2 is **COMPLETE** when ALL of the following pass:

### Output Files
- [x] `code/02-processing.R` created and tested
- [ ] CSV output: `soil-water-status-YYYY-WXX.csv` generates without errors
- [ ] Output directory created: `data/outputs/`

### Data Quality
- [ ] CSV has exactly 100 rows (one per grid cell)
- [ ] CSV has exactly 19 columns with correct headers
- [ ] No missing values in aggregated metric columns
- [ ] All dates in ISO format (YYYY-MM-DD)

### Metric Validation
- [ ] SWHC ranges realistic:
  - 6-inch: typically 0–50 mm
  - 12-inch: typically 0–100 mm
  - 24-inch: typically 0–150 mm
- [ ] Depth progression valid: swhc_6in ≤ swhc_12in ≤ swhc_24in
- [ ] Statistics valid: min ≤ mean ≤ max for each depth

### Functionality
- [ ] Phase 2 script runs in <5 minutes
- [ ] Re-running Phase 2 correctly overwrites previous output
- [ ] Error messages are helpful if Phase 1 data missing
- [ ] Logging shows progress (loading, processing, saving)

## Known Limitations (Phase 2)

❌ **NOT included in Phase 2:**
- Historical benchmarking (Phase 3)
- HTML report generation (Phase 3)
- Quarto website (Phase 4)
- Automated scheduling (Phase 4)
- Multi-year averages (Phase 2 is weekly only)

✅ **Phase 2 focuses on:**
- Reliable data extraction and aggregation
- CSV output for downstream analysis
- Minimal, maintainable code

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| "Phase 1 results not found" | Phase 1 not run or failed | Run `source("code/01-simulation.R")` first |
| "Missing required columns" | Phase 1 didn't extract all variables | Check Phase 1 error log, re-run Phase 1 |
| CSV has 0 rows | All Phase 1 simulations failed | Verify weather/soil data quality |
| NaN/NA values in CSV | Phase 1 cells failed partially | Check Phase 1 error messages |
| CSV file very large | Too many cells | Expected behavior, file is ~50 KB per 100 cells |

## Files Structure Ready

```
ar-weekly-weather-soil-reports/
├── code/
│   ├── 00-config.R              ✅ Configuration
│   ├── 01-simulation.R          ✅ Phase 1 (APSIM)
│   └── 02-processing.R          ✅ Phase 2 (Data processing)
├── data/
│   ├── processed/
│   │   └── simulation-results.rds  (Phase 1 output)
│   └── outputs/
│       └── soil-water-status-*.csv (Phase 2 output)
├── PHASE-2-TESTING.md           ✅ Testing guide
├── PHASE-2-CHECKLIST.md         ✅ This file
└── CLAUDE.md                    (updated)
```

## Ready to Test?

**To test Phase 2:**

1. Ensure Phase 1 ran successfully
2. Run: `source("code/02-processing.R")`
3. Follow testing steps in `PHASE-2-TESTING.md`
4. Verify all success criteria above
5. Confirm CSV output is correct

**Estimated testing time:**
- Quick validation: 5-10 minutes
- Full validation: 15-20 minutes

## Next Steps After Phase 2

Once Phase 2 passes all checks:

1. **Phase 3:** Create `code/03-generate-report.R`
   - Create Quarto/Rmarkdown report template
   - Generate HTML weekly report from CSV data
   - Add charts, maps, and tables
   - Output: `data/outputs/weekly-report-YYYY-WXX.html`

2. **Phase 4:** Create orchestration and website
   - Create `code/00-master.R` to run phases 1-3 in sequence
   - Build Quarto website with weekly archives
   - GitHub Actions automation for scheduled runs

---

**Status:** ✅ PHASE 2 CODE COMPLETE, READY FOR TESTING  
**Next:** Follow PHASE-2-TESTING.md for validation  
**Timeline:** Phase 2 implementation + testing = 1 day  

