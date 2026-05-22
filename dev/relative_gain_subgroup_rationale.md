# Relative Gain Denominator For Subgroup Splitting

For greedy subgroup discovery, `min_relative_gain` should be computed against
the impurity of the node currently being split:

```r
relative_gain(t, j, s) = gain(t, j, s) / abs(parent_impurity(t))
```

Statistically, each node is a conditional subgroup problem. At node `t`, the
candidate variable and split `(j, s)` should be judged by how much of the
remaining inequality inside that subgroup it removes. Using the parent-node
impurity therefore asks:

> Given the subgroup we are currently in, does this split explain a meaningful
> share of the subgroup's remaining inequality?

At the root, the parent node is the full sample, so the same rule is naturally
relative to the overall impurity. Deeper in the tree, the denominator changes
with the subgroup, which keeps the stopping rule aligned with the local
subgroup-discovery goal.

Using root impurity instead asks a different question: whether a split matters
relative to the entire population. That is useful for global reporting and model
selection diagnostics, but it is too strict for deciding whether a split is
meaningful inside a smaller subgroup. A deep subgroup can have a small global
contribution while still having a strong local split.

For ranking candidate splits within a fixed node, the denominator does not
change across candidates. Maximizing raw gain and maximizing parent-relative
gain therefore select the same split. The denominator matters for stopping and
thresholding: `min_relative_gain` should decide whether the best split solves
enough of the current node's mini-problem to continue.

This local criterion should still be paired with sample-size controls such as
`minsplit`, `minbucket`, and `minprob`, so very small subgroups do not pass the
threshold only because their local impurity denominator is tiny.
