#' @title
#' @param wahis_outbreak_data_raw
#' @return
#' @export
prep_wahis_outbreak_data_raw <- function(wahis_outbreak_data_raw) {

  if(is.null(wahis_outbreak_data_raw)) return(NULL)

  # primary key for outbreak_reports_ingest_status_log
  wahis_outbreak_data_raw$outbreak_reports_ingest_status_log <- wahis_outbreak_data_raw$outbreak_reports_ingest_status_log |>
    select(report_info_id, everything())

  # outbreak_reports_events_raw - first filter out some administrative, unwieldy columns
  wahis_outbreak_data_raw$outbreak_reports_events_raw <- wahis_outbreak_data_raw$outbreak_reports_events_raw |>
    dplyr::select(-all_of(starts_with("sender_"))) |>
    dplyr::select(-one_of("send_path")) |>
    dplyr::select(-one_of("description"))  # too long, this info should be avail elsewhere

  # outbreak_reports_details_raw
  if(is.null( wahis_outbreak_data_raw[["outbreak_reports_details_raw"]])) {
    message("outbreak_reports_details_raw was NULL")
  }else{
    wahis_outbreak_data_raw$outbreak_reports_details_raw <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      mutate(id = paste0(report_id, outbreak_location_id, species_name)) |>
      dplyr::select(id, everything()) |>
      dplyr::select(-one_of("affected_desc")) |>
      distinct()

    outbreak_reports_details_raw_dup_ids <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      janitor::get_dupes(id) |>
      pull(id) |>
      unique()

    wahis_outbreak_data_raw$outbreak_reports_details_raw <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      filter(!id %in% outbreak_reports_details_raw_dup_ids) # handful of dupes, removed
  }

  # outbreak_reports_diseases_unmatched
  if(is.null( wahis_outbreak_data_raw[["outbreak_reports_diseases_unmatched"]])) {
    message("outbreak_reports_diseases_unmatched was NULL.")
  }else{
    wahis_outbreak_data_raw$outbreak_reports_diseases_unmatched <- wahis_outbreak_data_raw$outbreak_reports_diseases_unmatched |> distinct(disease)
  }

  wahis_outbreak_data_raw
}
