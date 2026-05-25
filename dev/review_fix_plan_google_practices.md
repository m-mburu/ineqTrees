# Review Fix Plan: Code Health, Correctness, and Maintainability

This note records six review findings from the fusen templates and C++ split
engine, using the Google code-review lens: design, functionality, complexity,
tests, naming, comments, consistency, documentation, and user impact.

The common theme is that the package should make the same split decisions
across R and C++ engines, reject invalid inputs before they reach low-level
numeric code, and test the behavior users actually depend on.

## 1. Factor Split Search Can Miss the Best Split

### Problem

`best_factor_split()` orders factor levels by weighted mean outcome, then tries
only cumulative splits in that ordering. The C++ factor split engine mirrors the
same strategy.

That shortcut is common for squared-error regression trees, but it is not
guaranteed to optimize concentration-index gain. A better non-cumulative factor
partition can exist.

### Why We Must Solve It

This is a correctness issue. If the split search misses the best admissible
factor split, then:

- `ci_tree()` can grow the wrong tree.
- `ci_forest()` can aggregate many suboptimal trees.
- `fit$variable.importance` can credit the wrong variables.
- R and C++ tests may still pass because both engines share the same flawed
  heuristic.

### Proposed Fix

For unordered factors, evaluate all binary partitions when the number of
present levels is small enough.

Recommended control:

```r
ci_tree_control(
  max_factor_levels_partition = 10L
)
```

For `k` present levels, exhaustive binary partitions are `2^(k - 1) - 1`. To
avoid evaluating complements twice, force the first present level to be in the
left child.

For larger factors, choose one of:

- return a clear error asking the user to reduce levels,
- keep the current ordered heuristic but document it as approximate,
- or add an explicit approximation flag such as
  `factor_split = c("exhaustive", "ordered")`.

The safest first implementation is:

- exhaustive for `k <= 10`,
- ordered fallback for `k > 10`,
- document the fallback clearly, especially for high-cardinality fields such as
  DRC provinces with around 100 levels.

Important performance note: exhaustive factor splitting grows exponentially.
At `k = 10`, the number of unique binary partitions is `2^9 - 1 = 511`, which is manageable.
At `k = 49`, the number of unique binary partitions is `2^48 - 1`, which is far
too large for a literal full enumeration in normal use. If we keep the user
requirement "exhaustive for 10 or fewer levels", the implementation needs a
guardrail such as:

- a hard timeout or maximum candidate count,
- a warning/error when the implied partition count is too large for the current
  data,
- or a smarter exact algorithm if one can be derived for the concentration-index
  objective.

Without that guardrail, a 49-level factor could make `ci_tree()` effectively
non-terminating.

### Files to Edit

Both R and C++ must change together because the package exposes parallel split
engines and tests expect parity.

- `dev/ci_split_search.Rmd`
  - Update `best_factor_split()`.
  - Add an exhaustive factor-partition helper for the R engine.
  - Add tests in the factor split-search test chunk.
- `dev/ci_split_search_cpp.Rmd`
  - Update wrapper documentation if new controls or return behavior are added.
  - Add R/C++ parity tests for exhaustive factor splits.
- `src/ci_split_search_cpp.cpp`
  - Update `ci_best_factor_split_cpp_engine()`.
  - Keep split enumeration and tie-breaking consistent with the R helper.
- `dev/ci_tree_builder.Rmd`
  - Add any new factor-search control option to `ci_tree_control()` and
    `.ci_tree_normalize_control()`.
- `dev/ci_tree_models.Rmd`
  - Update `ci_tree()` and `ci_forest()` docs if factor split behavior becomes
    configurable.
- `src/RcppExports.cpp` and `R/RcppExports.R`
  - Do not edit by hand. Regenerate only if the C++ exported function
    signature changes.

### Tests

Add a fixture where the current cumulative ordering misses the exhaustive best
split. Test both:

- `best_factor_split()`
- `best_factor_split_cpp()`

Also test R/C++ parity on factors with 3-5 levels.

## 2. Non-Finite Weights Are Accepted

### Problem

`ci_tree()` and `ci_forest()` reject negative and missing weights, but do not
reject `Inf`, `-Inf`, or `NaN` consistently before fitting.

The C++ path filters invalid weights internally in some places, while the R path
can let non-finite weights propagate into weighted means and gains.

### Why We Must Solve It

This is both a correctness and consistency issue.

Invalid weights can cause:

- different split decisions between `split_engine = "R"` and `"cpp"`,
- `NaN` gains,
- misleading node summaries,
- hard-to-debug downstream errors.

### Proposed Fix

Create one internal validator and use it everywhere weights enter public
fitting/scoring APIs:

```r
.ci_validate_weights <- function(weights, n, arg = "weights") {
  if (length(weights) != n) stop(...)
  if (anyNA(weights)) stop(...)
  if (!all(is.finite(weights))) stop(...)
  if (any(weights < 0)) stop(...)
  if (!any(weights > 0)) stop(...)
  as.numeric(weights)
}
```

