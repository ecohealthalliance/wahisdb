library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "main"
nproc = 10
run_cue <- Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahisdb <- tar_plan(

  # Event Reports ---------------------------------------------------------

  # Currently this reads a static saved file from the WAHIS sharepoint
  tar_target(outbreak_events_file, "wahis-extracts/infur_20230414.xlsx",
             format = "file",
             repository = "local"),
  tar_target(outbreak_events_extract, readxl::read_excel(outbreak_events_file, sheet = 2)),

  # Process into epi_event and outbreak table
  tar_target(outbreak_events_tables, create_outbreak_events_tables(outbreak_events_extract)),

  # Six Month Reports ---------------------------------------------------------

  # Currently this reads a static saved file
  # https://wahis.woah.org/#/dashboards/country-or-disease-dashboard
  # Disease status by semester, country, disease, animal_category (wild/domestic)
  tar_target(six_month_status_file, "wahis-extracts/4a115a74-6ad4-4031-94a4-2f48256f09d1.xlsx",
             format = "file",
             repository = "local"),
  tar_target(six_month_status_extract, readxl::read_excel(six_month_status_file, sheet = 1)),

  # Currently this reads a static saved file
  # from https://wahis.woah.org/#/dashboards/control-measure-dashboard
  # Disease controls applied by semester, country, disease, animal_category (wild/domestic), and species
  tar_target(six_month_controls_file, "wahis-extracts/088b3012-d64a-45d8-8997-87f8d9123f4e.xlsx",
             format = "file",
             repository = "local"),
  tar_target(six_month_controls_extract, readxl::read_excel(six_month_controls_file, sheet = 1)),

  # Currently this reads a static saved file
  # from https://wahis.woah.org/#/dashboards/qd-dashboard
  # The quantitative data dashboard provides aggregated data from events reports and six monthly reports.
  # Its limitation is that it's broken down by semester and doesn't provide further outbreaks details such as geographical coordinates etc.
  # Case counts and other metrics by semester, country, disease, serotype, animal_category (wild/domestic), species, outbreak_id, administrative_division
  tar_target(six_month_quantitative_file, "wahis-extracts/c940c93d-474e-4c94-b1de-82cb4f0522f0.xlsx",
             format = "file",
             repository = "local"),
  tar_target(six_month_quantitative_extract, readxl::read_excel(six_month_quantitative_file, sheet = 1)),

  # Process
  tar_target(six_month_tables, create_six_month_tables(six_month_status_extract, six_month_controls_extract, six_month_quantitative_extract)),

  # Standardization  ---------------------------------------------------------

  # Disease key for outbreak and six month reports
  # Manually curated by N. Layman
  tar_target(disease_key_file, "keys/disease_key.csv",
             format = "file",
             repository = "local"),
  tar_target(disease_key, readr::read_csv(disease_key_file) |>
               select(-standardized_disease_name_alt) |>
               distinct()),

  # Taxon key for outbreak reports
  # TODO six month reports
  # Manually curated by N. Layman
  tar_target(taxon_key_file, "keys/taxon_key.csv",
             format = "file",
             repository = "local"),
  tar_target(taxon_key, readr::read_csv(taxon_key_file)),

  # Standardize outbreak_events tables
  tar_target(outbreak_events_tables_standardized, standardize_outbreak_events_tables(outbreak_events_tables,
                                                                                     disease_key, taxon_key)),

  # Standardize six_month tables
  # TODO still needs standardized taxa
  tar_target(six_month_tables_standardized, standardize_six_month_tables(six_month_tables,
                                                                         disease_key, taxon_key)),

  # Schema ---------------------------------------------------------

  # Read wahis-generated schema (this can also come from the sharepoint pull)
  tar_target(schema_extract_file, "wahis-extracts/Field_description.xlsx", format = "file", repository = "local"), # this is extracted from the WAHIS sharepoint
  tar_target(schema_extract, readxl::read_excel(schema_extract_file)),
  tar_target(schema_fields, process_schema(schema_extract, outbreak_events_tables_standardized, six_month_tables_standardized, disease_key, taxon_key)),
  tar_target(schema_tables, create_table_schema()),


  # Add everything to the database  ---------------------------------------------------------

  tar_target(keys_in_db, add_data_to_db(data = list("disease_key" = disease_key,
                                                    "taxon_key" = taxon_key),
                                        primary_key_lookup = c("disease_key" = "disease",
                                                               "taxon_key" = "taxon"),
                                        db_branch = db_branch)),

  tar_target(outbreak_events_tables_in_db, add_data_to_db(data = outbreak_events_tables_standardized,
                                                          primary_key_lookup = c("wahis_epi_events" = "epi_event_id_unique",
                                                                                 "wahis_outbreaks" = "report_outbreak_species_id_unique"),
                                                          db_branch = db_branch)),


  tar_target(six_month_tables_in_db, add_data_to_db(data = six_month_tables_standardized,
                                                    primary_key_lookup = c("wahis_six_month_status" = "six_month_status_unique_id",
                                                                           "wahis_six_month_controls" = "six_month_controls_unique_id",
                                                                           "wahis_six_month_quantitative" = "six_month_quantitative_unique_id"),
                                                    db_branch = db_branch)),

  tar_target(schema_in_db, add_data_to_db(data = list("schema_tables" = schema_tables,
                                                      "schema_fields" = schema_fields),
                                          primary_key_lookup = c("schema_tables" = "table_name",
                                                                 "schema_fields" = "id"),
                                          db_branch)),

  # Set foreign keys
  tar_target(outbreak_events_tables_in_db_with_foreign_keys,
             set_foreign_keys(outbreak_events_tables_in_db,
                              db_branch = db_branch)),

  # README ---------------------------------------------------------
  tar_render(readme, path = "README.Rmd")

)

list(wahisdb)
