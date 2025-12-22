# tidyfault

## R Package for tidy *Fault Tree Analysis* (FTA)! 

Uses `tidyverse`, `tidygraph`, and `QCA` packages, among others, to visualize fault trees, identify minimal cutsets, and other quantities of interest. 

## Basic Usage

How do we use `tidyfault` to analyze fault trees? 

### Load Packages and Data

Let's start by loading our dependencies!

```r
# Load dependencies
library(tidyfault)
library(tidyverse)
library(QCA)
```

Next, let's get some fake data to work with, including **nodes** and **edges** in our fault tree.

```r
#Load example data into our environment
data("fakenodes")
data("fakeedges")
```

### Workflow (Step-by-Step)

Finally, let's demonstrate the basic workflow for `tidyfault`!

First, we...

1. `curate()` a list of **gates** in the fault tree;

```r
mygates = curate(nodes = fakenodes, edges = fakeedges)
```

2. use `equate()` to find the boolean equation for the fault tree;

```r
myequation = mygates %>% equate()
```

3. `formulate()` that equation into an `R` function we can use;

```r
myfunction = myequation %>% formulate()
```

4. `calculate()` all the truth table of all possible combinations of events and the `outcome` each leads to.

```r
mycombos = myfunction %>% calculate()
```

5. `concentrate()` our truth table into the minimum cutsets, the smallest sets of events necessary to cause system failure. This function uses boolean minimalization to find the minimum cutsets.

```r
mymin = mycombos %>% concentrate()
```

6. `tabulate()` up our minimum cutsets and how coverage they have over the total paths to failure found with `calculate()`.

```r
mytable = mymin %>% tabulate()
```

### Workflow (All at Once!)

Or, we can do this all in one fell swoop!

Let's extract the minimum cutsets from our fault tree data!

```r
# Start by curating the gates...
mytable = curate(
  nodes = fakenodes, 
  edges = fakeedges) %>%
  # Now apply our next functions
  equate() %>%
  formulate() %>%
  calculate() %>%
  concentrate() %>% 
  tabulate()
```


## Questions?

Contact: Timothy Fraser, PhD (timothy.fraser.1\@gmail.com)