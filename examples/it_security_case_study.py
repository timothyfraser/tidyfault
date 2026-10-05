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
#   2. Turn each component's failure rate (lambda, per hour) into the
#      probability that it fails within a given time.
#   3. Find the minimal cut sets and the probability of the top event.
#   4. Ask "which fix buys the most?": cut each failure rate by 5%, one at a
#      time, and measure how much the top event's probability drops.
#   5. Sweep four scenarios over 10 years (fix A, fix B, both, neither),
#      where a fix removes 90% of a component's failures, simulating
#      uncertainty in every failure rate, and report the probability of the
#      top event with 90% intervals.
#   6. Simulate 10,000 possible worlds for one year, to show the full
#      distribution of the risk.
#
# Time is in hours, the reliability-engineering convention: failure rates are
# failures per hour, and 8,760 hours is one year (24 * 365).
#
# Runs as-is in Python, or in the browser through Pyodide
# (tidyfault.netlify.app). Its R twin is it_security_case_study.R, in this same
# folder. The two use different random number generators, so the simulated
# numbers (steps 5 and 6) agree closely but not exactly.

# 0. Packages and settings ####################################################

import numpy as np      # arrays and random draws
import pandas as pd     # data wrangling
import tidyfault as tf  # fault tree analysis

rng = np.random.default_rng(20261012)  # a fixed seed, so every run gives the same draws

horizon = 8760     # the time window for a single probability: one year, in hours
times = np.arange(0, 87600 + 1, 4380)  # step 5: 0 to 10 years, every half year (hours)
cut = 0.05         # step 4: cut each failure rate by 5%
fix = 0.10         # step 5: a "fix" cuts a component's failure rate by 90%
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

# One failure rate (lambda, failures per hour) per basic event, in one row.
outcomes = tf.data.load_data("it_security_outcomes_rates")[["event", "lambda"]]
rates = outcomes.set_index("event")["lambda"].to_frame().T.reset_index(drop=True)
rates.columns.name = None
events = list(rates.columns)


# If failures arrive at a constant rate, the chance a component has failed
# by time t is 1 - exp(-lambda * t): the exponential distribution (R's pexp()).
def pexp(q, rate):
    return 1 - np.exp(-rate * q)


probs = pexp(horizon, rates)


# 3. Cut sets and the top event ###############################################

# A minimal cut set is a smallest group of basic events whose joint failure
# causes the top event. concentrate() finds them (MOCUS).
cutsets = tf.concentrate(gates)

# The probability that sensitive data leaks within one year.
p_top = float(tf.quantify(f, newdata=probs, prob=True))


# 4. Which fix buys the most? #################################################

# quantify_if() asks "what if?" once per component: cut that component's
# failure rate by 5%, keep the others as they are, turn every rate into a
# probability within the horizon, and recompute the top event. The baseline
# and all 10 what-ifs go through the fault tree in one call.
whatif = tf.quantify_if(f, rates, cut=cut, time=horizon)

# The top event's probability with no cut (the same in every row).
baseline = whatif["baseline"].iloc[0]

# Each what-if as a change from the baseline, biggest drop first.
marginal_effects = (
    whatif.rename(columns={"event": "changed"})
    [["changed", "p_top", "change", "pct_change"]]
)


# 5. Scenario sweep over time #################################################

# Four scenarios: fix neither, fix A only, fix B only, or fix both. Each fix
# multiplies that component's failure rate by `fix` (0.10 keeps 10% of its
# failures).
#
# quantify_when() builds one row of failure rates per scenario, repeats it for
# every time step from 0 to 87,600 hours (10 years), turns each rate into the
# probability of failing by that time, and evaluates the fault tree for every
# row. (R passes the scenarios as named arguments; Python takes a dict.)
#
# Uncertainty (ci=True): we don't know each failure rate exactly, so it draws
# n_sims plausible values per component from a Normal around its estimate
# (sd = cv * lambda), floored at zero. Every scenario and time step reuses the
# SAME draws (common random numbers), so differences between scenarios come
# from the fixes, not noise. Passing rng continues this script's random stream.
#
# The result has one row per scenario and time step: p_top is the median
# simulation, lower and upper bound the middle 90% of simulations (our
# interval), and reliability is 1 - p_top.
over_time = tf.quantify_when(f, rates, {
    "Fix A only": {component_a: fix},
    "Fix B only": {component_b: fix},
    "Fix A and B": {component_a: fix, component_b: fix},
}, time=times, baseline="Neither", ci=True, n=n_sims, cv=cv, level=0.90, seed=rng)


# 6. Ten thousand possible worlds #############################################

# Same idea as step 5, for one year and no fixes, with many more draws: each
# row is one possible world with its own set of failure rates, sent through the
# fault tree. draws=True keeps every world instead of summarizing them.
worlds = tf.quantify_ci(f, rates, n=n_worlds, cv=cv, time=horizon, seed=rng,
                        draws=True).rename(columns={"sim": "world"})

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
print("\nover_time (the four scenarios at 1, 5 and 10 years)")
print(over_time[over_time["time"].isin([8760, 43800, 87600])].to_string(index=False))
print("\nuncertainty (the spread across 10,000 worlds)")
print(uncertainty)

# To draw the scenario sweep as ribbons (needs matplotlib, which is not part of
# the core script above):
#
# import matplotlib.pyplot as plt
# fig, ax = plt.subplots()
# for name, d in over_time.groupby("scenario", observed=True):
#     ax.fill_between(d["time"], d["lower"], d["upper"], alpha=0.2)
#     ax.plot(d["time"], d["p_top"], label=name)
# ax.set_xticks(range(0, 87601, 17520))
# ax.set_xticklabels([f"{h:,} h\n({h // 8760} y)" for h in range(0, 87601, 17520)])
# ax.set_xlabel("Hours")
# ax.set_ylabel("P(sensitive data leaks by time t)")
# ax.legend()
# plt.show()
