#' tabulate() Function
#'
#' This function *tabulates* a `data.frame` of `N` minimum cutsets in your fault tree, describing each `mincut` set, a `query` used to filter a table of all sets, the number of `cutsets` that include that `mincut`, the total number of cutsets leading to `failure`, and the `coverage` (percentage of `cutsets` covered out of total failures) for that `mincut`.
#'
#' @param data (Required) output from `concentrate()` function; a `QCA` object representing the boolean minimalization of the truth table of all possible sets. Used to find the `mincut` sets.
#' @param formula (Required) output from `formulate()` function.
#' @keywords minimum cutset
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
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate() %>%
#'    calculate() %>%
#'    concentrate() %>% 
#'    tabulate()

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
