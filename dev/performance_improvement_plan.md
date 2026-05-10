# Performance Improvement Plan for Greedy CI Trees

This note outlines a step-by-step plan for improving the speed of the greedy
concentration-index tree and forest implementation. The current implementation is
methodologically clean and readable, but several parts of the split-search path
repeat expensive work. The priority should be to reduce repeated concentration
index calculations, avoid unnecessary allocation inside tight loops, and avoid
rebuilding model frames repeatedly in the forest.

The guiding principle is:

> Optimize the hot path first: node-level split search, concentration-index
> scoring, and repeated forest fitting. Do not start by micro-optimizing the
> recursive tree builder itself.

## Data Structure Design Rule

Use `data.table` deliberately, not as a blanket replacement for every
`data.frame`. A `data.table` also inherits from `data.frame`, which makes it a
good internal tool, but it also has reference semantics. Internal code should
therefore avoid modifying user-supplied data by reference unless it has first
made an explicit copy.

The package should follow this rule:

```text
public API: data.frame compatible
internal grouped/subset work: data.table
numeric hot loops: base vectors
partykit storage: data.frame/model.frame compatible
```

Practical implications:

- User-facing functions such as `ctree_ci()` and `cf_ci()` should continue to
  accept ordinary `data.frame`, `data.table`, and compatible tabular objects.
- Internal factor summaries and forest data handling can use `data.table`,
  especially when grouping, sampling, or repeatedly subsetting rows.
- Numeric split search should use base vectors and cumulative sums rather than
  `data.table`, because the innermost loop needs minimal overhead.
- Objects stored in `partykit::party()` should remain compatible with
  `stats::model.frame()` and ordinary `data.frame` behavior.
- When internal code may modify columns, use
  `data.table::copy(data.table::as.data.table(data))` to avoid changing the
  user's original data by reference.

## Profiling-Based Priority Ranking

The first profiling pass gives a clearer implementation order than the original
intuition-only plan. The strongest evidence is:

- `best_numeric_split()` is the clearest standalone bottleneck. On the current
  benchmark it takes roughly 19-21 seconds, while `best_factor_split()` takes
  about 0.15 seconds.
- The `Rprof()` output for `best_numeric_split()` shows most total time flowing
  through `ci_fun`, with repeated calls to `rank_wt()`, `stats::cov.wt()`,
  temporary `data.frame` construction, matrix conversion, and `order()`.
- `ctree_ci()` and `cf_ci()` inherit this cost because every node split calls
  global split search.
- The `lobstr` memory profile shows larger retained objects for whole fitted
  tree and forest objects, especially `cf_ci()`, but memory is not the first
  bottleneck to attack. CPU time inside repeated CI scoring is the more urgent
  issue.

Given that evidence, the first improvements should be ranked as follows:

| rank | improvement | why first | expected impact |
|---:|---|---|---|
| 1 | Cache parent CI in split scoring | Low-risk change; removes a repeated `ci_fun(y, wt)` call for every candidate split | Moderate speedup, especially numeric split search |
| 2 | Rewrite numeric split search with cumulative weights | Directly targets the slowest benchmark and removes repeated logical allocation and weight summation | Moderate to high speedup for numeric variables |
| 3 | Add a fast internal CI scorer | Profiling shows `rank_wt()`, `cov.wt()`, and temporary `data.frame` work dominate `ci_fun` | High speedup across trees, forests, and tuning |
| 4 | Optimize factor split summaries | Factor split is currently not the main bottleneck, but will matter for high-cardinality predictors and forests | Moderate speedup in factor-heavy models |
| 5 | Add a forest-specific fast path | Forest runtime compounds tree-fitting costs, but should be done after split search is faster | High speedup for `cf_ci()` and `tune_cf_ci()` |
| 6 | Refactor recursive builder to pass row indices | Useful, but profiling does not show it as the first-order bottleneck | Moderate memory and runtime improvement |

