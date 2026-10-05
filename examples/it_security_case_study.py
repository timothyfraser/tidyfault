# it_security_case_study.py
#
# A HYPOTHETICAL case study: how could sensitive data leak out of an
# organization, and which fixes would lower that risk the most?
#
# The fault tree, failure rates and fixes below are illustrative. They come
# from tidyfault's bundled example data (it_security_nodes, it_security_edges,
# it_security_outcomes_rates), not from a real organization's records.
#
# What this script does, in order:
#   1. Build the fault tree from two tidy tables (nodes + edges).
#   2. Turn each component's failure rate (lambda, per year) into the
#      probability that it fails within a given time.
#   3. Find the minimal cut sets and the probability of the top event.
#   4. Ask "which fix buys the most?": cut each failure rate by 5%, one at a
#      time, and measure how much the top event's probability drops.
#   5. Sweep four scenarios over 10 years (fix A, fix B, both, neither),
#      simulating uncertainty in every failure rate, and report the
#      probability of the top event with 90% intervals.
#   6. Simulate 10,000 possible worlds for one year, to show the full
#      distribution of the risk.
#
# Runs as-is in Python, or in the browser through Pyodide
# (tidyfault.netlify.app). Its R twin is it_security_case_study.R, in this same
# folder. The two use different random number generators, so the simulated
# numbers (steps 5 and 6) agree closely but not exactly.

# 0. Packages and settings ####################################################

import numpy as np      # arrays and random draws
import pandas as pd     # data wrangling
import tidyfault as tf  # fault tree analysis

rng = np.random.default_rng(20261012)  # the conference date, so every run gives the same draws

horizon = 1        # the time window for a single probability (years)
cut = 0.05         # step 4: cut each failure rate by 5%
fix = 0.50         # step 5: a "fix" halves a component's failure rate
cv = 0.20          # uncertainty: each failure rate varies by +/- 20% (sd / mean)
n_sims = 1000      # step 5: simulations per scenario and time step
n_worlds = 10000   # step 6: simulated worlds for one year

# The two components we consider fixing in step 5.
component_a = "MN"  # no second login step (add multi-factor authentication)
component_b = "PO"  # security updates applied late (patch on time)


# 1. The fault tree ###########################################################

# Two tidy tables describe the whole system.
# nodes: one row per event or gate (type = "top", "and", "or", or "not" for a
#        basic event). edges: one row per link, parent (from) -> child (to).
nodes = tf.data.load_data("it_security_nodes")
edges = tf.data.load_data("it_security_edges")

# curate() lists every gate and its inputs; equate() writes the top event as
# one boolean equation; formulate() turns that equation into a Python function
# whose arguments are the basic events.
gates = tf.curate(nodes=nodes, edges=edges)
f = tf.formulate(tf.equate(gates))


# 2. Failure rates and probabilities ##########################################

# One failure rate (lambda, events per year) per basic event, in one row.
outcomes = tf.data.load_data("it_security_outcomes_rates")[["event", "lambda"]]
rates = outcomes.set_index("event")["lambda"].to_frame().T.reset_index(drop=True)
rates.columns.name = None
events = list(rates.columns)


# If failures arrive at a constant rate, the chance a component has failed
# by time t is 1 - exp(-lambda * t): the exponential distribution (R's pexp()).
def pexp(q, rate):
    return 1 - np.exp(-rate * q)


probs = pexp(horizon, rates)


# quantify() checks every possible state of the tree for every row of newdata.
# With 10 basic events that is 1,024 states per row, so for tens of thousands of
# rows we hand it the rows in chunks. The answer is the same, just lighter on
# memory (this matters in the browser).
def quantify_top(newdata, chunk=1000):
    newdata = newdata[events]
    out = [tf.quantify(f, newdata=newdata.iloc[i:i + chunk], prob=True)
           for i in range(0, len(newdata), chunk)]
    return np.concatenate([np.atleast_1d(o) for o in out])


# 3. Cut sets and the top event ###############################################

# A minimal cut set is a smallest group of basic events whose joint failure
# causes the top event. concentrate() finds them (MOCUS).
cutsets = tf.concentrate(gates)

# The probability that sensitive data leaks within one year.
p_top = float(quantify_top(probs)[0])


# 4. Which fix buys the most? #################################################

# Make one row per "what-if": cut one component's failure rate by 5%, keep
# the others as they are. Add the unchanged baseline as a final row.
whatif = pd.concat(
    [rates.assign(**{e: rates[e] * (1 - cut)}).assign(changed=e) for e in events]
    + [rates.assign(changed="none")],
    ignore_index=True,
)
# Convert every rate to a probability within the horizon...
whatif[events] = pexp(horizon, whatif[events])
# ...and compute the top event's probability for all 11 rows in one call.
whatif["p_top"] = quantify_top(whatif)

