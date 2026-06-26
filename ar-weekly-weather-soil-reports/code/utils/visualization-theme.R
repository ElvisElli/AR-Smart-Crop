# ggplot2 Theme for AR Weather Reports
# Consistent styling across all visualizations

library(ggplot2)

# Define custom theme
theme_ar_weather <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      # Typography
      plot.title = element_text(
        size = rel(1.5),
        face = "bold",
        color = "#1a472a",
        margin = margin(b = 10)
      ),
      plot.subtitle = element_text(
        size = rel(1.1),
        color = "#555555",
        margin = margin(b = 15)
      ),
      axis.title = element_text(
        size = rel(0.95),
        face = "bold",
        color = "#333333"
      ),
      axis.text = element_text(
        size = rel(0.85),
        color = "#555555"
      ),

      # Legends
      legend.position = "right",
      legend.title = element_text(
        size = rel(0.9),
        face = "bold"
      ),
      legend.text = element_text(
        size = rel(0.85)
      ),

      # Panels & gridlines
      panel.border = element_rect(
        color = "#cccccc",
        fill = NA,
        size = 0.3
      ),
      panel.grid.major = element_line(
        color = "#eeeeee",
        size = 0.25
      ),
      panel.grid.minor = element_blank(),
      strip.text = element_text(
        size = rel(0.95),
        face = "bold",
        color = "#333333"
      ),
      strip.background = element_rect(
        fill = "#f0f0f0",
        color = "#cccccc"
      ),

      # Layout
      plot.background = element_rect(
        fill = "white",
        color = NA
      ),
      panel.background = element_rect(
        fill = "#fafafa",
        color = NA
      ),
      plot.margin = margin(10, 10, 10, 10)
    )
}

# Add theme to ggplot2 defaults
ggplot2::theme_set(theme_ar_weather())

# Define University of Arkansas colors
uark_colors <- list(
  primary = "#1a472a",      # Dark green
  secondary = "#d4a052",    # Gold
  accent = "#e8a525",       # Bright gold
  text = "#333333",         # Dark gray
  light = "#f5f5f5"         # Light gray
)

# Color palettes for common weather variables
palette_temperature <- function() {
  c("#1f77b4", "#ff7f0e", "#d62728")  # Cool, Neutral, Hot
}

palette_precipitation <- function() {
  c("#2ca25f", "#1b9e77", "#0868ac")  # Green to blue (dry to wet)
}

palette_soil_water <- function() {
  c("#8B4513", "#DAA520", "#90EE90")  # Brown to green (dry to wet)
}

# Function to create consistent plot with title and subtitle
wrap_ar_plot <- function(p, title, subtitle = NULL, caption = NULL) {
  p +
    labs(
      title = title,
      subtitle = subtitle,
      caption = caption
    ) +
    theme_ar_weather()
}
