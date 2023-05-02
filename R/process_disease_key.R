#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param disease_key_file
#' @return
#' @author Emma Mendelsohn
#' @export
process_disease_key <- function(disease_key_file) {

  disease_key <- read_csv(disease_key_file) |>
    filter(source == "oie") |>
    select(-source) |>
    rename(standardized_disease_name_alt = alt)
  colnames(disease_key)[4:13] <- paste("disease",   colnames(disease_key)[4:13], sep = "_")

  return(disease_key)
}
