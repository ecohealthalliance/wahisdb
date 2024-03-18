#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param six_month_status_extract
#' @param six_month_controls_extract
#' @param six_month_quantitative_extract
#' @param ando_lookup
#' @param disease_key
#' @return
#' @author Emma Mendelsohn
#' @export
create_six_month_tables <- function(six_month_status_extract,
                                    six_month_controls_extract,
                                    six_month_quantitative_extract) {

  six_month_tables <- list("wahis_six_month_status" = six_month_status_extract,
                           "wahis_six_month_controls" = six_month_controls_extract,
                           "wahis_six_month_quantitative" = six_month_quantitative_extract)

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

  ### Unique IDs
  six_month_tables$wahis_six_month_status <- six_month_tables$wahis_six_month_status |>
    mutate(six_month_status_unique_id = paste(year, semester_code, country, disease, animal_category, sep = "_")) |>
    relocate(six_month_status_unique_id, .before = everything())

  assert_that(n_distinct(six_month_tables$wahis_six_month_status$six_month_status_unique_id) == nrow(six_month_tables$wahis_six_month_status))

  six_month_tables$wahis_six_month_controls <- six_month_tables$wahis_six_month_controls |>
    mutate(control_measure_code = as.numeric(factor(control_measure))) |>
    mutate(six_month_controls_unique_id = paste(year, semester_code, country,disease, animal_category, species, control_measure_code, sep = "_")) |>
    relocate(six_month_controls_unique_id, .before = everything())

  assert_that(n_distinct(six_month_tables$wahis_six_month_controls$six_month_controls_unique_id) == nrow(six_month_tables$wahis_six_month_controls))

  six_month_tables$wahis_six_month_quantitative <- six_month_tables$wahis_six_month_quantitative |>
    mutate(
      six_month_quantitative_unique_id = paste(year, semester_code, country, disease, serotype_subtype_genotype, animal_category, species, outbreak_id, administrative_division, sep = "_"),
      # dplyr::across(
      #   .cols = year:outbreak_id,
      #   .fns = ~ifelse(.x == "-", NA_character_, .x)
      # ),
      dplyr::across(
        .cols = new_outbreaks:vaccinated,
        .fns = ~suppressWarnings(as.integer(.x))
      )#,
      # semester_code = ifelse(semester_code == "-", NA_character_, semester_code)
    ) |>
    relocate(six_month_quantitative_unique_id, .before = everything()) |>
    dplyr::group_by(six_month_quantitative_unique_id) |>
    dplyr::summarise(
      # dplyr::across(
      #   .cols = year:outbreak_id,
      #   .fns = ~unique(.x)[1]
      # ),
      dplyr::across(
        .cols = new_outbreaks:vaccinated,
        .fns = ~sum(.x, na.rm = TRUE)
      )#,
      # semester_code = unique(semester_code)[1]
    )

  assert_that(n_distinct(six_month_tables$wahis_six_month_quantitative$six_month_quantitative_unique_id) == nrow(six_month_tables$wahis_six_month_quantitative))

  ### Harmonize
  #colnames(six_month_tables$wahis_six_month_status)
  #colnames(six_month_tables$wahis_six_month_controls)
  #colnames(six_month_tables$wahis_six_month_quantitative)

  six_month_tables$wahis_six_month_status <- six_month_tables$wahis_six_month_status |> rename(world_region = region)
  six_month_tables$wahis_six_month_controls <- six_month_tables$wahis_six_month_controls |> rename(world_region = region)

  return(six_month_tables)


}
