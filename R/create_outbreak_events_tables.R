#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_outbreak_events_tables <- function(outbreak_events_extract,
                                          disease_key,
                                          taxon_key,
                                          ...){

  ### Record raw names
  raw_names <- colnames(outbreak_events_extract)

  ### Initial clean
  outbreak_events_extract <- outbreak_events_extract  |>
    janitor::clean_names() |>
    mutate_if(is.character, tolower)  |>
    mutate_at(vars(contains("date")), lubridate::as_datetime)

  # Check that reported end months are after start months
  # If this fails, there is likely a data format issue. I have seen extracts where date columns have different formats
  # see example infur_20240311, event_start_date is mm/dd/yyyy and event_closing_date is dd/mm/yyyy
  # note that there can still be data cleaning issues where event_closing_date is a few days after event_start_date, hence doing this check by month
  assertthat::assert_that(all(na.omit(lubridate::floor_date(outbreak_events_extract$event_start_date, unit = "month") <= lubridate::floor_date(outbreak_events_extract$event_closing_date, unit = "month"))),
                          msg = "check date formats")

  # Match raw names to cleans names
  clean_names <- colnames(outbreak_events_extract)
  names(raw_names) <- clean_names

  # There is subreporting by serotype that needs to be handled before splitting
  dup_event_ids <- outbreak_events_extract |>
    select(epi_event_id:terra_aqua) |>
    distinct() |>
    get_dupes(epi_event_id) |>
    mutate(epi_event_id_unique = paste(epi_event_id, reporting_level, ifelse(reporting_level != "disease", sero_sub_genotype_eng, ""), sep = "_")) #|>

  # few cases where sero_sub_genotype_eng is not enough to distinguish
  dup_event_ids2 <- dup_event_ids |>
    get_dupes(epi_event_id_unique) |>
    mutate(epi_event_id_unique2 = paste(epi_event_id_unique, strain_eng, sep = "_")) |>
    select(epi_event_id, epi_event_id_unique, epi_event_id_unique2, reporting_level, sero_sub_genotype_eng, strain_eng)

  # all unique epi_event_ids
  dup_event_ids <- dup_event_ids |>
    left_join(dup_event_ids2) |>
    mutate(epi_event_id_unique = coalesce(epi_event_id_unique2, epi_event_id_unique)) |>
    select(-epi_event_id_unique2, -dupe_count)

  assert_that(length(dup_event_ids$epi_event_id_unique) == n_distinct(dup_event_ids$epi_event_id_unique))

  # clean epi_event_id_unique
  dup_event_ids <- dup_event_ids |>
    mutate(epi_event_id_unique = make_clean_names(epi_event_id_unique)) |>
    mutate(epi_event_id_unique = str_remove(epi_event_id_unique, "^.")) |>
    select(epi_event_id, epi_event_id_unique, reporting_level, sero_sub_genotype_eng, strain_eng)

  # add epi_event_id_unique column
  outbreak_events_extract <- outbreak_events_extract |>
    left_join(dup_event_ids) |>
    mutate(epi_event_id_unique = coalesce(epi_event_id_unique, as.character(epi_event_id))) |>
    relocate(epi_event_id_unique)

  ### Standardize disease and taxon names
  disease_key <- disease_key |>
    select(disease, standardized_disease_name)

  outbreak_events_extract <- outbreak_events_extract  |>
    left_join(disease_key, by = c("disease_eng" = "disease"))

  assertthat::assert_that(!any(is.na(outbreak_events_extract$standardized_disease_name)))

  taxon_key <- taxon_key |>
    select(taxon, standardized_taxon_name)

  outbreak_events_extract <- outbreak_events_extract  |>
    left_join(taxon_key, by = c("species" = "taxon"))

  assertthat::assert_that(!any(is.na(outbreak_events_extract$standardized_taxon_name)))

  ### Epi event table is the high level summary of the disease event thread, each row is an event
  # exception for events with subtype reporting
  events <- outbreak_events_extract |>
    select(epi_event_id_unique:terra_aqua, standardized_disease_name) |>
    distinct()

  assert_that(length(events$epi_event_id_unique) == n_distinct(events$epi_event_id_unique))

  ### Outbreak table has subevent information related to individual outbreak locations, taxa
  outbreaks <- outbreak_events_extract |>
    select(epi_event_id_unique, disease_eng, report_id:last_col()) |>
    mutate(report_outbreak_species_id_unique = paste(report_id, outbreak_id, str_extract(tolower(species), "^[^\\(]+"), sep = "_")) |>
    mutate(report_outbreak_species_id_unique = str_trim(report_outbreak_species_id_unique)) |>
    relocate(report_outbreak_species_id_unique, report_id, outbreak_id, species, epi_event_id_unique, everything())

  # ID dupes (these are related to separate reports for cases/deaths and overall morbidity and mortality)
  outbreaks_dups <- outbreaks |>
    janitor::get_dupes(report_outbreak_species_id_unique) |>
    select(-dupe_count)

  # Mark report_outbreak_species_id_unique's as dupes
  if(nrow(outbreaks_dups)){
    outbreaks_dups_fix <- outbreaks_dups |>
      group_split(report_outbreak_species_id_unique) |>
      map_dfr(function(x){
        mutate(x, report_outbreak_species_id_unique = paste0(report_outbreak_species_id_unique, "_DUPE_", row_number()))
      })

    outbreaks <- outbreaks |>
      filter(!report_outbreak_species_id_unique %in% unique(outbreaks_dups$report_outbreak_species_id_unique)) |>
      bind_rows(outbreaks_dups_fix)
  }

  message(paste("identified", n_distinct(outbreaks_dups$report_outbreak_species_id_unique), "duplicate report_outbreak_species IDs in wahis outbreaks. These are marked as duplicates in `report_outbreak_species_id_unique`"))

  return(list("events" = events,
              "outbreaks" = outbreaks,
              "outbreak_events_schema_raw" = raw_names))

}
