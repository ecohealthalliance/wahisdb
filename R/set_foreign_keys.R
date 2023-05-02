#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param wahis_tables_in_db
#' @param disease_key_in_db
#' @return
#' @author Emma Mendelsohn
#' @export
set_foreign_keys <- function(wahis_tables_in_db, db_branch) {

  message("setting foreign keys")
  dolt_checkout(db_branch)
  conn <- dolt()

  # foreign keys
  assign_fk(conn, table = "wahis_outbreaks",  table_field = "epi_event_id_unique",
            foreign = "wahis_epi_events", foreign_field = "epi_event_id_unique")

  data_in_db <- dolt_state(conn = conn)
  dbDisconnect(conn)
  data_in_db

}

assign_fk <- function(conn, table, table_field, foreign, foreign_field){
  tryCatch(dbExecute(conn, glue::glue("alter table {table} add constraint fk_{table}_{table_field} foreign key ({table_field}) references {foreign} ({foreign_field})")), error=function(e) e, warning=function(w) w)
}
