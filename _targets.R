library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "main"
run_cue <- Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahisdb <- tar_plan(

  # Read in extracts ---------------------------------------------------------

  ## Events/outbreaks
  ## Currently this reads a static saved file from the WAHIS sharepoint
  tar_target(outbreak_events_file, "wahis-extracts/infur_20240325.xlsx",
             format = "file",
             repository = "local"),
  tar_target(outbreak_events_extract, readxl::read_excel(outbreak_events_file, sheet = 2)),

  ## Six month disease status
  ## Currently this reads a static saved file
  ## https://wahis.woah.org/#/dashboards/country-or-disease-dashboard
  ## Disease status by semester, country, disease, animal_category (wild/domestic)
  tar_target(six_month_status_file, "wahis-extracts/e9aec3a2-0481-4f46-a97c-9ab2f1c8cd1b.xlsx",
             format = "file",
             repository = "local"),
  tar_target(six_month_status_extract, readxl::read_excel(six_month_status_file, sheet = 1)),

  ## Six month bio controls
  ## Currently this reads a static saved file
  ## from https://wahis.woah.org/#/dashboards/control-measure-dashboard
  ## Disease controls applied by semester, country, disease, animal_category (wild/domestic), and species
  tar_target(six_month_controls_file, "wahis-extracts/e9cd71f0-1943-4bf4-b485-4c743a2ed3d6.xlsx",
             format = "file",
             repository = "local"),
  tar_target(six_month_controls_extract, readxl::read_excel(six_month_controls_file, sheet = 1)),

  ## Six month quantitative
  ## Currently this reads a static saved file
  ## from https://wahis.woah.org/#/dashboards/qd-dashboard
  ## The quantitative data dashboard provides aggregated data from events reports and six monthly reports.
  ## Its limitation is that it's broken down by semester and doesn't provide further outbreaks details such as geographical coordinates etc.
  ## Case counts and other metrics by semester, country, disease, serotype, animal_category (wild/domestic), species, outbreak_id, event_id, administrative_division
  tar_target(six_month_quantitative_file, "wahis-extracts/ac264b00-8a95-4241-9739-523be38abf4c.xlsx",
             format = "file",
             repository = "local"),
  tar_target(six_month_quantitative_extract, readxl::read_excel(six_month_quantitative_file, sheet = 1)),

  # Field name checks ---------------------------------------------------------

  ## Check current data fields against previous version - throws error if any of the fields are not as expected
  tar_target(
    name = wahis_datasets_check,
    command = check_data_fields(
      outbreak_events_extract,
      six_month_status_extract,
      six_month_controls_extract,
      six_month_quantitative_extract,
      db_branch = db_branch)
  ),

  # Read in manually-curated standardization files  ---------------------------------------------------------

  ## Disease key
  tar_target(disease_key_file, "keys/disease_key.csv",
             format = "file",
             repository = "local"),
  tar_target(disease_key, readr::read_csv(disease_key_file) |>
               select(-standardized_disease_name_alt) |>
               distinct() |>
               mutate(standardized_disease_name = tolower(standardized_disease_name))),

  ## Taxon key
  tar_target(taxon_key_file, "keys/taxon_key.csv",
             format = "file",
             repository = "local"),
  tar_target(taxon_key, readr::read_csv(taxon_key_file)),


  # Process data ---------------------------------------------------------
  ## Include wahis_datasets_check to enforce order (field name checks before processing)

  ## Process outbreak_events_extract into separate event and outbreak tables, standardize taxon and diseases
  tar_target(outbreak_events_tables, create_outbreak_events_tables(outbreak_events_extract, disease_key, taxon_key,
                                                                   wahis_datasets_check)),
  tar_target(outbreak_table, outbreak_events_tables$outbreaks),
  tar_target(events_table, outbreak_events_tables$events),
  tar_target(outbreak_events_schema_raw, outbreak_events_tables$outbreak_events_schema_raw),

  ## Process six_month_status_extract, standardize diseases
  tar_target(six_month_status_tables, create_six_month_table(six_month_extract = six_month_status_extract,
                                                             table_name = "six_month_status",
                                                             unique_ids = c("year", "semester_code", "country", "disease", "animal_category"),
                                                             disease_key,
                                                             taxon_key,
                                                             wahis_datasets_check)),
  tar_target(six_month_status_table, six_month_status_tables$table),
  tar_target(six_month_status_schema_raw, six_month_status_tables$schema_raw),

  ## Process six_month_controls_extract, standardize diseases and taxon
  tar_target(six_month_controls_tables, create_six_month_table(six_month_extract = six_month_controls_extract,
                                                               table_name = "six_month_controls",
                                                               unique_ids = c("year", "semester_code", "country", "disease", "animal_category", "species", "control_measure_code"),
                                                               disease_key,
                                                               taxon_key,
                                                               wahis_datasets_check)),
  tar_target(six_month_controls_table, six_month_controls_tables$table),
  tar_target(six_month_controls_schema_raw, six_month_controls_tables$schema_raw),

  ## Process six_month_quantitative_extract, standardize diseases and taxon
  tar_target(six_month_quantitative_tables, create_six_month_table(six_month_extract = six_month_quantitative_extract,
                                                                   table_name = "six_month_quantitative",
                                                                   unique_ids = c("year", "semester_code", "country", "disease", "serotype_subtype_genotype", "animal_category", "species", "epi_event_id", "outbreak_id", "administrative_division"),
                                                                   disease_key,
                                                                   taxon_key,
                                                                   wahis_datasets_check)),
  tar_target(six_month_quantitative_table, six_month_quantitative_tables$table),
  tar_target(six_month_quantitative_schema_raw, six_month_quantitative_tables$schema_raw),


  # Schema ---------------------------------------------------------

  ## Read wahis-generated schema (this can also come from the sharepoint pull)
  tar_target(schema_extract_file, "wahis-extracts/Field_description.xlsx", format = "file", repository = "local"), # this is extracted from the WAHIS sharepoint
  tar_target(schema_extract, readxl::read_excel(schema_extract_file)),
  tar_target(schema_fields, process_schema(schema_extract,
                                           outbreak_events_tables,
                                           six_month_status_tables,
                                           six_month_controls_tables,
                                           six_month_quantitative_tables,
                                           disease_key,
                                           taxon_key)),
  tar_target(schema_tables, create_table_schema()),


  # Add everything to the database  ---------------------------------------------------------

  tar_target(keys_in_db, add_data_to_db(data = list("disease_key" = disease_key,
                                                    "taxon_key" = taxon_key),
                                        primary_key_lookup = c("disease_key" = "disease",
                                                               "taxon_key" = "taxon"),
                                        db_branch = db_branch)),

  tar_target(wahis_tables_in_db, add_data_to_db(data = list("wahis_epi_events" = events_table,
                                                                      "wahis_outbreaks" = outbreak_table,
                                                                      "wahis_six_month_status" = six_month_status_table,
                                                                      "wahis_six_month_controls" = six_month_controls_table,
                                                                      "wahis_six_month_quantitative" = six_month_quantitative_table),
                                                          primary_key_lookup = c("wahis_epi_events" = "epi_event_id_unique",
                                                                                 "wahis_outbreaks" = "report_outbreak_species_id_unique",
                                                                                 "wahis_six_month_status" = "six_month_status_unique_id",
                                                                                 "wahis_six_month_controls" = "six_month_controls_unique_id",
                                                                                 "wahis_six_month_quantitative" = "six_month_quantitative_unique_id"
                                                          ),
                                                          db_branch = db_branch)),


  tar_target(schema_in_db, add_data_to_db(data = list("schema_tables" = schema_tables,
                                                      "schema_fields" = schema_fields),
                                          primary_key_lookup = c("schema_tables" = "table_name",
                                                                 "schema_fields" = "id"),
                                          db_branch)),

  # Set foreign keys
  tar_target(wahis_tables_in_db_with_foreign_keys,
             set_foreign_keys(wahis_tables_in_db,
                              db_branch = db_branch)),

  # README ---------------------------------------------------------
  # tar_render(readme, path = "README.Rmd", knit_root_dir = here::here())

)

list(wahisdb)
