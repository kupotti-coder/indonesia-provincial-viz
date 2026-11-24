# =====================================================================
# get_data.R : retrieve the data from the BPS WebAPI and place it in data/
# =====================================================================
# Requires your own BPS API key in ~/.Renviron (BPS_API_KEY=...).
# See docs/how-to-get-the-data.md.
#
#   source("get_data.R")              # about 15 minutes
#
# Step 1 runs the retrieval pipeline (pipeline/run_all.R), which writes
#   pipeline/out/raw/    tables as retrieved (38 provinces + national)
#   pipeline/out/panel/  the 33-province panel, one file per indicator
#   pipeline/out/report/ retrieval log and checks
# Step 2 copies the files the figures need into data/ under the names R/data.R expects.
# Neither pipeline/out/ nor data/ is committed to the repository.
# =====================================================================

source("pipeline/run_all.R")

dir.create("data", showWarnings = FALSE)
panel <- file.path("pipeline", "out", "panel")
raw   <- file.path("pipeline", "out", "raw")
copy <- c(
  "population_33.csv"          = file.path(panel, "population_33.csv"),
  "poverty_rate_33.csv"        = file.path(panel, "poverty_rate_P0_33.csv"),
  "grdp_total_const_33.csv"    = file.path(panel, "grdp_total_const_33.csv"),
  "hdi_33.csv"                 = file.path(panel, "hdi_33.csv"),
  "life_expectancy_33.csv"     = file.path(panel, "life_expectancy_33.csv"),
  "poor_people_33.csv"         = file.path(panel, "poor_people_33.csv"),
  "improved_sanitation_33.csv" = file.path(panel, "improved_sanitation_33.csv"),
  "gini_33.csv"                = file.path(panel, "gini_33.csv"),
  "eys_male_38.csv"            = file.path(raw,   "dyn_eys_male.csv"),
  "eys_female_38.csv"          = file.path(raw,   "dyn_eys_female.csv"))
# keep a copy of the current data/ before overwriting it (data_backup_* is git-ignored)
old <- list.files("data", pattern = "\\.(csv|rds)$", full.names = TRUE)
if (length(old)) {
  bk <- paste0("data_backup_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  dir.create(bk)
  file.copy(old, bk)
  cat("Backed up", length(old), "files to", bk, "\n")
}
ok <- file.copy(unname(copy), file.path("data", names(copy)), overwrite = TRUE)
if (!all(ok)) stop("Not found: ", paste(unname(copy)[!ok], collapse = ", "))
cat("\nCopied", sum(ok), "files to data/. Next: source(\"make_figures.R\") or knit README.Rmd\n")