This means the next implementation step should be **parent-CI caching**, not a
large refactor. It is the safest first optimization and gives us a clean
before/after benchmark before touching the CI formula internals.

Suggested immediate sequence:

1. Add `.weighted_ci_gain_from_parent()` in `dev/ci_ranking.Rmd`.
2. Compute `ci_parent` once inside `best_numeric_split()` and
   `best_factor_split()`.
3. Re-run `Rscript dev/run_performance_benchmarks.R`.
4. Compare `dev/performance_baseline_results.csv` and
   `dev/profile_top_by_self.csv`.
5. Only then move to cumulative numeric split search.

Status after first implementation:

- `.weighted_ci_gain_from_parent()` has been added as an internal helper.
- `weighted_ci_gain()` remains the exported user-facing function.
- `best_numeric_split()` and `best_factor_split()` now compute parent CI once
  per split-search call and reuse it for each candidate split.
- Focused tests for `ci_ranking` and `ci_split_search` pass.
- With the benchmark script loading the current working tree through
  `pkgload::load_all()`, the post-change timing is approximately:
  `best_numeric_split()` median 9.86 seconds, `ctree_ci()` median 1.17 seconds,
  and `cf_ci(ntree = 20)` 6.64 seconds on the development benchmark.

The next implementation step should be cumulative-weight numeric split search.

Status after cumulative-weight admissibility checks:

- `best_numeric_split()` now uses cumulative row weights for `minbucket` and
  `minprob` checks.
- `best_factor_split()` now uses cumulative ordered-level weights for the same
  admissibility checks.
- The logical `left` vector is created only after a candidate split passes the
  child-size and child-proportion checks.
- Focused split-search tests pass.
- Post-change timing is approximately: `best_numeric_split()` median 8.78
  seconds, `best_factor_split()` median 0.09 seconds, `ctree_ci()` median 1.00
  seconds, and `cf_ci(ntree = 20)` 6.28 seconds on the development benchmark.

The next implementation step should be a faster internal CI scorer, because the
profile still shows `ci_fun`, `rank_wt()`, `stats::cov.wt()`, and temporary
`data.frame` or matrix conversion work inside the numeric split hot path.

Status after fast internal CI scorer:

- `.ci_fast_score()` has been added in `dev/ci_ranking.Rmd`.
- `ci_factory()` keeps the same public interface, but now delegates scoring to
  `.ci_fast_score()`.
- The new scorer avoids temporary `data.frame` construction and avoids
  `stats::cov.wt()` by computing the same unbiased weighted covariance directly
  with normalized weights.
- Tests compare `ci_factory()` against the previous `cov.wt()` reference
  calculation for `CI`, `CIg`, and `CIc`.
- Focused tests for `ci_ranking` and `ci_split_search` pass.
- Post-change timing is approximately: `best_numeric_split()` median 3.94
  seconds, `best_factor_split()` median 0.05 seconds, `ctree_ci()` median 0.25
  seconds, and `cf_ci(ntree = 20)` 1.69 seconds on the development benchmark.

The next implementation step should be factor split optimization only if the
use case is factor-heavy. For the current benchmark, the larger remaining
package-level gain is likely the forest-specific fast path, because forest
runtime compounds repeated tree setup and prediction work.

Status after forest-specific prepared-frame path:

- `cf_ci()` now prepares the model frame, response matrix, predictor ids, and
  normalized controls once per forest fit.
- Each tree is still stored as a real `ci_tree` object inheriting from
  `partykit::party`; the forest no longer calls the public `ctree_ci()` wrapper
  for every perturbed sample.
- The per-tree fitting path now calls the same internal prepared-frame builder
  used by `ctree_ci()`, avoiding repeated model-frame construction and repeated
  formula/response setup.
- Tests assert that every stored forest member inherits from both `ci_tree` and
  `party`.
- Post-change timing is approximately: `best_numeric_split()` median 3.81
  seconds, `best_factor_split()` median 0.06 seconds, `ctree_ci()` median 0.26
  seconds, and `cf_ci(ntree = 20)` 1.45 seconds on the development benchmark.

