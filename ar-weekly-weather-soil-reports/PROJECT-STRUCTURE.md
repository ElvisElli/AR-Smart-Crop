# Project Structure: AR Weekly Weather & Soil Water Reports

Complete directory organization and file descriptions.

---

## Directory Tree

```
ar-weekly-weather-soil-reports/
│
├── README.md                              # Project overview & quick start
├── CLAUDE.md                              # Instructions for Claude Code
├── PROJECT-STRUCTURE.md                   # This file
├── .gitignore                             # Git ignore rules
│
├── _quarto.yml                            # Quarto website configuration
├── index.qmd                              # Website homepage
│
├── code/                                  # R pipeline scripts
│   ├── 00-config.R                        # Global configuration (edit this!)
│   ├── 01-data-fetch.R                    # Fetch weather & soil data
│   ├── 02-data-processing.R               # QA/QC & aggregation
│   ├── 03-historical-benchmark.R          # Calculate historical stats
│   ├── 04-soil-water-model.R              # Soil water modeling
│   ├── 05-forecast-processing.R           # Forecast signal extraction
│   ├── 06-generate-report.R               # Render reports
│   ├── 99-master.R                        # Orchestrator (run this!)
│   │
│   └── utils/                             # Reusable utility functions
│       ├── api-utils.R                    # Weather API wrappers
│       ├── data-utils.R                   # Data wrangling
│       ├── soil-utils.R                   # Soil water functions
│       └── visualization-theme.R          # ggplot2 theme
│
├── reports/                               # Quarto/Rmarkdown templates
│   ├── index.qmd                          # Reports landing page
│   ├── current-report.qmd                 # This week's report (template)
│   ├── archive.qmd                        # Report archive page
│   ├── weekly-report-template.qmd         # Main report (auto-populated)
│   ├── station-detail-template.qmd        # Per-station detail (optional)
│   │
│   └── css/
│       └── theme.css                      # Report styling
│
├── data/                                  # Data storage
│   │
│   ├── raw/                               # Static input data (not auto-generated)
│   │   ├── research-stations.csv          # Station metadata (EDIT THIS)
│   │   ├── historical-weather/            # 30-year climate data (not in git)
│   │   └── soil-properties/               # Soil profiles by station (not in git)
│   │
│   ├── processed/                         # Intermediate outputs (checkpoints)
│   │   ├── raw-weather.rds                # Downloaded weather data
│   │   ├── raw-forecasts.rds              # Downloaded forecasts
│   │   ├── current-conditions.rds         # Processed & aggregated
│   │   ├── historical-stats.rds           # Benchmark calculations
│   │   ├── soil-water-status.rds          # Soil water model output
│   │   ├── forecast-trends.rds            # Forecast signals
│   │   └── soil-properties.rds            # Soil metadata
│   │
│   ├── cache/                             # API response cache
│   │   └── [auto-generated]
│   │
│   ├── logs/                              # Pipeline logs
│   │   └── pipeline.log
│   │
│   └── outputs/                           # Final deliverables
│       ├── reports/                       # Generated HTML/PDF reports
│       │   └── weekly-report-YYYY-WW.html
│       └── datasets/                      # CSV exports
│           ├── weather-current-YYYY-WW.csv
│           ├── soil-water-YYYY-WW.csv
│           └── forecast-YYYY-WW.csv
│
├── schedule/                              # Automation configuration
│   ├── github-actions-workflow.yml        # CI/CD for cloud scheduling
│   ├── run-weekly-report.sh               # Bash script (local cron)
│   └── windows-task-scheduler.xml         # Windows Task Scheduler config
│
├── assets/                                # Website static assets
│   ├── logo.png                           # Lab logo
│   ├── favicon.ico
│   └── custom.css                         # Website styling
│
├── .claude/                               # Claude Code settings
│   └── settings.json
│
└── .github/                               # GitHub-specific config
    └── workflows/
        └── weekly-report.yml              # (symlink to schedule/)
```

---

## File Descriptions

### Root Level

