#' quantify_prob_fast() Function
#'
#' Computes top-event failure probability using the same exact truth-table
#' approach as \code{quantify_prob()}, but with a compiled inner loop for faster
#' evaluation across many scenarios.
#'
#' @param f (Required) Function outputted by \code{formulate()}, with one argument
#'   per basic event.
#' @param newdata (Required) Failure probabilities in \code{[0, 1]}. Can be a
#'   single vector/list, or a data frame/matrix with one row per scenario.
#' @param truth_table (Optional) Data frame with one column per basic event and
#'   an \code{outcome} column. If \code{NULL}, computed via \code{calculate(f)}.
#'
#' @return Numeric vector of top-event failure probabilities (length 1 for a
#'   single scenario).
#'
#' @keywords fault tree probability quantification
#' @importFrom methods formalArgs
#' @export
quantify_prob_fast = function(f, newdata, truth_table = NULL) {

  if (!exists("quantify_prob_cpp_impl", mode = "function")) {
    stop(
      "quantify_prob_cpp_impl() is not available. ",
      "Reinstall tidyfault so compiled Rcpp routines are registered."
    )
  }

  fargs = formalArgs(f)
  multi = (is.matrix(newdata) || is.data.frame(newdata)) && nrow(newdata) > 1L

  if (!multi) {
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

    P = matrix(as.numeric(newdata[fargs]), nrow = 1L, ncol = length(fargs))
  } else {
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
  }

  if (is.null(truth_table))
    truth_table = calculate(f)

  event_cols_tt = setdiff(colnames(truth_table), "outcome")
  if (!all(fargs %in% event_cols_tt))
    stop("truth_table must contain columns for each basic event and 'outcome'.")

  TT = truth_table[, fargs, drop = FALSE]
  TT = matrix(as.integer(as.matrix(TT)), nrow = nrow(TT), ncol = ncol(TT))
  failure_rows = truth_table$outcome >= 1L

  probs = quantify_prob_cpp_impl(
    probs = P,
    truth_events = TT,
    failure_rows = failure_rows
  )

  if (multi) probs else as.numeric(probs[[1L]])
}
