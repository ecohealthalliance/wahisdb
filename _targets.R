library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

#TODO run automation
#TODO Document - db tables and automation
#TODO synchronize disease lookup - currently some is done in transform reports, rest is done in downstream dtra-ml function. let's keep it all downstream.

db_branch = "main"
nproc = 1
run_cue <- "always"#Sys.getenv("TARGETS_DATA_CUE", unset = "thorough") # "thorough" when developing. "always" in CI.

wahis <- tar_plan(

  # Disease Key
  tar_target(disease_key_file, "inst/disease_key.csv", format = "file", repository = "local", cue = tar_cue(run_cue)),
  tar_target(disease_key, suppressMessages(read_csv(disease_key_file) |> filter(source == "oie") |> mutate(source = "wahis")), cue = tar_cue(run_cue)),
  tar_target(disease_key_in_db, add_data_to_db(data = list("disease_key" = disease_key), db_branch), cue = tar_cue(run_cue)),

  # Get full list of available outbreak reports from wahis API
  tar_target(wahis_outbreak_reports_list, scrape_wahis_outbreak_report_list(), cue = tar_cue(run_cue)),

  # Determine which of these reports have not been previously processed (check outbreak_reports_ingest_status_log)
  tar_target(wahis_outbreak_reports_new, id_wahis_outbreak_reports_new(wahis_outbreak_reports_list, db_branch), cue = tar_cue(run_cue)),

  # Fetch these new reports (or a subsample for testing)
  tar_target(wahis_outbreak_reports_responses, fetch_wahis_outbreak_reports_responses(wahis_outbreak_reports_new, # input list of reports to fetch
                                                                                      test_max_reports = 10), cue = tar_cue(run_cue)), # set to NULL if not in testing mode
  # Update the reports list with the fetched reports
  tar_target(wahis_outbreak_reports_list_updated, update_wahis_outbreak_reports_list(wahis_outbreak_reports_responses, # API responses for fetched reports
                                                                                     wahis_outbreak_reports_new), cue = tar_cue(run_cue)), # list of fetched reports
  # Process API responses into outbreak data - returns list of tables
  tar_target(wahis_outbreak_data_raw, process_wahis_outbreak_data_raw(wahis_outbreak_reports_responses,  # API responses for fetched reports
                                                                      wahis_outbreak_reports_list,   # full outbreak report list for lookup in transform function
                                                                      wahis_outbreak_reports_list_updated,
                                                                      nproc = nproc), cue = tar_cue(run_cue)), # This lets us use parallel processing
  # Add to database
  tar_target(wahis_outbreak_data_raw_in_db, add_wahis_outbreak_data_to_db(wahis_outbreak_data_raw, db_branch), cue = tar_cue(run_cue)),

  # Now do some cleaning to get outbreak tables (summary and time series)
  tar_target(wahis_outbreak_data, generate_wahis_outbreak_data(db_branch,
                                                               wahis_outbreak_data_raw_in_db), cue = tar_cue(run_cue)), # enforce dependency on raw data being in db

  # Add to database
  tar_target(wahis_outbreak_data_in_db, add_data_to_db(wahis_outbreak_data, db_branch), cue = tar_cue(run_cue))

)

list(wahis)
