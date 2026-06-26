# ═══════════════════════════════════════════════════════════════════════════
# Phase 3: Report Generation — Quarto HTML Weekly Report
# ═══════════════════════════════════════════════════════════════════════════
#
# This script generates a professional HTML report from Phase 2 CSV output.
# Uses Quarto to render weekly soil water status summary with maps and plots.
#
# Input:  data/outputs/soil-water-status-YYYY-WW.csv (Phase 2 output)
# Output: data/outputs/weekly-report-YYYY-WW.html
#
# ═══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

.ts <- function() format(Sys.time(), "%H:%M:%S")

source("code/00-config.R", local = TRUE)

message(sprintf("\n[%s] Phase 3: Report Generation started\n", .ts()))

## ── Find Phase 2 CSV output ────────────────────────────────────────────────

csv_files <- list.files(PATH_OUTPUTS, pattern = "^soil-water-status-.*\\.csv$")

if (length(csv_files) == 0) {
  stop(sprintf("[ERROR] No Phase 2 CSV files found in %s\n", PATH_OUTPUTS),
       "  Run Phase 2 first: source('code/02-processing.R')")
}

# Use the most recent CSV (by name, should match latest week)
csv_file <- file.path(PATH_OUTPUTS, sort(csv_files, decreasing = TRUE)[1])

message(sprintf("[INPUT] Loading Phase 2 data: %s", csv_file))
data <- read_csv(csv_file, show_col_types = FALSE)
message(sprintf("[INPUT] Loaded: %d rows × %d columns", nrow(data), ncol(data)))

## ── Extract metadata ──────────────────────────────────────────────────────

year <- as.character(unique(data$year))
week <- unique(data$week)
week_start <- as.Date(unique(data$week_start))
week_end <- as.Date(unique(data$week_end))
report_date <- Sys.Date()

# Calculate summary statistics
swhc_6in_mean  <- mean(data$swhc_6in_mean, na.rm = TRUE)
swhc_6in_min   <- min(data$swhc_6in_min, na.rm = TRUE)
swhc_6in_max   <- max(data$swhc_6in_max, na.rm = TRUE)

swhc_12in_mean <- mean(data$swhc_12in_mean, na.rm = TRUE)
swhc_12in_min  <- min(data$swhc_12in_min, na.rm = TRUE)
swhc_12in_max  <- max(data$swhc_12in_max, na.rm = TRUE)

swhc_24in_mean <- mean(data$swhc_24in_mean, na.rm = TRUE)
swhc_24in_min  <- min(data$swhc_24in_min, na.rm = TRUE)
swhc_24in_max  <- max(data$swhc_24in_max, na.rm = TRUE)

message(sprintf("[STATS] Week %s (Year %s): %d cells", week, year, nrow(data)))
message(sprintf("[STATS] Date range: %s to %s", week_start, week_end))
message(sprintf("[STATS] Soil water (6in): %.1f–%.1f mm (mean: %.1f)",
                swhc_6in_min, swhc_6in_max, swhc_6in_mean))

## ── Read template and substitute values ────────────────────────────────────

template_file <- "reports/weekly-report-template.qmd"

if (!file.exists(template_file)) {
  stop(sprintf("[ERROR] Template not found: %s", template_file))
}

message(sprintf("[%s] Reading template: %s", .ts(), template_file))
template_content <- readLines(template_file)

