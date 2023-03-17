#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Collin Schwantes
#' @export
make_deposits_cli <- function(dump_paths) {

  ## grab non-metdata tables
  table_paths <- dump_paths$dump_paths[!grepl(pattern = "descriptive_metadata|schema_.|people|role*",x = dump_paths$dump_paths)]

  ## grab descriptive metadata
  descriptive_metadata_path <- dump_paths$dump_paths[grepl(pattern = "descriptive_metadata",x = dump_paths$dump_paths)]

  descriptive_metadata_df <- read_csv(descriptive_metadata_path)

  term_check <-names(descriptive_metadata_df) %in% deposits::dcmi_terms()

  creators <- descriptive_metadata_df$authors %>%
    str_split(pattern = ", ") %>%
    unlist() %>%
    as.list()

  db_contributors <- descriptive_metadata_df$contributors %>%
    str_split(pattern = ", ")%>%
    unlist() %>%
    as.list()

  keywords <- descriptive_metadata_df$keywords %>%
    str_split(pattern = ", ")%>%
    unlist() %>%
    as.list()

  ## create a new deposit
  metadata <- as.list(descriptive_metadata_df[term_check])

  ## drop NA elements
  metadata<- purrr::discard(metadata,~ any(is.na(.x)))

  ## add elements
  metadata$created <- lubridate::as_date(dump_paths$commit_date)
  metadata$creator <- creators
  #metadata$contributor <- db_contributors[4][[1]]
  metadata$subject <- keywords

  # create a new client
  cli <- depositsClient$new (service = "zenodo", sandbox = TRUE, metadata =   metadata)

  ## update existing deposit
  # update deposits cli
  cli$deposits_list()

  # check for data using DOI
  if(nrow(cli$deposits) > 0){
    if(!rlang::is_empty(metadata$identifier)){
      dump_deposit <- cli$deposits %>%
        dplyr::filter(doi == {metadata$identifier[[1]]})
    } else {
      # check for data using Title

      rlang::inform("Deposit identified via title")
      dump_deposit <- cli$deposits %>%
        dplyr::filter(title == {metadata$title[[1]]})

      # check for multiple deposits
      if(nrow(dump_deposit) > 1){
        err_msg <- glue::glue("Multiple titles match {metadata$title[[1]]}")
        rlang::abort(message = err_msg)
      }
    }

    ## if we found the deposit, then process it ----
    if(nrow(dump_deposit) >0){

      deposit_id <- dump_deposit$id
      cli$deposit_update(deposit_id = deposit_id[6])

    } else {
      ### create a new deposit ----
      cli$deposit_new()
    }
  }






  cli$deposit_upload_file (path = )


}
