# Tidymodels inequality-scoring verification

Checked on 25 October 2026 using the current working tree, including the
uncommitted repairs that preceded this task. The package version was
`0.0.0.2`. This work concerns the parsnip bridge, tuning and scoring, and
preserves unrelated local changes.

## Findings and repairs

The previous `ci_tuning_metric_set()` grouped assessment observations by
their predicted risk when node IDs were absent. That is a different
quantity from gain on fitted terminal-node partitions:

- Separate tree leaves can share the same fitted risk. Merging them
  changes the within-leaf inequality calculation.
- A forest's averaged risk does not identify its member-tree partitions.
  Scoring groups formed by averaged risk can overstate partition gain.

An initial weighted, three-fold, two-candidate experiment reproduced forest
discrepancies for all four criteria. Maximum absolute discrepancies were
0.168534 for CI, 0.055648 for CIg, 0.222593 for CIc and 0.027748 for L.
Training-gain metrics were not available through the bridge.

The repair changes the registered numeric prediction method to return
`.pred` together with the actual node assignments and analysis diagnostics.
`ci_tuning_metric_set()` now scores those partitions. Missing node metadata
produces an informative error instead of silently substituting predicted
risks. An explicit `node_name` supports manually prepared partitions.
The standalone low-level `ci_gain()` interface retains its documented
prediction-group approximation when called without nodes.

The metric set now supports four quantities:

| Metric | Population and denominator |
| --- | --- |
| `validation_gain` | Assessment-root impurity minus weighted within-leaf impurity on that assessment fold |
| `relative_validation_gain` | Validation gain divided by its assessment-root impurity |
| `training_gain` | The same partition calculation on the analysis sample used for fitting |
| `relative_training_gain` | Training gain divided by its analysis-root impurity |

Forest gain averages the member-tree partition gains on the full scored
sample. It does not substitute a surrogate or group averaged predictions.
Relative gains are `NA` when the relevant root impurity is numerically zero.
Negative gains are retained. Training gain is descriptive and should not
replace validation gain for selecting parameters.

Additional repairs reject invalid `.row` indices and mismatched engine and
metric criteria. Grouping preserves custom tuning parameter names and
resample IDs, including repeated-CV `id2`, when rescoring saved predictions.

## Independent experiments

Run from the package root:

```sh
/usr/bin/Rscript dev/run_tidymodels_scoring_experiments.R
```

The script constructs synthetic observations with a binary health outcome,
tied positive socioeconomic levels, unequal importance weights and
zero-weight observations. There are no missing measurements in this
experiment. Zero weights contribute neither rank probability nor impurity
mass. CIc retains the package's current observed-range convention, and L
uses socioeconomic levels rather than fractional ranks.

The reference calculation independently constructs weighted midpoint ranks
by summing the mass below a value and half the mass tied at that value. It
then computes weighted population covariance and the index formulas,
without calling the package's rank, score or gain functions. It recalculates
the index within each leaf, using the node assignments actually scored.

The experiment covers:

- CI, CIg, CIc and L, for trees and forests;
- weighted and unweighted formula workflows;
- a weighted recipe workflow with factor dummy encoding;
- ordinary three-fold CV, repeated CV and bootstrap resamples;
- two candidates per model and a custom `depth` tuning identifier;
- training and validation gains and their relative forms;
- rescoring saved predictions while keeping folds separate;
- parameter selection against independent mean validation gains.

All **1,152 fold-metric comparisons** passed a `1e-12` absolute tolerance.
The largest observed absolute error was `1.136868e-13`. All **40 selection
checks** chose a candidate with the independently best mean validation gain.
An additional **16 direct-fit checks** compared parsnip and native fits,
with equal seeds and controls, across both model families, all four criteria
and weighted/unweighted data. Node assignments matched exactly and risks
agreed within the same tolerance.

The final experiments also compare actual partition gains with gains formed
by grouping the same predictions by risk:

| Model | CI | CIg | CIc | L |
| --- | ---: | ---: | ---: | ---: |
| Tree | 0 | 0 | 0 | 0.034965 |
| Forest | 0.324373 | 0.102596 | 0.410385 | 0.083561 |

Entries are maximum absolute discrepancies across the tested scenarios.
These are counterexamples to using risk groups as substitutes for fitted
partitions, not performance comparisons across index types.

Results and package versions are saved in
[`validation/tidymodels_scoring/`](validation/tidymodels_scoring/):

- `fold_scores.csv`: every reported score and its independent reference;
- `summary.csv`: maximum error by scenario, model, criterion and metric;
- `selection_checks.csv`: selected candidates and independent best means;
- `direct_fit_checks.csv`: native/parsnip prediction and node comparisons;
- `prediction_grouping_checks.csv`: risk-group/partition discrepancies;
- `session_info.txt`: the environment used for execution.

Tested versions include parsnip 1.6.0, tune 2.1.0, yardstick 1.4.0,
workflows 1.3.0, hardhat 1.4.3, rsample 1.3.2 and R 4.5.3. Online parsnip
documentation advertised a newer patch release; that release was not
installed or claimed as tested.

## Package verification

