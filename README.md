
<!-- README.md is generated from README.Rmd. Please edit README.Rmd. -->

# tidyfault

<img src="man/figures/logo.png" align="right" width="120" style="float: right; margin-left: 1rem;" alt="tidyfault logo" />

## R Package for tidy *Fault Tree Analysis* (FTA)!

**`tidyfault`** uses `tidyverse`, `tidygraph`, and related tools to
visualize fault trees, identify minimal cutsets, and evaluate failure
outcomes.

Fault tree methods are used in aerospace, energy, safety, and security
contexts. The package keeps trees in rectangular **nodes** and **edges**
tables so you can combine FTA with familiar data manipulation and
plotting tools in R.

------------------------------------------------------------------------

## Applications

<div class="tf-mood-grid">

<img src="https://images.unsplash.com/photo-1517976487492-5750f3195933?ixlib=rb-4.0.3&amp;auto=format&amp;fit=crop&amp;w=520&amp;q=70" width="48%" alt="View from an aircraft window over clouds"/>

<img src="https://images.unsplash.com/photo-1451187580459-43490279c0fa?ixlib=rb-4.0.3&amp;auto=format&amp;fit=crop&amp;w=520&amp;q=70" width="48%" alt="Satellite view of night lights on Earth"/>

<img src="https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?ixlib=rb-4.0.3&amp;auto=format&amp;fit=crop&amp;w=520&amp;q=70" width="48%" alt="Wind turbines in a rural landscape"/>

<img src="https://images.unsplash.com/photo-1550751827-4bd374c3f58b?ixlib=rb-4.0.3&amp;auto=format&amp;fit=crop&amp;w=520&amp;q=70" width="48%" alt="Close-up of a printed circuit board"/>

<details>

<summary>

Image Sources
</summary>

