#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_six_month_table <- function(six_month_extract, ando_lookup, disease_key){

  ### Initial clean
  six_month_extract <- six_month_extract  |>
    janitor::clean_names() |>
    mutate_if(is.character, tolower) |>
    mutate(semester = str_remove(semester, "-\\b\\d{4}\\b")) |>
    mutate(semester_code = case_when(semester == "jan-jun" ~ "1", semester == "jul-dec" ~ "2"))

  assert_that(length(unique(six_month_extract$semester)) <= 2)

  ### Disease name standardization
  # first some manual cleaning
  six_month_extract <- six_month_extract |>
    mutate(disease_intermediate = trimws(disease)) |>
    mutate(disease_intermediate = textclean::replace_non_ascii(disease_intermediate)) |>
    mutate(disease_intermediate = str_remove_all(disease_intermediate, "\\s*\\([^\\)]+\\)")) |>
    mutate(disease_intermediate = str_remove(disease_intermediate, "virus")) |>
    mutate(disease_intermediate = trimws(disease_intermediate)) |>
    mutate(disease_intermediate = str_replace_all(disease_intermediate, "  ", " "))

  # bring in ANDO standardization
  six_month_extract <- six_month_extract |>
    left_join(ando_lookup |> select(disease, preferred_label), by = c("disease_intermediate" = "disease")) |>
    mutate(disease_intermediate = coalesce(preferred_label, disease_intermediate)) |>
    select(-preferred_label)

  # bring in manual disease key
  six_month_extract <- six_month_extract |>
    left_join(disease_key, by = c("disease_intermediate" = "disease")) |>
    mutate(standardized_disease_name = coalesce(standardized_disease_name, disease_intermediate)) |>
    select(-disease_intermediate)

  # create unique ID
  six_month_extract <- six_month_extract |>
    #mutate(unique_id = paste(year, semester_code, country, animal_category, standardized_disease_name, sep = "_"))
    mutate(unique_id = as.character(row_number())) |>
    relocate(unique_id, .before = everything())

  return(list("wahis_six_month_status" = six_month_extract))

}
