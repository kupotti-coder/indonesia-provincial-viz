# =====================================================================
# R/figures.R : the six figures, each as a function of the data list from load_data()
# =====================================================================
# Used by both make_figures.R (saves PNG files) and README.Rmd (knits the README).
# =====================================================================

suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(dplyr)
})
SRC <- "Data: BPS (Statistics Indonesia) via WebAPI, 33-province basis. Boundaries: GADM.\nLayanan ini menggunakan API Badan Pusat Statistik (BPS)."
BLUE <- "#0057A8"; ORANGE <- "#B04A00"
theme_set(theme_minimal(base_size = 11) +
          theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank(),
                plot.caption = element_text(colour = "grey40", size = 8)))

# 1. Bivariate choropleth: per-capita GRDP x HDI ---------------------------
fig_bivariate <- function(d, year = 2024) {
  x <- merge(d$gpc[d$gpc$year == year, ], d$hdi[d$hdi$year == year, ], by = c("prov_name", "year"))
  x$log_gpc <- log10(x$grdp_pc)                       # damp the resource provinces
  m <- biscale::bi_class(left_join(d$geo, x, by = "prov_name"), x = log_gpc, y = hdi,
                         style = "quantile", dim = 3)
  p <- ggplot(m) +
    geom_sf(aes(fill = bi_class), colour = "white", linewidth = 0.15, show.legend = FALSE) +
    biscale::bi_scale_fill(pal = "DkBlue2", dim = 3) +
    labs(title = sprintf("Production and human development do not always coincide (%d)", year),
         subtitle = "Per-capita GRDP at 2010 prices × Human Development Index, tertiles", caption = SRC) +
    theme_void() + theme(plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey40", size = 8))
  lg <- biscale::bi_legend(pal = "DkBlue2", dim = 3, xlab = "GRDP per capita", ylab = "HDI", size = 8)
  cowplot::ggdraw() + cowplot::draw_plot(p) + cowplot::draw_plot(lg, 0.02, 0.10, 0.22, 0.22)
}

# 2. Dorling cartogram: poor people x sanitation ------------------------------
fig_dorling <- function(d, year = 2024) {
  geo_m <- st_transform(d$geo, 3395)
  x <- merge(d$poor[d$poor$year == year, ], d$san[d$san$year == year, ], by = c("prov_name", "year"))
  m <- cartogram::cartogram_dorling(left_join(geo_m, x, by = "prov_name"), weight = "poor", k = 2.5)
  ggplot() +
    geom_sf(data = geo_m, fill = "grey93", colour = "grey80", linewidth = 0.1) +
    geom_sf(data = m, aes(fill = sanitation), colour = "white", linewidth = 0.3) +
    geom_sf_text(data = m[m$poor > 1e6, ], aes(label = prov_name), size = 2.6, colour = "grey15") +
    scale_fill_distiller(palette = "YlOrBr", direction = -1, name = "Improved\nsanitation (%)") +
    labs(title = sprintf("Where the poor live, and what they can access (%d)", year),
         subtitle = "Circle area = number of poor people; colour = households with improved sanitation",
         caption = SRC) +
    theme_void() + theme(plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey40", size = 8))
}

# 3. Dumbbell: expected years of schooling by sex (38 provinces as published) --
fig_dumbbell <- function(d, year = 2024) {
  x <- merge(d$eys_m[d$eys_m$year == year, ], d$eys_f[d$eys_f$year == year, ], by = c("prov_name", "year"))
  nat <- x[x$prov_name == "INDONESIA", ]; x <- x[x$prov_name != "INDONESIA", ]
  x$prov_name <- reorder(x$prov_name, (x$eys_m + x$eys_f) / 2)
  ggplot(x, aes(y = prov_name)) +
    geom_vline(xintercept = nat$eys_m, colour = BLUE, linetype = 3) +
    geom_vline(xintercept = nat$eys_f, colour = ORANGE, linetype = 3) +
    geom_segment(aes(x = eys_m, xend = eys_f, yend = prov_name), colour = "grey70", linewidth = 1) +
    geom_point(aes(x = eys_m, colour = "Male"), size = 2.2) +
    geom_point(aes(x = eys_f, colour = "Female"), size = 2.2) +
    scale_colour_manual(values = c(Male = BLUE, Female = ORANGE), name = NULL) +
    labs(title = sprintf("Expected years of schooling by sex (%d)", year),
         subtitle = "Provinces ordered by the mean of male and female; dotted lines = national values",
         x = "Years", y = NULL, caption = "Data: BPS var 457, 38 provinces as published.") +
    theme(legend.position = "top")
}

# 4. Connected scatterplot: per-capita GRDP x life expectancy -----------------
fig_trajectory <- function(d, highlight = c("Jakarta Raya", "Kalimantan Timur", "Papua",
                                             "Nusa Tenggara Timur", "Jawa Tengah", "Sulawesi Tengah")) {
  x <- merge(d$gpc, d$le, by = c("prov_name", "year"))
  x <- x[order(x$prov_name, x$year), ]
  x$hl <- ifelse(x$prov_name %in% highlight, x$prov_name, "Other")
  end <- x[x$year == max(x$year) & x$prov_name %in% highlight, ]
  ggplot(x, aes(grdp_pc, le, group = prov_name)) +
    geom_path(data = x[x$hl == "Other", ], colour = "grey85", linewidth = 0.4) +
    geom_path(data = x[x$hl != "Other", ], aes(colour = hl), linewidth = 0.9,
              arrow = arrow(length = unit(2, "mm"), type = "closed")) +
    geom_point(data = end, aes(colour = hl, size = pop), alpha = 0.8) +
    ggrepel::geom_text_repel(data = end, aes(label = prov_name, colour = hl), size = 3, show.legend = FALSE) +
    scale_x_log10(labels = scales::label_number(suffix = "M")) +
    scale_size_area(max_size = 9, guide = "none") +
    scale_colour_brewer(palette = "Dark2", guide = "none") +
    labs(title = sprintf("Income and life expectancy, %d → %d", min(x$year), max(x$year)),
         subtitle = "Per-capita GRDP at 2010 prices (million Rp, log scale); circle = population in the last year",
         x = "GRDP per capita (million Rp, log)", y = "Life expectancy at birth (years)", caption = SRC)
}

# 5. Geofacet: Gini over time, laid out like the map --------------------------
IDN_GRID <- data.frame(
  row  = c(1,1,1,1,1,1,1,1,1,1, 2,2,2,2,2,2,2,2,2, 3,3,3,3,3, 4,4,4,4,4,4,4,4, 5),
  col  = c(1,2,3,4,5,6,7,8,9,10, 2,3,4,5,6,7,8,9,10, 2,3,4,7,8, 3,4,5,6,7,8,9,10, 6),
  code = c("AC","SU","RI","KR","KB","KI","GO","SA","MU","PB", "SB","JA","BB","KT","KS","SR","ST","MA","PA",
           "BE","SS","LA","SN","SG", "BT","JK","JB","JT","JI","BA","NB","NT", "YO"),
  name = c("Aceh","Sumatera Utara","Riau","Kepulauan Riau","Kalimantan Barat","Kalimantan Timur",
           "Gorontalo","Sulawesi Utara","Maluku Utara","Papua Barat",
           "Sumatera Barat","Jambi","Bangka Belitung","Kalimantan Tengah","Kalimantan Selatan",
           "Sulawesi Barat","Sulawesi Tengah","Maluku","Papua",
           "Bengkulu","Sumatera Selatan","Lampung","Sulawesi Selatan","Sulawesi Tenggara",
           "Banten","Jakarta Raya","Jawa Barat","Jawa Tengah","Jawa Timur","Bali",
           "Nusa Tenggara Barat","Nusa Tenggara Timur","Yogyakarta"),
  stringsAsFactors = FALSE)

fig_geofacet <- function(d) {
  g <- d$gini
  stopifnot(setequal(IDN_GRID$name, unique(g$prov_name)))
  # Map-shaped grid drawn with plain facet_grid(row ~ col). geofacet::facet_geo mislaid the
  # panels with current ggplot2 (labels and lines in different cells), so it is not used.
  pos <- IDN_GRID[, c("name", "row", "col")]; names(pos)[1] <- "prov_name"
  g   <- merge(g, pos)
  med <- aggregate(gini ~ year, d$gini, median)
  ref <- merge(pos, med)                       # the median line, repeated in every province's cell
  lab <- pos; lab$year <- min(g$year); lab$gini <- max(g$gini, na.rm = TRUE) * 1.04
  ggplot(g, aes(year, gini)) +
    geom_line(data = ref, colour = "grey70", linewidth = 0.4) +
    geom_line(colour = BLUE, linewidth = 0.7) +
    geom_text(data = lab, aes(label = prov_name), hjust = 0, vjust = 1, size = 2.3, fontface = "bold", colour = "grey20") +
    facet_grid(row ~ col, drop = TRUE) +
    scale_x_continuous(breaks = c(2010, 2025), labels = c("'10", "'25")) +
    labs(title = sprintf("Gini ratio by province, %d–%d (March round)", min(g$year), max(g$year)),
         subtitle = "Arranged roughly as on the map, west to east; grey = median of all provinces",
         x = NULL, y = NULL, caption = SRC) +
    theme(strip.text = element_blank(), strip.background = element_blank(),
          panel.grid = element_blank(), panel.background = element_blank(),
          axis.text = element_text(size = 6), panel.spacing = unit(4, "pt"))
}

# 6. LISA cluster map: poverty rate ------------------------------------------
fig_lisa <- function(d, year = 2024) {
  m <- left_join(st_transform(d$geo, 3395), d$p0[d$p0$year == year, c("prov_name", "p0")], by = "prov_name")
  nb <- spdep::poly2nb(m, queen = TRUE, snap = 1000)
  iso <- which(spdep::card(nb) == 0)
  if (length(iso)) {   # island provinces without a land neighbour: link to the nearest one
    k1 <- spdep::knn2nb(spdep::knearneigh(st_coordinates(st_centroid(st_geometry(m))), k = 1))
    for (i in iso) { j <- k1[[i]]; nb[[i]] <- j; nb[[j]] <- sort(unique(c(nb[[j]][nb[[j]] > 0], i))) }
  }
  lw <- spdep::nb2listw(nb, style = "W")
  gm <- spdep::moran.test(m$p0, lw)
  lm <- spdep::localmoran(m$p0, lw)
  z <- as.numeric(scale(m$p0)); lz <- spdep::lag.listw(lw, z); pv <- lm[, 5]
  m$cluster <- factor(ifelse(pv >= 0.05, "Not significant",
                      ifelse(z > 0 & lz > 0, "High-High", ifelse(z < 0 & lz < 0, "Low-Low",
                      ifelse(z > 0, "High-Low", "Low-High")))),
                      levels = c("High-High", "Low-Low", "High-Low", "Low-High", "Not significant"))
  p <- ggplot(m) +
    geom_sf(aes(fill = cluster), colour = "white", linewidth = 0.15) +
    scale_fill_manual(values = c("High-High" = ORANGE, "Low-Low" = BLUE, "High-Low" = "#F2A766",
                                 "Low-High" = "#8DB6DD", "Not significant" = "grey88"), drop = FALSE, name = NULL) +
    labs(title = sprintf("Local clusters of poverty (P0, March %d): global Moran's I = %.2f (p %s)",
                         year, gm$estimate[1], format.pval(gm$p.value, digits = 2, eps = 0.001)),
         subtitle = "LISA, p < 0.05; Queen contiguity, island provinces linked to their nearest neighbour",
         caption = SRC) +
    theme_void() + theme(plot.title = element_text(face = "bold"), legend.position = "bottom",
                         plot.caption = element_text(colour = "grey40", size = 8))
  attr(p, "moran") <- gm
  attr(p, "isolated") <- m$prov_name[iso]
  p
}
