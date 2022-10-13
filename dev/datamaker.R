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

# Make a data directory if it doesn't already exist
dir.create("data")
# Save fake data to file
use_data(fakenodes, overwrite = TRUE)
use_data(fakeedges, overwrite = TRUE)
