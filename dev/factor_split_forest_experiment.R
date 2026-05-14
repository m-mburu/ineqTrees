if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", export_all = FALSE)
} else {
  library(ineqTrees)
}

if (!requireNamespace("Rcpp", quietly = TRUE)) {
  stop("The Rcpp package is needed for the factor split experiment.", call. = FALSE)
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

double ci_score_factor_side(
    const IntegerVector& code,
    const NumericMatrix& y,
    const NumericVector& wt,
    const std::vector<int>& ses_ord,
    const std::vector<unsigned char>& side,
    bool left_child,
    int type_code) {

  int n_valid = 0;
  double total_wt = 0.0;

  for (int idx : ses_ord) {
    const int cd = code[idx];
    if (cd == NA_INTEGER || cd <= 0) continue;
    const bool in_child = static_cast<bool>(side[cd]) == left_child;
    if (!in_child) continue;
    if (valid_scalar(y(idx, 0)) &&
        valid_scalar(y(idx, 1)) &&
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
      const int cd = code[idx];
      if (cd == NA_INTEGER || cd <= 0) continue;
      const bool in_child = static_cast<bool>(side[cd]) == left_child;
      if (!in_child || !valid_scalar(y(idx, 0)) ||
          !valid_scalar(y(idx, 1)) || !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      mu_s += wt[idx] * y(idx, 0) / total_wt;
    }
    if (!R_finite(mu_s) || std::abs(mu_s) <= DBL_EPSILON) {
      return 0.0;
    }

    double l_index = 0.0;
    for (int idx : ses_ord) {
      const int cd = code[idx];
      if (cd == NA_INTEGER || cd <= 0) continue;
      const bool in_child = static_cast<bool>(side[cd]) == left_child;
      if (!in_child || !valid_scalar(y(idx, 0)) ||
          !valid_scalar(y(idx, 1)) || !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      const double p = wt[idx] / total_wt;
      l_index += p * ((y(idx, 0) - mu_s) / mu_s) * y(idx, 1);
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
    const int cd = code[idx];
    if (cd == NA_INTEGER || cd <= 0) continue;
    const bool in_child = static_cast<bool>(side[cd]) == left_child;
    if (!in_child || !valid_scalar(y(idx, 0)) ||
        !valid_scalar(y(idx, 1)) || !valid_scalar(wt[idx]) ||
        wt[idx] <= 0.0) {
      continue;
    }
    const double w_norm = wt[idx] / total_wt;
    const double rank_w = cumulative_wt + w_norm / 2.0;
    cumulative_wt += w_norm;
    sum_wt2 += w_norm * w_norm;
    mean_rank += w_norm * rank_w;
    mean_outcome += w_norm * y(idx, 1);
    min_outcome = std::min(min_outcome, y(idx, 1));
    max_outcome = std::max(max_outcome, y(idx, 1));
  }

  const double cov_denom = 1.0 - sum_wt2;
  if (!R_finite(cov_denom) || cov_denom <= 0.0) {
    return 0.0;
  }

  cumulative_wt = 0.0;
  double cov12 = 0.0;
  for (int idx : ses_ord) {
    const int cd = code[idx];
    if (cd == NA_INTEGER || cd <= 0) continue;
    const bool in_child = static_cast<bool>(side[cd]) == left_child;
    if (!in_child || !valid_scalar(y(idx, 0)) ||
        !valid_scalar(y(idx, 1)) || !valid_scalar(wt[idx]) ||
        wt[idx] <= 0.0) {
      continue;
    }
    const double w_norm = wt[idx] / total_wt;
    const double rank_w = cumulative_wt + w_norm / 2.0;
    cumulative_wt += w_norm;
    cov12 += w_norm * (rank_w - mean_rank) *
      (y(idx, 1) - mean_outcome);
  }
  cov12 /= cov_denom;

  if (type_code == 1) {
    if (!R_finite(mean_outcome) || std::abs(mean_outcome) <= DBL_EPSILON) {
      return 0.0;
    }
    return std::abs(2.0 * cov12 / mean_outcome);
  }

  if (type_code == 2) return std::abs(2.0 * cov12);

  const double range = max_outcome - min_outcome;
  if (!R_finite(range) || range <= DBL_EPSILON) {
    return 0.0;
  }
  return 4.0 * std::abs(2.0 * cov12) / range;
}

double ci_score_all(
    const NumericMatrix& y,
    const NumericVector& wt,
    const std::vector<int>& ses_ord,
    int type_code) {

  IntegerVector all_code(y.nrow());
  std::vector<unsigned char> side(2, 1);
  for (int i = 0; i < y.nrow(); ++i) all_code[i] = 1;
  return ci_score_factor_side(all_code, y, wt, ses_ord, side, true, type_code);
}

}

// [[Rcpp::export]]
List best_factor_split_cpp_engine(
    IntegerVector code,
    NumericMatrix y,
    NumericVector wt,
    int n_levels,
    double minbucket,
    double minprob,
    std::string type) {

  const int n = code.size();
  if (y.nrow() != n || y.ncol() != 2 || wt.size() != n) {
    stop("Inputs have incompatible sizes.");
  }

  std::vector<double> level_w(n_levels + 1, 0.0);
  std::vector<double> level_yw(n_levels + 1, 0.0);
  std::vector<int> present;
  std::vector<unsigned char> seen(n_levels + 1, 0);

  for (int i = 0; i < n; ++i) {
    const int cd = code[i];
    if (cd == NA_INTEGER || cd <= 0 || cd > n_levels) continue;
    if (!valid_scalar(y(i, 1)) || !valid_scalar(wt[i]) || wt[i] <= 0.0) continue;
    if (!seen[cd]) {
      seen[cd] = 1;
      present.push_back(cd);
    }
    level_w[cd] += wt[i];
    level_yw[cd] += wt[i] * y(i, 1);
  }

  if (present.size() <= 1) {
    return List::create(
      _["gain"] = R_NegInf,
      _["left"] = LogicalVector(n, false),
      _["left_codes"] = IntegerVector(0)
    );
  }

  std::sort(present.begin(), present.end());
  std::stable_sort(present.begin(), present.end(), [&](int a, int b) {
    return (level_yw[a] / level_w[a]) < (level_yw[b] / level_w[b]);
  });

  std::vector<int> ses_ord(n);
  std::iota(ses_ord.begin(), ses_ord.end(), 0);
  std::stable_sort(ses_ord.begin(), ses_ord.end(), [&](int a, int b) {
    return y(a, 0) < y(b, 0);
  });

  const int type_code = type_to_code(type);
  const double ci_parent = ci_score_all(y, wt, ses_ord, type_code);

  std::vector<double> cum_level_w(present.size(), 0.0);
  double total_w = 0.0;
  for (size_t i = 0; i < present.size(); ++i) {
    total_w += level_w[present[i]];
    cum_level_w[i] = total_w;
  }

  std::vector<unsigned char> side(n_levels + 1, 0);
  double best_gain = R_NegInf;
  int best_k = -1;

  for (size_t k = 0; k + 1 < present.size(); ++k) {
    side[present[k]] = 1;

    const double wl = cum_level_w[k];
    const double wr = total_w - wl;
    if (wl < minbucket || wr < minbucket) continue;
    if ((wl / total_w) < minprob || (wr / total_w) < minprob) continue;

    const double ci_left = ci_score_factor_side(
      code, y, wt, ses_ord, side, true, type_code
    );
    const double ci_right = ci_score_factor_side(
      code, y, wt, ses_ord, side, false, type_code
    );
    const double gain = ci_parent -
      ((wl / total_w) * ci_left + (wr / total_w) * ci_right);

    if (gain > best_gain) {
      best_gain = gain;
      best_k = static_cast<int>(k);
    }
  }

  LogicalVector left(n, false);
  IntegerVector left_codes;

  if (best_k >= 0) {
    std::vector<unsigned char> best_side(n_levels + 1, 0);
    left_codes = IntegerVector(best_k + 1);
    for (int i = 0; i <= best_k; ++i) {
      best_side[present[i]] = 1;
      left_codes[i] = present[i];
    }
    for (int i = 0; i < n; ++i) {
      const int cd = code[i];
      left[i] = cd != NA_INTEGER && cd > 0 && cd <= n_levels && best_side[cd];
    }
  }

  return List::create(
    _["gain"] = best_gain,
    _["left"] = left,
    _["left_codes"] = left_codes
  );
}
')

gain_from_parent <- function(y, wt, left, ci_fun, ci_parent) {
  wl <- sum(wt[left], na.rm = TRUE)
  wr <- sum(wt[!left], na.rm = TRUE)
  wtot <- wl + wr
  if (wl <= 0 || wr <= 0 || wtot <= 0) {
    return(-Inf)
  }
  ci_left <- ci_fun(y[left, , drop = FALSE], wt[left])
  ci_right <- ci_fun(y[!left, , drop = FALSE], wt[!left])
  ci_parent - ((wl / wtot) * ci_left + (wr / wtot) * ci_right)
}

best_factor_split_int_dt <- function(x, y, wt, ctrl, ci_fun) {
  code <- as.integer(x)
  ok <- !is.na(code) & !is.na(y[, 1]) & !is.na(y[, 2]) & !is.na(wt) & wt > 0
  if (!any(ok)) return(NULL)

  code <- code[ok]
  y <- y[ok, , drop = FALSE]
  wt <- wt[ok]

  DT <- data.table::data.table(
    code = code,
    outcome = y[, 2],
    wt = wt
  )
  level_stats <- DT[, .(
    w = sum(wt),
    ybar = sum(wt * outcome) / sum(wt)
  ), by = code]
  data.table::setorder(level_stats, code)
  data.table::setorder(level_stats, ybar)

  if (nrow(level_stats) <= 1L) return(NULL)

  ord_codes <- level_stats$code
  level_weight <- level_stats$w
  cum_level_weight <- cumsum(level_weight)
  total_weight <- cum_level_weight[length(cum_level_weight)]
  ci_parent <- ci_fun(y, wt)
  side <- rep(FALSE, length(levels(x)))
  gains <- rep(-Inf, length(ord_codes) - 1L)

  for (k in seq_len(length(ord_codes) - 1L)) {
    side[ord_codes[k]] <- TRUE
    wl <- cum_level_weight[k]
    wr <- total_weight - wl

    if (wl < ctrl$minbucket || wr < ctrl$minbucket) next
    if ((wl / total_weight) < ctrl$minprob ||
        (wr / total_weight) < ctrl$minprob) {
      next
    }

    left <- side[code]
    gains[k] <- gain_from_parent(y, wt, left, ci_fun, ci_parent)
  }

  if (!any(is.finite(gains))) return(NULL)

  best_k <- which.max(gains)
  side <- rep(FALSE, length(levels(x)))
  side[ord_codes[seq_len(best_k)]] <- TRUE
  left <- side[as.integer(x)]
  left[is.na(left)] <- FALSE

  list(
    gain = gains[best_k],
    left = left,
    left_codes = ord_codes[seq_len(best_k)]
  )
}

best_factor_split_current_engine <- function(x, y, wt, ctrl, ci_fun) {
  best_factor_split(
    x_full = x,
    keep = rep(TRUE, length(x)),
    y_full = y,
    wt_full = wt,
    varid = 1L,
    ctrl = ctrl,
    ci_fun = ci_fun,
    return = "candidate"
  )
}

best_factor_split_cpp <- function(x, y, wt, ctrl, type) {
  out <- best_factor_split_cpp_engine(
    code = as.integer(x),
    y = y,
    wt = wt,
    n_levels = length(levels(x)),
    minbucket = ctrl$minbucket,
    minprob = ctrl$minprob,
    type = type
  )
  if (!is.finite(out$gain)) return(NULL)
  list(
    gain = out$gain,
    left = as.logical(out$left),
    left_codes = as.integer(out$left_codes)
  )
}

best_global_factor_split_engine <- function(x_list, y, wt, rows, vars, ctrl,
                                            method, ci_fun, type, mtry = NULL) {
  vars <- as.integer(vars)
  if (!is.null(mtry)) {
    vars <- sample(vars, min(length(vars), mtry))
  }

  best <- NULL
  for (j in vars) {
    x <- x_list[[j]][rows]
    candidate <- switch(
      method,
      current = best_factor_split_current_engine(x, y[rows, , drop = FALSE], wt[rows], ctrl, ci_fun),
      int_dt = best_factor_split_int_dt(x, y[rows, , drop = FALSE], wt[rows], ctrl, ci_fun),
      cpp = best_factor_split_cpp(x, y[rows, , drop = FALSE], wt[rows], ctrl, type),
      stop("unknown method", call. = FALSE)
    )
    if (!is.null(candidate) &&
        !is.null(candidate$left) &&
        is.finite(candidate$gain) &&
        (is.null(best) || candidate$gain > best$gain)) {
      candidate$varid <- j
      best <- candidate
    }
  }

  if (is.null(best) || !is.finite(best$gain) || best$gain <= ctrl$min_gain) {
    return(NULL)
  }
  best
}

fit_factor_tree_engine <- function(x_list, y, wt, rows, vars, depth, ctrl,
                                   method, ci_fun, type, mtry = NULL) {
  if (depth >= ctrl$maxdepth || sum(wt[rows], na.rm = TRUE) < ctrl$minsplit) {
    return(1L)
  }

  split <- best_global_factor_split_engine(
    x_list = x_list,
    y = y,
    wt = wt,
    rows = rows,
    vars = vars,
    ctrl = ctrl,
    method = method,
    ci_fun = ci_fun,
    type = type,
    mtry = mtry
  )

  if (is.null(split) || !any(split$left) || all(split$left)) {
    return(1L)
  }

  1L +
    fit_factor_tree_engine(x_list, y, wt, rows[split$left], vars, depth + 1L, ctrl, method, ci_fun, type, mtry) +
    fit_factor_tree_engine(x_list, y, wt, rows[!split$left], vars, depth + 1L, ctrl, method, ci_fun, type, mtry)
}

fit_factor_forest_engine <- function(x_list, y, wt, ctrl, ntree, method,
                                     ci_fun, type, mtry = NULL,
                                     fraction = 0.632) {
  n <- nrow(y)
  vars <- seq_along(x_list)
  sizes <- integer(ntree)

  for (b in seq_len(ntree)) {
    rows <- sample.int(n, size = max(1L, ceiling(n * fraction)), replace = FALSE)
    sizes[b] <- fit_factor_tree_engine(
      x_list = x_list,
      y = y,
      wt = wt,
      rows = rows,
      vars = vars,
      depth = 0L,
      ctrl = ctrl,
      method = method,
      ci_fun = ci_fun,
      type = type,
      mtry = mtry
    )
  }
  sizes
}

time_once <- function(expr, env = parent.frame()) {
  expr <- substitute(expr)
  gc()
  unname(system.time(eval(expr, envir = env))[["elapsed"]])
}

time_repeated <- function(expr, iterations = 20L, env = parent.frame()) {
  expr <- substitute(expr)
  gc()
  elapsed <- unname(system.time({
    for (i in seq_len(iterations)) {
      eval(expr, envir = env)
    }
  })[["elapsed"]])
  elapsed / iterations
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
    d$median_sec_for_log <- pmax(d$median_sec, 1e-6)
    fit <- stats::lm(log(median_sec_for_log) ~ log(n), data = d)
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
factor_vars <- c("rural", "ed", "reg", "unskilled")
bench_vars <- c("wealth", "deadu5_num", factor_vars)
base_data <- kenya[stats::complete.cases(kenya[, bench_vars]), bench_vars]
base_data[factor_vars] <- lapply(base_data[factor_vars], factor)

make_sample <- function(n, rep) {
  set.seed(20260514 + 1000L * rep + n)
  d <- base_data[sample.int(nrow(base_data), n), , drop = FALSE]
  list(
    x_list = lapply(d[factor_vars], factor),
    y = cbind(rank = d$wealth, outcome = d$deadu5_num),
    wt = rep(1, n)
  )
}

type <- "CI"
ci_fun <- ci_factory(type)
ctrl <- ci_tree_control(
  minsplit = 100L,
  minbucket = 50L,
  minprob = 0.01,
  maxdepth = 4L,
  min_gain = 0
)
methods <- c("current", "int_dt", "cpp")

correct_sample <- make_sample(3000L, 1L)
current_reg <- best_factor_split_current_engine(
  correct_sample$x_list$reg,
  correct_sample$y,
  correct_sample$wt,
  ctrl,
  ci_fun
)
int_reg <- best_factor_split_int_dt(
  correct_sample$x_list$reg,
  correct_sample$y,
  correct_sample$wt,
  ctrl,
  ci_fun
)
cpp_reg <- best_factor_split_cpp(
  correct_sample$x_list$reg,
  correct_sample$y,
  correct_sample$wt,
  ctrl,
  type
)

correctness <- data.frame(
  method = c("int_dt", "cpp"),
  gain_abs_diff = c(
    abs(current_reg$gain - int_reg$gain),
    abs(current_reg$gain - cpp_reg$gain)
  ),
  left_membership_changes = c(
    sum(current_reg$left != int_reg$left),
    sum(current_reg$left != cpp_reg$left)
  )
)

split_results <- bench_randomized(
  label = "factor_split_reg",
  methods = methods,
  sizes = c(1000L, 3000L, 5000L),
  reps = 3L,
  expr_fun = function(n, method, rep) {
    s <- make_sample(n, rep)
    time_repeated(switch(
      method,
      current = best_factor_split_current_engine(s$x_list$reg, s$y, s$wt, ctrl, ci_fun),
      int_dt = best_factor_split_int_dt(s$x_list$reg, s$y, s$wt, ctrl, ci_fun),
      cpp = best_factor_split_cpp(s$x_list$reg, s$y, s$wt, ctrl, type)
    ), iterations = 20L)
  }
)

forest_results <- bench_randomized(
  label = "factor_forest_engine_ntree30",
  methods = methods,
  sizes = c(1000L, 3000L, 5000L),
  reps = 3L,
  expr_fun = function(n, method, rep) {
    s <- make_sample(n, rep)
    set.seed(20260514 + 2000L * rep + n)
    time_once(fit_factor_forest_engine(
      x_list = s$x_list,
      y = s$y,
      wt = s$wt,
      ctrl = ctrl,
      ntree = 30L,
      method = method,
      ci_fun = ci_fun,
      type = type,
      mtry = 2L
    ))
  }
)

results <- rbind(split_results, forest_results)
summary <- summarise_growth(results)

print(correctness)
print(summary$medians)
print(summary$growth)

utils::write.csv(
  correctness,
  file = "dev/factor_split_forest_correctness.csv",
  row.names = FALSE
)
utils::write.csv(
  results,
  file = "dev/factor_split_forest_raw.csv",
  row.names = FALSE
)
utils::write.csv(
  summary$medians,
  file = "dev/factor_split_forest_medians.csv",
  row.names = FALSE
)
utils::write.csv(
  summary$growth,
  file = "dev/factor_split_forest_growth_rates.csv",
  row.names = FALSE
)