The profile now shows the remaining forest time mostly flowing through
`best_global_ci_split()`, `best_split_for_one_variable()`,
`best_factor_split()`, `order()`, `%in%`, and `.ci_fast_score()`. That suggests
the next meaningful forest improvement should target factor split work and
prediction aggregation, not another wrapper-level refactor.

## 1. Establish a baseline benchmark

Before changing code, add a small benchmark script or development chunk that
measures current runtime for:

- One `ctree_ci()` fit on a representative dataset.
- One `cf_ci()` fit with a small forest, for example `ntree = 20`.
- One `best_numeric_split()` call on a large numeric predictor.
- One `best_factor_split()` call on a high-cardinality factor such as `reg`.

Suggested files:

- `dev/ci_split_search.Rmd`
- `dev/ci_tree_models.Rmd`
- optionally `dev/performance_benchmarks.Rmd`

Expected improvement:

- This does not speed up the package directly, but it gives a reference point so
  later changes can be judged by evidence rather than intuition.
- This step is now complete. The current benchmark confirms that
  `best_numeric_split()` is much more expensive than `best_factor_split()` on
  the current development benchmark.

Verification:

- Record elapsed time before and after each optimization.
- Confirm that selected splits, gains, terminal nodes, and predictions remain
  unchanged where deterministic behavior is expected.

## 2. Avoid recomputing parent CI for every candidate split

Current hotspot:

`weighted_ci_gain()` computes:

```r
ci_parent <- ci_fun(y, wt)
ci_left   <- ci_fun(y[left,  , drop = FALSE], wt[left])
ci_right  <- ci_fun(y[!left, , drop = FALSE], wt[!left])
```

Inside a node, `ci_parent` is constant. In numeric split search, it is currently
recomputed for every candidate cutpoint. In factor split search, it is also
recomputed for every candidate level partition.

Suggested implementation:

1. Add an internal helper such as `.weighted_ci_gain_from_parent()`.
2. The helper should accept `ci_parent` as an argument.
3. Compute `ci_parent <- ci_fun(y, wt)` once inside `best_numeric_split()` and
   once inside `best_factor_split()`.
4. Use that cached parent CI when scoring candidates.
5. Keep `weighted_ci_gain()` as the exported simple interface for users and
   tests.

Suggested files:

- `dev/ci_ranking.Rmd`
- `dev/ci_split_search.Rmd`

Expected improvement:

- Moderate speedup in both numeric and factor split search.
- Larger gain when a node has many candidate cutpoints or many factor levels.

Risk:

- Low. The formula is unchanged; only repeated parent computation is removed.

Verification:

- Existing `weighted_ci_gain()` tests should still pass.
- Add a test that cached-parent gain equals `weighted_ci_gain()` for several
  candidate splits.

## 3. Rewrite numeric split search using cumulative weights

Current hotspot:

`best_numeric_split()` creates a full logical vector for every candidate:

```r
left <- seq_along(x) <= pos
wl <- sum(wt[left], na.rm = TRUE)
wr <- sum(wt[!left], na.rm = TRUE)
```

This repeatedly allocates logical vectors and recomputes sums from scratch.

Suggested implementation:

1. After sorting `x`, compute cumulative weights:

```r
cum_wt <- cumsum(wt)
total_wt <- sum(wt)
```

2. For a candidate position `pos`, compute:

```r
wl <- cum_wt[pos]
wr <- total_wt - wl
```

3. Use these values for `minbucket` and `minprob` checks.
4. Avoid creating `left` until a candidate is admissible and actually needs CI
   scoring.
5. Longer-term: consider a faster CI scorer that can compute left/right CI from
   sorted slices using indices, but keep that as a later optimization.

Suggested files:

- `dev/ci_split_search.Rmd`

Expected improvement:

- Moderate to high speedup for numeric predictors with many unique values.
- Lower memory allocation in large nodes.

