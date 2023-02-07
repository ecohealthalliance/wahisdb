# wahis_outbreak_data_in_db is required to let targets know that
# this function needs to be downstream of the wahis_outbreak_data_raw_prepped_in_db target.
generate_wahis_outbreak_data <- function(db_branch, wahis_outbreak_data_raw_prepped_in_db) {


  wahis_raw <- get_wahis_raw(db_branch)  # this gets and cleans raw, including handling and renaming fields

  wahis_outbreak_data <- list(
    outbreak_summary = get_wahis_outbreak_summary(wahis_raw),
    outbreak_time_series = get_wahis_time_series(wahis_raw)
  )


  wahis_outbreak_data
}

get_wahis_raw <- function(db_branch) {


  # Pull data from database -------------------------------------------------------------------------
  dolt_checkout(db_branch)
  conn <- dolt()
  outbreak_reports_details_raw <- doltr::dbReadTable(conn, "outbreak_reports_details_raw") |> as_tibble()
  outbreak_reports_events_raw <- doltr::dbReadTable(conn, "outbreak_reports_events_raw")|> as_tibble()
  outbreak_reports_ingest_status_log <- doltr::dbReadTable(conn, "outbreak_reports_ingest_status_log")|> as_tibble()
  dbDisconnect(conn)

  # outbreak_reports_events_raw -------------------------------------------------------------------------
  # First implement renaming and other edits that had previously been done prior to saving raw data

  # Pull in outbreak thread ID
  lookup_outbreak_thread_id <-  outbreak_reports_ingest_status_log |>
    select(outbreak_thread_id = event_id_oie_reference, report_info_id)

  outbreak_reports_events <- outbreak_reports_events_raw |>
    left_join(lookup_outbreak_thread_id,  by = "report_info_id") |>
    select(outbreak_thread_id, report_id, report_info_id, everything())

  # Iso3c lookup and column renaming
  outbreak_reports_events <- outbreak_reports_events |>
    mutate(country_iso3c = countrycode::countrycode(country_or_territory, origin = "country.name", destination = "iso3c")) |>
    rename_all(recode,
               country_or_territory = "country",
               disease_name = "disease",
               report_title = "report_type",
               translated_reason = "reason_for_notification",
               confirmed_on = "date_of_confirmation_of_the_event",
               start_date = "date_of_start_of_the_event",
               end_date = "date_event_resolved",
               last_occurance_date = "date_of_previous_occurrence",
               disease_type = "serotype",
               event_description_status = "future_reporting")

  # Adding some fields
  outbreak_reports_events <- outbreak_reports_events |>
    mutate(follow_up_number = ifelse(str_detect(report_type, "immediate notification"), 0, str_extract(report_type, "[[:digit:]]+"))) |>
    mutate(is_final_report = str_detect(report_type, "final report")) |>
    mutate(is_endemic = str_detect(future_reporting, "the event cannot be considered resolved"))

  # Check for missing end_date
  if(suppressWarnings(is.null(outbreak_reports_events$date_event_resolved))) outbreak_reports_events$date_event_resolved <- lubridate::as_datetime(NA)
  missing_resolved <- outbreak_reports_events |>
    filter(is.na(date_event_resolved)) |>
    filter(is_final_report)

  if(nrow(missing_resolved)){
    # Check threads to confirm these are final. If they are, then assume last report is the end date.
    check_final <- outbreak_reports_events |>
      select(report_id, outbreak_thread_id, report_date) |>
      filter(outbreak_thread_id %in% missing_resolved$outbreak_thread_id) |>
      left_join(missing_resolved |> select(report_id, is_final_report),  by = "report_id") |>
      mutate(is_final_report = coalesce(is_final_report, FALSE)) |>
      group_by(outbreak_thread_id) |>
      mutate(check = report_date == max(report_date)) |>
      ungroup() |>
      mutate(confirm_final = is_final_report == check)

    check_final_resolved <- check_final |>
      filter(is_final_report, check)
    check_final_unresolved <- check_final |>
      filter(is_final_report, !check)

    outbreak_reports_events <- outbreak_reports_events |>
      mutate(date_event_resolved = if_else(report_id %in% check_final_resolved$report_id, report_date, date_event_resolved))
  }

  # Disease standardization
  # disease_export <- outbreak_reports_events |>
  #   distinct(disease, causal_agent) |>
  #   mutate_all(~tolower(trimws(.)))
  # write_csv(disease_export, here::here("inst/diseases/outbreak_report_diseases.csv"))

  ando_disease_lookup <- readxl::read_xlsx(here::here("inst", "ando_disease_lookup.xlsx")) |> # this can be manually edited
    mutate(disease = textclean::replace_non_ascii(disease)) |>
    rename(disease_class = class_desc) |>
    filter(report == "animal") |>
    select(-report, -no_match_found) |>
    mutate_at(.vars = c("ando_id", "preferred_label", "disease_class"), ~na_if(., "NA"))

  outbreak_reports_events <- outbreak_reports_events |>
    mutate(disease = trimws(disease)) |>
    mutate(disease = textclean::replace_non_ascii(disease)) |>
    mutate(disease = ifelse(disease == "", causal_agent, disease)) |>
    mutate(disease = str_remove_all(disease, "\\s*\\([^\\)]+\\)")) |>
    mutate(disease = str_remove(disease, "virus")) |>
    mutate(disease = trimws(disease)) |>
    left_join(ando_disease_lookup, by = "disease") |>
    mutate(disease = coalesce(preferred_label, disease)) |>
    select(-preferred_label) |>
    distinct()

  diseases_unmatched <- outbreak_reports_events |>
    filter(is.na(ando_id)) |>
    distinct(disease) |>
    mutate(table = "outbreak_animal")

  # outbreak_reports_details_raw -------------------------------------------------------------------------
  # First implement renaming and other edits that had previously been done prior to saving raw data
  outbreak_reports_detail <- outbreak_reports_details_raw |>
    select(-starts_with("total_")) |> # these are rolling and values and may cause confusion
    rename(outbreak_location_id = oie_reference) |>
    mutate_at(vars(suppressWarnings(one_of("susceptible", "cases", "deaths", "killed_and_disposed", "slaughtered_for_commercial_use"))), ~replace_na(., 0))

  cnames <- colnames(outbreak_reports_detail)

  if("wildlife_type" %in% cnames & "type_of_wildlife" %in% cnames){
    outbreak_reports_detail <- outbreak_reports_detail |>
      mutate(wildlife_type = coalesce(wildlife_type, type_of_wildlife)) |>
      select(-type_of_wildlife)
  }
  if(!"wildlife_type" %in% cnames & "type_of_wildlife" %in% cnames){
    outbreak_reports_detail <- outbreak_reports_detail |>
      rename(wildlife_type = type_of_wildlife)
  }

  # combine details and events -------------------------------------------------------------------------

  # Note both duration_in_days and interval can't be zero.
  wahis_raw <- outbreak_reports_detail |>
    left_join(outbreak_reports_events, by = "report_id") |>
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
      unique_id,
      source,
      outbreak_thread_id,
      outbreak_location_id,
      latitude,
      longitude,
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
    ungroup()

  wahis_time_series
}
