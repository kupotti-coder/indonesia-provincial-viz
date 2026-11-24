# =====================================================================
# 03_fetch_static.R : 静的表を取得して縦長に開く（indicators.csv の source = sta）
# =====================================================================
# 出力：out/raw/sta_<name>.csv   州（＋全国）× 指標 × 年
# 表ごとに先頭6行を表示する。形が想定と違えば、ここで止まる。
# 所要：1分程度
# =====================================================================
source(file.path(Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", ".")), "00_setup.R"), encoding = "UTF-8")

parse_map <- function(x) {
  if (is.na(x) || !nzchar(x)) return(NULL)
  kv <- strsplit(strsplit(x, ";", fixed = TRUE)[[1]], "=", fixed = TRUE)
  setNames(vapply(kv, `[`, "", 2), vapply(kv, `[`, "", 1))
}

spec <- SPEC[SPEC$source == "sta" & SPEC$name %in% only(SPEC$name), ]
log <- list()
for (i in seq_len(nrow(spec))) {
  s <- spec[i, ]
  cat(sprintf("\n[%d/%d] %s（静的表 %d）\n", i, nrow(spec), s$name, s$id))
  res <- tryCatch({
    tb <- static_tables(s$id)
    cat("  表題:", attr(tb, "title"), "\n  表の数:", length(tb), "\n")
    static_peek(tb[[1]])
    d <- parse_static_long(tb[[1]], group_map = parse_map(s$group_key), indicator = s$name)
    d$value <- d$value * as.numeric(s$mult)
    d$static_id <- s$id
    wr(d, file.path(DIR_RAW, paste0("sta_", s$name, ".csv")))
    pv <- d[d$prov_name != "INDONESIA", ]
    cat(sprintf("  OK  指標 %s  年 %d–%d  州数 %d〜%d\n", paste(unique(d$indicator), collapse = ", "),
                min(d$year), max(d$year), min(table(pv$year)) / length(unique(pv$indicator)),
                max(table(pv$year)) / length(unique(pv$indicator))))
    data.frame(name = s$name, ok = TRUE, indicators = paste(unique(d$indicator), collapse = ";"),
               from = min(d$year), to = max(d$year), message = "", fetched = format(Sys.Date()))
  }, error = function(e) {
    cat("  失敗:", .mask(conditionMessage(e)), "\n")
    data.frame(name = s$name, ok = FALSE, indicators = NA, from = NA, to = NA,
               message = .mask(conditionMessage(e)), fetched = format(Sys.Date()))
  })
  log[[s$name]] <- res
}
log <- do.call(rbind, log)
wr(log, file.path(DIR_REPORT, "fetch_log_static.csv"))
cat("\n=== 静的表の取得記録 ===\n"); print(log[, c("name", "ok", "indicators", "from", "to")], row.names = FALSE)
