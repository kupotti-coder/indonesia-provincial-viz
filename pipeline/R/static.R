# =====================================================================
# static.R : 静的表（HTML の表）を「州 × 指標 × 年」の縦長に開く
# =====================================================================
# 静的表は表ごとに形が違うので、列の位置を決め打ちしない。
# 共通しているのは「どこかに年が並んだ行がある」ことなので、その行を基準に読む。
#
#   年の行     ：1960–2035 の4桁が3つ以上並ぶ最初の行（"1 980" のような空白入りも読む）
#   グループ行 ：年の行の1つ上。1つの表に複数の指標が横に並ぶとき、ここで区別する
#                例 静的表951：Calories ×19年 | Protein ×19年
#   州名の列   ：1列目
#   数値       ："2 210.02" のように空白が桁区切り。"-" は欠測
#
# 州名として対応づけられない行（末尾の脚注など）は落として、何を落としたか表示する。
# 1州×1指標×1年に2行以上あれば止める（グループの割り当てを間違えている）。
# =====================================================================

.int_of <- function(x) suppressWarnings(as.integer(gsub("[^0-9]", "", x)))
.num_of <- function(x) {
  z <- gsub("[^0-9.-]", "", as.character(x))
  z[z %in% c("", "-", ".", "--")] <- NA_character_
  suppressWarnings(as.numeric(z))
}

#' 表の先頭を文字で表示する（形を確かめるため）
static_peek <- function(tb, n = 6) {
  m <- as.data.frame(tb, stringsAsFactors = FALSE)
  for (i in seq_len(min(n, nrow(m)))) {
    cells <- substr(gsub("\\s+", " ", as.character(unlist(m[i, ]))), 1, 18)
    cat(sprintf("  行%-2d| %s\n", i, paste(utils::head(cells, 10), collapse = " | ")))
  }
  cat(sprintf("  （%d行 × %d列）\n", nrow(m), ncol(m)))
}

#' @param group_map  グループ行のキーワード → 指標名。名前の順に当てていき、後のものが上書きする
#'                   （例 c(Food = "exp_food", Non = "exp_nonfood", Total = "exp_total") なら
#'                     "Non Food" は先に exp_food になり、次に exp_nonfood で上書きされる）
#'                   NULL なら表全体を indicator 1つとして読む
parse_static_long <- function(tb, group_map = NULL, indicator = "value") {
  m <- as.data.frame(tb, stringsAsFactors = FALSE)
  is_year_row <- apply(m, 1, function(r) {
    d <- .int_of(r); sum(!is.na(d) & d >= 1960 & d <= 2035) >= 3
  })
  hdr <- which(is_year_row)[1]
  if (is.na(hdr)) stop("年の行が見つかりません")
  yrs  <- .int_of(unlist(m[hdr, ]))
  ycol <- which(!is.na(yrs) & yrs >= 1960 & yrs <= 2035)

  ind <- rep(indicator, ncol(m))
  if (!is.null(group_map)) {
    if (hdr < 2) stop("グループ行がありません")
    grp <- as.character(unlist(m[hdr - 1, ]))
    ind <- rep(NA_character_, ncol(m))
    for (k in names(group_map)) ind[grepl(k, grp, ignore.case = TRUE)] <- group_map[[k]]
  }
  keep <- ycol[!is.na(ind[ycol])]
  if (!length(keep)) stop("group_map がどの列にも当たりません")
  cat(sprintf("  年の行=%d  年=%s  値の列=%d\n", hdr, paste(range(yrs[ycol]), collapse = "-"), length(keep)))
  if (!is.null(group_map)) print(table(ind[keep]))

  body <- m[(hdr + 1):nrow(m), , drop = FALSE]
  prov <- norm_prov(body[[1]])
  raw1 <- .strip_html(body[[1]])
  dropped <- unique(raw1[is.na(prov) & nzchar(raw1)])
  if (length(dropped)) {
    cat("  [!] 州名として対応づけられない行を落としました（脚注などのはず）:\n")
    for (b in dropped) cat("      ", substr(b, 1, 70), "\n")
  }
  ok <- !is.na(prov)
  out <- do.call(rbind, lapply(keep, function(j) data.frame(
    prov_name = prov[ok], indicator = ind[j], year = yrs[j],
    value = .num_of(body[[j]][ok]), stringsAsFactors = FALSE)))
  out <- out[!is.na(out$value), ]

  dup <- stats::aggregate(value ~ prov_name + indicator + year, data = out, FUN = length)
  if (any(dup$value > 1)) {
    print(utils::head(dup[dup$value > 1, ], 10))
    stop("1州×1指標×1年に複数行があります。group_map を見直してください")
  }
  out[order(out$indicator, out$year, out$prov_name), ]
}
