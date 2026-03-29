# Fusen Knowledge Base

Built on 2026-03-29 from the public Fusen documentation site and CRAN package vignettes for `fusen` 0.7.2.

Primary sources reviewed:

- `How to use fusen`
- `Maintain packages with {fusen}`
- `Tips and tricks`
- `Share on a GitHub website`
- `Inflate all your flat files`
- `Deal with a 'fusen' flat file`
- `Draw a tree of your package files and functions`
- `Register files in config`
- `Switch from a package developed with fusen to a classical package`

## What Fusen is

Fusen is an "Rmarkdown first" package-development workflow.

You develop one feature in one flat `.Rmd` or `.qmd` file, mixing:

- prose
- function code
- examples
- tests
- one-off development commands

Then `fusen::inflate()` copies each recognized part into standard package locations such as `R/`, `tests/testthat/`, and `vignettes/`.

Core idea: design, documentation, examples, and tests stay close to the code while you prototype, instead of being spread across multiple files too early.

## Mental model

Think of a flat file as the source of truth for a feature family.

- Markdown text becomes vignette content.
- `function-*` chunks become code in `R/`.
- `example-*` chunks become roxygen examples and remain in the vignette.
- `test-*` or `tests-*` chunks become unit tests.
- `development-*` chunks are for setup or helper commands and are not copied into the package.

Fusen is not a new package structure. After inflation, the result is still a regular R package.

## How the current repo already matches Fusen

This repository already uses the expected Fusen layout in `dev/`.

- `dev/0-dev_history.Rmd` is the setup and maintenance notebook for package-level actions such as DESCRIPTION, Git, pkgdown, and GitHub sharing.
- `dev/flat_partytrees.Rmd` is a flat template with `development`, `function`, `examples`, `tests`, and `development-inflate` chunks.

That means the repo is already structured in the way the Fusen vignettes recommend.

## Canonical workflow

### 1. Create or open a flat template

Typical entry points:

- `fusen::create_fusen("path/to/pkg", template = "teaching")`
- `fusen::add_flat_template(template = "add")`
- wrappers such as `fusen::add_additional()`, `fusen::add_full()`, `fusen::add_minimal()`

### 2. Fill package metadata early

Use `fusen::fill_description()` and a `usethis::use_*_license()` call from a development chunk or from `dev/0-dev_history.Rmd`.

Typical pattern:

```r
fusen::fill_description(
  pkg = here::here(),
  fields = list(
    Title = "Your package title",
    Description = "Short package description.",
    `Authors@R` = c(
      person("First", "Last", email = "name@example.org", role = c("aut", "cre"))
    )
  )
)
usethis::use_mit_license("First Last")
```

### 3. Write feature prose before or alongside code

Recommended order from the vignettes:

- explain what the feature is supposed to do in markdown
- write tests and examples early
- implement the function
- inflate and check

This is close to test-driven development and makes the future vignette useful from the start.

### 4. Inflate the flat file

Core command:

```r
fusen::inflate(
  flat_file = "dev/flat_partytrees.Rmd",
  vignette_name = "Minimal",
  open_vignette = TRUE,
  document = TRUE,
  check = TRUE
)
```

Important `inflate()` arguments:

- `flat_file`: flat source file to inflate
- `vignette_name`: title of the resulting vignette; use `NA` to skip vignette creation
- `open_vignette`: whether to open the vignette after inflation
- `document`: runs `attachment::att_amend_desc()` / documentation updates
- `check`: runs `devtools::check()` after inflating
- `overwrite`: whether existing generated files should be replaced
- `clean`: whether files no longer generated from the flat file should be removed
- `update_params`: whether to update `dev/config_fusen.yaml`
- `codecov`: compute coverage after inflation

### 5. Iterate

Two supported maintenance modes exist:

- Continue editing the flat file and re-inflate.
- Deprecate the flat file and continue in normal package files.

The documentation strongly recommends starting with the first mode until the flat-file workflow becomes awkward for the feature.

## Chunk naming rules

Recognized chunk families:

- `function-*`
- `example-*`
- `test-*` or `tests-*`
- `development-*`

Short aliases are accepted in practice, including:

- `fun-*`
- `ex-*`
- `dev-*`

Key rules:

