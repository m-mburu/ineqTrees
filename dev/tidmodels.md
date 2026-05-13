
# LLM Instruction: Add Tidymodels Bridges for `ineqTrees`

You are working in the R package:

`C:/Users/moses.mburu.FIND/Pictures/personal/ineqTrees`

The package already implements:

- `ci_tree()`
- `ci_forest()`
- `ci_tree_control()`
- `ci_tree_validation_gain()`
- `ci_dials_grid()`
- `tune_ci_tree()`
- `tune_ci_forest()`

The goal is to let users fit both inequality-aware trees and forests through tidymodels/parsnip:

```r
decision_tree(tree_depth = 4, min_n = 50) |>
  set_engine("ineqTrees", type = "CIg") |>
  set_mode("regression")
```

```r
rand_forest(trees = 100, mtry = 4, min_n = 50) |>
  set_engine("ineqTrees", type = "CIg") |>
  set_mode("regression")
```

Also expose CI validation gain as a yardstick-compatible metric.

## Important Package Structure

This package uses `{fusen}`. Do not edit generated `R/*.R` files directly unless explicitly asked.

Add the new implementation in a flat file, preferably:

```r
dev/tidymodels_bridge.Rmd
```

Then inflate it to generate:

```r
R/tidymodels_bridge.R
tests/testthat/test-tidymodels_bridge.R
vignettes/tidymodels-bridge.Rmd
```

Use the existing package style in `dev/model_selection.Rmd`.

## Dependencies

Update `DESCRIPTION`.

Recommended `Imports` if the bridge should work after `library(ineqTrees)`:

```r
parsnip,
hardhat,
yardstick,
tibble,
rlang
```

Keep `dials` in `Suggests` or `Imports`; it is used for parsnip argument metadata.

## Parsnip Argument Mapping

Parsnip exposes only generic tree/forest controls.

Actual parsnip signatures are:

```r
decision_tree(
  mode = "unknown",
  engine = "rpart",
  cost_complexity = NULL,
  tree_depth = NULL,
  min_n = NULL
)
```

```r
rand_forest(
  mode = "unknown",
  engine = "ranger",
  mtry = NULL,
  trees = NULL,
  min_n = NULL
)
```

Map these to `ineqTrees` as follows:

For `decision_tree()`:

```r
decision_tree(tree_depth) -> ci_tree_control(maxdepth)
decision_tree(min_n)      -> ci_tree_control(minbucket)
cost_complexity           -> not used initially
```

For `rand_forest()`:

```r
rand_forest(trees) -> ci_forest(ntree)
rand_forest(mtry)  -> ci_forest(mtry)
rand_forest(min_n) -> ci_tree_control(minbucket)
```

Engine-specific arguments should be supplied through `set_engine()`:

```r
rank_name
outcome_name
type
minsplit
minprob
maxdepth
min_gain
perturb
na.action
```

For trees, `tree_depth` should map to `maxdepth`, but allow `maxdepth` in `set_engine()` to override or fill in when `tree_depth` is absent.

## Part 1: Fit Wrappers

### 1. Tree wrapper

Implement an exported wrapper:

```r
ci_tree_parsnip <- function(
    formula,
    data,
    weights = NULL,
    rank_name = "wealth",
    outcome_name = "deadu5_num",
    type = "CIg",
    minbucket = 100L,
    minsplit = 200L,
    minprob = 0.01,
    maxdepth = 4L,
    min_gain = 0,
    na.action = stats::na.omit,
    ...
) {
  if (!is.null(weights)) {
    weights <- as.numeric(weights)
  }

  control <- ci_tree_control(
    minsplit = as.integer(minsplit),
    minbucket = as.integer(minbucket),
    minprob = minprob,
    maxdepth = as.integer(maxdepth),
    min_gain = min_gain
  )

  ci_tree(
    formula = formula,
    data = data,
    rank_name = rank_name,
    outcome_name = outcome_name,
    weights = weights,
    type = type,
    control = control,
    na.action = na.action,
    ...
  )
}
```

### 2. Forest wrapper

Implement an exported wrapper:

