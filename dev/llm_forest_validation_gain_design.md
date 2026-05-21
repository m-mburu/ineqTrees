# Forest-native validation gain design notes

## Motivation

`validation_gain` for a single `ci_tree` is a partition metric:

```r
root_impurity - weighted_terminal_impurity
```

The metric is natural for one tree because the fitted tree assigns validation
rows to one terminal-node partition. A `ci_forest` averages predictions from
many trees and does not have one canonical terminal-node partition after
aggregation. Scoring forest validation gain through a surrogate tree is useful
for interpretation, but it makes the primary forest tuning metric depend on
the surrogate rather than the forest's internal trees.

## Decision

Use the forest's stored member trees to define forest-native validation gain:

```r
forest_validation_gain =
  mean(ci_tree_validation_gain(tree_b, validation_data) for tree_b in forest)
```

Equivalently, because the validation root impurity is shared across trees:

```r
forest_validation_gain =
  root_impurity(validation_data) -
  mean(weighted_terminal_impurity(tree_b, validation_data))
```

This reports how much root concentration-index impurity is removed on average
by the internal tree partitions in the forest.

## API and implementation steps

1. Add a public `ci_forest_validation_gain()` helper near
   `ci_tree_validation_gain()`.
2. Add internal wrappers for forest relative validation gain so tuning can use
   the same root impurity denominator as tree tuning.
3. In `.ci_tune_forest_task()`, compute training and validation CI-gain
   diagnostics from the forest's internal trees, not from the surrogate.
4. Keep fitting and returning the surrogate tree for interpretation through
   `best_surrogate` and `ci_forest_surrogate()`.
5. Let predictive metrics (`brier`, `log_loss`, `roc_auc`) continue to use the
   averaged forest predictions directly.
6. Change forest tuning's `n_terminal` diagnostic to the mean number of
   terminal nodes across internal trees. The surrogate terminal count can be
   added later as a separate diagnostic if needed.
7. Update tests and docs so forest `validation_gain` is described as internal
   tree average validation gain, while surrogate trees are described as
   interpretation tools.

## Files to touch

- `dev/model_selection.Rmd`: validation gain helper, forest tuning logic,
  tests, and roxygen docs.
- `dev/ci_tree_models.Rmd`: inspect forest object structure and keep its
  stored tree semantics unchanged.
- `dev/ci_tree_builder.Rmd`: no expected code change; controls already provide
  tree-level split and size settings used by forest member trees.
