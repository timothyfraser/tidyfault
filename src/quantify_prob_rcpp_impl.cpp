// quantify_prob_rcpp_impl.cpp
// Fast exact probability accumulation over truth-table failure rows.
// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
#include <vector>

using namespace Rcpp;

// [[Rcpp::export]]
NumericVector quantify_prob_cpp_impl(NumericMatrix probs,
                                     IntegerMatrix truth_events,
                                     LogicalVector failure_rows) {
  const int n_scenarios = probs.nrow();
  const int n_events = probs.ncol();
  const int n_truth = truth_events.nrow();

  if (truth_events.ncol() != n_events) {
    stop("truth_events must have the same number of columns as probs.");
  }
  if (failure_rows.size() != n_truth) {
    stop("failure_rows must have length equal to nrow(truth_events).");
  }

  std::vector<int> fail_idx;
  fail_idx.reserve(n_truth);
  for (int r = 0; r < n_truth; ++r) {
    if (failure_rows[r] == TRUE) {
      fail_idx.push_back(r);
    }
  }

  NumericVector out(n_scenarios);
  for (int s = 0; s < n_scenarios; ++s) {
    double p_fail = 0.0;
    for (size_t j = 0; j < fail_idx.size(); ++j) {
      const int r = fail_idx[j];
      double p_row = 1.0;
      for (int e = 0; e < n_events; ++e) {
        const double p = probs(s, e);
        p_row *= (truth_events(r, e) == 1) ? p : (1.0 - p);
      }
      p_fail += p_row;
    }
    out[s] = p_fail;
  }

  return out;
}
