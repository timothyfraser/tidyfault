#' tabulate() Function
#'
#' This function *tabulates* a `data.frame` of `N` minimum cutsets in your fault tree, describing each `mincut` set, a `query` used to filter a table of all sets, the number of `cutsets` that include that `mincut`, the total number of cutsets leading to `failure`, and the `coverage` (percentage of `cutsets` covered out of total failures) for that `mincut`.
#'
#' @param data (Required) Output from `concentrate()` function. For `method = "mocus"`, expects a character vector of minimum cutset expressions (e.g., `"A * B"`). For `method = "CCubes"`, expects a QCA solution object from `concentrate()` with `method = "CCubes"`.
#' @param formula (Required) Function output from `formulate()`. Used to generate the truth table for calculating coverage statistics when `method = "mocus"`. Not used when `method = "CCubes"`.
#' @param method (Optional) Character string specifying the method used. Default is `"mocus"`, which works with character vector output from `concentrate(method = "mocus")`. Alternatively, `"CCubes"` works with QCA solution objects from `concentrate(method = "CCubes")`.
#' 
#' @return A `data.frame` (tibble) with one row per minimum cutset, containing:
#'   \itemize{
#'     \item `mincut`: Character string representing the minimum cutset as a boolean expression (e.g., `"A * B"` for events A AND B)
#'     \item `query`: Character string containing a filter expression that can be used to identify truth table rows matching this cutset (e.g., `"filter(A == 1, B == 1, outcome == 1)"`)
#'     \item `cutsets`: Integer count of truth table rows (cutsets) that match this minimum cutset and result in system failure
#'     \item `failures`: Integer count of total truth table rows that result in system failure (same for all rows)
#'     \item `coverage`: Numeric value (0 to 1) representing the proportion of failure cases covered by this minimum cutset. Calculated as `cutsets / failures`. Higher coverage indicates a more critical failure path.
#'   }
#'   Rows are grouped by `mincut`, allowing easy identification of the most critical failure paths based on coverage.
#' 
#' @details This function analyzes minimum cutsets to quantify their importance in system failure:
#'   \itemize{
#'     \item \strong{Truth Table Generation}: For `method = "mocus"`, uses `formula` to generate a complete truth table via `calculate()`. For `method = "CCubes"`, extracts the truth table from the QCA solution object.
#'     \item \strong{Cutset Parsing}: Splits each minimum cutset expression into individual events and determines their required states (1 for occurrence, 0 for non-occurrence, indicated by tilde `~` in QCA format)
#'     \item \strong{Query Construction}: Creates filter expressions that identify truth table rows matching each cutset's event combination
#'     \item \strong{Coverage Calculation}: Counts how many failure cases (rows with `outcome == 1`) are covered by each minimum cutset, then calculates coverage as a proportion
#'   }
#'   Coverage represents the explanatory power of each minimum cutset: a cutset with coverage = 0.5 means it explains 50% of all system failure cases. This metric helps prioritize which failure paths are most critical for risk mitigation. The `query` column provides reusable filter expressions for further analysis.
#' 
#' @seealso \code{\link{concentrate}} for generating minimum cutsets, \code{\link{formulate}} for creating the function used in truth table generation, \code{\link{calculate}} for generating truth tables
#' 
#' @keywords minimum cutset
#' @importFrom dplyr %>% select filter group_by summarize mutate ungroup if_else
#' @importFrom tibble tibble
#' @importFrom stringr str_split str_detect str_remove
#' @export
#' @examples 
#' 
#' # Load dependencies
#' library(tidyverse)
#' library(tidyfault)
#' library(QCA)
#' 
#' # Load example data into our environment
#' data("fakenodes")
#' data("fakeedges")
#' 
#' # Extract minimum cutset from fault tree data
#' formula <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate()
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate() %>%
#'    calculate() %>%
#'    concentrate() %>% 
#'    tabulate(formula = formula)

tabulate = function(data, formula, method = "mocus"){
  
  require(dplyr)
  require(tibble)
  require(stringr)
  
  if(method == "mocus"){
    # Extract the truth table from our formula
    tab = formula %>%
      calculate() %>%
      select(1:outcome)
    
  }else if(method == "CCubes"){
    require(QCA)
    
    # Extract the truth table from the boolean minimalization solution object
    tab = data$tt$tt %>% select(1:OUT) %>% rename(outcome = OUT)
    
    # Convert from QCA format
    data = data %>%
      with(essential)
  }
  
  # Extract the solution set as a tibble(),
  # where each column shows one solution, 
  # including however many minimum cutsets there are
  # in that vector named for the solution 
  # (eg. solution M1 gets its own column)
  data %>%
    tibble(mincut = .) %>%
    # For each minimum cutset,
    group_by(mincut) %>%
    summarize(
      # please extract each of the values in that cutset, one per row
      event = mincut %>% str_split(pattern = "[*]", simplify = TRUE) %>% as.vector(),
      # then classify cutset values as positive (no tilde = 1) or negative (tilde = 0)
      value = if_else(str_detect(event, "[~]"), 0, 1),
      # then construct a label
      label = paste(event, "==", value)) %>%
    # For each cutset
    group_by(mincut) %>%
    # Consolidate labels into 1 query per minimal cutset
    # asking whether you saw these cutset values AND the outcome == 1
    summarize(query = c(label, "outcome == 1") %>%
                # Collapse them into one line, with commas between them
                paste(collapse = ", ") %>%
                # and append a filter function and the name of the data to be filtered,
                paste( deparse(quote(tab)), " %>% ", "filter", "(", ., ")", sep = "")) %>%
    # Finally, for each minimal cutset,
    group_by(mincut) %>%
    # Please claculate...
    mutate(
      # number of cutsets that include these prime implicants
      cutsets = query %>% parse(text = .) %>% eval() %>% nrow(),
      # total cutsets that ever see failure
      failures = tab %>% filter(outcome == 1) %>% nrow(),
      # percentage of cutsets covering prime implicants, out of total cutsets that fail
      # In other words, the explanatory power of our cutsets for system failure
      coverage = cutsets / failures,
      query = query %>% str_remove(pattern = paste( deparse(quote(tab)), " %>% ", sep = "") )) %>%
    ungroup() %>%
    return()
}
