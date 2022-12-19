#' Determine which outbreak reports need to be pulled from WAHIS
#' report_info_id can be appended to "https://wahis.oie.int/pi/getReport/" to access the report API,
#' and to "https://wahis.oie.int/#/report-info?reportId=" to see the formatted outbreak report.
#' @title wahis_get_outbreak_reports_new
#' @param wahis_outbreak_reports_list
#' @param db_branch
#' @return
#' @export

wahis_get_outbreak_reports_new <- function(wahis_outbreak_reports_list, db_branch){

  # not sure what this will look like exactly, but establish db connection referencing branch/commit
  # conn <- dolt(db_branch)
  conn <- dbConnect(dolt_local())
  dolt_checkout(db_branch)

  # if ingest status log already exists, pull report_info_id of all reports that have already been processed
  if(dbExistsTable(conn, "outbreak_reports_ingest_status_log")){
    current_report_info_ids <- dbReadTable(conn, "outbreak_reports_ingest_status_log") %>%
      mutate(report_info_id = as.integer(report_info_id)) %>%
      filter(!ingest_error) %>%
      pull(report_info_id)
  }else{
    current_report_info_ids <- NA_integer_
  }

  # determine which report_info_id are new (if any)
  new_ids <- setdiff(wahis_outbreak_reports_list$report_info_id, current_report_info_ids)

  # return a tibble of reports to fetch
  wahis_outbreak_reports_new <- wahis_outbreak_reports_list %>%
    filter(report_info_id %in% new_ids) %>%
    mutate(url =  paste0("https://wahis.woah.org/pi/getReport/", report_info_id))

  dbDisconnect(conn)

  return(wahis_outbreak_reports_new)


}
