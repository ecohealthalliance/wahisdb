
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
- **wahis_six_month_status** Disease status by 6-month semester.
  `unique_id` is a generated unique primary key.
- \*\*wahis_six_month_controls\*“\*\* Control measures applied by
  disease and taxa by 6-month semester. `unique_id` is a generated
  unique primary key.
- **wahis_six_month_quantitative** Aggregated impact data from outbreak
  events reports AND six monthly reports on 6-month basis.
  `six_month_quantitative_unique_id` is a generated unique primary key.

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
    xbddb73c04cc744ca(["disease_key_file"]):::skipped --> x3fa380dc1bb2ee6e(["disease_key"]):::queued
    x3fa380dc1bb2ee6e(["disease_key"]):::queued --> x57ec39d36d300eb7(["six_month_tables_standardized"]):::queued
    x37b36237069aea80(["six_month_tables"]):::queued --> x57ec39d36d300eb7(["six_month_tables_standardized"]):::queued
    x8b6a5220bfbdabdf(["taxon_key"]):::queued --> x57ec39d36d300eb7(["six_month_tables_standardized"]):::queued
    x3fa380dc1bb2ee6e(["disease_key"]):::queued --> x5cbe2bbd0725c754(["schema_fields"]):::queued
    xdca9076b94036ae3(["outbreak_events_tables_standardized"]):::queued --> x5cbe2bbd0725c754(["schema_fields"]):::queued
    xb8193a09354c7cc0(["schema_extract"]):::queued --> x5cbe2bbd0725c754(["schema_fields"]):::queued
    x57ec39d36d300eb7(["six_month_tables_standardized"]):::queued --> x5cbe2bbd0725c754(["schema_fields"]):::queued
    x8b6a5220bfbdabdf(["taxon_key"]):::queued --> x5cbe2bbd0725c754(["schema_fields"]):::queued
    x3fa380dc1bb2ee6e(["disease_key"]):::queued --> xa7adee78ecc918bb(["keys_in_db"]):::queued
    x8b6a5220bfbdabdf(["taxon_key"]):::queued --> xa7adee78ecc918bb(["keys_in_db"]):::queued
    xa4fa2a66c31d7b33(["six_month_status_file"]):::skipped --> xde280acaaefdc7be(["six_month_status_extract"]):::queued
    x52f10102fdbda18d(["six_month_controls_file"]):::skipped --> x6740ee55561635cd(["six_month_controls_extract"]):::queued
    x3fa380dc1bb2ee6e(["disease_key"]):::queued --> xdca9076b94036ae3(["outbreak_events_tables_standardized"]):::queued
    x32a3bb2ce92d02b0(["outbreak_events_tables"]):::queued --> xdca9076b94036ae3(["outbreak_events_tables_standardized"]):::queued
    x8b6a5220bfbdabdf(["taxon_key"]):::queued --> xdca9076b94036ae3(["outbreak_events_tables_standardized"]):::queued
    xb062d399d449ab75(["schema_extract_file"]):::skipped --> xb8193a09354c7cc0(["schema_extract"]):::queued
    x5cbe2bbd0725c754(["schema_fields"]):::queued --> x9c3cd21d02b17883(["schema_in_db"]):::queued
    xe2a64b31ce9fa139(["schema_tables"]):::skipped --> x9c3cd21d02b17883(["schema_in_db"]):::queued
    x37b36237069aea80(["six_month_tables"]):::queued --> x06f5315659bba48a(["six_month_tables_in_db"]):::queued
    x32a3bb2ce92d02b0(["outbreak_events_tables"]):::queued --> xe395ec11fce57977(["outbreak_events_tables_in_db"]):::queued
    xcc7bba8de0af4cfe(["outbreak_events_file"]):::skipped --> xed1d4a32cc4d66ec(["outbreak_events_extract"]):::queued
    x6740ee55561635cd(["six_month_controls_extract"]):::queued --> x37b36237069aea80(["six_month_tables"]):::queued
    x52699edfaa6546df(["six_month_quantitative_extract"]):::queued --> x37b36237069aea80(["six_month_tables"]):::queued
    xde280acaaefdc7be(["six_month_status_extract"]):::queued --> x37b36237069aea80(["six_month_tables"]):::queued
    xe395ec11fce57977(["outbreak_events_tables_in_db"]):::queued --> x706a5521f33a5641(["outbreak_events_tables_in_db_with_foreign_keys"]):::queued
    xb3e4b9db3d59cdbc(["taxon_key_file"]):::skipped --> x8b6a5220bfbdabdf(["taxon_key"]):::queued
    xc235746cd78fdcc9(["six_month_quantitative_file"]):::skipped --> x52699edfaa6546df(["six_month_quantitative_extract"]):::queued
    xed1d4a32cc4d66ec(["outbreak_events_extract"]):::queued --> x32a3bb2ce92d02b0(["outbreak_events_tables"]):::queued
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
