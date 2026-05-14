if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", export_all = FALSE)
} else {
  library(ineqTrees)
}

.ci_score_from_order <- function(y, wt, ord, type) {
  n <- length(ord)
  if (n <= 1L) {
    return(0)
  }

  rank <- y[, 1]
  outcome <- y[, 2]
  wt <- as.numeric(wt)

  ok <- !is.na(rank[ord]) & !is.na(outcome[ord]) & !is.na(wt[ord]) & wt[ord] > 0
  ord <- ord[ok]
  n <- length(ord)
  if (n <= 1L) {
    return(0)
  }

  total_wt <- sum(wt[ord])
  if (!is.finite(total_wt) || total_wt <= 0) {
    return(0)
  }

  if (identical(type, "L")) {
    mu_s <- sum(wt[ord] * rank[ord]) / total_wt
    if (!is.finite(mu_s) || abs(mu_s) <= .Machine$double.eps) {
      return(0)
    }

    p <- wt[ord] / total_wt
    l_index <- sum(p * ((rank[ord] - mu_s) / mu_s) * outcome[ord])
    if (!is.finite(l_index)) {
      return(0)
    }
    return(abs(l_index))
  }

  wt_norm <- wt[ord] / total_wt
  rank_ord <- c(0, cumsum(wt_norm[-n])) + wt_norm / 2

  mean_rank <- sum(wt_norm * rank_ord)
  mean_outcome <- sum(wt_norm * outcome[ord])
  cov_denom <- 1 - sum(wt_norm^2)

  if (!is.finite(cov_denom) || cov_denom <= 0) {
    return(0)
  }

  cov12 <- sum(wt_norm * (rank_ord - mean_rank) *
    (outcome[ord] - mean_outcome)) / cov_denom

  if (identical(type, "CI")) {
    if (!is.finite(mean_outcome) || abs(mean_outcome) <= .Machine$double.eps) {
      return(0)
    }
    return(abs(2 * cov12 / mean_outcome))
  }

  if (identical(type, "CIg")) {
    return(abs(2 * cov12))
  }

  rng <- max(outcome[ord], na.rm = TRUE) - min(outcome[ord], na.rm = TRUE)
  if (!is.finite(rng) || rng <= .Machine$double.eps) {
    return(0)
  }

  4 * abs(2 * cov12) / rng
}

.weighted_ci_gain_from_orders <- function(y, wt, left_ord, right_ord, ci_parent, type) {
  wl <- sum(wt[left_ord], na.rm = TRUE)
  wr <- sum(wt[right_ord], na.rm = TRUE)
  wtot <- wl + wr

  if (wl <= 0 || wr <= 0 || wtot <= 0) {
    return(-Inf)
  }

  ci_left <- .ci_score_from_order(y, wt, left_ord, type)
  ci_right <- .ci_score_from_order(y, wt, right_ord, type)

  ci_parent - ((wl / wtot) * ci_left + (wr / wtot) * ci_right)
}

