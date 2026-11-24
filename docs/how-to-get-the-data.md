# How to get the data

This repository does not redistribute data. Instead, it gives you the code that retrieves every number from Statistics Indonesia (Badan Pusat Statistik, BPS) yourself, with your own API key, and documents what the code does at each step. Running it takes about fifteen minutes and produces the same 33-province panel used for the figures.

> Layanan ini menggunakan API Badan Pusat Statistik (BPS). (This service uses the API of Statistics Indonesia.)

---

## 1. Get an API key

1. Register at the BPS WebAPI developer portal: <https://webapi.bps.go.id/developer/>
2. Create an application and copy its key.
3. Store the key in your user-level `.Renviron` file so that it never appears in code:

```r
usethis::edit_r_environ()     # opens ~/.Renviron
# add one line, save, and restart R:
# BPS_API_KEY=your_key_here
```

The key is personal. The BPS terms of use do not allow it to be shared, and the service is free for non-commercial use. Any page or output that uses the API must carry the notice quoted above.

## 2. Run the retrieval

Open `indonesia-provincial-viz.Rproj` in RStudio, then:

```r
source("pipeline/01_check_api.R")   # a few seconds: is the key accepted?
source("get_data.R")                # about 15 minutes: retrieves, harmonises, copies into data/
```

`get_data.R` runs the whole pipeline (`pipeline/run_all.R`) and then copies the files the figures need into `data/`. After that, `source("make_figures.R")` or *Knit* on `README.Rmd` works.

Packages used: `jsonlite` and `rvest` for retrieval; the figures also need `sf`, `ggplot2`, `biscale`, `cowplot`, `cartogram`, `geofacet`, `ggrepel`, `spdep`, `geodata` and `rmapshaper`. Missing packages are installed on first run. Progress messages from the pipeline are in Japanese; the files it writes are self-describing.

## 3. What the pipeline does

| Step | Script | Output |
|---|---|---|
| Check access | `01_check_api.R` | — |
| Dynamic tables (numbers returned as JSON) | `02_fetch_dynamic.R` | `pipeline/out/raw/dyn_*.csv` — 38 provinces + national, as published |
| Static tables (HTML tables) | `03_fetch_static.R` | `pipeline/out/raw/sta_*.csv` |
| Population | `04_build_population.R` | `pipeline/out/panel/population_33.csv` and population weights |
| 33-province panel | `05_build_panel33.R` | `pipeline/out/panel/<indicator>_33.csv`, `panel33_long.csv`, `variables.csv` |

Every indicator is defined by one line of `pipeline/indicators.csv`:

| Column | Meaning | Example |
|---|---|---|
| `name` | Indicator name used in the output | `gini` |
| `source` | `dyn` (dynamic table) or `sta` (static table) | `dyn` |
| `id` | BPS table number | `98` |
| `turvar` | Breakdown to take; alternatives separated by `\|` in order of preference | `Urban+Rural\|Total` |
| `turtahun` | Period to take; fallbacks separated by `>` | `Semester 1 (March) > Annually` |
| `kind` | `int` for rates and averages, `ext` for counts and totals | `int` |
| `mult` | Unit conversion; `auto` reads the table's unit | `1000` |

To add an indicator, find its table number (see section 5) and add one line.

## 4. How the tables are read

The BPS WebAPI returns values together with the list of regions (`vervar`), the breakdown categories (`turvar`, e.g. urban / rural / total) and the sub-annual periods (`turtahun`, e.g. March / September / annual). The pipeline applies the same rules to every table:

- **Years** are listed from the API first (all pages of the list; listings come ten entries per page) and requested one at a time. Year IDs are calendar year − 1900.
- **Breakdown.** The "total" category is called *Total* in some tables and *Urban+Rural* in others, so alternatives are tried in order. If a table has several breakdowns and none is specified, the pipeline stops instead of guessing.
- **Period.** Poverty and inequality are published twice a year; the March round is used, falling back to the annual figure where March does not exist. Unemployment uses the August round.
- **Values** are stored under a key that concatenates the codes of region, variable, breakdown, year and period. Keys are built from these codes and looked up, never parsed apart.
- **Provinces** are selected by region code (two digits, or four digits ending in `00`; `9999` is the national total), not by name. Tables that also list districts mark province names with HTML (`<b>ACEH</b>`); the markup is removed before names are matched to the boundary file.
- **Units** recorded with each table (thousands, billions) are converted to base units.
- **Static tables** are read from the API's `view` response, which carries the table as HTML. The row of years is located first and used as the anchor, so that differently shaped tables can be read with the same code.

## 5. From 38 provinces to 33

Indonesia had 33 provinces in 2010 and has 38 today; all new provinces were created by splitting. To compare years, the new provinces are folded back:

| New province | Folded into |
|---|---|
| Kalimantan Utara (2012) | Kalimantan Timur |
| Papua Barat Daya (2022) | Papua Barat |
| Papua Selatan, Papua Tengah, Papua Pegunungan (2022) | Papua |

Counts and totals are summed; rates and averages are averaged with population weights.

One detail matters: **the row of a parent province does not mean the same thing in every table.** In most tables, *Papua* after 2022 is the reduced province and the new provinces must be added to it. In the population projection table (var 2790), the *Papua* and *Papua Barat* rows still hold the pre-split totals, and the new provinces are listed in addition. The pipeline decides this for each parent province from the continuity of its series (or, where no earlier year exists, from agreement with the national total), and prints its decisions.

## 6. Checks to read in the output

`05_build_panel33.R` prints, and saves to `pipeline/out/panel/variables.csv`:

- **Provinces per year** — must be 33.
- **Largest deviation from the national figure** — the 33 provinces are combined (summed, or population-weighted) and compared with the national value BPS publishes. Counts should agree closely; rates can differ by a few percent where the denominator is not population (for example, sanitation is measured per household).
- **The years around each split** — for rates, the value in the year before the new provinces appear and the folded value in the first year. A smooth series means the folding is right.

## 7. Finding other tables

The national site (`domain/0000`) lists about 1,700 dynamic and 700 static tables. A table's number is part of its address on the BPS website: the address segment after `statistics-table/2/` (dynamic) or `statistics-table/1/` (static) is base64 for `"<id>#<type>"`. For example `MTkyIzI=` decodes to `192#2`, the poverty rate.

Several tables on the national site also carry **district rows** (about 514 districts and cities), including the poverty rate and poverty line (var 621 and 624, 2004–2025) and mean and expected years of schooling and life expectancy (var 415, 457, 414, from 2010). The same pipeline can be pointed at them.
