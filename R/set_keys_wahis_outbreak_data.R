#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param wahis_outbreak_data
#' @return
#' @author Emma Mendelsohn
#' @export
set_keys_wahis_outbreak_data <- function(wahis_db_check, wahis_outbreak_data_in_db) {

  if(!wahis_db_check) return()

  dolt_checkout(db_branch)
  conn <- dolt()

  # primary keys
  assign_pk(conn, "outbreak_reports_ingest_status_log", "report_info_id")
  assign_pk(conn, "outbreak_reports_events_raw", "report_id")
  assign_pk(conn, "outbreak_reports_details_raw", "id")
  assign_pk(conn, "outbreak_summary", "outbreak_thread_id")
  assign_pk(conn, "outbreak_time_series", "id")

  # foreign keys
  assign_fk(conn, "outbreak_reports_events_raw",  "report_info_id",
            "outbreak_reports_ingest_status_log", "report_info_id")

  assign_fk(conn, "outbreak_reports_details_raw",  "report_id",
            "outbreak_reports_events_raw", "report_id")

  assign_fk(conn, "outbreak_time_series",  "outbreak_thread_id",
            "outbreak_summary", "outbreak_thread_id")

  # assign multiple outbreak thread IDs (event_id_oie_reference) from ingest log to the outbreak_summary table
  # This doesn't work because some of event_id_oie_reference is not in outbreak_summary$outbreak_thread_id
  # assign_fk(conn, "outbreak_reports_ingest_status_log",  "event_id_oie_reference",
  #           "outbreak_summary", "outbreak_thread_id")

}

assign_pk <- function(conn, table, table_field){
  data_types <- dbDataType(conn, dbReadTable(conn, table))[table_field]
  dbExecute(conn, glue::glue("alter table {table} modify {table_field} {data_types} NOT NULL"))
  dbExecute(conn, glue::glue("alter table {table} add constraint pk_{table} primary key ({table_field})"))
}

assign_fk <- function(conn, table, table_field, foreign, foreign_field){
  dbExecute(conn, glue::glue("alter table {table} add constraint fk_{table}_{table_field} foreign key ({table_field}) references {foreign} ({foreign_field})"))
}

