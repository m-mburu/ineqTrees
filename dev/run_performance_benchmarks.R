if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", export_all = FALSE)
} else {
  library(ineqTrees)
}

set.seed(20260510)

bench_time <- function(label, expr, reps = 3L, env = parent.frame()) {
  expr <- substitute(expr)
  reps <- as.integer(reps)
  if (length(reps) != 1L || is.na(reps) || reps <= 0L) {
    stop("`reps` must be a positive integer.", call. = FALSE)
  }

  times <- numeric(reps)
  for (i in seq_len(reps)) {
    gc()
    times[i] <- unname(system.time(eval(expr, envir = env))[["elapsed"]])
  }

  data.frame(
    label = label,
    reps = reps,
    median_sec = stats::median(times),
    min_sec = min(times),
    max_sec = max(times),
    all_sec = paste(round(times, 3), collapse = ", "),
    stringsAsFactors = FALSE
  )
}

profile_expr <- function(label, expr, out_dir = "dev/profiles",
                         interval = 0.01, env = parent.frame()) {
  expr <- substitute(expr)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  profile_file <- file.path(out_dir, paste0(label, ".out"))
  summary_file <- file.path(out_dir, paste0(label, "_summary.txt"))

  gc()
  Rprof(filename = profile_file, interval = interval)
  on.exit(Rprof(NULL), add = TRUE)
  eval(expr, envir = env)
  Rprof(NULL)

  summary <- summaryRprof(profile_file)
  capture.output(summary, file = summary_file)

  by_self <- as.data.frame(summary$by.self)
  by_self$function_name <- rownames(by_self)
  rownames(by_self) <- NULL

  by_total <- as.data.frame(summary$by.total)
  by_total$function_name <- rownames(by_total)
  rownames(by_total) <- NULL

  list(
    label = label,
    profile_file = profile_file,
    summary_file = summary_file,
    by_self = by_self,
    by_total = by_total
  )
}

