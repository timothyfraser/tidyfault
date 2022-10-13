# dev_workflow.R
# Tim Fraser, Fall 2022
# Usual workflow for updating this package


# Remove, Rinse, and Repeat
detach("package:tidyfault", unload = TRUE)
devtools::uninstall("tidyfault")
.rs.restartR()


# Load packages
library(devtools)
library(roxygen2)
library(tidyverse)

# Process Documentation
setwd("/cloud/project/")
document()


# Formally install
setwd("..")
install("/cloud/project/")
# Load
library(tidyfault)



#######################
# Make a vignette
#######################
#usethis::use_vignette("tidyfault")

#setwd("/cloud/project/")


######################
# Put on Github
######################


################################
# Test from Github
################################

library(devtools)
# It works!
install_github("timothyfraser/tidyfault")

library(tidyfault)

tidyfault()
vignette("tidyfault")


##############
# Trial Run
#################
#data("starwars")

# Load dependencies
library(tidyverse)
library(tidyfault)
library(QCA)
 
# Load example data into our environment
data("fakenodes")
data("fakeedges")

# Extract minimum cutset from fault tree data
curate(
  nodes = fakenodes, 
  edges = fakeedges) %>%
  equate() %>%
  formulate() %>%
  calculate() %>%
  concentrate() %>% 
  tabulate()

gg = illustrate(nodes = fakenodes, edges = fakeedges, type = c("both"))

gg$nodes %>% head()

gg$edges %>% head()
