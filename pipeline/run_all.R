# =====================================================================
# run_all.R : 0 から全部作り直す（約15分）
# =====================================================================
#   source("pipeline/run_all.R")   # リポジトリの直下から（通常は get_data.R が呼ぶ）
#   source("pipeline/run_all.R")              # 可視化リポジトリから
# 途中で止まったら、そのスクリプトから単独で再開できる。
# =====================================================================
P <- Find(function(p) file.exists(file.path(p, "00_setup.R")), c("jscs40aniv/pipeline", "pipeline", "."))
for (f in c("01_check_api.R", "02_fetch_dynamic.R", "03_fetch_static.R",
            "04_build_population.R", "05_build_panel33.R")) {
  cat("\n##########", f, "##########\n")
  source(file.path(P, f), encoding = "UTF-8")
}