```r
ci_forest_parsnip <- function(
    formula,
    data,
    weights = NULL,
    rank_name = "wealth",
    outcome_name = "deadu5_num",
    type = "CIg",
    ntree = 500L,
    mtry = NULL,
    minbucket = 100L,
    minsplit = 200L,
    minprob = 0.01,
    maxdepth = 4L,
    min_gain = 0,
    perturb = list(replace = FALSE, fraction = 0.632),
    na.action = stats::na.omit,
    ...
) {
  if (!is.null(weights)) {
    weights <- as.numeric(weights)
  }

  control <- ci_tree_control(
    minsplit = as.integer(minsplit),
    minbucket = as.integer(minbucket),
    minprob = minprob,
    maxdepth = as.integer(maxdepth),
    min_gain = min_gain
  )

  ci_forest(
    formula = formula,
    data = data,
    rank_name = rank_name,
    outcome_name = outcome_name,
    weights = weights,
    type = type,
    control = control,
    ntree = as.integer(ntree),
    mtry = mtry,
    perturb = perturb,
    na.action = na.action,
    ...
  )
}
```

Parsnip case weights arrive as hardhat weight vectors, so `as.numeric(weights)` is required before passing to `ci_tree()` or `ci_forest()`.

## Part 2: Register Parsnip Engines

Implement one exported registration function:

```r
register_ineqtrees_parsnip <- function() {
  register_ineqtrees_decision_tree()
  register_ineqtrees_rand_forest()
  invisible(TRUE)
}
```

### 1. Register `decision_tree()` engine

```r
register_ineqtrees_decision_tree <- function() {
  if (!any(parsnip::show_engines("decision_tree")$engine == "ineqTrees")) {
    parsnip::set_model_engine(
      model = "decision_tree",
      mode = "regression",
      eng = "ineqTrees"
    )
  }

  parsnip::set_dependency("decision_tree", eng = "ineqTrees", pkg = "ineqTrees")

  parsnip::set_model_arg(
    model = "decision_tree",
    eng = "ineqTrees",
    parsnip = "tree_depth",
    original = "maxdepth",
    func = list(pkg = "dials", fun = "tree_depth"),
    has_submodel = FALSE
  )

  parsnip::set_model_arg(
    model = "decision_tree",
    eng = "ineqTrees",
    parsnip = "min_n",
    original = "minbucket",
    func = list(pkg = "dials", fun = "min_n"),
    has_submodel = FALSE
  )

  parsnip::set_encoding(
    model = "decision_tree",
    mode = "regression",
    eng = "ineqTrees",
    options = list(
      predictor_indicators = "none",
      compute_intercept = FALSE,
      remove_intercept = FALSE,
      allow_sparse_x = FALSE
    )
  )

  parsnip::set_fit(
    model = "decision_tree",
    mode = "regression",
    eng = "ineqTrees",
    value = list(
      interface = "formula",
      data = c(formula = "formula", data = "data", weights = "weights"),
      protect = c("formula", "data", "weights"),
      func = c(pkg = "ineqTrees", fun = "ci_tree_parsnip"),
      defaults = list()
    )
  )

  parsnip::set_pred(
    model = "decision_tree",
    mode = "regression",
    eng = "ineqTrees",
    type = "numeric",
    value = list(
      pre = NULL,
      post = function(results, object) {
        tibble::tibble(.pred = as.numeric(results))
      },
      func = c(fun = "predict"),
      args = list(
        object = rlang::expr(object$fit),
        newdata = rlang::expr(new_data),
        type = "response"
      )
    )
  )

  parsnip::set_pred(
    model = "decision_tree",
    mode = "regression",
    eng = "ineqTrees",
    type = "raw",
    value = list(
      pre = NULL,
      post = function(results, object) {
        tibble::tibble(.node = as.integer(results))
      },
      func = c(fun = "predict"),
      args = list(
        object = rlang::expr(object$fit),
        newdata = rlang::expr(new_data),
        type = "node"
      )
    )
  )

  invisible(TRUE)
}
```

Note: the raw prediction type gives terminal node IDs. This is useful for the CI gain yardstick metric.

### 2. Register `rand_forest()` engine

