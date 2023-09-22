#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param six_month_status_extract
#' @param six_month_controls_extract
#' @param six_month_quantiative_extract
#' @param ando_lookup
#' @param disease_key
#' @return
#' @author Emma Mendelsohn
#' @export
create_six_month_tables <- function(six_month_status_extract,
                                    six_month_controls_extract,
                                    six_month_quantiative_extract,
                                    ando_lookup,
                                    disease_key) {

  disease_key <- disease_key |>
    select(disease, standardized_disease_name)

  six_month_tables <- list("six_month_status" = six_month_status_extract,
                           "six_month_controls" = six_month_controls_extract,
                           "six_month_quantiative" = six_month_quantiative_extract)

  ### Initial clean
  six_month_tables <- map(six_month_tables, function(six_month_table){

    six_month_table <- six_month_table |>
      janitor::clean_names() |>
      mutate_if(is.character, tolower) |>
      mutate(semester = str_remove(semester, "-\\b\\d{4}\\b")) |>
      mutate(semester = str_remove(semester, " \\b\\d{4}\\b")) |>
      mutate(semester_code = case_when(semester == "jan-jun" ~ "1", semester == "jul-dec" ~ "2"))

    assert_that(length(unique(six_month_table$semester)) <= 2)

    return(six_month_table)

  })

  ### Disease name standardization
  six_month_tables <- map(six_month_tables, function(six_month_table){

    # first some manual cleaning
    six_month_table <- six_month_table |>
      mutate(disease_intermediate = trimws(disease)) |>
      mutate(disease_intermediate = textclean::replace_non_ascii(disease_intermediate)) |>
      mutate(disease_intermediate = str_remove_all(disease_intermediate, "\\s*\\([^\\)]+\\)")) |>
      mutate(disease_intermediate = str_remove(disease_intermediate, "virus")) |>
      mutate(disease_intermediate = trimws(disease_intermediate)) |>
      mutate(disease_intermediate = str_replace_all(disease_intermediate, "  ", " "))

    # bring in ANDO standardization
    six_month_table <- six_month_table |>
      left_join(ando_lookup |> select(disease, preferred_label), by = c("disease_intermediate" = "disease")) |>
      mutate(disease_intermediate = coalesce(preferred_label, disease_intermediate)) |>
      select(-preferred_label)

    # bring in manual disease key
    six_month_table <- six_month_table |>
      left_join(disease_key, by = c("disease_intermediate" = "disease")) |>
      mutate(standardized_disease_name = coalesce(standardized_disease_name, disease_intermediate)) |>
      select(-disease_intermediate)

    return(six_month_table)

  })

  ### Unique IDs
  six_month_tables$six_month_status <- six_month_tables$six_month_status |>
    mutate(six_month_status_unique_id = paste(year, semester_code, country, disease, animal_category, sep = "_")) |>
    relocate(six_month_status_unique_id, .before = everything())

  assert_that(n_distinct(six_month_tables$six_month_status$six_month_status_unique_id) == nrow(six_month_tables$six_month_status))

  six_month_tables$six_month_controls <- six_month_tables$six_month_controls |>
    mutate(control_measure_code = as.numeric(factor(control_measure))) |>
    mutate(six_month_controls_unique_id = paste(year, semester_code, country,disease, animal_category, species, control_measure_code, sep = "_")) |>
    relocate(six_month_controls_unique_id, .before = everything())

  assert_that(n_distinct(six_month_tables$six_month_controls$six_month_controls_unique_id) == nrow(six_month_tables$six_month_controls))

  six_month_tables$six_month_quantiative <- six_month_tables$six_month_quantiative |>
    mutate(six_month_quantiative_unique_id = paste(year, semester_code, country, disease, serotype_subtype_genotype, animal_category, species, outbreak_id, administrative_division, sep = "_")) |>
    relocate(six_month_quantiative_unique_id, .before = everything())

  assert_that(n_distinct(six_month_tables$six_month_quantiative$six_month_quantiative_unique_id) == nrow(six_month_tables$six_month_quantiative))

  ### Harmonize
  #colnames(six_month_tables$six_month_status)
  #colnames(six_month_tables$six_month_controls)
  #colnames(six_month_tables$six_month_quantiative)

  six_month_tables$six_month_status <- six_month_tables$six_month_status |> rename(world_region = region)
  six_month_tables$six_month_controls <- six_month_tables$six_month_controls |> rename(world_region = region)

  return(six_month_tables)


}
