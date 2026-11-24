# =====================================================================
# make_figures.R : draw the six figures as PNG files in figures/
# =====================================================================
# Open the project (indonesia-provincial-viz.Rproj) in RStudio, then:
#   source("make_figures.R")
# =====================================================================

pk <- c("sf", "dplyr", "ggplot2", "biscale", "cowplot", "cartogram",
        "ggrepel", "spdep", "scales", "geodata", "rmapshaper")
miss <- pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) install.packages(miss)

source("R/data.R"); source("R/figures.R")
d <- load_data()
dir.create("figures", showWarnings = FALSE)
save <- function(p, f, w, h) {
  ggsave(file.path("figures", f), p, width = w, height = h, dpi = 200, bg = "white")
  cat("saved:", f, "\n")
}

save(fig_bivariate(d),  "1_bivariate_grdp_hdi.png",        10, 5)
save(fig_dorling(d),    "2_dorling_poor_sanitation.png",   10, 5.5)
save(fig_dumbbell(d),   "3_dumbbell_eys_sex.png",           8, 9)
save(fig_trajectory(d), "4_connected_grdp_le.png",          9, 6)
save(fig_geofacet(d),   "5_geofacet_gini.png",             13, 7)
p6 <- fig_lisa(d)
save(p6,                "6_lisa_poverty.png",              10, 5.5)
cat("Moran's I:", round(attr(p6, "moran")$estimate[1], 3), "\n")
