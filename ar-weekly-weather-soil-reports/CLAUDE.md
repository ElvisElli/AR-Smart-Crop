# CLAUDE.md — ar-weekly-weather-soil-reports

Project instructions for Claude Code when working in this repository.

## Project Purpose

Generate automated, weekly reports on Arkansas weather conditions and soil water status for crop development monitoring. Deliver benchmarked, actionable insights to researchers and farmers by comparing current conditions to historical data, forecasting crop stress, and providing decision-support metrics.

## Quick Reference

| Setting | Value |
|---------|-------|
| **Main orchestrator** | `code/99-master.R` |
| **Configuration** | `code/00-config.R` |
| **Report output** | `data/outputs/reports/` |
| **Report templates** | `reports/*.Rmd` |
| **Expected runtime** | 10–15 minutes (full pipeline) |
| **Frequency** | Weekly (every Monday 7 AM recommended) |

## Architecture at a Glance

```
99-master.R (orchestrator)
    ├─ 01-data-fetch.R              Download current & forecast weather
    ├─ 02-data-processing.R         Clean, QA/QC, aggregate data
    ├─ 03-historical-benchmark.R    Compare to 20+ yr normals
    ├─ 04-soil-water-model.R        Calculate soil water status
    ├─ 05-forecast-processing.R     Extract crop stress signals
    └─ 06-generate-report.R         Render Quarto/Rmarkdown → HTML/CSV
```

**Intermediate outputs** (checkpoints):
- `data/processed/current-conditions.rds`
- `data/processed/historical-stats.rds`
- `data/processed/soil-water-status.rds`
- `data/processed/forecast-trends.rds`

## Running the Pipeline

### Full Pipeline (Recommended)
```r
# From RStudio or command line
source("code/99-master.R")
```
Runs all 6 steps, generates report, outputs to `data/outputs/reports/`.

### Individual Steps
```r
# Run only data fetch
source("code/01-data-fetch.R")

# Or regenerate report from existing data
source("code/06-generate-report.R")
```

### Command Line (for scheduling)
```bash
cd /path/to/ar-weekly-weather-soil-reports
Rscript code/99-master.R
```

## Configuration

**File**: `code/00-config.R`

All global settings in one place. Customize:
- Research stations and grid cells to include
- Weather API sources (IEM vs Open-Meteo)
- Soil water model parameters (AWC, bucket size)
- Historical baseline period (1995–2020 default)
- Report date and timezone

Example:
```r
# Add a new station
STATIONS <- c("Fayetteville", "Marianna", "MyNewStation")

# Change soil model
AWC_DEFAULT <- 0.25  # 25% available water capacity

# Run for a specific date
REPORT_DATE <- as.Date("2025-06-23")
```

## Data Sources

| Data | API/Source | Notes |
|------|-----------|-------|
| Current weather | IEM (NOAA) | Highly reliable, 1+ year history |
| Forecasts | Open-Meteo | Free, no API key required, 7–10 day |
| Soil properties | USDA SSURGO | Pre-processed, stored locally |
| Historical climate | NOAA / NASS | Cached locally (20+ years) |
| Station metadata | `data/raw/research-stations.csv` | Edit to add/remove stations |

## Key Files & Their Purpose

### Orchestrator
- **`code/99-master.R`** — Runs all 6 steps in sequence; this is the main entry point

### Pipeline Scripts
1. **`code/01-data-fetch.R`** — Download current weather & forecasts from APIs
2. **`code/02-data-processing.R`** — Clean, QA/QC, aggregate to uniform 5km grid
3. **`code/03-historical-benchmark.R`** — Calculate percentiles, anomalies vs. 20yr normal
4. **`code/04-soil-water-model.R`** — Bucket model: rain − ET → relative soil water (%)
5. **`code/05-forecast-processing.R`** — Extract frost risk, stress days, 7-day trends
6. **`code/06-generate-report.R`** — Render Quarto/Rmarkdown → HTML + CSV exports

### Utilities
- **`code/utils/data-utils.R`** — Common data wrangling (filter, aggregate, join)
- **`code/utils/visualization-theme.R`** — ggplot2 theme (consistent styling)
- **`code/utils/soil-utils.R`** — Soil water model functions
- **`code/utils/api-utils.R`** — API wrappers (error handling, rate limiting)

### Report Templates
- **`reports/weekly-report-template.Rmd`** — Main statewide summary
- **`reports/station-detail-template.Rmd`** — Per-station deep-dive (optional)
- **`reports/css/theme.css`** — HTML styling

## Common Tasks

### Add a New Research Station
1. Add row to `data/raw/research-stations.csv`
2. Place soil properties file at `data/raw/soil-properties/{stationid}.rds`
3. Re-run: `source("code/99-master.R")`

### Change Report Date
```r
# In 00-config.R:
REPORT_DATE <- as.Date("2025-06-23")  # Change to desired date

# Then run pipeline
source("code/99-master.R")
```

