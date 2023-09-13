library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "main"
nproc = 10
run_cue <- Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahisdb <- tar_plan(

  # Standardization keys ---------------------------------------------------------

  # ANDO disease lookup (leave cue as thorough because it will only be updated manually)
  tar_target(ando_lookup_file, "inst/ando_disease_lookup.xlsx", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(ando_lookup, process_ando_lookup(ando_lookup_file), cue = tar_cue("thorough")),

  # Disease Key (leave cue as thorough because it will only be updated manually)
  # Note this key builds on cleaning from ANDO standardization (Nate developed this as part of dtra-ml, eventually we should have just a single cleaning file)
  tar_target(disease_key_file, "inst/disease_key.csv", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(disease_key, process_disease_key(disease_key_file), cue = tar_cue("thorough")),

  # Outbreak events ---------------------------------------------------------

  # Currently this reads a static saved file from the WAHIS sharepoint
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

  # Six month reports ---------------------------------------------------------

  # Currently this reads a static saved file
  # https://wahis.woah.org/#/dashboards/country-or-disease-dashboard
  # But when the above was down, we acquired the data by:
  #   Go to: https://dashboards-wahis.woah.org/sense/app/d56ee542-175f-47e0-a210-61d2a976741d/sheet/33ed7149-028c-484e-aa3e-ebae6eb4be75 (which is the dashboard that is embedded in WOAH, (en-language, public version found from the hub at https://dashboards-wahis.woah.org)
  #   Click “Selections” then “Show fields” in App Dimensions, select the region(s) or other filters.  This selected all regions.
  #   Click the back button back to the app, then wait for it to load the table and the export button. (Note pop-ups must be allowed in your browser).
  tar_target(six_month_file, "wahis-extracts/4a115a74-6ad4-4031-94a4-2f48256f09d1.xlsx",
             format = "file",
             repository = "local", cue = tar_cue("thorough")),
  tar_target(six_month_extract, readxl::read_excel(six_month_file, sheet = 1), cue = tar_cue("thorough")),

  # Process
  tar_target(six_month_table, create_six_month_table(six_month_extract, ando_lookup, disease_key), cue = tar_cue(run_cue)),

  # Add to database
  tar_target(six_month_table_in_db, add_data_to_db(data = six_month_table,
                                                   primary_key_lookup = c("wahis_six_month_status" = "unique_id"),
                                                   db_branch = db_branch), cue = tar_cue(run_cue)),

  # Control measures  ---------------------------------------------------------

  # Currently this reads a static saved file
  # from https://wahis.woah.org/#/dashboards/control-measure-dashboard
  tar_target(control_measures_file, "wahis-extracts/088b3012-d64a-45d8-8997-87f8d9123f4e.xlsx",
             format = "file",
             repository = "local", cue = tar_cue("thorough")),
  tar_target(control_measures_extract, readxl::read_excel(control_measures_file, sheet = 1), cue = tar_cue("thorough")),

  # Process
  tar_target(control_measures_table, create_control_measures_table(control_measures_extract, ando_lookup, disease_key), cue = tar_cue(run_cue)),

  # Add to database
  tar_target(control_measures_table_in_db, add_data_to_db(data = control_measures_table,
                                                          primary_key_lookup = c("wahis_six_month_controls" = "unique_id"),
                                                          db_branch = db_branch), cue = tar_cue(run_cue)),


  # Schema ---------------------------------------------------------

  # Read wahis-generated schema (this can also come from the sharepoint pull)
  tar_target(schema_extract_file, "wahis-extracts/Field_description.xlsx", format = "file", repository = "local", cue = tar_cue("thorough")), # this is extracted from the WAHIS sharepoint
  tar_target(schema_extract, readxl::read_excel(schema_extract_file), cue = tar_cue("thorough")),
  tar_target(schema_fields, process_schema(schema_extract, wahis_tables, six_month_table, control_measures_table, disease_key), cue = tar_cue("thorough")),
  tar_target(schema_tables, create_table_schema(), cue = tar_cue("thorough")),

  tar_target(schema_in_db, add_data_to_db(data = list("schema_tables" = schema_tables,
                                                      "schema_fields" = schema_fields
  ),
  primary_key_lookup = c("schema_tables" = "table",
                         "schema_fields" = "id"),
  db_branch), cue = tar_cue("thorough")),

  # README ---------------------------------------------------------
  tar_render(readme, path = "README.Rmd")

)

list(wahisdb)