Use it in:

- `ci_tree()`
- `ci_forest()`
- `ci_gain_vec()`
- `ci_prediction_index_vec()`
- validation-gain helpers where applicable.

### Files to Edit

This is mostly R-side validation. The C++ engine already filters some invalid
rows internally, but public R APIs should reject invalid inputs before split
search begins.

- `dev/ci_tree_models.Rmd`
  - Validate `weights` in `ci_tree()`.
  - Validate `weights` in `ci_forest()`.
  - Consider adding a shared internal validator in this template if it is only
    used by tree/forest fitting.
- `dev/tidymodels_bridge.Rmd`
  - Validate `case_weights` in `ci_gain_vec()`.
  - Validate `case_weights` in `ci_prediction_index_vec()`.
- `dev/model_selection.Rmd`
  - Reuse the same validation logic in validation-gain and tuning helpers where
    weights enter directly.
- `dev/ci_split_search.Rmd`
  - Add defensive tests for direct R split-helper calls with invalid weights.
- `dev/ci_split_search_cpp.Rmd`
  - Add parity tests showing invalid weights are rejected before reaching C++.
- `src/ci_split_search_cpp.cpp`
  - No required change unless C++ should throw on non-finite weights rather
    than silently skip them. If changed, mirror the behavior in R.

### Tests

Add tests for:

- `weights = c(1, Inf, 1)`
- `weights = c(1, NaN, 1)`
- `weights = c(1, -Inf, 1)`
- R and C++ split engines returning the same result after validation.

## 3. Control Validation Allows Non-Finite Size and Depth Values

### Problem

`.ci_tree_normalize_control()` checks scalar controls for length and `NA`, but
does not require finite values for all controls.

For example, `minsplit = Inf` can be converted through `ceiling()` and
`as.integer()` into invalid integer values. Similar issues can occur with
`maxdepth`, `minbucket`, and `minprob`.

### Why We Must Solve It

Controls define the tree-growth contract. Non-finite controls make stopping
rules unpredictable and can produce warnings, invalid comparisons, or trees that
do not match user intent.

### Proposed Fix

Require finite numeric values for structural controls:

- `minsplit`
- `minbucket`
- `minprob`
- `maxdepth`
- `min_relative_gain`

For `min_gain`, decide explicitly whether `Inf` is allowed. If keeping
`min_gain = Inf` as a convenient "never split" setting, document and test it.
Otherwise require it to be finite too.

Suggested rule:

```r
finite_names <- c(
  "minsplit", "minbucket", "minprob", "maxdepth", "min_relative_gain"
)
```

Then handle `min_gain` separately.

### Files to Edit

This is a control-layer change. It affects both R and C++ engines because the
same normalized control object is passed to either split path.

- `dev/ci_tree_builder.Rmd`
  - Update `ci_tree_control()` if adding new control fields.
  - Update `.ci_tree_normalize_control()`.
  - Add tests in the `tests-ci_tree_control` chunk.
- `dev/ci_split_search.Rmd`
  - No algorithm change expected, but tests may need updates if
    `min_gain = Inf` behavior changes.
- `dev/ci_split_search_cpp.Rmd`
  - No wrapper change expected unless controls passed to C++ change.
- `src/ci_split_search_cpp.cpp`
  - No change expected unless new controls are passed into exported C++
    functions.
- `dev/ci_tree_models.Rmd`
  - Update examples or docs if public control semantics change.

### Tests

Add tests that reject:

- `minsplit = Inf`
- `minbucket = Inf`
- `maxdepth = Inf`
- `minprob = Inf`
- `min_relative_gain = Inf`

If `min_gain = Inf` is allowed, add a test showing it produces no split.

## 4. `perturb` Is Not Validated as a List

### Problem

`.ci_forest_sample()` assumes `perturb` supports `$replace` and `$fraction`.
Malformed inputs can produce low-level errors.

### Why We Must Solve It

This is user-facing API hygiene. A forest resampling configuration is a public
argument, so errors should tell users what to fix.

### Proposed Fix

Validate `perturb` at the start of `.ci_forest_sample()` or in `ci_forest()`.

Suggested checks:

```r
if (!is.null(perturb) && !is.list(perturb)) {
  stop("`perturb` must be `NULL` or a list.", call. = FALSE)
}
```

Then validate:

- `replace` is `NULL` or a single non-missing logical.
- `fraction` is `NULL` or a single finite positive number.
- if `replace = FALSE`, cap sample size at `n`.

### Files to Edit

This is R-only because forest sampling is performed in R before each tree fit.

- `dev/ci_tree_models.Rmd`
  - Update `.ci_forest_sample()`.
  - Possibly validate `perturb` once in `ci_forest()` before tree growth, so
    errors happen before any sampling begins.
  - Add tests in the `tests-ci_forest` chunk.
- `dev/model_selection.Rmd`
  - Check whether `tune_ci_forest()` passes `perturb` through directly. Add
    tests if malformed `perturb` should be caught during tuning too.
