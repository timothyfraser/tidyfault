library(usethis)
library(devtools)
library(roxygen2)
library(tidyverse)

# Security Breach - Outcome Datasets

# 1. Probability outcomes
security_outcomes_prob = tribble(
  ~event, ~probability,
  "VE",   0.25,   # Vulnerability exists
  "ES",   0.12,   # Exploit successful
  "PH",   0.20,   # Phishing
  "MW",   0.18,   # Malware
  "UA",   0.10,   # Unauthorized access
  "WP",   0.30,   # Weak password
  "N2F",  0.22)   # No 2FA

# 2. Binary outcomes (10 scenarios)
set.seed(42)  # For reproducibility
security_outcomes_binary = tibble(
  scenario = 1:10,
  VE = c(1, 1, 0, 1, 1, 0, 1, 1, 0, 1),      # Vulnerability exists
  ES = c(0, 1, 0, 0, 1, 0, 0, 0, 1, 0),      # Exploit successful
  PH = c(1, 0, 1, 1, 0, 1, 0, 1, 0, 1),      # Phishing
  MW = c(0, 1, 1, 0, 1, 0, 1, 0, 1, 0),      # Malware
  UA = c(0, 0, 0, 1, 0, 0, 0, 1, 0, 0),      # Unauthorized access
  WP = c(1, 1, 1, 0, 1, 1, 0, 1, 1, 1),      # Weak password
  N2F = c(1, 0, 1, 1, 0, 1, 1, 0, 1, 1)      # No 2FA
)

# 3. Exponential failure rates (lambda per day)
security_outcomes_rates = tribble(
  ~event, ~lambda, ~time_unit,
  "VE",   0.005,   "days",   # Vulnerability exists: 0.005 failures/day
  "ES",   0.0025,  "days",   # Exploit successful: 0.0025 failures/day
  "PH",   0.004,   "days",   # Phishing: 0.004 failures/day
  "MW",   0.0035,  "days",   # Malware: 0.0035 failures/day
  "UA",   0.002,   "days",   # Unauthorized access: 0.002 failures/day
  "WP",   0.006,   "days",   # Weak password: 0.006 failures/day
  "N2F",  0.0045,  "days")   # No 2FA: 0.0045 failures/day

# Save to data directory
use_data(security_outcomes_prob, overwrite = TRUE)
use_data(security_outcomes_binary, overwrite = TRUE)
use_data(security_outcomes_rates, overwrite = TRUE)
