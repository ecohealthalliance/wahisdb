#' .. content for \description{} (no empty lines) ..
#' Thin wrapper for dolt_dump. Creates a folder based on the last commit hash
#' .. content for \details{} ..
#'
#' @title Get a dolt dump

#' @return
#' @author Collin Schwantes
#' @export
get_dolt_dump <- function() {

  doltr::dolt_pull()
  a <- doltr::dolt_last_commit()

  dump_path <- sprintf("doltdump/%s",a$commit_hash)

  dir.create(path = dump_path,recursive = TRUE)


  dump_out <- rlang::try_fetch(
  doltr::dolt_dump(format = "csv",out = dump_path,overwrite = FALSE )
  ,
  error = function(cond){
    if(cond$status == 1){
      ## if the data already exist, just return the file paths
      warning("data already exist. Do you need to dolt_commit?")
      file_paths <- list.files(path = dump_path,full.names = TRUE)
      return(file_paths)
    } else {
      rlang::abort("Failed.", parent = cond)
    }
  })

  dump_paths <- list(dump_dir = dump_path,
                  dump_paths = dump_out,
                  commit_date = a$date)

  return(dump_paths)

}