All photographs are served from the [Unsplash](https://unsplash.com/)
CDN and are subject to the [Unsplash
License](https://unsplash.com/license).
</details>

</div>

------------------------------------------------------------------------

## Key capabilities

| Capability | What tidyfault provides |
|----|----|
| Tidy inputs | Fault trees as [`nodes` / `edges`](https://tidyfault.netlify.app/reference/curate.html) tables (one row per gate or basic event, one row per directed link). |
| Core pipeline | [`curate()`](https://tidyfault.netlify.app/reference/curate.html) → [`equate()`](https://tidyfault.netlify.app/reference/equate.html) → [`formulate()`](https://tidyfault.netlify.app/reference/formulate.html) → [`calculate()`](https://tidyfault.netlify.app/reference/calculate.html) → [`concentrate()`](https://tidyfault.netlify.app/reference/concentrate.html) → [`tabulate()`](https://tidyfault.netlify.app/reference/tabulate.html). |
| Minimal cutsets | MOCUS-style expansion ([`mocus()`](https://tidyfault.netlify.app/reference/mocus.html), Rcpp-backed by default) plus boolean reduction in [`concentrate()`](https://tidyfault.netlify.app/reference/concentrate.html). |
| Visualization | [`illustrate()`](https://tidyfault.netlify.app/reference/illustrate.html) and [`plot()`](https://tidyfault.netlify.app/reference/plot.html) for **ggplot2** / **ggraph** fault tree layouts. |
| Quantification | [`quantify()`](https://tidyfault.netlify.app/reference/quantify.html) for binary scenarios or top-event probabilities over many rows at once. |
| Documentation | [Articles](https://tidyfault.netlify.app/articles/index.html) on workflows, plotting, `quantify()`, and simulation. |

------------------------------------------------------------------------

## Basic Usage

How do we use `tidyfault` to analyze fault trees?

### Load Packages and Data

Let’s start by loading our dependencies!

``` r
# Load dependencies
library(tidyfault)
library(tidyverse)
```

Next, let’s get some fake data to work with, including **nodes** and
**edges** in our fault tree.

``` r
#Load example data into our environment
data("fakenodes")
data("fakeedges")
```

### Workflow (Step-by-Step)

Finally, let’s demonstrate the basic workflow for `tidyfault`!

First, we…

1.  `curate()` a list of **gates** in the fault tree;

``` r
mygates = curate(nodes = fakenodes, edges = fakeedges)
mygates
#> # A tibble: 6 × 6
#>   gate  type  class     n set           items    
#>   <chr> <fct> <fct> <int> <chr>         <list>   
#> 1 T     top   top       1 " (G1) "      <chr [1]>
#> 2 G1    and   gate      2 " (G2 * G3) " <chr [2]>
#> 3 G2    and   gate      2 " (B * G5) "  <chr [2]>
#> 4 G3    or    gate      2 " (A + G4) "  <chr [2]>
#> 5 G4    and   gate      2 " (B * C) "   <chr [2]>
#> 6 G5    or    gate      2 " (C + D) "   <chr [2]>
```

2.  use `equate()` to find the boolean equation for the fault tree;

``` r
myequation = mygates %>% equate()
myequation
#> [1] " ( ( (B *  (C + D) )  *  (A +  (B * C) ) ) ) "
```

3.  `formulate()` that equation into an `R` function we can use;

``` r
myfunction = myequation %>% formulate()
myfunction
#> function (A, B, C, D) 
#> (((B * (C + D)) * (A + (B * C))))
#> <environment: 0x000002d1cfb479a8>
```

4.  `calculate()` the full truth table of all possible combinations of
    events and the `outcome` each leads to.

``` r
mycombos = myfunction %>% calculate()
head(mycombos)
#> # A tibble: 6 × 5
#>       A     B     C     D outcome
#>   <dbl> <dbl> <dbl> <dbl>   <dbl>
#> 1     0     1     1     0       1
#> 2     0     1     1     1       1
#> 3     1     1     0     1       1
#> 4     1     1     1     0       1
#> 5     1     1     1     1       1
#> 6     0     0     0     0       0
```

5.  `concentrate()` our gate structure into the minimum cutsets, the
    smallest sets of events necessary to cause system failure. This
    function uses boolean minimalization to find the minimum cutsets.

``` r
mymin = mygates %>% concentrate()
mymin
#> [1] "B*C"   "A*B*D"
```

6.  `tabulate()` the minimum cutsets and how much coverage they have
    over the total paths to failure found with `calculate()`.
    `tabulate()` needs both the minimum cutsets and the formula
    (function from step 3).

``` r
mytable = tabulate(mymin, formula = myfunction)
mytable
#> # A tibble: 2 × 4
#>   mincut cutsets failures coverage
#>   <chr>    <int>    <int>    <dbl>
#> 1 A*B*D        2        5      0.4
#> 2 B*C          4        5      0.8
```

7.  `illustrate()` + `plot()` to visualize the fault tree structure.

``` r
myviz <- illustrate(nodes = fakenodes, edges = fakeedges, type = "both")
myplot <- plot(myviz)
myplot
```

<img src="man/figures/README-visualize-1.png" alt="Fault tree diagram for the fakenodes and fakeedges example: gates and basic events laid out as a directed graph." width="100%" />

8.  `quantify()` to evaluate specific scenarios (binary) or top-event
    probabilities.

``` r
# Binary scenario evaluation
quantify(myfunction, c(TRUE, FALSE, TRUE, FALSE))
#> [1] FALSE

# Probabilistic evaluation
quantify(myfunction, c(0.10, 0.20, 0.05, 0.15), prob = TRUE)
#> [1] 0.01285
```

### Workflow (All at Once!)

Or, we can do this all in one fell swoop!

Let’s extract the minimum cutsets from our fault tree data!

``` r
# Build gates and formula once (needed for tabulate)
mygates = curate(nodes = fakenodes, edges = fakeedges)
myfunction = mygates %>%
  equate() %>%
  formulate()

# Run the full pipeline; tabulate() needs the formula for coverage stats
mytable = mygates %>%
  concentrate() %>%
  tabulate(formula = myfunction)
```

------------------------------------------------------------------------

## Credits and license

- **Software:** [GPL-3](https://www.gnu.org/licenses/gpl-3.0.html) (see
  the `LICENSE` file in the repository). The documentation site is built
  with [pkgdown](https://pkgdown.r-lib.org/).
- **Images above:** Unsplash-hosted stock photos; see the [Unsplash
  License](https://unsplash.com/license). When redistributing or
  cropping, follow Unsplash attribution guidance.
- **Favicons:** Generated with
  [RealFaviconGenerator](https://realfavicongenerator.net/) from the
  package logo.

------------------------------------------------------------------------

## Questions?

Contact: Timothy Fraser, PhD (<timothy.fraser.1@gmail.com>)
