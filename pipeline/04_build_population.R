# =====================================================================
# 04_build_population.R : 人口パネル（33州, 2010–2025）と人口重み（38州）を作る
# =====================================================================
# 出所
#   2010       センサス（静的表1267）
#   2011–2014  2010年と2015年の間を等比で補間（公表値ではない）
#   2015–2019  SUPAS2015 推計（var 1886）
#   2020–2025  センサス2020 推計（var 2790）
# 人口は足せる量なので、33州への畳み込みは和。ただし var 2790 のように親州の行が
# 分割前の合計になっている年は、子州を足さない（全国値との一致で判定）。
#
# 出力：out/panel/population_33.csv   33州パネル
#       out/report/pop38_weights.csv  率・平均を畳むときの人口重み（縮小後の親州）
# =====================================================================
source(file.path(Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", ".")), "00_setup.R"), encoding = "UTF-8")

rdp <- function(f, yrs) { d <- rd(file.path(DIR_RAW, f)); d[d$year %in% yrs, c("prov_name", "year", "value")] }
cen <- rdp("sta_census_pop.csv",     2010)
sup <- rdp("dyn_pop_supas2015.csv",  2015:2019)
sp  <- rdp("dyn_pop_sp2020.csv",     2020:2025)

parts <- list(cen = cen, sup = sup, sp = sp)
p33 <- do.call(rbind, lapply(parts, function(d) collapse33(d, "ext")[, c("prov_name", "year", "value")]))

# 2011–2014：等比補間
e <- merge(p33[p33$year == 2010, ], p33[p33$year == 2015, ], by = "prov_name", suffixes = c(".a", ".b"))
mid <- do.call(rbind, lapply(2011:2014, function(t) data.frame(
  prov_name = e$prov_name, year = t,
  value = round(e$value.a * (e$value.b / e$value.a)^((t - 2010) / 5)))))
pop33 <- rbind(p33, mid)
pop33$indicator <- "population"
pop33$source <- ifelse(pop33$year == 2010, "BPS static table 1267 (Census 2010)",
                ifelse(pop33$year <= 2014, "Geometric interpolation 2010-2015",
                ifelse(pop33$year <= 2019, "BPS var 1886 (SUPAS 2015 projection)",
                                           "BPS var 2790 (Census 2020 projection)")))
pop33 <- pop33[order(pop33$year, pop33$prov_name), c("prov_name", "indicator", "year", "value", "source")]
wr(pop33, file.path(DIR_PANEL, "population_33.csv"))

# 人口重み（38州レベル、親州は縮小後の人口に直す）
w <- rbind(cen[cen$prov_name != "INDONESIA", ],
           shrink_parent(sup)[, c("prov_name", "year", "value")],
           shrink_parent(sp)[, c("prov_name", "year", "value")])
w <- w[w$prov_name != "INDONESIA" & !is.na(w$value), ]
wr(w, file.path(DIR_REPORT, "pop38_weights.csv"))

# --- 検算 ------------------------------------------------------------
cat("=== 人口：33州の和と全国値 ===\n")
nat <- do.call(rbind, lapply(parts, function(d) d[d$prov_name == "INDONESIA", c("year", "value")]))
chk <- merge(aggregate(value ~ year, pop33, sum), nat, by = "year", all.x = TRUE, suffixes = c("_33", "_nat"))
chk$n_prov <- as.integer(table(pop33$year)[as.character(chk$year)])
chk$diff_pct <- round(100 * (chk$value_33 / chk$value_nat - 1), 3)
print(chk, row.names = FALSE)
dec <- do.call(rbind, lapply(parts, function(d) detect_parent_total(d)))
dec <- dec[dec$parent_is_total, ]
cat("\n親州の行が分割前の合計だった年（子州を足さなかった）:\n")
if (nrow(dec)) print(dec, row.names = FALSE) else cat("  なし\n")
wr(chk, file.path(DIR_REPORT, "check_population.csv"))
