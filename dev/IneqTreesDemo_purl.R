## flowchart LR
##   A[Prepare DRC child recode data] --> B[Fit a greedy CI tree]
##   B --> C[Print terminal-node summaries]
##   A --> D[Fit a greedy CI forest]
##   D --> E[Print forest summary]
##   A --> F[Cross-validation grids]
##   F --> G[Tune tree controls and CI criterion]
##   F --> H[Tune forest controls and CI criterion]
##   G --> I[Refit selected tree]
##   H --> J[Refit selected forest]
##   J --> K[Fit surrogate tree]
##   J --> L[SHAP decomposition of predicted risk]

knitr::opts_chunk$set(
  fig.width = 10,
  fig.height = 6,
  dpi = 500,
  dev = "svg"
)

library(data.table)
library(grid)
library(knitr)
library(ggplot2)
library(ineqTrees)


load(here::here("data", "drc_data.rda"))
drc_v8_dt <- as.data.table(drc_data)

congo_dt <- copy(drc_v8_dt)
congo_dt[, `:=`(
  b5_num = as.numeric(b5),
  b7_num = as.numeric(b7),
  v191_num = as.numeric(v191),
  v190_num = as.numeric(v190),
  v025_num = as.numeric(v025),
  v024_num = as.integer(v024),
  v133_num = as.numeric(v133),
  v012_num = as.numeric(v012),
  v701_num = as.numeric(v701),
  v717_num = as.numeric(v717),
  v705_num = as.numeric(v705),
  bord_num = as.numeric(bord),
  b11_num = as.numeric(b11),
  b4_num = as.numeric(b4),
  v005_num = as.numeric(v005)
)]

province_labels_v8 <- c(
  "1" = "Kinshasa", "2" = "Kwango", "3" = "Kwilu",
  "4" = "Mai-Ndombe", "5" = "Kongo Central", "6" = "Equateur",
  "7" = "Mongala", "8" = "Nord-Ubangi", "9" = "Sud-Ubangi",
  "10" = "Tshuapa", "11" = "Kasai", "12" = "Kasai Central",
  "13" = "Kasai Oriental", "14" = "Lomami", "15" = "Sankuru",
  "16" = "Haut-Katanga", "17" = "Haut-Lomami", "18" = "Lualaba",
  "19" = "Tanganyika", "20" = "Maniema", "21" = "Nord-Kivu",
  "22" = "Bas-Uele", "23" = "Haut-Uele", "24" = "Ituri",
  "25" = "Tshopo", "26" = "Sud-Kivu"
)

congo_dt[, `:=`(
  sample_weight = v005_num / 1000000,
  wealth = v191_num / 100000,
  quint = fcase(
    v190_num %in% c(1, 2), "b low",
    v190_num %in% c(3, 4, 5), "a high",
    default = NA_character_
  ),
  reg = province_labels_v8[as.character(v024_num)],
  rural = fcase(v025_num == 1, FALSE, v025_num == 2, TRUE, default = NA),
  ed = fcase(
    v133_num == 0, "b no education",
    !is.na(v133_num), "a education",
    default = NA_character_
  ),
  ped = fcase(
    v701_num == 0, "b no education",
    v701_num %in% c(1, 2, 3), "a education",
    default = NA_character_
  ),
  mocc = fcase(
    v717_num %in% c(0, 6, 9), "c Household, unskilled manual, not working",
    v717_num %in% c(4, 5, 10), "d Agriculture",
    v717_num %in% c(1, 2, 3, 7, 8, 96), "a other",
    v717_num == 97, "c Household, unskilled manual, not working",
    v717_num >= 98, NA_character_,
    default = NA_character_
  ),
  pocc = fcase(
    v705_num %in% c(0, 6, 9), "c Household, unskilled manual, not working",
    v705_num %in% c(4, 5, 10), "d Agriculture",
    v705_num %in% c(1, 2, 3, 7, 8, 96), "a other",
    v705_num == 97, "c Household, unskilled manual, not working",
    v705_num >= 98, NA_character_,
    default = NA_character_
  ),
  agemoth = fcase(
    v012_num < 20, "less than 20",
    v012_num >= 20, "a20 or more",
    default = NA_character_
  ),
  male = fcase(b4_num == 1, TRUE, b4_num == 2, FALSE, default = NA),
  birth = fcase(
    bord_num == 1, "a first",
    bord_num %in% 2:4 & !is.na(b11_num) & b11_num < 24, "b 2-4 short",
    bord_num %in% 2:4 & !is.na(b11_num) & b11_num >= 24, "c 2-4 long",
    bord_num > 4 & !is.na(b11_num) & b11_num < 24, "d 5+ short",
    bord_num > 4 & !is.na(b11_num) & b11_num >= 24, "e 5+ long",
    default = NA_character_
  ),
  deadu5_num = fcase(
    b5_num == 0 & !is.na(b7_num) & b7_num < 60, 1,
    b5_num == 1, 0,
    b5_num == 0 & !is.na(b7_num) & b7_num >= 60, 0,
    default = NA_real_
  ),
  unskilled = fcase(
    v717_num %in% c(0, 6, 9) | v705_num %in% c(0, 6, 9), TRUE,
    !is.na(v717_num) | !is.na(v705_num), FALSE,
    default = NA
  )
)]

