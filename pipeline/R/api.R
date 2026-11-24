# =====================================================================
# api.R : BPS WebAPI への問い合わせ（動的表・静的表）と州名の扱い
# =====================================================================
#   get_json()       1回の問い合わせ。失敗しても止めず status と理由を返す
#   bps_years()      動的表の収録年（全ページ読む。一覧は1ページ10件）
#   fetch_var()      動的表の値を、指定した区分・期間で全地域・全年ぶん取る
#   static_tables()  静的表の中身（HTML の表）を data.frame のリストで返す
#   norm_prov()      BPS の州名 → このプロジェクトの州名（GADM 表記）
#   select_prov()    取得した行から、地域コードで州と全国だけを選ぶ
#
# 必要なもの：~/.Renviron に BPS_API_KEY=...、パッケージ jsonlite（静的表は rvest も）
# API キーは画面にもファイルにも出さない（エラー文中のキーは <KEY> に置き換える）
# =====================================================================

for (p in c("jsonlite", "rvest")) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

BPS_KEY  <- Sys.getenv("BPS_API_KEY", unset = "")
if (!nzchar(BPS_KEY)) stop("BPS_API_KEY がありません（usethis::edit_r_environ() で設定）", call. = FALSE)
BPS_BASE <- "https://webapi.bps.go.id/v1/api/"
.mask <- function(s) gsub(BPS_KEY, "<KEY>", s, fixed = TRUE)

# 問い合わせの間隔（秒）。短くしすぎると BPS 側で弾かれる
BPS_WAIT <- 0.5

get_json <- function(path, retry = TRUE) {
  Sys.sleep(BPS_WAIT)
  u <- paste0(BPS_BASE, path, "/key/", BPS_KEY, "/")
  w <- NULL
  txt <- tryCatch(
    withCallingHandlers(
      paste(readLines(u, warn = FALSE, encoding = "UTF-8"), collapse = ""),
      warning = function(x) { w <<- conditionMessage(x); invokeRestart("muffleWarning") }),
    error = function(e) NULL)
  if (is.null(txt)) {
    if (retry) { Sys.sleep(3); return(get_json(path, retry = FALSE)) }
    return(list(status = "HTTP_ERROR", message = .mask(if (is.null(w)) "接続失敗" else w)))
  }
  tryCatch(jsonlite::fromJSON(txt, simplifyVector = TRUE),
           error = function(e) list(status = "PARSE_ERROR", message = substr(.mask(txt), 1, 200)))
}

bps_years <- function(var_id) {
  yrs <- integer(0); p <- 1
  repeat {
    r <- get_json(sprintf("list/model/th/lang/eng/domain/0000/var/%d/page/%d", var_id, p))
    if (!identical(r$status, "OK") || length(r$data) < 2) break
    yrs <- c(yrs, suppressWarnings(as.integer(r$data[[2]]$th)))
    pages <- suppressWarnings(as.integer(r$data[[1]]$pages)); if (is.na(pages)) pages <- 1
    if (p >= pages) break
    p <- p + 1
  }
  sort(unique(stats::na.omit(yrs)))
}

# 単位の文字列から倍率を推定する（推定した結果は必ず記録・表示する）
unit_mult <- function(unit) {
  u <- tolower(paste(unit))
  if (grepl("thousand|ribu", u)) return(1e3)
  if (grepl("million|juta",   u)) return(1e6)
  if (grepl("billion|miliar", u)) return(1e9)
  1
}

# ---------------------------------------------------------------------
# fetch_var
#   turvar   : 区分のラベル。"A|B" と書くと、A が無い表では B を使う
#              （表によって "Total" だったり "Urban+Rural" だったりするため）
#              区分が1つしか無い表は "" でよい。区分が複数あるのに指定が無ければ止まる
#   turtahun : 期間のラベル。"A > B" と書くと、A に値が無い年は B を使う
#   1年ずつ問い合わせ、値は「地域＋変数＋区分＋年＋期間」の連結キーを組み立てて引く
#   戻り値には表の単位（unit）を列として付ける
# ---------------------------------------------------------------------
fetch_var <- function(var_id, years, turvar = "", turtahun = "Annual") {
  ys <- intersect(years, bps_years(var_id))
  if (!length(ys)) stop("var ", var_id, ": 指定した年が収録されていません")
  prio <- trimws(strsplit(turtahun, ">", fixed = TRUE)[[1]])
  alts <- if (is.na(turvar) || !nzchar(turvar)) character(0) else trimws(strsplit(turvar, "|", fixed = TRUE)[[1]])

  out <- list()
  for (y in ys) {
    r <- get_json(sprintf("list/model/data/lang/eng/domain/0000/var/%d/th/%d", var_id, y - 1900))
    if (!identical(r$status, "OK") || is.null(r$datacontent)) {
      stop("var ", var_id, " ", y, ": ", paste(r$status, unlist(r$message)))
    }
    vv <- r$vervar; tv <- r$turvar; tt <- r$turtahun
    if (!length(alts)) {
      if (nrow(tv) > 1) stop("var ", var_id, ": 区分が複数あります → ", paste(tv$label, collapse = " | "))
      tv_sel <- tv[1, , drop = FALSE]
    } else {
      hit <- alts[tolower(alts) %in% tolower(tv$label)][1]
      if (is.na(hit)) stop("var ", var_id, ": 区分 '", turvar, "' がありません → ", paste(tv$label, collapse = " | "))
      tv_sel <- tv[tolower(tv$label) == tolower(hit), , drop = FALSE][1, , drop = FALSE]
    }
    thv <- r$tahun$val[r$tahun$label == as.character(y)]
    if (!length(thv)) thv <- y - 1900
    dc <- unlist(r$datacontent)
    for (pl in prio) {
      ttv <- tt$val[tolower(tt$label) == tolower(pl)]
      if (!length(ttv)) next
      val <- suppressWarnings(as.numeric(dc[paste0(vv$val, var_id, tv_sel$val, thv, ttv)]))
      if (sum(!is.na(val)) > 0) {
        out[[length(out) + 1]] <- data.frame(
          region_code = as.character(vv$val), region_raw = vv$label, year = y,
          turvar = tv_sel$label, turtahun = pl, value = val,
          unit = paste(r$var$unit[1]), stringsAsFactors = FALSE)
        break
      }
    }
  }
  if (!length(out)) stop("var ", var_id, ": 値が1件も取れませんでした")
  d <- do.call(rbind, out)
  d$var_id <- var_id
  d
}

