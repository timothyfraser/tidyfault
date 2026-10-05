# it_security_case_study.R
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
# Runs as-is in R, or in the browser through webR (tidyfault.netlify.app).
# Its Python twin is it_security_case_study.py, in this same folder.

# 0. Packages and settings ##################################################

library(dplyr)     # data wrangling
library(tidyr)     # pivot_wider()
library(tidyfault) # fault tree analysis

set.seed(20261012) # a fixed seed, so every run gives the same draws

horizon = 8760     # the time window for a single probability: one year, in hours
times = seq(from = 0, to = 87600, by = 4380) # step 5: 0 to 10 years, every half year (hours)
cut = 0.05         # step 4: cut each failure rate by 5%
fix = 0.10         # step 5: a "fix" cuts a component's failure rate by 90%
cv = 0.20          # uncertainty: each failure rate varies by +/- 20% (sd / mean)
n_sims = 1000      # step 5: simulations per scenario and time step
n_worlds = 10000   # step 6: simulated worlds for one year

# The two components we consider fixing in step 5.
component_a = "MN" # no second login step (add multi-factor authentication)
component_b = "PO" # security updates applied late (patch on time)


# 1. The fault tree #########################################################

# Two tidy tables describe the whole system.
# nodes: one row per event or gate (type = "top", "and", "or", or "not" for a
#        basic event). edges: one row per link, parent (from) -> child (to).
nodes = it_security_nodes
edges = it_security_edges

# curate() lists every gate and its inputs; equate() writes the top event as
# one boolean equation; formulate() turns that equation into an R function
# whose arguments are the basic events.
gates = curate(nodes = nodes, edges = edges)
f = gates %>% equate() %>% formulate()


# 2. Failure rates and probabilities ########################################

# One failure rate (lambda, failures per hour) per basic event, in one row.
rates = it_security_outcomes_rates %>%
  select(event, lambda) %>%
  pivot_wider(names_from = event, values_from = lambda)

# If failures arrive at a constant rate, the chance a component has failed
# by time t is 1 - exp(-lambda * t): the exponential distribution, pexp().
probs = rates %>%
  mutate(across(everything(), ~ pexp(q = horizon, rate = .x)))


# 3. Cut sets and the top event #############################################

# A minimal cut set is a smallest group of basic events whose joint failure
# causes the top event. concentrate() finds them (MOCUS, in C++).
cutsets = concentrate(gates)

# The probability that sensitive data leaks within one year.
p_top = quantify(f = f, newdata = probs, prob = TRUE)


# 4. Which fix buys the most? ###############################################

# quantify_if() asks "what if?" once per component: cut that component's
# failure rate by 5%, keep the others as they are, turn every rate into a
# probability within the horizon, and recompute the top event. The baseline
# and all 10 what-ifs go through the fault tree in one call.
whatif = quantify_if(f = f, data = rates, cut = cut, time = horizon)

# The top event's probability with no cut (the same in every row).
baseline = whatif$baseline[1]

# Each what-if as a change from the baseline, biggest drop first.
marginal_effects = whatif %>%
  select(changed = event, p_top, change, pct_change)


# 5. Scenario sweep over time ###############################################

# Four scenarios: fix neither, fix A only, fix B only, or fix both. Each fix
# multiplies that component's failure rate by `fix` (0.10 keeps 10% of its
# failures).
#
# quantify_when() builds one row of failure rates per scenario, repeats it for
# every time step from 0 to 87,600 hours (10 years), turns each rate into the
# probability of failing by that time, and evaluates the fault tree for every
# row in a single call.
#
# Uncertainty (ci = TRUE): we don't know each failure rate exactly, so it
# draws n_sims plausible values per component from a Normal around its
# estimate (sd = cv * lambda), floored at zero. Every scenario and time step
# reuses the SAME draws (common random numbers), so differences between
# scenarios come from the fixes, not noise.
#
# The result has one row per scenario and time step: p_top is the median
# simulation, lower and upper bound the middle 90% of simulations (our
# interval), and reliability is 1 - p_top.
over_time = quantify_when(
  f = f, data = rates,
  "Fix A only"  = setNames(fix, component_a),
  "Fix B only"  = setNames(fix, component_b),
  "Fix A and B" = setNames(c(fix, fix), c(component_a, component_b)),
  time = times, baseline = "Neither",
  ci = TRUE, n = n_sims, cv = cv, level = 0.90
)


# 6. Ten thousand possible worlds ###########################################

# Same idea as step 5, for one year and no fixes, with many more draws: each
# row is one possible world with its own set of failure rates, sent through
# the fault tree in one call. draws = TRUE keeps every world instead of
# summarizing them.
worlds = quantify_ci(f = f, data = rates, n = n_worlds, cv = cv, time = horizon,
                     draws = TRUE) %>%
  rename(world = sim)

uncertainty = worlds %>%
  summarize(median = median(p_top),
            lower = quantile(p_top, probs = 0.05),
            upper = quantile(p_top, probs = 0.95))


# 7. Print the headline results #############################################

cutsets            # the minimal cut sets
p_top              # P(data leaks within one year)
marginal_effects   # which 5% cut lowers that the most
over_time %>% filter(time %in% (c(1, 5, 10) * 8760))  # the four scenarios at 1, 5, 10 years
uncertainty        # the spread across 10,000 worlds

# To draw the scenario sweep as ribbons (needs ggplot2, already installed
# with tidyfault):
#
# library(ggplot2)
# ggplot(over_time, aes(x = time, y = p_top, ymin = lower, ymax = upper,
#                       fill = scenario, color = scenario)) +
#   geom_ribbon(alpha = 0.2, color = NA) +
#   geom_line() +
#   scale_x_continuous(breaks = seq(0, 87600, by = 17520),
#                      labels = function(h) paste0(h, " h\n(", h / 8760, " y)")) +
#   labs(x = "Hours", y = "P(sensitive data leaks by time t)")