Risk:

- Low to moderate. The split search order and selected cutpoint should remain
  the same, but index handling needs careful tests.

Verification:

- Existing numeric split tests should pass.
- Add tests comparing old and new gain values on tied values, weighted data, and
  non-uniform weights.

## 4. Add a faster internal CI scorer

Current hotspot:

`ci_factory()` currently calls `rank_wt()` and then uses `stats::cov.wt()` with a
temporary `data.frame`:

```r
cov12 <- stats::cov.wt(
  x = as.matrix(data.frame(y1 = y[, 1], y2 = y[, 2])),
  wt = wt
)$cov[1, 2]
```

This is clear but expensive inside repeated split scoring.

Suggested implementation:

1. Keep `ci_factory()` as the public and readable interface.
2. Add an internal low-allocation scorer, for example `.ci_fast_score()`.
3. Compute weighted ranks directly using vectors.
4. Compute weighted means and weighted covariance directly:

```r
mu_r <- sum(w * r) / sum(w)
mu_y <- sum(w * y) / sum(w)
cov_ry <- sum(w * (r - mu_r) * (y - mu_y)) / sum(w)
```

5. Return the same absolute CI, CIg, and CIc values as `ci_factory()`.
6. Use this fast scorer internally in split search while preserving exported
   behavior.

Suggested files:

- `dev/ci_ranking.Rmd`
- `dev/ci_split_search.Rmd`
- possibly `dev/ci_tree_builder.Rmd` if node summaries should also use it

Expected improvement:

- High impact, because CI scoring is called many times per node.
- Especially important for forests and cross-validation.

Risk:

- Moderate. The exact convention of `stats::cov.wt()` must be matched or
  intentionally documented. Tests should verify numerical equivalence.

Verification:

- Compare `.ci_fast_score()` against `ci_factory()` for `CI`, `CIg`, and `CIc`.
- Include tests with missing data, zero weights, one valid row, constant outcome,
  and non-uniform weights.

## 5. Use `data.table` for factor split summaries

Current hotspot:

`best_factor_split()` repeatedly converts the predictor to character and scans
the vector for each level:

```r
idx <- as.character(x) == lv
stats::weighted.mean(y[idx, 2], wt[idx])
```

For high-cardinality factors such as region, this is expensive.

Suggested implementation:

1. Use integer factor codes where possible.
2. For level summaries, use one grouped operation.
3. A `data.table` version could compute level weights and weighted outcome
   means in one pass:

```r
DT[, .(
  w = sum(wt),
  ybar = sum(wt * outcome) / sum(wt)
), by = level]
```

4. Order levels by `ybar`, then search cumulative level splits.
5. Avoid repeated `%in%` checks where possible by using integer level codes.

Suggested files:

- `dev/ci_split_search.Rmd`
- `DESCRIPTION` if `data.table` is not already imported
- `NAMESPACE` through roxygen imports if needed

Expected improvement:

- Moderate improvement for factor variables.
- High improvement for high-cardinality factors repeatedly searched across many
  nodes or trees.

Risk:

- Moderate. Factor split behavior must preserve unused levels and the
  `partykit::partysplit()` level mapping.

Verification:

- Existing factor split tests should pass.
- Add tests with unused levels, high-cardinality factors, missing values, and
  non-uniform weights.

## 6. Avoid data-frame copying at every recursive node

Current hotspot:

`.build_ci_tree()` currently creates node-local copies:

```r
y_node <- y[obs, , drop = FALSE]
wt_node <- wt[obs]
data_node <- data[obs, , drop = FALSE]
```

This is convenient, but repeated data-frame subsetting can be costly.

Suggested implementation:

1. Keep the public behavior of `.build_ci_tree()` unchanged at first.
2. Add internal row-index-aware split search helpers.
3. Pass the full predictor data and the current row indices into split search.
4. Subset only the single predictor vector being evaluated, not the full data
   frame.