# Create substitution pairs
substitutions <- list(
  "{{WEEK_START}}" = format(week_start, "%B %d, %Y"),
  "{{WEEK_END}}" = format(week_end, "%B %d, %Y"),
  "{{REPORT_DATE}}" = format(report_date, "%B %d, %Y"),
  "{{WEEK}}" = sprintf("W%s", week),
  "{{N_CELLS}}" = as.character(nrow(data)),
  "{{SWHC_6IN_MEAN}}" = sprintf("%.1f", swhc_6in_mean),
  "{{SWHC_6IN_MIN}}" = sprintf("%.1f", swhc_6in_min),
  "{{SWHC_6IN_MAX}}" = sprintf("%.1f", swhc_6in_max),
  "{{SWHC_12IN_MEAN}}" = sprintf("%.1f", swhc_12in_mean),
  "{{SWHC_12IN_MIN}}" = sprintf("%.1f", swhc_12in_min),
  "{{SWHC_12IN_MAX}}" = sprintf("%.1f", swhc_12in_max),
  "{{SWHC_24IN_MEAN}}" = sprintf("%.1f", swhc_24in_mean),
  "{{SWHC_24IN_MIN}}" = sprintf("%.1f", swhc_24in_min),
  "{{SWHC_24IN_MAX}}" = sprintf("%.1f", swhc_24in_max)
)

# Apply substitutions
report_content <- template_content
for (key in names(substitutions)) {
  report_content <- gsub(key, substitutions[[key]], report_content, fixed = TRUE)
}

# Create working file
work_file <- file.path(PATH_OUTPUTS, paste0("report-work-", year, "-W", week, ".qmd"))
writeLines(report_content, work_file)
message(sprintf("[PROCESS] Created working Quarto file: %s", work_file))

## ── Render report ──────────────────────────────────────────────────────────

# Check if quarto is available
quarto_available <- nzchar(Sys.which("quarto"))

if (!quarto_available) {
  warning("[WARNING] Quarto not found. HTML report skipped.\n",
          "  Install Quarto from https://quarto.org/docs/get-started/ to generate reports")
  message(sprintf("[OUTPUT] Quarto file ready: %s", work_file))
} else {
  message(sprintf("[%s] Rendering Quarto document", .ts()))

  # Prepare quarto render command
  output_file <- file.path(PATH_OUTPUTS,
                          sprintf("weekly-report-%s-W%s.html", year, week))

  # Quarto command
  cmd <- sprintf(
    'quarto render "%s" --output "%s"',
    work_file, basename(output_file)
  )

  # Run quarto in the output directory
  tryCatch({
    system(sprintf('cd "%s" && %s', PATH_OUTPUTS, cmd),
           ignore.stdout = TRUE, ignore.stderr = TRUE)

    if (file.exists(output_file)) {
      message(sprintf("[OUTPUT] ✓ Report saved: %s", output_file))
      message(sprintf("[OUTPUT] Report size: %.2f MB",
                     file.size(output_file) / (1024^2)))

      # Clean up working file
      unlink(work_file)
      message(sprintf("[CLEANUP] Removed: %s", work_file))
    } else {
      warning("[WARNING] Report rendering completed but output not found")
      message(sprintf("[OUTPUT] Check: %s", work_file))
    }
  }, error = function(e) {
    warning(sprintf("[ERROR] Report rendering failed: %s", e$message))
    message(sprintf("[OUTPUT] Quarto file ready for manual rendering: %s", work_file))
  })
}

## ── Print summary ──────────────────────────────────────────────────────────

cat("\n")
cat(strrep("=", 70), "\n")
cat("PHASE 3: REPORT GENERATION COMPLETE\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Input:    %s\n", csv_file))
cat(sprintf("Template: %s\n", template_file))
if (quarto_available && file.exists(output_file)) {
  cat(sprintf("Output:   %s\n", output_file))
} else {
  cat(sprintf("Output:   %s (ready for rendering)\n", work_file))
}
cat(sprintf("Week:     %s W%s (%s to %s)\n", year, week,
           format(week_start, "%m-%d"), format(week_end, "%m-%d")))
cat(sprintf("Cells:    %d\n", nrow(data)))
cat("\nNext: Review HTML report in browser or proceed to Phase 4 (Website)\n")
cat("  source('code/04-orchestrate.R')\n")
cat(strrep("=", 70), "\n\n")

message(sprintf("[%s] Phase 3 finished", .ts()))
