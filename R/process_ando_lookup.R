#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param ando_lookup_file
#' @return
#' @author Emma Mendelsohn
#' @export
process_ando_lookup <- function(ando_lookup_file) {

  readxl::read_xlsx(ando_lookup_file) |> # this can be manually edited
    mutate(disease = textclean::replace_non_ascii(disease)) |>
    rename(disease_class = class_desc) |>
    filter(report == "animal") |>
    mutate_at(.vars = c("ando_id", "preferred_label", "disease_class"), ~na_if(., "NA")) |>
    distinct()

}
