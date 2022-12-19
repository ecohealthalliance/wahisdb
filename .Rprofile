source("renv/activate.R")

options(
  repos = c(RSPM = "https://packagemanager.rstudio.com/all/latest",
            CRAN = "https://cran.rstudio.com/"),

  renv.config.auto.snapshot = TRUE, ## Attempt to keep renv.lock updated automatically
  renv.config.rspm.enabled = TRUE, ## Use RStudio Package manager for pre-built package binaries
  renv.config.install.shortcuts = TRUE, ## Use the existing local library to fetch copies of packages for renv
  renv.config.cache.enabled = TRUE,   ## Use the renv build cache to speed up install times
  renv.config.cache.symlinks = TRUE,  ## Keep full copies of packages locally than symlinks to make the project portable in/out of containers
  renv.config.install.transactional = FALSE,
  tidyverse.quiet = TRUE

)

# Since RSPM does not provide Mac binaries, always install packages from CRAN
# on mac, even if renv.lock specifies they came from RSPM
if (Sys.info()[["sysname"]] %in% c("Darwin", "Windows")) {
  options(renv.config.repos.override = c(
    CRAN = "https://cran.rstudio.com/",
    INLA = "https://inla.r-inla-download.org/R/testing"))
} else if (Sys.info()[["sysname"]] == "Linux") {
  options(renv.config.repos.override = c(
    RSPM = "https://packagemanager.rstudio.com/all/latest",
    INLA = "https://inla.r-inla-download.org/R/testing"))
}

# If project packages have conflicts define them here
if(requireNamespace("conflicted", quietly = TRUE)) {
  conflicted::conflict_prefer("filter", "dplyr", quiet = TRUE)
  conflicted::conflict_prefer("count", "dplyr", quiet = TRUE)
  conflicted::conflict_prefer("select", "dplyr", quiet = TRUE)
  conflicted::conflict_prefer("summarize", "dplyr", quiet = TRUE)
}
