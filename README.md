---
output: github_document
---




# ineqTrees

<!-- badges: start -->

 [![R-CMD-check](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->



`ineqTrees` provides tools for studying socioeconomic inequality in health
outcomes with tree-based models. The package includes weighted rank and
concentration-index utilities, inequality-aware split scoring, and wrappers
around `partykit` for fitting conditional inference trees and forests.

## Installation

You can install the development version of ineqTrees like so:

``` r
remotes::install_github("m-mburu/ineqTrees")
```

## Fitting a tree

The example below fits an inequality-aware conditional inference tree on a
sample from the built-in `kenya` dataset. The response combines the ranking
variable (`wealth`) and the health outcome (`deadu5_num`), while the split
criterion is based on concentration-index reduction.


``` r
library(ineqTrees)
load("data/kenya.rda")

set.seed(1)

fit_tree <- ctree_ci(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  control = partykit::ctree_control(mincriterion = 0.95, maxdepth = 4)
)

plot(
  fit_tree,
  gp = grid::gpar(fontsize = 6.5),
  data = kenya,
  var_labels = c(
    rural = "Residence",
    reg = "Province",
    ed = "Mother education",
    unskilled = "Mother occupation"
  ),
  terminal_stats = list(
    n = nrow,
    death_rate = function(df) mean(df$deadu5_num),
    mean_wealth = function(df) mean(df$wealth),
    ci = function(df) {
      ci_factory("CI")(cbind(df$wealth, df$deadu5_num), rep(1, nrow(df)))
    }
  ),
  stat_labels = list(
    n = "n",
    death_rate = "% death",
    mean_wealth = expression(mu ~ wealth),
    ci = "CI"
  ),
  stat_formatters = list(
    n = function(x) format(x, big.mark = ",", scientific = FALSE),
    death_rate = function(x) sprintf("%.2f%%", 100 * x),
    mean_wealth = function(x) sprintf("%.2f", x),
    ci = function(x) sprintf("%.3f", x)
  ),
  terminal_fill = "#d9d9d9",
  tp_args = list(
    width_lines = 11,
    height_lines = 5.2
  ),
  tnex = 0.85
)
```

<div class="figure">
<img src="man/figures/README-example-1.png" alt="plot of chunk example" width="100%" />
<p class="caption">plot of chunk example</p>
</div>

## Fit forests


``` r
fit_forest <- cf_ci(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled,
  data = kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  ntree = 10L,
  mtry = 1L,
  control = partykit::ctree_control(mincriterion = 0.95, maxdepth = 4)
)
```


### Fit surrogate trees


``` r
preds <- stats::predict(
  fit_forest,
  newdata = kenya,
  OOB = FALSE,
  FUN = function(y, w) stats::weighted.mean(y[, "deadu5_num"], w)
)

surrogate_data <- transform(kenya, forest_risk = preds)

surrogate_fit <- ctree_ci(
  cbind(wealth, forest_risk) ~ rural + ed + reg + unskilled,
  data = surrogate_data,
  rank_name = "wealth",
  outcome_name = "forest_risk",
  control = partykit::ctree_control(mincriterion = 0.95, maxdepth = 4)
)

summary(preds)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#> 0.03283 0.06146 0.07527 0.07328 0.08570 0.14294
plot(
  surrogate_fit,
  gp = grid::gpar(fontsize = 6.5),
  data = surrogate_data,
  var_labels = c(
    rural = "Residence",
    reg = "Province",
    ed = "Mother education",
    unskilled = "Mother occupation"
  ),
  terminal_stats = list(
    n = nrow,
    predicted_death_rate = function(df) mean(df$forest_risk),
    mean_wealth = function(df) mean(df$wealth),
    ci = function(df) {
      ci_factory("CI")(cbind(df$wealth, df$forest_risk), rep(1, nrow(df)))
    }
  ),
  stat_labels = list(
    n = "n",
    predicted_death_rate = "% death",
    mean_wealth = expression(mu ~ wealth),
    ci = "CI"
  ),
  stat_formatters = list(
    n = function(x) format(x, big.mark = ",", scientific = FALSE),
    predicted_death_rate = function(x) sprintf("%.2f%%", 100 * x),
    mean_wealth = function(x) sprintf("%.2f", x),
    ci = function(x) sprintf("%.3f", x)
  ),
  terminal_fill = "#d9d9d9",
  tp_args = list(
    width_lines = 11,
    height_lines = 5.2
  ),
  tnex = 0.85
)
```

<div class="figure">
<img src="man/figures/README-surrogate-1.png" alt="plot of chunk surrogate" width="100%" />
<p class="caption">plot of chunk surrogate</p>
</div>

## SHAP-based decomposition

- Approximate SHAP values for the fitted forest with `fastshap::explain()`, using a prediction wrapper that returns the predicted outcome for each observation. 
- Decompose the concentration index of those predicted risks with `shap_conc_decomp()`.


``` r
predict_cf_ci_wrapper <- function(object, newdata) {
  stats::predict(
    object,
    newdata = newdata,
    OOB = FALSE,
    FUN = function(y, w) stats::weighted.mean(y[, "deadu5_num"], w)
  )
}

set.seed(20260328)
shap_eval_n <- min(400L, nrow(kenya))
shap_rows <- sort(sample.int(nrow(kenya), shap_eval_n))
forest_X <- kenya[c("rural", "ed", "reg", "unskilled")]
shap_X_eval <- forest_X[shap_rows, , drop = FALSE]
forest_pred_eval <- predict_cf_ci_wrapper(fit_forest, shap_X_eval)
wealth_eval <- kenya$wealth[shap_rows]

forest_shap <- fastshap::explain(
  object = fit_forest,
  X = forest_X,
  pred_wrapper = predict_cf_ci_wrapper,
  newdata = shap_X_eval,
  nsim = 64,
  adjust = TRUE
)

decomp <- shap_conc_decomp(
  shap = forest_shap,
  rank = wealth_eval,
  prediction = forest_pred_eval
)

decomp$diagnostics
#>        n mean_prediction concentration_index    shap_sum additivity_gap
#>    <int>           <num>               <num>       <num>          <num>
#> 1:   400      0.07383822         -0.08955779 -0.08955779  -3.491166e-12
#>    centered_rank_sum prediction_source
#>                <num>            <char>
#> 1:     -5.551115e-17        prediction
decomp$contributions
#>      feature     D_k_SHAP pct_contribution abs_contribution
#>       <char>        <num>            <num>            <num>
#> 1:     rural -0.034318511        38.319961      0.034318511
#> 2:       reg -0.026980079        30.125887      0.026980079
#> 3:        ed -0.020417402        22.798019      0.020417402
#> 4: unskilled -0.007841799         8.756133      0.007841799

ggplot2::ggplot(
  as.data.frame(decomp$contributions),
  ggplot2::aes(
    x = stats::reorder(feature, pct_contribution),
    y = pct_contribution,
    fill = pct_contribution > 0
  )
) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(
    values = c("#2166ac", "#b2182b"),
    guide = "none"
  ) +
  ggplot2::labs(
    x = NULL,
    y = "Percentage contribution",
    title = "SHAP-based concentration-index decomposition"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
```

<div class="figure">
<img src="man/figures/README-shap-decomposition-1.png" alt="plot of chunk shap-decomposition" width="100%" />
<p class="caption">plot of chunk shap-decomposition</p>
</div>
