#' quantify_prob() Function
#'
#' Computes the top event failure probability from a fault tree when given
#' basic event failure probabilities. Assumes independent basic events; uses
#' the full truth table to sum probabilities over all failure combinations.
#'
#' @param f (Required) Function outputted by \code{formulate()}, with one argument per
#'   basic event. Used to identify event names and, if \code{truth_table} is not
#'   supplied, to generate the truth table via \code{calculate(f)}.
#' @param newdata (Required) Failure probabilities (0 to 1) for each basic event.
#'   Can be a single vector or list (one scenario), or a data frame or matrix with
#'   one row per scenario and columns for each basic event (names must match
#'   \code{formalArgs(f)}). Unnamed vectors are interpreted in \code{formalArgs(f)}
#'   order. Values should be in \code{[0, 1]}, where each value represents the
#'   probability that the corresponding basic event occurs.
#' @param truth_table (Optional) Data frame with one column per basic event (0/1)
#'   and an \code{outcome} column (1 = system failure, 0 = no failure). If
#'   provided, the truth table is not recomputed (useful when \code{calculate()}
#'   was already run).
#'
#' @return A numeric vector of top-event failure probabilities. If \code{newdata} is
#'   a single scenario (vector/list or single-row data frame), returns a single
#'   numeric value. If \code{newdata} has multiple rows (one per scenario), returns
#'   a numeric vector with one probability per scenario (same order as rows of
#'   \code{newdata}). Similar to R's \code{predict()} function style.
#'
#' @details The top event probability is computed exactly via the complete truth
#'   table: for each of the 2^n combinations of basic event states, the
#'   probability of that combination is the product of \code{newdata[e]} for events
#'   that occur (1) and \code{1 - newdata[e]} for events that do not (0). The
#'   function sums these probabilities over all combinations where
#'   \code{outcome == 1}. This is exact for independent basic events but has
#'   complexity O(2^n); for trees with many basic events, consider using minimal
#'   cut set approximations elsewhere. When \code{newdata} has multiple rows, the
#'   truth table is computed once and all scenarios are evaluated in one pass.
#'
#' @seealso \code{\link{formulate}} for creating the function from a boolean
#'   equation, \code{\link{calculate}} for generating the truth table,
#'   \code{\link{quantify}} for evaluating whether the top event occurs given
#'   binary (0/1) basic event states. The result matches the FaultTree package when
#'   the same tree is built and \code{ftree.calc(DF, use.bdd = TRUE)} is used
#'   (BDD accounts for repeated basic events; gate-by-gate with \code{use.bdd = FALSE}
#'   does not).
#'
#' @keywords fault tree probability quantification
#' @importFrom dplyr %>%
#' @importFrom methods formalArgs
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
#' # Pipe-friendly: probability vector in event order (e.g. A, B, C, D)
#' curate(nodes = fakenodes, edges = fakeedges) %>%
#'   equate() %>%
#'   formulate() %>%
#'   quantify_prob(c(0.1, 0.2, 0.05, 0.15))
#'
#' # Named probs (names must match event names in the tree)
#' probs <- setNames(c(0.1, 0.2, 0.05, 0.15), formalArgs(f))
#' f %>% quantify_prob(probs)
#'
#' # Reuse an existing truth table to avoid recomputing
#' tt <- calculate(f)
#' f %>% quantify_prob(probs, truth_table = tt)
#'
#' # Many scenarios at once (vectorized): pass a data frame, one row per scenario
#' probs_df <- as.data.frame(replicate(4, runif(1000), simplify = FALSE))
#' names(probs_df) <- formalArgs(f)
#' f %>% quantify_prob(probs_df, truth_table = tt)  # length-1000 vector
quantify_prob = function(f, newdata, truth_table = NULL) {

  fargs = formalArgs(f)

  # Detect multi-scenario: data frame or matrix with more than one row
  multi = (is.matrix(newdata) || is.data.frame(newdata)) && nrow(newdata) > 1L

  if (!multi) {
    # Single scenario: vector or list, or single-row df/matrix
    if (is.list(newdata) && !is.data.frame(newdata))
      newdata = unlist(newdata)
    if (is.matrix(newdata) || is.data.frame(newdata)) {
      nms = colnames(newdata)
      if (!is.null(nms) && all(fargs %in% nms))
        newdata = setNames(as.numeric(newdata[1L, fargs, drop = FALSE]), fargs)
      else
        newdata = setNames(as.numeric(newdata[1L, ]), fargs)
    }
    nms = names(newdata)
    if (is.null(nms) || all(nms == "", na.rm = TRUE)) {
      newdata = as.numeric(newdata)
      if (length(newdata) != length(fargs))
        stop("newdata length must match number of basic events (", length(fargs), ").")
      names(newdata) = fargs
    } else {
      newdata = setNames(as.numeric(newdata), nms)
      missing_events = setdiff(fargs, names(newdata))
      if (length(missing_events) > 0L)
        stop("newdata must contain values for all basic events. Missing: ",
             paste(missing_events, collapse = ", "))
    }
    if (any(newdata < 0 | newdata > 1, na.rm = TRUE))
      warning("Some newdata values are outside [0, 1]; result may not be a valid probability.")

    if (is.null(truth_table))
      truth_table = calculate(f)

    event_cols_tt = setdiff(colnames(truth_table), "outcome")
    if (!all(fargs %in% event_cols_tt))
      stop("truth_table must contain columns for each basic event and 'outcome'.")

    probs_vec = newdata[event_cols_tt]
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

  # Multi-scenario path: newdata is matrix or data frame, one row per scenario
  if (is.data.frame(newdata)) {
    missing_events = setdiff(fargs, colnames(newdata))
    if (length(missing_events) > 0L)
      stop("newdata must contain columns for all basic events. Missing: ",
           paste(missing_events, collapse = ", "))
    P = as.matrix(newdata[, fargs, drop = FALSE])
  } else {
    if (is.null(colnames(newdata)) || !all(fargs %in% colnames(newdata)))
      stop("newdata matrix must have column names matching basic events: ",
           paste(fargs, collapse = ", "))
    P = newdata[, fargs, drop = FALSE]
  }
  P = matrix(as.numeric(P), nrow = nrow(P), ncol = ncol(P))
  if (any(P < 0 | P > 1, na.rm = TRUE))
    warning("Some newdata values are outside [0, 1]; results may not be valid probabilities.")

  n_scenarios = nrow(P)
  if (is.null(truth_table))
    truth_table = calculate(f)

  event_cols_tt = setdiff(colnames(truth_table), "outcome")
  if (!all(fargs %in% event_cols_tt))
    stop("truth_table must contain columns for each basic event and 'outcome'.")

  tt_mat = as.matrix(truth_table[, event_cols_tt, drop = FALSE])
  n_truth = nrow(tt_mat)
  failure_rows = truth_table$outcome >= 1L

  # M[r, s] = probability of truth row r under scenario s
  M = matrix(NA_real_, nrow = n_truth, ncol = n_scenarios)
  for (r in seq_len(n_truth)) {
    row_r = tt_mat[r, ]
    # term[s, i] = P[s,i] if row_r[i]==1 else 1-P[s,i]
    term = matrix(NA_real_, nrow = n_scenarios, ncol = length(fargs))
    for (i in seq_along(fargs)) {
      term[, i] = if (row_r[i] == 1L) P[, i] else (1 - P[, i])
    }
    M[r, ] = apply(term, 1L, prod)
  }

  colSums(M[failure_rows, , drop = FALSE])
}