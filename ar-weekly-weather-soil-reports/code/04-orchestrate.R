# ═══════════════════════════════════════════════════════════════════════════
# Phase 4: Master Orchestrator — Pipeline Routing (Phases 1-5 by Mode)
# ═══════════════════════════════════════════════════════════════════════════
#
# Routes the complete pipeline based on simulation mode:
#   - WEEKLY: Phase 1 (sims) → Phase 2 (process) → Phase 3 (report)
#   - HISTORICAL: Phase 1 (yearly sims) → [pause] → Phase 5 (benchmark generation)
#   - FORECAST: Phase 1 (sims) → Phase 2 (process) → Phase 3 (report)
#
# Usage:
#   source("code/04-orchestrate.R")
#   # Or: Rscript code/04-orchestrate.R
#
# The script is fully resumable: if Phase N fails, run again and it will
# skip completed phases (unless FORCE_RERUN_* is TRUE).
#
# ═══════════════════════════════════════════════════════════════════════════

cat("\n")
cat(strrep("═", 70), "\n")
cat("AR WEEKLY WEATHER & SOIL WATER REPORTS — ORCHESTRATOR\n")
cat(strrep("═", 70), "\n\n")

# Record when this orchestrator started (for timing/progress reporting)
start_time <- Sys.time()

## ── Load configuration ─────────────────────────────────────────────────────
#
# WHAT: Load the central configuration file with all user settings
# WHY:  Configuration defines what mode to run, what dates, where files are stored
# HOW:  Sources code/00-config.R which sets all the PATH_*, SIMULATION_MODE, etc.
# RESULT: All configuration variables are now available to all phases

# Load configuration from the central config file
# This makes all the settings available (DATE_START, DATE_END, PATH_WEATHER, etc.)
source("code/00-config.R", local = TRUE)

## ── Phase 0: Weather Download & Lag Check (Weekly/Forecast modes only) ────
#
# WHAT: Downloads latest weather data from IEM, checks if data is current/stale
# WHY:  Before simulating, we need to know if weather data is fresh enough to use
# WHEN: Only runs for WEEKLY and FORECAST modes (historical uses archived weather)
# HOW:  Sources code/00-download-weather.R which queries IEM and logs results
# OUTPUT: Latest weather files, lag analysis report, recommended DATE_END

# CHECK: Is this a weekly or forecast simulation?
# (If it's historical mode, we skip Phase 0 because historical uses archived weather)
if (SIMULATION_MODE %in% c("weekly", "forecast")) {
  # YES - this is a weekly or forecast run
  # We need to check if the latest weather data is available

  cat(strrep("─", 70), "\n")
  cat("PHASE 0: Weather Data Download & Lag Check\n")
  cat(strrep("─", 70), "\n")

  # Run Phase 0 with error handling
  # If weather download fails, we continue anyway (using existing weather files)
  tryCatch({
    # Call the weather download & lag detection script
    source("code/00-download-weather.R")
    cat(sprintf("\n✓ Phase 0 completed\n\n"))
  }, error = function(e) {
    # If Phase 0 has an error, warn user but continue
    # This is non-critical because we can use previously downloaded weather files
    cat(sprintf("\n⚠ Phase 0 WARNING: %s\n", e$message))
    cat("Proceeding with existing weather data.\n\n")
  })
}
# END Phase 0

