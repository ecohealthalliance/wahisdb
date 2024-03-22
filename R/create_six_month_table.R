#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title
#' @param six_month_extract
#' @param disease_key
#' @param taxon_key
#' @return
#' @author Emma Mendelsohn
#' @export
create_six_month_table <- function(six_month_extract,
                                   table_name,
                                   unique_ids,
                                   disease_key,
                                   taxon_key,
                                   ...) {

  ### Record raw names
  raw_names <- colnames(six_month_extract)

  ### Initial clean
  six_month_extract <- janitor::clean_names(six_month_extract)

  ### Table-specific cleaning
  if(table_name %in% c("six_month_controls", "six_month_status")){
    six_month_extract <- six_month_extract |>
      rename(world_region = region) # to match name in quantitative
  }

  if(table_name %in% c("six_month_quantitative")){
    six_month_extract <- six_month_extract |>
      rename(epi_event_id = event_id) # to match name in outbreaks
  }

  ### Match raw names to cleans names
  clean_names <- colnames(six_month_extract)
  names(raw_names) <- clean_names

  ### Table-specific new field
  if(table_name == "six_month_controls"){
    six_month_extract <- six_month_extract |>
      mutate(control_measure_code = as.numeric(factor(control_measure)))
  }

  ### Continue clean
  six_month_extract <- six_month_extract |>
    mutate_if(is.character, tolower) |>
    mutate(semester = str_remove(semester, "-\\b\\d{4}\\b")) |>
    mutate(semester = str_remove(semester, " \\b\\d{4}\\b")) |>
    mutate(semester_code = case_when(semester == "jan-jun" ~ "1", semester == "jul-dec" ~ "2"))

  assert_that(length(unique(six_month_extract$semester)) <= 2)

  ### Unique IDs
  six_month_extract <- six_month_extract |>
    mutate(!!paste0(table_name, "_unique_id") := paste(!!!syms(unique_ids), sep = "_")) |>
    relocate(!!paste0(table_name, "_unique_id"), .before = everything())

  assert_that(n_distinct(six_month_extract[[paste0(table_name, "_unique_id")]]) == nrow(six_month_extract))

  ### Standardize disease
  disease_key <- disease_key |>
    select(disease, standardized_disease_name)

  six_month_extract <-  six_month_extract  |>
    left_join(disease_key, by = c("disease" = "disease"))

  assertthat::assert_that(!any(is.na(six_month_extract$standardized_disease_name)))

  ### Standardize taxon
  if(table_name %in% c("six_month_controls", "six_month_quantitative")){

    taxon_key <- taxon_key |>
      select(taxon, standardized_taxon_name)

    six_month_extract <- six_month_extract  |>
      left_join(taxon_key, by = c("species" = "taxon"))

    # NAs are expected here because we haven't finished standardizing the taxon names for the 6 month tables
    if(any(is.na(six_month_extract$standardized_taxon_name))) warning(paste("NAs in standardized_taxon_name in table", table_name))

  }

  return(list("table" = six_month_extract,
              "schema_raw" = raw_names))



}