congo_model_dt <- na.omit(congo_dt[, .(
  wealth, deadu5_num, quint, unskilled, male, birth, agemoth, rural,
  ed, ped, mocc, pocc, reg, sample_weight
)])

congo_model_dt[, `:=`(
  quint = factor(quint, levels = c("a high", "b low")),
  unskilled = factor(unskilled, levels = c(FALSE, TRUE), labels = c("No", "Yes")),
  male = factor(male, levels = c(FALSE, TRUE), labels = c("Female", "Male")),
  birth = factor(
    birth,
    levels = c("a first", "b 2-4 short", "c 2-4 long", "d 5+ short", "e 5+ long")
  ),
  agemoth = factor(agemoth, levels = c("a20 or more", "less than 20")),
  rural = factor(rural, levels = c(FALSE, TRUE), labels = c("Urban", "Rural")),
  ed = factor(ed, levels = c("a education", "b no education")),
  ped = factor(ped, levels = c("a education", "b no education")),
  mocc = factor(
    mocc,
    levels = c("a other", "c Household, unskilled manual, not working", "d Agriculture")
  ),
  pocc = factor(
    pocc,
    levels = c("a other", "c Household, unskilled manual, not working", "d Agriculture")
  ),
  reg = factor(reg, levels = unname(province_labels_v8))
)]

congo_model_dt <- congo_model_dt[sample_weight > 0]

congo_predictors <- c(
  "unskilled", "male", "birth", "agemoth", "rural",
  "ed", "ped", "mocc", "pocc", "reg"
)

congo_ci_formula <- stats::as.formula(
  paste("cbind(wealth, deadu5_num) ~", paste(congo_predictors, collapse = " + "))
)

congo_var_labels <- c(
  unskilled = "Low-skill HH",
  male = "Child sex",
  birth = "Birth group",
  agemoth = "Mother age",
  rural = "Residence",
  ed = "Mother education",
  ped = "Partner education",
  mocc = "Mother occupation",
  pocc = "Partner occupation",
  reg = "Province"
)

nrow(congo_model_dt)

weighted_mean_safe <- function(x, w) {
  keep <- stats::complete.cases(x, w) & w > 0
  if (!any(keep)) return(NA_real_)
  stats::weighted.mean(x[keep], w[keep])
}

forest_predict <- function(object, newdata) {
  as.numeric(stats::predict(object, newdata = as.data.frame(newdata), OOB = FALSE))
}

demo_tuning_table <- function(x, columns, labels) {
  out <- as.data.frame(x)
  missing_columns <- setdiff(columns, names(out))
  for (column in missing_columns) out[[column]] <- NA
  out <- out[, columns, drop = FALSE]
  names(out) <- labels
  out
}

demo_tree_plot <- function(fit, data, outcome_name, outcome_label = "Outcome", ci_type = "CI") {
  ci_fun <- ci_factory(ci_type)
  plot(
    fit,
    gp = grid::gpar(fontsize = 6.5),
    data = as.data.frame(data),
    var_labels = congo_var_labels,
    terminal_stats = list(
      weighted_n = function(df) sum(df$sample_weight, na.rm = TRUE),
      outcome = function(df) weighted_mean_safe(df[[outcome_name]], df$sample_weight),
      mean_wealth = function(df) weighted_mean_safe(df$wealth, df$sample_weight),
      ci = function(df) ci_fun(cbind(df$wealth, df[[outcome_name]]), df$sample_weight)
    ),
    stat_labels = list(
      weighted_n = "weighted n",
      outcome = outcome_label,
      mean_wealth = expression(mu ~ wealth),
      ci = "CI"
    ),
    stat_formatters = list(
      weighted_n = function(x) format(round(x), big.mark = ",", scientific = FALSE),
      outcome = function(x) sprintf("%.2f%%", 100 * x),
      mean_wealth = function(x) sprintf("%.2f", x),
      ci = function(x) sprintf("%.3f", x)
    ),
    terminal_fill = "#d9d9d9",
    tp_args = list(width_lines = 11, height_lines = 5.2),
    tnex = 0.85
  )
}

