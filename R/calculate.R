#' calculate() Function
#'
#' This function takes a supplied function `f` and computes the system failure outcomes (1 = failure vs. 0 = not) given every possible combination of input events failing (1) or not failing (0). Outputs a `data.frame`.
#' 
#' @param f (Required) Function outputted by `formulate()`, including arguments for all input events in the fault tree (excluding gates or top events). The function should accept binary (0/1) arguments for each basic event and return a numeric value.
#' 
#' @return A `data.frame` containing a truth table with:
#'   \itemize{
#'     \item One column for each input event (named according to the function's formal arguments)
#'     \item An `outcome` column indicating system failure (1) or no failure (0)
#'   }
#'   Rows are arranged in descending order by `outcome`, with failure cases listed first. The truth table contains 2^n rows where n is the number of input events, representing all possible combinations of event states.
#' 
#' @details This function generates a complete truth table by:
#'   \itemize{
#'     \item Extracting the formal arguments from the supplied function to identify all input events
#'     \item Creating a grid of all possible binary combinations (0/1) for each event using `tidyr::expand_grid()`
#'     \item Evaluating the function for each combination to determine system failure
#'     \item Converting outcomes to binary: any value >= 1 indicates failure (1), otherwise no failure (0)
#'   }
#'   The function is designed to work with boolean functions created by `formulate()` that represent fault tree logic. The outcome threshold (>= 1) allows for functions that may return counts or probabilities rather than strict boolean values.
#' 
#' @seealso \code{\link{formulate}} for creating the function from a boolean equation, \code{\link{concentrate}} for finding minimum cutsets from the truth table
#' 
#' @keywords boolean logic fault tree equation
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


calculate = function(f){

  # Let's write a function to extract the truth table
  
  require(dplyr)
  require(tidyr)
  
  # Extract name of function object as text
  fname = deparse(quote(f))
  
  
  # Extract the names of our formal arguments from the function.
  fargs = f %>% formalArgs() 
  
  # get basic usage of function with all its arguments
  fusage = fargs %>% paste(., collapse = ", ") %>% 
    paste(fname, "(", ., ")", sep = "")
  
  # Generate a grid of all possible binary inputs to the arguments
  # eg. A = 1, B = 0, C = 1, etc.
  fgrid = fargs %>%
    # Paste them into one string, saying Argument1 = c(0,1), Argument2 = .... etc.
    paste(., "= c(0, 1)", collapse = ", ") %>%
    # Put this inside expand_grid()
    paste("expand_grid(", ., ")", sep = "") %>%
    # parse it into an expression
    parse(text = .) %>%
    # And evaluate the expression
    eval()
  
  # Let's generate the truth table!
  ftab = fgrid %>%
    # Now calculate the outcome,
    # having it run our function f using 
    mutate(outcome = fusage %>% parse(text = .) %>% eval()) %>%
    # Simplify the 'outcome' field into a binary,
    # where if 1 means outcome >= 1 while 0 means any 0
    mutate(outcome = as.numeric(outcome >= 1)) %>%
    # Arrange from top to bottom
    arrange(desc(outcome))
  
  return(ftab)
}
