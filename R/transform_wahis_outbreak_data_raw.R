#' Transform outbreak report responses to list of tibbles containing outbreak data
#' @title
#' @param wahis_outbreak_reports_responses
#' @param wahis_outbreak_reports_list
#' @param wahis_outbreak_reports_list_updated
#' @param nproc
#' @return
#' @export
transform_wahis_outbreak_data_raw <- function(wahis_outbreak_reports_responses,
                                              wahis_outbreak_reports_list,
                                              wahis_outbreak_reports_list_updated,
                                              nproc = nproc) {

  if (nproc > 1) {
    oplan <- plan(callr, workers = nproc)
  } else {
    oplan <- plan(sequential)
  }
  on.exit(plan(oplan), add = TRUE)

  if(nrow(wahis_outbreak_reports_list_updated) == 0) return(NULL)
  if(all(wahis_outbreak_reports_list_updated$ingest_error)) return(NULL)

  wahis_outbreak_data <- split(wahis_outbreak_reports_responses, (1:length(wahis_outbreak_reports_responses)-1) %/% 1000) %>% # batching by 1000s (probably only necessary for initial run)
    future_map(., flatten_outbreak_reports)

  wahis_outbreak_data <- transpose(wahis_outbreak_data) %>%
    map(function(x) reduce(x, bind_rows))

  wahis_outbreak_data$outbreak_reports_ingest_status_log <- wahis_outbreak_reports_list_updated

  return(wahis_outbreak_data)


}


#' Convert a list of scraped ourbreak reports to a list of table
#' @param outbreak_reports a list of outbreak reports produced by [ingest_report]
#' @param report_list produced by scrape_outbreak_report_list()
#' @import dplyr tidyr purrr stringr
#' @importFrom glue glue_collapse
#' @importFrom janitor clean_names
#' @importFrom lubridate dmy myd ymd
#' @importFrom textclean replace_non_ascii
#' @importFrom countrycode countrycode
#' @importFrom assertthat %has_name%
#' @export

