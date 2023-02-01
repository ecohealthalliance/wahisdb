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
      mutate(unique_id = paste(report_id,
                               oie_reference,
                                janitor::make_clean_names(str_extract(unique(species_name), "^[^\\(]+")),
                               sep = "_")) |> # report, thread and taxa
      dplyr::select(unique_id, report_id, oie_reference, species_name, everything()) |>
      dplyr::select(-one_of("affected_desc")) |>
      distinct()

    outbreak_reports_details_raw_dup_ids <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      janitor::get_dupes(unique_id) |>
      pull(unique_id) |>
      unique()

    assert_that(length(outbreak_reports_details_raw_dup_ids)==0)

    if(length(outbreak_reports_details_raw_dup_ids)) warning(paste("removing", length(outbreak_reports_details_raw_dup_ids), "dup IDs"))

    wahis_outbreak_data_raw$outbreak_reports_details_raw <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      filter(!unique_id %in% outbreak_reports_details_raw_dup_ids) # handful of dupes, removed
  }

  # outbreak_reports_diseases_unmatched
  # if(is.null( wahis_outbreak_data_raw[["outbreak_reports_diseases_unmatched"]])) {
  #   message("outbreak_reports_diseases_unmatched was NULL.")
  # }else{
  #   wahis_outbreak_data_raw$outbreak_reports_diseases_unmatched <- wahis_outbreak_data_raw$outbreak_reports_diseases_unmatched |> distinct(disease)
  # }

  # order matters
  list(
    outbreak_reports_ingest_status_log = wahis_outbreak_data_raw$outbreak_reports_ingest_status_log,
    outbreak_reports_events_raw = wahis_outbreak_data_raw$outbreak_reports_events_raw,
    outbreak_reports_details_raw = wahis_outbreak_data_raw$outbreak_reports_details_raw
  )

}
