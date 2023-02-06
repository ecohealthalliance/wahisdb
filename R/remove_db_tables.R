#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param db_branch
#' @param wahis_outbreak_data
#' @return
#' @author Emma Mendelsohn
#' @export
remove_db_tables <- function(db_branch, data) {


  dolt_checkout(db_branch)
  conn <- dolt()

  purrr::iwalk(data, function(table, tname) {
    if(nrow(table)){
    dbRemoveTable(conn, tname)
    }
  })

  dolt_state(conn = conn)


}
