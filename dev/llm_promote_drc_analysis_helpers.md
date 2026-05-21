# LLM Prompt: Promote Reusable DRC Analysis Helpers Into `ineqTrees`

You are working in the `ineqTrees` package source:

```text
C:\Users\moses.mburu.FIND\Pictures\personal\ineqTrees
```

This is a **fusen package**. Do not edit generated `R/*.R`, `man/*.Rd`, or `tests/testthat/*.R` files first. Edit the relevant flat file, usually:

```text
C:\Users\moses.mburu.FIND\Pictures\personal\ineqTrees\dev\model_selection.Rmd
```

Then regenerate with `fusen::inflate()`.

Use this DRC thesis analysis file as the reference for repeated analysis helpers:

```text
C:\Users\moses.mburu.FIND\Pictures\personal\mse-thesis\analysis\drc_inequality_analysis.qmd
```

## Goal

Identify helper functions in the DRC analysis that are not truly report-specific and promote them into `ineqTrees`, so future inequality analyses do not need to rewrite the same logic. The package should expose reusable helpers for:

- selecting best tuning settings,
- collecting/widening tuning metrics,
- building report-ready train/validation tuning summary tables,
- converting selected tuning rows to controls,
- fitting forest surrogate trees,
- optionally running batched/logged forest tuning.

Keep purely thesis/report-specific helpers inside the analysis file.

## High Priority Helpers To Promote

### 1. Best Settings By Type

Reference function in DRC QMD:

```r
best_settings_by_type()
```

Current role: Selects the best tuning row for each impurity `type` using a chosen metric.

Package direction:

- Check whether current `ci_select_best()` already fully replaces this.
- If not, extend `ci_select_best()` or add a small helper that selects one best row per `type`.
- Preserve current metric direction behavior from package tuning objects.
- Avoid thesis globals like `criterion_types` and `tuning_selection_metric`.

Expected public usage:

```r
ci_select_best(tree_tuning, metric = "validation_gain")
ci_select_best(forest_tuning, metric = "validation_gain")
```

### 2. Selected Metric / Root Summary Table

Reference function:

```r
selected_metric_table()
```

Current role: Joins selected tuning settings, validation roots, mean scores, standard deviations, and percent validation gain.

Package direction:

- Prefer building on `ci_collect_metrics(x, format = "tidy")`.
- Consider adding either:

```r
ci_collect_metrics(x, format = "wide")
```

or:

```r
ci_tuning_summary(x, selected = NULL)
```

- It should handle both `tune_ci_tree()` and `tune_ci_forest()` objects.
- It should include root objective / root impurity summaries when available.
- It should expose standard errors, not only means.

Expected columns may include:

```r
type
grid_id
ntree
mtry
minsplit
minbucket
minprob
maxdepth
min_gain
min_relative_gain
mean_root_objective
mean_train_gain
std_err_train_gain
mean_train_relative_gain
std_err_train_relative_gain
mean_validation_gain
std_err_validation_gain
mean_validation_relative_gain
std_err_validation_relative_gain
```

### 3. Root Impurity Helper

Reference function:

```r
ci_root_impurity()
```

Current role: Computes root impurity for a dataset using rank, outcome, weights, and CI type.

Package status:

- Package already has internal `.ci_data_root_impurity()`.

Package direction:

- Consider exporting a public wrapper, for example:

```r
ci_root_impurity(data, rank_name, outcome_name, weights = NULL, type = "CI")
```

- Use existing internal implementation.
- Validate inputs consistently with tuning functions.

### 4. Tidy Metrics To Wide Metrics

Reference function:

```r
ci_tuning_metrics_wide()
```

Current role: Converts `ci_collect_metrics(..., format = "tidy")` into one row per grid/type with columns like `mean_validation_gain`, `std_err_validation_gain`, etc.

Package direction:

- Add `format = "wide"` to `ci_collect_metrics()`, or export a dedicated helper:

```r
ci_collect_metrics(x, format = "wide")
```

- Wide output should support both tree and forest tuning objects.
- Use package-safe `data.table`.
- Do not break existing default behavior:

```r
ci_collect_metrics(x)
ci_collect_metrics(x, summarize = FALSE)
```

### 5. Report-Ready Fit Summary Table

Reference functions:

```r
fit_summary_table()
fit_summary_kable()
```

