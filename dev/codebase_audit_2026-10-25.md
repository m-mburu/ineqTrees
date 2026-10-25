# ineqTrees code audit

Audited on 25 October 2026 against commit `3c23406`. The working tree was
clean before this audit. This delivery adds documentation only.

The package passes its existing checks, but targeted probes expose defects
in resampling, OOB prediction and SHAP decomposition. Fix these before
undertaking general formatting or performance work.

## Basis and scope

The review used the local Codex guidance on
[coding](/home/mburu/.codex/guidance/coding-best-practices.md),
[software engineering](/home/mburu/.codex/guidance/software-engineering.md),
[R style](/home/mburu/.codex/guidance/r-style.md),
[mathematics](/home/mburu/.codex/guidance/mathematics.md),
[writing voice](/home/mburu/.codex/guidance/writing-voice.md) and
[natural writing](/home/mburu/.codex/guidance/write_like_human.md).

Inspection covered ranking and scoring, R/C++ split search, tree and forest
fitting, prediction, tuning, SHAP input preparation, tests, fusen mappings,
package metadata and CI configuration. It was targeted to these paths,
rather than a line-by-line review of every tutorial and plotting helper.
It did not establish the scientific validity of every estimator or execute
GitHub Actions.

Verification used temporary package copies and `/usr/bin/Rscript`, with
R 4.5.3:

| Check | Observed result | Limit |
| --- | --- | --- |
| `devtools::test()` | 148 blocks, 461 passed expectations; no failures, errors, warnings or skips | Existing tests only |
| Source build and `R CMD check` | `Status: OK` | Manuals and vignettes excluded |
| Targeted probes | Findings F1-F7 below reproduced | Small synthetic examples |
| Fusen configuration inspection | Two mapped paths absent | Regeneration was not executed |

The package check used a source archive of the audited commit:

```sh
R CMD build --no-build-vignettes --no-manual source
_R_CHECK_FORCE_SUGGESTS_=false R CMD check \
  --no-manual --no-build-vignettes --ignore-vignettes \
  ineqTrees_0.0.0.1.tar.gz
```

`fusen` is unavailable in the inspected R environment. Installed tooling
was sufficient to compile the C++ engine, run tests and check the package.

## Findings

P1 means repair first because ordinary inputs can silently change an
analysis. P2 means a narrower correctness or maintenance issue. P3 means
focused code-health work after correctness is established.

### F1. P1: stratified folds can omit rows or omit requested folds

