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
