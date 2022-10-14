#' concentrate() Function
#'
#' This function *concentrates* the boolean equation of a fault tree to find the minimum cutsets in the fault tree. Takes a data.frame outputted by the `curate()` function and applies the `mocus()` algorithm, or takes a data.frame outputted by the `calculate()` function and applies the QCA package's `"CCubes"` algorithm to perform boolean minimization.
#' 
#' @param data (Required) data.frame containing output from `curate()` function for the `"mocus"` algorithm. (Or output from `calculate()` for the `'CCubes' algorithm`.
#' @param method (Optional) By default, runs `"mocus"` algorithm on output from `curate()` and simplifies to minimum cutsets. Alternatively, can run `"CCubes"` algorithm on the output from `calculate()` (but best on smaller datasets).
#' @keywords minimalization qca minimum cutset fault tree
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
#'    concentrate() %>% 
#'    tabulate()

concentrate = function(data, method = "mocus"){

  # Let's write a function to simplify a boolean expression
  
  require(dplyr)
  require(admisc)
  
  if(method == "mocus"){
    # Taking an output from curate()
    output = data %>%
      # Run MOCUS algorithm
      mocus()
      
      # Get list of outputted cutsets, formatted as boolean equation 
      combos = output %>%
        map(~paste(., collapse = " * ") %>% paste("(", ., ")", sep = "")) %>%
        unlist() %>%
        paste(., collapse = " + ")
      
      # Get the vector of events which will end up as prime implicants
      # or parts of our minimum cutset
      values = output %>% unlist() %>% unique() %>% sort() %>% paste(collapse = ", ")
      
      # Simplify the expression!
      result = admisc::simplify(combos, snames = values) %>% as.vector() %>%
        # split into separate strings any time we see a '+'
        str_split(pattern = "[+]", simplify = FALSE) %>%
        # trim white space
        str_trim(side = "both") %>%
        # and convert back to vector
        unlist() %>%
        return()
      
  }else if(method == "CCubes"){
    
    require(QCA)
    
    # Taking an output from calculate()
  data %>%
    # Convert to matrix
    as.matrix() %>%
    # Convert to truth table
    QCA::truthTable(outcome = "outcome") %>%
    # Use boolean minimalization,
    # with the CCubes algorithm, to get the prime implicants!!!
    QCA::minimize("outcome", use.tilde = FALSE, method = "CCubes") %>%
    return()
  }
}