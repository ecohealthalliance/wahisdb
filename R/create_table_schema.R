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
  "wahis_epi_event",	"Summarizes high level event data, where each row is an independent event, as defined by the reporting country. `epi_event_id_unique` is the generated primary key.",
  "wahis_outbreaks",	"Detailed location and impact data for outbreak subevents (e.g., individual farms within a larger outbreak event). `report_outbreak_species_id_unique` is a generated unique primary key.",
 "disease_key", "Hand-curated lookup for disease name standardization and taxonomy, used to clean the disease names in outbreak_summary. `disease` is the primary key, and can be used to join with outbreak summary.")

}
