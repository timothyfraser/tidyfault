# tidyfault (development version)

* tidyfault now ships a Python twin in `python/` with the same function names, arguments and return shapes, tested against R's own output; install it with `pip install "git+https://github.com/timothyfraser/tidyfault#subdirectory=python"`.

* Figures in the README and the vignettes now render at 300 dpi (the README tree figure is 1800x1200 px) with the gate palette.

* tidyfault no longer depends on admisc or QCA.

* The bundled `db_nodes`/`db_edges`, `ai_nodes`/`ai_edges` and `security_nodes`/`security_edges` trees gain an OR gate `G0` between the top event `T` and its former children, so each top event has exactly one gate child. Their minimal cut sets are now `AF`, `AUF`, `DC`, `NF`, `BF*SF`, `HF*MF` (db), `AF`, `CWE`, `RL`, `TO` (ai) and `MW`, `PH`, `UA`, `ES*VE`, `N2F*WP` (security), which agree with `equate()`; previously MOCUS read these tops as AND and returned four 6-event (db) and three 5-event (security) cut sets. The `*_probs` and `*_outcomes_*` datasets are unchanged.

* The compiled `src/*.o` and `src/*.dll` files are no longer tracked; they were Windows build objects that broke `devtools::load_all()` on Linux and macOS.

* `concentrate()` minimises the MOCUS cut sets by absorption (dropping duplicate and superset cut sets, fewest events first, then by sorted event position). This fixes empty results when a variable named `outcome` exists in the session, removes an undeclared runtime dependency on QCA, and lets `concentrate()` finish on `it_security_nodes`.

* `curate()` now stops when the tree does not have exactly one top event, or when the top event does not have exactly one child that is an `and` or `or` gate. The top event carries no logic of its own: a top event with several children used to be read as OR by `curate()`/`equate()` but as AND by MOCUS, so `concentrate()` and the equation disagreed. The error names the top event and its children and asks you to insert an `or` or `and` gate between them; MOCUS now starts from the top event's one gate.

* `equate()` matches gate names only as whole tokens, so a gate named `T` no longer matches inside a basic event named `TO` (which made it loop forever on `ai_nodes`), and it stops with an error naming the gates when a gate references itself directly or through other gates.

* `illustrate()` returns a `tidyfault_tree` object for `type = "both"` and `type = "all"`, and `plot()` is now its S3 method, so tidyfault no longer masks `base::plot()` (the generic is re-exported, so `tidyfault::plot(x)` works as before); the default palette follows the gate colours and gains an `edge_colour` argument.

* quantify() gains a `fast` argument (default `TRUE`) that dispatches to `quantify_binary_fast()` or `quantify_prob_fast()` instead of the legacy pure-R implementations.

* quantify_binary_fast() evaluates binary scenarios with the same semantics as `quantify_binary()` using streamlined coercion for larger batches.

* quantify_prob_fast() computes top-event probabilities with the same exact truth-table method as `quantify_prob()` using a compiled inner loop for faster multi-scenario evaluation.

* `simulate()` gives the top event exactly one gate: with two or more gates (or none) it adds an OR gate `G0`, with the last node id, between the top event and the other gates. No random draw is added, so a seed gives the same gates, basic events and probabilities as before.
