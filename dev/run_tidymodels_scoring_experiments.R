# Compare tidymodels gains with independent weighted calculations.
# Run from the package root. Synthetic observations have no missing values;
# zero weights do not contribute to ranks, means or impurity denominators.

pkgload::load_all(".", quiet = TRUE)

arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments)) arguments[1L] else {
  file.path("dev", "validation", "tidymodels_scoring")
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# This reference deliberately does not call the package's scoring helpers.
# Each tied rank receives half the probability mass of its tied block.

reference_impurity <- function(rank, outcome, weights, criterion) {
  keep <- weights > 0
  rank <- rank[keep]
  outcome <- outcome[keep]
  weights <- weights[keep]
  if (length(rank) <= 1L) {
    return(0)
  }

  probability <- weights / sum(weights)
  mean_outcome <- sum(probability * outcome)
  if (criterion == "L") {
    mean_level <- sum(probability * rank)
    if (abs(mean_level) <= .Machine$double.eps) {
      return(0)
    }
    return(abs(sum(probability * (rank - mean_level) * outcome) / mean_level))
  }

  fractional_rank <- vapply(rank, function(level) {
    sum(probability[rank < level]) + sum(probability[rank == level]) / 2
  }, numeric(1))
  rank_mean <- sum(probability * fractional_rank)
  covariance <- sum(
    probability * (fractional_rank - rank_mean) * (outcome - mean_outcome)
  )

  if (criterion == "CI") {
    if (abs(mean_outcome) <= .Machine$double.eps) {
      return(0)
    }
    return(abs(2 * covariance / mean_outcome))
  }
  if (criterion == "CIg") {
    return(abs(2 * covariance))
  }
  outcome_range <- diff(range(outcome))
  if (outcome_range <= .Machine$double.eps) {
    return(0)
  }
  abs(8 * covariance / outcome_range)
}

reference_gain <- function(data, nodes, criterion, weighted) {
  weights <- if (weighted) data$weight else rep(1, nrow(data))
  if (is.list(nodes)) {
    partitions <- as.data.frame(do.call(rbind, nodes))
  } else {
    partitions <- data.frame(node = nodes)
  }

  root <- reference_impurity(data$rank, data$outcome, weights, criterion)
  gains <- vapply(partitions, function(partition) {
    child_impurity <- sum(vapply(unique(partition), function(node) {
      rows <- which(partition == node & weights > 0)
      if (!length(rows)) {
        return(0)
      }
      sum(weights[rows]) / sum(weights) * reference_impurity(
        data$rank[rows], data$outcome[rows], weights[rows], criterion
      )
    }, numeric(1)))
    root - child_impurity
  }, numeric(1))

  gain <- mean(gains)
  relative <- if (root <= .Machine$double.eps) NA_real_ else gain / root
  c(gain = gain, relative_gain = relative)
}

# Include tied socioeconomic values, unequal weights and zero-weight rows.

set.seed(302)
analysis_data <- data.frame(
  rank = rep(seq_len(36), each = 2),
  outcome = rbinom(72, 1, seq(0.1, 0.85, length.out = 72)),
  predictor = rep(seq_len(12), 6),
  group = factor(rep(letters[1:3], each = 24)),
  weight = rep(c(1, 2, 5, 0), 18)
)
analysis_data$case_wt <- hardhat::importance_weights(analysis_data$weight)

metric_names <- c(
  "validation_gain", "relative_validation_gain",
  "training_gain", "relative_training_gain"
)
scenarios <- c(
  "weighted_formula", "unweighted_formula",
  "weighted_recipe", "repeated_cv", "bootstrap"
)
comparisons <- list()
selection_checks <- list()
prediction_grouping_checks <- list()

for (scenario in scenarios) {
  weighted <- scenario != "unweighted_formula"
  set.seed(50)
  folds <- if (scenario == "bootstrap") {
    rsample::bootstraps(analysis_data, times = 3)
  } else {
    rsample::vfold_cv(
      analysis_data, v = 3, repeats = if (scenario == "repeated_cv") 2 else 1
    )
  }

  for (model in c("tree", "forest")) {
    for (criterion in c("CI", "CIg", "CIc", "L")) {
      specification <- if (model == "tree") {
        parsnip::decision_tree(
          tree_depth = tune::tune(id = "depth"), min_n = 3
        )
      } else {
        parsnip::rand_forest(trees = 4, mtry = 2, min_n = tune::tune())
      }
      specification <- parsnip::set_engine(
        specification,
        "ineqTrees",
        rank_name = "rank",
        outcome_name = "outcome",
        type = criterion,
        minsplit = 6,
        minprob = 0
      )
      specification <- parsnip::set_mode(specification, "regression")
      model_workflow <- workflows::workflow()
      model_workflow <- workflows::add_model(model_workflow, specification)

      if (scenario == "weighted_recipe") {
        preprocessing <- recipes::recipe(
          outcome ~ rank + predictor + group + case_wt,
          data = analysis_data
        )
        preprocessing <- recipes::step_dummy(
          preprocessing, recipes::all_nominal_predictors()
        )
        model_workflow <- workflows::add_recipe(
          model_workflow, preprocessing
        )
      } else {
        model_workflow <- workflows::add_formula(
          model_workflow, outcome ~ rank + predictor + group
        )
      }
      if (weighted) {
        model_workflow <- workflows::add_case_weights(model_workflow, case_wt)
      }
      grid <- if (model == "tree") {
        data.frame(depth = c(1L, 2L))
      } else {
        data.frame(min_n = c(3L, 8L))
      }

      metric_set <- ci_tuning_metric_set(
        analysis_data,
        rank_name = "rank",
        case_weight_name = if (weighted) "weight" else NULL,
        type = criterion,
        metrics = metric_names
      )
      set.seed(714)
      tuned <- tune::tune_grid(
        model_workflow,
        resamples = folds,
        grid = grid,
        metrics = metric_set,
        control = tune::control_grid(
          allow_par = FALSE,
          save_pred = TRUE,
          extract = workflows::extract_fit_engine
        )
      )
      stopifnot(nrow(tune::collect_notes(tuned)) == 0L)
      scores <- tune::collect_metrics(tuned, summarize = FALSE)
      saved <- tune::collect_predictions(tuned)
      fold_columns <- intersect(c("id", "id2"), names(folds))
      label_fold <- function(data) {
        do.call(paste, c(data[, fold_columns, drop = FALSE], sep = "/"))
      }
      score_fold <- label_fold(scores)
      prediction_fold <- label_fold(saved)
      rescored <- metric_set(saved, truth = outcome, estimate = .pred)
      score_keys <- paste(score_fold, scores$.config, scores$.metric)
      rescored_keys <- paste(
        label_fold(rescored), rescored$.config, rescored$.metric
      )
      stopifnot(nrow(rescored) == nrow(scores))
      stopifnot(isTRUE(all.equal(
        rescored$.estimate[match(score_keys, rescored_keys)],
        scores$.estimate,
        tolerance = 1e-12
      )))

      first_comparison <- length(comparisons) + 1L
      for (fold in seq_len(nrow(folds))) {
        training <- rsample::analysis(folds$splits[[fold]])
        fold_label <- label_fold(folds[fold, ])
        extracted <- tuned$.extracts[[fold]]

        for (candidate in seq_len(nrow(extracted))) {
          engine <- extracted$.extracts[[candidate]]
          configuration <- extracted$.config[candidate]
          predictions <- saved[
            prediction_fold == fold_label & saved$.config == configuration,
          ]
          assessment <- analysis_data[predictions$.row, , drop = FALSE]
          training_nodes <- attr(engine, "ci_training_diagnostics")$nodes
          assessment_gain <- reference_gain(
            assessment, predictions$.ci_node, criterion, weighted
          )
          risk_group_gain <- reference_gain(
            assessment, predictions$.pred, criterion, weighted
          )
          comparison_id <- length(prediction_grouping_checks) + 1L
          gain_difference <- abs(assessment_gain[1L] - risk_group_gain[1L])
          prediction_grouping_checks[[comparison_id]] <- data.frame(
            scenario = scenario, model = model, type = criterion,
            fold = fold_label, config = configuration,
            partition_gain = assessment_gain[1L],
            prediction_group_gain = risk_group_gain[1L],
            absolute_difference = gain_difference
          )
          training_gain <- reference_gain(
            training, training_nodes, criterion, weighted
          )
          expected <- c(assessment_gain, training_gain)

          rows <- score_fold == fold_label & scores$.config == configuration
          actual <- scores[rows, ]
          actual <- actual$.estimate[match(metric_names, actual$.metric)]
          stopifnot(length(actual) == 4L)
          stopifnot(identical(is.na(actual), is.na(unname(expected))))
          stopifnot(all(is.finite(actual[!is.na(actual)])))
          errors <- abs(actual - expected)
          errors[is.na(actual) & is.na(expected)] <- 0
          stopifnot(all(errors < 1e-12))

          comparisons[[length(comparisons) + 1L]] <- data.frame(
            scenario = scenario,
            model = model,
            type = criterion,
            fold = fold_label,
            config = configuration,
            metric = metric_names,
            reported = actual,
            reference = unname(expected),
            absolute_error = unname(errors)
          )
        }
      }

      scenario_rows <- do.call(rbind, comparisons[
        seq.int(first_comparison, length(comparisons))
      ])
      validation_rows <- scenario_rows[
        scenario_rows$metric == "validation_gain",
      ]
      means <- aggregate(reference ~ config, validation_rows, mean)
      selected <- tune::select_best(tuned, metric = "validation_gain")
      selected_mean <- means$reference[means$config == selected$.config]
      stopifnot(abs(selected_mean - max(means$reference)) < 1e-12)
      selection_checks[[length(selection_checks) + 1L]] <- data.frame(
        scenario = scenario, model = model, type = criterion,
        selected_config = selected$.config,
        independently_best_mean = max(means$reference)
      )
    }
  }
}

results <- do.call(rbind, comparisons)
summary <- aggregate(
  absolute_error ~ scenario + model + type + metric, results, max
)
write.csv(results, file.path(output_dir, "fold_scores.csv"), row.names = FALSE)
write.csv(summary, file.path(output_dir, "summary.csv"), row.names = FALSE)
write.csv(
  do.call(rbind, selection_checks),
  file.path(output_dir, "selection_checks.csv"),
  row.names = FALSE
)
write.csv(
  do.call(rbind, prediction_grouping_checks),
  file.path(output_dir, "prediction_grouping_checks.csv"),
  row.names = FALSE
)
writeLines(
  trimws(capture.output(sessionInfo()), which = "right"),
  file.path(output_dir, "session_info.txt")
)
cat(nrow(results), "fold-metric comparisons passed; maximum error:",
  max(results$absolute_error), "\n"
)

# Check the fit interface independently of tune. Numeric split variables avoid
# stochastic routing of factor levels absent from a forest member's sample.

direct_data <- analysis_data
direct_data$group_numeric <- as.integer(direct_data$group)
direct_checks <- list()
for (weighted in c(FALSE, TRUE)) {
  weights <- if (weighted) direct_data$weight else NULL
  for (model in c("tree", "forest")) {
    for (criterion in c("CI", "CIg", "CIc", "L")) {
      specification <- if (model == "tree") {
        parsnip::decision_tree(tree_depth = 2, min_n = 3)
      } else {
        parsnip::rand_forest(trees = 4, mtry = 2, min_n = 3)
      }
      specification <- parsnip::set_engine(
        specification,
        "ineqTrees",
        rank_name = "rank",
        outcome_name = "outcome",
        type = criterion,
        minsplit = 6,
        minprob = 0,
        maxdepth = 2
      )
      specification <- parsnip::set_mode(specification, "regression")
      set.seed(909)
      bridged <- parsnip::fit(
        specification,
        outcome ~ rank + predictor + group_numeric,
        data = direct_data,
        case_weights = if (weighted) {
          hardhat::importance_weights(weights)
        } else {
          NULL
        }
      )
      native_arguments <- list(
        formula = cbind(rank, outcome) ~ predictor + group_numeric,
        data = direct_data,
        rank_name = "rank",
        outcome_name = "outcome",
        weights = weights,
        type = criterion,
        control = ci_tree_control(
          minsplit = 6, minbucket = 3, minprob = 0, maxdepth = 2
        )
      )
      if (model == "forest") {
        native_arguments$ntree <- 4L
        native_arguments$mtry <- 2L
      }
      native_function <- if (model == "tree") ci_tree else ci_forest
      set.seed(909)
      native <- do.call(native_function, native_arguments)
      prediction_error <- max(abs(
        predict(bridged, new_data = direct_data)$.pred -
          as.numeric(predict(native, newdata = direct_data))
      ))
      node_error <- max(abs(
        predict(bridged, new_data = direct_data, type = "raw") -
          predict(native, newdata = direct_data, type = "node")
      ))
      stopifnot(prediction_error < 1e-12, node_error == 0)
      direct_checks[[length(direct_checks) + 1L]] <- data.frame(
        weighted = weighted, model = model, type = criterion,
        prediction_error = prediction_error, node_error = node_error
      )
    }
  }
}
write.csv(
  do.call(rbind, direct_checks),
  file.path(output_dir, "direct_fit_checks.csv"),
  row.names = FALSE
)
cat(length(direct_checks), "direct parsnip/native fit comparisons passed.\n")