- Chunk names must be unique.
- `example` and `test` chunks should come after the related `function` chunk.
- One title / one main function chunk is the intended pattern.
- If multiple functions live in one `function` chunk, only the first function gets direct example handling.

## What goes where

### `function-*` chunks

Contain roxygen and function code.

If Fusen does not detect a function definition or `R6Class()`, the chunk is copied as-is into an `R/` file. That is how dataset documentation or package-level helper files can still be created from a flat file.

### `example-*` chunks

Used twice:

- inserted into `@examples`
- kept in the vignette

Because examples are later run independently, they must be self-contained.

### `test-*` chunks

Become testthat files. They must also be runnable independently from the flat notebook context.

### `development-*` chunks

Used for local setup and one-off actions only. They are ignored by package generation.

Typical uses:

- `library(testthat)` during authoring
- `pkgload::load_all()`
- `fusen::inflate(...)`
- `usethis` commands

The final inflate chunk should usually use `eval = FALSE` to avoid accidental recursive inflation when knitting the flat file.

## Practical command cheat sheet

### Load only functions from the current flat file

Useful before inflation when you want something like `load_all()` for the current flat file.

```r
fusen::load_flat_functions(flat_file = "dev/flat_partytrees.Rmd")
```

This loads code from `function-*` chunks into the current environment. It does not replace package dependency management.

### Add another flat template

```r
fusen::add_flat_template(template = "add")
```

### Inflate every registered flat file

```r
fusen::inflate_all(check = FALSE, document = TRUE)
```

`inflate_all()` only works after each flat file has been inflated at least once so that Fusen can record its parameters in `dev/config_fusen.yaml`.

Useful arguments:

- `check`
- `document`
- `open_vignette`
- `overwrite`
- `check_unregistered`
- `codecov`
- `stylers`

Fast wrapper without checks:

```r
fusen::inflate_all_no_check()
```

### Draw the package structure

```r
fusen::draw_package_structure()
```

This is meant to help developers understand which flat file generated which R files, tests, and vignettes. The vignettes explicitly recommend placing this output in a `dev/README`-style file.

### Rename a flat file safely

```r
fusen::rename_flat_file(
  flat_file = "dev/flat_old.Rmd",
  new_name = "flat_new.Rmd"
)
```

### Deprecate a flat file after first inflation

```r
fusen::deprecate_flat_file(flat_file = "dev/flat_partytrees.Rmd")
```

This updates the config, removes "do not edit" guidance from generated files, and moves the flat file toward history storage.

### Fully remove Fusen from a package

```r
fusen::sepuku(force = TRUE)
```

This is intentionally destructive and should be used only with version control in place.

## `dev/config_fusen.yaml`

From Fusen >= 0.5, this config file is central.

It records:

- each inflated flat file
- whether it is `active` or `deprecated`
- R files generated from it
- test files generated from it
- vignettes generated from it
- inflate parameters used for that flat file
- a `keep` section for files that were not generated from flat files

Why it matters:

- `inflate_all()` depends on it
- file cleanup depends on it
- package structure visualization depends on it
- safe migration away from flat files depends on it

## Handling unregistered or stale files

Fusen expects the repository to know which files belong to which flat source.

When files are renamed, removed, or created manually, stale files can remain in `R/`, `tests/`, or `vignettes/`.

Recommended workflow:

```r
fusen::check_not_registered_files()
fusen::register_all_to_config()
```

`check_not_registered_files()` writes `dev/config_not_registered.csv`, which helps you decide whether a file is:

- a deprecated generated file that should be deleted
- a manually maintained file that should be registered under `keep`
- a file from an older Fusen workflow that needs to be reattached to config

## Two maintenance strategies

### Strategy A: keep editing flat files

Pros:

- documentation, code, tests, and examples stay together
- easier for feature-focused review
- reduces the risk of updating code but forgetting tests/examples

Cons:

- debugging tools may send you into generated `R/` files instead of the flat source
- collaborators unfamiliar with Fusen may edit the wrong file

### Strategy B: switch to classical package maintenance

Pros:

- standard RStudio and package tooling feels natural
- easier with collaborators who already work directly in package files

Cons:

- you lose the "single feature, single source" workflow
- discipline around documentation and tests becomes manual again

