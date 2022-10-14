# dev_publishing.R
# Tim Fraser, Fall 2022
# R Script for final steps for publishing package on Github 

# Load packages
library(tidyverse)
library(devtools)
library(roxygen2)
library(usethis)

document()
library(credentials)
set_github_pat()
