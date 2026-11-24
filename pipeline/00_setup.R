# =====================================================================
# 00_setup.R : パイプライン共通の設定（他のスクリプトの先頭で読む）
# =====================================================================
# 作業ディレクトリはこのリポジトリの直下を想定（get_data.R から呼ばれる）。setwd() はしない。
# このパイプラインは pCloud のファイルに一切依存しない（0 から作り直せる）。
# =====================================================================

PIPE <- Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", "."))
for (f in c("api.R", "static.R", "harmonise.R")) source(file.path(PIPE, "R", f), encoding = "UTF-8")

YEARS <- 2010:2025

DIR_RAW    <- file.path(PIPE, "out", "raw")      # BPS から取ったまま（38州＋全国）
DIR_PANEL  <- file.path(PIPE, "out", "panel")    # 33州パネル（分析・アプリ用）
DIR_REPORT <- file.path(PIPE, "out", "report")   # 取得記録・検算結果
for (d in c(DIR_RAW, DIR_PANEL, DIR_REPORT)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

SPEC <- read.csv(file.path(PIPE, "indicators.csv"), stringsAsFactors = FALSE,
                 na.strings = "", strip.white = TRUE)

rd <- function(f) read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
wr <- function(x, f) write.csv(x, f, row.names = FALSE, fileEncoding = "UTF-8")

# 一部だけやり直すとき：ONLY <- c("gini") を定義してから source する
only <- function(names) if (exists("ONLY", envir = globalenv()) && length(get("ONLY", envir = globalenv())))
  names[names %in% get("ONLY", envir = globalenv())] else names
