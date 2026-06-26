# Master Orchestrator for AR Weekly Weather & Soil Water Reports
# Runs the complete pipeline: fetch → process → benchmark → model → forecast → report
#
# Usage:
#   source("code/99-master.R")        # Full pipeline
#   Rscript code/99-master.R          # From command line

rm(list = ls())

# ============================================================================
# Setup
# ============================================================================

start_time <- Sys.time()

# Create required directories
dir.create("data/processed", showWarnings = FALSE)
dir.create("data/outputs/reports", showWarnings = FALSE)
dir.create("data/outputs/datasets", showWarnings = FALSE)
dir.create("data/cache", showWarnings = FALSE)
dir.create("data/logs", showWarnings = FALSE)

# Load configuration
source("code/00-config.R")

# Helper function to run step with error handling
run_step <- function(step_num, step_name, script_file) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(sprintf("STEP %d: %s\n", step_num, step_name))
  cat(sprintf("Running: %s\n", script_file))
  cat(strrep("=", 70), "\n", sep = "")

  tryCatch({
    source(script_file)
    cat(sprintf("✓ Step %d complete\n\n", step_num))
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("✗ Step %d FAILED: %s\n\n", step_num, e$message))
    return(FALSE)
  })
}

# ============================================================================
# Pipeline Execution
# ============================================================================

cat("\n")
cat(strrep("*", 70), "\n")
cat("AR WEEKLY WEATHER & SOIL WATER REPORTS\n")
cat(sprintf("Report Date: %s\n", format(Sys.Date(), "%Y-%m-%d")))
cat(strrep("*", 70), "\n")

# Step 0: Weather Check & Lag Detection
success_0 <- run_step(
  0,
  "Weather Data Check & Lag Detection",
  "code/00-download-weather.R"
)

# Step 1: Data Fetch
success_1 <- run_step(
  1,
  "Data Fetch (Current Weather & Forecasts)",
  "code/01-data-fetch.R"
)

# Step 2: Data Processing
success_2 <- run_step(
  2,
  "Data Processing (QA/QC, Aggregation)",
  "code/02-data-processing.R"
)

# Step 3: Historical Benchmark
success_3 <- run_step(
  3,
  "Historical Benchmark (Percentiles, Anomalies)",
  "code/03-historical-benchmark.R"
)

# Step 4: Soil Water Model
success_4 <- run_step(
  4,
  "Soil Water Modeling (Relative Water Status)",
  "code/04-soil-water-model.R"
)

# Step 5: Forecast Processing
success_5 <- run_step(
  5,
  "Forecast Processing (Trends, Stress Signals)",
  "code/05-forecast-processing.R"
)

# Step 6: Report Generation
success_6 <- run_step(
  6,
  "Report Generation (Render Quarto/Rmarkdown)",
  "code/06-generate-report.R"
)

# ============================================================================
# Summary & Output
# ============================================================================

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

cat("\n")
cat(strrep("*", 70), "\n")
cat("PIPELINE SUMMARY\n")
cat(strrep("*", 70), "\n")

steps <- data.frame(
  Step = c("00: Weather Check", "01: Data Fetch", "02: Processing", "03: Benchmark",
           "04: Soil Water", "05: Forecast", "06: Report"),
  Status = c(
    ifelse(success_0, "✓ PASS", "✗ FAIL"),
    ifelse(success_1, "✓ PASS", "✗ FAIL"),
    ifelse(success_2, "✓ PASS", "✗ FAIL"),
    ifelse(success_3, "✓ PASS", "✗ FAIL"),
    ifelse(success_4, "✓ PASS", "✗ FAIL"),
    ifelse(success_5, "✓ PASS", "✗ FAIL"),
    ifelse(success_6, "✓ PASS", "✗ FAIL")
  )
)

print(steps)

cat("\n")
cat(sprintf("Total Runtime: %.2f minutes\n", as.numeric(elapsed_time)))
cat(sprintf("Completed: %s\n", format(end_time, "%Y-%m-%d %H:%M:%S %Z")))

if (all(success_0, success_1, success_2, success_3, success_4, success_5, success_6)) {
  cat("\n✓ PIPELINE COMPLETE - All steps succeeded\n")

  # Report weather lag status
  if (exists("WEATHER_LAG_STATUS")) {
    cat(sprintf("\nWeather Status: %s (%d days lag)\n", WEATHER_LAG_STATUS, WEATHER_LAG_DAYS))
  }

  cat(sprintf("\nReports available at: %s/\n", PATH_OUTPUT_REPORTS))
  cat(sprintf("Datasets available at: %s/\n", PATH_OUTPUT_DATASETS))
  cat(sprintf("Weather log: data/outputs/weather-log.csv\n"))

  # List generated files
  report_files <- list.files(PATH_OUTPUT_REPORTS, pattern = "*.html$")
  if (length(report_files) > 0) {
    cat("\nGenerated reports:\n")
    for (f in report_files) {
      cat(sprintf("  - %s\n", f))
    }
  }
} else {
  cat("\n✗ PIPELINE INCOMPLETE - Some steps failed\n")
  cat("Check error messages above for details\n")

  if (exists("WEATHER_LAG_STATUS")) {
    cat(sprintf("\nNote: Weather status was %s (%d days lag)\n", WEATHER_LAG_STATUS, WEATHER_LAG_DAYS))
  }
}

cat(strrep("*", 70), "\n\n")
