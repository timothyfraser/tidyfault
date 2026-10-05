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
#'         \item Uses the original MOCUS implementation (`mocus()` with `method = "mocus_original"`) to generate all cutsets
#'         \item Returns the cutsets as character strings
#'       }
#'   }
#'   Every method then minimises the MOCUS products by absorption: duplicate cutsets and any cutset containing another cutset are dropped. Cutsets are ordered fewest events first, then by the sorted position of their events.
#'   Minimum cutsets represent the smallest combinations of basic events that can cause the top event (system failure) to occur.
#' 
#' @seealso \code{\link{curate}} for preparing gate data for MOCUS method, \code{\link{mocus_rcpp}}, \code{\link{mocus_r}}, and \code{\link{mocus}} for MOCUS implementations, \code{\link{tabulate}} for analyzing and summarizing minimum cutsets
#' 
#' @keywords minimization minimum cutset fault tree
#' @importFrom dplyr %>%
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
    mocus_original = mocus(data, method = "mocus_original")
  )

  absorb_cutsets(output)
}

# Minimal cut sets by absorption. MOCUS products contain only plain basic
# events, so dropping duplicates and supersets gives the minimal sum of
# products. Order: fewest events first, then by sorted event position.
absorb_cutsets = function(products) {
  events = sort(unique(unlist(products)))
  idx = lapply(products, function(p) sort(unique(match(p, events))))
  idx = idx[!duplicated(vapply(idx, paste, character(1), collapse = ","))]
  if (length(idx) == 0L) {
    return(character(0))
  }
  keep = vapply(
    seq_along(idx),
    function(i) !any(vapply(idx[-i], function(o) all(o %in% idx[[i]]), logical(1))),
    logical(1)
  )
  idx = idx[keep]
  n = lengths(idx)
  cols = lapply(seq_len(max(n)), function(k) vapply(idx, function(x) x[k], numeric(1)))
  idx = idx[do.call(order, c(list(n), cols))]
  vapply(idx, function(x) paste(events[x], collapse = "*"), character(1))
}
