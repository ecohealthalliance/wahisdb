#' Update and save wahis_outbreak_reports_list with status of latest pulled reports
#' @title
#' @param wahis_outbreak_reports_responses
#' @param wahis_outbreak_reports_new
#' @return
#' @export
update_wahis_outbreak_reports_list <- function(wahis_outbreak_reports_responses,
                                               wahis_outbreak_reports_new) {

  wahis_outbreak_reports_list_updated <- imap_dfr(wahis_outbreak_reports_responses, function(x, y){
    ingest_error <-  !is.null(x$ingest_status) && str_detect(x$ingest_status, "ingestion error") |
      !is.null(x$message) && str_detect(x$message, "Endpoint request timed out") |
      !is.null(x$status) && x$status == "BAD_REQUEST"
    wahis_outbreak_reports_new[which(names(wahis_outbreak_reports_responses) == y), ] %>% mutate(ingest_error = ingest_error)
  })

  return(wahis_outbreak_reports_list_updated)


}
