#' quantify_if() Function
#'
#' Asks "which fix buys the most?". Cuts the failure rate (or probability) of
#' each basic event in turn by the same share, keeps every other event as it
#' is, and measures how much the probability of the top event drops. It is a
#' one-at-a-time sensitivity analysis of the top event.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event.
#' @param data (Required) One row of values, one column per basic event of
#'   \code{f} (extra columns are ignored): a one-row data frame or tibble, or a
#'   named numeric vector. With \code{time}, the values are failure rates
#'   (events per hour, by default); without it, they are failure
#'   probabilities.
#' @param cut (Optional) The share to cut each value by, in \code{(0, 1]}: each
#'   event's value is multiplied by \code{1 - cut}. Default \code{0.05} (a 5\%
#'   cut). \code{cut = 1} removes the event entirely.
#' @param time (Optional) A single positive number, in the same unit as the
#'   rates (hours, the reliability-engineering convention; 8,760 hours is one
#'   year). If given, \code{data} holds failure rates, and each (cut) rate
#'   becomes the probability of failing by \code{time}, \code{pexp(time, rate)}. If \code{NULL} (default),
#'   \code{data} holds probabilities and is used as is.
#' @param events (Optional) Character vector naming the basic events to cut.
#'   Default \code{NULL} cuts every basic event of \code{f}, in
#'   \code{formalArgs(f)} order.
#' @param ci (Optional) \code{FALSE} (default) returns the exact values only.
#'   \code{TRUE} adds an uncertainty interval per row from
#'   \code{\link{quantify_ci}}.
#' @param n,cv,level,seed (Optional) Passed to \code{\link{quantify_ci}} when
#'   \code{ci = TRUE}: the number of draws (default \code{1000}), the
#'   coefficient of variation of each value (default \code{0.2}), the
#'   coverage of the interval (default \code{0.90}) and a seed for
#'   \code{set.seed()} (default \code{NULL}, the current random stream).
#'   Ignored when \code{ci = FALSE}.
#'
#' @return A tibble with one row per cut event, sorted by \code{pct_change}
#'   from the biggest drop to the smallest (ties keep the order of
#'   \code{events}), with columns:
#'   \itemize{
#'     \item \code{event}: the basic event that was cut.
#'     \item \code{p_top}: the probability of the top event after the cut.
#'     \item \code{baseline}: the probability of the top event with no cut
#'       (the same in every row).
#'     \item \code{change}: \code{p_top - baseline}.
#'     \item \code{pct_change}: the percent change from the baseline,
#'       \code{100 * (p_top / baseline - 1)}.
#'     \item \code{lower}, \code{upper}: only with \code{ci = TRUE}, the
#'       central \code{level} interval of the top event's probability after
#'       the cut, from \code{\link{quantify_ci}}. \code{p_top} stays the exact
#'       value.
#'   }
#'
#' @details The baseline and every what-if go through \code{quantify(f, prob =
#'   TRUE)} in one call, so the exact (truth-table) top event probability is
#'   used throughout. The cut is applied to the value in \code{data} before any
#'   conversion: with \code{time}, the rate is cut and then turned into a
#'   probability, which is what a fix to a component does.
#'
#'   With \code{ci = TRUE}, the baseline and every what-if share the same
#'   random draws (common random numbers), so the intervals can be compared
#'   row to row.
#'
#' @seealso \code{\link{quantify}} for the top event probability,
#'   \code{\link{quantify_when}} for scenarios over time,
#'   \code{\link{quantify_ci}} for uncertainty intervals.
#'
#' @keywords fault tree sensitivity
#' @importFrom methods formalArgs
#' @importFrom stats pexp
#' @importFrom tibble tibble
#' @export
#' @examples
#' library(dplyr)
#' library(tidyr)
#' library(tidyfault)
#'
#' f <- curate(nodes = it_security_nodes, edges = it_security_edges) %>%
#'   equate() %>%
#'   formulate()
#'
#' # One row of failure rates (events per hour), one column per basic event
#' rates <- it_security_outcomes_rates %>%
#'   select(event, lambda) %>%
#'   pivot_wider(names_from = event, values_from = lambda)
#'
#' # Cut each failure rate by 5%, one at a time: which fix lowers the chance
#' # that data leaks within one year (8,760 hours) the most?
#' quantify_if(f, rates, cut = 0.05, time = 8760)
#'
#' # Only two candidate fixes, each removing 90% of the failures, with 90%
#' # uncertainty intervals (each rate +/- 20%)
#' quantify_if(f, rates, cut = 0.9, time = 8760, events = c("MN", "PO"),
#'             ci = TRUE, n = 200, seed = 1)
#'
#' # With probabilities instead of rates, leave out `time`
#' quantify_if(f, it_security_probs)
quantify_if = function(f, data, cut = 0.05, time = NULL, events = NULL, ci = FALSE,
                       n = 1000, cv = 0.2, level = 0.90, seed = NULL) {
  if (!is.function(f))
    stop("`f` must be a function from formulate().", call. = FALSE)
  fargs = methods::formalArgs(f)
  if (!is.data.frame(data) && !(is.numeric(data) && !is.null(names(data))))
    stop("`data` must be a one-row data frame or a named numeric vector, ",
         "one value per basic event.", call. = FALSE)

  missing = setdiff(fargs, names(data))
  if (length(missing) > 0)
    stop("`data` must have a column for every basic event of `f`. Missing: ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  # Extra columns (an id, a label) are ignored. Keep data's column order: it
  # fixes the order of the random draws when ci = TRUE.
  values = one_row_values(data[names(data)[names(data) %in% fargs]],
                          arg = "data", fun = "quantify_if")

  if (is.null(events)) {
    events = fargs
  } else {
    if (!is.character(events) || length(events) == 0 || anyNA(events))
      stop("`events` must be a character vector of basic event names, or NULL for all of them.",
           call. = FALSE)
    unknown = setdiff(events, fargs)
    if (length(unknown) > 0)
      stop("`events` names events that are not basic events of `f`: ",
           paste(unknown, collapse = ", "), ". Choose from: ",
           paste(fargs, collapse = ", "), ".", call. = FALSE)
    if (anyDuplicated(events))
      stop("`events` must not repeat an event: ",
           paste(unique(events[duplicated(events)]), collapse = ", "), ".", call. = FALSE)
  }

  if (!is.numeric(cut) || length(cut) != 1 || !is.finite(cut) || cut <= 0 || cut > 1)
    stop("`cut` must be a single number in (0, 1], the share to cut each value by ",
         "(0.05 cuts it by 5%).", call. = FALSE)

  if (!is.null(time) &&
      (!is.numeric(time) || length(time) != 1 || !is.finite(time) || time <= 0))
    stop("`time` must be a single positive number, or NULL when `data` holds probabilities.",
         call. = FALSE)

  if (any(values < 0))
    stop("`data` values must be non-negative. Negative: ",
         paste(names(values)[values < 0], collapse = ", "), ".", call. = FALSE)
  if (is.null(time) && any(values > 1))
    stop("Without `time`, `data` must hold probabilities in [0, 1]. Above 1: ",
         paste(names(values)[values > 1], collapse = ", "),
         ". If these are failure rates, pass `time`.", call. = FALSE)

  if (!is.logical(ci) || length(ci) != 1 || is.na(ci))
    stop("`ci` must be TRUE or FALSE.", call. = FALSE)

  # Row 1 is the baseline; row i + 1 cuts events[i] alone.
  m = matrix(values, nrow = length(events) + 1, ncol = length(values), byrow = TRUE,
             dimnames = list(NULL, names(values)))
  for (i in seq_along(events)) m[i + 1, events[i]] = m[i + 1, events[i]] * (1 - cut)
  # The interval is drawn on the values before any conversion, as the cut is.
  if (ci)
    interval = quantify_ci(f = f, data = as.data.frame(m), n = n, cv = cv, time = time,
                           level = level, seed = seed)
  if (!is.null(time)) m[] = stats::pexp(q = time, rate = m)

  p = quantify(f = f, newdata = as.data.frame(m), prob = TRUE)
  baseline = p[1]

  out = tibble::tibble(
    event = events,
    p_top = p[-1],
    baseline = baseline,
    change = p[-1] - baseline,
    pct_change = 100 * (p[-1] / baseline - 1)
  )
  if (ci) {
    out$lower = interval$lower[-1]
    out$upper = interval$upper[-1]
  }
  out[order(out$pct_change, method = "radix"), , drop = FALSE]
}

# One row of named, finite numbers from a one-row data frame or a named numeric
# vector. Shared by quantify_if() and quantify_when().
one_row_values = function(data, arg, fun) {
  if (is.data.frame(data)) {
    if (nrow(data) != 1)
      stop("`", arg, "` must have exactly one row; it has ", nrow(data), ". ",
           "Give ", fun, "() one row of values, one column per basic event.",
           call. = FALSE)
    is_num = vapply(data, is.numeric, logical(1))
    if (!all(is_num))
      stop("`", arg, "` columns must be numeric. Not numeric: ",
           paste(names(data)[!is_num], collapse = ", "), ".", call. = FALSE)
    values = vapply(data, function(col) as.numeric(col[[1]]), numeric(1))
  } else if (is.numeric(data) && !is.null(names(data))) {
    values = stats::setNames(as.numeric(data), names(data))
  } else {
    stop("`", arg, "` must be a one-row data frame or a named numeric vector, ",
         "one value per basic event.", call. = FALSE)
  }
  if (any(names(values) == "") || anyDuplicated(names(values)))
    stop("`", arg, "` must name every value once.", call. = FALSE)
  if (any(!is.finite(values)))
    stop("`", arg, "` values must be finite. Not finite: ",
         paste(names(values)[!is.finite(values)], collapse = ", "), ".", call. = FALSE)
  values
}
