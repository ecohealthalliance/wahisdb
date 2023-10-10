#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param outbreak_events_tables
#' @param disease_key
#' @param taxon_key
#' @return
#' @author Emma Mendelsohn
#' @export
standardize_outbreak_events_tables <- function(outbreak_events_tables,
                                               disease_key, taxon_key) {

  disease_key <- disease_key |>
    select(disease, standardized_disease_name)

  outbreak_events_tables$wahis_epi_events <- outbreak_events_tables$wahis_epi_events  |>
    left_join(disease_key, by = c("disease_eng" = "disease"))

  assertthat::assert_that(!any(is.na(outbreak_events_tables$wahis_epi_events$standardized_disease_name)))


  outbreak_events_tables$wahis_outbreaks <- outbreak_events_tables$wahis_outbreaks  |>
    left_join(disease_key, by = c("disease_eng" = "disease"))

  assertthat::assert_that(!any(is.na(outbreak_events_tables$wahis_outbreaks$standardized_disease_name)))

  taxon_key <- taxon_key |>
    select(taxon, standardized_taxon_name)

  outbreak_events_tables$wahis_outbreaks <- outbreak_events_tables$wahis_outbreaks  |>
    left_join(taxon_key, by = c("species" = "taxon"))

  assertthat::assert_that(!any(is.na(outbreak_events_tables$wahis_outbreaks$standardized_taxon_name)))

  return(outbreak_events_tables)
}