Recommended practice from the vignettes: stay with Strategy A until the feature or package complexity makes it too cumbersome, then deprecate the flat file and continue classically.

## Sharing on GitHub

The Fusen guidance for public sharing centers on:

```r
fusen::init_share_on_github()
```

This bootstraps:

- git
- GitHub repo setup
- CI
- pkgdown deployment
- README and NEWS support

The docs treat it as an all-in-one bootstrap for publishing a package website after you already have a working inflated package.

## Useful tips from the vignettes

### You can knit a flat file

Flat files can be knitted, but that is secondary. Keep in mind that examples and tests later run independently in package context.

### Use plain unnamed chunks when you want code copied only into the vignette

This is the way to keep `library(...)` calls for vignette rendering without turning them into package code or tests.

### Non-run examples

If an example should appear but not run:

- set the chunk to `eval = FALSE` to avoid vignette execution
- use roxygen `#' \\dontrun{}` lines inside the example block for package examples

### Multiple functions in one R file

Supported options:

- put multiple function triplets under one section title
- share the same `@rdname`
- use Fusen-only `@filename`
- use the chunk parameter `filename = "shared_name"`

### Testing with local fixture files

Tests run relative to `tests/testthat/`, so flat-file code often needs to account for both development-time and test-time paths.

### Quarto is allowed

Fusen can use `.qmd` flat files, but the produced vignette is still an R Markdown vignette.

### Golem compatibility

Fusen can be used with `golem`, with the recommendation to keep business logic in flat files and align module names with flat-file names.

## Main limitations and cautions

- Unique chunk names are mandatory.
- Examples and tests need to stand on their own.
- Global workspace state can hide issues during development.
- Newly added flat files must be inflated once before `inflate_all()` can manage them.
- Old or manually created package files must be registered if you want cleanup and structure tools to behave correctly.
- `sepuku()` is irreversible unless you rely on version control.

## Interpreting the repo's current files

### `dev/0-dev_history.Rmd`

This file is aligned with Fusen recommendations.

It acts as an operations notebook for:

- DESCRIPTION and licensing
- git setup
- README / NEWS / code of conduct
- local package checks
- adding more flat templates
- package structure drawing
- pkgdown sharing

### `dev/flat_partytrees.Rmd`

This file currently follows the minimal Fusen pattern correctly:

- initial development chunk loads `testthat`
- `development-load` chunk calls `pkgload::load_all(export_all = FALSE)`
- one function section exists
- examples and tests are colocated with the function
- a final `development-inflate` chunk shows the intended `inflate()` call

That means the main missing work in this repo is content, not structure.

## Suggested next actions for this repo

1. Complete the DESCRIPTION and license steps in `dev/0-dev_history.Rmd`.
2. Replace the placeholder `partytrees()` implementation with the real function design, examples, and tests inside `dev/flat_partytrees.Rmd`.
3. Run `fusen::inflate(flat_file = "dev/flat_partytrees.Rmd", vignette_name = "Minimal")` once to generate package files and create the initial `dev/config_fusen.yaml`.
4. After you have more than one flat file, switch routine regeneration to `fusen::inflate_all()`.
5. Add a developer-facing structure snapshot with `fusen::draw_package_structure()` once the package has multiple generated files.

## Short reference table

| Task | Function |
| --- | --- |
| Create package from template | `create_fusen()` |
| Add another flat file | `add_flat_template()` |
| Fill DESCRIPTION | `fill_description()` |
| Inflate one flat file | `inflate()` |
| Inflate all active flat files | `inflate_all()` |
| Inflate all without checks | `inflate_all_no_check()` |
| Load flat-file functions into env | `load_flat_functions()` |
| Visualize package structure | `draw_package_structure()` |
| Find stale or unregistered files | `check_not_registered_files()` |
| Register remaining files in config | `register_all_to_config()` |
| Rename a flat file safely | `rename_flat_file()` |
| Stop using a flat file | `deprecate_flat_file()` |
| Remove Fusen from package | `sepuku()` |

## Bottom line

Fusen is best understood as a disciplined authoring workflow for package features, not as an alternative package format.

For this repo, the main practical consequence is simple: keep feature work in `dev/flat_*.Rmd`, use `dev/0-dev_history.Rmd` for package-wide operations, and inflate deliberately so the generated package structure stays synchronized.