if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", export_all = FALSE)
} else {
  library(ineqTrees)
}

if (!requireNamespace("Rcpp", quietly = TRUE)) {
  stop("The Rcpp package is needed for this experiment.", call. = FALSE)
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

double ci_score_segment(
    const std::vector<double>& rank,
    const std::vector<double>& outcome,
    const std::vector<double>& wt,
    int begin,
    int end,
    int type_code) {

  std::vector<int> rows;
  rows.reserve(std::max(0, end - begin));
  double total_wt = 0.0;

  for (int i = begin; i < end; ++i) {
    if (valid_scalar(rank[i]) &&
        valid_scalar(outcome[i]) &&
        valid_scalar(wt[i]) &&
        wt[i] > 0.0) {
      rows.push_back(i);
      total_wt += wt[i];
    }
  }

  const int n = rows.size();
  if (n <= 1 || !R_finite(total_wt) || total_wt <= 0.0) {
    return 0.0;
  }

  if (type_code == 4) {
    double mu_s = 0.0;
    for (int idx : rows) {
      mu_s += wt[idx] * rank[idx] / total_wt;
    }
    if (!R_finite(mu_s) || std::abs(mu_s) <= DBL_EPSILON) {
      return 0.0;
    }

    double l_index = 0.0;
    for (int idx : rows) {
      const double p = wt[idx] / total_wt;
      l_index += p * ((rank[idx] - mu_s) / mu_s) * outcome[idx];
    }
    if (!R_finite(l_index)) {
      return 0.0;
    }
    return std::abs(l_index);
  }

  std::stable_sort(
    rows.begin(),
    rows.end(),
    [&](int a, int b) {
      return rank[a] < rank[b];
    }
  );

  std::vector<double> rank_w(rank.size(), 0.0);
  double cumulative_wt = 0.0;
  double sum_wt2 = 0.0;

  for (int idx : rows) {
    const double w_norm = wt[idx] / total_wt;
    rank_w[idx] = cumulative_wt + w_norm / 2.0;
    cumulative_wt += w_norm;
    sum_wt2 += w_norm * w_norm;
  }

  double mean_rank = 0.0;
  double mean_outcome = 0.0;
  double min_outcome = R_PosInf;
  double max_outcome = R_NegInf;

  for (int idx : rows) {
    const double w_norm = wt[idx] / total_wt;
    mean_rank += w_norm * rank_w[idx];
    mean_outcome += w_norm * outcome[idx];
    min_outcome = std::min(min_outcome, outcome[idx]);
    max_outcome = std::max(max_outcome, outcome[idx]);
  }

  const double cov_denom = 1.0 - sum_wt2;
  if (!R_finite(cov_denom) || cov_denom <= 0.0) {
    return 0.0;
  }

  double cov12 = 0.0;
  for (int idx : rows) {
    const double w_norm = wt[idx] / total_wt;
    cov12 += w_norm * (rank_w[idx] - mean_rank) *
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

int type_to_code(std::string type) {
  if (type == "CI") return 1;
  if (type == "CIg") return 2;
  if (type == "CIc") return 3;
  if (type == "L") return 4;
  stop("Unknown CI type.");
}

}

// [[Rcpp::export]]
double ci_score_cpp(NumericMatrix y, NumericVector wt, std::string type) {
  const int n = y.nrow();
  if (y.ncol() != 2 || wt.size() != n) {
    stop("`y` must have two columns and `wt` must match its row count.");
  }

  std::vector<double> rank(n), outcome(n), weight(n);
  for (int i = 0; i < n; ++i) {
    rank[i] = y(i, 0);
    outcome[i] = y(i, 1);
    weight[i] = wt[i];
  }

  return ci_score_segment(rank, outcome, weight, 0, n, type_to_code(type));
}

// [[Rcpp::export]]
List best_numeric_split_cpp_engine(
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

  std::vector<int> ord(n);
  std::iota(ord.begin(), ord.end(), 0);
  std::stable_sort(
    ord.begin(),
    ord.end(),
    [&](int a, int b) {
      return x[a] < x[b];
    }
  );

  std::vector<double> xs(n), rank(n), outcome(n), weight(n);
  for (int i = 0; i < n; ++i) {
    const int src = ord[i];
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
      _["position"] = NA_INTEGER
    );
  }

  const int type_code = type_to_code(type);
  const double ci_parent = ci_score_segment(rank, outcome, weight, 0, n, type_code);
  double best_gain = R_NegInf;
  double best_cutpoint = NA_REAL;
  int best_position = NA_INTEGER;

  for (int pos = 0; pos < n - 1; ++pos) {
    if (xs[pos] == xs[pos + 1]) {
      continue;
    }

    const double wl = cum_wt[pos];
    const double wr = total_wt - wl;

    if (wl < minbucket || wr < minbucket) {
      continue;
    }
    if ((wl / total_wt) < minprob || (wr / total_wt) < minprob) {
      continue;
    }

    const double ci_left = ci_score_segment(
      rank, outcome, weight, 0, pos + 1, type_code
    );
    const double ci_right = ci_score_segment(
      rank, outcome, weight, pos + 1, n, type_code
    );
    const double gain = ci_parent -
      ((wl / total_wt) * ci_left + (wr / total_wt) * ci_right);

    if (gain > best_gain) {
      best_gain = gain;
      best_cutpoint = (xs[pos] + xs[pos + 1]) / 2.0;
      best_position = pos + 1;
    }
  }

  return List::create(
    _["gain"] = best_gain,
    _["cutpoint"] = best_cutpoint,
    _["position"] = best_position
  );
}
')

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
bench_n <- min(2500L, nrow(bench_data))
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

score_r <- ci_fun(y_mat, wt_vec)
score_cpp <- ci_score_cpp(y_mat, wt_vec, "CI")

split_r <- best_numeric_split(
  x = bench_data$sample_weight,
  y = y_mat,
  wt = wt_vec,
  varid = 1L,
  ctrl = ctrl,
  ci_fun = ci_fun,
  return = "candidate"
)

split_cpp <- best_numeric_split_cpp_engine(
  x = bench_data$sample_weight,
  y = y_mat,
  wt = wt_vec,
  minbucket = ctrl$minbucket,
  minprob = ctrl$minprob,
  type = "CI"
)

correctness <- data.frame(
  check = c("ci_score", "numeric_split_gain", "numeric_split_cutpoint"),
  r_value = c(score_r, split_r$gain, split_r$cutpoint),
  cpp_value = c(score_cpp, split_cpp$gain, split_cpp$cutpoint),
  abs_diff = abs(c(score_r, split_r$gain, split_r$cutpoint) -
    c(score_cpp, split_cpp$gain, split_cpp$cutpoint))
)

timings <- rbind(
  bench_time(
    "ci_fast_score_R_x1000",
    for (i in seq_len(1000L)) ci_fun(y_mat, wt_vec),
    reps = 5L
  ),
  bench_time(
    "ci_score_cpp_x1000",
    for (i in seq_len(1000L)) ci_score_cpp(y_mat, wt_vec, "CI"),
    reps = 5L
  ),
  bench_time(
    "best_numeric_split_R",
    best_numeric_split(
      x = bench_data$sample_weight,
      y = y_mat,
      wt = wt_vec,
      varid = 1L,
      ctrl = ctrl,
      ci_fun = ci_fun,
      return = "candidate"
    ),
    reps = 2L
  ),
  bench_time(
    "best_numeric_split_cpp_engine",
    best_numeric_split_cpp_engine(
      x = bench_data$sample_weight,
      y = y_mat,
      wt = wt_vec,
      minbucket = ctrl$minbucket,
      minprob = ctrl$minprob,
      type = "CI"
    ),
    reps = 2L
  )
)

print(correctness)
print(timings)

utils::write.csv(
  correctness,
  file = "dev/rcpp_split_experiment_correctness.csv",
  row.names = FALSE
)
utils::write.csv(
  timings,
  file = "dev/rcpp_split_experiment_timings.csv",
  row.names = FALSE
)
