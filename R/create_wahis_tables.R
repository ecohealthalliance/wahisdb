#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_wahis_tables <- function() {

  dat <- readxl::read_excel(here::here("wahis-extracts", "infur_20230414.xlsx"), sheet = 2) |>
    janitor::clean_names()

  conn <- dolt()

 # create event table (previously outbreak_summary)
  outbreak_summary <- dbReadTable(conn, "outbreak_summary")
  colnames(outbreak_summary)
  event_thread_summary <- dat |>
    select(epi_event_id:reporting_date) |>
    distinct()
  str(event_thread_summary)
  match_cols <- tribble(~outbreak_summary, ~event_thread_summary,
                        "outbreak_thread_id",  "epi_event_id",
                        "country")



  outbreak_time_series <- dbReadTable(conn, "outbreak_time_series")
  colnames(outbreak_time_series)

  # make event/thread and outbreak/subevent tables


}
