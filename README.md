
# ineqTrees

<!-- badges: start -->

[![R-CMD-check](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/m-mburu/ineqTrees/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

`ineqTrees` provides tools for studying socioeconomic inequality in
health outcomes with tree-based models. The package includes weighted
rank and concentration-index utilities, inequality-aware split scoring,
and wrappers around `partykit` for fitting conditional inference trees
and forests.

## Installation

You can install the development version of ineqTrees like so:

``` r
remotes::install_github("m-mburu/ineqTrees")
```

## Fitting a tree

The example below fits an inequality-aware conditional inference tree on
a sample from the built-in `kenya` dataset. The response combines the
ranking variable (`wealth`) and the health outcome (`deadu5_num`), while
the split criterion is based on concentration-index reduction.

``` r
pkgload::load_all(quiet = TRUE)
load("data/kenya.rda")

set.seed(1)

toy_kenya <- kenya[sample(nrow(kenya), 500), ]
toy_kenya$reg <- droplevels(toy_kenya$reg)

fit_tree <- ctree_ci(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg,
  data = toy_kenya,
  rank_name = "wealth",
  outcome_name = "deadu5_num",
  control = partykit::ctree_control(mincriterion = 0.95, maxdepth = 4)
)

inherits(fit_tree, "party")
#> [1] TRUE
partykit::nodeids(partykit::node_party(fit_tree), terminal = TRUE)
#> [1]  3  4  7  9 10 12 14 15
```

## Fit forests

``` r
fit_forest <- cf_ci(
  formula = cbind(wealth, deadu5_num) ~ rural + ed + reg,
  data = toy_kenya,
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
  newdata = toy_kenya,
  OOB = FALSE,
  FUN = function(y, w) stats::weighted.mean(y[, "deadu5_num"], w)
)

surrogate_data <- transform(toy_kenya, forest_risk = preds)

surrogate_fit <- ctree_ci(
  cbind(wealth, forest_risk) ~ rural + ed + unskilled,
  data = surrogate_data,
  rank_name = "wealth",
  outcome_name = "forest_risk",
  control = partykit::ctree_control(mincriterion = 0.95, maxdepth = 2)
)

summary(preds)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#> 0.03909 0.05607 0.07399 0.07371 0.08968 0.13204
partykit::nodeids(partykit::node_party(surrogate_fit), terminal = TRUE)
#> [1] 3 4 6 7
```
