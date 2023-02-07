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
    dplyr::select(-one_of("description")) |> # too long, this info should be avail elsewhere
    dplyr::select(-one_of("report_desc"))   # too long, this info should be avail elsewhere

  # outbreak_reports_details_raw
  if(is.null( wahis_outbreak_data_raw[["outbreak_reports_details_raw"]])) {
    message("outbreak_reports_details_raw was NULL")
  }else{
    wahis_outbreak_data_raw$outbreak_reports_details_raw <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      mutate(unique_id = paste(report_id,
                               oie_reference,
                               str_extract(species_name, "^[^\\(]+"),
                               sep = "_")) |> # report, thread and taxa
      mutate(unique_id = str_trim(unique_id)) |> # make_clean_names handles dupes
      dplyr::select(unique_id, report_id, oie_reference, species_name, everything()) |>
      dplyr::select(-one_of("affected_desc")) |>
      distinct()

    # ID any dupes
    outbreak_reports_details_raw_dups <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
      janitor::get_dupes(unique_id)

    # Mark unique_id's as dupes
    if(nrow(outbreak_reports_details_raw_dups)){
      outbreak_reports_details_raw_dups_fix <- outbreak_reports_details_raw_dups |>
        group_split(unique_id) |>
        map_dfr(function(x){
          mutate(x, unique_id = paste0(unique_id, "_DUPE_", row_number()))
        })

      wahis_outbreak_data_raw$outbreak_reports_details_raw <- wahis_outbreak_data_raw$outbreak_reports_details_raw |>
        filter(!unique_id %in% unique(outbreak_reports_details_raw_dups$unique_id)) |>
        bind_rows(outbreak_reports_details_raw_dups_fix)

      warning(paste("identified", n_distinct(outbreak_reports_details_raw_dups$unique_id), "duplicate IDs in outbreak_reports_details_raw"))

    }
  }

  # order matters
  list(
    outbreak_reports_ingest_status_log = wahis_outbreak_data_raw$outbreak_reports_ingest_status_log,
    outbreak_reports_events_raw = wahis_outbreak_data_raw$outbreak_reports_events_raw,
    outbreak_reports_details_raw = wahis_outbreak_data_raw$outbreak_reports_details_raw
  )

}
