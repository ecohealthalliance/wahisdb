#' Adds a table to a database, updating records with matching primary keys and
#' appending additional ones. Changes data types if required for expanding
#' limited-size (text and blob) fields
dbAddData <- function(conn,
                      name,
                      value,
                      primary_key,
                      add_new_cols = TRUE,
                      update_types = TRUE,
                      batch_size = 1000){

  if(is.null(value)) return(message(paste(name, "is NULL, no updates to database")))
  if(nrow(value)==0) return(message(paste(name, "has 0 rows, no updates database")))

  # Create new table if needed
  if(!dbExistsTable(conn, name)) {
    data_types <- dbDataType(conn, value)
    dbCreateTable(conn, name, data_types)
    for(idf in primary_key) {
      dbExecute(conn, glue::glue("alter table {name} modify {idf} {data_types[idf]} NOT NULL"))
    }
    dbExecute(conn, glue::glue("alter table {name} add constraint pk_{name} primary key ({glue::glue_collapse(primary_key, ',')})")) # can be more than one field
    dbxInsert(conn, name, value, batch_size)
    # Otherwise check if we need new columns in the table and add them
  } else {
    sql_table <- tbl(conn, name)
    if(!add_new_cols){
      assert_that(identical(sort(colnames(sql_table)), sort(colnames(value))))
    } else {
      add_cols_to_table_content <- setdiff(colnames(sql_table), colnames(value))
      value[,add_cols_to_table_content] <- NA
      add_cols_to_existing <- setdiff(colnames(value), colnames(sql_table))
      new_col_types <- dbDataType(conn, value[add_cols_to_existing])
      for(i in seq_along(add_cols_to_existing)) {
        dbExecute(conn, glue::glue("alter table {name} add column {add_cols_to_existing[i]} {new_col_types[i]}"))
      }
      sql_table <- tbl(conn, name)
      assert_that(identical(sort(colnames(sql_table)), sort(colnames(value))))
    }

    # update field types as needed if text or blob sizes aren't sufficient
    if (update_types) {
      update_dolt_field_types(conn, name, value)
    }

    dbxUpsert(conn, table = name, records = value, where_cols = primary_key,
              batch_size = batch_size)
  }
  NULL
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


