# Weather Data Strategy: Multi-Source Approach

## Overview

Accurate soil water simulation requires reliable weather data. However, real-time weather data always has lag:
- **IEM (temp/rain)**: 1-2 days behind
- **NASA POWER (radiation)**: 1-7 days behind  
- **CHIRPS (rainfall)**: 1-3 days behind

This document explains our **4-tier strategy** for handling data lag and filling gaps intelligently.

---

## The Problem: Data Lag

| Source | Type | Typical Lag | Issue |
|--------|------|-------------|-------|
| IEM | Temp, Rain, Wind | 1-2 days | Can't run simulation to present day |
| NASA POWER | Radiation | 1-7 days | Essential for crop model |
| Weather stations | Point observations | Variable | Sparse coverage |

**Example**: Today is June 26. Latest data might only be June 24 (2-day lag).
- For soil water simulation Jan-1 to June 26, we're missing June 25-26
- Solution: Intelligently fill those 2 days using fallback data

---

## Our 4-Tier Solution

### Tier 1: IEM (Primary Weather)

**Data**: Temperature, rainfall, wind, pressure  
**Lag**: 1-2 days typical  
**Availability**: Daily  
**Geographic**: Station-based (sparse in rural areas)

**Strength**: Most accurate temp/rain observations  
**Weakness**: Station coverage gaps in Arkansas  

**Action if available**: Use as primary data source

---

### Tier 2: NASA POWER (Radiation)

**Data**: Solar radiation  
**Lag**: 1-7 days (satellite processing delay)  
**Availability**: Daily  
**Geographic**: Global grid (0.5° resolution)

**Strength**: Global coverage, fills radiation gaps  
**Weakness**: Sometimes very stale  

**Fallback if unavailable**: Clear-sky radiation model (based on cloud cover)

---

### Tier 3: CHIRPS (Enhanced Rainfall)

**Data**: High-resolution rainfall  
**Lag**: 1-3 days  
**Resolution**: 0.05° (~5 km)  
**Method**: Blends satellite + rain gauge data  
**Source**: University of California Santa Barbara (UCSB)  

**Strength**: 
- Much finer resolution than IEM stations
- Better captures local rainfall variability
- Validated for agricultural use

**Weakness**: 
- Requires Google Earth Engine setup
- Python/ee package needed
- Not automatic in current Phase 0

**Setup for CHIRPS**:
```bash
# 1. Install Python Earth Engine
pip install earthengine-api pandas python-dateutil

# 2. Authenticate (opens browser)
earthengine authenticate

# 3. Test download
python code/get_chirps_rainfall.py --test

# 4. Download CHIRPS data
python code/get_chirps_rainfall.py \
  --lon -92.5 --lat 34.5 \
  --start 2026-01-01 --end 2026-06-26 \
  --output chirps_2026.csv
```

---

### Tier 4: Climatology (Ultimate Fallback)

**Data**: 40-year average conditions for each day  
**Lag**: N/A (historical)  
**Accuracy**: Low for specific year, high for "typical" conditions  

**Generated from**: Historical baseline (Phase 5 output)

**Use when**:
- All Tier 1-3 sources are stale (>7 days old)
- Need to fill very long gaps
- Early season (before real-time data starts)

**Limitation**: Loses interannual variability but captures seasonal pattern

---

## Data Lag Response Strategy

### Decision Tree

```
Check latest IEM date
    |
    +-- ≤ 1 day old? ────→ CURRENT
    |                       Use as-is, no fill needed
    |
    +-- 1-3 days old? ─→ ACCEPTABLE  
    |                    Fill last 1-2 days with:
    |                    1. Forward-fill (repeat last values)
    |                    2. Use CHIRPS for rain if available
    |
    +-- 3-7 days old? ─→ STALE
    |                    Fill gap using:
    |                    1. Forward-fill initial days
    |                    2. Climatology for longer gaps
    |                    3. Use CHIRPS for enhanced rain
    |
    +-- > 7 days old? ──→ CRITICAL
                         Use primarily:
                         1. Climatology (40-year avg)
                         2. Consider forecast data
                         3. Alert user to data quality
```

---

## Implementation in Phase 0

**Current Phase 0** (`code/00-download-weather.R`):
- Downloads from IEM
- Checks lag
- Recommends DATE_END
- Warns if data stale

**Future enhancement** (`code/00-weather-multi-source.R`):
- Implements full 4-tier strategy
- Automatic Tier fallback
- CHIRPS integration
- Climatology fill

---

## Practical Scenarios

### Scenario 1: Fresh Data (Today is June 26, latest data is June 25)

```
DATA LAG: 1 day

Action: CURRENT
- Use IEM data for June 25
- Extend to June 26 using climatology
- NASA POWER likely also fresh
- No quality concerns
```

**Result**: Full accuracy simulation

---

### Scenario 2: Moderate Lag (Today is June 26, latest data is June 23)

```
DATA LAG: 3 days

Action: ACCEPTABLE  
- Use IEM June 23 data
- Forward-fill June 24-25 with June 23 values
- OR use CHIRPS if rain pattern changed
- Continue simulation to June 26
```

**Result**: Minor loss of accuracy (missed weather events in last 3 days)

---

### Scenario 3: Stale Data (Today is June 26, latest data is June 19)