flatten_outbreak_reports <- function(outbreak_reports#, report_list
) {

  message("Transforming outbreak reports")

  # Preprocessing ---------------------------------------------------
  # outbreak_reports[which(map_int(outbreak_reports, length)==2)]

  outbreak_reports2 <- discard(outbreak_reports, function(x){
    !is.null(x$ingest_status) && str_detect(x$ingest_status, "ingestion error") |
      !is.null(x$message) && str_detect(x$message, "Endpoint request timed out")
  })
  if(!length(outbreak_reports2)) return(NULL)

  # Events table ------------------------------------------------------------

  # Initial flattening
  outbreak_reports_events <- map_dfr(outbreak_reports2, function(x){
    map_dfc(c("senderDto", "generalInfoDto", "reportDto", "report_info_id"), function(tbl){
      out <- x[[tbl]] %>%
        compact() %>%
        as_tibble()
      if(tbl=="generalInfoDto") out <- out %>% select(-one_of("reportDate"))
      if(tbl=="totalCases" & nrow(out)) out <- out %>% rename(total_cases = value)
      if(tbl=="report_info_id" & nrow(out)) out <- out %>% rename(report_info_id = value)
      return(out)
    })
  }) %>%
    janitor::clean_names()

  outbreak_reports_events <- outbreak_reports_events %>%
    mutate(country_or_territory = case_when(
      country_or_territory == "Central African (Rep.)" ~ "Central African Republic",
      country_or_territory == "Dominican (Rep.)" ~ "Dominican Republic",
      country_or_territory == "Ceuta" ~ "Morocco",
      country_or_territory == "Melilla"~ "Morocco",
      TRUE ~ country_or_territory
    )) %>%
    mutate_if(is.character, tolower)  %>%
    select(suppressWarnings(one_of("report_id",
                                   "report_info_id",
                                   "country_or_territory",
                                   "disease_category",
                                   "disease_name",
                                   "is_aquatic",
                                   "report_date",
                                   "report_title",
                                   "translated_reason",
                                   "confirmed_on",
                                   "start_date",
                                   "end_date",
                                   "last_occurance_date",
                                   "casual_agent",
                                   "disease_type",
                                   "event_description_status")),
           everything()
    )

  # Dates handling - convert to  ISO-8601
  outbreak_reports_events <- outbreak_reports_events %>%
    mutate_at(vars(contains("date")), ~lubridate::as_datetime(.))


  # Outbreak tables ---------------------------------------------------

  # outbreak_reports_detail$oieReference
  # ^ denotes different locations within one report - not unique because there can be multiple species
  # outbreak_reports_detail$outbreakInfoId  and outbreak_reports_detail$outbreakId
  # seems to be reduntant with oieReference - leaving out for now

  process_outbreak_map <- function(outbreak_loc, report_id){

    # base dataframe
    outbreak_loc[["geographicCoordinates"]] <- NULL
    outbreak_loc[["newlyAddedCm"]] <- NULL
    outbreak_loc[["administrativeDivisionList"]] <- NULL
    outbreak_loc[["diagSummary"]] <- NULL
    outbreak_loc[["deletedCm"]] <- NULL
    cm <- glue::glue_collapse(unique(outbreak_loc$controlMeasures), sep = "; ")
    outbreak_loc[["controlMeasures"]] <- NULL
    out <- as_tibble(outbreak_loc[which(!sapply(outbreak_loc, is.list))])
    out$report_id <- report_id
    if(length(cm)) out$control_measures <- cm
    assert_that(nrow(out) == 1)

    # add species details
    if(!is.null(outbreak_loc$speciesDetails)){
      sd <- outbreak_loc$speciesDetails[-nrow(outbreak_loc$speciesDetails),]
      out <- bind_cols(out, sd, .name_repair = "minimal")
    }

    # add animal category
    if(!is.null(outbreak_loc$animalCategory)){
      out <- bind_cols(out, outbreak_loc$animalCategory, .name_repair = "minimal")
    }

    return(out)
  }

  outbreak_reports_detail <- imap(outbreak_reports2, function(x, i){

    report_id <- x$reportDto$reportId
    outbreak_map <-  x$eventOutbreakDto$outbreakMap
    print(i)

    if(is.null(outbreak_map)) return()

    map_dfr(outbreak_map, process_outbreak_map, report_id = report_id)
  })

  if(length(outbreak_reports_detail)) {

    outbreak_reports_detail <- reduce(outbreak_reports_detail, bind_rows)

    outbreak_reports_detail <- outbreak_reports_detail %>%
      mutate_if(is.character, tolower) %>%
      janitor::clean_names()  %>%
      select(-suppressWarnings(one_of("prod_type"))) %>%
      select(-suppressWarnings(one_of("specie_id")), -suppressWarnings(one_of("morbidity")), -suppressWarnings(one_of("mortality")), -suppressWarnings(one_of("outbreak_info_id")), -suppressWarnings(one_of("outbreak_id"))) %>%
      rename_with(~str_replace(., "^spicie_name$", "species_name"), suppressWarnings(one_of("spicie_name"))) %>%
      rename_with( ~str_replace(., "^killed$", "killed_and_disposed"), suppressWarnings(one_of("killed"))) %>%
      rename_with( ~str_replace(., "^slaughtered$", "slaughtered_for_commercial_use"), suppressWarnings(one_of("slaughtered"))) %>%
      mutate_all(~na_if(., "" )) %>%
      mutate_at(vars(contains("date")), ~lubridate::as_datetime(.))

    cnames <- colnames(outbreak_reports_detail)

  }

  # Export -----------------------------------------------
  wahis_joined <- list("outbreak_reports_events_raw" = outbreak_reports_events,
                       "outbreak_reports_details_raw" = outbreak_reports_detail)

  # remove empty tables
  wahis_joined <- keep(wahis_joined, ~nrow(.)>0)

  return(wahis_joined)
}
