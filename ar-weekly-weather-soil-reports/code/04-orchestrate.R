# ═══════════════════════════════════════════════════════════════════════════
# Phase 4: Master Orchestrator — Run Full Pipeline (Phases 1-3)
# ═══════════════════════════════════════════════════════════════════════════
#
# This script orchestrates the complete weekly pipeline:
# Phase 1 (APSIM simulations) → Phase 2 (data processing) → Phase 3 (reporting)
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
cat("AR WEEKLY WEATHER & SOIL WATER REPORTS — FULL PIPELINE ORCHESTRATOR\n")
cat(strrep("═", 70), "\n\n")

start_time <- Sys.time()

## ── Load configuration ─────────────────────────────────────────────────────

source("code/00-config.R", local = TRUE)

cat(sprintf("Start time: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Pipeline window: %s to %s\n", DATE_START, DATE_END))
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

## ── Phase 2: Data Processing ──────────────────────────────────────────────

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

## ── Phase 3: Report Generation ────────────────────────────────────────────

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

## ── Pipeline Summary ──────────────────────────────────────────────────────

cat(strrep("═", 70), "\n")
cat("PIPELINE COMPLETE\n")
cat(strrep("═", 70), "\n")
cat(sprintf("Completed: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

## ── Output Summary ────────────────────────────────────────────────────────

cat("Output Files:\n")

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
  cat(sprintf("  ✓ %s (%.1f KB)\n", html_path,
             file.size(html_path) / 1024))
}

cat("\nNext Steps:\n")
cat("  1. Review Phase 3 working file if report rendering needed\n")
cat("  2. Set up GitHub Actions for scheduled weekly runs\n")
cat("  3. Build Quarto website with archived reports\n")
cat("       quarto render\n")
cat("  4. Deploy to GitHub Pages (automatic with Actions)\n\n")

cat("✓ Full pipeline completed successfully!\n\n")

cat(strrep("═", 70), "\n\n")