```r
register_ineqtrees_rand_forest <- function() {
  if (!any(parsnip::show_engines("rand_forest")$engine == "ineqTrees")) {
    parsnip::set_model_engine(
      model = "rand_forest",
      mode = "regression",
      eng = "ineqTrees"
    )
  }

  parsnip::set_dependency("rand_forest", eng = "ineqTrees", pkg = "ineqTrees")

  parsnip::set_model_arg(
    model = "rand_forest",
    eng = "ineqTrees",
    parsnip = "trees",
    original = "ntree",
    func = list(pkg = "dials", fun = "trees"),
    has_submodel = FALSE
  )

  parsnip::set_model_arg(
    model = "rand_forest",
    eng = "ineqTrees",
    parsnip = "mtry",
    original = "mtry",
    func = list(pkg = "dials", fun = "mtry"),
    has_submodel = FALSE
  )

  parsnip::set_model_arg(
    model = "rand_forest",
    eng = "ineqTrees",
    parsnip = "min_n",
    original = "minbucket",
    func = list(pkg = "dials", fun = "min_n"),
    has_submodel = FALSE
  )

  parsnip::set_encoding(
    model = "rand_forest",
    mode = "regression",
    eng = "ineqTrees",
    options = list(
      predictor_indicators = "none",
      compute_intercept = FALSE,
      remove_intercept = FALSE,
      allow_sparse_x = FALSE
    )
  )

  parsnip::set_fit(
    model = "rand_forest",
    mode = "regression",
    eng = "ineqTrees",
    value = list(
      interface = "formula",
      data = c(formula = "formula", data = "data", weights = "weights"),
      protect = c("formula", "data", "weights"),
      func = c(pkg = "ineqTrees", fun = "ci_forest_parsnip"),
      defaults = list()
    )
  )

  parsnip::set_pred(
    model = "rand_forest",
    mode = "regression",
    eng = "ineqTrees",
    type = "numeric",
    value = list(
      pre = NULL,
      post = function(results, object) {
        tibble::tibble(.pred = as.numeric(results))
      },
      func = c(fun = "predict"),
      args = list(
        object = rlang::expr(object$fit),
        newdata = rlang::expr(new_data),
        type = "response"
      )
    )
  )

  parsnip::set_pred(
    model = "rand_forest",
    mode = "regression",
    eng = "ineqTrees",
    type = "raw",
    value = list(
      pre = NULL,
      post = function(results, object) {
        as_tibble(as.data.frame(results))
      },
      func = c(fun = "predict"),
      args = list(
        object = rlang::expr(object$fit),
        newdata = rlang::expr(new_data),
        type = "node"
      )
    )
  )

  invisible(TRUE)
}
```

For forest raw predictions, `predict.ci_forest(type = "node")` returns one node column per tree. This is useful for diagnostics, but for yardstick CI gain you may prefer a surrogate-tree node column.

## Registration Strategy

If `parsnip` is in `Imports`, call the registration from `.onLoad()`:

```r
.onLoad <- function(libname, pkgname) {
  register_ineqtrees_parsnip()
}
```

If tidymodels dependencies are optional, do not use `.onLoad()`. Export `register_ineqtrees_parsnip()` and document that users must call:

```r
ineqTrees::register_ineqtrees_parsnip()
```

before using:

```r
set_engine("ineqTrees")
```

## Part 3: Yardstick Metric Bridge

The package already has `ci_tree_validation_gain()`, but yardstick metrics usually receive prediction tables, not fitted model objects. Therefore implement a prediction-table metric that computes CI gain when a partition column is available.

### 1. Vector metric

Implement:

```r
ci_gain_vec <- function(
    truth,
    estimate,
    rank,
    node = NULL,
    case_weights = NULL,
    type = "CIg",
    root_impurity = NULL,
    na_rm = TRUE,
    ...
) {
  truth <- .ci_outcome_numeric(truth, "truth")
  estimate <- as.numeric(estimate)
  rank <- as.numeric(rank)

  if (is.null(case_weights)) {
    case_weights <- rep(1, length(truth))
  } else {
    case_weights <- as.numeric(case_weights)
  }

  if (is.null(node)) {
    node <- estimate
  }

  keep <- stats::complete.cases(truth, estimate, rank, node, case_weights) &
    case_weights > 0

  if (!na_rm && any(!keep)) {
    return(NA_real_)
  }

  truth <- truth[keep]
  rank <- rank[keep]
  node <- node[keep]
  case_weights <- case_weights[keep]

  ci_fun <- ci_factory(type)
  y <- cbind(rank = rank, outcome = truth)

  if (is.null(root_impurity)) {
    root_impurity <- ci_fun(y, case_weights)
  }

  total_weight <- sum(case_weights)
  node_indices <- split(seq_along(truth), node)

  child_impurity <- sum(vapply(
    node_indices,
    function(idx) {
      node_weight <- sum(case_weights[idx])
      (node_weight / total_weight) *
        ci_fun(y[idx, , drop = FALSE], case_weights[idx])
    },
    numeric(1)
  ))

  as.numeric(root_impurity - child_impurity)
}
```

Important: true CI gain requires a partition. For `decision_tree()`, use terminal node IDs from raw predictions. For `rand_forest()`, use either a surrogate tree’s node IDs or a carefully defined forest grouping. If only `.pred` is available, using predictions as `node` is only an approximation.

### 2. Data-frame yardstick metric

Implement:

