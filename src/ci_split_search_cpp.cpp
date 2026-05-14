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

  double cumulative_wt = 0.0;
  double sum_wt2 = 0.0;
  double mean_rank = 0.0;
  double mean_outcome = 0.0;
  double min_outcome = R_PosInf;
  double max_outcome = R_NegInf;
  std::vector<double> rank_w(rank.size(), 0.0);

  for (int idx : rows) {
    const double w_norm = wt[idx] / total_wt;
    rank_w[idx] = cumulative_wt + w_norm / 2.0;
    cumulative_wt += w_norm;
    sum_wt2 += w_norm * w_norm;
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

} // namespace

// [[Rcpp::export]]
List ci_best_numeric_split_cpp_engine(
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
  std::stable_sort(ord.begin(), ord.end(), [&](int a, int b) {
    return x[a] < x[b];
  });

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

  LogicalVector empty_left(n, false);
  if (!R_finite(total_wt) || total_wt <= 0.0) {
    return List::create(
      _["gain"] = R_NegInf,
      _["cutpoint"] = NA_REAL,
      _["left"] = empty_left
    );
  }

  const int type_code = type_to_code(type);
  const double ci_parent = ci_score_segment(rank, outcome, weight, 0, n, type_code);
  double best_gain = R_NegInf;
  double best_cutpoint = NA_REAL;
  int best_pos = -1;

  for (int pos = 0; pos < n - 1; ++pos) {
    if (xs[pos] == xs[pos + 1]) continue;

    const double wl = cum_wt[pos];
    const double wr = total_wt - wl;

    if (wl < minbucket || wr < minbucket) continue;
    if ((wl / total_wt) < minprob || (wr / total_wt) < minprob) continue;

    const double ci_left = ci_score_segment(rank, outcome, weight, 0, pos + 1, type_code);
    const double ci_right = ci_score_segment(rank, outcome, weight, pos + 1, n, type_code);
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
      left[ord[i]] = true;
    }
  }

  return List::create(
    _["gain"] = best_gain,
    _["cutpoint"] = best_cutpoint,
    _["left"] = left
  );
}

// [[Rcpp::export]]
List ci_best_factor_split_cpp_engine(
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

  LogicalVector empty_left(n, false);
  if (present.size() <= 1) {
    return List::create(
      _["gain"] = R_NegInf,
      _["left"] = empty_left,
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

    const double ci_left = ci_score_factor_side(code, y, wt, ses_ord, side, true, type_code);
    const double ci_right = ci_score_factor_side(code, y, wt, ses_ord, side, false, type_code);
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