best_numeric_split_ordered_once <- function(
    x,
    y,
    wt,
    varid,
    ctrl,
    type = c("CI", "CIg", "CIc", "L"),
    return = c("split", "candidate")) {
  type <- match.arg(type)
  return <- match.arg(return)

  ord_x <- order(x, method = "radix")
  x <- x[ord_x]
  y <- y[ord_x, , drop = FALSE]
  wt <- wt[ord_x]

  cut_pos <- which(diff(x) != 0)
  if (!length(cut_pos)) {
    return(NULL)
  }

  gains <- rep(-Inf, length(cut_pos))
  row_id <- seq_along(x)
  ses_ord <- order(y[, 1], method = "radix")
  ci_parent <- .ci_score_from_order(y, wt, ses_ord, type)
  cum_wt <- cumsum(wt)
  total_wt <- cum_wt[length(cum_wt)]

  for (k in seq_along(cut_pos)) {
    pos <- cut_pos[k]
    wl <- cum_wt[pos]
    wr <- total_wt - wl

    if (wl < ctrl$minbucket || wr < ctrl$minbucket) next
    if ((wl / total_wt) < ctrl$minprob ||
        (wr / total_wt) < ctrl$minprob) {
      next
    }

    left <- row_id <= pos
    left_ord <- ses_ord[left[ses_ord]]
    right_ord <- ses_ord[!left[ses_ord]]

    gains[k] <- .weighted_ci_gain_from_orders(
      y = y,
      wt = wt,
      left_ord = left_ord,
      right_ord = right_ord,
      ci_parent = ci_parent,
      type = type
    )
  }

  if (!any(is.finite(gains))) {
    return(NULL)
  }

  best_index <- which.max(gains)
  best_k <- cut_pos[best_index]
  cut <- (x[best_k] + x[best_k + 1L]) / 2
  left <- row_id <= best_k
  left_original <- logical(length(left))
  left_original[ord_x] <- left

  sp <- partykit::partysplit(
    varid = as.integer(varid),
    breaks = cut,
    index = 1:2
  )

  if (identical(return, "split")) {
    return(sp)
  }

  list(
    gain = gains[best_index],
    varid = as.integer(varid),
    partysplit = sp,
    split = sp,
    left = left_original,
    type = "numeric",
    cutpoint = cut
  )
}

bench_time <- function(label, expr, reps = 5L, env = parent.frame()) {
  expr <- substitute(expr)
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
    all_sec = paste(round(times, 4), collapse = ", "),
    stringsAsFactors = FALSE
  )
}

data("kenya", package = "ineqTrees")

bench_vars <- c(
  "wealth",
  "deadu5_num",
  "sample_weight"
)

bench_data <- kenya[stats::complete.cases(kenya[, bench_vars]), bench_vars]
set.seed(20260514)
bench_n <- min(5000L, nrow(bench_data))
bench_data <- bench_data[sample.int(nrow(bench_data), bench_n), , drop = FALSE]

y_mat <- cbind(rank = bench_data$wealth, outcome = bench_data$deadu5_num)
wt_vec <- rep(1, nrow(bench_data))
ctrl <- ci_tree_control(
  minsplit = 200L,
  minbucket = 100L,
  minprob = 0.01,
  maxdepth = 4L,
  min_gain = 0
)
ci_fun <- ci_factory("CI")

current <- best_numeric_split(
  x = bench_data$sample_weight,
  y = y_mat,
  wt = wt_vec,
  varid = 1L,
  ctrl = ctrl,
  ci_fun = ci_fun,
  return = "candidate"
)

ordered_once <- best_numeric_split_ordered_once(
  x = bench_data$sample_weight,
  y = y_mat,
  wt = wt_vec,
  varid = 1L,
  ctrl = ctrl,
  type = "CI",
  return = "candidate"
)

correctness <- data.frame(
  check = c("numeric_split_gain", "numeric_split_cutpoint", "left_membership"),
  current = c(current$gain, current$cutpoint, NA_real_),
  ordered_once = c(ordered_once$gain, ordered_once$cutpoint, NA_real_),
  abs_diff = c(
    abs(current$gain - ordered_once$gain),
    abs(current$cutpoint - ordered_once$cutpoint),
    sum(current$left != ordered_once$left)
  )
)

timings <- rbind(
  bench_time(
    "best_numeric_split_current",
    best_numeric_split(
      x = bench_data$sample_weight,
      y = y_mat,
      wt = wt_vec,
      varid = 1L,
      ctrl = ctrl,
      ci_fun = ci_fun,
      return = "candidate"
    ),
    reps = 3L
  ),
  bench_time(
    "best_numeric_split_ordered_once",
    best_numeric_split_ordered_once(
      x = bench_data$sample_weight,
      y = y_mat,
      wt = wt_vec,
      varid = 1L,
      ctrl = ctrl,
      type = "CI",
      return = "candidate"
    ),
    reps = 3L
  )
)

print(correctness)
print(timings)

utils::write.csv(
  correctness,
  file = "dev/ordered_ci_scoring_experiment_correctness.csv",
  row.names = FALSE
)
utils::write.csv(
  timings,
  file = "dev/ordered_ci_scoring_experiment_timings.csv",
  row.names = FALSE
)
