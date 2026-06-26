#!/usr/bin/env python3
"""
Download CHIRPS rainfall data from Google Earth Engine

CHIRPS: Climate Hazards Group IR Precipitation with Stations
- Resolution: 0.05 degrees (~5 km)
- Blends satellite + rain gauge data
- Updated daily with ~1-3 day lag
- Perfect for filling rain gaps in IEM

Setup:
------
1. Create Google account if needed
2. Visit: https://earthengine.google.com/
3. Register and enable Earth Engine
4. Install: pip install earthengine-api
5. Authenticate: earthengine authenticate
6. Test: python get_chirps_rainfall.py --test

Usage:
------
python get_chirps_rainfall.py \\
  --lon -92.5 --lat 34.5 \\
  --start 2026-01-01 --end 2026-06-26 \\
  --output chirps_rainfall.csv

Output:
-------
CSV with columns:
  date, rainfall_mm, source
"""

import argparse
import sys
from datetime import datetime, timedelta

try:
    import ee
    import pandas as pd
    from dateutil import parser as date_parser
except ImportError:
    print("ERROR: Required packages not installed")
    print("Install with: pip install earthengine-api pandas python-dateutil")
    sys.exit(1)


def authenticate_ee():
    """Authenticate with Google Earth Engine"""
    try:
        ee.Authenticate()
        ee.Initialize()
        print("[OK] Google Earth Engine authenticated")
        return True
    except Exception as e:
        print(f"[ERROR] Authentication failed: {e}")
        print("Run: earthengine authenticate")
        return False


def download_chirps(lon, lat, start_date, end_date, output_file=None):
    """
    Download CHIRPS rainfall data for a point location

    Args:
        lon: Longitude
        lat: Latitude
        start_date: Start date (YYYY-MM-DD)
        end_date: End date (YYYY-MM-DD)
        output_file: Optional output CSV file

    Returns:
        DataFrame with date, rainfall_mm columns
    """

    if not authenticate_ee():
        return None

    print(f"\n[DOWNLOAD] CHIRPS rainfall")
    print(f"  Location: {lon}, {lat}")
    print(f"  Date range: {start_date} to {end_date}")

    try:
        # Parse dates
        start = ee.Date(start_date)
        end = ee.Date(end_date)

        # Create point geometry
        point = ee.Geometry.Point([lon, lat])

        # Load CHIRPS dataset
        # UCSB-CHG/CHIRPS/DAILY: Daily data, v2.0
        chirps = ee.ImageCollection("UCSB-CHG/CHIRPS/DAILY") \
            .filterDate(start, end) \
            .filterBounds(point) \
            .select("precipitation")

        print(f"  Found {chirps.size().getInfo()} images")

        # Extract time series
        def extract_time_series(image):
            value = image.sample(point, 5000).first().get("precipitation")
            return ee.Feature(None, {
                "date": image.date().format("YYYY-MM-dd"),
                "rainfall_mm": value
            })

        features = chirps.map(extract_time_series).getInfo()

        if not features or len(features["features"]) == 0:
            print("  [WARNING] No CHIRPS data returned")
            return None

        # Convert to DataFrame
        data = []
        for feat in features["features"]:
            props = feat["properties"]
            rainfall = props.get("rainfall_mm")
            if rainfall is not None:
                data.append({
                    "date": props["date"],
                    "rainfall_mm": float(rainfall),
                    "source": "CHIRPS"
                })

        df = pd.DataFrame(data)
        df["date"] = pd.to_datetime(df["date"])
        df = df.sort_values("date")

        print(f"  Downloaded: {len(df)} days of data")
        print(f"  Latest date: {df['date'].max().date()}")
        print(f"  Rainfall range: {df['rainfall_mm'].min():.1f} - {df['rainfall_mm'].max():.1f} mm")

        # Save if requested
        if output_file:
            df.to_csv(output_file, index=False)
            print(f"  Saved: {output_file}")

        return df

    except Exception as e:
        print(f"  [ERROR] {e}")
        return None


def compare_with_iem(chirps_df, iem_df):
    """
    Compare CHIRPS with IEM rainfall data

    Args:
        chirps_df: DataFrame from download_chirps
        iem_df: IEM rainfall data with columns: date, rain

    Returns:
        DataFrame with side-by-side comparison
    """

    if chirps_df is None or iem_df is None:
        print("[INFO] Cannot compare: missing data")
        return None

    # Merge
    merged = chirps_df.merge(
        iem_df[["date", "rain"]].rename(columns={"rain": "iem_mm"}),
        on="date",
        how="outer"
    )

    merged["diff_mm"] = merged["rainfall_mm"] - merged["iem_mm"]
    merged["agree"] = (merged["diff_mm"].abs() < 5)  # Within 5mm

    agreement_pct = (merged["agree"].sum() / len(merged)) * 100 if len(merged) > 0 else 0

    print(f"\n[COMPARISON] CHIRPS vs IEM")
    print(f"  Days in common: {merged['agree'].notna().sum()}")
    print(f"  Agreement (within 5mm): {agreement_pct:.1f}%")
    print(f"  Mean difference: {merged['diff_mm'].mean():.2f} mm")
    print(f"\n{merged.tail(10)}")

    return merged


def main():
    parser = argparse.ArgumentParser(
        description="Download CHIRPS rainfall from Google Earth Engine"
    )
    parser.add_argument("--lon", type=float, default=-92.5, help="Longitude")
    parser.add_argument("--lat", type=float, default=34.5, help="Latitude")
    parser.add_argument("--start", default="2026-01-01", help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", default=None, help="End date (default: today)")
    parser.add_argument("--output", default=None, help="Output CSV file")
    parser.add_argument("--test", action="store_true", help="Test auth only")

    args = parser.parse_args()

    # Default to today
    if args.end is None:
        args.end = datetime.now().strftime("%Y-%m-%d")

    if args.test:
        print("Testing Google Earth Engine authentication...")
        authenticate_ee()
        print("[OK] Authentication successful")
        return

    # Download CHIRPS
    chirps_df = download_chirps(args.lon, args.lat, args.start, args.end, args.output)

    if chirps_df is None:
        sys.exit(1)

    print("\n[SUCCESS] CHIRPS data downloaded")
    print(f"Output format: CSV with date, rainfall_mm, source")


if __name__ == "__main__":
    main()