# ---------------------------------------------------------------------
# 静的表：中身は HTML の表。view のレスポンスの data$table にエスケープされて入っている
# ---------------------------------------------------------------------
.unescape <- function(x) {
  for (p in list(c("&lt;", "<"), c("&gt;", ">"), c("&quot;", '"'), c("&#39;", "'"),
                 c("&nbsp;", " "), c("&amp;", "&"))) x <- gsub(p[1], p[2], x, fixed = TRUE)
  x
}
static_tables <- function(id) {
  r <- get_json(sprintf("view/model/statictable/lang/eng/domain/0000/id/%d", id))
  if (!identical(r$status, "OK")) stop("static ", id, ": ", paste(r$status, unlist(r$message)))
  html <- r$data$table
  if (is.null(html) || !nzchar(html)) stop("static ", id, ": data$table が空です")
  tb <- rvest::html_table(rvest::read_html(.unescape(html)), fill = TRUE)
  attr(tb, "title") <- paste(r$data$title)
  attr(tb, "updated") <- paste(r$data$updt_date)
  tb
}

# ---------------------------------------------------------------------
# 州名（33州＋分割で生まれた5州）
# ---------------------------------------------------------------------
PROV33 <- c("Aceh", "Sumatera Utara", "Sumatera Barat", "Riau", "Jambi", "Sumatera Selatan",
            "Bengkulu", "Lampung", "Bangka Belitung", "Kepulauan Riau", "Jakarta Raya",
            "Jawa Barat", "Jawa Tengah", "Yogyakarta", "Jawa Timur", "Banten", "Bali",
            "Nusa Tenggara Barat", "Nusa Tenggara Timur", "Kalimantan Barat",
            "Kalimantan Tengah", "Kalimantan Selatan", "Kalimantan Timur", "Sulawesi Utara",
            "Sulawesi Tengah", "Sulawesi Selatan", "Sulawesi Tenggara", "Gorontalo",
            "Sulawesi Barat", "Maluku", "Maluku Utara", "Papua Barat", "Papua")
TO33 <- c("Kalimantan Utara" = "Kalimantan Timur",
          "Papua Barat Daya" = "Papua Barat",
          "Papua Selatan" = "Papua", "Papua Tengah" = "Papua", "Papua Pegunungan" = "Papua")

# HTML タグを除く（県込みの表では州の行が <b>ACEH</b> のように太字タグ付き）
.strip_html <- function(x) trimws(gsub("\\s+", " ", gsub("<[^>]+>", "", x)))
# 照合用のキー：脚注番号 "1)"・記号・空白を落として大文字に
.pkey <- function(x) gsub("[^A-Z]", "", toupper(gsub("\\s*[0-9]+\\)\\s*$", "", .strip_html(x))))
.alias <- c(DKIJAKARTA = "Jakarta Raya", JAKARTA = "Jakarta Raya",
            DIYOGYAKARTA = "Yogyakarta", DAERAHISTIMEWAYOGYAKARTA = "Yogyakarta",
            KEPBANGKABELITUNG = "Bangka Belitung", KEPULAUANBANGKABELITUNG = "Bangka Belitung",
            KEPRIAU = "Kepulauan Riau",
            NTB = "Nusa Tenggara Barat", NTT = "Nusa Tenggara Timur")  # 静的表 1276 は "N T B" / "N T T"
.lookup <- c(setNames(c(PROV33, names(TO33)), .pkey(c(PROV33, names(TO33)))), .alias)

#' 州名をそろえる。全国は "INDONESIA"、対応づけられないものは NA
norm_prov <- function(x) {
  x <- gsub("^\\s*(PROV(INSI|INCE)?|PROP(INSI)?)\\.?\\s+", "", .strip_html(x), ignore.case = TRUE)
  k <- .pkey(x)
  out <- unname(.lookup[k])
  out[k == "INDONESIA"] <- "INDONESIA"
  out
}

#' 動的表の行から、州と全国だけを地域コードで選ぶ（名前だけで選ぶと同名の県を拾う）
select_prov <- function(d) {
  code   <- as.character(d$region_code)
  is_nat <- code %in% c("9999", "0000") | .pkey(d$region_raw) == "INDONESIA"
  keep   <- is_nat | grepl("^[0-9]{2}(00)?$", code)
  d <- d[keep, , drop = FALSE]
  d$region_raw <- .strip_html(d$region_raw)
  d$prov_name  <- ifelse(is_nat[keep], "INDONESIA", norm_prov(d$region_raw))
  bad <- unique(d$region_raw[is.na(d$prov_name)])
  if (length(bad)) stop("州名を対応づけられません: ", paste(bad, collapse = " / "))
  d
}
