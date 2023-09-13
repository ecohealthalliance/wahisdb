#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_table_schema <- function() {

  tribble(~table, ~description,
  "wahis_epi_events",	"Summarizes high level event data, where each row is an independent event, as defined by the reporting country. `epi_event_id_unique` is the generated primary key.",
  "wahis_outbreaks",	"Detailed location and impact data for outbreak subevents (e.g., individual farms within a larger outbreak event). `report_outbreak_species_id_unique` is a generated unique primary key.",
  "wahis_six_month_status",	"Disease status by 6-month semester. `unique_id` is a generated unique primary key.",
  "wahis_six_month_controls",	"Control measures applied by disease and taxa by 6-month semester. `unique_id` is a generated unique primary key.")

}
