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

start_time <- Sys.time()

## ── Load configuration ─────────────────────────────────────────────────────

source("code/00-config.R", local = TRUE)

## ── Phase 0: Weather Download & Lag Check (Weekly/Forecast modes only) ────

if (SIMULATION_MODE %in% c("weekly", "forecast")) {
  cat(strrep("─", 70), "\n")
  cat("PHASE 0: Weather Data Download & Lag Check\n")
  cat(strrep("─", 70), "\n")

  tryCatch({
    source("code/00-download-weather.R")
    cat(sprintf("\n✓ Phase 0 completed\n\n"))
  }, error = function(e) {
    cat(sprintf("\n⚠ Phase 0 WARNING: %s\n", e$message))
    cat("Proceeding with existing weather data.\n\n")
  })
}

cat(sprintf("Start time: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Mode: %s\n", toupper(SIMULATION_MODE)))
cat(sprintf("Date range: %s to %s\n", ACTIVE_DATE_START, ACTIVE_DATE_END))
cat(sprintf("Test mode: %s\n", if(TEST_RUN) "ON (limited cells)" else "OFF (full grid)"))
cat(sprintf("Resumable: %s\n\n", if(!FORCE_RERUN_SIM) "YES" else "NO (restarting)"))

## ── Phase 1: APSIM Simulation ──────────────────────────────────────────────

cat(strrep("─", 70), "\n")
cat("PHASE 1: APSIM Grid Simulation\n")
cat(strrep("─", 70), "\n")

tryCatch({
  source("code/01-simulation.R")
  cat(sprintf("✓ Phase 1 completed\n\n"))
}, error = function(e) {
  cat(sprintf("\n✗ Phase 1 ERROR: %s\n\n", e$message))
  cat("Pipeline halted. Fix issues and try again.\n\n")
  quit(save = "no", status = 1)
})

## ── Mode-specific Phase Routing ────────────────────────────────────────────

if (SIMULATION_MODE == "historical") {
  cat(strrep("─", 70), "\n")
  cat("HISTORICAL MODE: Phases 2-3 skipped\n")
  cat(strrep("─", 70), "\n\n")
  cat("✓ Phase 1 (yearly simulations) completed\n")
  cat("✗ Phases 2-3 skipped in historical mode\n\n")
  cat("Next: Run Phase 5 to generate 40-year baseline statistics\n")
  cat("  source('code/05-generate-historical-benchmark.R')\n\n")

} else {
  # Weekly or Forecast mode: run Phase 2 and 3

  ## ── Phase 2: Data Processing ──────────────────────────────────────────

  cat(strrep("─", 70), "\n")
  cat("PHASE 2: Data Processing & Aggregation\n")
  cat(strrep("─", 70), "\n")

  tryCatch({
    source("code/02-processing.R")
    cat(sprintf("✓ Phase 2 completed\n\n"))
  }, error = function(e) {
    cat(sprintf("\n✗ Phase 2 ERROR: %s\n\n", e$message))
    cat("Pipeline halted. Check Phase 1 output and fix issues.\n\n")
    quit(save = "no", status = 1)
  })

  ## ── Phase 3: Report Generation ────────────────────────────────────────

  cat(strrep("─", 70), "\n")
  cat("PHASE 3: Report Generation\n")
  cat(strrep("─", 70), "\n")

  tryCatch({
    source("code/03-generate-report.R")
    cat(sprintf("✓ Phase 3 completed\n\n"))
  }, error = function(e) {
    cat(sprintf("\n⚠ Phase 3 WARNING: %s\n", e$message))
    cat("Report generation non-critical; pipeline continues.\n\n")
  })
}

## ── Pipeline Summary ──────────────────────────────────────────────────────

cat(strrep("═", 70), "\n")
cat("PIPELINE COMPLETE\n")
cat(strrep("═", 70), "\n")
cat(sprintf("Completed: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

## ── Output Summary ────────────────────────────────────────────────────────

cat("Output Files:\n")

if (SIMULATION_MODE == "historical") {
  # Historical mode: yearly results files
  yearly_files <- list.files(PATH_PROCESSED, pattern = "^simulation-results-[0-9]{4}\\.rds$")
  if (length(yearly_files) > 0) {
    cat(sprintf("  ✓ %d yearly results files in %s\n", length(yearly_files), PATH_PROCESSED))
    for (f in head(yearly_files, 3)) {
      fpath <- file.path(PATH_PROCESSED, f)
      cat(sprintf("    - %s (%.1f MB)\n", f, file.size(fpath) / (1024^2)))
    }
    if (length(yearly_files) > 3) {
      cat(sprintf("    ... and %d more\n", length(yearly_files) - 3))
    }
  }

  cat("\nNext Steps:\n")
  cat("  1. After all historical years complete, generate 40-year baseline:\n")
  cat("     source('code/05-generate-historical-benchmark.R')\n")
  cat("  2. The benchmark file will enable weekly reports to compare conditions\n\n")

} else {
  # Weekly or Forecast mode: regular output files
  sim_file <- file.path(PATH_PROCESSED, "simulation-results.rds")
  if (file.exists(sim_file)) {
    cat(sprintf("  ✓ %s (%.1f MB)\n", sim_file,
               file.size(sim_file) / (1024^2)))
  }

  csv_files <- list.files(PATH_OUTPUTS, pattern = "^soil-water-status-.*\\.csv$")
  if (length(csv_files) > 0) {
    csv_path <- file.path(PATH_OUTPUTS, csv_files[1])
    cat(sprintf("  ✓ %s (%.1f KB)\n", csv_path,
               file.size(csv_path) / 1024))
  }

  qmd_files <- list.files(PATH_OUTPUTS, pattern = "^report-work.*\\.qmd$")
  if (length(qmd_files) > 0) {
    qmd_path <- file.path(PATH_OUTPUTS, qmd_files[1])
    cat(sprintf("  ✓ %s (%.1f KB)\n", qmd_path,
               file.size(qmd_path) / 1024))
  }

  html_files <- list.files(PATH_OUTPUTS, pattern = "^weekly-report.*\\.html$")
  if (length(html_files) > 0) {
    html_path <- file.path(PATH_OUTPUTS, html_files[1])
    cat(sprintf("  ✓ %s (%.1f MB)\n", html_path,
               file.size(html_path) / (1024^2)))
  }

  cat("\nNext Steps:\n")
  if (SIMULATION_MODE == "weekly") {
    cat("  1. Review weekly report in browser\n")
    cat("  2. Compare to 40-year benchmark (if available)\n")
    cat("  3. Schedule for automated weekly runs via GitHub Actions\n")
  } else if (SIMULATION_MODE == "forecast") {
    cat("  1. Review forecast report for research stations\n")
    cat("  2. Use for 7-day water management planning\n")
  }
  cat("  3. Build Quarto website with archived reports:\n")
  cat("       quarto render\n")
  cat("  4. Deploy to GitHub Pages (automatic with Actions)\n\n")
}

cat("✓ Pipeline execution completed!\n\n")

cat(strrep("═", 70), "\n\n")
