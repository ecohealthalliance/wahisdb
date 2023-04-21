#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Emma Mendelsohn
#' @export
create_wahis_tables <- function(){

  # temp read from saved file, until we get extraction from sharepoint figured out
  dat <- readxl::read_excel(here::here("wahis-extracts", "infur_20230414.xlsx"), sheet = 2) |>
    janitor::clean_names() |>
    mutate_if(is.character, tolower)  |>
    mutate_at(vars(contains("date")), lubridate::as_datetime)

  wahis_epi_event <- dat |>
    select(epi_event_id:terra_aqua) |>
    distinct()

  wahis_outbreaks <- dat |>
    select(epi_event_id, report_id:last_col()) |>
    mutate(unique_id = paste(epi_event_id, report_id, outbreak_id, str_extract(tolower(species), "^[^\\(]+"), sep = "_")) |>
    mutate(unique_id = str_trim(unique_id)) |>
    relocate(unique_id, epi_event_id, report_id, outbreak_id, species, everything())

  # ID any dupes
  wahis_outbreaks_dups <- wahis_outbreaks |>
    janitor::get_dupes(unique_id)

  # Mark unique_id's as dupes
  if(nrow(wahis_outbreaks_dups)){
    wahis_outbreaks_dups_fix <- wahis_outbreaks_dups |>
      group_split(unique_id) |>
      map_dfr(function(x){
        mutate(x, unique_id = paste0(unique_id, "_DUPE_", row_number()))
      })

    wahis_outbreaks <- wahis_outbreaks |>
      filter(!unique_id %in% unique(wahis_outbreaks_dups$unique_id)) |>
      bind_rows(wahis_outbreaks_dups_fix)
  }

  message(paste("identified", n_distinct(wahis_outbreaks_dups$unique_id), "duplicate IDs in wahis outbreaks"))

  return(list("wahis_epi_event" = wahis_epi_event, "wahis_outbreaks" = wahis_outbreaks))

}