```r
ci_gain <- function(data, ...) {
  UseMethod("ci_gain")
}

ci_gain <- yardstick::new_numeric_metric(ci_gain, direction = "maximize")

ci_gain.data.frame <- function(
    data,
    truth,
    estimate,
    rank,
    node = NULL,
    case_weights = NULL,
    type = "CIg",
    root_impurity = NULL,
    na_rm = TRUE,
    ...
) {
  truth <- rlang::enquo(truth)
  estimate <- rlang::enquo(estimate)
  rank <- rlang::enquo(rank)
  node <- rlang::enquo(node)
  case_weights <- rlang::enquo(case_weights)

  truth_vec <- rlang::eval_tidy(truth, data)
  estimate_vec <- rlang::eval_tidy(estimate, data)
  rank_vec <- rlang::eval_tidy(rank, data)

  node_vec <- if (rlang::quo_is_null(node)) {
    NULL
  } else {
    rlang::eval_tidy(node, data)
  }

  weight_vec <- if (rlang::quo_is_null(case_weights)) {
    NULL
  } else {
    rlang::eval_tidy(case_weights, data)
  }

  tibble::tibble(
    .metric = "ci_gain",
    .estimator = "standard",
    .estimate = ci_gain_vec(
      truth = truth_vec,
      estimate = estimate_vec,
      rank = rank_vec,
      node = node_vec,
      case_weights = weight_vec,
      type = type,
      root_impurity = root_impurity,
      na_rm = na_rm
    )
  )
}
```

### 3. Optional prediction CI metric

Also implement a simpler metric for the concentration index of predictions:

```r
ci_prediction_index_vec <- function(
    estimate,
    rank,
    case_weights = NULL,
    type = "CIg"
) {
  if (is.null(case_weights)) {
    case_weights <- rep(1, length(estimate))
  }

  ci_factory(type)(
    cbind(rank = as.numeric(rank), outcome = as.numeric(estimate)),
    as.numeric(case_weights)
  )
}
```

This is not split gain, but it is useful for comparing inequality in fitted risks.

## Part 4: Tests

Add tests in:

```r
tests/testthat/test-tidymodels_bridge.R
```

### Tree engine test

```r
test_that("decision_tree can fit ci_tree through ineqTrees engine", {
  register_ineqtrees_parsnip()

  toy_data <- data.frame(
    rank = c(10, 20, 30, 40, 50, 60, 70, 80),
    outcome = c(1, 0, 1, 0, 1, 1, 0, 1),
    income = c(2, 4, 6, 8, 10, 12, 14, 16),
    group = factor(c("a", "a", "b", "b", "a", "a", "b", "b")),
    weight = 1
  )

  spec <- parsnip::decision_tree(tree_depth = 1, min_n = 1) |>
    parsnip::set_engine(
      "ineqTrees",
      rank_name = "rank",
      outcome_name = "outcome",
      type = "CIg",
      minsplit = 1,
      minprob = 0
    ) |>
    parsnip::set_mode("regression")

  fit <- parsnip::fit(
    spec,
    cbind(rank, outcome) ~ income + group,
    data = toy_data,
    case_weights = hardhat::importance_weights(toy_data$weight)
  )

  expect_s3_class(fit$fit, "ci_tree")

  pred <- predict(fit, new_data = toy_data)
  expect_s3_class(pred, "tbl_df")
  expect_true(".pred" %in% names(pred))
  expect_equal(nrow(pred), nrow(toy_data))

  nodes <- predict(fit, new_data = toy_data, type = "raw")
  expect_true(".node" %in% names(nodes))
})
```

### Forest engine test

```r
test_that("rand_forest can fit ci_forest through ineqTrees engine", {
  register_ineqtrees_parsnip()

  toy_data <- data.frame(
    rank = c(10, 20, 30, 40, 50, 60, 70, 80),
    outcome = c(1, 0, 1, 0, 1, 1, 0, 1),
    income = c(2, 4, 6, 8, 10, 12, 14, 16),
    group = factor(c("a", "a", "b", "b", "a", "a", "b", "b")),
    weight = 1
  )

  spec <- parsnip::rand_forest(trees = 3, mtry = 1, min_n = 1) |>
    parsnip::set_engine(
      "ineqTrees",
      rank_name = "rank",
      outcome_name = "outcome",
      type = "CIg",
      minsplit = 1,
      minprob = 0,
      maxdepth = 1
    ) |>
    parsnip::set_mode("regression")

  fit <- parsnip::fit(
    spec,
    cbind(rank, outcome) ~ income + group,
    data = toy_data,
    case_weights = hardhat::importance_weights(toy_data$weight)
  )

  expect_s3_class(fit$fit, "ci_forest")

  pred <- predict(fit, new_data = toy_data)
  expect_s3_class(pred, "tbl_df")
  expect_true(".pred" %in% names(pred))
  expect_equal(nrow(pred), nrow(toy_data))
})
```

