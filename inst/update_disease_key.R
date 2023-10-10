# This takes the original key developed by Nate for DTRA-ML bases on the WAHIS API extract data
# Updates with a combination of fuzzy matching and manual for the current data

library(targets)

tar_load(outbreak_events_tables)
tar_load(six_month_tables)

wahis_disease_names <- unique(c(outbreak_events_tables$wahis_epi_events$disease_eng,
                                six_month_tables$wahis_six_month_status$disease,
                                six_month_tables$wahis_six_month_controls$disease,
                                six_month_tables$wahis_six_month_quantitative$disease))
wahis_disease_key <- read_csv(here::here("inst", "disease_key.csv"))

# Disease not in key
missing_diseases <- wahis_disease_names[!wahis_disease_names %in% wahis_disease_key$disease]

# Fuzzy match missing diseases against key
new_disease_key <- tibble(disease = missing_diseases, key_row = stringdist::amatch(missing_diseases, wahis_disease_key$disease, maxDist = 100), standardized_disease_name = wahis_disease_key$standardized_disease_name[key_row])
new_disease_key <- left_join(new_disease_key |> select(-key_row), wahis_disease_key |> select(-disease), relationship = "many-to-many")
new_disease_key <- bind_rows(wahis_disease_key, new_disease_key)

write_csv(x = new_disease_key, file = "data/new_disease_key.csv")
