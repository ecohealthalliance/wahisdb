#' .. content for \description{} (no empty lines) ..
#'
#' .. content for \details{} ..
#'
#' @title

#' @return
#' @author Collin Schwantes
#' @export
make_deposits_cli <- function(dump_paths) {

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



  metadata$created <- lubridate::as_date(dump_paths$commit_date)
  metadata$creator <- creators
  #metadata$contributor <- db_contributors[4][[1]]
  metadata$subject <- keywords




  ### likely need a way to update and not create a new thing
  cli <- depositsClient$new (service = "zenodo", sandbox = TRUE, metadata =   metadata[-4])

  cli$deposit_new()
  ## upload non-schema, non-metadata tables



}
