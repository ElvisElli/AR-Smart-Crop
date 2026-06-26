# Step 06: Generate Report - Render Quarto/Rmarkdown templates
# Input: All processed data in data/processed/*.rds
# Output: data/outputs/reports/*.html + CSV datasets

source("code/00-config.R")

if (VERBOSE) cat("Step 06: Report Generation\n")

library(tidyverse)

# ============================================================================
# 1. Load All Processed Data
# ============================================================================

conditions <- readRDS(file.path(PATH_PROCESSED_DATA, "current-conditions.rds"))
soil_water <- readRDS(file.path(PATH_PROCESSED_DATA, "soil-water-status.rds"))

# Try to load optional data (won't fail if missing)
historical_stats <- tryCatch(
  readRDS(file.path(PATH_PROCESSED_DATA, "historical-stats.rds")),
  error = function(e) NULL
)
forecast_trends <- tryCatch(
  readRDS(file.path(PATH_PROCESSED_DATA, "forecast-trends.rds")),
  error = function(e) NULL
)

if (VERBOSE) {
  cat("Loaded processed data:\n")
  cat("  - Current conditions:", nrow(conditions), "records\n")
  cat("  - Soil water:", nrow(soil_water), "records\n")
  if (!is.null(historical_stats)) cat("  - Historical stats:", nrow(historical_stats), "records\n")
  if (!is.null(forecast_trends)) cat("  - Forecast trends:", nrow(forecast_trends), "records\n")
}

# ============================================================================
# 2. Export CSV Datasets
# ============================================================================

if (VERBOSE) cat("\nExporting CSV datasets...\n")

week_label <- format(REPORT_DATE, "%Y-W%U")

write_csv(conditions,
  file.path(PATH_OUTPUT_DATASETS, sprintf("weather-current-%s.csv", week_label))
)
write_csv(soil_water,
  file.path(PATH_OUTPUT_DATASETS, sprintf("soil-water-%s.csv", week_label))
)

if (!is.null(historical_stats)) {
  write_csv(historical_stats,
    file.path(PATH_OUTPUT_DATASETS, sprintf("historical-percentiles-%s.csv", week_label))
  )
}

if (!is.null(forecast_trends)) {
  write_csv(forecast_trends,
    file.path(PATH_OUTPUT_DATASETS, sprintf("forecast-%s.csv", week_label))
  )
}

if (VERBOSE) cat("✓ CSV datasets exported\n")

# ============================================================================
# 3. Render Quarto Report
# ============================================================================

if (VERBOSE) cat("\nRendering HTML report...\n")

report_output_file <- file.path(
  PATH_OUTPUT_REPORTS,
  sprintf("weekly-report-%s.html", week_label)
)

# Check if quarto is installed
quarto_installed <- nzchar(Sys.which("quarto"))

if (quarto_installed && file.exists("reports/weekly-report-template.qmd")) {
  # Render with quarto
  tryCatch({
    quarto::quarto_render(
      "reports/weekly-report-template.qmd",
      output_file = report_output_file,
      quiet = !VERBOSE
    )
    if (VERBOSE) cat(sprintf("✓ Report generated: %s\n", report_output_file))
  }, error = function(e) {
    warning(sprintf("Quarto rendering failed: %s", e$message))
    cat("Falling back to Rmarkdown...\n")
  })
} else if (file.exists("reports/weekly-report-template.Rmd")) {
  # Fall back to Rmarkdown
  tryCatch({
    rmarkdown::render(
      "reports/weekly-report-template.Rmd",
      output_file = report_output_file,
      quiet = !VERBOSE
    )
    if (VERBOSE) cat(sprintf("✓ Report generated: %s\n", report_output_file))
  }, error = function(e) {
    warning(sprintf("Rmarkdown rendering failed: %s", e$message))
  })
} else {
  # Generate simple HTML report
  if (VERBOSE) cat("Creating simple HTML report (no template found)...\n")

  html_content <- sprintf("
    <!DOCTYPE html>
    <html>
    <head>
      <title>AR Weekly Weather Report - %s</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #1a472a; }
        table { border-collapse: collapse; width: 100%%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #1a472a; color: white; }
      </style>
    </head>
    <body>
      <h1>Arkansas Weekly Weather & Soil Water Report</h1>
      <p><strong>Week:</strong> %s</p>
      <p><strong>Report Date:</strong> %s</p>
      <p><strong>Stations:</strong> %s</p>

      <h2>Current Conditions (Last 7 Days)</h2>
      <pre>%s</pre>

      <h2>Soil Water Status</h2>
      <pre>%s</pre>

      <p><em>For detailed analysis, update reports/ templates with Quarto or Rmarkdown</em></p>
    </body>
    </html>
  ",
    week_label,
    week_label,
    format(REPORT_DATE, "%B %d, %Y"),
    paste(unique(conditions$station), collapse = ", "),
    capture.output(tail(conditions, 10)),
    capture.output(tail(soil_water, 10))
  )

  writeLines(html_content, report_output_file)
  if (VERBOSE) cat(sprintf("✓ Simple HTML report generated: %s\n", report_output_file))
}

# ============================================================================
# Summary
# ============================================================================

if (VERBOSE) {
  cat("\n=== Step 06 Complete: Report Generation ===\n")
  cat(sprintf("Report output: %s/\n", PATH_OUTPUT_REPORTS))
  cat(sprintf("Datasets output: %s/\n", PATH_OUTPUT_DATASETS))
}
