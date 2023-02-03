suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

conn <- dolt()
tbs <-
  map_dfr(dbListTables(conn),
          ~dbGetQuery(conn, glue::glue("SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_name = '{.}'"))
  ) |>
  janitor::clean_names()

write_csv(tbs, "inst/schema_export.csv")
