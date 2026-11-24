# =====================================================================
# harmonise.R : 38州 → 33州（2010年の区画）への畳み込みと検算
# =====================================================================
# 2012年以降に分かれた州を親州に戻す
#   Kalimantan Utara → Kalimantan Timur
#   Papua Barat Daya → Papua Barat
#   Papua Selatan / Papua Tengah / Papua Pegunungan → Papua
#
# 【表によって親州の行の意味が違う】
#   多くの表では、親州の行は「分割後の縮小した州」。子州と足して元の州になる。
#   しかし年齢別人口（var 2790）では、パプア・西パプアの行が「分割前の合計」のまま
#   で、子州も別に載っている。そのまま足すと二重計上になる。
#   → 人数・総額（ext）は、親州グループごとに「子州を足すか」を決める
#     （系列の連続性で判定。前年が無いときだけ全国値との一致で判定）
#   → 率・平均（int）は、縮小後の親州の人口で重みを作って加重平均する
# =====================================================================

GROUPS <- list("Kalimantan Timur" = "Kalimantan Utara",
               "Papua Barat"      = "Papua Barat Daya",
               "Papua"            = c("Papua Selatan", "Papua Tengah", "Papua Pegunungan"))

#' 親州の行が分割前の合計かを判定する（@return parent, year, parent_is_total, method）
detect_parent_total <- function(d) {
  # 親州の行が「分割前の合計」か「分割後の縮小した州」かを、親州グループごとに判定する。
  #  (a) 子州が初めて現れた年の前年に親州の値があれば、系列の連続性で判定する
  #      親州の行だけで前年に近い → 分割前の合計（子州を足すと跳ねる）
  #      子州を足すと前年に近い   → 縮小後の州
  #  (b) 前年が無い（表の最初から子州がある）グループだけ、全国値で判定する
  #      全国値を超えた分が、どのグループの子州の合計とちょうど一致するか（誤差10%以内）
  # 全国値だけで判定すると、州の合計と全国値が統計上もともと少しずれる表（GRDP など）で
  # 誤判定する。1つずつ順に判定すると、パプアの過大分を北カリマンタンで打ち消す誤判定も起きた。
  x <- d[!is.na(d$value), ]
  pv <- function(p, y) x$value[x$prov_name == p & x$year == y][1]
  chv <- function(p, y) sum(x$value[x$prov_name %in% GROUPS[[p]] & x$year == y])
  out <- list(); fallback <- character(0)
  for (p in names(GROUPS)) {
    yc <- sort(unique(x$year[x$prov_name %in% GROUPS[[p]]]))
    if (!length(yc)) next
    prev <- sort(unique(x$year[x$prov_name == p & x$year < yc[1]]))
    if (length(prev)) {
      b <- pv(p, max(prev)); a <- pv(p, yc[1]); c <- chv(p, yc[1])
      tot <- !is.na(a) && abs(a - b) < abs(a + c - b)
      out[[p]] <- data.frame(parent = p, year = yc, parent_is_total = tot, method = "continuity")
    } else fallback <- c(fallback, p)
  }
  if (length(fallback)) {
    rows <- list()
    for (y in sort(unique(x$year))) {
      gs <- fallback[sapply(fallback, function(p) chv(p, y) > 0)]
      if (!length(gs)) next
      n <- x$value[x$prov_name == "INDONESIA" & x$year == y][1]
      s <- sum(x$value[x$prov_name != "INDONESIA" & x$year == y])
      for (q in names(out)) if (out[[q]]$parent_is_total[1] && y %in% out[[q]]$year) s <- s - chv(q, y)
      flag <- setNames(rep(FALSE, length(gs)), gs)
      if (!is.na(n)) {
        cmb <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), length(gs)))); best <- Inf
        for (k in seq_len(nrow(cmb))) {
          if (!any(cmb[k, ])) next
          D <- sum(sapply(gs[cmb[k, ]], chv, y = y)); err <- abs((s - n) - D) / D
          if (err < 0.1 && err < best) { best <- err; flag[] <- cmb[k, ] }
        }
      }
      rows[[length(rows) + 1]] <- data.frame(parent = gs, year = y, parent_is_total = unname(flag), method = "national")
    }
    out <- c(out, rows)
  }
  if (length(out)) do.call(rbind, out)
  else data.frame(parent = character(), year = integer(), parent_is_total = logical(), method = character())
}

