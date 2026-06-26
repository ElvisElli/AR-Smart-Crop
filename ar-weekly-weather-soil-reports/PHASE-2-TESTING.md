# Phase 2 Testing Guide — Data Processing

## Objective

Verify that Phase 2 data processing correctly:
- Loads Phase 1 APSIM results
- Extracts soil water holding capacity (SWHC) metrics
- Aggregates by grid cell and calculates statistics
- Outputs properly formatted CSV for downstream use

## Prerequisites

✅ Phase 1 simulation completed successfully
- `data/processed/simulation-results.rds` exists
- Contains columns: cellid, date, swhc_6in, swhc_12in, swhc_24in

## Step-by-Step Testing

### Step 1: Verify Phase 1 Output

```r
# Check Phase 1 results exist and have expected structure
results <- readRDS("data/processed/simulation-results.rds")
head(results)
cat("Dimensions:", nrow(results), "rows ×", ncol(results), "cols\n")
cat("Columns:", names(results), "\n")
```

Expected:
- 100+ rows (one per cell per day)
- Columns include: cellid, date, swhc_6in, swhc_12in, swhc_24in
- Date range: typically 7 days (one week)

### Step 2: Run Phase 2 Processing

```bash
# From project root:
Rscript code/02-processing.R

# Or in RStudio:
source("code/02-processing.R")
```

Expected output:
```
[HH:MM:SS] Phase 2: Data Processing started

[INPUT] Loading Phase 1 results: data/processed/simulation-results.rds
[INPUT] Loaded: XXX rows × 15 columns

[HH:MM:SS] Extracting soil water metrics
[PROCESS] Aggregated: 100 cells
[STATS] Soil water range (6in): X.X–XX.X mm

[HH:MM:SS] Writing output: data/outputs/soil-water-status-YYYY-WXX.csv
[OUTPUT] ✓ Saved: data/outputs/soil-water-status-YYYY-WXX.csv
[OUTPUT] Rows: 100 cells
[OUTPUT] Columns: 19

======================================================================
PHASE 2: DATA PROCESSING COMPLETE
======================================================================
```

### Step 3: Verify CSV Output

```r
# Load and inspect the CSV
csv_data <- read_csv("data/outputs/soil-water-status-2025-W26.csv")
head(csv_data)

# Check structure
cat("Dimensions:", nrow(csv_data), "cells ×", ncol(csv_data), "columns\n")
cat("Columns:", names(csv_data), "\n")

# Check for missing values
colSums(is.na(csv_data))

# Check data ranges
summary(csv_data[, c("swhc_6in_mean", "swhc_12in_mean", "swhc_24in_mean")])
```

Expected:
- **Dimensions:** 100 rows (one per cell) × 19 columns
- **Columns:** 
  - Identifiers: year, week, week_start, week_end, cellid, x, y, n_days
  - 6-inch depth: swhc_6in_mean, swhc_6in_min, swhc_6in_max
  - 12-inch depth: swhc_12in_mean, swhc_12in_min, swhc_12in_max
  - 24-inch depth: swhc_24in_mean, swhc_24in_min, swhc_24in_max
- **No missing values** in aggregated metrics
- **Realistic ranges:**
  - swhc_6in: typically 0–50 mm (shallower = less water held)
  - swhc_12in: typically 0–100 mm
  - swhc_24in: typically 0–150 mm
- **Temporal consistency:**
  - n_days should be 5–7 (one week of simulation)
  - week_start and week_end should span one calendar week

### Step 4: Validate Metrics

```r
# Check that min ≤ mean ≤ max for each depth
check_mins <- csv_data$swhc_6in_min <= csv_data$swhc_6in_mean
check_maxs <- csv_data$swhc_6in_mean <= csv_data$swhc_6in_max

cat("6in metrics valid:", all(check_mins & check_maxs), "\n")

# Check that shallower depths generally hold less water
mean_6in  <- mean(csv_data$swhc_6in_mean, na.rm = TRUE)
mean_12in <- mean(csv_data$swhc_12in_mean, na.rm = TRUE)
mean_24in <- mean(csv_data$swhc_24in_mean, na.rm = TRUE)

cat("Depth progression (should increase):\n")
cat(sprintf("  6in:  %.1f mm\n", mean_6in))
cat(sprintf("  12in: %.1f mm\n", mean_12in))
cat(sprintf("  24in: %.1f mm\n", mean_24in))
```

Expected: 6in ≤ 12in ≤ 24in (deeper soil holds more water)

### Step 5: Spot-Check Individual Cells

```r
# Look at a few cells in detail
cell_ids <- unique(csv_data$cellid)[1:3]
for (cid in cell_ids) {
  cell_row <- csv_data %>% filter(cellid == cid)
  cat(sprintf("\nCell %d (%.2f, %.2f):\n", cid, cell_row$x, cell_row$y))
  cat(sprintf("  6in:  mean=%.1f, min=%.1f, max=%.1f (range=%.1f)\n",
              cell_row$swhc_6in_mean, cell_row$swhc_6in_min, cell_row$swhc_6in_max,
              cell_row$swhc_6in_max - cell_row$swhc_6in_min))
  cat(sprintf("  Days simulated: %d\n", cell_row$n_days))
}
```

### Step 6: Test Re-running Phase 2

```r
# Run Phase 2 again (should overwrite existing CSV)
source("code/02-processing.R")

# Verify file was updated
file.info("data/outputs/soil-water-status-2025-W26.csv")$mtime
```

## Troubleshooting

### Issue: "Phase 1 results not found"

**Solution:**
1. Run Phase 1 first: `source("code/01-simulation.R")`
2. Verify file exists: `file.exists("data/processed/simulation-results.rds")`
3. Check file is not empty: `file.size("data/processed/simulation-results.rds")`

### Issue: "Missing required columns"

**Solution:**
1. Verify Phase 1 results were generated correctly
2. Check column names: `names(readRDS("data/processed/simulation-results.rds"))`
3. May indicate Phase 1 failed to extract results (check error log)

### Issue: "No rows in output"

**Solution:**
1. Check Phase 1 had successful simulations
2. Verify cells with valid data: `nrow(readRDS("data/processed/simulation-results.rds"))`
3. Run Phase 1 in full mode (not test mode) if needed

### Issue: CSV missing columns or has NaN values

**Solution:**
1. Check for Phase 1 simulation errors (some cells may have failed)
2. Verify APSIM results include all required variables
3. Check date ranges in Phase 1 output

## Success Criteria

Phase 2 testing is **SUCCESSFUL** if all of the following pass:

✅ Phase 2 script runs without errors  
✅ CSV file created at `data/outputs/soil-water-status-YYYY-WXX.csv`  
✅ CSV has correct structure:
  - 100 rows (one per cell)
  - 19 columns with proper headers
  - No missing values in metric columns
✅ Soil water metrics are realistic:
  - 6in: 0–50 mm range typically
  - 12in: 0–100 mm range typically
  - 24in: 0–150 mm range typically
✅ Depth progression correct: 6in ≤ 12in ≤ 24in (on average)  
✅ Statistics valid: min ≤ mean ≤ max for each metric  
✅ Date columns correctly formatted (ISO format YYYY-MM-DD)  
✅ Re-running Phase 2 updates the output file  

## Next: Phase 3 Testing

Once Phase 2 passes all checks, proceed to Phase 3 (Report Generation):

```r
# Create report template first (Phase 3 setup)
# Then run: source("code/03-generate-report.R")
```

---

**Questions?** Check inline comments in `code/02-processing.R` or see `CLAUDE.md`