memory_expr <- function(label, expr, env = parent.frame()) {
  expr <- substitute(expr)

  if (!requireNamespace("lobstr", quietly = TRUE)) {
    return(data.frame(
      label = label,
      lobstr_available = FALSE,
      mem_before_bytes = NA_real_,
      mem_after_bytes = NA_real_,
      mem_change_bytes = NA_real_,
      result_size_bytes = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  gc()
  before <- lobstr::mem_used()
  result <- eval(expr, envir = env)
  after <- lobstr::mem_used()
  result_size <- lobstr::obj_size(result)

  data.frame(
    label = label,
    lobstr_available = TRUE,
    mem_before_bytes = as.numeric(before),
    mem_after_bytes = as.numeric(after),
    mem_change_bytes = as.numeric(after - before),
    result_size_bytes = as.numeric(result_size),
    stringsAsFactors = FALSE
  )
}

data("kenya", package = "ineqTrees")

bench_vars <- c(
  "wealth",
  "deadu5_num",
  "rural",
  "ed",
  "reg",
  "unskilled",
  "sample_weight"
)

bench_data <- kenya[stats::complete.cases(kenya[, bench_vars]), bench_vars]
bench_n <- min(5000L, nrow(bench_data))
bench_data <- bench_data[sample.int(nrow(bench_data), bench_n), , drop = FALSE]

y_mat <- cbind(
  rank = bench_data$wealth,
  outcome = bench_data$deadu5_num
)
wt_vec <- rep(1, nrow(bench_data))
ci_fun <- ci_factory("CI")

tree_formula <- cbind(wealth, deadu5_num) ~ rural + ed + reg + unskilled
tree_control <- ci_tree_control(
  minsplit = 200L,
  minbucket = 100L,
  minprob = 0.01,
  maxdepth = 4L,
  min_gain = 0
)

profile_n <- min(2500L, nrow(bench_data))
profile_data <- bench_data[seq_len(profile_n), , drop = FALSE]
profile_y <- cbind(
  rank = profile_data$wealth,
  outcome = profile_data$deadu5_num
)
profile_wt <- rep(1, nrow(profile_data))

profile_results <- list(
  rank_wt = profile_expr(
    "rank_wt",
    rank_wt(profile_data$wealth, profile_wt)
  ),
  ci_factory_score = profile_expr(
    "ci_factory_score",
    ci_fun(profile_y, profile_wt)
  ),
  weighted_ci_gain = profile_expr(
    "weighted_ci_gain",
    weighted_ci_gain(
      y = profile_y,
      wt = profile_wt,
      left = profile_data$sample_weight <= stats::median(profile_data$sample_weight),
      ci_fun = ci_fun
    )
  ),
  best_numeric_split = profile_expr(
    "best_numeric_split",
    best_numeric_split(
      x = profile_data$sample_weight,
      y = profile_y,
      wt = profile_wt,
      varid = 1L,
      ctrl = tree_control,
      ci_fun = ci_fun,
      return = "candidate"
    )
  ),
  best_factor_split = profile_expr(
    "best_factor_split",
    best_factor_split(
      x_full = profile_data$reg,
      keep = rep(TRUE, nrow(profile_data)),
      y_full = profile_y,
      wt_full = profile_wt,
      varid = 1L,
      ctrl = tree_control,
      ci_fun = ci_fun,
      return = "candidate"
    )
  ),
  ctree_ci = profile_expr(
    "ctree_ci",
    ctree_ci(
      formula = tree_formula,
      data = profile_data,
      rank_name = "wealth",
      outcome_name = "deadu5_num",
      control = tree_control,
      type = "CI"
    )
  ),
  cf_ci = profile_expr(
    "cf_ci_ntree_10",
    cf_ci(
      formula = tree_formula,
      data = profile_data,
      rank_name = "wealth",
      outcome_name = "deadu5_num",
      control = tree_control,
      ntree = 10L,
      mtry = 2L,
      type = "CI"
    )
  )
)

top_self <- do.call(
  rbind,
  lapply(profile_results, function(x) {
    if (!nrow(x$by_self)) {
      return(data.frame(
        self.time = NA_real_,
        self.pct = NA_real_,
        total.time = NA_real_,
        total.pct = NA_real_,
        function_name = NA_character_,
        profile = x$label,
        stringsAsFactors = FALSE
      ))
    }
    out <- head(x$by_self, 15L)
    out$profile <- x$label
    out
  })
)

utils::write.csv(
  top_self,
  file = "dev/profile_top_by_self.csv",
  row.names = FALSE
)

memory_results <- rbind(
  memory_expr(
    "rank_wt",
    rank_wt(profile_data$wealth, profile_wt)
  ),
  memory_expr(
    "ci_factory_score",
    ci_fun(profile_y, profile_wt)
  ),
  memory_expr(
    "weighted_ci_gain",
    weighted_ci_gain(
      y = profile_y,
      wt = profile_wt,
      left = profile_data$sample_weight <= stats::median(profile_data$sample_weight),
      ci_fun = ci_fun
    )
  ),
  memory_expr(
    "best_numeric_split",
    best_numeric_split(
      x = profile_data$sample_weight,
      y = profile_y,
      wt = profile_wt,
      varid = 1L,
      ctrl = tree_control,
      ci_fun = ci_fun,
      return = "candidate"
    )
  ),
  memory_expr(
    "best_factor_split",
    best_factor_split(
      x_full = profile_data$reg,
      keep = rep(TRUE, nrow(profile_data)),
      y_full = profile_y,
      wt_full = profile_wt,
      varid = 1L,
      ctrl = tree_control,
      ci_fun = ci_fun,
      return = "candidate"
    )
  ),
  memory_expr(
    "ctree_ci",
    ctree_ci(
      formula = tree_formula,
      data = profile_data,
      rank_name = "wealth",
      outcome_name = "deadu5_num",
      control = tree_control,
      type = "CI"
    )
  ),
  memory_expr(
    "cf_ci_ntree_10",
    cf_ci(
      formula = tree_formula,
      data = profile_data,
      rank_name = "wealth",
      outcome_name = "deadu5_num",
      control = tree_control,
      ntree = 10L,
      mtry = 2L,
      type = "CI"
    )
  )
)

utils::write.csv(
  memory_results,
  file = "dev/profile_memory_lobstr.csv",
  row.names = FALSE
)

baseline_results <- rbind(
  bench_time(
    "best_numeric_split_sample_weight",
    best_numeric_split(
      x = bench_data$sample_weight,
      y = y_mat,
      wt = wt_vec,
      varid = 1L,
      ctrl = tree_control,
      ci_fun = ci_fun,
      return = "candidate"
    )
  ),
  bench_time(
    "best_factor_split_reg",
    best_factor_split(
      x_full = bench_data$reg,
      keep = rep(TRUE, nrow(bench_data)),
      y_full = y_mat,
      wt_full = wt_vec,
      varid = 1L,
      ctrl = tree_control,
      ci_fun = ci_fun,
      return = "candidate"
    )
  ),
  bench_time(
    "ctree_ci_representative",
    ctree_ci(
      formula = tree_formula,
      data = bench_data,
      rank_name = "wealth",
      outcome_name = "deadu5_num",
      control = tree_control,
      type = "CI"
    ),
    reps = 3L
  ),
  bench_time(
    "cf_ci_ntree_20",
    cf_ci(
      formula = tree_formula,
      data = bench_data,
      rank_name = "wealth",
      outcome_name = "deadu5_num",
      control = tree_control,
      ntree = 20L,
      mtry = 2L,
      type = "CI"
    ),
    reps = 1L
  )
)

print(baseline_results)
print(top_self)
print(memory_results)
utils::write.csv(
  baseline_results,
  file = "dev/performance_baseline_results.csv",
  row.names = FALSE
)
