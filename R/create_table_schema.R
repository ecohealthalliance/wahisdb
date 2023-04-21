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
  "wahis_epi_event",	"Summarizes high level event data, where each row is an independent event, as defined by the reporting country. `epi_event_id` is the primary key.",
  "wahis_outbreaks",	"Detailed location and impact data for outbreak subevents (e.g., individual farms within a larger outbreak event). `unique_id` is a generated unique primary key, consisting of a concatenation of report_id, outbreak_id, and species.",
 "disease_key", "Hand-curated lookup for disease name standardization and taxonomy, used to clean the disease names in outbreak_summary. `disease` is the primary key, and can be used to join with outbreak summary.")

}
