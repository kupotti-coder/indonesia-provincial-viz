# data/

The data files are not part of this repository. Run `source("get_data.R")` from the
project root: it retrieves everything from the BPS WebAPI with your own key
(free: https://webapi.bps.go.id/developer/) and places the files here with these names.
See ../docs/how-to-get-the-data.md.

| File | Content |
|---|---|
| `population_33.csv` | Population, 33 provinces, 2010–2025 |
| `poverty_rate_33.csv` | Poverty rate P0 (March), 2010–2025 |
| `grdp_total_const_33.csv` | GRDP at 2010 constant prices |
| `hdi_33.csv` | Human Development Index (new method) |
| `life_expectancy_33.csv` | Life expectancy at birth (new method) |
| `poor_people_33.csv` | Number of poor people (March) |
| `improved_sanitation_33.csv` | Households with improved sanitation (%) |
| `gini_33.csv` | Gini ratio (March) |
| `eys_male_38.csv`, `eys_female_38.csv` | Expected years of schooling by sex, 38 provinces as published |
| `prov33.rds` | Optional. 33-province boundaries; built from GADM on first run if absent |

All panel files are long format: `prov_name, indicator, year, value, source`.

Layanan ini menggunakan API Badan Pusat Statistik (BPS).