Fusen 0.7.2 regenerated the bridge and extension outputs in a temporary
package copy. The generated R file, namespace, documentation, vignettes and
tests were brought back into the checkout. No changes to `DESCRIPTION` or
the fusen ownership configuration were needed for this repair.

The initial scoring suite passed **743 expectations in 197 test blocks**, with
zero failures, errors, warnings or skips. Regression checks cover tied-risk
leaves, missing partition metadata, invalid row mapping, criterion mismatch,
zero-root relative gains, analysis/assessment separation, custom parameter
names, saved-prediction rescoring and workflow finalisation.

The source-package check used `devtools::check()` with `document = FALSE`,
`args = "--no-manual"` and `build_args = "--no-manual"`. Examples and
vignette builds and rebuilds passed. There were **0 errors, 0 warnings and
2 notes**:

- The check could not verify the current time in this environment.
- The installed Ubuntu R configuration supplied
  `-mno-omit-leaf-frame-pointer` as a compiler flag.

Neither note identifies a scoring defect. The PDF reference manual was
excluded. These were local checks; no GitHub workflow or site deployment
was run at that stage. The later release checks below also cover the plotting
repairs and prepare the changes for the requested pull request.

### Development reload regression

A subsequent `fusen::inflate_all()` failed in an existing R session because
parsnip retained the earlier numeric prediction definition. The fresh-process
checks above had not exercised an upgrade from that older registration.

The registration helper now replaces only the matching `ineqTrees`
regression prediction entry and restores the previous registry if replacement
fails. Other engines are preserved. Regression tests seed the legacy
registrations for both trees and forests, repeat registration, check for
duplicates and test rollback after an invalid definition.

The exact default `fusen::inflate_all()` completed in a temporary package
copy with both legacy registrations present. Its package check returned
0 errors, 0 warnings and the same 2 environment notes. Two subsequent
`pkgload::load_all()` calls and explicit registration also succeeded.
The full post-inflation suite passed **755 expectations in 200 test blocks**,
without failures, errors, warnings or skips. The complete generated
`NAMESPACE` was restored after the failed run had left it incomplete.

## Interpretation and compatibility

The added `.ci_node` column contains integer IDs for a tree and a list of
per-member IDs for a forest. `.ci_type`, `.ci_training_gain` and
`.ci_training_root` carry the scoring context. Code needing only numeric
risks should select `predict(fit, new_data = data)$.pred`. The standard
parsnip numeric prediction tibble now contains these additional columns;
native tree/forest prediction methods were not changed.
Forest node metadata grows with observation count times member-tree count.
For routine tuning, use `save_pred = FALSE` when retaining all assessment
assignments is unnecessary; the metrics still use those assignments while
scoring.

## Final package and website checks

The release check for version `0.0.0.2` passed **757 expectations**, with no
failed tests, warnings or skips. `R CMD check`, with the PDF manual excluded,
returned **0 errors, 0 warnings and 2 environment notes**, concerning the
current-time lookup and the compiler flag listed above. Setting
`TZ=Africa/Nairobi` avoided a container-only `timedatectl` warning while
loading lubridate. The generated `README.html` preview is excluded from both
Git and the source package.

The complete pkgdown site built successfully, including reference examples,
all articles and its problem checks. The final article was refreshed with
the development package loaded, and the homepage was refreshed after README
rendering. Pandoc still emits an upstream `--highlight-style` deprecation
message from the installed rendering tools; it does not prevent the build.

Plotting changes follow the helpers in
`recursive_partitioning_paper/RDC_l_index_analysis.Rmd`: values-only edges,
wrapped labels, individual internal-box sizes and sufficient terminal-panel
height. README trees use depth 2 on a 9 by 4.5 inch canvas; the main article
retains depth 3. All four README tree figures and both introductory article
figures were visually inspected. White backgrounds keep branches visible in
the site's dark theme. Exact criterion names and weighted article summaries
are preserved.

Partykit can randomly route factor levels that are absent from a forest
member's sample or a split's observed levels. This existing behaviour is
retained. The bridge uses one routing draw for both risk and partition
metadata, and caches the analysis assignments used for training gain in
`attr(engine, "ci_training_diagnostics")$nodes`. A later native prediction
can draw different assignments and yield a different gain. Audit the saved
assignments rather than assuming a new routing call recreates them.

The direct native/parsnip equivalence checks use numeric split variables to
avoid comparing independent random routing draws. The tuning experiments
include factors and verify the actual saved assignments independently.
This establishes score arithmetic and data alignment for these scenarios.
It does not establish survey-design inference, population generalisation,
causality or correctness for every possible recipe transformation.

Keep the original analysis table in the metric context, with the same row
order used to create the resamples. Recipes must retain the socioeconomic
variable and case-weight role. Transforming socioeconomic levels can change
L and therefore changes the estimand. Compare candidates within a fixed
criterion and use held-out gain for selection.

## Documentation consulted

The implementation uses the registered prediction interface described in
[parsnip's model development guide](https://www.tidymodels.org/learn/develop/models/)
and the metric/resampling behaviour documented for
[`tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html).
The experiments retain fitted engines and saved assessment predictions
through the documented
[`control_grid()` extraction and prediction options](https://tune.tidymodels.org/reference/control_grid.html).
Installed package code was inspected to verify how prediction columns,
grouping keys and `.row` reach the metric functions.