ci_tree_fit <- ctree_ci(
  formula = congo_ci_formula,
  data = congo_model_dt,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  weights = congo_model_dt$sample_weight,
  type = "CIg",
  control = ci_tree_control(
    minsplit = 150L,
    minbucket = 75L,
    minprob = 0.01,
    maxdepth = 4L,
    min_gain = 0
  )
)

ci_tree_fit

knitr::kable(
  ci_tree_terminal_summary(ci_tree_fit),
  digits = 3,
  caption = "Terminal-node summary for the fitted greedy CI tree"
)

demo_tree_plot(
  fit = ci_tree_fit,
  data = congo_model_dt,
  outcome_name = "deadu5_num",
  outcome_label = "U5 death",
  ci_type = "CIg"
)

ci_forest_fit <- cf_ci(
  formula = congo_ci_formula,
  data = congo_model_dt,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  weights = congo_model_dt$sample_weight,
  type = "CIg",
  control = ci_tree_control(
    minsplit = 150L,
    minbucket = 75L,
    minprob = 0.01,
    maxdepth = 5L
  ),
  ntree = 20L,
  mtry = 4L,
  perturb = list(replace = FALSE, fraction = 0.632)
)

ci_forest_fit

knitr::kable(
  ci_forest_summary(ci_forest_fit),
  digits = 3,
  caption = "Summary of the fitted greedy CI forest"
)

set.seed(20260507)
tuning_n <- min(800L, nrow(congo_model_dt))
tuning_rows <- sort(sample.int(nrow(congo_model_dt), tuning_n))
tuning_data <- congo_model_dt[tuning_rows]

nrow(tuning_data)

tree_grid <- ci_tree_control_grid(
    minsplit = c(50L, 100L, 200L),
    minbucket = c(100L, 200L, 400L),
    minprob = c(0.01, 0.03, 0.05, 0.2),
    maxdepth = c(2L, 3L, 5L),
    min_gain = 0
)


tree_tuning <- tune_ctree_ci(
  formula = congo_ci_formula,
  data = tuning_data,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  weights = tuning_data$sample_weight,
  type = c("CI", "CIg", "CIc"),
  control_grid = tree_grid,
  v = 5L,
  strata = "deadu5_num",
  seed = 20260507,
  metric = "validation_gain",
  refit = TRUE
)

tree_tuning$best_params

tree_tuning_table <- demo_tuning_table(
  tree_tuning$summary,
  columns = c(
    "type", "minsplit", "minbucket", "minprob", "maxdepth",
    "mean_score", "sd_score", "mean_terminal_nodes"
  ),
  labels = c(
    "type", "minsplit", "minbucket", "minprob", "maxdepth",
    "mean_validation_gain", "sd_validation_gain", "mean_terminal_nodes"
  )
)

knitr::kable(
  head(tree_tuning_table, 12L),
  digits = 3,
  caption = "Top cross-validated greedy CI tree settings"
)

best_tree <- ctree_ci(
  formula = congo_ci_formula,
  data = congo_model_dt,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  weights = congo_model_dt$sample_weight,
  type = tree_tuning$best_type,
  control = tree_tuning$best_control
)

best_tree

demo_tree_plot(
  fit = best_tree,
  data = congo_model_dt,
  outcome_name = "deadu5_num",
  outcome_label = "U5 death",
  ci_type = tree_tuning$best_type
)

forest_grid <- ci_tree_control_grid(
  minsplit = c(50L, 100L, 200L),
  minbucket = c(100L,200L, 400L),
  minprob = c(0.01, 0.03, 0.05, 0.2),
  maxdepth = c(2L, 3L, 5L),
  mtry = c(2L, 4L),
  ntree = c(5L, 10L, 50L, 100L),
  min_gain = 0
)

forest_tuning <- tune_cf_ci(
  formula = congo_ci_formula,
  data = tuning_data,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  weights = tuning_data$sample_weight,
  type = c("CI", "CIg", "CIc"),
  control_grid = forest_grid,
  v = 3L,
  strata = "deadu5_num",
  seed = 20260508,
  prediction_name = "forest_risk",
  refit = TRUE
)

forest_tuning$best_params

forest_tuning_table <- demo_tuning_table(
  forest_tuning$summary,
  columns = c(
    "type", "ntree", "mtry", "maxdepth", "mean_score", "sd_score",
    "mean_terminal_nodes"
  ),
  labels = c(
    "type", "ntree", "mtry", "maxdepth", "mean_validation_gain",
    "sd_validation_gain", "mean_terminal_nodes"
  )
)

