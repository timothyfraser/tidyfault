#' formulate() Function
#'
#' This function *formulates* a `function` that can compute probabilities of system failure. To do so, it converts a character string describing the boolean equation of a fault tree into a `function` that can compute probabilities of system failure into that function. Handles AND and OR operations.
#' 
#' @param formula (Required) A character string containing the boolean logic equation of a fault tree. Should use `*` for AND operations, `+` for OR operations, and parentheses for grouping. The equation should contain only basic event names (no gate references). Typically output from `equate()`.
#' 
#' @return A function object that:
#'   \itemize{
#'     \item Accepts named arguments for each basic event in the formula
#'     \item Each argument accepts numeric values (typically 0 or 1 for binary events)
#'     \item Returns a numeric value representing the system state (typically 0 for no failure, >= 1 for failure)
#'     \item Evaluates the boolean equation using R's arithmetic operators (`*` for AND, `+` for OR)
#'   }
#'   The function can be called directly with event values or passed to `calculate()` to generate a complete truth table.
#' 
#' @details This function converts a boolean equation string into an executable R function through the following process:
#'   \itemize{
#'     \item Extracts all unique event names from the formula by splitting on operators (`+`, `*`, `(`, `)`)
#'     \item Creates formal arguments for the function, one for each unique event name
#'     \item Sets the function body to parse and evaluate the formula string
#'     \item Returns a function that can be called with named arguments for each event
#'   }
#'   The function uses R's arithmetic operators where multiplication (`*`) represents AND logic and addition (`+`) represents OR logic. When called with binary inputs (0/1), the function returns 0 for no failure and a positive value for failure. The function preserves the order of operations through parentheses in the original formula.
#' 
#' @seealso \code{\link{equate}} for generating the boolean equation string, \code{\link{calculate}} for generating truth tables from the function
#' 
#' @keywords fault tree formula boolean equation
#' @importFrom dplyr %>%
#' @importFrom stringr str_split str_trim
#' @importFrom dplyr na_if
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

formulate = function(formula){
  # As our next step we need to format that equation
  # transforming it from a character string
  # into a function we can compute!
  
  require(dplyr)
  require(stringr)
  
  # Can I now remove ANYTHING that is not a (, ), +, or *?
  values = formula %>% 
    # Split into separate values anytime you see an operator
    str_split(pattern = "[(]|[)]|[+]|[*]", simplify = TRUE) %>% 
    # Convert matrix to vector
    as.vector() %>%
    # Trim any spaces
    str_trim(side = "both") %>%
    # If any values are now empty, eg. "", set to NA
    na_if(y = "") %>%
    # Drop NAs
    .[!is.na(.)] %>%
    # Return just the unique list of inputs
    unique() %>%
    # Sort the unique inputs
    sort()
  
  # Get whatever values go into that formula, 
  # and format them as a special list of arguments
  args = values %>%
    paste(., " = ") %>%
    paste(collapse = ", ")  %>%
    paste("alist(", ., ")", sep = "") %>%
    # Parse the phrase
    parse(text = .) %>%
    # And evaluate it, so that formals(functionname) can use it
    eval()
  
  # We need to make an empty function, called 'f()'
  f = function(){ }
  
  # Then parse and assign the text 'equation' to the body of this function
  body(f) <- parse(text = formula)
  
  # Assign our collection to be the formal arguments for this function
  formals(f) <- args
  
  # And return our function!
  return(f)
}
