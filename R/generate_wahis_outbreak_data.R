# wahis_outbreak_data_in_db is required to let targets know that
# this function needs to be downstream of the wahis_outbreak_data_in_db target.
generate_wahis_outbreak_data <- function(db_branch, wahis_outbreak_data_in_db) {

  conn <- dbConnect(dolt_local())
  dolt_checkout(db_branch, conn = conn)

  wahis_raw <- get_wahis_raw(db_branch)

  wahis_outbreak_data <- list(
    outbreak_summary = get_wahis_outbreak_summary(wahis_raw),
    outbreak_time_series = get_wahis_time_series(wahis_raw)
  )

  dbDisconnect(conn)

  wahis_outbreak_data
}

get_wahis_raw <- function(db_branch) {

  conn = dbConnect(dolt_local())
  doltr::dolt_checkout(db_branch)

  outbreak_reports_details_raw <- doltr::dbReadTable(conn, "outbreak_reports_details_raw")
  outbreak_reports_events_raw <- doltr::dbReadTable(conn, "outbreak_reports_events_raw")

  dbDisconnect(conn)

  # Similar logic to previous SQL query
  # Note both duration_in_days and interval can't be zero.
  wahis_raw <- outbreak_reports_details_raw |>
    left_join(outbreak_reports_events_raw, by = "report_id") |>
    mutate(source = "wahis",
           location = country,
           location_adm_level = "Country")

  # Account for data entry errors.
  # If start_date is greater than end_date and they both exist swap them.
  wahis_raw <- wahis_raw |>
    mutate(outbreak_start_date = dplyr::if_else(outbreak_start_date > outbreak_end_date, outbreak_end_date, outbreak_start_date),
           outbreak_end_date = dplyr::if_else(outbreak_start_date > outbreak_end_date, outbreak_start_date, outbreak_end_date))

  # Account for data entry errors.
  # If start_date is NA but end_date exists swap them.
  wahis_raw <- wahis_raw |>
    mutate(outbreak_start_date = dplyr::if_else(is.na(outbreak_start_date) & !is.na(outbreak_end_date), outbreak_end_date, outbreak_start_date),
           outbreak_end_date = dplyr::if_else(is.na(outbreak_start_date) & !is.na(outbreak_end_date), outbreak_start_date, outbreak_end_date))

  # Sometimes no end_date is reported preventing calculation of case interval.
  # This is an attempt to account for this by imputing missing end_dates as
  # one day before the start of the next start_date if available.
  # However we have to group by both outbreak_thread_id and outbreak_location_id here
  # because locations are (somewhat) independent. In other words, the outbreak_start_date
  # at one farm later in time is not a good indicator of the outbreak_end_date at a
  # different farm.
  wahis_raw <- wahis_raw |>
    group_by(outbreak_thread_id, outbreak_location_id) |>
    mutate(outbreak_start_date_next = dplyr::lead(outbreak_start_date)) |> # get leading start date by group
    mutate(outbreak_end_date = dplyr::if_else(!is.na(outbreak_start_date) & is.na(outbreak_end_date), outbreak_start_date_next - 1, outbreak_end_date)) |>
    ungroup()

  # Calculate raw interval between start and end date
  # outbreak_end_date + lubridate::days(1) to guard from start_date == end_date. This makes the end date inclusive
  wahis_raw <- wahis_raw |>
    mutate(interval = as.numeric(difftime(outbreak_end_date, outbreak_start_date, units="days")))

  # Prune any rows without BOTH a start and end date
  wahis_raw <- wahis_raw |> filter(!is.na(outbreak_start_date) & !is.na(outbreak_end_date))

  wahis_raw
}

# https://stackoverflow.com/questions/38699761/getting-the-centroids-of-lat-and-longitude-in-a-data-frame
get_centroid <- function(x) {
  tibble(geosphere::centroid(as.matrix(x[,c("longitude", "latitude")])))
}

# na.rm=T in min, max not right
get_wahis_outbreak_summary <- function(wahis_raw) {

  # get lat/lon for the start of outbreak
  # to identify start: filter for min report_date, then min outbreak_start_date
  # for multiple initial reported locations, take the centroid (just the mean)
  outbreak_start_coords <- wahis_raw |>
    distinct(outbreak_thread_id, latitude, longitude, report_date, outbreak_start_date) |>
    group_by(outbreak_thread_id) |>
    filter(report_date == min(report_date)) |>
    filter(outbreak_start_date == min(outbreak_start_date)) |>
    summarize(latitude = mean(latitude, na.rm = TRUE), longitude = mean(longitude, na.rm = TRUE)) |>
    ungroup()

  wahis_outbreaks <- wahis_raw |>
    group_by(outbreak_thread_id,
             source,
             country,
             location,
             country_iso3c,
             location_adm_level,
             disease) |>
    summarize(num_locations = length(unique(outbreak_location_id)),
              num_taxa = length(unique(species_name)),
              outbreak_start_date = min(outbreak_start_date, outbreak_end_date, na.rm = T), # Correct for data entry blunders
              outbreak_end_date = max(outbreak_start_date, outbreak_end_date, na.rm = T),
              raw_avg_interval = as.numeric(mean(interval)),
              total_cases_per_outbreak = sum(cases),
              .groups = "drop") |>
    left_join(outbreak_start_coords, by = "outbreak_thread_id") |>
    mutate(duration_in_days = as.integer(difftime(outbreak_end_date, outbreak_start_date, units = c("days"))) + 1) |> # Add one to guard from start_date == end_date
    select(c("outbreak_thread_id", "source", "location"), everything()) |>
    distinct(outbreak_thread_id, .keep_all = T) # Make sure no annoying disease naming irregularities snuck through

  wahis_outbreaks
}

get_wahis_time_series <- function(wahis_raw) {

  wahis_time_series <- wahis_raw |>
    mutate(cases_per_interval = as.numeric(cases),
           start_date = outbreak_start_date,
           end_date = outbreak_end_date,
           taxon = species_name)|>
    select(
      source,
      outbreak_thread_id,
      outbreak_location_id,
      taxon,
      is_wild,
      is_aquatic,
      start_date,
      end_date,
      interval,
      cases_per_interval
    ) |>
    group_by(across(-cases_per_interval)) |>
    mutate(cases_per_interval = sum(cases_per_interval)) |> # Aggregate across reports (sum). This might not be correct
    distinct() |>
    ungroup() |>
    mutate(id = 1:n()) |>
    select(id, everything())

  wahis_time_series
}