knitr::kable(
  head(forest_tuning_table, 12L),
  digits = 3,
  caption = "Top cross-validated greedy CI forest settings"
)

best_forest_ntree <- as.integer(forest_tuning$best_params$ntree[1L])

best_forest <- cf_ci(
  formula = congo_ci_formula,
  data = congo_model_dt,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  weights = congo_model_dt$sample_weight,
  type = forest_tuning$best_type,
  control = forest_tuning$best_control,
  ntree = best_forest_ntree,
  perturb = list(replace = FALSE, fraction = 0.632)
)

best_forest

knitr::kable(
  ci_forest_summary(best_forest),
  digits = 3,
  caption = "Summary of the cross-validated greedy CI forest refit on full data"
)

forest_pred <- forest_predict(best_forest, congo_model_dt[, ..congo_predictors])
forest_surrogate_dt <- copy(congo_model_dt)
forest_surrogate_dt[, forest_risk := forest_pred]

forest_surrogate_formula <- stats::as.formula(
  paste("cbind(wealth, forest_risk) ~", paste(congo_predictors, collapse = " + "))
)

surrogate_control <- forest_tuning$best_control
surrogate_control$mtry <- NULL

forest_surrogate <- ctree_ci(
  formula = forest_surrogate_formula,
  data = forest_surrogate_dt,
  rank_name = "wealth",
  outcome_name = "forest_risk",
  weights = forest_surrogate_dt$sample_weight,
  type = forest_tuning$best_type,
  control = surrogate_control
)

forest_surrogate

knitr::kable(
  ci_tree_terminal_summary(forest_surrogate),
  digits = 3,
  caption = "Terminal-node summary for the forest surrogate tree"
)

demo_tree_plot(
  fit = forest_surrogate,
  data = forest_surrogate_dt,
  outcome_name = "forest_risk",
  outcome_label = "Predicted U5 death",
  ci_type = forest_tuning$best_type
)

if (!requireNamespace("fastshap", quietly = TRUE)) {
  knitr::asis_output("`fastshap` is not installed, so the SHAP decomposition is skipped.")
} else {
  set.seed(20260328)
  shap_eval_n <- min(250L, nrow(congo_model_dt))
  shap_rows <- sort(sample.int(nrow(congo_model_dt), shap_eval_n))

  forest_X <- as.data.frame(congo_model_dt[, ..congo_predictors])
  shap_X_eval <- forest_X[shap_rows, , drop = FALSE]
  forest_pred_eval <- forest_predict(best_forest, shap_X_eval)
  wealth_eval <- congo_model_dt$wealth[shap_rows]

  forest_shap <- fastshap::explain(
    object = best_forest,
    X = forest_X,
    pred_wrapper = forest_predict,
    newdata = shap_X_eval,
    nsim = 16,
    adjust = TRUE
  )

  shap_decomp <- shap_conc_decomp(
    shap = forest_shap,
    rank = wealth_eval,
    prediction = forest_pred_eval
  )

  shap_diagnostics <- as.data.frame(shap_decomp$diagnostics)
  shap_contributions <- as.data.frame(shap_decomp$contributions)
  shap_contributions <- shap_contributions[
    order(-shap_contributions$abs_contribution),
    ,
    drop = FALSE
  ]
}

if (exists("shap_diagnostics")) {
  knitr::kable(
    shap_diagnostics,
    digits = 4,
    caption = "Diagnostics for the SHAP concentration-index decomposition"
  )
}

if (exists("shap_contributions")) {
  knitr::kable(
    shap_contributions,
    digits = 4,
    caption = "Feature-level SHAP concentration-index decomposition"
  )
}

if (exists("shap_contributions")) {
  shap_plot_dt <- as.data.table(head(shap_contributions, 10L))
  shap_plot_dt[, feature := factor(feature, levels = rev(feature))]
  shap_plot_dt[, positive := pct_contribution >= 0]

  ggplot(shap_plot_dt, aes(x = feature, y = pct_contribution, fill = positive)) +
    geom_col(width = 0.7) +
    coord_flip() +
    geom_hline(yintercept = 0, linetype = 2, color = "gray40") +
    scale_fill_manual(
      values = c("TRUE" = "#3C8D2F", "FALSE" = "#B7472A"),
      guide = "none"
    ) +
    labs(
      x = NULL,
      y = "Percent contribution to the CI of predicted risk",
      title = "Top SHAP-Based CI Contributions"
    ) +
    theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank())
}
