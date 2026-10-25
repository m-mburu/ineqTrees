# LLM instructions: make the tree figures readable

Improve the tree figures in `README.Rmd` and the introductory article.
Use smaller demonstration trees, normally capped at `maxdepth = 3L`, and
smaller plotting canvases. The aim is readable figures at ordinary page
size, with clear branches, unclipped labels and useful terminal summaries.
Inspect the current images before editing, and inspect the rendered result
before declaring the task complete.

## Current implementation

The findings below record the original audit and are historical. Follow the
current fusen sources when making further changes. The later plotting review
also used `recursive_partitioning_paper/RDC_l_index_analysis.Rmd`, especially
`tree_edge_panel_values_only()`, `tree_inner_panel_labeled()` and
`plot_l_tree()`, as requested by the user.

Preserve the following presentation choices:

- Put variable names inside internal nodes and split values on branches.
  `tree_edge_panel_compact()` defaults to `show_variable = FALSE`; callers
  can request the earlier labels with `show_variable = TRUE`.
- Wrap long category lists and internal labels. Size each internal box to
  its own text, and allow enough terminal-box height for every statistic.
- Keep README examples at depth 2 and the main article at depth 3. The
  README uses a 9 by 4.5 inch canvas with 10.5-point text and an opaque
  white background. Check every regenerated figure at normal page width.
- Preserve exact criterion names (`CI`, `CIg`, `CIc`, `L`) when calculating
  and labelling node statistics. Keep weighted article summaries consistent
  with the weighted fit.

The user has authorised committing, pushing and opening a PR after
verification. The earlier instruction below to leave repairs unstaged
described the audit stage and does not override that later authorisation.

## Read first

Follow applicable `AGENTS.md` instructions, including `dev/AGENTS.md`, and
these guides in the user's Codex home folder:

- [Coding best practices](/home/mburu/.codex/guidance/coding-best-practices.md)
- [Software engineering](/home/mburu/.codex/guidance/software-engineering.md)
- [R style](/home/mburu/.codex/guidance/r-style.md)
- [Natural writing](/home/mburu/.codex/guidance/write_like_human.md)
- [Writing voice](/home/mburu/.codex/guidance/writing-voice.md)

Read the mathematics guide if changing mathematical labels. Keep new R code
spacious, within 80 characters where required, with two-space indentation.
Use British English and no Unicode en or em dashes in new text.

Inspect `git status --short` first. There is already substantial unrelated
work in this checkout, including the audit repairs for findings F1 to F9
in `dev/model_selection.Rmd`, `dev/shap_decomposition.Rmd`,
`dev/ci_tree_models.Rmd` and `src/`. Preserve all of it. Do not reset,
stage or rewrite it. If those repairs are still uncommitted, keep the
plotting work separable so it can be committed on its own.

## Why the text looks small

The root cause is canvas size, not font size alone. The README currently
renders a 15-inch-wide figure, and the chunk option `out.width = "100%"`
scales it to the page. At a desktop content width of about 850 pixels,
6.5-point text on a 15-inch canvas occupies roughly 5 pixels of height.
Reducing the canvas to 8 or 9 inches at 9 to 11 points gives roughly 13
pixels, which is near normal body text. Enlarging the canvas while keeping
6.5-point text cannot fix this, and lowering `dpi` changes sharpness only,
because `dpi` affects raster density rather than the relative size of text
once the image is scaled to a fixed display width.

Reducing pixel dimensions alone will not remove overlapping labels either.
The panels need enough physical space for the text they contain.

## What has already been verified

These observations were checked against the working tree on 25 October
2026. Verify them again if the files have changed.

- `README.Rmd` sets `out.width = "100%"` and `dpi = 600` for every chunk
  (lines 11 and 12).
- `readme_tree_plot()` (line 56) uses 6.5-point text, terminal boxes of
  11 by 5.2 lines, `tnex = 0.85`, and a hardcoded CI statistic, described
  as defect D3 below.
- All four evaluated README tree chunks use a 15 by 9 inch canvas. The
  direct tree (line 206) and direct surrogate (line 316) allow depth 4.
  The introductory forest (line 234) allows depth 5. The evaluated tuning
  grids use `maxdepth = c(3L, 4L)` (lines 570 and 684).
- The four README PNGs are 9000 by 5400 pixels with three channels, so
  they are already opaque white. Their background is not the dark-mode
  problem.
