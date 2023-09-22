library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "six-month-tweaks"
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

  # Event/Outbreak Reports ---------------------------------------------------------

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

  # Six Month Reports ---------------------------------------------------------

  # Currently this reads a static saved file
  # https://wahis.woah.org/#/dashboards/country-or-disease-dashboard
  # Disease status by semester, country, disease, animal_category (wild/domestic)
  tar_target(six_month_status_file, "wahis-extracts/4a115a74-6ad4-4031-94a4-2f48256f09d1.xlsx",
             format = "file",
             repository = "local", cue = tar_cue("thorough")),
  tar_target(six_month_status_extract, readxl::read_excel(six_month_status_file, sheet = 1), cue = tar_cue("thorough")),

  # Currently this reads a static saved file
  # from https://wahis.woah.org/#/dashboards/control-measure-dashboard
  # Disease controls applied by semester, country, disease, animal_category (wild/domestic), and species
  tar_target(six_month_controls_file, "wahis-extracts/088b3012-d64a-45d8-8997-87f8d9123f4e.xlsx",
             format = "file",
             repository = "local", cue = tar_cue("thorough")),
  tar_target(six_month_controls_extract, readxl::read_excel(six_month_controls_file, sheet = 1), cue = tar_cue("thorough")),

  # Currently this reads a static saved file
  # from https://wahis.woah.org/#/dashboards/qd-dashboard
  # The quantitative data dashboard provides aggregated data from events reports and six monthly reports.
  # Its limitation is that it's broken down by semester and doesn't provide further outbreaks details such as geographical coordinates etc.
  # Case counts and other metrics by semester, country, disease, serotype, animal_category (wild/domestic), species, outbreak_id, administrative_division
  tar_target(six_month_quantiative_file, "wahis-extracts/c940c93d-474e-4c94-b1de-82cb4f0522f0.xlsx",
             format = "file",
             repository = "local", cue = tar_cue("thorough")),
  tar_target(six_month_quantiative_extract, readxl::read_excel(six_month_quantiative_file, sheet = 1), cue = tar_cue("thorough")),


  # Process
  tar_target(six_month_tables, create_six_month_tables(six_month_status_extract, six_month_controls_extract, six_month_quantiative_extract, ando_lookup, disease_key), cue = tar_cue(run_cue)),

  # Add to database
  tar_target(six_month_tables_in_db, add_data_to_db(data = six_month_tables,
                                                    primary_key_lookup = c("six_month_status" = "six_month_status_unique_id",
                                                                           "six_month_controls" = "six_month_controls_unique_id",
                                                                           "six_month_quantiative" = "six_month_quantiative_unique_id"),
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