Evidence: [ci_cv_folds()](../R/predict_ci_tree_terminal_mean.R#L252),
especially lines 289-300. Edit its source in
[`dev/model_selection.Rmd`](model_selection.Rmd#L322).

With `n = 6`, `v = 2`, `seed = 1` and strata
`c("a", "a", "b", "b", NA, NA)`, the result is `1 2 1 2 0 0`.
Missing strata remain unassigned because comparing a factor level to `NA`
does not select its rows. The resampling helper can then treat zero as an
additional fold.

With six singleton strata and `v = 3`, the result is `1 1 1 0 1 0`.
`sample(idx, length(idx))` samples from `1:idx` when `idx` is a single
positive integer. It can overwrite another row's assignment.

With three strata of size two and `v = 3`, only folds 1 and 2 appear.
Every stratum restarts allocation at fold 1. The requested number of folds
is therefore not guaranteed even when `n >= v`.

### F2. P1: OOB prediction silently includes in-sample predictions

Evidence: [predict.ci_forest()](../R/ci_forest.R#L425), especially lines
478-494. Source: [`dev/ci_tree_models.Rmd`](ci_tree_models.Rmd#L1390).

A two-tree forest fitted with `replace = FALSE`, `fraction = 1` has zero
OOB trees for every row. `predict(forest, OOB = TRUE)` nevertheless returns
finite predictions. Rows without OOB predictions are filled with the mean
of all tree predictions. Those values cannot serve as OOB estimates.

The method also accepts unrelated or reordered `newdata` whenever its row
count matches the training data. It applies the training in-bag mask by
position, without establishing row identity. For `type = "node"`, it
returns before processing `OOB` at all.

### F3. P1: SHAP feature names can overwrite analytical inputs

Evidence: [shap_conc_decomp()](../R/shap_conc_decomp.R#L183), especially
lines 183-216. Source:
[`dev/shap_decomposition.Rmd`](shap_decomposition.Rmd#L475).

The function appends `rank__`, `weights__` and `prediction__` to the SHAP
table without checking existing feature names. These assignments can
replace real attributions. Later calculations still treat the replaced
columns as SHAP features.

For a feature named `rank__` with values `c(0.1, 0.2, -0.1)`, ranks `1:3`
and baseline `0.5`, mean prediction becomes `2.5`. The correct mean from
the supplied attributions is approximately `0.566667`. The reported
additivity gap is still zero, so this diagnostic does not expose the error.

### F4. P1: DALEX conversion loses observation alignment

Evidence: [.dalex_shap_to_wide()](../R/assert_data_table_available.R#L173).
Source: [`dev/shap_decomposition.Rmd`](shap_decomposition.Rmd#L302).

The converter sorts by observation ID, drops that ID and returns only the
features. `rank`, `weights` and `prediction` are supplied separately and
are not reordered or joined by ID. The interface does not establish how
these vectors align with the sorted rows.

For IDs `c(30, 10, 20)` and feature values `c(0.1, 0.2, -0.1)`, the long
and wide calls below give signed indices of `-0.03921569` and
`-0.07843137`, respectively, using the same observation order for ranks.
This is an observation-matching defect, not a numerical tolerance issue.

### F5. P1: invalid numeric inputs can produce plausible statistics

Evidence: [SHAP filtering](../R/shap_conc_decomp.R#L144),
[SHAP table validation](../R/assert_data_table_available.R#L227),
[scoring](../R/rank_wt_retained.R#L28) and
[log loss](../R/predict_ci_tree_terminal_mean.R#L1514).
Sources: `dev/shap_decomposition.Rmd`, `dev/ci_ranking.Rmd` and
`dev/model_selection.Rmd`.

Reproduced behaviours:

- SHAP weights `c(1, -1, 1)` silently remove the negative-weight row,
  reducing the analysis from three observations to two.
- An infinite SHAP attribution passes table validation and later produces
  the generic error `missing value where TRUE/FALSE needed`.
- `ci_factory("CI")` returns zero for the infinite weight or outcome
  examples below. Invalid data can therefore resemble zero inequality.
- `ci_log_loss(c(0, 1), c(-Inf, Inf))` returns approximately `0.000001`,
  because clipping converts infinities to apparently excellent probabilities.

Tree and forest entry points already reject non-finite weights. The issue
is inconsistent validation across public entry points. Preserve intentional
handling of missing data, zero weights and degenerate nodes while making
invalid numeric input explicit.

### F6. P2: tuning can select incomplete or unscored candidates

Evidence: [summary and selection helpers](../R/predict_ci_tree_terminal_mean.R#L999).
Source: [`dev/model_selection.Rmd`](model_selection.Rmd#L1086).

Scores are averaged with `na.rm = TRUE`. Selection ranks the mean before
fold completion and does not exclude failed candidates. A synthetic summary
with mean gain `0.9` from one completed fold and four failed folds beats
mean gain `0.5` from five completed folds. A type with only an `NA` score
still receives a row in `best_params`. Refit separately filters finite
scores, so an all-missing row does not imply a successful refit.

These behaviours were reproduced directly through the selection helper.
An end-to-end partial-failure tuning run was not executed. The package
needs an explicit eligibility policy, plus tests of its public collectors
and refitting behaviour. Scoring failures also need separate accounting:
`folds_failed` currently counts fitting errors only.

### F7. P2: numeric midpoint overflow breaks split routing

Evidence: [R cutpoint](../R/best_numeric_split.R#L432) and
[C++ cutpoint](../src/ci_split_search_cpp.cpp#L373).
Edit `dev/ci_split_search.Rmd` and `src/ci_split_search_cpp.cpp`.

Both engines calculate `(lower + upper) / 2`. With predictors
`c(1e308, 1.1e308, 1.2e308, 1.3e308)` and outcomes `c(0, 0, 1, 1)`,
both return an infinite cutpoint. Candidate membership is
`TRUE TRUE FALSE FALSE`, while `x <= cutpoint` is true for every row.
Agreement between engines does not establish correctness when both share
the same defect. This is an extreme-value boundary case.

### F8. P2: generation metadata and repository hygiene need repair

Static evidence:

- [`dev/config_fusen.yaml`](config_fusen.yaml) references absent files
  `R/rank_wt.R` and `tests/testthat/test-rank_wt.R`. Their functions and
  tests may have been consolidated into other generated files. Reconcile
  ownership before regenerating anything.
- [`dev/ci_split_search_cpp.Rmd`](ci_split_search_cpp.Rmd#L36) says
  production builders still use R search. The builder selects C++ by
  default through `ci_tree_control()`. Related wrapper prose still calls
  that path experimental.
- Git tracks `src/RcppExports.o`, `src/ci_split_search_cpp.o` and
  `src/ineqTrees.dll`. These are compiled artifacts, not portable sources.
  `.gitignore` has no corresponding object/shared-library rules. The
  successful source build does not remove the repository hygiene problem.

### F9. P3: improve readability and clarify the public API selectively

[`R/predict_ci_tree_terminal_mean.R`](../R/predict_ci_tree_terminal_mean.R)
contains 2,592 lines spanning grids, resampling, scoring, surrogate models,
tuning and collectors. Its fusen owner is `dev/model_selection.Rmd`.
There are also long calls and compact expressions in tuning code.

Apply the 80-character R limit, spacing between stages and descriptive
intermediate names to code touched by the repairs. Consider separating
fusen chunks by responsibility only where that makes maintenance clearer.
File size alone does not justify a rewrite.

[`NAMESPACE`](../NAMESPACE#L13) exports ten dot-prefixed helpers, including
assertions and `.build_ci_tree`. Review whether these are supported public
contracts. Removing an existing export requires a compatibility assessment.

## Compact reproductions

Run from the repository root after loading the development package. These
are audit probes of the current behaviour, not tests of desired behaviour.

```r
pkgload::load_all(".", quiet = TRUE)

# F1: zeros and missing folds
ci_cv_folds(6, 2, c("a", "a", "b", "b", NA, NA), seed = 1)
ci_cv_folds(6, 3, letters[1:6], seed = 1)
ci_cv_folds(6, 3, rep(letters[1:3], each = 2), seed = 1)

# F2: every row is in every tree
toy <- data.frame(rank = 1:8, outcome = rep(0:1, 4), predictor = 1:8)
forest <- ci_forest(
  cbind(rank, outcome) ~ predictor,
  data = toy,
  rank_name = "rank",
  outcome_name = "outcome",
  ntree = 2,
  perturb = list(replace = FALSE, fraction = 1),
  control = ci_tree_control(maxdepth = 0)
)
rowSums(forest$inbag == 0)
predict(forest, OOB = TRUE)

# F3-F5: attribution identity, row order and numeric validation
shap <- data.frame(feature_a = c(0.1, 0.2, -0.1))
shap_conc_decomp(
  data.frame(rank__ = shap$feature_a), rank = 1:3, baseline = 0.5
)$diagnostics

long_shap <- data.frame(
  id = c(30, 10, 20),
  variable = "feature_a",
  contribution = shap$feature_a
)
shap_conc_decomp(shap, rank = 1:3, baseline = 0.5)$diagnostics
shap_conc_decomp(
  long_shap, rank = 1:3, baseline = 0.5, from_dalex = TRUE
)$diagnostics
shap_conc_decomp(
  shap, rank = 1:3, baseline = 0.5, weights = c(1, -1, 1)
)$diagnostics
ci_factory("CI")(cbind(1:3, c(0, 1, 1)), c(1, Inf, 1))
ci_factory("CI")(cbind(1:3, c(0, Inf, 1)), rep(1, 3))
ci_log_loss(c(0, 1), c(-Inf, Inf))

# F7: scored membership disagrees with the stored threshold
candidate <- best_numeric_split(
  x = c(1e308, 1.1e308, 1.2e308, 1.3e308),
  y = cbind(1:4, c(0, 0, 1, 1)),
  wt = rep(1, 4),
  varid = 1,
  ctrl = ci_tree_control(minsplit = 1, minbucket = 1, minprob = 0),
  ci_fun = ci_factory("CI"),
  return = "candidate"
)
candidate[c("cutpoint", "left")]
```

## What already works

The package has R/C++ parity tests, hand-computed covariance checks,
weighted tie handling, exhaustive small-factor partition search with a
candidate-count guard, validated tree/forest weights and compatibility
aliases. Keep these protections. Existing planning notes describe some
issues that are already repaired; recheck each proposal against current
code before acting on it.

Use the accompanying
[LLM improvement instructions](llm_codebase_improvement_instructions.md)
to turn these findings into bounded changes and regression checks.
