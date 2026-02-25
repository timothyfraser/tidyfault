#' quantify() Function
#'
#' Unified quantification: when \code{prob = FALSE}, evaluates whether the top
#' event occurs given binary (0/1) basic event states; when \code{prob = TRUE},
#' computes the top event failure probability given basic event failure
#' probabilities.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event. Used to identify event names and to evaluate the fault tree
#'   (and, when \code{prob = TRUE}, to build the truth table via \code{calculate(f)}
#'   if \code{truth_table} is not supplied).
#' @param scenarios (Required) When \code{prob = FALSE}: binary 0/1 or logical—
#'   either a tibble/data frame with one column per basic event, or a single
#'   vector/list. When \code{prob = TRUE}: failure probabilities in \code{[0, 1]}
#'   for each basic event—same shapes (vector/list or data frame with one row per
#'   scenario).
#' @param prob (Optional) If \code{FALSE} (default), binary evaluation is
#'   performed. If \code{TRUE}, \code{scenarios} is interpreted as basic-event
#'   failure probabilities and the top-event failure probability is returned.
#' @param truth_table (Optional) Used only when \code{prob = TRUE}. Data frame
#'   with one column per basic event (0/1) and an \code{outcome} column. If
#'   provided, the truth table is not recomputed.
#'
#' @return When \code{prob = FALSE}: if \code{scenarios} is a data frame, a
#'   tibble with the same columns plus \code{outcome} (logical); otherwise a
#'   single logical. When \code{prob = TRUE}: a single numeric or a numeric
#'   vector (one per scenario row if \code{scenarios} is a multi-row data frame
#'   or matrix).
#'
#' @seealso \code{\link{formulate}} for creating the fault tree function,
#'   \code{\link{calculate}} for the full truth table.
#'
#' @keywords fault tree quantification binary probability
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
#' f <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'   equate() %>%
#'   formulate()
#'
#' # Binary (prob = FALSE): single scenario
#' f %>% quantify(c(TRUE, FALSE, TRUE, FALSE))
#'
#' # Binary: tibble of scenarios
#' scenarios_tbl <- tibble(
#'   A = c(1L, 0L, 1L),
#'   B = c(0L, 1L, 1L),
#'   C = c(1L, 0L, 0L),
#'   D = c(0L, 1L, 1L)
#' )
#' f %>% quantify(scenarios_tbl)
#'
#' # Probability (prob = TRUE): single scenario
#' f %>% quantify(c(0.1, 0.2, 0.05, 0.15), prob = TRUE)
#'
#' # Probability: reuse truth table
#' tt <- calculate(f)
#' probs <- setNames(c(0.1, 0.2, 0.05, 0.15), formalArgs(f))
#' f %>% quantify(probs, prob = TRUE, truth_table = tt)
quantify = function(f, scenarios, prob = FALSE, truth_table = NULL) {

  fargs = formalArgs(f)

  if (!prob) {
    # Binary path (same as quantify)
    if (is.data.frame(scenarios)) {
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
  } else {
    # Probability path (same as quantify_prob, with scenarios as probs)
    probs = scenarios
    multi = (is.matrix(probs) || is.data.frame(probs)) && nrow(probs) > 1L

    if (!multi) {
      if (is.list(probs) && !is.data.frame(probs))
        probs = unlist(probs)
      if (is.matrix(probs) || is.data.frame(probs)) {
        nms = colnames(probs)
        if (!is.null(nms) && all(fargs %in% nms))
          probs = setNames(as.numeric(probs[1L, fargs, drop = FALSE]), fargs)
        else
          probs = setNames(as.numeric(probs[1L, ]), fargs)
      }
      nms = names(probs)
      if (is.null(nms) || all(nms == "", na.rm = TRUE)) {
        probs = as.numeric(probs)
        if (length(probs) != length(fargs))
          stop("scenarios length must match number of basic events (", length(fargs), ").")
        names(probs) = fargs
      } else {
        probs = setNames(as.numeric(probs), nms)
        missing_events = setdiff(fargs, names(probs))
        if (length(missing_events) > 0L)
          stop("scenarios must contain values for all basic events. Missing: ",
               paste(missing_events, collapse = ", "))
      }
      if (any(probs < 0 | probs > 1, na.rm = TRUE))
        warning("Some values are outside [0, 1]; result may not be a valid probability.")

      if (is.null(truth_table))
        truth_table = calculate(f)

      event_cols_tt = setdiff(colnames(truth_table), "outcome")
      if (!all(fargs %in% event_cols_tt))
        stop("truth_table must contain columns for each basic event and 'outcome'.")

      probs_vec = probs[event_cols_tt]
      one_minus = 1 - probs_vec

      row_probs = apply(
        truth_table[, event_cols_tt, drop = FALSE],
        1L,
        function(row) {
          prod(ifelse(row == 1L, probs_vec, one_minus))
        }
      )

      return(sum(row_probs[truth_table$outcome >= 1L]))
    }

    # Multi-scenario probability path
    if (is.data.frame(probs)) {
      missing_events = setdiff(fargs, colnames(probs))
      if (length(missing_events) > 0L)
        stop("scenarios must contain columns for all basic events. Missing: ",
             paste(missing_events, collapse = ", "))
      P = as.matrix(probs[, fargs, drop = FALSE])
    } else {
      if (is.null(colnames(probs)) || !all(fargs %in% colnames(probs)))
        stop("scenarios matrix must have column names matching basic events: ",
             paste(fargs, collapse = ", "))
      P = probs[, fargs, drop = FALSE]
    }
    P = matrix(as.numeric(P), nrow = nrow(P), ncol = ncol(P))
    if (any(P < 0 | P > 1, na.rm = TRUE))
      warning("Some values are outside [0, 1]; results may not be valid probabilities.")

    if (is.null(truth_table))
      truth_table = calculate(f)

    event_cols_tt = setdiff(colnames(truth_table), "outcome")
    if (!all(fargs %in% event_cols_tt))
      stop("truth_table must contain columns for each basic event and 'outcome'.")

    tt_mat = as.matrix(truth_table[, event_cols_tt, drop = FALSE])
    n_truth = nrow(tt_mat)
    n_scenarios = nrow(P)
    failure_rows = truth_table$outcome >= 1L

    M = matrix(NA_real_, nrow = n_truth, ncol = n_scenarios)
    for (r in seq_len(n_truth)) {
      row_r = tt_mat[r, ]
      term = matrix(NA_real_, nrow = n_scenarios, ncol = length(fargs))
      for (i in seq_along(fargs)) {
        term[, i] = if (row_r[i] == 1L) P[, i] else (1 - P[, i])
      }
      M[r, ] = apply(term, 1L, prod)
    }

    colSums(M[failure_rows, , drop = FALSE])
  }
}
