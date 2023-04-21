library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "wahis-extracts"
nproc = 10
run_cue <- Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahisdb <- tar_plan(

  # Disease Key (leave cue as thorough because it will only be updated manually)
  tar_target(disease_key_file, "inst/disease_key.csv", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(disease_key, suppressMessages(read_csv(disease_key_file) |> filter(source == "oie") |> mutate(source = "wahis")), cue = tar_cue("thorough")),
  tar_target(disease_key_in_db, add_data_to_db(data = list("disease_key" = disease_key),
                                               primary_key_lookup = c("disease_key" = "disease"),
                                               db_branch), cue = tar_cue('thorough')),

  # TODO extract weekly data from sharepoint to tmp directory
  # Currently this reads a static saved file - it will be updated to pull the sharepoint extracts
  tar_target(wahis_sharepoint_extract, "wahis-extracts/infur_20230414.xlsx",
             format = "file",
             repository = "local", cue = tar_cue(run_cue)),
  tar_target(wahis_raw, readxl::read_excel(wahis_sharepoint_extract, sheet = 2), cue = tar_cue("thorough")),

  # Process into epi_event and outbreak table
  tar_target(wahis_tables, create_wahis_tables(wahis_raw), cue = tar_cue(run_cue)),

  # Set primary keys
  tar_target(wahis_primary_keys, c("wahis_epi_event" = "epi_event_id",
                                   "wahis_outbreaks" = "unique_id"),
             cue = tar_cue(run_cue)),

  # Add to database
  tar_target(wahis_tables_in_db, add_data_to_db(data = wahis_tables,
                                                primary_key_lookup = wahis_primary_keys,
                                                db_branch = db_branch), cue = tar_cue(run_cue)),

  # TODO clean disease name and species
  # TODO schema
  # TODO readme

)

list(wahisdb)
