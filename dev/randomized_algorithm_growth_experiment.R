if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", export_all = FALSE)
} else {
  library(ineqTrees)
}

if (!requireNamespace("Rcpp", quietly = TRUE)) {
  stop("The Rcpp package is needed for the combined benchmark.", call. = FALSE)
}

Rcpp::sourceCpp(code = '
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <vector>
using namespace Rcpp;

namespace {

bool valid_scalar(double x) {
  return !NumericVector::is_na(x) && R_finite(x);
}

int type_to_code(std::string type) {
  if (type == "CI") return 1;
  if (type == "CIg") return 2;
  if (type == "CIc") return 3;
  if (type == "L") return 4;
  stop("Unknown CI type.");
}

double ci_score_membership(
    const std::vector<double>& rank,
    const std::vector<double>& outcome,
    const std::vector<double>& wt,
    const std::vector<int>& ses_ord,
    int split_pos,
    bool left_child,
    int type_code) {

  int n_valid = 0;
  double total_wt = 0.0;

  for (int idx : ses_ord) {
    const bool in_child = left_child ? idx <= split_pos : idx > split_pos;
    if (!in_child) continue;
    if (valid_scalar(rank[idx]) &&
        valid_scalar(outcome[idx]) &&
        valid_scalar(wt[idx]) &&
        wt[idx] > 0.0) {
      ++n_valid;
      total_wt += wt[idx];
    }
  }

  if (n_valid <= 1 || !R_finite(total_wt) || total_wt <= 0.0) {
    return 0.0;
  }

  if (type_code == 4) {
    double mu_s = 0.0;
    for (int idx : ses_ord) {
      const bool in_child = left_child ? idx <= split_pos : idx > split_pos;
      if (!in_child || !valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) || !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      mu_s += wt[idx] * rank[idx] / total_wt;
    }
    if (!R_finite(mu_s) || std::abs(mu_s) <= DBL_EPSILON) {
      return 0.0;
    }

    double l_index = 0.0;
    for (int idx : ses_ord) {
      const bool in_child = left_child ? idx <= split_pos : idx > split_pos;
      if (!in_child || !valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) || !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      const double p = wt[idx] / total_wt;
      l_index += p * ((rank[idx] - mu_s) / mu_s) * outcome[idx];
    }
    if (!R_finite(l_index)) return 0.0;
    return std::abs(l_index);
  }

  double cumulative_wt = 0.0;
  double sum_wt2 = 0.0;
  double mean_rank = 0.0;
  double mean_outcome = 0.0;
  double min_outcome = R_PosInf;
  double max_outcome = R_NegInf;

  for (int idx : ses_ord) {
    const bool in_child = left_child ? idx <= split_pos : idx > split_pos;
    if (!in_child || !valid_scalar(rank[idx]) ||
        !valid_scalar(outcome[idx]) || !valid_scalar(wt[idx]) ||
        wt[idx] <= 0.0) {
      continue;
    }

    const double w_norm = wt[idx] / total_wt;
    const double rank_w = cumulative_wt + w_norm / 2.0;
    cumulative_wt += w_norm;
    sum_wt2 += w_norm * w_norm;
    mean_rank += w_norm * rank_w;
    mean_outcome += w_norm * outcome[idx];
    min_outcome = std::min(min_outcome, outcome[idx]);
    max_outcome = std::max(max_outcome, outcome[idx]);
  }

  const double cov_denom = 1.0 - sum_wt2;
  if (!R_finite(cov_denom) || cov_denom <= 0.0) {
    return 0.0;
  }

  cumulative_wt = 0.0;
  double cov12 = 0.0;
  for (int idx : ses_ord) {
    const bool in_child = left_child ? idx <= split_pos : idx > split_pos;
    if (!in_child || !valid_scalar(rank[idx]) ||
        !valid_scalar(outcome[idx]) || !valid_scalar(wt[idx]) ||
        wt[idx] <= 0.0) {
      continue;
    }

    const double w_norm = wt[idx] / total_wt;
    const double rank_w = cumulative_wt + w_norm / 2.0;
    cumulative_wt += w_norm;
    cov12 += w_norm * (rank_w - mean_rank) *
      (outcome[idx] - mean_outcome);
  }
  cov12 /= cov_denom;

  if (type_code == 1) {
    if (!R_finite(mean_outcome) || std::abs(mean_outcome) <= DBL_EPSILON) {
      return 0.0;
    }
    return std::abs(2.0 * cov12 / mean_outcome);
  }

  if (type_code == 2) {
    return std::abs(2.0 * cov12);
  }

  const double range = max_outcome - min_outcome;
  if (!R_finite(range) || range <= DBL_EPSILON) {
    return 0.0;
  }
  return 4.0 * std::abs(2.0 * cov12) / range;
}

}

// [[Rcpp::export]]
List best_numeric_split_ordered_cpp_engine(
    NumericVector x,
    NumericMatrix y,
    NumericVector wt,
    double minbucket,
    double minprob,
    std::string type) {

  const int n = x.size();
  if (y.nrow() != n || y.ncol() != 2 || wt.size() != n) {
    stop("Inputs have incompatible sizes.");
  }

  std::vector<int> x_ord(n);
  std::iota(x_ord.begin(), x_ord.end(), 0);
  std::stable_sort(x_ord.begin(), x_ord.end(), [&](int a, int b) {
    return x[a] < x[b];
  });

  std::vector<double> xs(n), rank(n), outcome(n), weight(n);
  for (int i = 0; i < n; ++i) {
    const int src = x_ord[i];
    xs[i] = x[src];
    rank[i] = y(src, 0);
    outcome[i] = y(src, 1);
    weight[i] = wt[src];
  }

  std::vector<double> cum_wt(n);
  double total_wt = 0.0;
  for (int i = 0; i < n; ++i) {
    total_wt += weight[i];
    cum_wt[i] = total_wt;
  }

  if (!R_finite(total_wt) || total_wt <= 0.0) {
    return List::create(
      _["gain"] = R_NegInf,
      _["cutpoint"] = NA_REAL,
      _["left"] = LogicalVector(n, false)
    );
  }

  std::vector<int> ses_ord(n);
  std::iota(ses_ord.begin(), ses_ord.end(), 0);
  std::stable_sort(ses_ord.begin(), ses_ord.end(), [&](int a, int b) {
    return rank[a] < rank[b];
  });

  const int type_code = type_to_code(type);
  const double ci_parent = ci_score_membership(
    rank, outcome, weight, ses_ord, n - 1, true, type_code
  );

  double best_gain = R_NegInf;
  double best_cutpoint = NA_REAL;
  int best_pos = -1;

  for (int pos = 0; pos < n - 1; ++pos) {
    if (xs[pos] == xs[pos + 1]) continue;

    const double wl = cum_wt[pos];
    const double wr = total_wt - wl;

    if (wl < minbucket || wr < minbucket) continue;
    if ((wl / total_wt) < minprob || (wr / total_wt) < minprob) continue;

    const double ci_left = ci_score_membership(
      rank, outcome, weight, ses_ord, pos, true, type_code
    );
    const double ci_right = ci_score_membership(
      rank, outcome, weight, ses_ord, pos, false, type_code
    );
    const double gain = ci_parent -
      ((wl / total_wt) * ci_left + (wr / total_wt) * ci_right);

    if (gain > best_gain) {
      best_gain = gain;
      best_cutpoint = (xs[pos] + xs[pos + 1]) / 2.0;
      best_pos = pos;
    }
  }

  LogicalVector left(n, false);
  if (best_pos >= 0) {
    for (int i = 0; i <= best_pos; ++i) {
      left[x_ord[i]] = true;
    }
  }

  return List::create(
    _["gain"] = best_gain,
    _["cutpoint"] = best_cutpoint,
    _["left"] = left
  );
}
')

.ci_score_from_order <- function(y, wt, ord, type) {
  n <- length(ord)
  if (n <= 1L) return(0)

  rank <- y[, 1]
  outcome <- y[, 2]
  wt <- as.numeric(wt)

  ok <- !is.na(rank[ord]) & !is.na(outcome[ord]) & !is.na(wt[ord]) & wt[ord] > 0
  ord <- ord[ok]
  n <- length(ord)
  if (n <= 1L) return(0)

  total_wt <- sum(wt[ord])
  if (!is.finite(total_wt) || total_wt <= 0) return(0)

  if (identical(type, "L")) {
    mu_s <- sum(wt[ord] * rank[ord]) / total_wt
    if (!is.finite(mu_s) || abs(mu_s) <= .Machine$double.eps) return(0)
    p <- wt[ord] / total_wt
    l_index <- sum(p * ((rank[ord] - mu_s) / mu_s) * outcome[ord])
    if (!is.finite(l_index)) return(0)
    return(abs(l_index))
  }

  wt_norm <- wt[ord] / total_wt
  rank_ord <- c(0, cumsum(wt_norm[-n])) + wt_norm / 2
  mean_rank <- sum(wt_norm * rank_ord)
  mean_outcome <- sum(wt_norm * outcome[ord])
  cov_denom <- 1 - sum(wt_norm^2)
  if (!is.finite(cov_denom) || cov_denom <= 0) return(0)

  cov12 <- sum(wt_norm * (rank_ord - mean_rank) *
    (outcome[ord] - mean_outcome)) / cov_denom

  if (identical(type, "CI")) {
    if (!is.finite(mean_outcome) || abs(mean_outcome) <= .Machine$double.eps) return(0)
    return(abs(2 * cov12 / mean_outcome))
  }
  if (identical(type, "CIg")) return(abs(2 * cov12))

  rng <- max(outcome[ord], na.rm = TRUE) - min(outcome[ord], na.rm = TRUE)
  if (!is.finite(rng) || rng <= .Machine$double.eps) return(0)
  4 * abs(2 * cov12) / rng
}

best_numeric_split_ordered_once <- function(x, y, wt, varid, ctrl,
                                            type = "CI") {
  ord_x <- order(x, method = "radix")
  x <- x[ord_x]
  y <- y[ord_x, , drop = FALSE]
  wt <- wt[ord_x]

  cut_pos <- which(diff(x) != 0)
  if (!length(cut_pos)) return(NULL)

  row_id <- seq_along(x)
  ses_ord <- order(y[, 1], method = "radix")
  ci_parent <- .ci_score_from_order(y, wt, ses_ord, type)
  cum_wt <- cumsum(wt)
  total_wt <- cum_wt[length(cum_wt)]
  gains <- rep(-Inf, length(cut_pos))
  best_left <- NULL

  for (k in seq_along(cut_pos)) {
    pos <- cut_pos[k]
    wl <- cum_wt[pos]
    wr <- total_wt - wl

    if (wl < ctrl$minbucket || wr < ctrl$minbucket) next
    if ((wl / total_wt) < ctrl$minprob || (wr / total_wt) < ctrl$minprob) next

    left <- row_id <= pos
    left_ord <- ses_ord[left[ses_ord]]
    right_ord <- ses_ord[!left[ses_ord]]

    ci_left <- .ci_score_from_order(y, wt, left_ord, type)
    ci_right <- .ci_score_from_order(y, wt, right_ord, type)
    gains[k] <- ci_parent - ((wl / total_wt) * ci_left + (wr / total_wt) * ci_right)
  }

  if (!any(is.finite(gains))) return(NULL)

  best_index <- which.max(gains)
  best_k <- cut_pos[best_index]
  left <- row_id <= best_k
  left_original <- logical(length(left))
  left_original[ord_x] <- left

  list(
    gain = gains[best_index],
    cutpoint = (x[best_k] + x[best_k + 1L]) / 2,
    left = left_original
  )
}

best_numeric_split_current_engine <- function(x, y, wt, ctrl, type = "CI") {
  best_numeric_split(
    x = x,
    y = y,
    wt = wt,
    varid = 1L,
    ctrl = ctrl,
    ci_fun = ci_factory(type),
    return = "candidate"
  )
}

best_numeric_split_cpp_ordered_engine <- function(x, y, wt, ctrl, type = "CI") {
  out <- best_numeric_split_ordered_cpp_engine(
    x = x,
    y = y,
    wt = wt,
    minbucket = ctrl$minbucket,
    minprob = ctrl$minprob,
    type = type
  )
  if (!is.finite(out$gain)) return(NULL)
  list(gain = out$gain, cutpoint = out$cutpoint, left = as.logical(out$left))
}

fit_numeric_tree_engine <- function(x, y, wt, rows, depth, ctrl, method) {
  if (depth >= ctrl$maxdepth || sum(wt[rows], na.rm = TRUE) < ctrl$minsplit) {
    return(1L)
  }

  split <- switch(
    method,
    current = best_numeric_split_current_engine(x[rows], y[rows, , drop = FALSE], wt[rows], ctrl),
    ordered_once = best_numeric_split_ordered_once(x[rows], y[rows, , drop = FALSE], wt[rows], 1L, ctrl),
    ordered_cpp = best_numeric_split_cpp_ordered_engine(x[rows], y[rows, , drop = FALSE], wt[rows], ctrl),
    stop("unknown method", call. = FALSE)
  )

  if (is.null(split) || !is.finite(split$gain) || split$gain <= ctrl$min_gain ||
      !any(split$left) || all(split$left)) {
    return(1L)
  }

  1L +
    fit_numeric_tree_engine(x, y, wt, rows[split$left], depth + 1L, ctrl, method) +
    fit_numeric_tree_engine(x, y, wt, rows[!split$left], depth + 1L, ctrl, method)
}

fit_numeric_forest_engine <- function(x, y, wt, ctrl, ntree, method,
                                      fraction = 0.632) {
  n <- length(x)
  sizes <- integer(ntree)
  for (b in seq_len(ntree)) {
    rows <- sample.int(n, size = max(1L, ceiling(n * fraction)), replace = FALSE)
    sizes[b] <- fit_numeric_tree_engine(x, y, wt, rows, 0L, ctrl, method)
  }
  sizes
}

time_once <- function(expr, env = parent.frame()) {
  expr <- substitute(expr)
  gc()
  unname(system.time(eval(expr, envir = env))[["elapsed"]])
}

bench_randomized <- function(label, methods, sizes, reps, expr_fun) {
  design <- expand.grid(
    rep = seq_len(reps),
    n = sizes,
    method = methods,
    stringsAsFactors = FALSE
  )
  design <- design[sample.int(nrow(design)), , drop = FALSE]

  rows <- lapply(seq_len(nrow(design)), function(i) {
    this <- design[i, ]
    elapsed <- expr_fun(n = this$n, method = this$method, rep = this$rep)
    data.frame(
      benchmark = label,
      rep = this$rep,
      n = this$n,
      method = this$method,
      elapsed_sec = elapsed,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

summarise_growth <- function(results) {
  med <- aggregate(
    elapsed_sec ~ benchmark + method + n,
    data = results,
    FUN = median
  )
  names(med)[names(med) == "elapsed_sec"] <- "median_sec"

  growth <- do.call(rbind, lapply(split(med, paste(med$benchmark, med$method)), function(d) {
    d <- d[order(d$n), ]
    fit <- stats::lm(log(median_sec) ~ log(n), data = d)
    data.frame(
      benchmark = d$benchmark[1L],
      method = d$method[1L],
      alpha = unname(stats::coef(fit)[["log(n)"]]),
      baseline_n = d$n[1L],
      largest_n = d$n[nrow(d)],
      baseline_sec = d$median_sec[1L],
      largest_sec = d$median_sec[nrow(d)],
      stringsAsFactors = FALSE
    )
  }))

  list(medians = med, growth = growth)
}

data("kenya", package = "ineqTrees")
bench_vars <- c("wealth", "deadu5_num", "sample_weight")
base_data <- kenya[stats::complete.cases(kenya[, bench_vars]), bench_vars]

make_sample <- function(n, rep) {
  set.seed(20260514 + 1000L * rep + n)
  d <- base_data[sample.int(nrow(base_data), n), , drop = FALSE]
  list(
    x = d$sample_weight,
    y = cbind(rank = d$wealth, outcome = d$deadu5_num),
    wt = rep(1, n)
  )
}

ctrl <- ci_tree_control(
  minsplit = 100L,
  minbucket = 50L,
  minprob = 0.01,
  maxdepth = 3L,
  min_gain = 0
)

methods <- c("current", "ordered_once", "ordered_cpp")

split_results <- bench_randomized(
  label = "numeric_split",
  methods = methods,
  sizes = c(500L, 1000L, 2000L, 4000L),
  reps = 3L,
  expr_fun = function(n, method, rep) {
    s <- make_sample(n, rep)
    time_once(switch(
      method,
      current = best_numeric_split_current_engine(s$x, s$y, s$wt, ctrl),
      ordered_once = best_numeric_split_ordered_once(s$x, s$y, s$wt, 1L, ctrl),
      ordered_cpp = best_numeric_split_cpp_ordered_engine(s$x, s$y, s$wt, ctrl)
    ))
  }
)

forest_results <- bench_randomized(
  label = "numeric_forest_engine_ntree10",
  methods = methods,
  sizes = c(500L, 1000L, 2000L),
  reps = 2L,
  expr_fun = function(n, method, rep) {
    s <- make_sample(n, rep)
    set.seed(20260514 + 2000L * rep + n)
    time_once(fit_numeric_forest_engine(
      x = s$x,
      y = s$y,
      wt = s$wt,
      ctrl = ctrl,
      ntree = 10L,
      method = method
    ))
  }
)

results <- rbind(split_results, forest_results)
summary <- summarise_growth(results)

print(summary$medians)
print(summary$growth)

utils::write.csv(
  results,
  file = "dev/randomized_algorithm_growth_raw.csv",
  row.names = FALSE
)
utils::write.csv(
  summary$medians,
  file = "dev/randomized_algorithm_growth_medians.csv",
  row.names = FALSE
)
utils::write.csv(
  summary$growth,
  file = "dev/randomized_algorithm_growth_rates.csv",
  row.names = FALSE
)
