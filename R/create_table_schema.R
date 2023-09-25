#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_table_schema <- function() {

  tribble(~table_name, ~description,
          "disease_key", "Lookup table for cleaning and standardizing disease names",
          "wahis_epi_events",	"Summarizes high level event data, where each row is an independent event, as defined by the reporting country. `epi_event_id_unique` is the generated primary key.",
          "wahis_outbreaks",	"Detailed location and impact data for outbreak subevents (e.g., individual farms within a larger outbreak event). `report_outbreak_species_id_unique` is the generated unique primary key.",
          "wahis_six_month_status",	"Country disease status by 6-month semester. `six_month_status_unique_id` is a generated unique primary key.",
          "wahis_six_month_controls",	"Control measures applied by disease and taxa by 6-month semester. `six_month_controls_unique_id` is a generated unique primary key.",
          "wahis_six_month_quantitative",	"Aggregated impact data from outbreak events reports AND six monthly reports on 6-month basis. `six_month_quantitative_unique_id` is a generated unique primary key.")


}
