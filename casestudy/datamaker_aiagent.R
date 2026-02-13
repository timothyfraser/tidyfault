library(usethis)
library(devtools)
library(roxygen2)
library(tidyverse)

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

# Save to data directory
use_data(ai_nodes, overwrite = TRUE)
use_data(ai_edges, overwrite = TRUE)
