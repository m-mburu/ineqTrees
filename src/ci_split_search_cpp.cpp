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

struct TwoCiScores {
  double left;
  double right;
};

template <typename ChildId>
TwoCiScores ci_score_children_ordered(
    const std::vector<double>& rank,
    const std::vector<double>& outcome,
    const std::vector<double>& wt,
    const std::vector<int>& ses_ord,
    ChildId child_id,
    int type_code) {

  int n_valid[2] = {0, 0};
  double total_wt[2] = {0.0, 0.0};

  for (int idx : ses_ord) {
    const int child = child_id(idx);
    if (child < 0) continue;
    if (valid_scalar(rank[idx]) &&
        valid_scalar(outcome[idx]) &&
        valid_scalar(wt[idx]) &&
        wt[idx] > 0.0) {
      ++n_valid[child];
      total_wt[child] += wt[idx];
    }
  }

  bool usable[2] = {
    n_valid[0] > 1 && R_finite(total_wt[0]) && total_wt[0] > 0.0,
    n_valid[1] > 1 && R_finite(total_wt[1]) && total_wt[1] > 0.0
  };

  TwoCiScores out = {0.0, 0.0};

  if (type_code == 4) {
    double mu_s[2] = {0.0, 0.0};
    for (int idx : ses_ord) {
      const int child = child_id(idx);
      if (child < 0 || !usable[child]) continue;
      if (!valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) ||
          !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      mu_s[child] += wt[idx] * rank[idx] / total_wt[child];
    }

    for (int child = 0; child < 2; ++child) {
      usable[child] = usable[child] &&
        R_finite(mu_s[child]) &&
        std::abs(mu_s[child]) > DBL_EPSILON;
    }

    double l_index[2] = {0.0, 0.0};
    for (int idx : ses_ord) {
      const int child = child_id(idx);
      if (child < 0 || !usable[child]) continue;
      if (!valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) ||
          !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      const double p = wt[idx] / total_wt[child];
      l_index[child] += p * ((rank[idx] - mu_s[child]) / mu_s[child]) *
        outcome[idx];
    }

    if (usable[0] && R_finite(l_index[0])) out.left = std::abs(l_index[0]);
    if (usable[1] && R_finite(l_index[1])) out.right = std::abs(l_index[1]);
    return out;
  }

  double cumulative_wt[2] = {0.0, 0.0};
  double mean_rank[2] = {0.0, 0.0};
  double mean_outcome[2] = {0.0, 0.0};
  double min_outcome[2] = {R_PosInf, R_PosInf};
  double max_outcome[2] = {R_NegInf, R_NegInf};

  for (size_t start = 0; start < ses_ord.size();) {
    const int first_idx = ses_ord[start];
    size_t end = start + 1;
    while (end < ses_ord.size() && rank[ses_ord[end]] == rank[first_idx]) {
      ++end;
    }

    double block_w_norm[2] = {0.0, 0.0};
    for (size_t pos = start; pos < end; ++pos) {
      const int idx = ses_ord[pos];
      const int child = child_id(idx);
      if (child < 0 || !usable[child]) continue;
      if (!valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) ||
          !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      block_w_norm[child] += wt[idx] / total_wt[child];
    }

    double block_rank[2] = {0.0, 0.0};
    for (int child = 0; child < 2; ++child) {
      block_rank[child] = cumulative_wt[child] + block_w_norm[child] / 2.0;
      mean_rank[child] += block_w_norm[child] * block_rank[child];
    }

    for (size_t pos = start; pos < end; ++pos) {
      const int idx = ses_ord[pos];
      const int child = child_id(idx);
      if (child < 0 || !usable[child]) continue;
      if (!valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) ||
          !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      const double w_norm = wt[idx] / total_wt[child];
      mean_outcome[child] += w_norm * outcome[idx];
      min_outcome[child] = std::min(min_outcome[child], outcome[idx]);
      max_outcome[child] = std::max(max_outcome[child], outcome[idx]);
    }

    cumulative_wt[0] += block_w_norm[0];
    cumulative_wt[1] += block_w_norm[1];
    start = end;
  }

  cumulative_wt[0] = 0.0;
  cumulative_wt[1] = 0.0;
  double cov12[2] = {0.0, 0.0};

  for (size_t start = 0; start < ses_ord.size();) {
    const int first_idx = ses_ord[start];
    size_t end = start + 1;
    while (end < ses_ord.size() && rank[ses_ord[end]] == rank[first_idx]) {
      ++end;
    }

    double block_w_norm[2] = {0.0, 0.0};
    for (size_t pos = start; pos < end; ++pos) {
      const int idx = ses_ord[pos];
      const int child = child_id(idx);
      if (child < 0 || !usable[child]) continue;
      if (!valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) ||
          !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      block_w_norm[child] += wt[idx] / total_wt[child];
    }

    double block_rank[2] = {0.0, 0.0};
    for (int child = 0; child < 2; ++child) {
      block_rank[child] = cumulative_wt[child] + block_w_norm[child] / 2.0;
    }

    for (size_t pos = start; pos < end; ++pos) {
      const int idx = ses_ord[pos];
      const int child = child_id(idx);
      if (child < 0 || !usable[child]) continue;
      if (!valid_scalar(rank[idx]) ||
          !valid_scalar(outcome[idx]) ||
          !valid_scalar(wt[idx]) ||
          wt[idx] <= 0.0) {
        continue;
      }
      const double w_norm = wt[idx] / total_wt[child];
      cov12[child] += w_norm * (block_rank[child] - mean_rank[child]) *
        (outcome[idx] - mean_outcome[child]);
    }

    cumulative_wt[0] += block_w_norm[0];
    cumulative_wt[1] += block_w_norm[1];
    start = end;
  }

  for (int child = 0; child < 2; ++child) {
    if (!usable[child]) continue;

    double score = 0.0;
    if (type_code == 1) {
      if (!R_finite(mean_outcome[child]) ||
          std::abs(mean_outcome[child]) <= DBL_EPSILON) {
        score = 0.0;
      } else {
        score = std::abs(2.0 * cov12[child] / mean_outcome[child]);
      }
    } else if (type_code == 2) {
      score = std::abs(2.0 * cov12[child]);
    } else {
      const double range = max_outcome[child] - min_outcome[child];
      if (!R_finite(range) || range <= DBL_EPSILON) {
        score = 0.0;
      } else {
        score = 4.0 * std::abs(2.0 * cov12[child]) / range;
      }
    }

    if (child == 0) {
      out.left = score;
    } else {
      out.right = score;
    }
  }

  return out;
}

