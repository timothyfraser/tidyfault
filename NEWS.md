# tidyfault (development version)

* tidyfault now ships a Python twin in `python/` with the same function names, arguments and return shapes, tested against R's own output; install it with `pip install "git+https://github.com/timothyfraser/tidyfault#subdirectory=python"`.

* Figures in the README and the vignettes now render at 300 dpi (the README tree figure is 1800x1200 px) with the gate palette.

* tidyfault no longer depends on admisc or QCA.

* The compiled `src/*.o` and `src/*.dll` files are no longer tracked; they were Windows build objects that broke `devtools::load_all()` on Linux and macOS.

* `concentrate()` minimises the MOCUS cut sets by absorption (dropping duplicate and superset cut sets, fewest events first, then by sorted event position). This fixes empty results when a variable named `outcome` exists in the session, removes an undeclared runtime dependency on QCA, and lets `concentrate()` finish on `it_security_nodes`.

* `equate()` matches gate names only as whole tokens, so a gate named `T` no longer matches inside a basic event named `TO` (which made it loop forever on `ai_nodes`), and it stops with an error naming the gates when a gate references itself directly or through other gates.

* `illustrate()` returns a `tidyfault_tree` object for `type = "both"` and `type = "all"`, and `plot()` is now its S3 method, so tidyfault no longer masks `base::plot()`; the default palette follows the gate colours and gains an `edge_colour` argument.

* quantify() gains a `fast` argument (default `TRUE`) that dispatches to `quantify_binary_fast()` or `quantify_prob_fast()` instead of the legacy pure-R implementations.

* quantify_binary_fast() evaluates binary scenarios with the same semantics as `quantify_binary()` using streamlined coercion for larger batches.

* quantify_prob_fast() computes top-event probabilities with the same exact truth-table method as `quantify_prob()` using a compiled inner loop for faster multi-scenario evaluation.
