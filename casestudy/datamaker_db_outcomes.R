library(usethis)
library(devtools)
library(roxygen2)
library(tidyverse)

# Database System Failure - Outcome Datasets

# 1. Probability outcomes
db_outcomes_prob = tribble(
  ~event, ~probability,
  "DC",   0.05,   # Data corruption
  "AF",   0.10,   # Access failure
  "SF",   0.08,   # Storage failure
  "BF",   0.15,   # Backup failure
  "NF",   0.12,   # Network failure
  "AUF",  0.06,   # Authentication failure
  "HF",   0.04,   # Hardware failure
  "MF",   0.20)   # Monitoring failure

# 2. Binary outcomes (10 scenarios)
set.seed(42)  # For reproducibility
db_outcomes_binary = tibble(
  scenario = 1:10,
  DC = c(0, 0, 1, 0, 0, 1, 0, 0, 0, 1),      # Data corruption
  AF = c(1, 0, 0, 1, 0, 0, 1, 0, 1, 0),      # Access failure
  SF = c(0, 1, 0, 0, 0, 0, 1, 0, 0, 0),      # Storage failure
  BF = c(1, 0, 1, 0, 1, 0, 0, 1, 0, 1),      # Backup failure
  NF = c(0, 1, 0, 1, 0, 1, 0, 0, 1, 0),      # Network failure
  AUF = c(0, 0, 0, 0, 1, 0, 0, 0, 0, 1),     # Authentication failure
  HF = c(0, 0, 0, 1, 0, 0, 0, 0, 0, 0),      # Hardware failure
  MF = c(1, 1, 0, 0, 1, 1, 0, 1, 0, 1)       # Monitoring failure
)

# 3. Exponential failure rates (lambda per hour)
db_outcomes_rates = tribble(
  ~event, ~lambda, ~time_unit,
  "DC",   0.0001,  "hours",   # Data corruption: 0.0001 failures/hour
  "AF",   0.0002,  "hours",   # Access failure: 0.0002 failures/hour
  "SF",   0.00015, "hours",   # Storage failure: 0.00015 failures/hour
  "BF",   0.0003,  "hours",   # Backup failure: 0.0003 failures/hour
  "NF",   0.00025, "hours",   # Network failure: 0.00025 failures/hour
  "AUF",  0.00012, "hours",   # Authentication failure: 0.00012 failures/hour
  "HF",   0.00008, "hours",   # Hardware failure: 0.00008 failures/hour
  "MF",   0.0004,  "hours")   # Monitoring failure: 0.0004 failures/hour

# Save to data directory
use_data(db_outcomes_prob, overwrite = TRUE)
use_data(db_outcomes_binary, overwrite = TRUE)
use_data(db_outcomes_rates, overwrite = TRUE)
