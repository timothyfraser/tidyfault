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
#library(QCA)
 
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
ggplot() +
  geom_line(data = gg$edges, mapping = aes(x,y, group = edge_id)) +
  geom_point(data = gg$nodes, mapping = aes(x,y,  shape = type, color =type), size = 8) +
  geom_text(data = gg$nodes, mapping = aes(x,y,label = event))
gg$nodes %>% head()

gg$edges %>% head()


# Extract minimum cutset from fault tree data
g = curate(
  nodes = fakenodes, 
  edges = fakeedges)

f = g %>% 
  equate() %>%
  formulate()

g %>% 
  concentrate() %>%
  tabulate(formula = f, method = "mocus")

  calculate() %>%
  concentrate() %>% 
  tabulate()





library(tidyverse)
library(tidyfault)
library(QCA)

rm(list = ls())

# Load example data into our environment
data("fakenodes")
data("fakeedges")



combos = s %>%
  map(~paste(., collapse = " * ") %>% paste("(", ., ")", sep = "")) %>%
  unlist() %>%
  paste(., collapse = " + ")

# Get the vector of events which will end up as prime implicants
# or parts of our minimum cutset
values = s %>% unlist() %>% unique() %>% sort() %>% paste(collapse = ", ")

combos = "(B * A * C) + (B * A * D) + (B * C) + (B * D * C)"

admisc::simplify(combos, snames = values)





q = curate(fakenodes, fakeedges) %>%
  equate() %>%
  formulate() %>% 
  calculate() %>% 
  concentrate() %>% 
  tabulate()

s = curate(fakenodes, fakeedges) %>% simplify()

eq = curate(fakenodes, fakeedges) %>% equate() %>% formulate()

# Make a data.frame
tab = s %>%
  set_names(1:length(.)) %>%
  map_dfr(~tibble(event = .), .id = "id") %>%
  mutate(present = 1) %>%
  pivot_wider(id_cols = c(id), 
              names_from = event, 
              values_from = present,
              values_fill = list(present = 0)) %>%
  mutate(outcome = 1) %>%
  select(-id) 


# Write a short algorithm


# Under what conditions can we consolidate a solution?

# Do several values show up elsewhere?

# For each item in s
for(i in 1:length(s)){
  i = 1
  
  combo = s[[i]]
  
  # For each value in s[[i]]
  for(j in 1:length(s[[i]])){
  j = 1
    # Find the values that are NOT that one
    notj = combo[-j]
  for( k in 1:length(notj)){
    k = 1
    
    pair = c(combo[j],  notj[k])
    
    # Do any OTHER items have BOTH j AND k?
      for(z in 1:length(s)){
      z = 1

      # Does it contain BOTH j and k?
      sum(s[[z]] %in% combo[j] & s[[z]] %in% notj[k])
      
      }
   }
    
  }
    
}

tab[, -5] %>% as.matrix() %>% QCA::findSubsets()


tab[, -5] %>% as.matrix() %>%
  QCA::findmin()

?findmin()

tab %>% as.matrix()
?QCA::removeRedundants()
QCA::removeRedundants()
QCA::find
tab

m = tab %>%
  as.matrix() %>%
  .[,-ncol(.)]

admisc::simplify("(URB + LIT)(~LIT + ~DEV)", snames = "DEV, URB, LIT")



posimp <- findSupersets(m+1, noflevels = rep(3, 4))
primeimp <- removeRedundants(posimp, noflevels = rep(3, 4))
primeimp
getRow(primeimp, noflevels = rep(3, 4))
?simplify()


m
findSupersets(HD[1:4, 1:4] + 1, noflevels = rep(3, 4))


findSupersets(HD[1:4, 1:4] + 1, noflevels = rep(3, 4))
admisc::simplify()


# can I....
# take this and...
# Generate some comparison set?

c = eq %>% calculate()


# Get each combination of these
# It's like ONLY these work.

# So, we should be able to say, every OTHER combination is zero

values = s %>% unlist() %>% unique()

# Go through the chart, find them all
expand_grid()


q = tab %>%
  as.matrix() %>%
  truthTable(outcome = "outcome") %>%
  minimize(method = "CCubes", all.sol = FALSE, neg.out = TRUE) 

# We know that these are vital...
f = g %>% equate() %>% formulate()

# So what if 




# How many times does B show up in this vector?


# Please classify, do you have 
m %>%
  map_dfr(~as_tibble(t(.) ))