- The [introductory article](https://m-mburu.github.io/ineqTrees/articles/inequality-aware-party-trees.html)
  uses depth 3 for its main tree. Its source uses canvases of 12 by 7
  inches and 14 by 10 inches for the basic and annotated plots, and sets
  no `dpi`, so it inherits knitr defaults and produces small rasters.

Two earlier assumptions need correcting:

- The `a education` and `b no education` labels inside the terminal rules
  are the literal factor levels in `kenya$ed`, not a prefix added by the
  plotting code. Relabel them with `var_labels` or a display-level map, or
  recode the demonstration data. Do not hunt for a prefix in
  `tree_pretty_var_name()`.
- The README has two forest tuning grids: line 272 sits inside a plain
  ```r fence that knitr never evaluates, and line 684 is the live chunk.
  Only the live grid affects a rendered figure.

## Use the thesis as a reference

Inspect these current files under
`/home/mburu/scool and projects/MSE_Work/mse-thesis/`:

| Reference | Relevant content |
| --- | --- |
| `thesis_mse/R/report_helpers.R` | `ci_report_tree_plot()` at line 1081; 11-point text, values-only edges, wrapped labels, weighted summaries |
| `R/ci_survey_helpers.R` | `survey_tree_inner_wrapped()` and `plot_survey_ci_tree()` at lines 401 to 439; labels wrapped at 24 characters, boxes sized to text, 9-point font |
| `thesis_mse/report/Generate_DRC_Results_Objects.qmd` | Tree and surrogate plotting examples |
| `thesis_mse/report/Generate_DRC_Results_Objects_files/figure-commonmark/ci-tree-preview-1.png` | An existing rendered thesis tree to view |

The report helper is the closest match to what this package needs. It uses
`tree_edge_panel_values_only` for edges, `tree_inner_panel_compact_labeled`
for nodes, and weighted summaries, including a weighted count labelled
`n`. Neither panel helper exists in this package, so treat them as design
references. The package's nearest equivalents are `tree_edge_panel_compact()`
and `tree_inner_panel_labeled()`; extend those rather than importing the
thesis versions.

Transfer the presentation principles, not the code. The viewed thesis
preview still has crowded branch text in places, so it is a reference
rather than a visual acceptance standard.

Keep the thesis read-only. Do not source the complete thesis workflow,
load private survey data or add a dependency on files outside this package.

## Verified defects to repair first

Three defects are not merely cosmetic. Fix them before tuning anything
visual, because two of them change what the figures assert.

### D1. `plot.ci_tree()` silently ignores `plural_overrides`

`dev/flat_partytrees.Rmd` line 261 passes
`plural_overrides = c(Province = "provinces")`. `plot.ci_tree()`
(`dev/plot_tree_helpers.Rmd` line 964) has no such parameter. The argument
falls into `...` and is forwarded to `partykit::plot.party()`, which
ignores it.

Verified by rendering the same fit with and without the argument: the PNGs
are byte-identical, and the label still reads `reg | 4 levels | a, b, ...`
instead of `Province | 4 provinces | ...`.

Repair this at the source helper. `tree_edge_panel_compact()` already
accepts `plural_overrides` and handles it correctly, so `plot.ci_tree()`
should accept the argument and pass it into the default edge panel. Add a
focused test that a plural override reaches the rendered label. Do not
work around it in the vignette.

### D2. The article annotates a weighted model with unweighted statistics

`tree_fit` is fitted with `weights = kenya_model$sample_weight` (line 209).
The annotated plot chunk at line 251 computes `mean(df$deadu5_num)`, which
ignores the weights. The figure therefore mixes a weighted fit with an
unweighted mortality rate.

Reproduced on a weighted fit of the same form (500 sampled rows,
`sample_weight`, depth 2): one terminal node has a weighted node mortality
of 6.48 per cent, while the chunk's unweighted statistic gives 10.4 per
cent for that same node. The exact gap will differ on the full article
data. The sign and cause of the discrepancy will not.

Repair it by computing `stats::weighted.mean(df$deadu5_num,
df$sample_weight)` and deciding explicitly what `n` means. Show the weight
sum if the summaries are weighted, or keep the row count and label it as
such. Either choice is defensible; silently mixing the two is not.

### D3. The README hardcodes the CI criterion

`readme_tree_plot()` always calls `ci_factory("CI")` and labels the result
`CI`. Both tuning examples search `type = c("CI", "CIg")`, so the selected
tree may be a `CIg` tree. The figure would then mislabel its own objective.

Repair it by reading the criterion from the fitted object and labelling it
accordingly. The field is not in the same place on both types. A `ci_forest`
exposes `$type` directly, while a `ci_tree` and a forest surrogate tree store
it in `$info$type`. Check both before writing the lookup, and fall back to
`"CI"` only when neither is present.

### Stale assets

Five tracked PNGs are referenced nowhere in the repository:
`README-example-1.png`, `README-surrogate-1.png`,
`README-shap-decomposition-1.png`, `README-tune-tree-1.png` and
`README-tune-forest-1.png`. Confirm each is genuinely orphaned after
regeneration before deleting it, and do not delete the four figures that
`README.md` actually embeds.

## 1. Cap the README demonstration trees

Read the whole current `README.Rmd` and trace the models feeding these
four evaluated chunks:

| Plot chunk | Model or controls to inspect |
| --- | --- |
| `readme-tree-plot` (line 215) | `fit_tree`, line 206, currently depth 4 |
| `surrogate-tree-plot` (line 326) | `forest_surrogate`, built at line 310, depth 4 |
| `tree-tuning-plot` (line 662) | `tree_tuning$best_fit`; live grid at line 570 uses depths 3 and 4 |
| `forest-surrogate-plot` (line 783) | `forest_tuning$best_surrogate`; live grid at line 684 |

Use `maxdepth = 3L` for the direct tree and the direct surrogate. Use
`maxdepth = c(2L, 3L)` for the short README tree-tuning grid. Cap the tuned
forest surrogate explicitly:

```r
forest_tuning <- tune_ci_forest(
  # other arguments unchanged
  surrogate_control = ci_tree_control(maxdepth = 3L)
)
```

`surrogate_control` is the supported interface. When it is `NULL`,
`.ci_surrogate_control()` copies the winning forest control and drops
`mtry`, so the surrogate inherits the member-tree depth unless you say
otherwise. Do not assume member-tree controls keep it small.

Consider depth 3 for the introductory README forest at line 234 and for
its own tuning example. If you change that model, update the surrounding
prose, which currently describes the forest as a demonstration of
averaging across many trees.

Depth 3 permits up to eight leaves. If that still reads as crowded, prefer
a clearly labelled depth-2 illustration or a documented minimum-node-size
setting. Do not conceal leaves, crop branches or alter split labels to
make a larger fitted tree appear smaller.

Refit affected examples and regenerate their summaries, predictions and
dependent output. Do not edit only the image while leaving tables from the
old model. `fit_forest` also feeds the SHAP section at lines 482 and 486,
so changing it changes those results too. Keep these changes inside
documentation examples. Do not change package defaults or thesis models.

## 2. Choose dimensions and labels together

Start the four README tree chunks near these settings, then adjust using
actual previews:

| Setting | Starting point |
| --- | --- |
| Figure width | 8 to 9 inches |
| Figure height | 5 to 6 inches |
| Text size | 9 to 11 points |
| PNG resolution | 200 to 300 dpi |
| Display width | About 750 to 850 pixels on desktop, responsive on narrow screens |
| Background | Explicit opaque white with dark text and borders |
| Terminal fill | Light grey or a restrained pale colour |

These are starting values, not proof that eight leaves will fit. Choose
terminal-panel width, height and `tnex` together with the actual leaf
count. Four summary lines need vertical space, and overly wide boxes
collide even when the image has whitespace elsewhere.

Apply tree-specific chunk settings rather than changing the global
`opts_chunk` block, which also governs the SHAP charts.

In `readme_tree_plot()`:

- Keep descriptive variable labels in internal nodes, wrapped and sized to
  the resulting text. Relabel the `a` and `b` education levels for display
  as described above.
- Put branch values or conditions on edges. The package already provides
  `tree_edge_panel_compact()` for this. Pass the plural override through
  the repaired `plot.ci_tree()` rather than duplicating the panel.
- For large factor groups, use short clearly marked previews and keep the
  complete rules in the terminal summary table. Do not imply that an
  abbreviated list is the full split condition.
- Inspect `ep_args`, `ip_args` and `tp_args` before changing anything. The
  supported `tp_args` controls are `width_lines` and `height_lines`. Tune
  those first. Do not invent arguments: the thesis report helper uses
  `tree_edge_panel_values_only`, which does not exist in this package.
- Keep terminal summaries short: observation count, outcome percentage,
  mean wealth and the applicable index. Use a short label such as
  `Risk %` for surrogate predictions.
- Preserve the statistical meaning of each summary. The README models are
  unweighted, so unweighted summaries are correct there, and
  `rep(1, nrow(df))` for the CI is correct. Do not introduce weights into
  the README while restyling it. Where weights are used, as in the
  article, compute and label weighted summaries consistently.
  Distinguish raw `n` from the sum of weights.
- Use the criterion that the fitted model actually used, as described in
  defect D3.

Retain one simple shared README plotting helper. Avoid a new theme
framework, plotting dependency or replacement tree renderer.

## 3. Apply the presentation fixes to the article

The article source is `dev/flat_partytrees.Rmd`, which generates
`vignettes/inequality-aware-party-trees.Rmd`. Edit the source and
regenerate only its outputs according to `dev/config_fusen.yaml`. Do not
edit the generated vignette by hand.

The main article tree is already capped at depth 3. Improve its basic
chunk at line 241 and annotated chunk at line 251 by coordinating canvas
size, font size, branch text and terminal boxes. Use the same visual
conventions as the README. Keep the basic plot simple and the annotated
plot informative. The annotated chunk needs the D2 weighting repair, and
both chunks set no `dpi`, so choose one deliberately.

Check `_pkgdown.yml` and `pkgdown/extra.css` before assuming a theme
problem. Two rules matter:

- Line 442 sets `img { background-color: #fff; }` for the light theme.
- Line 736 sets `[data-bs-theme="dark"] img { background-color:
  transparent; }` for the dark theme.

The dark rule has no visible effect on the current README PNGs, because
they have no alpha channel and their white pixels are part of the image.
It would matter for a transparent PNG, so keep new plot output opaque. An
opaque white surface with explicit dark text and borders is the right
default for these statistical figures in both themes. Do not change the
theme switch, and do not apply blanket CSS changes to every image.

If shared package helpers need a focused correction, edit their source in
`dev/plot_tree_helpers.Rmd` and regenerate the affected R files, tests and
docs. The `plural_overrides` repair in D1 belongs there. Preserve public
plotting behaviour outside the necessary fix, and add a regression test
for any signature change. Image generation tools are inappropriate here:
render the actual fitted models with R and `partykit`/`grid`.

## 4. Render, inspect and finish

Use `/usr/bin/Rscript`. Iterate on the affected model and plot chunks
first, so styling experiments do not repeatedly run unrelated ranger,
SHAP and tuning jobs. Then render the complete affected documents to
produce consistent final output:

```sh
/usr/bin/Rscript -e 'rmarkdown::render("README.Rmd", quiet = TRUE)'
/usr/bin/Rscript -e 'pkgdown::build_article("inequality-aware-party-trees")'
git diff --check
```

`pkgdown` is not listed in `DESCRIPTION`, so treat the article build as a
local tooling check rather than a package dependency. Confirm that
`pkgdown::build_article()` exists in the installed version before running
it. Regenerate the vignette source before building
it. Keep temporary previews outside tracked output paths. Do not publish
the site as part of a local presentation repair.

Acceptance requires viewing the actual regenerated PNGs and the rendered
README and article at normal desktop content width and at a narrow mobile
width:

- Every displayed README tree has depth at most 3, with a caption or text
  identifying a simpler illustration where appropriate.
- All four README tree figures use the revised compact settings.
- Internal labels, branch conditions and terminal statistics are readable
  without zooming at ordinary desktop width. As a target, text should
  occupy at least about 10 pixels of height at an 850-pixel display width.
- No clipped text, overlapping boxes, cut-off branches or excessive empty
  margins remain. Narrow screens have no page-breaking overflow.
- Image backgrounds, lines and text remain legible in both site themes.
- Counts, percentages, criterion labels and accompanying tables match the
  newly fitted models and their weighting conventions. The article's
  terminal statistics must agree with the weighted fit.
- The article's `plural_overrides` argument takes effect, or has been
  removed. It must not be silently ignored.
- `README.md`, its referenced `man/figures/README-*.png` assets and the
  article's source and generated outputs agree. Remove obsolete images
  only after checking that nothing still references them; the five
  candidates listed above are a starting point, not a licence to delete
  everything unreferenced.

If you change shared helpers, run the focused plotting tests and inspect
representative existing plots. Formatting-only documentation changes do
not require new tests that merely assert chosen aesthetic constants, but
the D1 signature change does need a regression test.

Do not claim browser or GitHub rendering was verified unless you actually
viewed it there. Report local visual checks separately from published
checks.

Finish with a concise report listing changed files, actual model depths,
final figure dimensions, measured text height if you computed it, visual
checks performed and remaining limitations. Separate the confirmed defects
from the aesthetic choices. Report unrelated uncommitted work without
modifying it.