```
DATA LAG: 7 days

Action: STALE (requires fill-forward + climatology)
- Use IEM June 19 data  
- Days 20-21: Forward-fill (carry June 19 values)
- Days 22-26: Use climatology (40-year avg)
- Use CHIRPS if available to enhance rain accuracy
```

**Result**: Moderate loss of accuracy (last week uses averages)

**Recommendation**: Check if fresher data available

---

### Scenario 4: Critical Lag (Today is June 26, latest data is June 15)

```
DATA LAG: 11 days

Action: CRITICAL (climatology + forecast)
- Do NOT use for real-time decisions
- Use primarily 40-year climatological averages
- Option A: Wait for fresher data
- Option B: Switch to FORECAST mode (use 7-day weather prediction)
- Option C: Note uncertainty and proceed with caveats
```

**Result**: Low accuracy (historical average, not current year)

**Recommendation**: Wait for data or use forecast data

---

## CHIRPS Integration

### Why CHIRPS?

CHIRPS combines:
- **Satellite data**: IR brightness temperature (spatial coverage)
- **Rain gauge data**: Actual measurements (accuracy)
- **Result**: High-resolution rainfall combining strengths of both

### Resolution Comparison

```
IEM:           Points only (~30-50 stations in Arkansas)
CHIRPS:        0.05° grid (~5 km resolution)
NASA POWER:    0.5° grid (~50 km resolution)

For 4,650 Arkansas crop cells:
- CHIRPS covers most locations better than IEM
- Can enhance rain accuracy in gaps
```

### Setup (One-Time)

1. **Python environment**:
   ```bash
   conda create -n chirps
   conda activate chirps
   pip install earthengine-api pandas python-dateutil
   ```

2. **Google Earth Engine setup**:
   - Visit: https://earthengine.google.com/
   - Sign in with Google account
   - Request access (usually instant)
   - In terminal: `earthengine authenticate`
   - Opens browser, authorizes access

3. **Test script**:
   ```bash
   python code/get_chirps_rainfall.py --test
   # Should show: [OK] Authentication successful
   ```

### Weekly Download

```bash
# Download latest CHIRPS data for your area
python code/get_chirps_rainfall.py \
  --lon -92.5 --lat 34.5 \
  --start 2026-01-01 \
  --end $(date +%Y-%m-%d) \
  --output data/raw/chirps_current.csv
```

---

## Recommended Weekly Workflow

### Option A: Automatic (Phase 0 does all)

```r
SIMULATION_MODE <- "weekly"
source("code/04-orchestrate.R")
# Phase 0 automatically:
# - Downloads IEM
# - Checks lag
# - Fills gaps
# - Recommends DATE_END
```

### Option B: Enhanced with CHIRPS

```bash
# Before running Phase 0:
# Download latest CHIRPS for enhanced rain
python code/get_chirps_rainfall.py --end $(date +%Y-%m-%d)

# Then run Phase 0 (will use CHIRPS if integrated)
R
SIMULATION_MODE <- "weekly"
source("code/04-orchestrate.R")
```

### Option C: Manual with Forecast Fallback

```bash
# If data very stale (>5 days old):
# Use forecast mode instead
R
SIMULATION_MODE <- "forecast"
source("code/04-orchestrate.R")
```

---

## Data Quality Documentation

Each week's report should note:

```
Weather Data Lag: 2 days
  - IEM temp/rain: June 24 (2 days behind)
  - NASA POWER rad: June 24 (2 days behind)  
  - Gap fill: June 25-26 forward-filled
  - CHIRPS rain: Enhanced to June 25
  - Data quality: HIGH (nearly current)
```

---

## Troubleshooting

### Q: "IEM download failed"
**A**: Check:
- Internet connection
- IEM server status: https://mesonet.agron.iastate.edu/
- apsimx version (may need update)

### Q: "NASA POWER always stale"
**A**: Normal - satellite processing has lag. Options:
- Use CHIRPS for rain instead
- Accept 5-7 day lag for radiation
- Use clear-sky model fallback

### Q: "CHIRPS authentication error"
**A**: Run setup:
```bash
earthengine authenticate  # Opens browser
# Follow login instructions
earthengine list  # Test access
```

### Q: "Data lag > 7 days, can't run simulation"
**A**: Your options:
1. Wait for fresher data (check tomorrow)
2. Switch to FORECAST mode (uses weather predictions)
3. Accept climatology-based results with caveats
4. Check if alternate data source available (state climatology)

---

## References

- **IEM**: https://mesonet.agron.iastate.edu/
- **NASA POWER**: https://power.larc.nasa.gov/
- **CHIRPS**: https://www.chc.ucsb.edu/data/chirps
- **Google Earth Engine**: https://earthengine.google.com/
- **apsimx documentation**: https://cran.r-project.org/web/packages/apsimx/

---

## Summary

| Tier | Source | Lag | Accuracy | Availability |
|------|--------|-----|----------|--------------|
| 1 | IEM | 1-2 d | High | Daily |
| 2 | NASA POWER | 1-7 d | High | Daily |
| 3 | CHIRPS | 1-3 d | Med-High | Daily (setup needed) |
| 4 | Climatology | N/A | Medium | Always |

**Best practice**: Use Tiers 1-3 when available, fallback to 4 only when necessary.