# PRINT SIMULATION PARAMETERS TO SCREEN
# This shows exactly what we're about to run (for verification)
cat(sprintf("Start time: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))  # When did this run start?
cat(sprintf("Mode: %s\n", toupper(SIMULATION_MODE)))  # Which mode: WEEKLY, HISTORICAL, or FORECAST?
cat(sprintf("Date range: %s to %s\n", ACTIVE_DATE_START, ACTIVE_DATE_END))  # What date range are we simulating?
cat(sprintf("Test mode: %s\n", if(TEST_RUN) "ON (limited cells)" else "OFF (full grid)"))  # Running full grid or just test?
cat(sprintf("Resumable: %s\n\n", if(!FORCE_RERUN_SIM) "YES" else "NO (restarting)"))  # Can we resume if it crashes?

## ── Phase 1: APSIM Simulation ──────────────────────────────────────────────
#
# WHAT: Runs APSIM crop simulations across all grid cells (or test subset)
# WHY:  Simulates soil water dynamics, yield, and other crop variables
# HOW:  Launches parallel jobs across multiple CPU cores
# DETAILS: Mode-specific behavior:
#   - WEEKLY: Runs full season Jan-1 to present (resumable via checkpoints)
#   - HISTORICAL: Runs yearly 1985-2025 (separate year-by-year loop)
#   - FORECAST: Runs full season + 7-day forecast (research stations only if specified)
# OUTPUT: simulation-results.rds (weekly/forecast) or simulation-results-YYYY.rds (historical)
# TIME: Typically 30-120 minutes depending on grid size and parallelization

cat(strrep("─", 70), "\n")
cat("PHASE 1: APSIM Grid Simulation\n")
cat(strrep("─", 70), "\n")

# Run Phase 1 with error handling
# If Phase 1 fails, we STOP the entire pipeline (simulation is critical)
tryCatch({
  # Call the simulation script
  # This will launch parallel jobs and run APSIM on all grid cells
  source("code/01-simulation.R")
  cat(sprintf("✓ Phase 1 completed\n\n"))
}, error = function(e) {
  # CRITICAL ERROR: If Phase 1 fails, the whole pipeline stops
  # The user must fix the problem and re-run
  cat(sprintf("\n✗ Phase 1 ERROR: %s\n\n", e$message))
  cat("Pipeline halted. Fix issues and try again.\n\n")
  quit(save = "no", status = 1)  # Exit with error status
})
# END Phase 1

## ── Mode-specific Phase Routing ────────────────────────────────────────────
#
# WHAT: Routes the pipeline based on SIMULATION_MODE
# WHY:  Different modes require different downstream processing
# LOGIC:
#   - HISTORICAL: Phase 1 only (generates yearly results)
#     → User then runs Phase 5 manually to generate 40-year benchmark
#   - WEEKLY: Phases 1 → 2 → 3 (simulates + reports)
#   - FORECAST: Phases 1 → 2 → 3 (simulates + reports)

# CHECK: What mode are we running?
if (SIMULATION_MODE == "historical") {
  # HISTORICAL MODE: Only phase 1 ran (yearly simulations)
  # Phases 2-3 don't apply because we're building baseline data, not reports

  cat(strrep("─", 70), "\n")
  cat("HISTORICAL MODE: Phases 2-3 skipped\n")
  cat(strrep("─", 70), "\n\n")
  cat("✓ Phase 1 (yearly simulations) completed\n")
  cat("✗ Phases 2-3 skipped in historical mode\n")
  cat("   (These modes are for weekly/forecast reporting only)\n\n")
  cat("Next: Run Phase 5 to generate 40-year baseline statistics\n")
  cat("  source('code/05-generate-historical-benchmark.R')\n\n")

} else {
  # WEEKLY or FORECAST MODE: Run Phases 2 and 3
  # Phase 2: Process simulation results into summary metrics
  # Phase 3: Generate professional HTML report

  ## ── Phase 2: Data Processing ──────────────────────────────────────────
  #
  # WHAT: Aggregates simulation results into summary metrics
  # WHY:  APSIM outputs daily results; we need weekly summaries and comparisons
  # HOW:  Extracts soil water at 6in, 12in, 24in; compares to 40-year benchmark
  # OUTPUT: soil-water-status-YYYY-WW.csv with aggregated metrics

  cat(strrep("─", 70), "\n")
  cat("PHASE 2: Data Processing & Aggregation\n")
  cat(strrep("─", 70), "\n")

  # Run Phase 2 with error handling
  # If Phase 2 fails, we stop (need the processed data for reporting)
  tryCatch({
    # Call the data processing script
    source("code/02-processing.R")
    cat(sprintf("✓ Phase 2 completed\n\n"))
  }, error = function(e) {
    # CRITICAL ERROR: Can't proceed without processed data
    cat(sprintf("\n✗ Phase 2 ERROR: %s\n\n", e$message))
    cat("Pipeline halted. Check Phase 1 output and fix issues.\n\n")
    quit(save = "no", status = 1)
  })

  ## ── Phase 3: Report Generation ────────────────────────────────────────
  #
  # WHAT: Creates professional HTML report with maps and tables
  # WHY:  Communicates results to end users (stakeholders, farmers, managers)
  # HOW:  Renders Quarto template with processed data, creates interactive maps
  # OUTPUT: weekly-report-YYYY-WW.html (professional report with comparisons)
  # NOTE: Non-critical; if this fails, we have the data (CSV) even without the report

  cat(strrep("─", 70), "\n")
  cat("PHASE 3: Report Generation\n")
  cat(strrep("─", 70), "\n")

  # Run Phase 3 with error handling
  # If Phase 3 fails, we continue (data is safe, just missing the HTML report)
  tryCatch({
    # Call the report generation script
    source("code/03-generate-report.R")
    cat(sprintf("✓ Phase 3 completed\n\n"))
  }, error = function(e) {
    # NON-CRITICAL WARNING: Report failed, but data is OK
    cat(sprintf("\n⚠ Phase 3 WARNING: %s\n", e$message))
    cat("Report generation non-critical; data is safely saved.\n")
    cat("You can still access results in CSV format.\n\n")
  })
}
# END Phase routing

## ── Pipeline Summary ──────────────────────────────────────────────────────
#
# WHAT: Print completion status and list all output files
# WHY:  Shows user what was produced and where to find it
# OUTPUT: Summary of files created + next steps

cat(strrep("═", 70), "\n")
cat("PIPELINE COMPLETE\n")
cat(strrep("═", 70), "\n")
cat(sprintf("Completed: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

# Calculate how long the pipeline took
elapsed_time <- difftime(Sys.time(), start_time, units = "mins")
cat(sprintf("Total time: %.1f minutes\n\n", elapsed_time))

## ── Output Summary ────────────────────────────────────────────────────────
#
# WHAT: Lists all files that were created by the pipeline
# WHY:  User needs to know where to find results
# HOW:  Searches for files matching each expected output pattern
# DISPLAY: Shows file names and sizes

cat("Output Files:\n\n")

# CHECK: What mode are we in? (Different output for historical vs weekly/forecast)
if (SIMULATION_MODE == "historical") {
  # ─────────────────────────────────────────────────────────────────────────
  # HISTORICAL MODE OUTPUT: Yearly results files
  # ─────────────────────────────────────────────────────────────────────────
  # In historical mode, we generated annual results for 1985-2025
  # Each year's simulation is saved as: simulation-results-YYYY.rds
  # These will later be aggregated into a 40-year benchmark

  yearly_files <- list.files(PATH_PROCESSED, pattern = "^simulation-results-[0-9]{4}\\.rds$")
  if (length(yearly_files) > 0) {
    # We found yearly result files
    cat(sprintf("  ✓ %d yearly results files in %s\n", length(yearly_files), PATH_PROCESSED))
    # Show first 3 files as examples
    for (f in head(yearly_files, 3)) {
      fpath <- file.path(PATH_PROCESSED, f)
      # Show file name and size
      cat(sprintf("    - %s (%.1f MB)\n", f, file.size(fpath) / (1024^2)))
    }
    # If there are more than 3, show a count of remaining
    if (length(yearly_files) > 3) {
      cat(sprintf("    ... and %d more\n", length(yearly_files) - 3))
    }
  } else {
    cat("  ⚠ No yearly results files found (check if Phase 1 completed successfully)\n")
  }

  cat("\nNext Steps:\n")
  cat("─────────────────\n")
  cat("  1. After all historical years (1985-2025) are complete:\n")
  cat("     source('code/05-generate-historical-benchmark.R')\n\n")
  cat("  2. This generates: data/outputs/benchmark/historical-statistics.rds\n")
  cat("     (Contains 40-year means, SD, percentiles per soil water metric)\n\n")
  cat("  3. The benchmark enables weekly reports to show:\n")
  cat("     'How do this week's conditions compare to the 40-year average?'\n\n")

} else {
  # ─────────────────────────────────────────────────────────────────────────
  # WEEKLY/FORECAST MODE OUTPUT: Current report files
  # ─────────────────────────────────────────────────────────────────────────
  # In weekly/forecast mode, we generated:
  # - simulation-results.rds (raw APSIM output)
  # - soil-water-status-YYYY-WW.csv (aggregated metrics)
  # - weekly-report-YYYY-WW.html (professional report for end users)

  # Check for simulation results file
  sim_file <- file.path(PATH_PROCESSED, "simulation-results.rds")
  if (file.exists(sim_file)) {
    cat(sprintf("  ✓ Simulation results: %s (%.1f MB)\n", sim_file,
               file.size(sim_file) / (1024^2)))
  } else {
    cat("  ⚠ Simulation results not found (check if Phase 1 completed)\n")
  }

  # Check for CSV summary file
  csv_files <- list.files(PATH_OUTPUTS, pattern = "^soil-water-status-.*\\.csv$")
  if (length(csv_files) > 0) {
    csv_path <- file.path(PATH_OUTPUTS, csv_files[1])
    cat(sprintf("  ✓ CSV summary: %s (%.1f KB)\n", csv_path,
               file.size(csv_path) / 1024))
  } else {
    cat("  ⚠ CSV summary not found (check if Phase 2 completed)\n")
  }

  # Check for Quarto template file (working version)
  qmd_files <- list.files(PATH_OUTPUTS, pattern = "^report-work.*\\.qmd$")
  if (length(qmd_files) > 0) {
    qmd_path <- file.path(PATH_OUTPUTS, qmd_files[1])
    cat(sprintf("  ✓ Report template: %s (%.1f KB)\n", qmd_path,
               file.size(qmd_path) / 1024))
  }

  # Check for final HTML report
  html_files <- list.files(PATH_OUTPUTS, pattern = "^weekly-report.*\\.html$")
  if (length(html_files) > 0) {
    html_path <- file.path(PATH_OUTPUTS, html_files[1])
    cat(sprintf("  ✓ HTML report: %s (%.1f MB)\n", html_path,
               file.size(html_path) / (1024^2)))
  } else {
    cat("  ⚠ HTML report not found (check if Phase 3 completed)\n")
  }

  cat("\nNext Steps:\n")
  cat("─────────────────\n")
  if (SIMULATION_MODE == "weekly") {
    cat("  1. REVIEW RESULTS:\n")
    cat("     → Open the HTML report in your browser\n")
    cat("     → Check spatial maps of soil water at 3 depths\n")
    cat("     → Compare current week to 40-year baseline\n\n")
    cat("  2. INTERPRETATION:\n")
    cat("     → Is soil water above, near, or below normal?\n")
    cat("     → Are there drought stress concerns for crops?\n\n")
    cat("  3. AUTOMATE:\n")
    cat("     → Schedule this script to run every Monday at 10:00 UTC\n")
    cat("     → See .github/workflows/weekly-report.yml for GitHub Actions setup\n\n")
  } else if (SIMULATION_MODE == "forecast") {
    cat("  1. REVIEW FORECAST:\n")
    cat("     → Check 7-day soil water outlook for research stations\n")
    cat("     → Plan irrigation based on predicted available water\n\n")
  }
  cat("  2. BUILD WEBSITE:\n")
  cat("     quarto render\n")
  cat("     (Compiles all reports into _site/ for GitHub Pages)\n\n")
  cat("  3. DEPLOY:\n")
  cat("     git add _site/ && git commit && git push\n")
  cat("     (Automatic on GitHub with Actions workflow)\n\n")
}
# END Output Summary

# FINAL COMPLETION MESSAGE
# Indicate that the orchestrator finished successfully
cat("✓ Pipeline execution completed!\n\n")

# Print separator line to mark the end
cat(strrep("═", 70), "\n\n")

# NOTE TO USER:
# The orchestrator has now finished routing through all required phases.
# All output files have been created and are ready for use.
# See summary above for where to find results and what to do next.
