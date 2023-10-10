#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param six_month_tables
#' @param disease_key
#' @param taxon_key
#' @return
#' @author Emma Mendelsohn
#' @export
standardize_six_month_tables <- function(six_month_tables, disease_key,
                                         taxon_key) {

  disease_key <- disease_key |>
    select(disease, standardized_disease_name)

  six_month_tables$wahis_six_month_status <-  six_month_tables$wahis_six_month_status  |>
    left_join(disease_key, by = c("disease" = "disease"))
  assertthat::assert_that(!any(is.na(six_month_tables$wahis_six_month_status$standardized_disease_name)))

  six_month_tables$wahis_six_month_controls <-  six_month_tables$wahis_six_month_controls  |>
    left_join(disease_key, by = c("disease" = "disease"))
  assertthat::assert_that(!any(is.na(six_month_tables$wahis_six_month_controls$standardized_disease_name)))

  six_month_tables$wahis_six_month_quantitative <-  six_month_tables$wahis_six_month_quantitative  |>
    left_join(disease_key, by = c("disease" = "disease"))
  assertthat::assert_that(!any(is.na(six_month_tables$wahis_six_month_quantitative$standardized_disease_name)))

  taxon_key <- taxon_key |>
    select(taxon, standardized_taxon_name)

  six_month_tables$wahis_six_month_controls <- six_month_tables$wahis_six_month_controls  |>
    left_join(taxon_key, by = c("species" = "taxon"))

  six_month_tables$wahis_six_month_quantitative <- six_month_tables$wahis_six_month_quantitative  |>
    left_join(taxon_key, by = c("species" = "taxon"))

  return(six_month_tables)


}
