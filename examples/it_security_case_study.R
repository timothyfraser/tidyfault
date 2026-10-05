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
# Runs as-is in R, or in the browser through webR (tidyfault.netlify.app).
# Its Python twin is it_security_case_study.py, in this same folder.

# 0. Packages and settings ##################################################

library(dplyr)     # data wrangling
library(tidyr)     # pivot_wider(), crossing()
library(purrr)     # map()
library(tidyfault) # fault tree analysis

set.seed(20261012) # the conference date, so every run gives the same draws

horizon = 1        # the time window for a single probability (years)
cut = 0.05         # step 4: cut each failure rate by 5%
fix = 0.50         # step 5: a "fix" halves a component's failure rate
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

# One failure rate (lambda, events per year) per basic event, in one row.
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

# Make one row per "what-if": cut one component's failure rate by 5%, keep
# the others as they are. Add the unchanged baseline as a final row.
whatif = names(rates) %>%
  map(~ rates %>% mutate(across(all_of(.x), ~ .x * (1 - cut)), changed = .x)) %>%
  bind_rows() %>%
  bind_rows(rates %>% mutate(changed = "none")) %>%
  # Convert every rate to a probability within the horizon...
  mutate(across(-changed, ~ pexp(q = horizon, rate = .x))) %>%
  # ...and compute the top event's probability for all 11 rows in one call.
  mutate(p_top = quantify(f = f, newdata = pick(-changed), prob = TRUE))

# Express each what-if as a percent change from the baseline.
baseline = whatif %>% filter(changed == "none") %>% pull(p_top)

marginal_effects = whatif %>%
  filter(changed != "none") %>%
  mutate(change = p_top - baseline,
         pct_change = 100 * (p_top / baseline - 1)) %>%
  arrange(pct_change) %>%
  select(changed, p_top, change, pct_change)


# 5. Scenario sweep over time ###############################################

# Four scenarios: fix neither, fix A only, fix B only, or fix both.
scenarios = tibble(
  scenario = c("Neither", "Fix A only", "Fix B only", "Fix A and B"),
  fix_a = c(FALSE, TRUE, FALSE, TRUE),
  fix_b = c(FALSE, FALSE, TRUE, TRUE)
)

# Uncertainty: we don't know each failure rate exactly. Draw n_sims plausible
# values per component from a Normal around its estimate (sd = cv * lambda),
# floored at zero. Every scenario reuses the SAME draws (common random
# numbers), so differences between scenarios come from the fixes, not noise.
draws = it_security_outcomes_rates %>%
  select(event, lambda) %>%
  crossing(sim = seq_len(n_sims)) %>%
  mutate(lambda_sim = pmax(rnorm(n = n(), mean = lambda, sd = cv * lambda), 0))

sweep = draws %>%
  crossing(scenarios) %>%
  # Apply each scenario's fixes: halve the failure rate of A and/or B.
  mutate(lambda_sim = case_when(
    event == component_a & fix_a ~ lambda_sim * fix,
    event == component_b & fix_b ~ lambda_sim * fix,
    TRUE ~ lambda_sim
  )) %>%
  # One row per scenario and simulation, one column per component's rate.
  select(scenario, sim, event, lambda_sim) %>%
  pivot_wider(names_from = event, values_from = lambda_sim) %>%
  # Repeat every row for each time step from 0 to 10 years...
  crossing(years = seq(from = 0, to = 10, by = 0.5)) %>%
  # ...turn rates into probabilities of failing by that time...
  mutate(across(all_of(names(rates)), ~ pexp(q = years, rate = .x))) %>%
  # ...and evaluate the fault tree for every row in a single call.
  mutate(p_top = quantify(f = f, newdata = pick(all_of(names(rates))), prob = TRUE))

# Summarize each scenario at each time step: the median simulation and the
# middle 90% of simulations (our interval). Reliability is 1 - P(top event).
over_time = sweep %>%
  group_by(scenario, years) %>%
  # (The interval comes first: once p_top is summarized to its median, the
  # individual simulations are gone.)
  summarize(
    lower = quantile(p_top, probs = 0.05),
    upper = quantile(p_top, probs = 0.95),
    p_top = median(p_top),
    .groups = "drop"
  ) %>%
  mutate(reliability = 1 - p_top,
         scenario = factor(scenario, levels = scenarios$scenario)) %>%
  arrange(scenario, years)


# 6. Ten thousand possible worlds ###########################################

# Same idea as step 5, for one year and no fixes, with many more draws: each
# row is one possible world with its own set of failure rates.
worlds = it_security_outcomes_rates %>%
  select(event, lambda) %>%
  crossing(world = seq_len(n_worlds)) %>%
  mutate(p = pexp(q = horizon,
                  rate = pmax(rnorm(n = n(), mean = lambda, sd = cv * lambda), 0))) %>%
  select(world, event, p) %>%
  pivot_wider(names_from = event, values_from = p)

# All 10,000 worlds through the fault tree in one call.
worlds = worlds %>%
  mutate(p_top = quantify(f = f, newdata = pick(all_of(names(rates))), prob = TRUE))

uncertainty = worlds %>%
  summarize(median = median(p_top),
            lower = quantile(p_top, probs = 0.05),
            upper = quantile(p_top, probs = 0.95))


# 7. Print the headline results #############################################

cutsets            # the minimal cut sets
p_top              # P(data leaks within one year)
marginal_effects   # which 5% cut lowers that the most
over_time %>% filter(years %in% c(1, 5, 10))  # the four scenarios, 3 horizons
uncertainty        # the spread across 10,000 worlds

# To draw the scenario sweep as ribbons (needs ggplot2, already installed
# with tidyfault):
#
# library(ggplot2)
# ggplot(over_time, aes(x = years, y = p_top, ymin = lower, ymax = upper,
#                       fill = scenario, color = scenario)) +
#   geom_ribbon(alpha = 0.2, color = NA) +
#   geom_line() +
#   labs(x = "Years", y = "P(sensitive data leaks by year t)")
