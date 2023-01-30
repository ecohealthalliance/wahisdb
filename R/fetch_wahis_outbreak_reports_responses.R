#' Pull outbreak report responses from WAHIS
#' @title
#' @param wahis_outbreak_reports_new
#' @param test_max_reports
#' @return
#' @export
fetch_wahis_outbreak_reports_responses <- function(wahis_outbreak_reports_new, test_max_reports = NULL){
  if(is.number(test_max_reports)){
    set.seed(0)
    n_reports <- ifelse(test_max_reports > nrow(wahis_outbreak_reports_new), nrow(wahis_outbreak_reports_new), test_max_reports)
    wahis_outbreak_reports_new <- wahis_outbreak_reports_new %>%
      slice(sample(nrow(.), n_reports, replace = FALSE))
  }
  message("Pulling ", nrow(wahis_outbreak_reports_new), " WAHIS outbreak reports")
  wahis_outbreak_reports_responses <- split(wahis_outbreak_reports_new, (1:nrow(wahis_outbreak_reports_new)-1) %/% 100) %>% # batching by 100s
    map(function(reports_to_get_split){
    map_curl(
        urls = reports_to_get_split$url,
        .f = function(x) safe_ingest(x),
        .host_con = 16L,
        .delay = 0.25,
        .handle_opts = list(low_speed_limit = 100, low_speed_time = 300), # bytes/sec
        .retry = 3,
        .handle_headers = list(`Accept-Language` = "en")
      )
    })

  wahis_outbreak_reports_responses <- reduce(wahis_outbreak_reports_responses, c)
  assertthat::are_equal(length(wahis_outbreak_reports_responses), nrow(wahis_outbreak_reports_new))
  return(wahis_outbreak_reports_responses)
}

ingest_report <- function (resp) {
  out <- fromJSON(rawToChar(resp$content))
  report_info_id <- suppressWarnings(as.integer(basename(resp$url)))
  if (!is.na(report_info_id)) {
    out$report_info_id <- report_info_id
  }
  return(out)
}


safe_ingest <- function (resp){
  out <- safely(ingest_report)(resp)
  if (!is.null(out$result)) {
    return(out$result)
  }
  else {
    return(list(ingest_status = paste("ingestion error: ",
                                      out$error)))
  }
}

