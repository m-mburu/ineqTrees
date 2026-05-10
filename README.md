
# ineqTrees

<!-- badges: start -->

[![R-CMD-check](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

`ineqTrees` provides tools for studying socioeconomic inequality in
health outcomes with tree-based models. The package includes weighted
rank and concentration-index utilities, inequality-aware split scoring,
and wrappers for fitting greedy concentration-index trees and forests.

## Installation

You can install the development version of ineqTrees like so:

``` r
remotes::install_github("m-mburu/ineqTrees")
```

## Fitting a tree

The example below fits an inequality-aware greedy tree on a sample from
the built-in `kenya` dataset. The response combines the ranking variable
(`wealth`) and the health outcome (`deadu5_num`), while the split
criterion is based on concentration-index reduction.

### load data and set seed for reproducibility

``` r
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  suppressMessages(pkgload::load_all(export_all = FALSE))
} else {
  library(ineqTrees)
}
library(data.table)
load("data/kenya.rda")

set.seed(1)
```

### Fit tree

- This is a concentration-index tree, so the response is a two-column
  matrix of the ranking variable and the outcome. The `rank_name` and
  `outcome_name` arguments specify which columns of the data to use for
  those roles. The split criterion is based on concentration-index
  reduction, so the `control` argument specifies greedy controls rather
  than conditional-inference test controls.

``` r
fit_tree <- ci_tree(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  control = ci_tree_control(maxdepth = 4L)
)
```

``` r
fit_tree
```

### Greedy concentration-index tree

**Formula:** `cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled`
**Criterion:** CI **Tree size:** 15 inner nodes, 16 terminal nodes, max
depth 4

| node |    n | weight | depth |    ci | outcome_mean | outcome_percent |
|-----:|-----:|-------:|------:|------:|-------------:|----------------:|
|    5 | 1389 |   1389 |     4 | 0.115 |        0.011 |             1.1 |
|    6 |  761 |    761 |     4 | 0.187 |        0.033 |             3.3 |
|    8 |  116 |    116 |     4 | 0.000 |        0.000 |             0.0 |
|    9 |  450 |    450 |     4 | 0.155 |        0.049 |             4.9 |
|   12 | 1030 |   1030 |     4 | 0.167 |        0.033 |             3.3 |
|   13 |  553 |    553 |     4 | 0.160 |        0.065 |             6.5 |
|   15 |  314 |    314 |     4 | 0.114 |        0.070 |             7.0 |
|   16 |  153 |    153 |     4 | 0.211 |        0.163 |            16.3 |
|   20 | 4281 |   4281 |     4 | 0.279 |        0.043 |             4.3 |
|   21 | 5564 |   5564 |     4 | 0.170 |        0.075 |             7.5 |
|   23 | 1082 |   1082 |     4 | 0.068 |        0.079 |             7.9 |
|   24 | 1661 |   1661 |     4 | 0.105 |        0.138 |            13.8 |
|   27 |  420 |    420 |     4 | 0.080 |        0.093 |             9.3 |
|   28 | 1244 |   1244 |     4 | 0.100 |        0.132 |            13.2 |
|   30 |  568 |    568 |     4 | 0.207 |        0.153 |            15.3 |
|   31 |  457 |    457 |     4 | 0.117 |        0.199 |            19.9 |

Terminal-node summary

``` r
ci_tree_terminal_summary(fit_tree)
#>      node     n weight depth         ci outcome_mean outcome_percent
#>     <int> <int>  <num> <int>      <num>        <num>           <num>
#>  1:     5  1389   1389     4 0.11450528   0.01079914        1.079914
#>  2:     6   761    761     4 0.18736842   0.03285151        3.285151
#>  3:     8   116    116     4 0.00000000   0.00000000        0.000000
#>  4:     9   450    450     4 0.15549706   0.04888889        4.888889
#>  5:    12  1030   1030     4 0.16732407   0.03300971        3.300971
#>  6:    13   553    553     4 0.15962158   0.06509946        6.509946
#>  7:    15   314    314     4 0.11443509   0.07006369        7.006369
#>  8:    16   153    153     4 0.21052632   0.16339869       16.339869
#>  9:    20  4281   4281     4 0.27940894   0.04321420        4.321420
#> 10:    21  5564   5564     4 0.17041553   0.07494608        7.494608
#> 11:    23  1082   1082     4 0.06787428   0.07948244        7.948244
#> 12:    24  1661   1661     4 0.10506129   0.13786875       13.786875
#> 13:    27   420    420     4 0.08035004   0.09285714        9.285714
#> 14:    28  1244   1244     4 0.10034731   0.13183280       13.183280
#> 15:    30   568    568     4 0.20736281   0.15316901       15.316901
#> 16:    31   457    457     4 0.11702333   0.19912473       19.912473
```

``` r
readme_tree_plot(fit_tree, kenya, "deadu5_num")
```

<img src="man/figures/README-readme-tree-plot-1.png" width="100%" />

## Fitting a forest

The forest interface uses the same response specification, but averages
predictions across many greedy concentration-index trees. The tuned
workflow later in the README uses the same model family with
cross-validation.

``` r
fit_forest <- ci_forest(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  ntree = 10L,
  mtry = 1L,
  control = ci_tree_control(maxdepth = 5L)
)
fit_forest
```

### Greedy concentration-index forest

**Formula:** `cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled`
**Criterion:** CI **Trees:** 10

| ntree | mtry | type | n | mean_outcome | mean_prediction | outcome_ci | prediction_ci | mean_terminal_nodes | mean_max_depth |
|---:|---:|:---|---:|---:|---:|---:|---:|---:|---:|
| 10 | 1 | CI | 20043 | 0.074 | 0.074 | 0.312 | 0.108 | 6.8 | 3.5 |

Forest summary

``` r
ci_forest_summary(fit_forest)
#>    ntree  mtry   type     n mean_outcome mean_prediction outcome_ci
#>    <int> <int> <char> <int>        <num>           <num>      <num>
#> 1:    10     1     CI 20043   0.07369156       0.0736521  0.3115051
#>    prediction_ci mean_terminal_nodes mean_max_depth
#>            <num>               <num>          <num>
#> 1:     0.1079965                 6.8            3.5
```

### Fit surrogarete tree to forest predictions

- The surrogate is a greedy concentration-index tree that approximates
  the predictions of the fitted forest. This is useful for interpreting
  the forest and for tuning it with cross-validation, since the
  surrogate can be refit on held-out data and scored with CI gain.

``` r
setDT(kenya)
kenya[, forest_risk := readme_forest_predict(
   fit_forest, .SD
), .SDcols = readme_predictors]

surrogate_tree <- ci_tree(
  formula = cbind(wealth, forest_risk) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "forest_risk",
  control = ci_tree_control(maxdepth = 4L)
)
surrogate_tree
```

### Greedy concentration-index tree

**Formula:** `cbind(wealth, forest_risk) ~ rural + ed + reg + unskilled`
**Criterion:** CI **Tree size:** 15 inner nodes, 16 terminal nodes, max
depth 4

| node |    n | weight | depth |    ci | outcome_mean | outcome_percent |
|-----:|-----:|-------:|------:|------:|-------------:|----------------:|
|    5 | 2046 |   2046 |     4 | 0.001 |        0.037 |             3.7 |
|    6 |  781 |    781 |     4 | 0.004 |        0.041 |             4.1 |
|    8 |  693 |    693 |     4 | 0.007 |        0.051 |             5.1 |
|    9 |  213 |    213 |     4 | 0.007 |        0.065 |             6.5 |
|   12 |  416 |    416 |     4 | 0.001 |        0.053 |             5.3 |
|   13 |  320 |    320 |     4 | 0.006 |        0.065 |             6.5 |
|   15 |  136 |    136 |     4 | 0.014 |        0.078 |             7.8 |
|   16 |  161 |    161 |     4 | 0.009 |        0.091 |             9.1 |
|   20 | 1598 |   1598 |     4 | 0.008 |        0.065 |             6.5 |
|   21 | 7816 |   7816 |     4 | 0.006 |        0.070 |             7.0 |
|   23 |  967 |    967 |     4 | 0.002 |        0.085 |             8.5 |
|   24 | 1526 |   1526 |     4 | 0.001 |        0.100 |            10.0 |
|   27 | 1059 |   1059 |     4 | 0.005 |        0.093 |             9.3 |
|   28 | 1492 |   1492 |     4 | 0.009 |        0.106 |            10.6 |
|   30 |  384 |    384 |     4 | 0.007 |        0.125 |            12.5 |
|   31 |  435 |    435 |     4 | 0.009 |        0.142 |            14.2 |

Terminal-node summary

## plot

``` r
readme_tree_plot(
  surrogate_tree,
  kenya,
  outcome_name = "forest_risk",
  outcome_label = "Predicted risk"
)
```

<img src="man/figures/README-surrogate-tree-plot-1.png" width="100%" />

## SHAP-based decomposition

- Approximate SHAP values for the fitted forest with
  `fastshap::explain()`, using a prediction wrapper that returns the
  predicted outcome for each observation.
- Decompose the concentration index of those predicted risks with
  `shap_conc_decomp()`.

``` r
set.seed(20260328)
shap_eval_n <- min(400L, nrow(kenya))
shap_rows <- sort(sample.int(nrow(kenya), shap_eval_n))
forest_X <- kenya[, ..readme_predictors]
shap_X_eval <- forest_X[shap_rows, , drop = FALSE]
forest_pred_eval <- readme_forest_predict(fit_forest, shap_X_eval)
wealth_eval <- kenya$wealth[shap_rows]

forest_shap <- fastshap::explain(
  object = fit_forest,
  X = forest_X,
  pred_wrapper = readme_forest_predict,
  newdata = shap_X_eval,
  nsim = 64,
  adjust = TRUE
)

decomp <- shap_conc_decomp(
  shap = forest_shap,
  rank = wealth_eval,
  prediction = forest_pred_eval
)

shap_diagnostics <- as.data.frame(decomp$diagnostics)
shap_contrib_table <- as.data.frame(decomp$contributions)
shap_contrib_table <- shap_contrib_table[
  order(-shap_contrib_table$abs_contribution),
  ,
  drop = FALSE
]
```

``` r
knitr::kable(
  shap_diagnostics,
  digits = 3,
  caption = "SHAP decomposition diagnostics"
)
```

| n | mean_prediction | concentration_index | shap_sum | additivity_gap | centered_rank_sum | prediction_source |
|---:|---:|---:|---:|---:|---:|:---|
| 400 | 0.074 | -0.099 | -0.099 | 0 | 0 | prediction |

SHAP decomposition diagnostics

``` r
knitr::kable(
  shap_contrib_table,
  digits = 3,
  caption = "SHAP-based concentration-index contributions"
)
```

| feature   | D_k_SHAP | pct_contribution | abs_contribution |
|:----------|---------:|-----------------:|-----------------:|
| rural     |   -0.036 |           36.488 |            0.036 |
| reg       |   -0.033 |           32.850 |            0.033 |
| ed        |   -0.022 |           21.821 |            0.022 |
| unskilled |   -0.009 |            8.842 |            0.009 |

SHAP-based concentration-index contributions

``` r
library(ggplot2)
ggplot(
  shap_contrib_table,
  aes(
    x = stats::reorder(feature, pct_contribution),
    y = pct_contribution,
    fill = pct_contribution > 0
  )
) +
  geom_col(width = 0.7) +
  coord_flip() +
  scale_fill_manual(
    values = c("#2166ac", "#b2182b"),
    guide = "none"
  ) +
  labs(
    x = NULL,
    y = "Percentage contribution",
    title = "SHAP-based concentration-index decomposition"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())
```

<img src="man/figures/README-shap-decomposition-plot-1.png" width="100%" />

``` r
set.seed(20260507)
tuning_n <- min(800L, nrow(kenya))
tuning_rows <- sort(sample.int(nrow(kenya), tuning_n))
tuning_data <- kenya[tuning_rows, , drop = FALSE]
```

## Tune tree hyperparameters

The current model-selection workflow uses `ci_tree_control_grid()` to
define candidate greedy controls and `tune_ci_tree()` to score them with
cross-validation. The concentration-index variant is tuned alongside the
tree controls by passing several values to `type`.

``` r
tree_tune_grid <- ci_tree_control_grid(
  minsplit = c(150L, 250L),
  minbucket = c(60L, 100L),
  maxdepth = 2L:5L,
  minprob = c(0.01, 0.1, 0.2, 0.3)
)
```

``` r
tree_tuning <- tune_ci_tree(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = tuning_data,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  type = c("CI", "CIg", "CIc"),
  control_grid = tree_tune_grid,
  v = 10L,
  strata = "deadu5_num",
  seed = 20260507,
  metric = "validation_gain",
  refit = TRUE
)
```

``` r
tree_tuning_table <- readme_tuning_table(
  tree_tuning$summary,
  columns = c(
    "type",
    "minsplit",
    "minbucket",
    "maxdepth",
    "mean_score",
    "sd_score",
    "mean_terminal_nodes"
  ),
  labels = c(
    "type",
    "minsplit",
    "minbucket",
    "maxdepth",
    "mean_validation_gain",
    "sd_validation_gain",
    "mean_terminal_nodes"
  )
)

knitr::kable(
  tree_tuning_table,
  digits = 3,
  caption = "Cross-validated greedy tree tuning results"
)
```

| type | minsplit | minbucket | maxdepth | mean_validation_gain | sd_validation_gain | mean_terminal_nodes |
|:---|---:|---:|---:|---:|---:|---:|
| CI | 150 | 60 | 4 | 0.039 | 0.169 | 6.5 |
| CI | 150 | 60 | 4 | 0.039 | 0.169 | 6.5 |
| CI | 150 | 60 | 5 | 0.039 | 0.169 | 6.5 |
| CI | 150 | 60 | 5 | 0.039 | 0.169 | 6.5 |
| CI | 150 | 60 | 4 | 0.018 | 0.169 | 6.3 |
| CI | 150 | 60 | 5 | 0.018 | 0.169 | 6.3 |
| CI | 150 | 60 | 4 | 0.015 | 0.164 | 6.1 |
| CI | 150 | 60 | 5 | 0.015 | 0.164 | 6.1 |
| CI | 150 | 60 | 3 | 0.011 | 0.177 | 5.6 |
| CI | 150 | 60 | 3 | 0.011 | 0.177 | 5.6 |
| CIc | 250 | 60 | 3 | 0.002 | 0.036 | 4.5 |
| CIc | 250 | 60 | 3 | 0.002 | 0.036 | 4.5 |
| CIc | 250 | 60 | 4 | 0.002 | 0.033 | 4.9 |
| CIc | 250 | 60 | 4 | 0.002 | 0.033 | 4.9 |
| CIc | 250 | 60 | 5 | 0.002 | 0.033 | 4.9 |
| CIc | 250 | 60 | 5 | 0.002 | 0.033 | 4.9 |
| CIc | 250 | 60 | 4 | 0.001 | 0.031 | 4.8 |
| CIc | 250 | 60 | 5 | 0.001 | 0.031 | 4.8 |
| CIg | 250 | 60 | 3 | 0.001 | 0.009 | 4.5 |
| CIg | 250 | 60 | 3 | 0.001 | 0.009 | 4.5 |
| CIc | 250 | 60 | 3 | 0.001 | 0.031 | 4.5 |
| CIg | 250 | 60 | 4 | 0.001 | 0.008 | 4.9 |
| CIg | 250 | 60 | 5 | 0.001 | 0.008 | 4.9 |
| CIg | 250 | 60 | 5 | 0.001 | 0.008 | 4.9 |
| CIg | 250 | 60 | 4 | 0.000 | 0.008 | 4.9 |
| CI | 150 | 60 | 3 | 0.000 | 0.182 | 5.5 |
| CIg | 250 | 60 | 4 | 0.000 | 0.008 | 4.8 |
| CIg | 250 | 60 | 5 | 0.000 | 0.008 | 4.8 |
| CIg | 250 | 60 | 3 | 0.000 | 0.008 | 4.5 |
| CIg | 250 | 100 | 3 | 0.000 | 0.008 | 3.6 |
| CIg | 250 | 100 | 4 | 0.000 | 0.008 | 3.6 |
| CIg | 250 | 100 | 5 | 0.000 | 0.008 | 3.6 |
| CIg | 250 | 100 | 2 | 0.000 | 0.007 | 3.5 |
| CIg | 250 | 60 | 2 | 0.000 | 0.009 | 3.6 |
| CIg | 250 | 60 | 2 | 0.000 | 0.009 | 3.6 |
| CIg | 250 | 60 | 2 | 0.000 | 0.009 | 3.6 |
| CIc | 250 | 100 | 3 | -0.001 | 0.030 | 3.6 |
| CIc | 250 | 100 | 4 | -0.001 | 0.030 | 3.6 |
| CIc | 250 | 100 | 5 | -0.001 | 0.030 | 3.6 |
| CIg | 150 | 100 | 3 | -0.001 | 0.008 | 3.7 |
| CIg | 150 | 100 | 4 | -0.001 | 0.008 | 3.7 |
| CIg | 150 | 100 | 5 | -0.001 | 0.008 | 3.7 |
| CIg | 150 | 60 | 2 | -0.001 | 0.009 | 4.0 |
| CIg | 150 | 60 | 2 | -0.001 | 0.009 | 4.0 |
| CIg | 150 | 60 | 2 | -0.001 | 0.009 | 4.0 |
| CIg | 150 | 100 | 2 | -0.001 | 0.008 | 3.6 |
| CIg | 250 | 100 | 2 | -0.001 | 0.006 | 3.4 |
| CIg | 250 | 100 | 2 | -0.001 | 0.006 | 3.4 |
| CIg | 250 | 100 | 2 | -0.001 | 0.006 | 3.4 |
| CIg | 150 | 60 | 3 | -0.001 | 0.010 | 5.5 |
| CIg | 150 | 60 | 3 | -0.001 | 0.010 | 5.5 |
| CIg | 150 | 60 | 4 | -0.001 | 0.010 | 5.9 |
| CIc | 250 | 100 | 2 | -0.001 | 0.030 | 3.5 |
| CIg | 150 | 60 | 4 | -0.001 | 0.010 | 5.9 |
| CIg | 250 | 100 | 3 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 4 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 4 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 4 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 3 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 3 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 5 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 5 | -0.001 | 0.005 | 3.8 |
| CIg | 250 | 100 | 5 | -0.001 | 0.005 | 3.8 |
| CIg | 150 | 60 | 5 | -0.001 | 0.010 | 6.0 |
| CIg | 150 | 60 | 5 | -0.001 | 0.010 | 6.0 |
| CIg | 150 | 60 | 4 | -0.001 | 0.009 | 5.9 |
| CIg | 150 | 60 | 5 | -0.001 | 0.009 | 6.0 |
| CIg | 150 | 60 | 3 | -0.001 | 0.009 | 5.5 |
| CIg | 150 | 100 | 2 | -0.002 | 0.006 | 3.5 |
| CIg | 150 | 100 | 2 | -0.002 | 0.006 | 3.5 |
| CIg | 150 | 100 | 2 | -0.002 | 0.006 | 3.5 |
| CIc | 250 | 60 | 2 | -0.002 | 0.034 | 3.6 |
| CIc | 250 | 60 | 2 | -0.002 | 0.034 | 3.6 |
| CIc | 250 | 60 | 2 | -0.002 | 0.034 | 3.6 |
| CIg | 150 | 100 | 3 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 3 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 4 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 3 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 4 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 4 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 5 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 5 | -0.002 | 0.006 | 3.9 |
| CIg | 150 | 100 | 5 | -0.002 | 0.006 | 3.9 |
| CIg | 250 | 60 | 3 | -0.002 | 0.008 | 3.9 |
| CIg | 250 | 60 | 4 | -0.002 | 0.008 | 3.9 |
| CIg | 250 | 60 | 5 | -0.002 | 0.008 | 3.9 |
| CIg | 250 | 60 | 2 | -0.002 | 0.008 | 3.8 |
| CIg | 150 | 60 | 2 | -0.002 | 0.008 | 4.0 |
| CI | 150 | 60 | 3 | -0.003 | 0.175 | 5.5 |
| CIc | 150 | 100 | 3 | -0.003 | 0.031 | 3.7 |
| CIc | 150 | 100 | 4 | -0.003 | 0.031 | 3.7 |
| CIc | 150 | 100 | 5 | -0.003 | 0.031 | 3.7 |
| CIc | 150 | 60 | 2 | -0.004 | 0.038 | 4.0 |
| CIc | 150 | 60 | 2 | -0.004 | 0.038 | 4.0 |
| CIc | 150 | 60 | 2 | -0.004 | 0.038 | 4.0 |
| CIc | 150 | 100 | 2 | -0.004 | 0.031 | 3.6 |
| CIc | 250 | 100 | 2 | -0.004 | 0.024 | 3.4 |
| CIc | 250 | 100 | 2 | -0.004 | 0.024 | 3.4 |
| CIc | 250 | 100 | 2 | -0.004 | 0.024 | 3.4 |
| CIg | 150 | 60 | 3 | -0.004 | 0.011 | 5.6 |
| CIg | 150 | 60 | 4 | -0.004 | 0.011 | 5.6 |
| CIg | 150 | 60 | 5 | -0.004 | 0.011 | 5.6 |
| CIc | 150 | 60 | 3 | -0.004 | 0.041 | 5.5 |
| CIc | 150 | 60 | 3 | -0.004 | 0.041 | 5.5 |
| CIc | 150 | 60 | 4 | -0.005 | 0.039 | 5.9 |
| CIc | 150 | 60 | 4 | -0.005 | 0.039 | 5.9 |
| CIc | 250 | 100 | 3 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 3 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 4 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 5 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 5 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 3 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 4 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 4 | -0.005 | 0.021 | 3.8 |
| CIc | 250 | 100 | 5 | -0.005 | 0.021 | 3.8 |
| CIc | 150 | 60 | 5 | -0.005 | 0.039 | 6.0 |
| CIc | 150 | 60 | 5 | -0.005 | 0.039 | 6.0 |
| CIc | 150 | 60 | 4 | -0.005 | 0.037 | 5.9 |
| CIc | 150 | 60 | 5 | -0.006 | 0.037 | 6.0 |
| CIc | 150 | 60 | 3 | -0.006 | 0.036 | 5.5 |
| CIc | 150 | 100 | 2 | -0.006 | 0.025 | 3.5 |
| CIc | 150 | 100 | 2 | -0.006 | 0.025 | 3.5 |
| CIc | 150 | 100 | 2 | -0.006 | 0.025 | 3.5 |
| CIc | 150 | 100 | 3 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 4 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 4 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 4 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 5 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 3 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 3 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 5 | -0.007 | 0.023 | 3.9 |
| CIc | 150 | 100 | 5 | -0.007 | 0.023 | 3.9 |
| CIc | 250 | 60 | 3 | -0.007 | 0.034 | 3.9 |
| CIc | 250 | 60 | 4 | -0.007 | 0.034 | 3.9 |
| CIc | 250 | 60 | 5 | -0.007 | 0.034 | 3.9 |
| CIc | 250 | 60 | 2 | -0.008 | 0.034 | 3.8 |
| CIc | 150 | 60 | 2 | -0.009 | 0.033 | 4.0 |
| CI | 250 | 60 | 4 | -0.013 | 0.187 | 4.8 |
| CI | 250 | 60 | 4 | -0.013 | 0.187 | 4.8 |
| CI | 250 | 60 | 5 | -0.013 | 0.187 | 4.8 |
| CI | 250 | 60 | 5 | -0.013 | 0.187 | 4.8 |
| CIc | 150 | 60 | 3 | -0.016 | 0.045 | 5.6 |
| CIc | 150 | 60 | 4 | -0.016 | 0.045 | 5.6 |
| CIc | 150 | 60 | 5 | -0.016 | 0.045 | 5.6 |
| CI | 150 | 100 | 4 | -0.017 | 0.176 | 4.3 |
| CI | 150 | 100 | 4 | -0.017 | 0.176 | 4.3 |
| CI | 150 | 100 | 4 | -0.017 | 0.176 | 4.3 |
| CI | 150 | 100 | 5 | -0.017 | 0.176 | 4.3 |
| CI | 150 | 100 | 5 | -0.017 | 0.176 | 4.3 |
| CI | 150 | 100 | 5 | -0.017 | 0.176 | 4.3 |
| CI | 150 | 100 | 3 | -0.018 | 0.179 | 4.3 |
| CI | 250 | 100 | 3 | -0.018 | 0.179 | 4.3 |
| CI | 150 | 100 | 4 | -0.018 | 0.179 | 4.3 |
| CI | 250 | 100 | 4 | -0.018 | 0.179 | 4.3 |
| CI | 150 | 100 | 5 | -0.018 | 0.179 | 4.3 |
| CI | 250 | 100 | 5 | -0.018 | 0.179 | 4.3 |
| CI | 250 | 60 | 3 | -0.018 | 0.171 | 4.5 |
| CI | 250 | 60 | 4 | -0.018 | 0.171 | 4.5 |
| CI | 250 | 60 | 5 | -0.018 | 0.171 | 4.5 |
| CI | 250 | 60 | 3 | -0.023 | 0.179 | 4.7 |
| CI | 250 | 60 | 3 | -0.023 | 0.179 | 4.7 |
| CI | 150 | 100 | 3 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 3 | -0.028 | 0.170 | 4.2 |
| CI | 150 | 100 | 3 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 3 | -0.028 | 0.170 | 4.2 |
| CI | 150 | 100 | 3 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 3 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 4 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 4 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 4 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 5 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 5 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 100 | 5 | -0.028 | 0.170 | 4.2 |
| CI | 250 | 60 | 3 | -0.041 | 0.178 | 4.5 |
| CI | 250 | 60 | 4 | -0.041 | 0.178 | 4.5 |
| CI | 250 | 60 | 5 | -0.041 | 0.178 | 4.5 |
| CI | 150 | 100 | 2 | -0.044 | 0.154 | 3.6 |
| CI | 250 | 100 | 2 | -0.044 | 0.154 | 3.6 |
| CI | 150 | 100 | 2 | -0.044 | 0.154 | 3.6 |
| CI | 250 | 100 | 2 | -0.044 | 0.154 | 3.6 |
| CI | 150 | 100 | 2 | -0.044 | 0.154 | 3.6 |
| CI | 250 | 100 | 2 | -0.044 | 0.154 | 3.6 |
| CI | 150 | 100 | 2 | -0.055 | 0.152 | 3.7 |
| CI | 250 | 100 | 2 | -0.055 | 0.152 | 3.7 |
| CI | 250 | 60 | 2 | -0.062 | 0.156 | 3.7 |
| CI | 150 | 60 | 2 | -0.067 | 0.157 | 3.9 |
| CI | 250 | 60 | 2 | -0.072 | 0.169 | 3.6 |
| CI | 250 | 60 | 2 | -0.072 | 0.169 | 3.6 |
| CI | 150 | 60 | 2 | -0.077 | 0.171 | 3.8 |
| CI | 150 | 60 | 2 | -0.077 | 0.171 | 3.8 |
| CI | 250 | 60 | 2 | -0.078 | 0.166 | 3.6 |
| CI | 150 | 60 | 2 | -0.083 | 0.168 | 3.8 |

Cross-validated greedy tree tuning results

``` r
readme_tree_plot(
  fit = tree_tuning$best_fit,
  data = tuning_data,
  outcome_name = "deadu5_num"
)
```

<img src="man/figures/README-tree-tuning-plot-1.png" width="100%" />

## Tune forest hyperparameters

For forests, `tune_ci_forest()` uses the same greedy controls and adds
`ntree` when that column is present in the tuning grid. Each candidate
forest is summarized by a surrogate greedy CI tree, and the grid is
ranked by held-out CI validation gain from that surrogate.

``` r
forest_tune_grid <- ci_tree_control_grid(
  minsplit = c(100L, 200L),
  minbucket = c(50L, 100L, 200L),
  maxdepth = c(3L:6L),
  mtry = c(1L, 2L),
  ntree = c(10L, 50L, 100L)
)
```

``` r
forest_tuning <- tune_ci_forest(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = tuning_data,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  type = c("CI", "CIg", "CIc"),
  control_grid = forest_tune_grid,
  v = 10L,
  strata = "deadu5_num",
  seed = 20260508,
  prediction_name = "forest_risk",
  refit = TRUE
)
```

``` r
forest_tuning_table <- readme_tuning_table(
  forest_tuning$summary,
  columns = c(
    "type",
    "ntree",
    "mtry",
    "maxdepth",
    "mean_score",
    "sd_score",
    "mean_terminal_nodes"
  ),
  labels = c(
    "type",
    "ntree",
    "mtry",
    "maxdepth",
    "mean_validation_gain",
    "sd_validation_gain",
    "mean_terminal_nodes"
  )
)

knitr::kable(
  forest_tuning_table,
  digits = 3,
  caption = "Cross-validated greedy forest tuning results ranked by validation gain"
)
```

| type | ntree | mtry | maxdepth | mean_validation_gain | sd_validation_gain | mean_terminal_nodes |
|:---|---:|---:|---:|---:|---:|---:|
| CI | 10 | 2 | 6 | 0.072 | 0.141 | 3.9 |
| CI | 10 | 2 | 5 | 0.051 | 0.086 | 3.3 |
| CI | 50 | 1 | 6 | 0.050 | 0.185 | 5.8 |
| CI | 100 | 1 | 3 | 0.047 | 0.138 | 6.0 |
| CI | 10 | 2 | 6 | 0.045 | 0.168 | 5.2 |
| CI | 10 | 1 | 6 | 0.040 | 0.144 | 4.7 |
| CI | 10 | 2 | 5 | 0.040 | 0.097 | 1.9 |
| CI | 10 | 2 | 5 | 0.038 | 0.130 | 4.4 |
| CI | 100 | 1 | 5 | 0.037 | 0.206 | 6.4 |
| CI | 100 | 2 | 4 | 0.033 | 0.059 | 3.1 |
| CI | 10 | 1 | 6 | 0.029 | 0.168 | 6.5 |
| CI | 50 | 2 | 5 | 0.029 | 0.146 | 5.8 |
| CI | 10 | 1 | 4 | 0.029 | 0.152 | 5.8 |
| CI | 50 | 2 | 5 | 0.029 | 0.072 | 3.4 |
| CI | 50 | 1 | 6 | 0.027 | 0.141 | 3.8 |
| CI | 50 | 1 | 6 | 0.025 | 0.164 | 4.1 |
| CI | 100 | 1 | 3 | 0.022 | 0.073 | 3.8 |
| CI | 10 | 2 | 4 | 0.021 | 0.054 | 2.2 |
| CI | 50 | 2 | 3 | 0.021 | 0.070 | 3.4 |
| CI | 10 | 1 | 6 | 0.020 | 0.138 | 4.0 |
| CI | 50 | 2 | 5 | 0.019 | 0.111 | 3.1 |
| CI | 10 | 1 | 5 | 0.017 | 0.163 | 4.9 |
| CI | 100 | 1 | 3 | 0.016 | 0.108 | 3.9 |
| CI | 50 | 1 | 3 | 0.016 | 0.052 | 2.0 |
| CI | 50 | 2 | 4 | 0.016 | 0.125 | 4.8 |
| CI | 10 | 1 | 5 | 0.014 | 0.185 | 3.4 |
| CI | 100 | 1 | 6 | 0.014 | 0.118 | 3.8 |
| CI | 10 | 2 | 5 | 0.013 | 0.156 | 3.3 |
| CI | 100 | 1 | 4 | 0.013 | 0.091 | 6.0 |
| CI | 10 | 2 | 4 | 0.012 | 0.070 | 3.3 |
| CI | 100 | 2 | 5 | 0.012 | 0.103 | 5.1 |
| CI | 50 | 1 | 4 | 0.010 | 0.057 | 2.0 |
| CI | 50 | 2 | 4 | 0.009 | 0.133 | 3.4 |
| CI | 10 | 1 | 3 | 0.009 | 0.085 | 3.1 |
| CI | 100 | 2 | 3 | 0.008 | 0.074 | 3.1 |
| CI | 100 | 1 | 5 | 0.007 | 0.072 | 2.3 |
| CI | 10 | 2 | 4 | 0.007 | 0.090 | 2.4 |
| CI | 100 | 2 | 5 | 0.007 | 0.068 | 3.4 |
| CIc | 100 | 1 | 4 | 0.006 | 0.018 | 2.2 |
| CI | 50 | 2 | 5 | 0.005 | 0.079 | 2.3 |
| CIc | 100 | 2 | 6 | 0.005 | 0.017 | 2.0 |
| CI | 50 | 2 | 6 | 0.005 | 0.059 | 2.2 |
| CI | 100 | 1 | 5 | 0.005 | 0.043 | 2.1 |
| CIc | 50 | 2 | 6 | 0.005 | 0.019 | 2.2 |
| CIc | 100 | 2 | 3 | 0.005 | 0.014 | 2.1 |
| CIc | 100 | 1 | 5 | 0.003 | 0.012 | 2.0 |
| CIc | 100 | 1 | 5 | 0.003 | 0.016 | 2.2 |
| CI | 10 | 1 | 5 | 0.003 | 0.086 | 2.1 |
| CIc | 10 | 1 | 5 | 0.003 | 0.016 | 2.1 |
| CIc | 10 | 2 | 6 | 0.003 | 0.013 | 2.1 |
| CIc | 100 | 1 | 6 | 0.003 | 0.016 | 2.1 |
| CIc | 50 | 2 | 4 | 0.002 | 0.016 | 2.0 |
| CI | 10 | 1 | 3 | 0.002 | 0.138 | 3.5 |
| CIc | 10 | 2 | 4 | 0.002 | 0.014 | 2.0 |
| CIc | 100 | 2 | 5 | 0.002 | 0.015 | 2.4 |
| CI | 10 | 2 | 6 | 0.002 | 0.042 | 1.9 |
| CIg | 10 | 2 | 6 | 0.002 | 0.004 | 2.3 |
| CIg | 50 | 2 | 5 | 0.002 | 0.004 | 2.0 |
| CI | 50 | 1 | 5 | 0.001 | 0.106 | 3.5 |
| CIc | 100 | 1 | 3 | 0.001 | 0.012 | 2.2 |
| CIg | 10 | 1 | 4 | 0.001 | 0.003 | 2.3 |
| CIc | 50 | 1 | 6 | 0.001 | 0.017 | 2.2 |
| CIc | 50 | 2 | 5 | 0.001 | 0.017 | 2.1 |
| CIc | 100 | 2 | 4 | 0.001 | 0.013 | 2.0 |
| CIc | 50 | 2 | 3 | 0.001 | 0.016 | 2.0 |
| CIc | 50 | 2 | 6 | 0.001 | 0.012 | 2.2 |
| CIg | 100 | 2 | 6 | 0.001 | 0.004 | 2.1 |
| CIc | 10 | 2 | 3 | 0.001 | 0.027 | 2.3 |
| CIg | 50 | 1 | 5 | 0.001 | 0.004 | 2.4 |
| CI | 50 | 1 | 5 | 0.001 | 0.036 | 2.0 |
| CIg | 100 | 1 | 5 | 0.001 | 0.003 | 2.1 |
| CI | 50 | 1 | 3 | 0.001 | 0.178 | 5.1 |
| CI | 100 | 1 | 3 | 0.001 | 0.208 | 5.3 |
| CIg | 100 | 1 | 4 | 0.000 | 0.003 | 2.0 |
| CIg | 10 | 2 | 4 | 0.000 | 0.003 | 2.2 |
| CIc | 10 | 1 | 4 | 0.000 | 0.015 | 2.0 |
| CIg | 50 | 1 | 3 | 0.000 | 0.003 | 2.2 |
| CIg | 100 | 2 | 4 | 0.000 | 0.004 | 2.2 |
| CIg | 10 | 1 | 6 | 0.000 | 0.003 | 2.2 |
| CIg | 10 | 1 | 3 | 0.000 | 0.003 | 1.9 |
| CIg | 50 | 2 | 4 | 0.000 | 0.005 | 2.2 |
| CIg | 100 | 2 | 5 | 0.000 | 0.003 | 2.1 |
| CIg | 10 | 2 | 3 | 0.000 | 0.003 | 2.3 |
| CIg | 100 | 1 | 3 | 0.000 | 0.004 | 2.3 |
| CIc | 50 | 1 | 3 | 0.000 | 0.017 | 2.1 |
| CIc | 50 | 1 | 6 | 0.000 | 0.015 | 2.2 |
| CIg | 10 | 2 | 4 | 0.000 | 0.004 | 2.3 |
| CIg | 100 | 1 | 4 | 0.000 | 0.004 | 2.1 |
| CIg | 100 | 1 | 5 | 0.000 | 0.004 | 2.1 |
| CIg | 100 | 1 | 3 | 0.000 | 0.003 | 2.2 |
| CIg | 10 | 2 | 5 | 0.000 | 0.005 | 2.2 |
| CIc | 50 | 2 | 4 | 0.000 | 0.008 | 2.1 |
| CIg | 100 | 2 | 3 | 0.000 | 0.003 | 2.0 |
| CIg | 50 | 1 | 6 | 0.000 | 0.003 | 2.1 |
| CIg | 10 | 2 | 5 | 0.000 | 0.004 | 2.1 |
| CIg | 50 | 2 | 4 | 0.000 | 0.003 | 2.1 |
| CIg | 50 | 2 | 3 | 0.000 | 0.003 | 2.3 |
| CIc | 100 | 2 | 3 | 0.000 | 0.016 | 2.1 |
| CI | 100 | 1 | 5 | 0.000 | 0.147 | 3.9 |
| CIg | 100 | 2 | 5 | 0.000 | 0.003 | 2.0 |
| CIg | 10 | 1 | 5 | 0.000 | 0.003 | 2.1 |
| CIg | 50 | 2 | 3 | -0.001 | 0.005 | 2.2 |
| CI | 50 | 2 | 6 | -0.001 | 0.065 | 2.2 |
| CIg | 50 | 2 | 6 | -0.001 | 0.003 | 2.1 |
| CIc | 10 | 2 | 5 | -0.001 | 0.011 | 2.3 |
| CIg | 10 | 1 | 4 | -0.001 | 0.005 | 2.2 |
| CIc | 10 | 2 | 4 | -0.001 | 0.021 | 2.3 |
| CIg | 100 | 1 | 6 | -0.001 | 0.004 | 2.1 |
| CIg | 50 | 1 | 4 | -0.001 | 0.005 | 2.3 |
| CIg | 100 | 2 | 4 | -0.001 | 0.006 | 2.3 |
| CIg | 50 | 1 | 3 | -0.001 | 0.003 | 2.1 |
| CIg | 50 | 2 | 6 | -0.001 | 0.003 | 2.1 |
| CIg | 100 | 2 | 6 | -0.001 | 0.006 | 2.4 |
| CIc | 100 | 2 | 6 | -0.001 | 0.014 | 2.3 |
| CI | 10 | 1 | 5 | -0.001 | 0.122 | 6.0 |
| CIc | 10 | 1 | 3 | -0.001 | 0.026 | 2.1 |
| CIg | 100 | 2 | 3 | -0.001 | 0.005 | 2.2 |
| CIg | 10 | 1 | 6 | -0.001 | 0.002 | 2.2 |
| CIg | 50 | 1 | 6 | -0.001 | 0.002 | 2.2 |
| CIc | 10 | 1 | 6 | -0.001 | 0.014 | 2.0 |
| CI | 100 | 2 | 4 | -0.001 | 0.059 | 3.0 |
| CIc | 10 | 1 | 4 | -0.001 | 0.012 | 2.0 |
| CIg | 10 | 1 | 3 | -0.001 | 0.003 | 1.9 |
| CIg | 10 | 2 | 3 | -0.001 | 0.003 | 2.4 |
| CIc | 100 | 1 | 4 | -0.001 | 0.015 | 2.1 |
| CIc | 50 | 2 | 5 | -0.002 | 0.023 | 2.2 |
| CIc | 100 | 1 | 3 | -0.002 | 0.013 | 2.2 |
| CIg | 50 | 2 | 5 | -0.002 | 0.004 | 2.1 |
| CIc | 10 | 2 | 5 | -0.002 | 0.016 | 2.2 |
| CIg | 10 | 2 | 6 | -0.002 | 0.004 | 2.4 |
| CIc | 10 | 2 | 3 | -0.002 | 0.015 | 2.1 |
| CI | 10 | 1 | 3 | -0.002 | 0.091 | 2.1 |
| CIc | 50 | 2 | 3 | -0.002 | 0.016 | 2.2 |
| CIc | 50 | 1 | 3 | -0.002 | 0.015 | 2.3 |
| CIg | 10 | 1 | 5 | -0.002 | 0.007 | 2.4 |
| CIg | 50 | 1 | 5 | -0.002 | 0.005 | 2.1 |
| CIc | 100 | 1 | 6 | -0.002 | 0.011 | 2.1 |
| CIg | 10 | 1 | 5 | -0.002 | 0.009 | 4.9 |
| CIg | 10 | 1 | 4 | -0.002 | 0.009 | 4.5 |
| CIg | 100 | 1 | 6 | -0.003 | 0.004 | 2.4 |
| CIg | 50 | 1 | 4 | -0.003 | 0.005 | 2.4 |
| CI | 100 | 1 | 4 | -0.003 | 0.039 | 2.1 |
| CIg | 10 | 1 | 3 | -0.004 | 0.009 | 4.5 |
| CI | 50 | 1 | 4 | -0.004 | 0.167 | 5.6 |
| CIg | 10 | 2 | 6 | -0.004 | 0.007 | 4.3 |
| CIc | 50 | 1 | 4 | -0.004 | 0.019 | 2.2 |
| CI | 10 | 1 | 3 | -0.004 | 0.166 | 5.9 |
| CIc | 50 | 1 | 4 | -0.005 | 0.018 | 2.1 |
| CIg | 50 | 1 | 4 | -0.005 | 0.009 | 4.5 |
| CIg | 10 | 2 | 3 | -0.005 | 0.009 | 4.4 |
| CIg | 10 | 2 | 6 | -0.005 | 0.008 | 4.2 |
| CIc | 10 | 1 | 5 | -0.005 | 0.024 | 1.9 |
| CIg | 10 | 1 | 3 | -0.005 | 0.009 | 4.5 |
| CIc | 50 | 1 | 5 | -0.005 | 0.011 | 2.1 |
| CI | 100 | 2 | 6 | -0.005 | 0.062 | 2.0 |
| CIc | 100 | 2 | 5 | -0.005 | 0.010 | 2.1 |
| CIc | 10 | 1 | 6 | -0.005 | 0.014 | 2.2 |
| CIc | 100 | 2 | 4 | -0.005 | 0.021 | 2.2 |
| CIg | 50 | 2 | 3 | -0.005 | 0.007 | 4.3 |
| CIg | 10 | 2 | 3 | -0.006 | 0.007 | 4.5 |
| CIg | 50 | 2 | 5 | -0.006 | 0.008 | 4.7 |
| CIg | 10 | 2 | 3 | -0.006 | 0.009 | 4.7 |
| CIg | 50 | 2 | 3 | -0.006 | 0.007 | 4.3 |
| CIc | 10 | 2 | 6 | -0.006 | 0.015 | 2.1 |
| CIg | 50 | 1 | 3 | -0.006 | 0.009 | 4.8 |
| CIg | 10 | 2 | 4 | -0.006 | 0.008 | 4.1 |
| CIg | 50 | 1 | 6 | -0.006 | 0.008 | 4.8 |
| CIg | 10 | 1 | 3 | -0.006 | 0.008 | 6.2 |
| CIg | 50 | 2 | 4 | -0.006 | 0.008 | 4.3 |
| CIc | 50 | 1 | 5 | -0.006 | 0.019 | 2.3 |
| CIg | 10 | 2 | 5 | -0.006 | 0.011 | 4.5 |
| CIg | 10 | 2 | 3 | -0.006 | 0.007 | 6.0 |
| CIg | 100 | 1 | 4 | -0.006 | 0.006 | 4.6 |
| CIg | 100 | 1 | 6 | -0.006 | 0.008 | 6.1 |
| CIg | 100 | 1 | 5 | -0.006 | 0.009 | 4.6 |
| CI | 10 | 1 | 4 | -0.006 | 0.091 | 2.1 |
| CIg | 100 | 2 | 5 | -0.006 | 0.008 | 4.6 |
| CIg | 10 | 1 | 6 | -0.006 | 0.010 | 6.3 |
| CI | 50 | 2 | 4 | -0.006 | 0.075 | 3.2 |
| CI | 10 | 2 | 6 | -0.006 | 0.138 | 4.9 |
| CIg | 10 | 1 | 6 | -0.006 | 0.009 | 4.3 |
| CIg | 10 | 1 | 6 | -0.007 | 0.010 | 4.1 |
| CIg | 100 | 1 | 3 | -0.007 | 0.006 | 4.3 |
| CIg | 50 | 1 | 5 | -0.007 | 0.009 | 6.2 |
| CIg | 100 | 1 | 5 | -0.007 | 0.007 | 4.8 |
| CIg | 100 | 1 | 6 | -0.007 | 0.008 | 4.6 |
| CIg | 10 | 2 | 4 | -0.007 | 0.007 | 4.4 |
| CI | 100 | 2 | 5 | -0.007 | 0.093 | 3.0 |
| CIg | 100 | 2 | 6 | -0.007 | 0.006 | 4.3 |
| CIg | 10 | 1 | 5 | -0.007 | 0.006 | 5.7 |
| CIg | 100 | 1 | 3 | -0.007 | 0.006 | 5.0 |
| CIg | 10 | 2 | 5 | -0.007 | 0.009 | 5.7 |
| CIg | 50 | 1 | 4 | -0.007 | 0.008 | 4.4 |
| CIg | 100 | 1 | 6 | -0.007 | 0.011 | 4.6 |
| CIg | 100 | 2 | 4 | -0.007 | 0.008 | 4.3 |
| CIg | 10 | 2 | 4 | -0.007 | 0.007 | 7.1 |
| CIg | 50 | 1 | 5 | -0.007 | 0.010 | 4.7 |
| CIg | 50 | 1 | 5 | -0.007 | 0.007 | 4.9 |
| CIg | 100 | 2 | 3 | -0.007 | 0.008 | 4.2 |
| CIg | 10 | 1 | 4 | -0.007 | 0.007 | 4.6 |
| CIg | 50 | 1 | 3 | -0.008 | 0.008 | 4.6 |
| CIg | 10 | 2 | 4 | -0.008 | 0.007 | 5.5 |
| CIg | 10 | 1 | 6 | -0.008 | 0.012 | 7.8 |
| CIg | 50 | 2 | 4 | -0.008 | 0.006 | 4.5 |
| CIg | 50 | 2 | 4 | -0.008 | 0.007 | 5.8 |
| CIg | 100 | 1 | 4 | -0.008 | 0.009 | 4.3 |
| CIg | 100 | 2 | 6 | -0.008 | 0.006 | 4.6 |
| CIg | 10 | 2 | 6 | -0.008 | 0.006 | 5.6 |
| CIg | 50 | 1 | 6 | -0.008 | 0.007 | 5.8 |
| CIg | 10 | 2 | 5 | -0.008 | 0.010 | 7.4 |
| CIg | 10 | 1 | 5 | -0.008 | 0.011 | 7.2 |
| CIg | 100 | 2 | 6 | -0.008 | 0.009 | 6.1 |
| CI | 10 | 2 | 3 | -0.008 | 0.045 | 4.6 |
| CIg | 100 | 1 | 3 | -0.008 | 0.010 | 4.6 |
| CIg | 100 | 2 | 4 | -0.008 | 0.010 | 4.3 |
| CIg | 50 | 1 | 3 | -0.008 | 0.006 | 6.0 |
| CIg | 10 | 1 | 5 | -0.008 | 0.009 | 4.4 |
| CIg | 50 | 2 | 6 | -0.008 | 0.011 | 4.9 |
| CIg | 50 | 2 | 6 | -0.008 | 0.007 | 4.6 |
| CIg | 100 | 2 | 5 | -0.008 | 0.014 | 7.6 |
| CIg | 50 | 2 | 3 | -0.008 | 0.007 | 5.0 |
| CIg | 100 | 2 | 3 | -0.008 | 0.008 | 4.9 |
| CIc | 10 | 1 | 3 | -0.008 | 0.024 | 3.9 |
| CIg | 50 | 2 | 5 | -0.008 | 0.007 | 4.5 |
| CI | 100 | 1 | 6 | -0.008 | 0.179 | 5.8 |
| CIg | 100 | 2 | 4 | -0.008 | 0.008 | 5.7 |
| CIg | 50 | 1 | 6 | -0.008 | 0.005 | 5.1 |
| CIg | 100 | 1 | 4 | -0.008 | 0.006 | 5.7 |
| CIg | 50 | 2 | 6 | -0.008 | 0.010 | 7.7 |
| CIg | 50 | 2 | 5 | -0.008 | 0.012 | 6.0 |
| CI | 50 | 2 | 6 | -0.008 | 0.108 | 3.0 |
| CIg | 10 | 2 | 5 | -0.008 | 0.009 | 4.6 |
| CIg | 10 | 1 | 4 | -0.009 | 0.008 | 5.7 |
| CIg | 10 | 1 | 3 | -0.009 | 0.008 | 4.8 |
| CIg | 50 | 1 | 5 | -0.009 | 0.009 | 7.1 |
| CIg | 100 | 1 | 5 | -0.009 | 0.008 | 6.2 |
| CIg | 50 | 1 | 4 | -0.009 | 0.007 | 5.8 |
| CIg | 50 | 1 | 6 | -0.009 | 0.008 | 7.6 |
| CIc | 10 | 1 | 3 | -0.009 | 0.016 | 2.1 |
| CI | 50 | 2 | 6 | -0.009 | 0.113 | 3.2 |
| CIg | 100 | 2 | 5 | -0.009 | 0.010 | 4.6 |
| CIg | 100 | 2 | 3 | -0.009 | 0.009 | 4.4 |
| CIg | 100 | 2 | 3 | -0.010 | 0.006 | 6.1 |
| CIg | 10 | 1 | 4 | -0.010 | 0.006 | 7.2 |
| CIg | 100 | 1 | 3 | -0.010 | 0.006 | 6.2 |
| CI | 100 | 1 | 5 | -0.010 | 0.196 | 5.0 |
| CIg | 50 | 1 | 4 | -0.010 | 0.011 | 7.4 |
| CIg | 50 | 2 | 4 | -0.010 | 0.007 | 6.5 |
| CIg | 50 | 2 | 6 | -0.010 | 0.008 | 5.9 |
| CIg | 100 | 2 | 5 | -0.011 | 0.008 | 5.9 |
| CIg | 10 | 2 | 6 | -0.011 | 0.008 | 7.2 |
| CIg | 50 | 1 | 3 | -0.011 | 0.010 | 4.7 |
| CI | 50 | 2 | 4 | -0.011 | 0.053 | 2.0 |
| CIg | 50 | 2 | 5 | -0.011 | 0.009 | 7.4 |
| CIg | 100 | 1 | 5 | -0.011 | 0.009 | 7.5 |
| CI | 10 | 2 | 3 | -0.011 | 0.049 | 2.2 |
| CI | 100 | 1 | 3 | -0.011 | 0.081 | 2.2 |
| CI | 100 | 2 | 3 | -0.012 | 0.067 | 3.5 |
| CI | 50 | 2 | 6 | -0.012 | 0.154 | 4.3 |
| CIg | 50 | 2 | 3 | -0.012 | 0.011 | 6.1 |
| CIg | 100 | 2 | 6 | -0.013 | 0.014 | 7.7 |
| CI | 100 | 2 | 3 | -0.013 | 0.075 | 2.1 |
| CIg | 100 | 2 | 4 | -0.013 | 0.008 | 7.2 |
| CIc | 10 | 1 | 4 | -0.013 | 0.025 | 3.7 |
| CI | 100 | 2 | 4 | -0.013 | 0.063 | 2.1 |
| CIc | 10 | 1 | 5 | -0.014 | 0.033 | 5.9 |
| CIg | 100 | 1 | 4 | -0.014 | 0.010 | 6.9 |
| CIg | 100 | 1 | 6 | -0.014 | 0.011 | 7.5 |
| CIc | 50 | 1 | 3 | -0.015 | 0.043 | 4.0 |
| CIc | 10 | 1 | 5 | -0.015 | 0.035 | 3.6 |
| CI | 100 | 2 | 3 | -0.015 | 0.144 | 4.6 |
| CI | 100 | 2 | 5 | -0.016 | 0.040 | 2.0 |
| CIc | 10 | 1 | 3 | -0.016 | 0.042 | 4.6 |
| CIc | 100 | 2 | 6 | -0.016 | 0.038 | 3.8 |
| CIc | 10 | 1 | 3 | -0.017 | 0.032 | 3.8 |
| CI | 10 | 1 | 4 | -0.017 | 0.133 | 3.9 |
| CI | 10 | 1 | 6 | -0.017 | 0.094 | 3.9 |
| CIc | 10 | 2 | 3 | -0.017 | 0.031 | 3.8 |
| CI | 50 | 1 | 5 | -0.018 | 0.162 | 4.1 |
| CI | 100 | 2 | 6 | -0.018 | 0.107 | 3.0 |
| CI | 10 | 1 | 5 | -0.018 | 0.093 | 3.4 |
| CI | 50 | 2 | 5 | -0.018 | 0.034 | 2.1 |
| CIc | 50 | 1 | 5 | -0.018 | 0.037 | 3.8 |
| CI | 100 | 1 | 4 | -0.018 | 0.110 | 6.2 |
| CIc | 50 | 1 | 4 | -0.019 | 0.033 | 3.7 |
| CIc | 100 | 1 | 3 | -0.019 | 0.035 | 4.0 |
| CI | 10 | 1 | 6 | -0.019 | 0.064 | 2.0 |
| CI | 10 | 2 | 6 | -0.019 | 0.041 | 2.2 |
| CIc | 50 | 1 | 5 | -0.019 | 0.027 | 3.4 |
| CI | 50 | 2 | 3 | -0.019 | 0.071 | 5.1 |
| CI | 50 | 1 | 6 | -0.019 | 0.064 | 2.0 |
| CIc | 50 | 2 | 6 | -0.020 | 0.032 | 4.1 |
| CIc | 10 | 1 | 5 | -0.020 | 0.041 | 3.8 |
| CI | 100 | 1 | 6 | -0.020 | 0.149 | 3.5 |
| CIc | 100 | 2 | 5 | -0.020 | 0.036 | 3.9 |
| CIc | 100 | 1 | 6 | -0.020 | 0.026 | 3.7 |
| CI | 100 | 1 | 6 | -0.020 | 0.048 | 2.1 |
| CIc | 100 | 1 | 4 | -0.021 | 0.040 | 3.8 |
| CIc | 50 | 1 | 4 | -0.021 | 0.028 | 3.6 |
| CIc | 10 | 2 | 4 | -0.021 | 0.037 | 4.0 |
| CI | 10 | 1 | 4 | -0.021 | 0.121 | 4.7 |
| CIc | 100 | 1 | 3 | -0.022 | 0.032 | 4.7 |
| CIc | 10 | 2 | 6 | -0.022 | 0.040 | 3.7 |
| CI | 100 | 1 | 3 | -0.023 | 0.054 | 2.1 |
| CI | 50 | 2 | 3 | -0.023 | 0.135 | 3.1 |
| CIc | 100 | 1 | 4 | -0.023 | 0.035 | 3.8 |
| CIc | 10 | 2 | 6 | -0.023 | 0.035 | 5.5 |
| CIc | 50 | 2 | 6 | -0.023 | 0.031 | 3.8 |
| CI | 100 | 2 | 5 | -0.023 | 0.051 | 2.0 |
| CIc | 10 | 2 | 5 | -0.023 | 0.041 | 5.5 |
| CIc | 100 | 2 | 4 | -0.023 | 0.030 | 5.6 |
| CIc | 10 | 2 | 3 | -0.024 | 0.033 | 3.9 |
| CIc | 50 | 1 | 3 | -0.024 | 0.038 | 4.0 |
| CIc | 10 | 2 | 5 | -0.024 | 0.025 | 4.1 |
| CI | 10 | 2 | 3 | -0.024 | 0.110 | 3.2 |
| CIc | 100 | 2 | 3 | -0.024 | 0.039 | 3.8 |
| CIc | 50 | 2 | 3 | -0.024 | 0.038 | 3.9 |
| CIc | 10 | 1 | 6 | -0.024 | 0.035 | 4.3 |
| CIc | 50 | 2 | 4 | -0.025 | 0.032 | 3.7 |
| CIc | 100 | 1 | 4 | -0.025 | 0.036 | 5.7 |
| CI | 50 | 1 | 4 | -0.025 | 0.177 | 5.2 |
| CIc | 10 | 2 | 6 | -0.025 | 0.034 | 4.1 |
| CI | 10 | 1 | 3 | -0.025 | 0.080 | 4.4 |
| CI | 50 | 1 | 3 | -0.025 | 0.125 | 5.6 |
| CIc | 100 | 1 | 5 | -0.025 | 0.029 | 3.7 |
| CIc | 100 | 1 | 6 | -0.025 | 0.029 | 3.8 |
| CIc | 50 | 1 | 6 | -0.026 | 0.023 | 4.3 |
| CI | 50 | 1 | 6 | -0.026 | 0.197 | 5.0 |
| CIc | 100 | 2 | 5 | -0.026 | 0.034 | 3.4 |
| CIc | 50 | 2 | 3 | -0.026 | 0.034 | 5.7 |
| CIc | 50 | 2 | 4 | -0.026 | 0.034 | 3.9 |
| CIc | 10 | 1 | 4 | -0.027 | 0.036 | 4.1 |
| CI | 10 | 2 | 5 | -0.027 | 0.184 | 6.0 |
| CIc | 10 | 1 | 4 | -0.027 | 0.030 | 6.3 |
| CIc | 10 | 2 | 4 | -0.027 | 0.025 | 3.8 |
| CIc | 100 | 2 | 4 | -0.027 | 0.030 | 4.2 |
| CIc | 50 | 1 | 6 | -0.028 | 0.036 | 3.7 |
| CIc | 50 | 2 | 5 | -0.028 | 0.033 | 3.9 |
| CIc | 10 | 2 | 3 | -0.028 | 0.035 | 5.3 |
| CIc | 50 | 2 | 3 | -0.028 | 0.034 | 4.5 |
| CIc | 100 | 1 | 6 | -0.028 | 0.034 | 6.7 |
| CIc | 100 | 1 | 3 | -0.029 | 0.028 | 3.8 |
| CI | 100 | 1 | 4 | -0.029 | 0.142 | 3.5 |
| CI | 100 | 1 | 5 | -0.029 | 0.164 | 4.0 |
| CIc | 100 | 2 | 6 | -0.029 | 0.034 | 3.7 |
| CI | 50 | 2 | 3 | -0.029 | 0.055 | 2.2 |
| CI | 10 | 2 | 5 | -0.029 | 0.061 | 2.1 |
| CIc | 100 | 2 | 3 | -0.029 | 0.035 | 4.9 |
| CIc | 50 | 2 | 5 | -0.029 | 0.027 | 3.8 |
| CIc | 10 | 2 | 3 | -0.029 | 0.028 | 4.9 |
| CIc | 100 | 2 | 3 | -0.029 | 0.029 | 3.5 |
| CIc | 10 | 1 | 6 | -0.029 | 0.028 | 3.6 |
| CI | 10 | 1 | 5 | -0.029 | 0.109 | 2.0 |
| CI | 50 | 2 | 6 | -0.030 | 0.101 | 4.7 |
| CIc | 50 | 2 | 3 | -0.030 | 0.034 | 4.1 |
| CIc | 10 | 1 | 3 | -0.030 | 0.029 | 5.7 |
| CI | 100 | 1 | 6 | -0.030 | 0.049 | 2.1 |
| CI | 100 | 1 | 4 | -0.030 | 0.071 | 2.1 |
| CI | 10 | 1 | 6 | -0.030 | 0.134 | 2.3 |
| CIc | 100 | 1 | 6 | -0.031 | 0.037 | 6.0 |
| CIc | 50 | 1 | 3 | -0.031 | 0.029 | 4.8 |
| CIc | 100 | 1 | 5 | -0.031 | 0.035 | 3.8 |
| CIc | 100 | 1 | 5 | -0.031 | 0.034 | 5.9 |
| CI | 50 | 1 | 4 | -0.031 | 0.045 | 2.3 |
| CIc | 100 | 2 | 6 | -0.031 | 0.032 | 5.6 |
| CI | 100 | 2 | 6 | -0.032 | 0.111 | 4.6 |
| CIc | 100 | 2 | 5 | -0.032 | 0.028 | 5.9 |
| CIc | 100 | 2 | 4 | -0.032 | 0.030 | 3.8 |
| CIc | 50 | 1 | 5 | -0.033 | 0.027 | 6.0 |
| CIc | 50 | 1 | 6 | -0.033 | 0.025 | 6.2 |
| CIc | 10 | 2 | 4 | -0.033 | 0.024 | 5.6 |
| CIc | 50 | 2 | 5 | -0.033 | 0.026 | 5.9 |
| CIc | 10 | 1 | 4 | -0.034 | 0.041 | 5.6 |
| CIc | 50 | 2 | 6 | -0.034 | 0.036 | 5.8 |
| CI | 100 | 2 | 4 | -0.035 | 0.079 | 2.2 |
| CIc | 10 | 2 | 5 | -0.035 | 0.036 | 4.3 |
| CIc | 50 | 1 | 4 | -0.035 | 0.045 | 5.7 |
| CIc | 50 | 1 | 4 | -0.035 | 0.035 | 6.4 |
| CI | 50 | 2 | 4 | -0.035 | 0.121 | 4.5 |
| CI | 10 | 2 | 3 | -0.036 | 0.176 | 3.7 |
| CI | 100 | 2 | 6 | -0.036 | 0.165 | 5.3 |
| CI | 100 | 2 | 4 | -0.037 | 0.120 | 4.8 |
| CIc | 10 | 1 | 6 | -0.037 | 0.050 | 5.9 |
| CI | 50 | 1 | 5 | -0.038 | 0.120 | 6.0 |
| CIc | 50 | 2 | 4 | -0.038 | 0.034 | 5.9 |
| CIc | 50 | 2 | 4 | -0.038 | 0.030 | 5.3 |
| CIc | 100 | 1 | 5 | -0.038 | 0.046 | 6.7 |
| CI | 10 | 1 | 3 | -0.038 | 0.076 | 2.0 |
| CIc | 50 | 1 | 5 | -0.039 | 0.038 | 7.3 |
| CIc | 10 | 2 | 4 | -0.039 | 0.026 | 5.9 |
| CI | 10 | 2 | 6 | -0.039 | 0.184 | 3.2 |
| CIc | 50 | 1 | 3 | -0.039 | 0.037 | 5.6 |
| CI | 100 | 1 | 4 | -0.039 | 0.142 | 4.0 |
| CI | 50 | 2 | 4 | -0.039 | 0.074 | 2.0 |
| CI | 100 | 2 | 6 | -0.040 | 0.069 | 3.1 |
| CI | 50 | 2 | 3 | -0.040 | 0.066 | 2.1 |
| CI | 100 | 2 | 3 | -0.040 | 0.090 | 2.2 |
| CI | 10 | 2 | 4 | -0.041 | 0.141 | 5.0 |
| CI | 100 | 2 | 6 | -0.042 | 0.097 | 2.1 |
| CIc | 50 | 1 | 6 | -0.042 | 0.036 | 7.3 |
| CIc | 50 | 2 | 6 | -0.043 | 0.037 | 6.0 |
| CIc | 50 | 2 | 5 | -0.043 | 0.035 | 6.8 |
| CIc | 10 | 2 | 6 | -0.043 | 0.036 | 6.9 |
| CIc | 100 | 1 | 3 | -0.043 | 0.024 | 5.9 |
| CIc | 10 | 1 | 5 | -0.043 | 0.023 | 6.9 |
| CI | 10 | 2 | 3 | -0.044 | 0.074 | 2.1 |
| CI | 10 | 2 | 3 | -0.044 | 0.133 | 4.0 |
| CIc | 100 | 2 | 6 | -0.044 | 0.043 | 6.8 |
| CI | 50 | 1 | 3 | -0.044 | 0.118 | 2.1 |
| CI | 100 | 2 | 3 | -0.044 | 0.188 | 4.6 |
| CI | 50 | 1 | 3 | -0.044 | 0.144 | 3.7 |
| CIc | 10 | 1 | 6 | -0.044 | 0.039 | 7.3 |
| CI | 10 | 1 | 4 | -0.046 | 0.126 | 3.4 |
| CIc | 10 | 2 | 5 | -0.046 | 0.048 | 6.7 |
| CI | 10 | 1 | 4 | -0.047 | 0.043 | 2.1 |
| CIc | 100 | 2 | 5 | -0.048 | 0.044 | 7.0 |
| CI | 100 | 2 | 5 | -0.048 | 0.152 | 4.4 |
| CI | 50 | 1 | 5 | -0.048 | 0.105 | 2.1 |
| CI | 50 | 2 | 3 | -0.051 | 0.100 | 4.5 |
| CIc | 100 | 2 | 4 | -0.051 | 0.035 | 6.4 |
| CIc | 100 | 2 | 3 | -0.052 | 0.032 | 6.0 |
| CI | 100 | 2 | 4 | -0.053 | 0.056 | 4.5 |
| CI | 50 | 1 | 6 | -0.054 | 0.077 | 2.3 |
| CIc | 100 | 1 | 4 | -0.055 | 0.037 | 7.0 |
| CI | 100 | 1 | 6 | -0.057 | 0.136 | 5.5 |
| CI | 50 | 2 | 5 | -0.057 | 0.176 | 4.7 |
| CI | 50 | 1 | 3 | -0.058 | 0.100 | 3.8 |
| CI | 10 | 2 | 4 | -0.065 | 0.145 | 5.0 |
| CI | 50 | 1 | 4 | -0.066 | 0.147 | 4.1 |
| CI | 10 | 2 | 4 | -0.080 | 0.121 | 3.3 |
| CI | 50 | 1 | 4 | -0.084 | 0.135 | 3.6 |
| CI | 50 | 1 | 5 | -0.088 | 0.175 | 4.8 |

Cross-validated greedy forest tuning results ranked by validation gain

``` r
best_tuned_forest <- forest_tuning$best_fit
forest_surrogate_data <- forest_tuning$best_surrogate_data
```

``` r
forest_surrogate_fit <- forest_tuning$best_surrogate
```

``` r
readme_tree_plot(
  fit = forest_surrogate_fit,
  data = forest_surrogate_data,
  outcome_name = "forest_risk",
  outcome_label = "Predicted risk"
)
```

<img src="man/figures/README-forest-surrogate-plot-1.png" width="100%" />
