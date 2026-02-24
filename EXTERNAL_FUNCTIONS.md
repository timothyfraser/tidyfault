# External Functions Used in tidyfault Package

This document lists all functions from external packages used in the tidyfault package, organized by package.

## dplyr Functions

- `%>%` (pipe operator) - Used in: calculate, concentrate, curate, equate, formulate, gate, gate_and, gate_or, gate_top, illustrate, mocus, tabulate
- `arrange` - Used in: calculate, curate
- `bind_rows` - Used in: gate_and, gate_or
- `case_when` - Used in: curate, gate_and, gate_or
- `filter` - Used in: curate, equate, gate, illustrate, mocus, tabulate
- `group_by` - Used in: curate, gate, illustrate, tabulate
- `if_else` - Used in: tabulate
- `left_join` - Used in: curate, illustrate
- `mutate` - Used in: calculate, curate, gate_and, gate_or, gate_top, illustrate, tabulate
- `n` - Used in: illustrate
- `nrow` - Used in: tabulate
- `reframe` - Used in: illustrate
- `rename` - Used in: gate, tabulate
- `select` - Used in: curate, gate_top, illustrate, tabulate
- `summarize` - Used in: curate, gate, tabulate
- `ungroup` - Used in: curate, tabulate
- `with` - Used in: mocus, tabulate

## stringr Functions

- `str_detect` - Used in: equate, tabulate
- `str_remove` - Used in: tabulate
- `str_replace` - Used in: equate
- `str_replace_all` - Used in: curate
- `str_split` - Used in: concentrate, formulate, tabulate
- `str_trim` - Used in: concentrate, formulate

## tibble Functions

- `tibble` - Used in: curate, gate_and, gate_or, gate_top, get_gate, tabulate
- `tribble` - Used in: gate_top

## tidyr Functions

- `expand_grid` - Used in: calculate

## purrr Functions

- `map` - Used in: concentrate, mocus
- `set_names` - Used in: illustrate

## rlang Functions

- `sym` - Used in: gate, illustrate

## scales Functions

- `rescale` - Used in: get_gate

## tidygraph Functions

- `tbl_graph` - Used in: illustrate

## ggraph Functions

- `create_layout` - Used in: illustrate

## admisc Functions

- `simplify` - Used in: concentrate

## QCA Functions

- `minimize` - Used in: concentrate
- `truthTable` - Used in: concentrate

## Base R Functions (for reference)

These are standard R functions that don't require external packages:
- `as.matrix`, `as.numeric`, `as.vector`
- `c`, `cbind`
- `deparse`, `eval`
- `factor`
- `length`, `list`
- `matrix`, `max`, `mapply`
- `na.rm` (parameter)
- `nrow`
- `parse`, `paste`
- `quote`
- `rep`
- `seq`, `seq_len`, `sort`, `split`, `sqrt`, `sum`
- `system.time`
- `unique`, `unlist`, `unname`
- `with`

## Summary by Package

1. **dplyr**: 18 functions (most heavily used)
2. **stringr**: 6 functions
3. **tibble**: 2 functions
4. **tidyr**: 1 function
5. **purrr**: 2 functions
6. **rlang**: 1 function
7. **scales**: 1 function
8. **tidygraph**: 1 function
9. **ggraph**: 1 function
10. **admisc**: 1 function
11. **QCA**: 2 functions

## Potential Reduction Opportunities

1. **dplyr functions** - Many could potentially be replaced with base R equivalents:
   - `mutate` → direct assignment
   - `filter` → base R subsetting
   - `select` → base R column selection
   - `arrange` → `order()`
   - `group_by`/`summarize` → `aggregate()` or `by()`
   - `left_join` → `merge()`

2. **stringr functions** - Could be replaced with base R:
   - `str_split` → `strsplit()`
   - `str_replace`/`str_replace_all` → `gsub()`/`sub()`
   - `str_detect` → `grepl()`
   - `str_trim` → `trimws()`
   - `str_remove` → `gsub()` with empty replacement

3. **tibble functions** - Could use base R `data.frame()`:
   - `tibble` → `data.frame()`
   - `tribble` → `data.frame()` with manual construction

4. **tidyr functions** - Could use base R:
   - `expand_grid` → `expand.grid()`

5. **purrr functions** - Could use base R:
   - `map` → `lapply()`
   - `set_names` → `names()<-`

6. **rlang functions** - Could use base R:
   - `sym` → `as.symbol()` or `as.name()`

7. **scales functions** - Could implement manually:
   - `rescale` → simple linear transformation

8. **Visualization packages** (tidygraph, ggraph) - Only used in `illustrate()`:
   - Could make visualization optional or move to a separate package
   - `tbl_graph` → could use `igraph` directly
   - `create_layout` → could use `igraph` layout functions

9. **admisc** - Only used for `simplify()` in `concentrate()`:
   - Could implement boolean simplification manually or use alternative

10. **QCA** - Only used in `concentrate()` with `method = "CCubes"`:
    - Could make this method optional or remove if not critical
