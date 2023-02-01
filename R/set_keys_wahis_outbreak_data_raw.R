#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param wahis_outbreak_data_raw_prepped
#' @return
#' @author Emma Mendelsohn
#' @export
set_keys_wahis_outbreak_data_raw <- function(wahis_outbreak_data_raw_prepped) {


  list("outbreak_reports_ingest_status_log" =
         list(table = wahis_outbreak_data_raw_prepped$outbreak_reports_ingest_status_log,
              primary_key  = "report_info_id",
              foreign_key = NULL),

       "outbreak_reports_events_raw" =
         list(
           table = wahis_outbreak_data_raw_prepped$outbreak_reports_events_raw,
           primary_key = "report_id",
           foreign_key = tibble(table = "outbreak_reports_ingest_status_log", field =  "report_info_id")
         ),

       "outbreak_reports_details_raw" =
         list(
           table = wahis_outbreak_data_raw_prepped$outbreak_reports_details_raw,
           primary_key = "id",
           foreign_key = tibble(table = "outbreak_reports_events_raw", field =  "report_id")
         )
  )



}