double ci_score_all_ordered(
    const std::vector<double>& rank,
    const std::vector<double>& outcome,
    const std::vector<double>& wt,
    const std::vector<int>& ses_ord,
    int type_code) {

  TwoCiScores scores = ci_score_children_ordered(
    rank,
    outcome,
    wt,
    ses_ord,
    [](int) { return 0; },
    type_code
  );

  return scores.left;
}

double factor_partition_count(size_t n_levels) {
  if (n_levels <= 1) return 0.0;
  return std::pow(2.0, static_cast<double>(n_levels - 1)) - 1.0;
}

std::string choose_factor_split_mode(
    const std::string& factor_split,
    size_t n_levels,
    int max_factor_levels_partition,
    double max_factor_partitions) {

  const double n_partitions = factor_partition_count(n_levels);
  const bool bitmask_fits = n_levels <= 63;
  const bool can_partition =
    n_levels <= static_cast<size_t>(max_factor_levels_partition) &&
    n_partitions <= max_factor_partitions &&
    bitmask_fits;

  if (factor_split == "order") return "order";
  if (factor_split == "auto") return can_partition ? "partition" : "order";
  if (factor_split == "partition") {
    if (!can_partition) {
      stop("Exact factor partition search would evaluate too many partitions.");
    }
    return "partition";
  }

  stop("Unknown factor split strategy.");
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
  std::vector<int> ses_ord(n);
  std::iota(ses_ord.begin(), ses_ord.end(), 0);
  std::stable_sort(ses_ord.begin(), ses_ord.end(), [&](int a, int b) {
    return rank[a] < rank[b];
  });

  const double ci_parent = ci_score_all_ordered(
    rank,
    outcome,
    weight,
    ses_ord,
    type_code
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

    TwoCiScores child_scores = ci_score_children_ordered(
      rank,
      outcome,
      weight,
      ses_ord,
      [&](int idx) {
        return idx <= pos ? 0 : 1;
      },
      type_code
    );
    const double gain = ci_parent -
      ((wl / total_wt) * child_scores.left +
       (wr / total_wt) * child_scores.right);

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

List ci_best_factor_split_cpp_engine_impl(
    IntegerVector code,
    NumericMatrix y,
    NumericVector wt,
    int n_levels,
    double minbucket,
    double minprob,
    std::string type,
    std::string factor_split,
    int max_factor_levels_partition,
    double max_factor_partitions) {

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
      _["left_codes"] = IntegerVector(0),
      _["factor_split"] = NA_STRING
    );
  }

  std::sort(present.begin(), present.end());
  const std::string split_mode = choose_factor_split_mode(
    factor_split,
    present.size(),
    max_factor_levels_partition,
    max_factor_partitions
  );

  std::vector<int> ses_ord(n);
  std::iota(ses_ord.begin(), ses_ord.end(), 0);
  std::stable_sort(ses_ord.begin(), ses_ord.end(), [&](int a, int b) {
    return y(a, 0) < y(b, 0);
  });

  std::vector<double> rank(n), outcome(n), weight(n);
  for (int i = 0; i < n; ++i) {
    rank[i] = y(i, 0);
    outcome[i] = y(i, 1);
    weight[i] = wt[i];
  }

  const int type_code = type_to_code(type);
  const double ci_parent = ci_score_all_ordered(
    rank,
    outcome,
    weight,
    ses_ord,
    type_code
  );

  std::vector<double> cum_level_w(present.size(), 0.0);
  double total_w = 0.0;
  for (size_t i = 0; i < present.size(); ++i) {
    total_w += level_w[present[i]];
  }
  if (!R_finite(total_w) || total_w <= 0.0) {
    return List::create(
      _["gain"] = R_NegInf,
      _["left"] = empty_left,
      _["left_codes"] = IntegerVector(0),
      _["factor_split"] = split_mode
    );
  }

  double best_gain = R_NegInf;
  std::vector<unsigned char> best_side(n_levels + 1, 0);
  std::vector<int> best_left_codes;

  if (split_mode == "partition") {
    const unsigned long long n_partitions =
      static_cast<unsigned long long>(factor_partition_count(present.size()));
    std::vector<unsigned char> side(n_levels + 1, 0);

    for (unsigned long long mask = 1; mask <= n_partitions; ++mask) {
      std::fill(side.begin(), side.end(), 0);
      double wl = 0.0;

      for (size_t i = 0; i + 1 < present.size(); ++i) {
        if ((mask & (1ULL << i)) != 0) {
          side[present[i]] = 1;
          wl += level_w[present[i]];
        }
      }

      const double wr = total_w - wl;
      if (wl < minbucket || wr < minbucket) continue;
      if ((wl / total_w) < minprob || (wr / total_w) < minprob) continue;

      TwoCiScores child_scores = ci_score_children_ordered(
        rank,
        outcome,
        weight,
        ses_ord,
        [&](int idx) {
          const int cd = code[idx];
          if (cd == NA_INTEGER || cd <= 0 || cd > n_levels) return -1;
          return static_cast<bool>(side[cd]) ? 0 : 1;
        },
        type_code
      );
      const double gain = ci_parent -
        ((wl / total_w) * child_scores.left +
         (wr / total_w) * child_scores.right);

      if (gain > best_gain) {
        best_gain = gain;
        best_side = side;
        best_left_codes.clear();
        for (int cd : present) {
          if (best_side[cd]) best_left_codes.push_back(cd);
        }
      }
    }
  } else {
    std::stable_sort(present.begin(), present.end(), [&](int a, int b) {
      return (level_yw[a] / level_w[a]) < (level_yw[b] / level_w[b]);
    });

    std::vector<unsigned char> side(n_levels + 1, 0);
    for (size_t i = 0; i < present.size(); ++i) {
      cum_level_w[i] = (i == 0 ? 0.0 : cum_level_w[i - 1]) + level_w[present[i]];
    }

    for (size_t k = 0; k + 1 < present.size(); ++k) {
      side[present[k]] = 1;

      const double wl = cum_level_w[k];
      const double wr = total_w - wl;
      if (wl < minbucket || wr < minbucket) continue;
      if ((wl / total_w) < minprob || (wr / total_w) < minprob) continue;

      TwoCiScores child_scores = ci_score_children_ordered(
        rank,
        outcome,
        weight,
        ses_ord,
        [&](int idx) {
          const int cd = code[idx];
          if (cd == NA_INTEGER || cd <= 0 || cd > n_levels) return -1;
          return static_cast<bool>(side[cd]) ? 0 : 1;
        },
        type_code
      );
      const double gain = ci_parent -
        ((wl / total_w) * child_scores.left +
         (wr / total_w) * child_scores.right);

      if (gain > best_gain) {
        best_gain = gain;
        best_side = side;
        best_left_codes.assign(present.begin(), present.begin() + k + 1);
      }
    }
  }

  LogicalVector left(n, false);
  IntegerVector left_codes(0);

  if (R_finite(best_gain)) {
    left_codes = IntegerVector(best_left_codes.size());
    for (size_t i = 0; i < best_left_codes.size(); ++i) {
      left_codes[i] = best_left_codes[i];
    }
    for (int i = 0; i < n; ++i) {
      const int cd = code[i];
      left[i] = cd != NA_INTEGER && cd > 0 && cd <= n_levels && best_side[cd];
    }
  }

  return List::create(
    _["gain"] = best_gain,
    _["left"] = left,
    _["left_codes"] = left_codes,
    _["factor_split"] = split_mode
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

  return ci_best_factor_split_cpp_engine_impl(
    code,
    y,
    wt,
    n_levels,
    minbucket,
    minprob,
    type,
    "order",
    49,
    1e6
  );
}

// [[Rcpp::export]]
List ci_best_factor_split_cpp_engine_controlled(
    IntegerVector code,
    NumericMatrix y,
    NumericVector wt,
    int n_levels,
    double minbucket,
    double minprob,
    std::string type,
    std::string factor_split,
    int max_factor_levels_partition,
    double max_factor_partitions) {

  return ci_best_factor_split_cpp_engine_impl(
    code,
    y,
    wt,
    n_levels,
    minbucket,
    minprob,
    type,
    factor_split,
    max_factor_levels_partition,
    max_factor_partitions
  );
}
