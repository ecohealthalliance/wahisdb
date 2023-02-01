#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param data
#' @param db_branch
#' @return
#' @author Emma Mendelsohn
#' @export
add_data_to_db <- function(data, primary_key_lookup = NULL, db_branch, ...) {

  dolt_checkout(db_branch)
  conn <- dolt()

  # old <- dbReadTable(conn, "outbreak_reports_events_raw")
  # new <- data[[ "outbreak_reports_events_raw"]]


  purrr::iwalk(data, function(table, tname) {
    print(glue::glue("Adding {tname} to db"))
    pk <- primary_key_lookup[tname]
    dbAddData(conn,
              name = tname,
              value = table,
              primary_key = pk,
              update_types = FALSE)
  })

  data_in_db <- dolt_state(conn = conn)
  dbDisconnect(conn)
  data_in_db
}

