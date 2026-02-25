library(usethis)
library(devtools)
library(roxygen2)
library(tidyverse)
setwd("/cloud/project")
getwd()

# Let's make a data.frame of nodes!
fakenodes = tribble(
  # Make the headers, using a tilde
  ~id, ~event, ~type,
  # Add the value entries
  1,  "T",   "top",
  2,  "G1",  "and",  
  3,  "G2",  "and",
  4,  "G3",  "or",
  5,  "G4",  "and",
  6,  "G5",  "or",
  7,  "A",   "not",
  # Notice how event 'B' appears twice,
  # so it has a logical but differentiated `id` "8" and "9"?
  8,  "B",   "not",
  9,  "B",   "not",
  10, "C",   "not",
  11, "C",   "not",
  12, "D",   "not") %>%
  # Classify 'type' as a factor, with specific levels
  mutate(type = factor(type, levels = c("top", "and", "or", "not")))


fakeedges = tribble(
  ~from, ~to,
  1,   2,
  2,   3,
  3,   8,
  3,   6,
  6,   10,
  6,   12,
  2,   4,
  4,   7,
  4,   5,
  5,   9,
  5,   11) 

# AI Agent Failure Fault Tree
# Top event: AI agent task failure
# Gates:
#   G3 (OR): API failure OR timeout OR rate limit

ai_nodes = tribble(
  ~id, ~event, ~type,
  1,  "T",   "top",      # Top event: AI agent task failure
  2,  "G3",  "or",       # OR gate: API failure OR timeout OR rate limit
  3,  "AF",  "not",      # API failure
  4,  "TO",  "not",      # Timeout
  5,  "RL",  "not",      # Rate limit
  6,  "CWE", "not") %>%  # Context window exceeded
  mutate(type = factor(type, levels = c("top", "and", "or", "not")))

ai_edges = tribble(
  ~from, ~to,
  1,   2,    # Top -> G3 (OR: API failure or timeout or rate limit)
  2,   3,    # G3 -> API failure
  2,   4,    # G3 -> Timeout
  2,   5,    # G3 -> Rate limit
  1,   6)    # Top -> Context window exceeded

# Security Breach Fault Tree
# Top event: Security breach detected
# Gates:
#   G2 (AND): Vulnerability exists AND exploit successful
#   G3 (OR): Phishing OR malware OR unauthorized access
#   G4 (AND): Weak password AND no 2FA

security_nodes = tribble(
  ~id, ~event, ~type,
  1,  "T",   "top",      # Top event: Security breach detected
  2,  "G2",  "and",      # AND gate: Vulnerability exists AND exploit successful
  3,  "G3",  "or",       # OR gate: Phishing OR malware OR unauthorized access
  4,  "G4",  "and",      # AND gate: Weak password AND no 2FA
  5,  "VE",  "not",      # Vulnerability exists
  6,  "ES",  "not",      # Exploit successful
  7,  "PH",  "not",      # Phishing
  8,  "MW",  "not",      # Malware
  9,  "UA",  "not",      # Unauthorized access
  10, "WP",  "not",      # Weak password
  11, "N2F", "not") %>%  # No 2FA
  mutate(type = factor(type, levels = c("top", "and", "or", "not")))

security_edges = tribble(
  ~from, ~to,
  1,   2,    # Top -> G2 (AND: vulnerability and exploit)
  2,   5,    # G2 -> Vulnerability exists
  2,   6,    # G2 -> Exploit successful
  1,   3,    # Top -> G3 (OR: phishing or malware or unauthorized)
  3,   7,    # G3 -> Phishing
  3,   8,    # G3 -> Malware
  3,   9,    # G3 -> Unauthorized access
  1,   4,    # Top -> G4 (AND: weak password and no 2FA)
  4,   10,   # G4 -> Weak password
  4,   11)   # G4 -> No 2FA

# Database System Failure Fault Tree
# Top event: Database system unavailable
# Gates:
#   G1 (OR): Data corruption OR Access failure
#   G2 (AND): Storage failure AND Backup failure
#   G3 (OR): Network failure OR Authentication failure
#   G4 (AND): Hardware failure AND Monitoring failure

db_nodes = tribble(
  ~id, ~event, ~type,
  1,  "T",   "top",      # Top event: Database system unavailable
  2,  "G1",  "or",       # OR gate: Data corruption OR Access failure
  3,  "G2",  "and",      # AND gate: Storage failure AND Backup failure
  4,  "G3",  "or",       # OR gate: Network failure OR Authentication failure
  5,  "G4",  "and",      # AND gate: Hardware failure AND Monitoring failure
  6,  "DC",  "not",      # Data corruption
  7,  "AF",  "not",      # Access failure
  8,  "SF",  "not",      # Storage failure
  9,  "BF",  "not",      # Backup failure
  10, "NF",  "not",      # Network failure
  11, "AUF", "not",      # Authentication failure
  12, "HF",  "not",      # Hardware failure
  13, "MF",  "not") %>%  # Monitoring failure
  mutate(type = factor(type, levels = c("top", "and", "or", "not")))

db_edges = tribble(
  ~from, ~to,
  1,   2,    # Top -> G1 (OR: data corruption or access failure)
  2,   6,    # G1 -> Data corruption
  2,   7,    # G1 -> Access failure
  1,   3,    # Top -> G2 (AND: storage failure and backup failure)
  3,   8,    # G2 -> Storage failure
  3,   9,    # G2 -> Backup failure
  1,   4,    # Top -> G3 (OR: network failure or authentication failure)
  4,   10,   # G3 -> Network failure
  4,   11,   # G3 -> Authentication failure
  1,   5,    # Top -> G4 (AND: hardware failure and monitoring failure)
  5,   12,   # G4 -> Hardware failure
  5,   13)   # G4 -> Monitoring failure

# AI Agent Failure - Outcome Datasets

# 1. Probability outcomes
ai_probs = tribble(
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

# Database System Failure - Outcome Datasets

# 1. Probability outcomes
db_probs = tribble(
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

# Security Breach - Outcome Datasets

# 1. Probability outcomes
security_probs = tribble(
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

# Make a data directory if it doesn't already exist
dir.create("data", showWarnings = FALSE)
# Save fake data to file
use_data(fakenodes, overwrite = TRUE)
use_data(fakeedges, overwrite = TRUE)
# Save AI agent datasets
use_data(ai_nodes, overwrite = TRUE)
use_data(ai_edges, overwrite = TRUE)
use_data(ai_probs, overwrite = TRUE)
use_data(ai_outcomes_binary, overwrite = TRUE)
use_data(ai_outcomes_rates, overwrite = TRUE)
# Save security datasets
use_data(security_nodes, overwrite = TRUE)
use_data(security_edges, overwrite = TRUE)
use_data(security_probs, overwrite = TRUE)
use_data(security_outcomes_binary, overwrite = TRUE)
use_data(security_outcomes_rates, overwrite = TRUE)
# Save database datasets
use_data(db_nodes, overwrite = TRUE)
use_data(db_edges, overwrite = TRUE)
use_data(db_probs, overwrite = TRUE)
use_data(db_outcomes_binary, overwrite = TRUE)
use_data(db_outcomes_rates, overwrite = TRUE)