# Express each what-if as a percent change from the baseline.
baseline = whatif.loc[whatif["changed"] == "none", "p_top"].iloc[0]

marginal_effects = (
    whatif[whatif["changed"] != "none"]
    .assign(change=lambda d: d["p_top"] - baseline,
            pct_change=lambda d: 100 * (d["p_top"] / baseline - 1))
    .sort_values("pct_change", kind="stable")
    [["changed", "p_top", "change", "pct_change"]]
    .reset_index(drop=True)
)


# 5. Scenario sweep over time #################################################

# Four scenarios: fix neither, fix A only, fix B only, or fix both.
scenarios = pd.DataFrame({
    "scenario": ["Neither", "Fix A only", "Fix B only", "Fix A and B"],
    "fix_a": [False, True, False, True],
    "fix_b": [False, False, True, True],
})

# Uncertainty: we don't know each failure rate exactly. Draw n_sims plausible
# values per component from a Normal around its estimate (sd = cv * lambda),
# floored at zero. Every scenario reuses the SAME draws (common random
# numbers), so differences between scenarios come from the fixes, not noise.
lam = rates.iloc[0].to_numpy()
draws = pd.DataFrame(np.maximum(rng.normal(loc=lam, scale=cv * lam,
                                           size=(n_sims, len(events))), 0),
                     columns=events)
draws["sim"] = np.arange(1, n_sims + 1)

# One row per scenario and simulation, one column per component's rate.
sweep = scenarios.merge(draws, how="cross")
# Apply each scenario's fixes: halve the failure rate of A and/or B.
sweep[component_a] = np.where(sweep["fix_a"], sweep[component_a] * fix, sweep[component_a])
sweep[component_b] = np.where(sweep["fix_b"], sweep[component_b] * fix, sweep[component_b])
sweep = sweep.drop(columns=["fix_a", "fix_b"])
# Repeat every row for each time step from 0 to 10 years...
sweep = sweep.merge(pd.DataFrame({"years": np.arange(0, 10.5, 0.5)}), how="cross")
# ...turn rates into probabilities of failing by that time...
sweep[events] = pexp(sweep[["years"]].to_numpy(), sweep[events].to_numpy())
# ...and evaluate the fault tree for every row.
sweep["p_top"] = quantify_top(sweep)

# Summarize each scenario at each time step: the median simulation and the
# middle 90% of simulations (our interval). Reliability is 1 - P(top event).
sweep["scenario"] = pd.Categorical(sweep["scenario"], categories=scenarios["scenario"])
over_time = (
    sweep.groupby(["scenario", "years"], observed=True)["p_top"]
    .agg(lower=lambda x: x.quantile(0.05),
         upper=lambda x: x.quantile(0.95),
         p_top="median")
    .reset_index()
    .assign(reliability=lambda d: 1 - d["p_top"])
    [["scenario", "years", "lower", "upper", "p_top", "reliability"]]
    .sort_values(["scenario", "years"])
    .reset_index(drop=True)
)


# 6. Ten thousand possible worlds #############################################

# Same idea as step 5, for one year and no fixes, with many more draws: each
# row is one possible world with its own set of failure rates.
worlds = pd.DataFrame(pexp(horizon, np.maximum(rng.normal(loc=lam, scale=cv * lam,
                                                          size=(n_worlds, len(events))), 0)),
                      columns=events)
worlds.insert(0, "world", np.arange(1, n_worlds + 1))

# All 10,000 worlds through the fault tree.
worlds["p_top"] = quantify_top(worlds)

uncertainty = pd.DataFrame({
    "median": [worlds["p_top"].median()],
    "lower": [worlds["p_top"].quantile(0.05)],
    "upper": [worlds["p_top"].quantile(0.95)],
})


# 7. Print the headline results ###############################################

print("\ncutsets (the minimal cut sets)")
print(cutsets)
print("\np_top (P(data leaks within one year))")
print(p_top)
print("\nmarginal_effects (which 5% cut lowers that the most)")
print(marginal_effects)
print("\nover_time (the four scenarios, 3 horizons)")
print(over_time[over_time["years"].isin([1, 5, 10])].to_string(index=False))
print("\nuncertainty (the spread across 10,000 worlds)")
print(uncertainty)

# To draw the scenario sweep as ribbons (needs matplotlib, which is not part of
# the core script above):
#
# import matplotlib.pyplot as plt
# fig, ax = plt.subplots()
# for name, d in over_time.groupby("scenario", observed=True):
#     ax.fill_between(d["years"], d["lower"], d["upper"], alpha=0.2)
#     ax.plot(d["years"], d["p_top"], label=name)
# ax.set_xlabel("Years")
# ax.set_ylabel("P(sensitive data leaks by year t)")
# ax.legend()
# plt.show()
