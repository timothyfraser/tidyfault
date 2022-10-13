#' concentrate() Function
#'
#' This function *concentrates* a `data.frame` of N possible combinations of input events in the graph (not counting gates or top events), by applying boolean minimalization to find the minimum cutsets in the fault tree. Uses the `QCA` package and the `"CCubes"` algorithm to perform boolean minimization.
#' 
#' @param data (Required) data.frame containing truth table of N possible combinations of input events (eg. `A`, `B`, `C`) as either failing (1) or not failing (0), and the corresponding `outcome` measured by `calculate()` showing overall system failure (1) or not (0). `outcome` must be the last column.
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
#'    equate() %>%
#'    formulate() %>%
#'    calculate() %>%
#'    concentrate() %>% 
#'    tabulate()

concentrate = function(data){

  # Let's write a function to perfor boolean minimalization
  
  require(dplyr)
  require(QCA)
  
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