#' 親州の行が合計だった年は、親州から子州を引いて「縮小後の州」に直す（人口重み用）
shrink_parent <- function(d) {
  pt <- detect_parent_total(d)
  for (i in which(pt$parent_is_total)) {
    p <- pt$parent[i]; y <- pt$year[i]
    ch <- sum(d$value[d$year == y & d$prov_name %in% GROUPS[[p]]], na.rm = TRUE)
    j <- d$year == y & d$prov_name == p
    d$value[j] <- d$value[j] - ch
  }
  attr(d, "decisions") <- pt
  d
}

#' 重み：各州のいちばん近い年の人口（重みは親州グループ内の比だけが効く）
make_weight_fun <- function(pop38) {
  function(prov, year) mapply(function(p, y) {
    x <- pop38[pop38$prov_name == p, ]
    if (!nrow(x)) return(NA_real_)
    x$value[which.min(abs(x$year - y))]
  }, prov, year)
}

#' 33州に畳む
#' @param kind "int"（人口加重平均）か "ext"（和）
collapse33 <- function(d, kind, weight_of = NULL) {
  dec <- if (kind == "ext") detect_parent_total(d) else NULL
  d <- d[d$prov_name != "INDONESIA" & !is.na(d$value), ]
  d$parent <- ifelse(d$prov_name %in% names(TO33), unname(TO33[d$prov_name]), d$prov_name)
  if (kind == "ext" && !is.null(dec) && nrow(dec)) {
    tot <- dec[dec$parent_is_total, ]
    d <- d[!(d$prov_name %in% names(TO33) & paste(d$parent, d$year) %in% paste(tot$parent, tot$year)), ]
  }
  d$w <- if (kind == "int") weight_of(d$prov_name, d$year) else 1
  if (kind == "int" && any(is.na(d$w))) stop("人口重みが無い州があります: ", paste(unique(d$prov_name[is.na(d$w)]), collapse = ", "))
  g <- split(d, list(d$parent, d$year), drop = TRUE)
  out <- do.call(rbind, lapply(g, function(x) data.frame(
    prov_name = x$parent[1], year = x$year[1],
    value = if (kind == "int") sum(x$value * x$w) / sum(x$w) else sum(x$value),
    n_parts = nrow(x),
    parent_only = x$value[x$prov_name == x$parent[1]][1])))
  rownames(out) <- NULL
  attr(out, "decisions") <- dec
  out[order(out$year, out$prov_name), ]
}

#' 子州が初めて現れた年の前後（int の確認用）
#' combined が prev に近ければ、親州の行は縮小後の州で、畳み方は正しい
jump_check <- function(p) {
  out <- list()
  for (pr in names(GROUPS)) {
    x <- p[p$prov_name == pr, ]; x <- x[order(x$year), ]
    k <- which(x$n_parts > 1)[1]
    if (is.na(k) || k == 1) next
    out[[length(out) + 1]] <- data.frame(parent = pr, first_year = x$year[k],
      prev = round(x$value[k - 1], 2), parent_only = round(x$parent_only[k], 2),
      combined = round(x$value[k], 2))
  }
  if (length(out)) do.call(rbind, out)
}

#' 33州から作った全国値と、BPS の全国値の差（年ごと、%）
national_check <- function(p, nat, kind, pop33) {
  m <- merge(p, pop33, by = c("prov_name", "year"))
  est <- sapply(split(m, m$year), function(x)
    if (kind == "int") sum(x$value * x$pop) / sum(x$pop) else sum(x$value))
  e <- data.frame(year = as.integer(names(est)), est = est)
  cmp <- merge(e, nat[, c("year", "value")], by = "year")
  cmp$diff_pct <- 100 * (cmp$est / cmp$value - 1)
  cmp
}
