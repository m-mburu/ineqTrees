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

// Cutpoint kept inside [lower, upper) so that `value <= cutpoint` selects
// exactly the observations that were scored on the left. Averaging the halves
// avoids the overflow of (lower + upper) / 2. Rounding can still land exactly
// on `upper` for adjacent doubles, where `lower` is then the largest
// representable value below `upper`.
double safe_numeric_midpoint(double lower, double upper) {
  double midpoint = lower / 2.0 + upper / 2.0;

  if (!R_finite(midpoint) || midpoint >= upper) {
    midpoint = lower;
  }

  return midpoint > lower ? midpoint : lower;
}

struct TwoCiScores {
  double left;
  double right;
};

// Reuse the parent node's socioeconomic sort order for every candidate.
// The callback assigns rows to the left (0), right (1), or neither (-1).
// The rank input holds SES levels. The rank-based indices derive fractional
// ranks within each child, and L uses the original levels.
template <typename ChildId>
TwoCiScores ci_score_children_ordered(
    const std::vector<double>& rank,
    const std::vector<double>& outcome,
    const std::vector<double>& wt,
    const std::vector<int>& ses_ord,
    ChildId child_id,
    int type_code) {

  // Track the scoring weight separately in each child after excluding rows
  // with invalid inputs or zero weight.
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

  // An unscorable child contributes zero impurity, matching the R scorer.
  // A failed split search is signalled separately by a gain of -Inf.
  TwoCiScores out = {0.0, 0.0};

  if (type_code == 4) {
    // The L index centres socioeconomic levels on each child's weighted mean.
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

    // An effectively zero mean SES leaves L undefined. Keep that child's
    // score at the default zero to avoid dividing by an unstable mean.
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

  // In the first pass, calculate the outcome mean and weighted midranks.
  // Tied rows share a rank within each child, based on their combined weight.
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
  // Revisit the tied blocks to compute covariance about the child means.
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

  // CI scales twice the covariance by the child's outcome mean. CIg uses
  // it directly, and CIc scales it by four over the child's outcome range.
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

  // Assign all rows to one side to score the unsplit parent.
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

  // The search budget uses the levels present in the current node.
  // Automatic mode can use ordered search when enumeration is too large.
  const double n_partitions = factor_partition_count(n_levels);
  // Bound both the size of the bitmask and the number of subsets searched.
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

  for (int i = 0; i < n; ++i) {
    if (NumericVector::is_na(x[i])) {
      stop("`x` must not contain missing values in split search.");
    }
    if (!R_finite(x[i])) {
      stop("`x` must contain only finite values in split search.");
    }
  }

  // Sort by predictor value to enumerate distinct thresholds. Keep the
  // permutation so the winning mask can be returned in input order.
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

  // Sum from the right so a small positive child retains its weight even
  // when the left child accounts for nearly all of the node's weight.
  std::vector<double> suffix_wt(weight.size() + 1, 0.0);
  for (int i = n; i > 0; --i) {
    suffix_wt[i - 1] = weight[i - 1] + suffix_wt[i];
  }
  const double total_wt = std::accumulate(weight.begin(), weight.end(), 0.0);

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
  // Until a cutpoint passes both weight limits, return no split. The R
  // wrapper checks the gain before it uses the cutpoint or mask.
  double best_gain = R_NegInf;
  double best_cutpoint = NA_REAL;
  int best_pos = -1;

  double wl = 0.0;
  for (int pos = 0; pos < n - 1; ++pos) {
    wl += weight[pos];
    // A numeric threshold cannot split rows with equal predictor values.
    if (xs[pos] == xs[pos + 1]) continue;

    const double wr = suffix_wt[pos + 1];

    // A zero-weight child has no share of the parent, even with zero limits.
    if (wl <= 0.0 || wr <= 0.0) continue;
    if (wl < minbucket || wr < minbucket) continue;
    if ((wl / total_wt) < minprob || (wr / total_wt) < minprob) continue;

    // The callback assigns rows by predictor position. The scorer still
    // visits them in SES order to rebuild ranks within each child.
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

    // Gain is the parent impurity less the two child impurities weighted by
    // their shares of the node's total case weight.
    const double gain = ci_parent -
      ((wl / total_wt) * child_scores.left +
       (wr / total_wt) * child_scores.right);

    // Keep the first threshold when multiple candidates have the same gain.
    if (gain > best_gain) {
      best_gain = gain;
      best_cutpoint = safe_numeric_midpoint(xs[pos], xs[pos + 1]);
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

  // Index these tables by one-based R factor codes. A level enters the
  // search with any finite outcome and positive finite weight.
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

    // Fix the last level on the right to count each partition once.
    for (unsigned long long mask = 1; mask <= n_partitions; ++mask) {
      std::fill(side.begin(), side.end(), 0);
      double wl = 0.0;
      double wr = level_w[present.back()];

      for (size_t i = 0; i + 1 < present.size(); ++i) {
        if ((mask & (1ULL << i)) != 0) {
          side[present[i]] = 1;
          wl += level_w[present[i]];
        } else {
          wr += level_w[present[i]];
        }
      }

      if (wl <= 0.0 || wr <= 0.0) continue;
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
    // The ordered search visits prefixes of the levels sorted by weighted
    // outcome mean. This limits the number of candidates to score.
    std::stable_sort(present.begin(), present.end(), [&](int a, int b) {
      return (level_yw[a] / level_w[a]) < (level_yw[b] / level_w[b]);
    });

    std::vector<unsigned char> side(n_levels + 1, 0);
    std::vector<double> suffix_wt(present.size() + 1, 0.0);
    for (size_t i = present.size(); i > 0; --i) {
      suffix_wt[i - 1] = level_w[present[i - 1]] + suffix_wt[i];
    }

    double wl = 0.0;
    for (size_t k = 0; k + 1 < present.size(); ++k) {
      // Move one level to the left at a time. The final level stays right
      // so each prefix defines two non-empty groups of levels.
      side[present[k]] = 1;

      wl += level_w[present[k]];
      const double wr = suffix_wt[k + 1];
      if (wl <= 0.0 || wr <= 0.0) continue;
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
    // Retain ordered search for the entry point without a strategy argument.
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
