# =====================================================================
# 02_fetch_dynamic.R : 動的表を取得する（indicators.csv の source = dyn）
# =====================================================================
# 出力：out/raw/dyn_<name>.csv   38州＋全国、BPS のまま（単位換算だけ済ませる）
#       out/raw/regions_<name>.csv  その表の地域一覧（州名の付け方の記録）
#       out/report/fetch_log.csv    取得記録（一部やり直しても前回分は残す）
# 所要：約10分（約20表 × 16年、1年1リクエスト）
# =====================================================================
source(file.path(Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", ".")), "00_setup.R"), encoding = "UTF-8")

spec <- SPEC[SPEC$source == "dyn" & SPEC$name %in% only(SPEC$name), ]
log <- list()
for (i in seq_len(nrow(spec))) {
  s <- spec[i, ]
  cat(sprintf("[%2d/%d] %-20s var %-5d ", i, nrow(spec), s$name, s$id))
  res <- tryCatch({
    d <- fetch_var(s$id, YEARS, turvar = s$turvar, turtahun = s$turtahun)
    wr(unique(d[, c("region_code", "region_raw")]), file.path(DIR_RAW, paste0("regions_", s$name, ".csv")))
    d <- select_prov(d)
    m <- if (identical(s$mult, "auto")) unit_mult(d$unit[1]) else as.numeric(s$mult)
    d$value <- d$value * m
    d$indicator <- s$name
    wr(d[, c("prov_name", "region_code", "region_raw", "indicator", "year", "turvar", "turtahun",
             "value", "unit", "var_id")], file.path(DIR_RAW, paste0("dyn_", s$name, ".csv")))
    pv <- d[d$prov_name != "INDONESIA" & !is.na(d$value), ]
    n <- tapply(pv$prov_name, pv$year, function(x) length(unique(x)))
    cat(sprintf("OK  %d–%d  州数 %d〜%d  単位「%s」×%g\n", min(d$year), max(d$year), min(n), max(n), d$unit[1], m))
    data.frame(name = s$name, ok = TRUE, from = min(d$year), to = max(d$year), prov_min = min(n),
               prov_max = max(n), national = any(d$prov_name == "INDONESIA"), unit = d$unit[1], mult = m,
               turvar = d$turvar[1], periods = paste(unique(d$turtahun), collapse = " / "), message = "",
               fetched = format(Sys.Date()))
  }, error = function(e) {
    cat("失敗:", .mask(conditionMessage(e)), "\n")
    data.frame(name = s$name, ok = FALSE, from = NA, to = NA, prov_min = NA, prov_max = NA, national = NA,
               unit = NA, mult = NA, turvar = NA, periods = NA, message = .mask(conditionMessage(e)),
               fetched = format(Sys.Date()))
  })
  log[[s$name]] <- res
}
log <- do.call(rbind, log)
lf <- file.path(DIR_REPORT, "fetch_log.csv")
if (file.exists(lf)) { old <- rd(lf); log <- rbind(old[!old$name %in% log$name, names(log)], log) }
wr(log, lf)
cat("\n=== 動的表の取得記録 ===\n"); print(log[, c("name", "ok", "from", "to", "prov_min", "prov_max", "unit", "mult", "periods")], row.names = FALSE)
