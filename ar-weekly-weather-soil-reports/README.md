# Arkansas Weekly Weather & Soil Water Reports

**Automated intelligence platform for crop development monitoring**

Generate comprehensive, weekly reports on Arkansas weather conditions and soil water status for research stations. Benchmarked against historical data, with weather forecasts and actionable crop development insights for researchers and farmers.

## Quick Start

```r
# From RStudio: Run the master orchestrator
source("code/99-master.R")

# Or from command line:
Rscript code/99-master.R
```

**Output**: HTML reports in `data/outputs/reports/` ready for distribution.

---

## Features

- ✅ **Automated Weekly Reports** — Run on schedule or manually; fully resumable
- 📊 **Historical Benchmarking** — Compare current conditions to 20+ year normals by station
- 💧 **Soil Water Modeling** — Relative soil water status across the state with precision
- 🌦️ **Weather Forecasts** — 7-10 day forecasts for research stations (Open-Meteo API)
- 📍 **Multi-Station Coverage** — 10+ Arkansas research stations + statewide grid (5km cells)
- 📈 **Publication-Quality Visuals** — Consistent theme, ready for web/print distribution
- 🔄 **Resumable Pipeline** — Checkpoints allow recovery from failures
- 📱 **Web-Ready Output** — HTML reports, embedded visualizations, CSV data exports

---

## Architecture

### Data Pipeline

```
┌─────────────────────────────────┐
│   Input: Weather APIs + Soil DB │
└────────────┬────────────────────┘
             │
        ┌────▼─────────────────┐
        │ 01-data-fetch.R      │  Download current/forecast weather
        │ (IEM, Open-Meteo)    │  Retrieve soil properties
        └────┬─────────────────┘
             │
        ┌────▼──────────────────────────┐
        │ 02-data-processing.R          │  Clean, interpolate, aggregate
        │ (Quality control)             │  Harmonize station/grid data
        └────┬──────────────────────────┘
             │
      ┌──────┼──────┐
      │      │      │
   ┌──▼──┐ ┌─▼──┐ ┌─▼──────────────────┐
   │ 03  │ │ 04 │ │ 05-forecast        │
   │ Hist│ │Soil│ │ (7-10 day trends)  │
   └──┬──┘ └─┬──┘ └────┬───────────────┘
      │      │         │
      └──────┴────┬────┘
                  │
            ┌─────▼──────────────────┐
            │ 06-generate-report.R   │  Render Quarto/Rmarkdown
            │ (Render templates)     │  Embed plots & tables
            └─────┬──────────────────┘
                  │
            ┌─────▼──────────┐
            │ Output Reports │
            │ HTML / CSV     │
            └────────────────┘
```

### File Organization

| Directory | Purpose |
|-----------|---------|
| `code/` | R pipeline scripts (numbered 01-99) |
| `code/utils/` | Reusable functions (theme, data utilities) |
| `data/raw/` | Static reference data (station metadata, soil) |
| `data/processed/` | Intermediate RDS files (checkpoints) |
| `data/outputs/reports/` | Generated HTML reports |
| `data/outputs/datasets/` | CSV exports for download |
| `reports/` | Quarto/Rmarkdown templates |
| `schedule/` | Automation (cron, GitHub Actions) |

---

## Configuration

**File**: `code/00-config.R`

All parameters in one place:

```r
# Research stations
STATIONS <- c("Fayetteville", "Marianna", "Pine Bluff", "Rohwer", "Hope")

# Weather API sources
WEATHER_API <- "iemaps"  # or "openmeteo"
FORECAST_API <- "openmeteo"

# Soil water model
SOIL_MODEL_TYPE <- "bucket"  # simple bucket model
AWC_DEFAULT <- 0.20  # Available Water Capacity (20%)

# Historical baseline period
BASELINE_START <- 1995
BASELINE_END <- 2020

# Report generation
REPORT_DATE <- Sys.Date()
REPORT_TIMEZONE <- "America/Chicago"
```

---

## Workflow: Step by Step

### 1. Data Fetch (`01-data-fetch.R`)
Retrieves weather and soil data for current day and next 7 days:
- **Current weather**: IEM/OpenMeteo API → `.met` format
- **Soil properties**: Database lookup by station/grid cell
- **Forecasts**: 7-10 day models from weather APIs

Output: `data/processed/raw-weather.rds`, `data/processed/raw-forecasts.rds`

### 2. Data Processing (`02-data-processing.R`)
Cleans and harmonizes data:
- QA/QC checks (remove outliers, fill gaps)
- Interpolate to uniform grid (5km)
- Aggregate by station (inverse-distance weighted)
- Calculate daily metrics (GDD, rainfall, radiation)

Output: `data/processed/current-conditions.rds`

### 3. Historical Benchmark (`03-historical-benchmark.R`)
Compares to normal conditions:
- Retrieve 20+ year daily climatology (1995–2020)
- Calculate percentiles for current week
- Identify anomalies (above/below normal)
- Rank current conditions among historical extremes

Output: `data/processed/historical-stats.rds`

### 4. Soil Water Modeling (`04-soil-water-model.R`)
Calculates relative soil water status:
- Bucket model: Track water balance (rain − ET)
- Inputs: Precipitation, ET (from temp, humidity, radiation)
- Outputs: Relative soil water (%), stress index (0–1)
- Per-cell and per-station aggregates

Output: `data/processed/soil-water-status.rds`

### 5. Forecast Processing (`05-forecast-processing.R`)
Extracts useful crop development signals:
- 7-day temperature trends
- Precipitation probability
- Frost risk dates
- Stress-day projections

Output: `data/processed/forecast-trends.rds`

