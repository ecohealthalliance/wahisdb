
<!-- README.md is generated from README.Rmd. Please edit that file -->

# wahisdb

[![License (for code):
MIT](https://img.shields.io/badge/License%20(for%20code)-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![License:
CC0-1.0](https://img.shields.io/badge/License%20(for%20data)-CC0_1.0-lightgrey.svg)](http://creativecommons.org/publicdomain/zero/1.0/)

This package accesses and formats veterinary disease data from [OIE
WAHIS](https://wahis.woah.org/#/home). Data is currently static
(outbreaks are from April 2023 and six month reports from August 2023).
In the future, we expect the data to be updated weekly. Publicly
available on DoltHub:
<https://www.dolthub.com/repositories/ecohealthalliance/wahisdb>.

## Database Tables

- **wahis_epi_events** Summarizes high level event data, where each row
  is an independent event, as defined by the reporting country.
  `epi_event_id_unique` is the generated primary key. This table
  included hand-curated disease name standardization and taxonomy.
- **wahis_outbreaks** Detailed location and impact data for outbreak
  subevents (e.g., individual farms within a larger outbreak event).
  `report_outbreak_species_id_unique` is a generated unique primary key.
  This table can be joined with wahis_epi_events by
  `epi_event_id_unique`.

## Repository Structure and Reproducibility

- `wahisdb/` contains the dolt database. See instructions below.
- `R/` contains functions used in this analysis.
- This project uses the `targets` package to create its analysis
  pipeline. The steps are defined in the `_targets.R` file and the
  workflow can be executed by running `targets::tar_make()`.
- The schematic figure below summarizes the steps. (The figure is
  generated using `mermaid.js` syntax and should display as a graph on
  GitHub.It can also be viewed by pasting the code into
  <https://mermaid.live>.)

``` mermaid
graph LR
subgraph Project Workflow
    direction LR
    x629c36d2af957bc8(["ando_lookup_file"]):::skipped --> x9f3106cdda58eb5e(["ando_lookup"]):::skipped
    x985e8121d5fee0a3(["wahis_tables"]):::skipped --> x251c9f94619dd3ca(["wahis_tables_in_db"]):::skipped
    xbddb73c04cc744ca(["disease_key_file"]):::skipped --> x3fa380dc1bb2ee6e(["disease_key"]):::skipped
    xb062d399d449ab75(["schema_extract_file"]):::skipped --> xb8193a09354c7cc0(["schema_extract"]):::skipped
    x6a8e2c18543f0da1(["wahis_extract_file"]):::skipped --> x800e0120ecf6dba0(["wahis_extract"]):::skipped
    x9f3106cdda58eb5e(["ando_lookup"]):::skipped --> x985e8121d5fee0a3(["wahis_tables"]):::skipped
    x3fa380dc1bb2ee6e(["disease_key"]):::skipped --> x985e8121d5fee0a3(["wahis_tables"]):::skipped
    x800e0120ecf6dba0(["wahis_extract"]):::skipped --> x985e8121d5fee0a3(["wahis_tables"]):::skipped
    x5cbe2bbd0725c754(["schema_fields"]):::skipped --> x9c3cd21d02b17883(["schema_in_db"]):::skipped
    xe2a64b31ce9fa139(["schema_tables"]):::skipped --> x9c3cd21d02b17883(["schema_in_db"]):::skipped
    x251c9f94619dd3ca(["wahis_tables_in_db"]):::skipped --> x1bd336b143fd25fb(["wahis_tables_in_db_with_foreign_keys"]):::skipped
    x3fa380dc1bb2ee6e(["disease_key"]):::skipped --> x5cbe2bbd0725c754(["schema_fields"]):::skipped
    xb8193a09354c7cc0(["schema_extract"]):::skipped --> x5cbe2bbd0725c754(["schema_fields"]):::skipped
    x985e8121d5fee0a3(["wahis_tables"]):::skipped --> x5cbe2bbd0725c754(["schema_fields"]):::skipped
  end
linkStyle 0 stroke-width:0px;
```

## Dolt

- Install and configure the database software, dolt:
  <https://www.dolthub.com/blog/2020-02-03-dolt-and-dolthub-getting-started/>
- Install: sudo curl -L
  <https://github.com/dolthub/dolt/releases/latest/download/install.sh>
  \| sudo bash
- Provide credentials:
  `dolt config --global --add user.email YOU@DOMAIN.COM` and
  `dolt config --global --add user.name "YOUR NAME"` Login: dolt login
- Copy key to <https://www.dolthub.com/settings/credentials>
- Clone the dolt database: dolt clone ecohealthalliance/wahisdb

## renv

- This project uses the [{renv}](https://rstudio.github.io/renv/)
  framework to record R package dependencies and versions. Packages and
  versions used are recorded in `renv.lock` and code used to manage
  dependencies is in `renv/` and other files in the root project
  directory. On starting an R session in the working directory, run
  `renv::restore()` to install R package dependencies.
