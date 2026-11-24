# =====================================================================
# 05_build_panel33.R : 全指標を33州に畳み、検算し、1つのパネルと変数辞書にまとめる
# =====================================================================
# 入力：out/raw/dyn_*.csv, out/raw/sta_*.csv, out/panel/population_33.csv,
#       out/report/pop38_weights.csv（04 の出力）
# 出力：out/panel/<indicator>_33.csv   指標ごと（prov_name, indicator, year, value, source）
#       out/panel/panel33_long.csv     全指標を縦につないだもの
#       out/panel/variables.csv        変数辞書（出所・期間・畳み方・収録年・全国値との差）
#       out/report/check_national.csv  年ごとの全国値との照合
# 派生指標（ここで作る）
#   eys           期待就学年数：男女の単純平均（BPS に男女計が無い）
#   food_share    食料支出の割合（%）＝ 食料 ÷ 総支出
#   real_exp_pc   実質一人当たり支出 ＝ 総支出 ÷ 貧困線（地域の物価差を除いた倍率）
#   grdp_growth   実質 GRDP の成長率（33州の総額から計算）
# =====================================================================
source(file.path(Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", ".")), "00_setup.R"), encoding = "UTF-8")

w_of  <- make_weight_fun(rd(file.path(DIR_REPORT, "pop38_weights.csv")))
pop33 <- rd(file.path(DIR_PANEL, "population_33.csv"))[, c("prov_name", "year", "value")]
names(pop33)[3] <- "pop"

# --- 38州レベルの材料を集める ---------------------------------------
items <- list()   # 各要素：list(data, kind, label, src)
add <- function(name, d, kind, label, src) items[[name]] <<- list(d = d[, c("prov_name", "year", "value")], kind = kind, label = label, src = src)

for (i in which(SPEC$source == "dyn" & !grepl("^pop_", SPEC$name))) {
  s <- SPEC[i, ]; f <- file.path(DIR_RAW, paste0("dyn_", s$name, ".csv"))
  if (!file.exists(f)) { cat("（未取得）", s$name, "\n"); next }
  d <- rd(f)
  add(s$name, d, s$kind, s$label, sprintf("BPS var %d (%s)", s$id, paste(unique(d$turtahun), collapse = " / ")))
}
for (i in which(SPEC$source == "sta" & SPEC$name != "census_pop")) {
  s <- SPEC[i, ]; f <- file.path(DIR_RAW, paste0("sta_", s$name, ".csv"))
  if (!file.exists(f)) { cat("（未取得）", s$name, "\n"); next }
  d <- rd(f)
  for (ind in unique(d$indicator))
    add(ind, d[d$indicator == ind, ], s$kind, paste(s$label, "-", ind), sprintf("BPS static table %d", s$id))
}

# 派生（38州レベル）：期待就学年数の男女計、食料支出の割合
pair <- function(a, b, f) { m <- merge(items[[a]]$d, items[[b]]$d, by = c("prov_name", "year")); data.frame(prov_name = m$prov_name, year = m$year, value = f(m$value.x, m$value.y)) }
if (all(c("eys_male", "eys_female") %in% names(items))) {
  add("eys", pair("eys_male", "eys_female", function(a, b) (a + b) / 2), "int",
      "Expected years of schooling (mean of male and female)", "Derived from BPS var 457 (male, female)")
  items$eys_male <- NULL; items$eys_female <- NULL
}
if (all(c("exp_food", "exp_total") %in% names(items)))
  add("food_share", pair("exp_food", "exp_total", function(a, b) 100 * a / b), "int",
      "Food share of expenditure (%)", "Derived from BPS static table 945")

# --- 33州に畳む ------------------------------------------------------
panel <- list(pop = rd(file.path(DIR_PANEL, "population_33.csv")))
dict <- list(); natc <- list(); jumps <- list(); decs <- list()
for (nm in names(items)) {
  it <- items[[nm]]
  p <- collapse33(it$d, it$kind, w_of)
  dec <- attr(p, "decisions"); if (!is.null(dec) && any(dec$parent_is_total)) decs[[nm]] <- cbind(indicator = nm, dec[dec$parent_is_total, ])
  if (it$kind == "int") { j <- jump_check(p); if (!is.null(j)) jumps[[nm]] <- cbind(indicator = nm, j) }
  nat <- it$d[it$d$prov_name == "INDONESIA", ]
  cmp <- if (nrow(nat)) national_check(p, nat, it$kind, pop33) else NULL
  if (!is.null(cmp) && nrow(cmp)) natc[[nm]] <- cbind(indicator = nm, cmp)
  src <- paste0(it$src, "; 33 provinces by ", if (it$kind == "int") "population-weighted mean" else "sum")
  out <- data.frame(prov_name = p$prov_name, indicator = nm, year = p$year, value = p$value, source = src)
  panel[[nm]] <- out
  wr(out, file.path(DIR_PANEL, paste0(nm, "_33.csv")))
  n <- table(p$year)
  dict[[nm]] <- data.frame(indicator = nm, label = it$label, kind = it$kind, source = src,
    from = min(p$year), to = max(p$year), n_years = length(n),
    prov_per_year = paste(unique(range(n)), collapse = "-"),
    max_abs_national_diff_pct = if (is.null(cmp) || !nrow(cmp)) NA else round(max(abs(cmp$diff_pct)), 2))
}

# --- 33州レベルの派生 ------------------------------------------------
if (!is.null(panel$exp_total) && !is.null(panel$poverty_line)) {
  m <- merge(panel$exp_total, panel$poverty_line, by = c("prov_name", "year"))
  panel$real_exp_pc <- data.frame(prov_name = m$prov_name, indicator = "real_exp_pc", year = m$year,
    value = m$value.x / m$value.y, source = "Derived: exp_total / poverty_line (multiples of the poverty line)")
}
if (!is.null(panel$grdp_total_const)) {
  g <- panel$grdp_total_const[order(panel$grdp_total_const$prov_name, panel$grdp_total_const$year), ]
  g$value <- ave(g$value, g$prov_name, FUN = function(v) c(NA, 100 * (v[-1] / v[-length(v)] - 1)))
  g <- g[!is.na(g$value), ]; g$indicator <- "grdp_growth"
  g$source <- "Derived: annual growth of GRDP at 2010 prices (33-province totals)"
  panel$grdp_growth <- g
}
for (nm in intersect(c("real_exp_pc", "grdp_growth"), names(panel))) {
  wr(panel[[nm]], file.path(DIR_PANEL, paste0(nm, "_33.csv")))
  p <- panel[[nm]]; n <- table(p$year)
  dict[[nm]] <- data.frame(indicator = nm, label = nm, kind = "derived", source = p$source[1],
    from = min(p$year), to = max(p$year), n_years = length(n),
    prov_per_year = paste(unique(range(n)), collapse = "-"), max_abs_national_diff_pct = NA)
}

long <- do.call(rbind, lapply(panel, function(x) x[, c("prov_name", "indicator", "year", "value", "source")]))
long <- long[long$year %in% YEARS, ]
wr(long, file.path(DIR_PANEL, "panel33_long.csv"))
dict <- do.call(rbind, dict)
wr(dict, file.path(DIR_PANEL, "variables.csv"))
if (length(natc)) wr(do.call(rbind, natc), file.path(DIR_REPORT, "check_national.csv"))

# --- 要約 ------------------------------------------------------------
cat("\n=== 33州パネル：変数辞書 ===\n")
print(dict[, c("indicator", "kind", "from", "to", "prov_per_year", "max_abs_national_diff_pct")], row.names = FALSE)
cat("\n=== 人数・総額で、親州の行が分割前の合計だった年 ===\n")
if (length(decs)) print(do.call(rbind, decs), row.names = FALSE) else cat("  なし\n")
cat("\n=== 率・平均：子州が初めて現れた年の前後（combined が prev に近ければ正しく畳めている）===\n")
if (length(jumps)) print(do.call(rbind, jumps), row.names = FALSE)
cat("\n行数:", nrow(long), " 指標数:", length(unique(long$indicator)), "\n")
cat("出力:", normalizePath(DIR_PANEL), "\n")
