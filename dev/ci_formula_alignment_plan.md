# CI Formula Alignment Plan

## Goal

Align the package implementation with the thesis methodology and the `rineq`
direct concentration-index definition used for interpretation:

```r
CI = 2 * cov_w(Y, R) / mu_Y
```

For tree split search and validation gain, use the population-style weighted
covariance:

```r
cov_w(Y, R) = sum(p_i * (Y_i - mu_Y) * (R_i - mu_R))
```

Do not use the finite-sample correction:

```r
cov_w(...) / (1 - sum(p_i^2))
```

That correction changes across candidate child nodes and can therefore affect
which splits are selected.

## Files To Edit

### `dev/ci_ranking.Rmd`

This is the main fusen source for rank and node scoring helpers.

Edits:

- Find the helper that computes CI, CIg, and CIc scores, especially
  `.ci_fast_score()` or equivalent.
- Remove the covariance denominator correction based on `1 - sum(w^2)`.
- Compute weighted covariance directly from normalized weights:

```r
cov_yr <- sum(w * (outcome - mu_y) * (rank - mu_r))
ci <- 2 * cov_yr / mu_y
```

- Keep the existing zero/near-zero `mu_y` guard.
- Keep absolute-value behavior if the tree objective is defined as impurity
  magnitude.
- Confirm:
  - `CIg = 2 * cov_yr`
  - `CIc = 4 * CIg / (b - a)`
  - for binary outcomes, `b - a = 1`, so `CIc = 4 * CIg`

### `dev/ci_split_search_cpp.Rmd`

This is the fusen source for the Rcpp split search implementation.

Edits:

- Find the C++ scoring code that computes child weighted covariance.
- Remove the child-specific correction:

```cpp
cov12[child] /= cov_denom[child];
```

where `cov_denom[child]` is based on:

```cpp
1.0 - sum_wt2[child]
```

- Ensure the C++ score uses the same direct population covariance as the R
  helper.
- Keep consistency between R fallback scoring and Rcpp scoring.

### `dev/ci_split_search.Rmd`

This is the fusen source for split-search orchestration and fallback behavior.

Edits:

- Check that the split search calls the same score factory/helper after the
  covariance correction is removed.
- If there are separate R-only candidate split paths, make sure they also use
  the direct covariance definition.
- Add or update tests comparing R and C++ split scoring on a small weighted
  example.

### `dev/model_selection.Rmd`

This is the fusen source for tuning, validation gain, and best-parameter
selection.

Edits:

- Keep best-parameter selection per `type`; CI, CIg, CIc, and L are on different
  scales.
- Keep `validation_gain` as:

```r
root_impurity - weighted_terminal_impurity
```

- Add a relative validation metric if useful:

```r
relative_validation_gain = validation_gain / abs(root_impurity)
```

- Use relative gain only for within-type interpretability unless explicitly
  normalized per metric.
- Ensure validation scoring uses the same corrected CI scorer as split search.

### `dev/performance_benchmarks.Rmd`

This is useful after changing R and C++ scoring.

Edits:

- Add a benchmark case checking that direct covariance scoring does not regress
  performance badly.
- Include one small weighted example and one realistic Congo-like example.

## Generated Files Not To Edit Directly

Do not manually patch these first:

- `R/rank_wt.R`
- `R/ci_split_search.R`
- `R/tune_ci_tree.R`
- `src/ci_split_search_cpp.cpp`
- `src/RcppExports.cpp`
- `R/RcppExports.R`

These should be regenerated from the fusen Rmd files after the templates are
patched.

## Validation Checks

### Mathematical Check

Use a small weighted example and compare package scoring to a hand-computed
direct CI:

```r
p <- weights / sum(weights)
mu_y <- sum(p * y)
mu_r <- sum(p * r)
cov_yr <- sum(p * (y - mu_y) * (r - mu_r))
ci <- 2 * cov_yr / mu_y
```

Expected:

- Package CI equals `abs(ci)` if impurity uses absolute CI.
- Package CIg equals `abs(2 * cov_yr)`.
- Package CIc equals `abs(4 * 2 * cov_yr)` for binary outcomes.

### R Versus C++ Check

Run the same candidate split through:

- R fallback split search
- Rcpp split search

Expected:

- Same best split variable.
- Same split point or factor partition.
- Same gain within numerical tolerance.

### Tuning Check

Run a small tuning grid with at least:

```r
type = c("CI", "CIg", "CIc", "L")
```

Expected:

- `best_params` returns one row per type.
- Validation gain is recomputed under the direct CI definition.
- `CIg` and `CIc` rankings should be identical when the outcome range is fixed
  and binary, because `CIc` is a positive constant multiple of `CIg`.

## Suggested Order

1. Patch `dev/ci_ranking.Rmd`.
2. Patch `dev/ci_split_search_cpp.Rmd`.
3. Patch any fallback scoring in `dev/ci_split_search.Rmd`.
4. Patch validation/tuning metrics in `dev/model_selection.Rmd`.
5. Regenerate the package files from fusen.
6. Run R versus C++ scoring tests.
7. Run a small Congo tuning smoke test.
8. Re-render the demo only after the package tests pass.

## Notes

The main methodological choice is to treat the concentration index as a
descriptive population quantity inside each node. That is the cleanest objective
for a tree because every candidate split is judged on the same direct impurity
definition, without a node-size-dependent covariance correction affecting the
search.
