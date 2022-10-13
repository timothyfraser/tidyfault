#' formulate() Function
#'
#' This function *formulates* a `function` that can compute probabilities of system failure. To do so, it converts a character string describing the boolean equation of a fault tree into a `function` that can compute probabilities of system failure into that function. Handles AND and OR operations.
#' 
#' @param formula (Required) a character string listing the boolean logic equation of a fault tree.
#' @keywords fault tree formula boolean equation
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
