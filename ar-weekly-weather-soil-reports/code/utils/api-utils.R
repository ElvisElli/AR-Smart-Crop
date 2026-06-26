# API Utilities - Wrappers for weather data APIs with error handling & rate limiting

library(httr)
library(jsonlite)

# ============================================================================
# IEM (Iowa Environmental Mesonet) API Functions
# ============================================================================

#' Fetch weather data from IEM API
#'
#' @param lon Longitude (WGS84)
#' @param lat Latitude (WGS84)
#' @param start_date Start date (YYYY-MM-DD)
#' @param end_date End date (YYYY-MM-DD)
#' @param api_delay Delay between requests (seconds)
#'
#' @return Data frame with columns: date, tmax, tmin, precip, radn, ...
#' @export
fetch_weather_iem <- function(lon, lat, start_date, end_date, api_delay = 2) {
  # IEM API endpoint
  url <- sprintf(
    "https://mesonet.agron.iastate.edu/json/raob.py?ts=%s&ts2=%s&lon=%.4f&lat=%.4f",
    format(start_date, "%Y%m%d%H%M"),
    format(end_date, "%Y%m%d%H%M"),
    lon, lat
  )

  tryCatch({
    Sys.sleep(api_delay)
    response <- GET(url, timeout(API_TIMEOUT_SECONDS))

    if (status_code(response) != 200) {
      warning(sprintf("IEM API returned status %d", status_code(response)))
      return(NULL)
    }

    data <- fromJSON(content(response, as = "text"))

    # Parse response (structure varies; adapt as needed)
    if (is.null(data$profiles) || length(data$profiles) == 0) {
      return(NULL)
    }

    weather_df <- data.frame(
      date = as.Date(data$profiles[[1]]$ts),
      tmax = NA_real_,
      tmin = NA_real_,
      precip = NA_real_,
      radn = NA_real_
    )

    return(weather_df)
  }, error = function(e) {
    warning(sprintf("IEM API error: %s", e$message))
    return(NULL)
  })
}

# ============================================================================
# Open-Meteo API Functions (Recommended - Free, No API Key Required)
# ============================================================================

#' Fetch historical weather from Open-Meteo API
#'
#' @param lon Longitude (WGS84)
#' @param lat Latitude (WGS84)
#' @param start_date Start date (YYYY-MM-DD)
#' @param end_date End date (YYYY-MM-DD)
#' @param api_delay Delay between requests (seconds)
#'
#' @return Data frame with columns: date, tmax, tmin, precip, radn
#' @export
fetch_weather_openmeteo <- function(lon, lat, start_date, end_date, api_delay = 2) {
  # Open-Meteo historical API
  url <- "https://archive-api.open-meteo.com/v1/archive"

  query <- list(
    latitude = lat,
    longitude = lon,
    start_date = format(start_date, "%Y-%m-%d"),
    end_date = format(end_date, "%Y-%m-%d"),
    daily = "temperature_2m_max,temperature_2m_min,precipitation_sum,shortwave_radiation_sum",
    timezone = "auto"
  )

  tryCatch({
    Sys.sleep(api_delay)
    response <- GET(url, query = query, timeout(API_TIMEOUT_SECONDS))

    if (status_code(response) != 200) {
      warning(sprintf("Open-Meteo API returned status %d", status_code(response)))
      return(NULL)
    }

    data <- fromJSON(content(response, as = "text"))

    if (is.null(data$daily) || length(data$daily$time) == 0) {
      return(NULL)
    }

    weather_df <- data.frame(
      date = as.Date(data$daily$time),
      tmax = data$daily$temperature_2m_max,
      tmin = data$daily$temperature_2m_min,
      precip = data$daily$precipitation_sum,
      radn = data$daily$shortwave_radiation_sum
    ) %>%
      filter(!is.na(date))

    return(weather_df)
  }, error = function(e) {
    warning(sprintf("Open-Meteo API error: %s", e$message))
    return(NULL)
  })
}

#' Fetch weather forecasts from Open-Meteo API
#'
#' @param lon Longitude (WGS84)
#' @param lat Latitude (WGS84)
#' @param days_ahead Number of days to forecast (1-10)
#' @param api_delay Delay between requests (seconds)
#'
#' @return Data frame with columns: forecast_date, tmax_forecast, tmin_forecast, precip_prob, ...
#' @export
fetch_forecast_openmeteo <- function(lon, lat, days_ahead = 7, api_delay = 2) {
  url <- "https://api.open-meteo.com/v1/forecast"

  query <- list(
    latitude = lat,
    longitude = lon,
    daily = "temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max",
    forecast_days = days_ahead,
    timezone = "auto"
  )

  tryCatch({
    Sys.sleep(api_delay)
    response <- GET(url, query = query, timeout(API_TIMEOUT_SECONDS))

    if (status_code(response) != 200) {
      warning(sprintf("Open-Meteo Forecast API returned status %d", status_code(response)))
      return(NULL)
    }

    data <- fromJSON(content(response, as = "text"))

    if (is.null(data$daily) || length(data$daily$time) == 0) {
      return(NULL)
    }

    forecast_df <- data.frame(
      forecast_date = as.Date(data$daily$time),
      tmax_forecast = data$daily$temperature_2m_max,
      tmin_forecast = data$daily$temperature_2m_min,
      precip_forecast = data$daily$precipitation_sum,
      precip_prob = data$daily$precipitation_probability_max
    ) %>%
      filter(!is.na(forecast_date))

    return(forecast_df)
  }, error = function(e) {
    warning(sprintf("Open-Meteo Forecast API error: %s", e$message))
    return(NULL)
  })
}

# ============================================================================
# Utility Functions
# ============================================================================

#' Validate API response
#'
#' @param response HTTP response object
#'
#' @return Logical TRUE if valid
validate_api_response <- function(response) {
  if (is.null(response)) return(FALSE)
  if (status_code(response) != 200) return(FALSE)
  TRUE
}

#' Retry API call with exponential backoff
#'
#' @param expr Expression to evaluate (API call)
#' @param max_retries Maximum retry attempts (default: 3)
#' @param backoff_base Backoff multiplier (seconds)
#'
#' @return Result of expr or NULL
retry_api_call <- function(expr, max_retries = 3, backoff_base = 2) {
  for (attempt in 1:max_retries) {
    result <- tryCatch(expr, error = function(e) NULL)

    if (!is.null(result)) {
      return(result)
    }

    if (attempt < max_retries) {
      wait_time <- backoff_base^attempt
      cat(sprintf("API call failed; retrying in %d seconds (attempt %d/%d)\n",
        wait_time, attempt + 1, max_retries
      ))
      Sys.sleep(wait_time)
    }
  }

  return(NULL)
}
