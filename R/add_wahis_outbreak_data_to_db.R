#' @title
#' @param wahis_outbreak_data
#' @param db_branch
#' @return
#' @export
add_wahis_outbreak_data_to_db <- function(wahis_outbreak_data, db_branch) {

  if(is.null(wahis_outbreak_data)) return(NULL) # This target expects a report containing the hash

  # not sure what this will look like exactly, but establish db connection referencing branch/commit
  conn <- dbConnect(dolt_local())
  dolt_checkout(db_branch, conn = conn)
  # conn <- repeldata::repel_remote_conn() # temp for testing

  # outbreak_reports_ingest_status_log
  dbAddData(conn,
            name = "outbreak_reports_ingest_status_log",
            value = wahis_outbreak_data$outbreak_reports_ingest_status_log,
            primary_key = "report_info_id")

  # outbreak_reports_events_raw
  dbAddData(conn,
            name = "outbreak_reports_events_raw",
            value = wahis_outbreak_data$outbreak_reports_events_raw,
            primary_key = "report_id")

  # outbreak_reports_details_raw
  outbreak_reports_details_raw <- wahis_outbreak_data[["outbreak_reports_details_raw"]]

  if(is.null(outbreak_reports_details_raw)) {
    warning("outbreak_reports_details_raw was NULL.")
    return(NULL)
  }

  outbreak_reports_details_raw <- outbreak_reports_details_raw %>%
    mutate(id = paste0(report_id, outbreak_location_id, species_name)) %>%
    select(id, everything()) %>%
    distinct()
  outbreak_reports_details_raw_dup_ids <- outbreak_reports_details_raw %>%
    janitor::get_dupes(id) %>%
    pull(id) %>%
    unique()
  outbreak_reports_details_raw <- outbreak_reports_details_raw %>% filter(!id %in% outbreak_reports_details_raw_dup_ids)

  tname <- "outbreak_reports_details_raw"
  dbAddData(conn,
            name = tname,
            value = outbreak_reports_details_raw,
            primary_key = "id")

  # outbreak_reports_diseases_unmatched
  outbreak_reports_diseases_unmatched <- wahis_outbreak_data$outbreak_reports_diseases_unmatched

  if(is.null(outbreak_reports_diseases_unmatched)) {
    warning("outbreak_reports_diseases_unmatched was NULL")
    return(NULL)
  }

  outbreak_reports_diseases_unmatched <- outbreak_reports_diseases_unmatched %>% distinct(disease)

  wahis_outbreak_data_in_db <- dbAddData(conn,
                                         name = "outbreak_reports_diseases_unmatched",
                                         value = outbreak_reports_diseases_unmatched,
                                         primary_key = "disease")

  wahis_outbreak_data_in_db <- dolt_state(conn = conn)
  dbDisconnect(conn)
  wahis_outbreak_data_in_db


}
