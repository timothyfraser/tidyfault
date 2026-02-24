#' concentrate() Function
#'
#' This function *concentrates* the boolean equation of a fault tree to find the minimum cutsets in the fault tree. Takes a data.frame outputted by the `curate()` function and applies the `mocus()` algorithm, or takes a data.frame outputted by the `calculate()` function and applies the QCA package's `"CCubes"` algorithm to perform boolean minimization.
#' 
#' @param data (Required) data.frame containing output from `curate()` function for the `"mocus"` algorithm, or output from `calculate()` for the `"CCubes"` algorithm. For `method = "mocus"`, expects the gates data.frame with columns `gate`, `type`, `set`, and `items`. For `method = "CCubes"`, expects a truth table data.frame with event columns and an `outcome` column.
#' @param method (Optional) Character string specifying the minimization algorithm. Default is `"mocus"`, which runs the MOCUS algorithm on output from `curate()` and simplifies to minimum cutsets using boolean algebra. Alternatively, `"CCubes"` runs the QCA package's CCubes algorithm on output from `calculate()` (recommended for smaller datasets due to computational complexity).
#' 
#' @return The return type depends on the `method`:
#'   \itemize{
#'     \item For `method = "mocus"`: A character vector where each element is a minimum cutset represented as a boolean expression (e.g., `"A * B"` for events A AND B). Each cutset represents a minimal set of events whose simultaneous occurrence causes system failure.
#'     \item For `method = "CCubes"`: A QCA solution object (list) containing the boolean minimization results, including prime implicants and solution details. This object can be used with QCA package functions or passed to `tabulate()` for further analysis.
#'   }
#' 
#' @details This function performs boolean minimization to identify the minimum cutsets (minimal failure paths) in a fault tree. Two algorithms are available:
#'   \itemize{
#'     \item \strong{MOCUS method} (`method = "mocus"`): 
#'       \itemize{
#'         \item Uses the MOCUS (Method of Obtaining Cutsets) algorithm implemented in `mocus()` to generate all cutsets
#'         \item Converts cutsets to a boolean equation format
#'         \item Applies boolean simplification using `admisc::simplify()` to find minimum cutsets
#'         \item Returns simplified cutsets as character strings
#'         \item Recommended for most use cases, especially larger fault trees
#'       }
#'     \item \strong{CCubes method} (`method = "CCubes"`):
#'       \itemize{
#'         \item Uses the QCA (Qualitative Comparative Analysis) package's truth table and minimization functions
#'         \item Converts the truth table to QCA format
#'         \item Applies the CCubes algorithm for boolean minimization
#'         \item Returns a QCA solution object with detailed minimization results
#'         \item Best for smaller datasets due to exponential complexity of truth tables (2^n rows)
#'       }
#'   }
#'   Minimum cutsets represent the smallest combinations of basic events that can cause the top event (system failure) to occur. These are critical for understanding system vulnerabilities and prioritizing risk mitigation efforts.
#' 
#' @seealso \code{\link{curate}} for preparing gate data for MOCUS method, \code{\link{calculate}} for generating truth tables for CCubes method, \code{\link{mocus}} for the MOCUS algorithm implementation, \code{\link{tabulate}} for analyzing and summarizing minimum cutsets
#' 
#' @keywords minimalization qca minimum cutset fault tree
#' @importFrom dplyr %>%
#' @importFrom purrr map
#' @importFrom stringr str_split str_trim
#' @importFrom admisc simplify
#' @importFrom QCA truthTable minimize
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
#'    concentrate(method = "mocus") %>% 
#'    tabulate(formula = formula, method = "mocus")

concentrate = function(data, method = "mocus"){

  # Let's write a function to simplify a boolean expression
  
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
      # Occasionally admisc::simplify() throws an internal
      # "object 'sols' not found" error when there are no
      # valid solutions to simplify; in that case we treat this as
      # "cannot be simplified further" and fall back to the original
      # (unsimplified) boolean expression.
      result = tryCatch(
        admisc::simplify(combos, snames = values),
        error = function(e) {
          msg = conditionMessage(e)
          if (grepl("object 'sols' not found", msg, fixed = TRUE)) {
            # Fall back to the original combined expression; this will
            # later be split back into individual cutsets.
            return(combos)
          } else {
            stop(e)
          }
        }
      ) %>%
        as.vector() %>%
        # split into separate strings any time we see a '+'
        str_split(pattern = "[+]", simplify = FALSE) %>%
        # and convert back to vector
        unlist() %>%
        # trim white space
        str_trim(side = "both")
      
      return(result)
      
  }else if(method == "CCubes"){
    
    # Taking an output from calculate()
    result = data %>%
      # Convert to matrix
      as.matrix() %>%
      # Convert to truth table
      QCA::truthTable(outcome = "outcome") %>%
      # Use boolean minimalization,
      # with the CCubes algorithm, to get the prime implicants!!!
      QCA::minimize("outcome", use.tilde = FALSE, method = "CCubes")
    
    return(result)
  }else{
    stop("Invalid method. Must be 'mocus' or 'CCubes' (case-sensitive).")
  }
}