| File | Purpose |
|------|---------|
| `README.md` | Quick start guide, feature overview, troubleshooting |
| `CLAUDE.md` | Project instructions for Claude Code (development) |
| `PROJECT-STRUCTURE.md` | This file — detailed directory reference |
| `.gitignore` | Excludes large data files, outputs, logs from git |
| `_quarto.yml` | Quarto website configuration (navbar, layout, theme) |
| `index.qmd` | Homepage (features, latest report, how-to guide) |

### Code Scripts (`code/`)

#### Main Pipeline

| Script | Purpose | Input | Output |
|--------|---------|-------|--------|
| `00-config.R` | Configuration hub — edit for customization | N/A | Console output |
| `01-data-fetch.R` | Fetch weather, forecasts, soil data from APIs | APIs, config | `raw-*.rds` |
| `02-data-processing.R` | QA/QC, interpolation, aggregation | `raw-*.rds` | `current-conditions.rds` |
| `03-historical-benchmark.R` | Compare to 20+ year normals | Processed + historical | `historical-stats.rds` |
| `04-soil-water-model.R` | Bucket model for soil water | Conditions + soil props | `soil-water-status.rds` |
| `05-forecast-processing.R` | Extract crop stress signals | `raw-forecasts.rds` | `forecast-trends.rds` |
| `06-generate-report.R` | Render Quarto/Rmarkdown → HTML/CSV | All processed data | HTML + CSV files |
| `99-master.R` | Orchestrator (runs 01–06 in sequence) | N/A | Complete report |

#### Utilities (`code/utils/`)

| File | Functions |
|------|-----------|
| `api-utils.R` | `fetch_weather_iem()`, `fetch_weather_openmeteo()`, `fetch_forecast_openmeteo()`, retry/validation helpers |
| `data-utils.R` | Common data wrangling: filtering, aggregation, joins, summarization |
| `soil-utils.R` | Soil water model: bucket dynamics, ET calculation, stress indicators |
| `visualization-theme.R` | `theme_ar_weather()`, color palettes, consistent ggplot styling |

### Reports (`reports/`)

| File | Purpose |
|------|---------|
| `index.qmd` | Reports landing page with navigation |
| `current-report.qmd` | Link to latest report (auto-updated) |
| `archive.qmd` | Browse all past reports |
| `weekly-report-template.qmd` | Main report template (populated by R script) |
| `station-detail-template.qmd` | Per-station detailed analysis (optional) |
| `css/theme.css` | HTML report styling |

### Data Directories

#### `data/raw/` (Input, mostly static)
- `research-stations.csv` — **EDIT THIS:** Add/remove stations, update metadata
- `historical-weather/` — 30 years of daily data (not in git; ~500 MB)
- `soil-properties/` — RDS files per station with soil profiles

#### `data/processed/` (Auto-generated checkpoints)
Generated during pipeline execution; can be deleted and regenerated.

#### `data/outputs/` (Final deliverables)
- `reports/` — HTML reports ready for distribution
- `datasets/` — CSV files for download by users

### Quarto Website

| File | Purpose |
|------|---------|
| `_quarto.yml` | Website config (navbar, theme, layout) |
| `index.qmd` | Homepage |
| `reports/index.qmd` | Reports section landing page |
| `reports/current-report.qmd` | Link to this week's report |
| `reports/archive.qmd` | Past reports browsable list |
| `lab-updates.qmd` | Lab news, research projects, updates |
| `data-downloads.qmd` | CSV downloads, data dictionary, usage guide |

### Scheduling & Automation (`schedule/`)

| File | Purpose |
|------|---------|
| `github-actions-workflow.yml` | Cloud automation: runs every Monday 7 AM, deploys to GitHub Pages |
| `run-weekly-report.sh` | Local cron script for Linux/macOS |
| `windows-task-scheduler.xml` | Windows Task Scheduler config |

---

## Configuration Points

### 1. Edit `code/00-config.R` to Customize:

```r
# Stations to include
STATIONS <- c("Fayetteville", "Marianna", "Pine Bluff", "Rohwer", "Hope")

# Weather APIs to use
WEATHER_API <- "iemaps"  # or "openmeteo"
FORECAST_API <- "openmeteo"

# Soil model parameters
AWC_DEFAULT <- 0.20
STRESS_THRESHOLD <- 0.5

# Historical baseline period
BASELINE_START <- 1995
BASELINE_END <- 2020

# Report options
BUILD_QUARTO_WEBSITE <- TRUE
PUBLISH_TO_GITHUB_PAGES <- FALSE
```

