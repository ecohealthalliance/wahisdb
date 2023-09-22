#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_outbreak_events_tables <- function(outbreak_events_extract, ando_lookup, disease_key){

  disease_key <- disease_key |>
    select(disease, standardized_disease_name)

  ### Initial clean
  outbreak_events_extract <- outbreak_events_extract  |>
    janitor::clean_names() |>
    mutate_if(is.character, tolower)  |>
    mutate_at(vars(contains("date")), lubridate::as_datetime)

  ### There is subreporting by serotype that needs to be handled before splitting
  wahis_dup_event_ids <- outbreak_events_extract |>
    select(epi_event_id:terra_aqua) |>
    distinct() |>
    get_dupes(epi_event_id) |>
    mutate(epi_event_id_unique = paste(epi_event_id, reporting_level, ifelse(reporting_level != "disease", sero_sub_genotype_eng, ""), sep = "_")) #|>

  # few cases where sero_sub_genotype_eng is not enough to distinguish
  wahis_dup_event_ids2 <- wahis_dup_event_ids |>
    get_dupes(epi_event_id_unique) |>
    mutate(epi_event_id_unique2 = paste(epi_event_id_unique, strain_eng, sep = "_")) |>
    select(epi_event_id, epi_event_id_unique, epi_event_id_unique2, reporting_level, sero_sub_genotype_eng, strain_eng)

  # all unique epi_event_ids
  wahis_dup_event_ids <- wahis_dup_event_ids |>
    left_join(wahis_dup_event_ids2) |>
    mutate(epi_event_id_unique = coalesce(epi_event_id_unique2, epi_event_id_unique)) |>
    select(-epi_event_id_unique2, -dupe_count)

  assert_that(length(wahis_dup_event_ids$epi_event_id_unique) == n_distinct(wahis_dup_event_ids$epi_event_id_unique))

  # clean epi_event_id_unique
  wahis_dup_event_ids <- wahis_dup_event_ids |>
    mutate(epi_event_id_unique = make_clean_names(epi_event_id_unique)) |>
    mutate(epi_event_id_unique = str_remove(epi_event_id_unique, "^.")) |>
    select(epi_event_id, epi_event_id_unique, reporting_level, sero_sub_genotype_eng, strain_eng)

  # add epi_event_id_unique colum
  outbreak_events_extract <- outbreak_events_extract |>
    left_join(wahis_dup_event_ids) |>
    mutate(epi_event_id_unique = coalesce(epi_event_id_unique, as.character(epi_event_id))) |>
    relocate(epi_event_id_unique)

  ### Epi event table is the high level summary of the disease event thread, each row is an event
  # exception for events with subtype reporting
  wahis_epi_events <- outbreak_events_extract |>
    select(epi_event_id_unique:terra_aqua) |>
    distinct()

  assert_that(length(wahis_epi_events$epi_event_id_unique) == n_distinct(wahis_epi_events$epi_event_id_unique))

  ### Disease name standardization
  # first some manual cleaning
  wahis_epi_events <- wahis_epi_events |>
    mutate(disease_intermediate = trimws(disease_eng)) |>
    mutate(disease_intermediate = textclean::replace_non_ascii(disease_intermediate)) |>
    mutate(disease_intermediate = str_remove_all(disease_intermediate, "\\s*\\([^\\)]+\\)")) |>
    mutate(disease_intermediate = str_remove(disease_intermediate, "virus")) |>
    mutate(disease_intermediate = trimws(disease_intermediate))

  # bring in ANDO standardization
  wahis_epi_events <- wahis_epi_events |>
    left_join(ando_lookup |> select(disease, preferred_label), by = c("disease_intermediate" = "disease")) |>
    mutate(disease_intermediate = coalesce(preferred_label, disease_intermediate)) |>
    select(-preferred_label)

  # bring in manual disease key
  wahis_epi_events <- wahis_epi_events |>
    left_join(disease_key, by = c("disease_intermediate" = "disease")) |>
    mutate(standardized_disease_name = coalesce(standardized_disease_name, disease_intermediate)) |>
    select(-disease_intermediate)

  ### Outbreak table has subevent information related to individual outbreak locations, taxa
  wahis_outbreaks <- outbreak_events_extract |>
    select(epi_event_id_unique, report_id:last_col()) |>
    mutate(report_outbreak_species_id_unique = paste(report_id, outbreak_id, str_extract(tolower(species), "^[^\\(]+"), sep = "_")) |>
    mutate(report_outbreak_species_id_unique = str_trim(report_outbreak_species_id_unique)) |>
    relocate(report_outbreak_species_id_unique, report_id, outbreak_id, species, epi_event_id_unique, everything())

  # ID dupes (these are related to separate reports for cases/deaths and overall morbidity and mortality)
  wahis_outbreaks_dups <- wahis_outbreaks |>
    janitor::get_dupes(report_outbreak_species_id_unique) |>
    select(-dupe_count)

  # Mark report_outbreak_species_id_unique's as dupes
  if(nrow(wahis_outbreaks_dups)){
    wahis_outbreaks_dups_fix <- wahis_outbreaks_dups |>
      group_split(report_outbreak_species_id_unique) |>
      map_dfr(function(x){
        mutate(x, report_outbreak_species_id_unique = paste0(report_outbreak_species_id_unique, "_DUPE_", row_number()))
      })

    wahis_outbreaks <- wahis_outbreaks |>
      filter(!report_outbreak_species_id_unique %in% unique(wahis_outbreaks_dups$report_outbreak_species_id_unique)) |>
      bind_rows(wahis_outbreaks_dups_fix)
  }

  message(paste("identified", n_distinct(wahis_outbreaks_dups$report_outbreak_species_id_unique), "duplicate report_outbreak_species IDs in wahis outbreaks"))

  return(list("wahis_epi_events" = wahis_epi_events, "wahis_outbreaks" = wahis_outbreaks))

}
