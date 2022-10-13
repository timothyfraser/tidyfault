#' calculate() Function
#'
#' This function takes a supplied function `f` and computes the system failure outcomes (1 = failure vs. 0 = not) given every possible combination of input events failing (1) or not failing (0). Outputs a `data.frame`.
#' 
#' @param data (Required) function outputted by `equate()`, including arguments for all input events in the fault tree (excluing gates or top events) 
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
