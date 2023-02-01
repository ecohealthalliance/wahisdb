#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param wahis_outbreak_data
#' @return
#' @author Emma Mendelsohn
#' @export
set_foreign_keys_wahis_outbreak_data <- function(wahis_db_check, wahis_outbreak_data_in_db, disease_key_in_db) {

  if(!wahis_db_check) return(message("skipping set_foreign_keys_wahis_outbreak_data"))

  message("setting foreign keys")
  dolt_checkout(db_branch)
  conn <- dolt()

  # foreign keys
  assign_fk(conn, "outbreak_reports_events_raw",  "report_info_id",
            "outbreak_reports_ingest_status_log", "report_info_id")

  assign_fk(conn, "outbreak_reports_details_raw",  "report_id",
            "outbreak_reports_events_raw", "report_id")

  assign_fk(conn, "outbreak_summary",  "disease",
            "disease_key", "disease")

  assign_fk(conn, "outbreak_time_series",  "outbreak_thread_id",
            "outbreak_summary", "outbreak_thread_id")

  assign_fk(conn, "outbreak_time_series",  "unique_id",
            "outbreak_reports_details_raw", "unique_id")

  #TODO connect event_id_oie_reference from outbreak_reports_ingest_status_log with outbreak_thread_id from outbreak_summary
  # in current form this cannot be done because
  # a) outbreak_reports_ingest_status_log has event_id_oie_reference values that are not in outbreak_summary (therefore outbreak_summary cannot be the reference)
  # b) there are dublicate values of event_id_oie_reference in outbreak_reports_ingest_status_log because the log tracks reports which can cover a single outbreak there (therefore outbreak_reports_ingest_status_log cannot be the ref)
  # solution would be a lookup table for the threads


}

# assign_pk <- function(conn, table, table_field){
#   data_types <- dbDataType(conn, dbReadTable(conn, table))[table_field]
#   dbExecute(conn, glue::glue("alter table {table} modify {table_field} {data_types} NOT NULL"))
#   dbExecute(conn, glue::glue("alter table {table} add constraint pk_{table} primary key ({table_field})"))
# }

assign_fk <- function(conn, table, table_field, foreign, foreign_field){
  dbExecute(conn, glue::glue("alter table {table} add constraint fk_{table}_{table_field} foreign key ({table_field}) references {foreign} ({foreign_field})"))
}

