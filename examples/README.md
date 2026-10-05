# Examples

This folder holds one worked example, in two languages.

- `it_security_case_study.R` is the case study in R.
- `it_security_case_study.py` is the same case study in Python.

The case study is **hypothetical**. It asks how sensitive data could leak out of
an organization and which fixes would lower that risk the most. The fault tree
and the failure rates come from tidyfault's bundled example data
(`it_security_nodes`, `it_security_edges`, `it_security_outcomes_rates`), not
from a real organization.

Both scripts follow the same steps: build the tree, turn failure rates into
probabilities, find the minimal cut sets, rank the fixes, sweep four scenarios
over 10 years with uncertainty, and simulate 10,000 possible worlds.

Time is in hours, the reliability-engineering convention. The failure rates
are failures per hour, a single probability uses a horizon of 8,760 hours (one
year), and the scenario sweep runs from 0 to 87,600 hours (10 years) in steps
of 4,380 hours (half a year).

Three tidyfault helpers do the what-if work, with the same names in R and
Python:

- `quantify_if()` ranks the fixes (step 4): it cuts each failure rate by 5% in
  turn and reports how much the probability of the top event drops.
- `quantify_when()` sweeps the scenarios over time (step 5): fix neither, fix A
  only (add multi-factor authentication, `MN`), fix B only (patch on time,
  `PO`), or both, where a fix removes 90% of that component's failures. One
  call returns `over_time`: `scenario`, `time`, `p_top`, `lower`, `upper` and
  `reliability`.
- `quantify_ci()` is the uncertainty engine (steps 5 and 6): it draws plausible
  failure rates around each estimate (+/- 20%), and every scenario and time
  reuses the same draws, so the differences between scenarios come from the
  fixes alone. `quantify_when()` calls it; step 6 calls it directly with
  `draws = TRUE` to keep all 10,000 worlds.

## Run it

From the root of the repository:

```
Rscript examples/it_security_case_study.R
python examples/it_security_case_study.py
```

You need the tidyfault package for the language you use. The R script also uses
dplyr and tidyr. The Python script uses pandas and numpy.

Both scripts also run in the browser on the tidyfault website, through webR (R)
and Pyodide (Python). Nothing needs to be installed.

## R and Python numbers

Each script sets its own random seed, but R and Python use different random
number generators. The exact results (cut sets, the probability of the top
event, and the ranking of fixes) match to many decimal places. The simulated
results (the scenario sweep and the 10,000 worlds) agree closely but not
exactly.
