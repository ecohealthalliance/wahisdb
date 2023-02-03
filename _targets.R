library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

db_branch = "main"
nproc = 10
run_cue <- Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahisdb <- tar_plan(

  # Disease Key (leave cue as thorough because it will only be updated manually)
  tar_target(disease_key_file, "inst/disease_key.csv", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(disease_key, suppressMessages(read_csv(disease_key_file) |> filter(source == "oie") |> mutate(source = "wahis")), cue = tar_cue("thorough")),
  tar_target(disease_key_in_db, add_data_to_db(data = list("disease_key" = disease_key),
                                               primary_key_lookup = c("disease_key" = "disease"),
                                               db_branch), cue = tar_cue('thorough')),

  # Is this the first time adding to db?
  tar_target(wahis_db_check, {dolt_checkout(db_branch); length(dbListTables(dolt())) <= 1},
             cue = tar_cue("always")),

  # Get full list of available outbreak reports from wahis API
  tar_target(wahis_outbreak_reports_list, scrape_wahis_outbreak_report_list(), cue = tar_cue(run_cue)),

  # Determine which of these reports have not been previously processed (check outbreak_reports_ingest_status_log)
  tar_target(wahis_outbreak_reports_new, id_wahis_outbreak_reports_new(wahis_outbreak_reports_list,
                                                                       db_branch,
                                                                       test_max_reports = NULL), # set to NULL if not in testing mode
             cue = tar_cue(run_cue)),

  # Fetch these new reports (or a subsample for testing)
  tar_target(wahis_outbreak_reports_responses, fetch_wahis_outbreak_reports_responses(wahis_outbreak_reports_new), # input list of reports to fetch

             cue = tar_cue(run_cue)),

  # Update the reports list with the fetched reports
  tar_target(wahis_outbreak_reports_list_updated, update_wahis_outbreak_reports_list(wahis_outbreak_reports_responses, # API responses for fetched reports
                                                                                     wahis_outbreak_reports_new), # list of fetched reports
             cue = tar_cue(run_cue)),

  # Process API responses into outbreak data - returns list of tables - limited transformation of raw data
  tar_target(wahis_outbreak_data_raw, transform_wahis_outbreak_data_raw(wahis_outbreak_reports_responses,  # API responses for fetched reports
                                                                        wahis_outbreak_reports_list,   # full outbreak report list for lookup in transform function
                                                                        wahis_outbreak_reports_list_updated,
                                                                        nproc = nproc),
             cue = tar_cue(run_cue)),

  # Minor cleaning and checks
  tar_target(wahis_outbreak_data_raw_prepped, prep_wahis_outbreak_data_raw(wahis_outbreak_data_raw),
             cue = tar_cue(run_cue)),

  # Set primary keys
  tar_target(wahis_outbreak_data_raw_primary_keys, c("outbreak_reports_ingest_status_log" = "report_info_id",
                                                     "outbreak_reports_events_raw" = "report_id",
                                                     "outbreak_reports_details_raw" = "unique_id"),
             cue = tar_cue(run_cue)),

  # Add to database
  tar_target(wahis_outbreak_data_raw_in_db, add_data_to_db(data = wahis_outbreak_data_raw_prepped,
                                                           primary_key_lookup = wahis_outbreak_data_raw_primary_keys,
                                                           db_branch = db_branch), cue = tar_cue(run_cue)),

  # Process get outbreak tables (summary and time series)
  tar_target(wahis_outbreak_data, generate_wahis_outbreak_data(db_branch, wahis_outbreak_data_raw_in_db), cue = tar_cue(run_cue)), # enforce dependency on raw data being in db

  # Set primary keys
  tar_target(wahis_outbreak_data_primary_keys, c("outbreak_summary" = "outbreak_thread_id",
                                                 "outbreak_time_series" = "unique_id"),
             cue = tar_cue(run_cue)),

  # Add to database
  tar_target(wahis_outbreak_data_in_db, add_data_to_db(data = wahis_outbreak_data,
                                                       primary_key_lookup = wahis_outbreak_data_primary_keys,
                                                       db_branch = db_branch), cue = tar_cue(run_cue)),

  # Set all keys
  tar_target(wahis_data_in_db_with_foreign_keys, set_foreign_keys_wahis_outbreak_data(wahis_db_check, wahis_outbreak_data_in_db, disease_key_in_db)),

  # Add schema
  tar_target(schema_field_info_file, "inst/schema_field_info.xlsx", format = "file", repository = "local", cue = tar_cue("thorough")),
  tar_target(schema_table_info_file, "inst/schema_table_info.xlsx", format = "file", repository = "local", cue = tar_cue("thorough")),

  tar_target(schema_field_info, readxl::read_excel(schema_field_info_file), cue = tar_cue("thorough")),
  tar_target(schema_table_info, readxl::read_excel(schema_table_info_file), cue = tar_cue("thorough")),

  tar_target(schema_in_db, add_data_to_db(data = list("schema_table_info" = schema_table_info,
                                                      "schema_field_info" = schema_field_info),
                                          primary_key_lookup = c("schema_table_info" = "table_name",
                                                                 "schema_field_info" = "id"),
                                          db_branch), cue = tar_cue('always'))


)

list(wahisdb)
