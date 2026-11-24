# =====================================================================
# 01_check_api.R : API が使えるかを確かめる（2リクエスト、数秒）
# =====================================================================
source(file.path(Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", ".")), "00_setup.R"), encoding = "UTF-8")

cat("APIキー: あり（", nchar(BPS_KEY), "文字）\n", sep = "")
r <- get_json("domain/type/prov")
cat("州ドメインの一覧:", r$status, "—", if (identical(r$status, "OK")) nrow(r$data[[2]]) else unlist(r$message), "件\n")
r <- get_json("list/model/data/lang/eng/domain/0000/var/192/th/124")
cat("貧困率 2024:", r$status, "— 地域", if (identical(r$status, "OK")) nrow(r$vervar) else unlist(r$message), "\n")
cat("（州ドメインの一覧は分割前の34州のまま。値の側は38州＋全国。州の正本には使わない）\n")
