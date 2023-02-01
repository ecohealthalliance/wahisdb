delete_all <- function() {
  try(walk(dbListTables(dolt()), ~dbRemoveTable(dolt(), .)))

  try( walk(rev(dbListTables(dolt())), ~dbRemoveTable(dolt(), .)))
}