5. Keep terminal-node fitted values based on original row indices.

Suggested files:

- `dev/ci_tree_builder.Rmd`
- `dev/ci_split_search.Rmd`

Expected improvement:

- Moderate improvement for wide data or deep trees.
- Lower memory pressure during recursive fitting.

Risk:

- Moderate. It changes the internal interface between builder and split search.

Verification:

- Compare full fitted terminal nodes before and after on deterministic examples.
- Check predictions, node ids, node summaries, and plots.

## 7. Add a forest-specific fast fitting path

Current hotspot:

`cf_ci()` calls `ctree_ci()` for every tree. Each call rebuilds:

- the model frame,
- terms object,
- factor conversion,
- response extraction,
- party object setup.

For many trees, this repeated setup can dominate runtime.

Suggested implementation:

1. In `cf_ci()`, build the model frame once.
2. Extract response, predictors, weights, terms, and factor columns once.
3. For each tree, sample row indices.
4. Call `.build_ci_tree()` directly on the sampled rows or on a lightweight
   internal tree-fitting helper.
5. Wrap each resulting tree in a `partykit::party()` object only after the node
   has been built.
6. Keep the public `ctree_ci()` unchanged for single-tree users.

Suggested files:

- `dev/ci_tree_models.Rmd`
- possibly `dev/ci_tree_builder.Rmd`

Expected improvement:

- High impact for `cf_ci()` and `tune_cf_ci()`.
- The improvement grows with `ntree`, number of folds, and grid size.

Risk:

- Moderate to high. Forest internals must preserve prediction behavior and
  stored tree structure.

Verification:

- Existing `cf_ci()` tests should pass.
- Add a test that forest predictions have the same length and valid values.
- Add a small deterministic seed test if possible, while allowing that sampling
  randomness may change if the implementation order changes.

## 8. Use `data.table` selectively around the hot loop

Good places for `data.table`:

- Forest-level preprocessing.
- Repeated row subsetting for forests.
- Factor-level grouped summaries.
- Cross-validation and tuning result aggregation.

Less useful places for `data.table`:

- The innermost numeric split loop, where base vector operations and cumulative
  sums should be faster.
- The CI calculation itself, where a direct vectorized scorer is more important.
- Recursive tree building, unless it is paired with row-index-aware interfaces.

Expected improvement:

- Moderate improvement when used for grouped factor work and forest data
  handling.
- Small or no improvement if used only as a drop-in replacement for every
  `data.frame`.

Risk:

- Low to moderate. The main risk is adding dependency complexity without
  improving the true bottleneck.

Verification:

- Benchmark `best_factor_split()` before and after.
- Benchmark `cf_ci()` before and after.
- Avoid adding `data.table` to the tight numeric loop unless benchmarks support
  it.

## 9. Recommended implementation order

Implement changes in this updated order:

1. Keep the current benchmark and profiling harness up to date.
2. Cache parent CI in split gain calculations.
3. Rewrite numeric split search using cumulative weights.
4. Add and test a fast internal CI scorer.
5. Optimize factor split summaries, using `data.table` if benchmarks justify it.
6. Add a forest-specific fast path that avoids repeated `ctree_ci()` setup.
7. Refactor tree building to pass row indices instead of copying node data.

This order starts with low-risk improvements and builds toward deeper internal
refactors. It also keeps the public API stable while improving the internal
engine.

## 10. Expected overall impact

The likely speed gains are:

- Small to moderate for shallow single trees with few predictors.
- Moderate to high for numeric-heavy trees with many unique cutpoints.
- High for forests, because the same tree-building cost is repeated many times.
- Very high for cross-validation and tuning, because each grid-fold combination
  repeats the full fitting procedure.

The most important conceptual point is that the performance issue is not the
greedy CI objective itself. It is the repeated implementation work around that
objective: repeated parent CI computation, repeated ranking and covariance
calculation, repeated logical vector allocation, repeated factor scans, and
repeated model-frame construction.