- C++ files
  - No change expected.

### Tests

Add tests for:

- `perturb = 0.632`
- `perturb = list(replace = NA)`
- `perturb = list(fraction = Inf)`
- `perturb = list(fraction = 0)`

## 5. Parallel Forest Path Needs a Friendly Dependency Check

### Problem

`ci_forest(parallel = TRUE)` calls `future.apply::future_lapply()` directly.
`future.apply` is in `Suggests`, not `Imports`.

### Why We Must Solve It

If a suggested package is absent, users should receive a clear package-level
message instead of a namespace error.

### Proposed Fix

Before calling `future.apply::future_lapply()`, add:

```r
if (parallel && !requireNamespace("future.apply", quietly = TRUE)) {
  stop(
    "`future.apply` is required when `parallel = TRUE`. ",
    "Install it or use `parallel = FALSE`.",
    call. = FALSE
  )
}
```

Do the same in tuning helpers if they call `future.apply` directly and rely on
`Suggests`.

### Files to Edit

This is R-only dependency handling.

- `dev/ci_tree_models.Rmd`
  - Add a dependency check in `ci_forest()` before
    `future.apply::future_lapply()` when `parallel = TRUE`.
- `dev/model_selection.Rmd`
  - Add dependency checks for `.ci_future_lapply()` or any direct
    `future.apply::future_lapply()` calls in `tune_ci_tree()` and
    `tune_ci_forest()`.
  - Keep error messages consistent with `ci_forest()`.
- C++ files
  - No change expected.

### Tests

This is harder to test without manipulating installed packages. At minimum:

- unit-test the helper if extracted,
- or use `testthat::skip_if_installed("future.apply")` / namespace mocking only
  if the package test environment supports it.

## 6. Variable-Importance Tests Should Assert Known Values

### Problem

The current variable-importance tests mainly compare stored values to the same
internal helper that produced them.

That confirms wiring, but it does not prove the calculation is correct.

### Why We Must Solve It

Variable importance is a user-facing diagnostic. Tests should fail if:

- gains are not summed by variable,
- sorting is wrong,
- forest aggregation changes from sum to something else accidentally,
- empty/no-split trees behave incorrectly.

### Proposed Fix

Add deterministic tests with known gains.

For tree importance, build a small artificial `partynode` tree manually:

```r
node <- partykit::partynode(
  id = 1L,
  split = ...,
  kids = list(...),
  info = list(varname = "x1", gain = 2)
)
```

Then assert:

```r
expect_equal(.ci_tree_variable_importance(node), c(x1 = 2))
```

For repeated variables, assert sums:

```r
expect_equal(out[["x1"]], 3)
```

For forest importance, construct a fake `trees` list:

```r
trees <- list(
  list(fit = list(variable.importance = c(x1 = 2, x2 = 1))),
  list(fit = list(variable.importance = c(x1 = 3)))
)
```

Assert:

```r
expect_equal(.ci_forest_variable_importance(trees), c(x1 = 5, x2 = 1))
```

### Tests

Add explicit tests for:

- no-split tree returns `numeric()`,
- one split returns one named score,
- repeated variable gains are summed,
- forest sums variables across trees,
- sorting is decreasing.

### Files to Edit

This is mainly tests, unless the helper behavior changes.

- `dev/ci_tree_builder.Rmd`
  - Add direct tests for `.ci_tree_variable_importance()`.
  - If helper behavior changes, update the helper here first.
- `dev/ci_tree_models.Rmd`
  - Add direct tests for `.ci_forest_variable_importance()`.
  - Keep `ci_tree()` and `ci_forest()` storage tests, but do not rely only on
    helper-against-helper assertions.
- `dev/ci_split_search.Rmd`
  - No direct change unless importance semantics depend on additional split
    metadata.
- `dev/ci_split_search_cpp.Rmd` and `src/ci_split_search_cpp.cpp`
  - No direct change unless importance starts using C++-returned competitor or
    surrogate metadata.

## Suggested Fix Order

1. Factor split correctness, because it affects tree structure and all later
   diagnostics.
2. Weight validation, because invalid numeric input can corrupt both engines.
3. Control validation, because it protects tree-growth invariants.
4. `perturb` validation, because it improves forest API reliability.
5. Friendly `future.apply` dependency checks, because this improves user
   experience without changing model behavior.
6. Stronger variable-importance tests, because they lock in the intended simple
   rpart-style behavior.

## Files Most Likely To Change

- `dev/ci_split_search.Rmd`
- `dev/ci_split_search_cpp.Rmd`
- `src/ci_split_search_cpp.cpp`
- `dev/ci_tree_builder.Rmd`
- `dev/ci_tree_models.Rmd`
- `dev/model_selection.Rmd`

Generated `R/`, `man/`, `tests/`, and `src/RcppExports.cpp` files should be
updated through the normal fusen/Rcpp generation workflow after the source
templates and C++ implementation are corrected.