### 6. Report Generation (`06-generate-report.R`)
Renders final reports from templates:
- Weekly summary (statewide overview)
- Per-station detail pages
- Downloadable CSV datasets

Output: `data/outputs/reports/weekly-report-YYYY-WW.html` + CSV

---

## Running the Pipeline

### Manual Execution
```r
# Full pipeline (all steps)
source("code/99-master.R")

# Or individual steps
source("code/01-data-fetch.R")
source("code/02-data-processing.R")
source("code/03-historical-benchmark.R")
source("code/04-soil-water-model.R")
source("code/05-forecast-processing.R")
source("code/06-generate-report.R")
```

### Automated Scheduling

**macOS/Linux** — Add to crontab:
```bash
# Run every Monday at 7 AM
0 7 * * 1 cd /path/to/repo && Rscript code/99-master.R
```

**Windows** — Use Task Scheduler or GitHub Actions (see `schedule/`)

**GitHub Actions** — Commit and push; workflow runs weekly + on-demand:
```bash
gh workflow run weekly-report.yml
```

---

## Output Files

### Reports
- `data/outputs/reports/weekly-report-2025-W26.html` — Interactive HTML
- Embedded visualizations, tables, download links
- Mobile-responsive design

### Datasets
- `data/outputs/datasets/weather-current-YYYY-WW.csv`
- `data/outputs/datasets/soil-water-YYYY-WW.csv`
- `data/outputs/datasets/forecast-YYYY-WW.csv`

### Benchmarks
- `data/outputs/datasets/historical-normals-by-station.csv`
- `data/outputs/datasets/historical-percentiles-YYYY-WW.csv`

---

## Data Sources

| Data | Source | Format | Update Freq |
|------|--------|--------|------------|
| Current Weather | IEM / NOAA | CSV/JSON API | Daily (auto-updated) |
| Forecasts | Open-Meteo | JSON API | Daily |
| Soil Properties | USDA SSURGO | RDS database | Annual |
| Historical Climate | NOAA / NASS | CSV | Fixed (1995–2024) |

---

## Report Sections

Each weekly report includes:

### 1. **Statewide Summary**
- Temperature (avg, high, low)
- Precipitation (total, % of normal)
- Soil water status (map)
- Week-over-week anomalies

### 2. **Station Deep-Dives** (10+ stations)
- 7-day historical comparison
- Current soil water (bucket model)
- Forecast (7-day outlook)
- Crop development index (GDD)
- Risk alerts (frost, drought stress)

### 3. **Benchmark Analysis**
- Percentile ranking of this week's temps/precip
- Historical extremes (hottest, wettest, driest)
- How this year compares to climatology

### 4. **Forecast Trends**
- 7-10 day outlook (temp, rain, frost risk)
- Actionable crop management alerts

### 5. **Data Downloads**
- CSV exports (weather, soil water, forecasts)
- Ready for analysis tools or databases

---

## Customization

### Add a New Research Station

1. Edit `data/raw/research-stations.csv`:
```csv
name,latitude,longitude,state,elevation_m
MyStation,34.2,-92.5,AR,150
```

2. Add soil properties to `data/raw/soil-properties/mystationid.rds`

3. Re-run pipeline:
```r
source("code/99-master.R")
```

### Change Report Layout

Edit report templates in `reports/`:
- `weekly-report-template.Rmd` — Main report structure
- `station-detail-template.Rmd` — Per-station page
- `reports/css/theme.css` — Styling

### Add New Metrics

Example: Add "Fire Weather Index" to soil water output

1. Edit `code/04-soil-water-model.R` — Add calculation
2. Edit `reports/weekly-report-template.Rmd` — Add visualization
3. Re-run pipeline

---

## Performance & Scaling

| Component | Typical Runtime | Bottleneck |
|-----------|-----------------|-----------|
| Data fetch (5 stations, 10 grid cells) | 2–3 min | API rate limits (add delays) |
| Processing (data clean, QA/QC) | 1 min | Data size (optimize filters) |
| Benchmark calculation | 30 sec | Historical file I/O |
| Soil water model | 2 min | Vectorization (use data.table) |
| Report rendering | 3–5 min | Quarto/Rmarkdown overhead |
| **Total** | **10–15 min** | — |

**Optimization tips:**
- Cache historical data (loaded once per week)
- Use local data directory instead of Box (Box sync delay ~30s)
- Parallelize across stations (4 cores = 50% faster)

---

## Troubleshooting

### API Rate Limits
```r
# Add delay between requests (in api-utils.R)
Sys.sleep(2)
```

### Missing Weather Data
- Check station coordinates in `research-stations.csv`
- Verify IEM/OpenMeteo availability for that location
- Fall back to nearest available station

### Soil Water Calculations Off
- Review `code/04-soil-water-model.R` — verify AWC, starting moisture
- Compare to NASS/USDA soil survey data
- Adjust model parameters in `code/00-config.R`

### Report Rendering Fails
- Check Quarto/Rmarkdown installation: `quarto check`
- Verify all data files exist in `data/processed/`
- Check R package dependencies: `renv::status()`

---

## Development & Contributing

See `CLAUDE.md` for project guidelines, branch strategy, and contribution workflow.

---

## License & Citation

**Project**: Arkansas Weekly Weather & Soil Water Reports  
**Purpose**: Research & farmer decision support  
**Contact**: eelli@uark.edu

---

## Next Steps

1. **Clone/download this repo**
2. **Install dependencies**: `renv::restore()`
3. **Configure stations**: Edit `data/raw/research-stations.csv`
4. **Run pipeline**: `source("code/99-master.R")`
5. **Schedule automation**: See `schedule/` for cron/GitHub Actions setup

Questions? See `CLAUDE.md` or check `code/` inline documentation.
