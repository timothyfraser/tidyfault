# tidyfault

<img src="tidyfault/man/figures/logo.png" align="right" height="140" />

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

4. `calculate()` the full truth table of all possible combinations of events and the `outcome` each leads to.

```r
mycombos = myfunction %>% calculate()
```

5. `concentrate()` our truth table into the minimum cutsets, the smallest sets of events necessary to cause system failure. This function uses boolean minimalization to find the minimum cutsets.

```r
mymin = mycombos %>% concentrate()
```

6. `tabulate()` the minimum cutsets and how much coverage they have over the total paths to failure found with `calculate()`. `tabulate()` needs both the minimum cutsets and the formula (function from step 3).

```r
mytable = tabulate(mymin, formula = myfunction)
```

### Workflow (All at Once!)

Or, we can do this all in one fell swoop!

Let's extract the minimum cutsets from our fault tree data!

```r
# Build the formula once (needed for tabulate)
myfunction = curate(nodes = fakenodes, edges = fakeedges) %>%
  equate() %>%
  formulate()

# Run the full pipeline; tabulate() needs the formula for coverage stats
mytable = curate(nodes = fakenodes, edges = fakeedges) %>%
  equate() %>%
  formulate() %>%
  calculate() %>%
  concentrate() %>%
  tabulate(formula = myfunction)
```


## Questions?

Contact: Timothy Fraser, PhD (timothy.fraser.1\@gmail.com)