#' Get master list of outbreak reports
#' @return A tibble of reports
#' @export
scrape_outbreak_report_list <- function() {
  post_url <- "https://wahis.woah.org/pi/getReportList"
  page_size <- 1000000L
  body_data <- list(pageNumber = 1L, pageSize = page_size,
                    searchText = "", sortColName = "", sortColOrder = "ASC",
                    languageChanged = FALSE)
  report_list_response <- POST(post_url, body = body_data,
                               encode = "json")
  report_list <- content(report_list_response)[[2]]
  assertthat::assert_that(length(report_list) < page_size)
  reports <- map_dfr(report_list, as_tibble) |>  janitor::clean_names()
  return(reports)
  }
