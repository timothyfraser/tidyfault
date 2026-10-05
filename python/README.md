# tidyfault (Python)

A Python port of **tidyfault**, the R package for tidy fault tree analysis by
Timothy Fraser and Jingyao Tong (GPL-3; <https://github.com/timothyfraser/tidyfault>).
Pure Python (pandas, numpy, igraph and matplotlib), no compiled code of its own.

**Design rule: R is the reference.** Function names, argument names, column
names, column order, row order and return shapes match R. Where the two
disagree, the Python is the bug, with the deliberate exceptions listed below.
Every ported function is tested against output produced by R itself
(`python/tests/test_core.py`, `python/tests/test_mocus.py`).

## Install and import

```
pip install "git+https://github.com/timothyfraser/tidyfault#subdirectory=python"
```

From a clone of the repository, `pip install "./python[test]"` also installs
pytest, and `python -m pytest python/tests -q` runs the suite.

```python
import tidyfault as tf

nodes, edges = tf.data.fakenodes, tf.data.fakeedges
gates = tf.curate(nodes, edges)          # R: curate(nodes = fakenodes, edges = fakeedges)
equation = tf.equate(gates)              # " ( ( (B *  (C + D) )  *  (A +  (B * C) ) ) ) "
f = tf.formulate(equation)               # function (A, B, C, D)
truth = tf.calculate(f)                  # 16-row truth table, failures first
tf.quantify_prob(f, [0.10, 0.20, 0.05, 0.15])   # 0.01285
tf.tabulate(["B*C", "A*B*D"], formula=f) # coverage 0.8 and 0.4
tf.concentrate(gates)                    # ["B*C", "A*B*D"], the minimal cut sets
tf.quantify(f, [True, True, True, False])            # True: the top event occurs
tf.quantify(f, [0.10, 0.20, 0.05, 0.15], prob=True)  # 0.01285
sim = tf.simulate(n_gates=3, n_basic=8, seed=1)      # {"nodes", "edges", "prob"}
```

## The data model

A fault tree is two tables, exactly as in R:

| table | columns | meaning |
|---|---|---|
| `nodes` | `id`, `event`, `type` | one row per node; `type` is `top`, `and`, `or` or `not` (not a gate = basic event), a Categorical with R's factor levels in R's order |
| `edges` | `from`, `to` | one row per link, parent id to child id |

A basic event that feeds two branches appears twice in `nodes`, same `event`,
different `id`. The top event is not a gate: there is exactly one `top` node,
it has exactly one child, and that child is an `and` or `or` gate. `curate()`
refuses anything else with R's message, word for word, which names the top
event and its children and asks for an `or` or `and` gate between them.
`tf.validate_tree(nodes, edges)` (Python only) checks a tree and names every
problem it finds, including that one.

## R | Python

| R | Python | status |
|---|---|---|
| `curate(nodes, edges)` | `curate(nodes, edges)` | ported; tested against R on 7 trees |
| `equate(data)` | `equate(data)` | ported; tested against R on 7 trees |
| `formulate(formula)` | `formulate(formula)` returns a callable `Formula` | ported; arguments and printed body match R |
| `formalArgs(f)` | `formal_args(f)` | helper |
| `calculate(f)` | `calculate(f)` | ported; full truth tables match R row for row |
| `quantify_prob(f, newdata, truth_table)` | `quantify_prob(f, newdata, truth_table=None)` | ported (top-event probability); matches R to 1e-9 |
| `tabulate(data, formula, method, query)` | `tabulate(data, formula, method="mocus_rcpp", query=False)` | ported; matches R |
| `populate(binary_outcomes, event_probs)` | `populate(binary_outcomes, event_probs)` | ported; matches R |
| `gate(data, group, gate, size, res)` | `gate(data, group="id", gate="type", size=1, res=50)` | ported; polygons match R |
| `gate_and(size, res)`, `gate_or`, `gate_top` | same names | ported; coordinates match R to 1e-12 |
| `get_gate(x, y, gate, size, res)` | `get_gate(x, y, gate, size=1, res=50)` | ported |
| `data("fakenodes")` and the other 26 datasets | `tf.data.fakenodes`, `tf.load_data("fakenodes")` | all 27 bundled as CSV |
| `mocus(data, method)` | `mocus(data, method="mocus_rcpp")` | ported, pure Python (no Rcpp); the cut sets equal R's `mocus_r()` and `mocus_rcpp()` element for element on 7 trees |
| `mocus_r(data)`, `mocus_rcpp(data)`, `mocus_cpp(data)` | same names | ported; one pure-Python queue algorithm behind all of them |
| `concentrate(data, method)` | `concentrate(data, method="mocus_rcpp")` | ported; equals R on 7 trees for all three methods |
| `quantify(f, newdata, prob, fast)` | `quantify(f, newdata, prob=False, fast=True)` | ported; reproduces R on the `*_outcomes_binary` datasets and on 3 probability scenarios per tree to 1e-9 |
| `quantify_binary(f, newdata)` | `quantify_binary(f, newdata)` | ported; DataFrame in, bool array out; one scenario in, one bool out |
| `quantify_binary_fast()`, `quantify_prob_fast()` | same names | aliases of `quantify_binary()` and `quantify_prob()`; R's fast paths return the same values |
| `simulate(n_gates, n_basic, p_range, seed)` | `simulate(n_gates=3, n_basic=8, p_range=(0.01, 0.2), seed=None)` | ported; returns `{"nodes", "edges", "prob"}`, R's list shape; seeded draws differ from R's (see deviation) |
| `illustrate(nodes, edges, type, node_key, layout = "tree", size, scale_size, res)` | `illustrate(nodes, edges, type="nodes", node_key="id", layout="tree", size=0.25, scale_size=False, res=50)` returns a DataFrame or a dict of `nodes`/`edges`/`gates`(/`pairwise`) | ported (igraph Reingold-Tilford tree layout); coordinates match R to 1e-9 on 5 trees; only `layout="tree"` |

## Deliberate deviations from R

1. **`formulate()` never calls `eval()`.** The equation is parsed by a small
   `+` / `*` / parentheses grammar, so a malformed or hostile string raises
   `ValueError` and is never executed. Argument order follows R's `sort()` under
   an English locale: case-insensitive, lowercase first on ties.
2. **`simulate(seed=)` draws from numpy, not R's random stream.** Same
   arguments, checks and return shape; a seed reproduces Python runs but not
   the tree R draws for the same seed.

Whole-number columns in the datasets (ids, 0/1 indicators) load as `int64`. R
stores them as double, but the values are identical.

## Reference outputs

`python/tests/reference/make_r_reference.R` sources the R functions straight
from this repository's R package, runs them on every bundled tree and writes
`python/tests/reference/r_reference.json`. The tests compare against that file.
To regenerate it, from the repository root:

```
Rscript python/tests/reference/make_r_reference.R . python/tests/reference/r_reference.json
```

The MOCUS and `concentrate()` fixtures cover the minimal tree and all six
bundled trees; the `quantify()` fixtures cover `db`, `ai` and `security`. The
file also records `curate()`'s refusal messages for malformed tops, which the
Python must reproduce word for word. A full run takes a few seconds.

`data/*.csv` were converted from the R package's `data/*.rda` with `pyreadr`;
the tree tables changed by the repair of `db`, `ai` and `security` were
rewritten from R with `write.csv(d, path, row.names = FALSE, quote = FALSE)`
(factors as character), which reproduces the other tree CSVs byte for byte.
| `plot(x, ...)` (ggplot) | `plot(ill, ...)` returns a matplotlib `Figure`; `to_png(fig, path, dpi=300)` | ported; same shapes, viridis fills, labels and legend as R |
