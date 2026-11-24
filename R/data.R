# =====================================================================
# R/data.R : load the 33-province panel and the province boundaries
# =====================================================================
# Expected files in data/ (not committed; see data/README.md):
#   population_33.csv, poverty_rate_33.csv, grdp_total_const_33.csv, hdi_33.csv,
#   life_expectancy_33.csv, poor_people_33.csv, improved_sanitation_33.csv, gini_33.csv
#   eys_male_38.csv, eys_female_38.csv   (38 provinces as published, for the dumbbell plot)
#   prov33.rds                            (optional; otherwise built from GADM)
# All panel files are long format: prov_name, indicator, year, value, source
# =====================================================================

read_panel <- function(file, name) {
  d <- read.csv(file.path("data", file), stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
  d <- d[, c("prov_name", "year", "value")]
  names(d)[3] <- name
  d
}

#' 33-province boundaries: use data/prov33.rds if present, otherwise build from GADM
#' (GADM level 1, provinces that split after 2010 are dissolved into their parents)
load_boundaries <- function() {
  f <- file.path("data", "prov33.rds")
  if (file.exists(f)) return(readRDS(f))
  to33 <- c("Papua Tengah" = "Papua", "Papua Pegunungan" = "Papua", "Papua Selatan" = "Papua",
            "Papua Barat Daya" = "Papua Barat", "Kalimantan Utara" = "Kalimantan Timur")
  x <- sf::st_as_sf(geodata::gadm(country = "IDN", level = 1, path = file.path("data", "gadm")))
  nm <- as.character(x$NAME_1)
  hit <- match(nm, names(to33)); nm[!is.na(hit)] <- unname(to33[hit[!is.na(hit)]])
  x$prov_name <- nm
  x <- dplyr::summarise(dplyr::group_by(x, prov_name), .groups = "drop")
  x <- rmapshaper::ms_simplify(x, keep = 0.05, keep_shapes = TRUE)
  saveRDS(x, f)
  x
}

load_data <- function() {
  d <- list(
    pop  = read_panel("population_33.csv", "pop"),
    p0   = read_panel("poverty_rate_33.csv", "p0"),
    grdp = read_panel("grdp_total_const_33.csv", "grdp"),
    hdi  = read_panel("hdi_33.csv", "hdi"),
    le   = read_panel("life_expectancy_33.csv", "le"),
    poor = read_panel("poor_people_33.csv", "poor"),
    san  = read_panel("improved_sanitation_33.csv", "sanitation"),
    gini = read_panel("gini_33.csv", "gini"),
    eys_m = read_panel("eys_male_38.csv", "eys_m"),
    eys_f = read_panel("eys_female_38.csv", "eys_f"))
  # per-capita GRDP at 2010 prices (million Rp) = 33-province GRDP / 33-province population
  g <- merge(d$grdp, d$pop, by = c("prov_name", "year"))
  g$grdp_pc <- g$grdp / g$pop / 1e6
  d$gpc <- g
  d$geo <- load_boundaries()
  stopifnot(setequal(d$geo$prov_name, unique(d$pop$prov_name)))   # names must match
  d
}
