# Startup
#https://hilaryparker.com/2014/04/29/writing-an-r-package-from-scratch/

##################################
# Getting Started
##################################
#install.packages("devtools")
#install.packages("roxygen2")
#install.packages("tidyverse")

library(devtools)
library(roxygen2)
library(tidyverse)

setwd("/cloud/project")
create("tidyfault")

# Click Definitely

##################################
# Installing
##################################

# Process Documentation
setwd("./tidyfault")
setwd(".")
getwd()
# Create all documentation
document()

# Reset
setwd("/cloud/project/")
# Get all files in the new project directory
# myfiles = dir("tidyfault", full.names = TRUE, recursive = TRUE, all.files = TRUE, include.dirs = TRUE)
# newfiles = myfiles %>% str_remove("tidyfault/")
# file.copy(from = myfiles, to = newfiles, recursive = TRUE, overwrite = TRUE)

# Remove tidyfault
unlink("tidyfault", recursive = TRUE)



# Formally install
setwd("..")
install("/cloud/project/")

# Unload
detach("package:tidyfault", unload = TRUE)
uninstall("tidyfault")
.rs.restartR()

