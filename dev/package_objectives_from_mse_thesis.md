# Why Build This Package?

Based on a review of the thesis repository at `/home/mburu/projects/uhasselt/mse-thesis`, especially the `R/`, `analysis/`, and `methodology_dev/` folders.

## Short answer

You need this package because the thesis work is no longer just a set of one-off analysis scripts. It already contains the core of a reusable methodological toolkit for studying socioeconomic inequality in health with tree-based models.

The current thesis repo mixes together:

- reusable statistical methods
- reusable data-preparation utilities
- visualization helpers
- country-specific analysis scripts
- methodology writing

That is exactly the point at which packaging becomes useful. A package will separate the reusable method from the thesis-specific application.

## Evidence from the thesis repo

### 1. The methodology defines a general method, not a single dataset workflow

The methodology files make it clear that the project is methodological.

Core methodological aim:

- decompose health inequality using tree-based regression models
- move beyond standard linear Wagstaff-style decomposition when effects are nonlinear, interactive, or subgroup-specific
- identify subgroups where socioeconomic inequality in health is especially pronounced
- modify recursive partitioning so that splits reduce within-node inequality rather than just optimize predictive fit
- recover additive determinant contributions for tree-based models using SHAP

This is package territory, not just thesis territory, because these are general procedures that can be reused on multiple datasets and in multiple empirical studies.

### 2. The `R/` folder already contains reusable modules

The thesis `R/` folder is not just a collection of ad hoc scripts. It already contains separable components that map naturally to package functions.

#### Data ingestion and harmonization

`R/data_prep_funs.r` includes reusable DHS-oriented data infrastructure:

- parsing SAS layouts into fixed-width specs
- reading DHS zip archives
- building a DHS file catalog
- standardizing IDs across modules
- merging modules safely
- constructing child-level analytical datasets by country / phase / version

This is reusable workflow code, not thesis-only prose.

#### Core inequality-tree algorithm

`R/partykit_ci.r` contains the methodological core:

- weighted within-node socioeconomic ranking
- concentration-index impurity functions for `CI`, `CIg`, and `CIc`
- candidate split scoring by reduction in within-node inequality
- numeric and factor split search
- custom `partykit` split function
- wrappers such as `ctree_ci()` and `cf_ci()`
- control-grid creation and cross-validation helpers
- prediction helpers and validation metrics

This is the strongest signal that a package is needed. This file is already implementing a new model class, not just running an analysis.

#### SHAP-based decomposition layer

`R/functions.R` adds another reusable methodological layer:

- fractional rank computation
- SHAP table validation and reshaping
- SHAP-based concentration-index decomposition
- diagnostics and printed summaries

This is not project glue. It is a reusable bridge between tree-based prediction and inequality decomposition.

#### Tree visualization helpers

`R/trees_helpers_plot.R` contains plot helpers for labeled, interpretable tree graphics:

- readable split labels
- internal-node annotation
- terminal-node summaries
- compact presentation for decision-rule communication

These are clear package helpers because they support communication and reproducibility across analyses.

### 3. The `analysis/` folder shows repeated applied workflow built on those methods

The analysis files are not defining a new method from scratch each time. They are repeatedly applying the same workflow:

- read and prepare DHS-based data
- construct inequality-relevant outcomes and rankings
- fit tree-based or benchmark models
- compare decomposition approaches
- examine interpretability outputs

In particular:

- `analysis/process_data.R` turns the data-prep layer into reusable country-phase datasets
- `analysis/child_health_eda.qmd` and `analysis/congo_ci_tree_demo.qmd` show the same analytical pipeline being used for empirical exploration and method demonstration

When the same pipeline is reused across multiple reports, the method should be extracted into a package.

### 4. The repo still contains signs of script-stage development

There are also clear signs that the thesis repo is still in a script-prototype phase:

- repeated `source(here("R", ...))` usage
- analysis code that defines helper functions inline
- absolute paths in some scripts
- method code and application code living side by side
- several overlapping experimental files and archives

That is normal during exploration, but it becomes fragile once the method matures. A package solves this by establishing:

- a stable API
- a single source of truth for functions
- tests
- documentation
- vignettes
- reproducible imports and dependencies

## Why packaging is justified now

You should build the package now because the thesis work already has four characteristics of package-worthy research software.

### 1. Reusability

The code is designed to be used across:

- multiple countries
- multiple DHS phases / versions
- multiple outcome definitions
- multiple inequality indices
- multiple model families and benchmarks

### 2. Conceptual coherence

The files point to one coherent software purpose:

- build, tune, validate, interpret, and decompose inequality-aware tree models for health outcomes

### 3. Need for reproducibility

The thesis requires methods that are inspectable and reproducible. A package gives:

- versioned functions
- documented assumptions
- testable outputs
- cleaner separation of method from empirical chapter code

### 4. Need for maintainability

Right now, method evolution risks breaking analysis scripts silently. Packaging reduces that risk by centralizing the implementation.

## Intended package objectives

The package should not try to package the full thesis. It should package the reusable methodology.

### Primary objective

Provide an R package for tree-based decomposition of socioeconomic inequality in health outcomes, with tools for fitting inequality-aware trees and decomposing fitted outcomes into determinant contributions.

### Objective 1: Fit inequality-aware recursive partitioning models

Implement tree models where split selection is driven by reduction in within-node inequality rather than only prediction error.

This should cover:

- standard concentration index (`CI`)
- generalized concentration index (`CIg`)
- corrected concentration index (`CIc`)
- single-tree and forest-style extensions where feasible

### Objective 2: Support decomposition of tree-based fitted values

Provide a decomposition framework for tree-based or ensemble predictions using SHAP-style additive contributions.

This should let users:

- compute fitted-value concentration indices
- attribute inequality contributions to determinants
- compare tree-based decomposition to classical regression-based decomposition

### Objective 3: Provide reusable ranking and weighting infrastructure

Implement the low-level utilities needed for inequality analysis under survey-style data.

This includes:

- weighted fractional rank functions
- weighted concentration-index utilities
- safe case-weight handling for tree fitting
- prediction and validation helpers

### Objective 4: Support subgroup interpretation

The package should make subgroup structure legible, not only estimable.

This includes tools for:

- extracting terminal-node summaries
- printing interpretable decision rules
- plotting trees with readable labels
- linking subgroups back to inequality patterns

### Objective 5: Support empirical workflows on DHS-like data

The package can include optional utilities for DHS ingestion and harmonization if you want the package to support end-to-end applied work.

At minimum, this means:

- reading DHS zip payloads
- harmonizing IDs across modules
- building child-level analytic tables

If you want the package to stay method-focused, these functions can be placed in a secondary layer or even a companion package.

### Objective 6: Enable method comparison and validation

The thesis is not only proposing a method; it is also evaluating it. The package should support that evaluation.

This includes helpers for:

- tuning tree controls by cross-validation
- computing validation metrics
- comparing inequality-tree outputs to classical regression decompositions
- benchmarking against standard trees or forests

## What the package should include

Recommended in-scope components:

- inequality index utilities
- inequality-aware tree fitting functions
- SHAP decomposition functions
- plotting and subgroup-summary helpers
- model tuning and validation helpers
- small reproducible example datasets or simulation utilities
- vignettes showing end-to-end usage

## What the package should probably not include

Recommended out-of-scope components:

- thesis chapter prose
- country-specific analysis reports
- hard-coded Kenya / DRC scripts
- one-off exploratory notebooks
- archived experiments that are not part of the final method
- machine-specific paths and local download credentials

## Best package framing for this project

The cleanest framing is:

"An R package for measuring, modeling, and decomposing socioeconomic inequality in health using inequality-aware tree-based methods."

That framing is better than describing the package as only:

- a DHS package
- a plotting package
- a SHAP package
- a thesis companion repo

Those are supporting layers, but the central package identity is methodological.

## Suggested package structure

A reasonable package architecture would be:

- `rank_*` and `ci_*` utilities for ranks and inequality metrics
- `ctree_ci_*` and related model wrappers for inequality-aware trees
- `shap_*` decomposition functions for additive contribution analysis
- `tree_*` helpers for visualization and subgroup summaries
- optional `dhs_*` data-prep helpers for applied workflows

## Bottom line

You need this package because your thesis has already produced a general analytical framework, not just a set of empirical scripts.

The package should capture the reusable method:

- inequality-aware recursive partitioning
- weighted concentration-index computation
- SHAP-based decomposition of fitted values
- subgroup interpretation and visualization
- reproducible validation and comparison tools

The empirical analyses in the thesis should then depend on the package, not reimplement it.