### Yardstick metric test

```r
test_that("ci_gain computes a yardstick-style metric", {
  toy_pred <- data.frame(
    truth = c(1, 0, 1, 0, 1, 1),
    pred = c(0.8, 0.2, 0.7, 0.3, 0.6, 0.9),
    rank = c(10, 20, 30, 40, 50, 60),
    node = c(1, 1, 2, 2, 2, 2),
    weight = 1
  )

  out <- ci_gain(
    toy_pred,
    truth = truth,
    estimate = pred,
    rank = rank,
    node = node,
    case_weights = weight,
    type = "CIg"
  )

  expect_s3_class(out, "tbl_df")
  expect_equal(out$.metric, "ci_gain")
  expect_true(is.finite(out$.estimate))
})
```

## Part 5: Example Usage

### Decision tree

```r
library(ineqTrees)
library(parsnip)
library(hardhat)

register_ineqtrees_parsnip()

tree_spec <- decision_tree(tree_depth = 4, min_n = 100) |>
  set_engine(
    "ineqTrees",
    rank_name = "wealth",
    outcome_name = "deadu5_num",
    type = "CIg",
    minsplit = 500,
    minprob = 0.01,
    min_gain = 0.001
  ) |>
  set_mode("regression")

tree_fit <- fit(
  tree_spec,
  cbind(wealth, deadu5_num) ~ rural + male + reg,
  data = congo_model_dt,
  case_weights = hardhat::importance_weights(congo_model_dt$sample_weight)
)

predict(tree_fit, new_data = congo_model_dt)
predict(tree_fit, new_data = congo_model_dt, type = "raw")
```

### Random forest

```r
forest_spec <- rand_forest(trees = 500, mtry = 4, min_n = 100) |>
  set_engine(
    "ineqTrees",
    rank_name = "wealth",
    outcome_name = "deadu5_num",
    type = "CIg",
    minsplit = 500,
    minprob = 0.01,
    maxdepth = 5,
    min_gain = 0.001,
    perturb = list(replace = FALSE, fraction = 0.632)
  ) |>
  set_mode("regression")

forest_fit <- fit(
  forest_spec,
  cbind(wealth, deadu5_num) ~ rural + male + reg,
  data = congo_model_dt,
  case_weights = hardhat::importance_weights(congo_model_dt$sample_weight)
)

predict(forest_fit, new_data = congo_model_dt)
```

## Part 6: Tuning Example

```r
library(tune)
library(dials)
library(rsample)
library(workflows)

register_ineqtrees_parsnip()

spec <- rand_forest(
  trees = tune(),
  mtry = tune(),
  min_n = tune()
) |>
  set_engine(
    "ineqTrees",
    rank_name = "wealth",
    outcome_name = "deadu5_num",
    type = "CIg",
    minsplit = 500,
    minprob = 0.01,
    maxdepth = 5
  ) |>
  set_mode("regression")

wf <- workflow() |>
  add_model(spec) |>
  add_formula(cbind(wealth, deadu5_num) ~ rural + male + reg)

grid <- grid_regular(
  trees(range = c(50L, 200L)),
  mtry(range = c(1L, 4L)),
  min_n(range = c(25L, 100L)),
  levels = 3
)

folds <- vfold_cv(congo_model_dt, v = 5)

tuned <- tune_grid(
  wf,
  resamples = folds,
  grid = grid
)
```

## Key Design Notes

- `decision_tree(tree_depth)` maps to `ci_tree_control(maxdepth)`.
- `decision_tree(min_n)` maps to `ci_tree_control(minbucket)`.
- `decision_tree(cost_complexity)` is ignored initially.
- `rand_forest(trees)` maps to `ci_forest(ntree)`.
- `rand_forest(mtry)` maps to `ci_forest(mtry)`.
- `rand_forest(min_n)` maps to `ci_tree_control(minbucket)`.
- `minsplit`, `minprob`, `min_gain`, `type`, `rank_name`, `outcome_name`, and `perturb` are engine-specific and should be passed through `set_engine()`.
- Use regression mode because `ci_tree()` and `ci_forest()` return numeric predicted risks/means.
- The formula should remain two-column: `cbind(rank, outcome) ~ predictors`.
- True CI validation gain requires a terminal-node or surrogate-node partition. Prediction-only `.pred` values are not enough for exact split gain.
```