### 2. Edit `data/raw/research-stations.csv` to Add Stations:

```csv
name,station_id,latitude,longitude,elevation_m,state,county,established,active
MyNewStation,MNS,34.5,-92.5,100,AR,MyCounty,2025,TRUE
```

### 3. Edit `_quarto.yml` for Website:

```yaml
website:
  title: "Your Lab Name - Weather Reports"
  site-url: "https://your-lab.uark.edu/weather-reports"
  navbar:
    logo: "assets/logo.png"
```

---

## Data Flow Diagram

```
APIs (Open-Meteo, IEM) + Local Data
        ↓
    01-data-fetch.R
        ↓ [raw-*.rds]
    02-data-processing.R
        ↓ [current-conditions.rds]
        ├─→ 03-historical-benchmark.R
        │       ↓ [historical-stats.rds]
        ├─→ 04-soil-water-model.R
        │       ↓ [soil-water-status.rds]
        └─→ 05-forecast-processing.R
                ↓ [forecast-trends.rds]
    06-generate-report.R
        ↓
    Reports (HTML) + Datasets (CSV)
        ↓
    Quarto Website (_site/)
        ↓
    GitHub Pages (optional)
```

---

## Typical Runtime

| Step | Runtime | Bottleneck |
|------|---------|-----------|
| 01: Data Fetch | 2–3 min | API calls + rate limiting |
| 02: Processing | 1 min | Data size & complexity |
| 03: Benchmark | 30 sec | Historical file I/O |
| 04: Soil Water | 2 min | Vectorization overhead |
| 05: Forecast | 1 min | Calculation |
| 06: Report | 3–5 min | Quarto rendering |
| **Total** | **10–15 min** | |

---

## Git Workflow

### Tracked Files (commit to repo)
- All R scripts (`code/`)
- Report templates (`reports/`)
- Configuration files (`_quarto.yml`, `.gitignore`)
- Documentation (`README.md`, `CLAUDE.md`)
- Website Quarto files (`*.qmd` at root level)

### Ignored Files (NOT tracked; re-generated each run)
- Data outputs (`data/outputs/`, `data/processed/`)
- Downloaded data (`data/raw/historical-weather/`)
- Quarto build artifacts (`_site/`, `_quarto/`)
- Logs (`data/logs/`)
- Cache (`data/cache/`)

---

## Extensibility

### Adding a New Metric
1. Edit `code/04-soil-water-model.R` — Add calculation
2. Edit `code/06-generate-report.R` — Export to CSV
3. Edit `reports/weekly-report-template.qmd` — Visualize in report

### Adding a New Station
1. Edit `data/raw/research-stations.csv` — Add row
2. Place soil file at `data/raw/soil-properties/{id}.rds`
3. Re-run: `source("code/99-master.R")`

### Custom Report Section
1. Edit `reports/weekly-report-template.qmd`
2. Add R code to load data from `data/processed/`
3. Create visualization
4. Re-render

---

## Version History

| Date | Change |
|------|--------|
| 2025-06-26 | Initial repository structure created |
| (Future) | API integrations completed |
| (Future) | Historical data loaded |
| (Future) | First live report generated |

---

## Next Steps

1. **Clone repo** and install dependencies: `renv::restore()`
2. **Edit `code/00-config.R`** — Customize stations, APIs, model parameters
3. **Prepare soil data** — Place RDS files in `data/raw/soil-properties/`
4. **Run pilot test** — `source("code/99-master.R")` 
5. **Customize reports** — Edit `reports/weekly-report-template.qmd`
6. **Deploy website** — Enable GitHub Pages or self-host
7. **Schedule automation** — GitHub Actions or local cron

---

## Questions?

- **Development help:** See `CLAUDE.md`
- **Usage guide:** See `README.md`
- **Technical details:** Inline comments in `code/`
- **Contact:** eelli@uark.edu
