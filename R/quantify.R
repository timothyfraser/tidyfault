#' quantify() Function
#'
#' Evaluates whether the top event occurs (system fails) when given whether each
#' basic event occurs or not. Inputs are binary: each event is 0 (did not occur)
#' or 1 (occurred). No probabilities—deterministic evaluation only.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event. Used to identify event names and to evaluate the fault tree.
#' @param scenarios (Required) Either a tibble/data frame with one column per
#'   basic event (names from \code{formalArgs(f)}), or a single vector/list.
#'   A single scenario can be an unnamed vector in \code{formalArgs(f)} order
#'   (e.g. \code{c(T, T, T, F)} or \code{c(1, 1, 0, 1)}), or a named vector/list.
#'   Values are logical (TRUE/FALSE) or numeric (0/1).
#'
#' @return If \code{scenarios} is a data frame: a tibble with the same columns
#'   plus an \code{outcome} column (logical: TRUE = system failure, FALSE = no
#'   failure). If \code{scenarios} is a named vector or list: a single logical
#'   (TRUE/FALSE).
#'
#' @details No probabilities are used; the function evaluates the fault tree
#'   on the given event states. Outcome is TRUE when \code{f(...) >= 1} (system
#'   failure). Logical and 0/1 inputs are coerced to 0/1 internally to match
#'   \code{calculate()} behavior. When \code{scenarios} is a data frame,
#'   evaluation is vectorized: \code{f} is called once with vector columns
#'   (one element per row), so many scenarios are handled efficiently.
#'
#' @seealso \code{\link{formulate}} for creating the function, \code{\link{calculate}}
#'   for the full truth table, \code{\link{quantify_prob}} for top event failure
#'   probability given basic event probabilities.
#'
#' @keywords fault tree binary evaluation
#' @importFrom dplyr %>% mutate
#' @importFrom methods formalArgs
#' @importFrom tibble as_tibble
#' @export
#' @examples
#' library(tidyverse)
#' library(tidyfault)
#' library(QCA)
#' data("fakenodes")
#' data("fakeedges")
#'
#' # Pipe-friendly: single scenario in event order (e.g. A, B, C, D)
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'   equate() %>%
#'   formulate() %>%
#'   quantify(c(T, T, T, F))
#'
#' f <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'   equate() %>%
#'   formulate()
#'
#' # Single scenario: unnamed vector in event order
#' f %>% quantify(c(TRUE, FALSE, TRUE, FALSE))
#'
#' # Single scenario: named vector (logical or 0/1)
#' one_scenario <- setNames(c(TRUE, FALSE, TRUE, FALSE), formalArgs(f))
#' f %>% quantify(one_scenario)
#'
#' # Tibble of scenarios: add outcome column (vectorized, one call to f for all rows)
#' scenarios_tbl <- tibble(
#'   A = c(1L, 0L, 1L),
#'   B = c(0L, 1L, 1L),
#'   C = c(1L, 0L, 0L),
#'   D = c(0L, 1L, 1L)
#' )
#' f %>% quantify(scenarios_tbl)
quantify = function(f, scenarios) {

  fargs = formalArgs(f)

  if (is.data.frame(scenarios)) {
    # Data frame path: require columns for all basic events; vectorized (one call to f)
    missing_events = setdiff(fargs, colnames(scenarios))
    if (length(missing_events) > 0L)
      stop("scenarios must contain columns for all basic events. Missing: ",
           paste(missing_events, collapse = ", "))

    args = lapply(fargs, function(a) as.integer(as.logical(scenarios[[a]])))
    names(args) = fargs
    res = do.call(f, args)
    scenarios %>%
      tibble::as_tibble() %>%
      mutate(outcome = as.logical(res >= 1))
  } else {
    # Single scenario: vector or list (unnamed = positional, or named)
    nms = names(scenarios)
    if (is.null(nms) || all(nms == "", na.rm = TRUE) || !all(fargs %in% nms)) {
      scenarios = as.list(scenarios)
      if (length(scenarios) != length(fargs))
        stop("scenarios length must match number of basic events (", length(fargs), ").")
      names(scenarios) = fargs
    }
    missing_events = setdiff(fargs, names(scenarios))
    if (length(missing_events) > 0L)
      stop("scenarios must contain values for all basic events. Missing: ",
           paste(missing_events, collapse = ", "))

    args = lapply(scenarios[fargs], function(x) as.integer(as.logical(x)))
    as.logical(do.call(f, args) >= 1)
  }
}
