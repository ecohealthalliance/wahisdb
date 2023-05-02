library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "main"
nproc = 10
run_cue <- Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahisdb <- tar_plan(

  # ANDO disease lookup (leave cue as thorough because it will only be updated manually)
  tar_target(ando_lookup_file, "inst/ando_disease_lookup.xlsx", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(ando_lookup, process_ando_lookup(ando_lookup_file), cue = tar_cue("thorough")),

  # Disease Key (leave cue as thorough because it will only be updated manually)
  # Note this key builds on cleaning from ANDO standardization (Nate developed this as part of dtra-ml, eventually we should have just a single cleaning file)
  tar_target(disease_key_file, "inst/disease_key.csv", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(disease_key, process_disease_key(disease_key_file), cue = tar_cue("thorough")),

  # TODO extract weekly data from sharepoint to tmp directory
  # Currently this reads a static saved file - it will be updated to pull the sharepoint extracts
  tar_target(wahis_extract_file, "wahis-extracts/infur_20230414.xlsx",
             format = "file",
             repository = "local", cue = tar_cue("thorough")),
  tar_target(wahis_extract, readxl::read_excel(wahis_extract_file, sheet = 2), cue = tar_cue("thorough")),

  # Process into epi_event and outbreak table
  tar_target(wahis_tables, create_wahis_tables(wahis_extract, ando_lookup, disease_key), cue = tar_cue(run_cue)),

  # Add to database
  tar_target(wahis_tables_in_db, add_data_to_db(data = wahis_tables,
                                                primary_key_lookup = c("wahis_epi_events" = "epi_event_id_unique",
                                                                       "wahis_outbreaks" = "report_outbreak_species_id_unique"),
                                                db_branch = db_branch), cue = tar_cue(run_cue)),

  # Set foreign keys
  tar_target(wahis_tables_in_db_with_foreign_keys,
             set_foreign_keys(wahis_tables_in_db,
                              db_branch = db_branch), cue = tar_cue(run_cue)),

  # Read schema (this can also come from the sharepoint pull)
  tar_target(schema_extract_file, "wahis-extracts/Field_description.xlsx", format = "file", repository = "local", cue = tar_cue("thorough")), # this is extracted from the WAHIS sharepoint
  tar_target(schema_extract, readxl::read_excel(schema_extract_file), cue = tar_cue("thorough")),
  tar_target(schema_fields, process_schema(schema_extract, wahis_tables, disease_key), cue = tar_cue("thorough")),
  tar_target(schema_tables, create_table_schema(), cue = tar_cue("thorough")),

  tar_target(schema_in_db, add_data_to_db(data = list("schema_tables" = schema_tables,
                                                      "schema_fields" = schema_fields
                                                      ),
                                          primary_key_lookup = c("schema_tables" = "table",
                                                                 "schema_fields" = "id"),
                                          db_branch), cue = tar_cue("thorough")),

  # README
  tar_render(readme, path = "README.Rmd")

)

list(wahisdb)
