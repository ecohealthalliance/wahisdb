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
add_data_to_db <- function(data, db_branch, ...) {

  dolt_checkout(db_branch)
  conn <- dolt()

  purrr::iwalk(data, function(tinf, tname) {
    print(glue::glue("Adding {tname} to db"))
    dbAddData(conn,
              name = tname,
              value = tinf$table,
              update_types = FALSE,
              primary_key = tinf$primary_key,
              foreign_key = tinf$foreign_key)
  })

  data_in_db <- dolt_state(conn = conn)
  dbDisconnect(conn)
  data_in_db
}

update_dolt_field_types <- function(conn, name, value) {
  df_field_types <- dbDataType(conn, value)
  df_field_maxsizes <- attr(df_field_types, "max_size")
  db_field_types <- dbGetQuery(conn,
                               glue::glue_sql("select column_name,data_type from information_schema.columns where table_name = {name}", .con = conn)) %>%
    rename_with(tolower) |>
    mutate(data_type = stringi::stri_trans_tolower(data_type)) %>%
    pull(data_type, name = column_name)
  stopifnot(length(df_field_types) == length(db_field_types))
  db_field_maxsizes <- dolt_type_sizes(db_field_types)
  for(i in seq_along(db_field_types)) {
    if (isTRUE(df_field_maxsizes[i] > db_field_maxsizes[i])) {
      dbExecute(conn,  glue::glue("alter table {name} modify {names(db_field_types)[i]} {df_field_types[i]}"))
    }
  }

}