### Modify Soil Water Model
Edit `code/04-soil-water-model.R`:
- Adjust bucket capacity: `AWC_DEFAULT`
- Change model type: switch `SOIL_MODEL_TYPE`
- Add new stress indices: extend output data frame

### Add New Report Section
1. Edit `reports/weekly-report-template.Rmd`
2. Reference data from `data/processed/` RDS files
3. Add ggplot2 visualization using `visualization-theme.R`
4. Test by running `source("code/06-generate-report.R")`

### Schedule Weekly Runs (macOS/Linux)
```bash
# Edit crontab
crontab -e

# Add this line (every Monday 7 AM):
0 7 * * 1 cd /path/to/ar-weekly-weather-soil-reports && Rscript code/99-master.R >> /tmp/weekly-report.log 2>&1
```

### Schedule on GitHub Actions (Cloud)
See `schedule/github-actions-workflow.yml` — enable Actions and commit workflow file.

---

## Development Guidelines

### Code Style
- Functions: snake_case, ~40 lines max
- Variables: descriptive names (e.g., `soil_water_pct` not `sw`)
- Comments: only for "why", not "what" (code is self-documenting)
- No hardcoded paths; use relative paths from repo root

### Error Handling
```r
# Always wrap API calls
weather_data <- try(fetch_weather_from_api(...), silent = TRUE)
if (inherits(weather_data, "try-error")) {
  warning("Weather API failed; using cached data")
  weather_data <- readRDS("data/processed/cached-weather.rds")
}
```

### Dependencies
- Core: `tidyverse` (dplyr, readr, ggplot2), `data.table`
- Geospatial: `sf`, `stars` (only if grid interpolation needed)
- APIs: `httr`, `jsonlite`
- Reporting: `quarto` or `rmarkdown`
- Parallel (optional): `parallel`, `doParallel`

Use `renv::snapshot()` to track versions.

### Testing
- Unit test new functions: `test_that("function works", { ... })`
- Run full pipeline monthly with known data
- Compare outputs to previous week's report (sanity check)

---

## Performance & Scaling

### Typical Runtimes
- Data fetch: 2–3 min (API calls)
- Processing: 1 min
- Historical benchmark: 30 sec
- Soil water model: 2 min
- Report rendering: 3–5 min
- **Total: 10–15 min**

### Optimization Tips
1. Cache historical data (loaded once/week, reused)
2. Use local data directory (avoid Box Drive network latency)
3. Parallelize across stations (if adding >20 stations): use `doParallel`
4. Pre-compute station aggregates (don't recalculate grid every time)

---

## Troubleshooting

### Issue: "API rate limit exceeded"
**Fix**: Add `Sys.sleep(2)` between requests in `api-utils.R`

### Issue: Missing weather data for a station
**Fix**: Check `data/raw/research-stations.csv` coordinates; verify IEM/OpenMeteo has data for that location

### Issue: Soil water values seem unrealistic
**Fix**: Review `code/04-soil-water-model.R`; verify starting soil moisture, AWC, ET calculation

### Issue: Report rendering fails
**Fix**: 
```r
quarto::quarto_version()  # Verify quarto installed
renv::status()            # Check package versions
```

### Issue: Data pipeline hangs
**Fix**: Check if API is down: `curl https://api.open-meteo.com/v1/forecast`; if failed, pipeline will timeout gracefully and use cached data

---

## Output & Distribution

### Report Location
`data/outputs/reports/weekly-report-YYYY-WW.html`

### Datasets
CSV exports in `data/outputs/datasets/`:
- `weather-current-YYYY-WW.csv`
- `soil-water-YYYY-WW.csv`
- `forecast-YYYY-WW.csv`
- `historical-normals-by-station.csv`

### Sharing
- Email HTML report link directly
- Host on web server (static site)
- Embed in dashboard (iframe)
- Post CSV datasets to shared drive for download

---

## Git Workflow

```bash
# Feature branch (e.g., add new metric)
git checkout -b add-fire-weather-index
# ... make changes ...
git add code/ reports/
git commit -m "Add fire weather index to soil water report"
git push -u origin add-fire-weather-index
# Create pull request on GitHub

# Main branch (always deployable)
# Pull request reviewed, merged to main
# GitHub Actions auto-runs pipeline, posts report
```

---

## Paper / Manuscript Integration

Reports generated by this pipeline can feed into research publications:
- Archival CSV datasets in `data/outputs/datasets/` for reproducibility
- Visualization code in `reports/` for supplement figures
- Station-level data for regional studies

---

## Environment Auto-Detection

Scripts auto-detect platform:

| Platform | Behavior |
|----------|----------|
| Windows | Uses local temp dir `C:/temp/apsim-proc` (if APSIM integration added) |
| Linux/Cloud | Uses `/tmp/` for temporary files |

No manual config needed; all paths are relative.

---

## Contact & Questions

**Project Lead**: eelli@uark.edu  
**Last Updated**: 2025-06-26

For Claude Code assistance: see /help or check inline documentation in `code/` scripts.
