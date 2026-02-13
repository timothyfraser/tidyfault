library(usethis)
library(devtools)
library(roxygen2)
library(tidyverse)

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

# Save to data directory
use_data(security_nodes, overwrite = TRUE)
use_data(security_edges, overwrite = TRUE)
