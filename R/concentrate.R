#' concentrate() Function
#'
#' This function *concentrates* the boolean equation of a fault tree to find the minimum cutsets in the fault tree. It takes a data.frame outputted by the `curate()` function and applies one of the available MOCUS implementations to perform boolean minimization.
#' 
#' @param data (Required) data.frame containing output from `curate()`. Expects the gates data.frame with columns `gate`, `type`, `set`, and `items`.
#' @param method (Optional) Character string specifying the minimization algorithm. Default is `"mocus_rcpp"`. Supported values are `"mocus_rcpp"`, `"mocus_r"`, and `"mocus_original"`.
#' 
#' @return A character vector where each element is a minimum cutset represented as a boolean expression (e.g., `"A * B"` for events A AND B). Each cutset represents a minimal set of events whose simultaneous occurrence causes system failure.
#' 
#' @details This function performs boolean minimization to identify the minimum cutsets (minimal failure paths) in a fault tree using the MOCUS algorithm:
#'   \itemize{
#'     \item \strong{Rcpp MOCUS} (`method = "mocus_rcpp"`):
#'       \itemize{
#'         \item Uses the Rcpp-backed MOCUS implementation (`mocus_rcpp()`)
#'         \item Recommended default for speed on larger trees
#'       }
#'     \item \strong{Pure-R fast MOCUS} (`method = "mocus_r"`):
#'       \itemize{
#'         \item Uses the optimized pure-R implementation (`mocus_r()`)
#'         \item Useful when compiled code is unavailable
#'       }
#'     \item \strong{Original MOCUS} (`method = "mocus_original"`):
#'       \itemize{
#'         \item Uses the original MOCUS implementation (`mocus()`) to generate all cutsets
#'         \item Converts cutsets to a boolean equation format
#'         \item Applies boolean simplification using `admisc::simplify()` to find minimum cutsets
#'         \item Returns simplified cutsets as character strings
#'       }
#'   }
#'   Minimum cutsets represent the smallest combinations of basic events that can cause the top event (system failure) to occur.
#' 
#' @seealso \code{\link{curate}} for preparing gate data for MOCUS method, \code{\link{mocus_rcpp}}, \code{\link{mocus_r}}, and \code{\link{mocus}} for MOCUS implementations, \code{\link{tabulate}} for analyzing and summarizing minimum cutsets
#' 
#' @keywords minimization minimum cutset fault tree
#' @importFrom dplyr %>%
#' @importFrom purrr map
#' @importFrom stringr str_split str_trim
#' @importFrom admisc simplify
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
#' # Extract minimum cutset from fault tree data
#' formula <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'    equate() %>%
#'    formulate()
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'    concentrate(method = "mocus_rcpp") %>%
#'    tabulate(formula = formula, method = "mocus_rcpp")
concentrate = function(data, method = c("mocus_rcpp", "mocus_r", "mocus_original")){
  method = match.arg(method)

  output = switch(
    method,
    mocus_rcpp = data %>% mocus_rcpp(),
    mocus_r = data %>% mocus_r(),
    mocus_original = data %>% mocus()
  )

  combos = output %>%
    map(~paste(., collapse = " * ") %>% paste("(", ., ")", sep = "")) %>%
    unlist() %>%
    paste(., collapse = " + ")

  values = output %>% unlist() %>% unique() %>% sort() %>% paste(collapse = ", ")

  result = tryCatch(
    admisc::simplify(combos, snames = values),
    error = function(e) {
      msg = conditionMessage(e)
      if (grepl("object 'sols' not found", msg, fixed = TRUE)) {
        return(combos)
      } else {
        stop(e)
      }
    }
  ) %>%
    as.vector() %>%
    str_split(pattern = "[+]", simplify = FALSE) %>%
    unlist() %>%
    str_trim(side = "both")

  return(result)
}