// mocus_rcpp_impl.cpp
// Core MOCUS expansion loop in C++.
// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
#include <deque>
#include <vector>
#include <unordered_map>
#include <unordered_set>

using namespace Rcpp;

// [[Rcpp::export]]
List mocus_cpp_impl(IntegerVector gate_ids,
                    IntegerVector gate_types,
                    IntegerVector child_flat,
                    IntegerVector child_start,
                    IntegerVector child_end,
                    int top_id) {

  int n_gates = gate_ids.size();

  // gate_id -> row index (0-based)
  std::unordered_map<int, int> id_to_idx;
  id_to_idx.reserve(n_gates * 2);
  for (int i = 0; i < n_gates; i++) id_to_idx[gate_ids[i]] = i;

  // fast gate membership
  std::unordered_set<int> gate_set;
  gate_set.reserve(n_gates * 2);
  for (int g : gate_ids) gate_set.insert(g);

  // copy Rcpp vectors to plain std::vectors for hot-loop speed
  std::vector<int> cf(child_flat.begin(),  child_flat.end());
  std::vector<int> cs(child_start.begin(), child_start.end());
  std::vector<int> ce(child_end.begin(),   child_end.end());
  std::vector<int> gt(gate_types.begin(),  gate_types.end());

  // work queue
  std::deque<std::vector<int>> queue;
  queue.push_back(std::vector<int>(1, top_id));

  std::vector<std::vector<int>> results;
  results.reserve(512);

  while (!queue.empty()) {
    std::vector<int> cutset = std::move(queue.front());
    queue.pop_front();

    // classify positions as AND-type (0) or OR-type (1) gates
    std::vector<int> and_pos, or_pos;
    for (int p = 0; p < (int)cutset.size(); p++) {
      auto it = id_to_idx.find(cutset[p]);
      if (it == id_to_idx.end()) continue;
      int idx = it->second;
      if (gt[idx] == 0) and_pos.push_back(p);
      else              or_pos.push_back(p);
    }

    // fully resolved cutset
    if (and_pos.empty() && or_pos.empty()) {
      std::unordered_set<int> seen;
      std::vector<int> deduped;
      deduped.reserve(cutset.size());
      for (int x : cutset) if (seen.insert(x).second) deduped.push_back(x);
      results.push_back(std::move(deduped));
      continue;
    }

    if (!and_pos.empty()) {
      // expand ALL AND/top gates in a single pass
      std::unordered_set<int> rm(and_pos.begin(), and_pos.end());
      std::vector<int> nc;
      nc.reserve(cutset.size() * 2);
      for (int p = 0; p < (int)cutset.size(); p++) {
        if (!rm.count(p)) nc.push_back(cutset[p]);
      }
      for (int p : and_pos) {
        int idx = id_to_idx[cutset[p]];
        for (int c = cs[idx]; c < ce[idx]; c++) nc.push_back(cf[c]);
      }
      queue.push_back(std::move(nc));
    } else {
      // branch on first OR gate
      int p0  = or_pos[0];
      int idx = id_to_idx[cutset[p0]];
      std::vector<int> rest;
      rest.reserve(cutset.size() - 1);
      for (int p = 0; p < (int)cutset.size(); p++) {
        if (p != p0) rest.push_back(cutset[p]);
      }
      for (int c = cs[idx]; c < ce[idx]; c++) {
        std::vector<int> branch(rest);
        branch.push_back(cf[c]);
        queue.push_back(std::move(branch));
      }
    }
  }

  List out(results.size());
  for (int i = 0; i < (int)results.size(); i++) out[i] = wrap(results[i]);
  return out;
}