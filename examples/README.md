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

## Run it

From the root of the repository:

```
Rscript examples/it_security_case_study.R
python examples/it_security_case_study.py
```

You need the tidyfault package for the language you use. The R script also uses
dplyr, tidyr and purrr. The Python script uses pandas and numpy.

Both scripts also run in the browser on the tidyfault website, through webR (R)
and Pyodide (Python). Nothing needs to be installed.

## R and Python numbers

Each script sets its own random seed, but R and Python use different random
number generators. The exact results (cut sets, the probability of the top
event, and the ranking of fixes) match to many decimal places. The simulated
results (the scenario sweep and the 10,000 worlds) agree closely but not
exactly.