Current role: Produces the table used in reports comparing root objective, training gain, validation gain, relative gain, and standard errors.

Package direction:

- The table-building logic is reusable; the `kable()` rendering may remain analysis-level.
- Prefer a data-returning helper, not an HTML/table-rendering helper.
- Candidate API:

```r
ci_fit_summary_table(
  x,
  selected = ci_select_best(x),
  metrics = c("train_gain", "validation_gain", "train_relative_gain", "relative_validation_gain"),
  include_percent = TRUE
)
```

- Return a `data.table`, not a rendered table.
- Let users call `knitr::kable()` themselves.

### 6. Control From Selected Tuning Row

Reference function:

```r
control_from_setting()
```

Current role: Converts a selected row from tuning output into `ci_tree_control()`, optionally including `mtry`.

Package direction:

- Add a helper such as:

```r
ci_control_from_row(row, include_mtry = TRUE)
```

- Use it internally where possible.
- Useful for refitting selected trees/forests after tuning.

### 7. Forest Prediction / Surrogate Helpers

Reference functions:

```r
forest_predict()
fit_forest_surrogate()
```

Current role: Predicts from a `ci_forest` and fits a surrogate `ci_tree` to forest predictions.

Package status:

- `predict.ci_forest()` already exists.
- Package has internal `.ci_fit_forest_surrogate()`.

Package direction:

- Avoid duplicating `forest_predict()` if `predict.ci_forest()` covers it.
- Consider exporting a public surrogate helper:

```r
ci_forest_surrogate(
  forest_fit,
  data,
  predictors = NULL,
  type = NULL,
  control = NULL,
  prediction_name = "forest_risk"
)
```

- Return a list with:

```r
fit
data
prediction_name
```

### 8. Batched / Logged Forest Tuning

Reference function:

```r
run_forest_tuning()
```

Current role: Runs `tune_ci_forest()` in batches, logs progress to a file, shifts grid IDs, and combines results.

Package direction:

- This may be valuable package-level functionality because forest tuning can be long-running.
- Consider implementing as either:

```r
tune_ci_forest_batched()
```

or as options in `control_ci_tune()` / `tune_ci_forest()`:

```r
control_ci_tune(
  log_file = "logs/forest_tuning.log",
  progress_steps = 50L,
  batch_size = NULL
)
```

- Preserve class:

```r
c("ci_forest_tuning", "ci_tree_tuning", "list")
```

- Ensure combined `summary`, `fold_results`, `predictions`, `extracts`, `fits`, and `notes` maintain global `grid_id`.
- Add tests for grid ID preservation and metric collection after batching.

## Lower Priority / Maybe Keep Analysis-Level

These may stay in the DRC QMD unless repeated across multiple analyses:

```r
sample_analysis_rows()
suggest_node_size_grid()
classify_fit_diagnostic()
```

`suggest_node_size_grid()` may become package-worthy if grid design is commonly reused.

## Keep Local To Analysis

These are report-specific and should usually remain in the QMD:

```r
weighted_mean_safe()
demo_tree_plot()
format_percent()
fit_summary_kable()
```

`demo_tree_plot()` depends on DRC-specific objects like `congo_var_labels`, `sample_weight`, `wealth`, and report formatting.

## Required Workflow

1. Read the reference analysis file:

```text
C:\Users\moses.mburu.FIND\Pictures\personal\mse-thesis\analysis\drc_inequality_analysis.qmd
```

2. Edit fusen flat file(s), primarily:

```text
C:\Users\moses.mburu.FIND\Pictures\personal\ineqTrees\dev\model_selection.Rmd
```

3. Add tests in the test chunks inside the flat file.

4. Inflate:

```r
fusen::inflate(
  flat_file = "dev/model_selection.Rmd",
  vignette_name = "Model selection",
  open_vignette = FALSE,
  check = FALSE,
  document = TRUE,
  overwrite = "yes",
  clean = "no"
)
```

5. Run focused tests:

```r
devtools::test(filter = "tune_ci_forest")
```

6. If adding helpers outside model selection, inflate the appropriate flat file and run relevant tests.

## Success Criteria

- DRC analysis no longer needs to define reusable modeling helpers.
- `ci_collect_metrics()` can produce both tidy and wide report-ready outputs.
- Tree and forest tuning objects behave consistently.
- Public helpers return `data.table` objects and avoid report-specific rendering.
- Existing package behavior remains backward compatible.
