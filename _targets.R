library(targets)
suppressPackageStartupMessages(
  targets::tar_source(c("packages.R", "R"))
)

#TODO migrate disease name lookup
#TODO commit targets to DB and push to dolthub
#TODO run automation

db_branch = "main"
nproc = 1

wahis <- tar_plan(
  tar_target(wahis_outbreak_reports_list, scrape_outbreak_report_list(),  cue = tar_cue("thorough")), # get full list of available outbreak reports from wahis API
  tar_target(wahis_outbreak_reports_new, wahis_get_outbreak_reports_new(wahis_outbreak_reports_list, db_branch), # determine which of these reports have not been previously processed
             cue = tar_cue("thorough")),
  tar_target(wahis_outbreak_reports_responses, wahis_get_outbreak_reports_responses(wahis_outbreak_reports_new, # input list of reports to fetch
                                                                                    test_max_reports = 10), # set to NULL if not in testing mode
             cue = tar_cue("thorough")),
  tar_target(wahis_outbreak_reports_list_updated, wahis_update_outbreak_reports_list(wahis_outbreak_reports_responses, # API responses for fetched reports
                                                                                     wahis_outbreak_reports_new), # list of fetched reports
             cue = tar_cue("thorough")),
  tar_target(wahis_outbreak_data, process_wahis_outbreak_data(wahis_outbreak_reports_responses,  # API responses for fetched reports
                                                              wahis_outbreak_reports_list,   # full outbreak report list for lookup in transform function
                                                              wahis_outbreak_reports_list_updated,
                                                              nproc = nproc), # This lets us use parallel processing
             cue = tar_cue("thorough")), # list of fetched reports with ingest status
  # tar_target(oie_data, generate_oie_data(db_branch, wahis_outbreak_data_in_db), cue = tar_cue("thorough"))

)

list(wahis)
