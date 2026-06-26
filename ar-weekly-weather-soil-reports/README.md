# Arkansas Weekly Weather & Soil Water Reports

**Automated APSIM-based soil water monitoring for Arkansas cropland**

Generates weekly benchmarked reports on weather conditions and soil water status using APSIM Next Generation crop simulation across ~4,650 grid cells across Arkansas. Results published to a professional Quarto website.

## Quick Start

```bash
# From repo root (RStudio or command line)
source("code/00-master.R")
```

**Output:**
- `data/outputs/weekly-report-YYYY-WW.html` — Interactive report
- `data/outputs/soil-water-status-YYYY-WW.csv` — Grid cell results
- Website updated in `_site/`

## Features

✅ **APSIM Grid Simulations** — Soil water modeling across ~4,650 cells  
✅ **Parallel Processing** — Multi-core chunk-based execution (resumable)  
✅ **Weekly Automation** — Scheduled runs (GitHub Actions or local cron)  
✅ **Professional Reporting** — Quarto website + HTML reports  
✅ **Benchmarked Analysis** — Compare to historical normals  
✅ **Open Data** — CSV exports for researcher download  

## Architecture

```
00-master.R (orchestrator)
    ├─ 01-simulation.R        APSIM grid simulations (parallel)
    ├─ 02-processing.R        Extract soil water metrics
    ├─ 03-generate-report.R   Render Quarto → HTML + CSV
    └─ website build          Quarto website (_site/)
```

## Requirements

- **R** 4.0+ with packages: `apsimx`, `dplyr`, `doParallel`, `readr`, `rmarkdown`, `quarto`
- **APSIM** Next Generation 2025.x
- **Data files:**
  - `data/raw/sim-grid.rds` — Spatial grid
  - `data/raw/weather/` — Daily `.met` files (station-specific)
  - `data/raw/soil/` — Soil profiles (`.rds` format)
  - `templates/baseline.apsimx` — APSIM template

## Installation

```bash
# Install R packages
Rscript -e "renv::restore()"

# Install APSIM (Windows/Linux - see CLAUDE.md)
# Install Quarto
# https://quarto.org/docs/get-started/
```

## Configuration

Edit `code/00-config.R` to customize:
```r
CHUNK_SIZE <- 50              # cells per parallel task
DATE_START <- "2025-06-16"    # Week start
DATE_END <- "2025-06-22"      # Week end
FORCE_RERUN_SIM <- FALSE      # Delete checkpoints and re-run
```

## Data Structure

```
data/
├── raw/
│   ├── sim-grid.rds                  # Spatial grid (x, y, cellid)
│   ├── weather/                      # Daily weather .met files
│   │   ├── 1.met, 2.met, ..., 4651.met
│   └── soil/                         # Soil profiles
│       ├── 1.rds, 2.rds, ..., 4651.rds
├── processed/                        # Intermediate files (checkpoints)
└── outputs/
    ├── weekly-report-*.html          # Generated reports
    ├── soil-water-status-*.csv       # Grid cell results
    └── checkpoints/                  # Per-chunk RDS files (resumable)
```

## Automation

**GitHub Actions** (recommended - cloud):
```bash
git push origin main
# Workflow runs automatically Monday 7 AM, deploys to GitHub Pages
```

**Local cron** (Linux/macOS):
```bash
crontab -e
# Add: 0 7 * * 1 cd /path/to/repo && Rscript code/00-master.R
```

## Troubleshooting

**APSIM not found:**
- Windows: Auto-detected from `%LOCALAPPDATA%\Programs\APSIM*`
- Linux: Run `which Models` to verify installation

**Missing weather/soil files:**
- Check `data/raw/weather/` and `data/raw/soil/` exist
- Verify file names match cell IDs in `sim-grid.rds`

**Simulation crashes mid-run:**
- Checkpoints auto-save in `data/outputs/checkpoints/`
- Re-run to resume from last completed chunk

See `CLAUDE.md` for detailed development guidance.

---

**Maintained by:** University of Arkansas Division of Agriculture  
**Contact:** eelli@uark.edu
