#' tabulate() Function
#'
#' This function *tabulates* a `data.frame` of `N` minimum cutsets in your fault tree, describing each `mincut` set, a `query` used to filter a table of all sets, the number of `cutsets` that include that `mincut`, the total number of cutsets leading to `failure`, and the `coverage` (percentage of `cutsets` covered out of total failures) for that `mincut`.
#'
#' @param data (Required) Output from `concentrate()` function. Expects a character vector of minimum cutset expressions (e.g., `"A * B"`).
#' @param formula (Required) Function output from `formulate()`. Used to generate the truth table for calculating coverage statistics.
#' @param method (Optional) Character string specifying the method used in `concentrate()`. Default is `"mocus_rcpp"`. Supported values are `"mocus_rcpp"`, `"mocus_r"`, and `"mocus_original"`.
#' @param query (Optional) Logical - Whether to include the query column in the output. Default is `FALSE`.
#' 
#' @return A `data.frame` (tibble) with one row per minimum cutset, containing:
#'   \itemize{
#'     \item `mincut`: Character string representing the minimum cutset as a boolean expression (e.g., `"A * B"` for events A AND B)
#'     \item `query`: Character string containing a filter expression that can be used to identify truth table rows matching this cutset (e.g., `"filter(A == 1, B == 1, outcome == 1)"`) (only included if `query = TRUE`)
#'     \item `cutsets`: Integer count of truth table rows (cutsets) that match this minimum cutset and result in system failure
#'     \item `failures`: Integer count of total truth table rows that result in system failure (same for all rows)
#'     \item `coverage`: Numeric value (0 to 1) representing the proportion of failure cases covered by this minimum cutset. Calculated as `cutsets / failures`.
#'   }
#' 
#' @details This function analyzes minimum cutsets to quantify their importance in system failure:
#'   \itemize{
#'     \item \strong{Truth Table Generation}: Uses `formula` to generate a complete truth table via `calculate()`.
#'     \item \strong{Cutset Parsing}: Splits each minimum cutset expression into individual events and determines their required states (1 for occurrence, 0 for non-occurrence)
#'     \item \strong{Query Construction}: Creates filter expressions that identify truth table rows matching each cutset's event combination
#'     \item \strong{Coverage Calculation}: Counts how many failure cases (rows with `outcome == 1`) are covered by each minimum cutset, then calculates coverage as a proportion
#'   }
#' 
#' @seealso \code{\link{concentrate}} for generating minimum cutsets, \code{\link{formulate}} for creating the function used in truth table generation, \code{\link{calculate}} for generating truth tables
#' 
#' @keywords minimum cutset
#' @importFrom dplyr %>% select filter group_by summarize mutate ungroup if_else
#' @importFrom tibble tibble
#' @importFrom stringr str_split str_detect str_remove
#' @export
#' @examples
#' # Load dependencies
#' library(tidyverse)
#' library(tidyfault)
#' 
#' # Load example data into our environment
#' data("fakenodes")
#' data("fakeedges")
#' 
#' formula <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate()
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'    concentrate(method = "mocus_rcpp") %>%
#'    tabulate(formula = formula, method = "mocus_rcpp")
tabulate = function(
  data,
  formula,
  method = c("mocus_rcpp", "mocus_r", "mocus_original"),
  query = FALSE
){
  method = match.arg(method)
  # Testing values
  # formula = myfunction
  # data = mymin
  # method = "mocus_rcpp"
  # query = FALSE

  # MOCUS / equate strings often wrap cutsets in parentheses, e.g. "(A * B)".
  # Splitting on * would otherwise yield "(A" as the first token and break filter()/parse().
  strip_outer_parens <- function(s) {
    s <- trimws(s)
    while (nzchar(s) && substr(s, 1L, 1L) == "(" && substr(s, nchar(s), nchar(s)) == ")") {
      s <- trimws(substr(s, 2L, nchar(s) - 1L))
    }
    s
  }

  tab = formula %>%
    calculate() %>%
    select(1:outcome)
  

  # Extract the solution set as a tibble(),
  # where each column shows one solution, 
  # including however many minimum cutsets there are
  # in that vector named for the solution 
  # (eg. solution M1 gets its own column)
  output = data %>%
    tibble(mincut = .) %>%
    # For each minimum cutset,
    group_by(mincut) %>%
    reframe(
      # please extract each of the values in that cutset, one per row
      event = strip_outer_parens(unique(mincut)[[1L]]) %>%
        str_split(pattern = "\\s*\\*\\s*", simplify = TRUE) %>%
        as.vector() %>%
        trimws(),
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
    ungroup()

  # Technically 
  # For each minimal cutset, please count up the number of rows in the truth table that match the cutset.
  # data %>% 
  #    stringr::str_split(pattern = "[*]", simplify = FALSE) %>%
  #    purrr::map_dfr(
  #     .f = ~tab %>% select(all_of(.x)) %>% filter_all(all_vars(. == 1)) %>% nrow() %>% as_tibble(),
  #     .id = "cutset"
  #    )
    if(query == FALSE){
      output = output %>% select(-query)
    }

    return(output)

    
}
