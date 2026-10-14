#' Evaluate binary scenarios in one vectorized pass
#'
#' Evaluates top-event outcomes for binary scenarios using the same semantics as
#' \code{quantify_binary()}, with streamlined coercion for larger batches.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event.
#' @param newdata (Required) Binary event states (0/1 or TRUE/FALSE) for each
#'   basic event. Accepts either a data frame/matrix of scenarios or a single
#'   vector/list.
#'
#' @return Logical vector of outcomes (TRUE = system failure, FALSE = no failure).
#'
#' @examples
#' data(db_nodes, db_edges, db_outcomes_binary, package = "tidyfault")
#' f <- formulate(equate(curate(db_nodes, db_edges)))
#'
#' # One logical value per scenario: TRUE means the top event occurs
#' quantify_binary_fast(f, db_outcomes_binary)
#'
#' @keywords fault tree binary evaluation internal
#' @importFrom methods formalArgs
#' @export
quantify_binary_fast = function(f, newdata) {

  fargs = formalArgs(f)

  if (is.data.frame(newdata) || is.matrix(newdata)) {
    if (is.null(colnames(newdata)))
      stop("newdata must contain columns for all basic events: ",
           paste(fargs, collapse = ", "))

    missing_events = setdiff(fargs, colnames(newdata))
    if (length(missing_events) > 0L)
      stop("newdata must contain columns for all basic events. Missing: ",
           paste(missing_events, collapse = ", "))

    X = as.matrix(newdata[, fargs, drop = FALSE])
    X = matrix(as.integer(as.logical(X)), nrow = nrow(X), ncol = ncol(X))
    args = as.list(as.data.frame(X, stringsAsFactors = FALSE))
    names(args) = fargs
    as.logical(do.call(f, args) >= 1)
  } else {
    nms = names(newdata)
    if (is.null(nms) || all(nms == "", na.rm = TRUE) || !all(fargs %in% nms)) {
      newdata = as.list(newdata)
      if (length(newdata) != length(fargs))
        stop("newdata length must match number of basic events (", length(fargs), ").")
      names(newdata) = fargs
    }
    missing_events = setdiff(fargs, names(newdata))
    if (length(missing_events) > 0L)
      stop("newdata must contain values for all basic events. Missing: ",
           paste(missing_events, collapse = ", "))

    args = lapply(newdata[fargs], function(x) as.integer(as.logical(x)))
    as.logical(do.call(f, args) >= 1)
  }
}
