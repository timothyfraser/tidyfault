# example.R

# This script shows examples of how to use the tidyfault package.
setwd("C:/Users/tmf77/tidyfault_paper/tidyfault")
remove.packages("tidyfault")
unloadNamespace("tidyfault")
devtools::document()
# unloadNamespace("tidyfault")
# devtools::build(vignettes = TRUE, manual = TRUE)
# unlink("tidyfault_0.0.0.9.tar.gz")
#install.packages("tidyfault_0.0.0.9.tar.gz", type = "source")

library(tidyfault)

data("db_nodes")
data("db_edges")
data("db_probs")
data("db_outcomes_binary")


# Use probabilities in analysis
mygates = curate(nodes = db_nodes, edges = db_edges)

# Extract the boolean equation
myequation = mygates |> equate()

# Formulate boolean equation as a function
myfunction = myequation |> formulate()

# Get the minimal cutset
mymin = mygates |> concentrate(method = "mocus")

# Tabulate coverage of minimal cutsets
mymin |> tabulate(formula = myfunction, method = "mocus")

# Calculate the truth table
mycombos = myfunction |> calculate()

# Populate the binary outcomes table with probabilities
myprobs = populate(binary_outcomes = db_outcomes_binary, event_probs = db_probs)

# Quantify the outcomes given these scenarios
# As binary values
myprobs |> mutate(outcome = quantify(f = myfunction, newdata = ., prob = FALSE))

# As probabilities
myprobs |> mutate(outcome = quantify(f = myfunction, newdata = ., prob = TRUE))


# Get visualization data frames
gg = illustrate(nodes = db_nodes, edges = db_edges, type = "all")

# Get plot
ggplot() +
  geom_line(data = gg$edges, mapping = aes(x = x, y = y, group = edge_id)) +
  geom_point(data = gg$nodes, mapping = aes(x = x, y = y, fill = type), shape = 21, size = 8) +
  geom_text(data = gg$nodes, mapping = aes(x = x, y = y, label = event), color = "white") +
  coord_fixed(ratio = 1)



