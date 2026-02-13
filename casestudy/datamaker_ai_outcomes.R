library(usethis)
library(devtools)
library(roxygen2)
library(tidyverse)

# AI Agent Failure - Outcome Datasets

# 1. Probability outcomes
ai_outcomes_prob = tribble(
  ~event, ~probability,
  "AF",   0.15,   # API failure
  "TO",   0.20,   # Timeout
  "RL",   0.25,   # Rate limit
  "CWE",  0.14)   # Context window exceeded

# 2. Binary outcomes (10 scenarios)
set.seed(42)  # For reproducibility
ai_outcomes_binary = tibble(
  scenario = 1:10,
  AF = c(1, 1, 0, 0, 1, 0, 1, 0, 1, 0),      # API failure
  TO = c(1, 0, 1, 1, 0, 1, 0, 1, 0, 1),      # Timeout
  RL = c(1, 1, 1, 0, 1, 1, 1, 0, 1, 1),      # Rate limit
  CWE = c(0, 1, 0, 1, 0, 0, 1, 0, 0, 1)      # Context window exceeded
)

# 3. Exponential failure rates (lambda per 1000 requests)
ai_outcomes_rates = tribble(
  ~event, ~lambda, ~time_unit,
  "AF",   0.30,    "per_1000_requests",   # API failure: 0.30 failures/1000 requests
  "TO",   0.40,    "per_1000_requests",   # Timeout: 0.40 failures/1000 requests
  "RL",   0.50,    "per_1000_requests",   # Rate limit: 0.50 failures/1000 requests
  "CWE",  0.28,    "per_1000_requests")   # Context window exceeded: 0.28 failures/1000 requests

# Save to data directory
use_data(ai_outcomes_prob, overwrite = TRUE)
use_data(ai_outcomes_binary, overwrite = TRUE)
use_data(ai_outcomes_rates, overwrite = TRUE)
