# tidyfault (development version)

* quantify() gains a `fast` argument (default `TRUE`) that dispatches to `quantify_binary_fast()` or `quantify_prob_fast()` instead of the legacy pure-R implementations.

* quantify_binary_fast() evaluates binary scenarios with the same semantics as `quantify_binary()` using streamlined coercion for larger batches.

* quantify_prob_fast() computes top-event probabilities with the same exact truth-table method as `quantify_prob()` using a compiled inner loop for faster multi-scenario evaluation.
