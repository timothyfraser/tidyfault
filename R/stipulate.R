#' stipulate() Function
#'
#' Builds a table of what-if scenarios. Each scenario multiplies the failure
#' rates (or probabilities) of some basic events by a factor, for example
#' \code{0.1} for a fix that removes 90\% of a component's failures, and keeps
#' every other event as it is. An unchanged baseline row comes first.
#'
#' @param data (Required) One row of values, one column per basic event: a
#'   one-row data frame or tibble, or a named numeric vector. Usually failure
#'   rates, but any non-negative values work.
#' @param ... (Required) One or more named scenarios. Each is a named numeric
#'   vector of multipliers, \code{c(event = factor)}, such as
#'   \code{"Fix A only" = c(MN = 0.1)}. Events a scenario does not name keep
#'   their value. Names with spaces need quotes or backticks.
#' @param baseline (Optional) The name of the unchanged row placed first.
#'   Default \code{"Neither"}. Use \code{NULL} to leave the baseline row out.
#'
#' @return A tibble with one row per scenario (the baseline first, then the
#'   scenarios in the order given). Its first column, \code{scenario}, is a
#'   factor whose levels follow that order; then one column per column of
#'   \code{data}, holding that scenario's values.
#'
#' @details Multipliers are applied to the values in \code{data} as they are.
#'   For rates, a multiplier of \code{0.1} means the event happens a tenth as
#'   often; convert to probabilities afterwards (for example with
#'   \code{pexp()}). Pass the result to \code{\link{fluctuate}} to add
#'   uncertainty, with every scenario sharing the same random draws.
#'
#' @seealso \code{\link{fluctuate}} for uncertainty draws,
#'   \code{\link{quantify_if}} for one-at-a-time cuts,
#'   \code{\link{quantify}} for the top event probability.
#'
#' @keywords fault tree scenarios
#' @importFrom rlang list2
#' @importFrom tibble as_tibble
#' @export
#' @examples
#' library(dplyr)
#' library(tidyr)
#' library(tidyfault)
#'
#' # One row of failure rates (events per year), one column per basic event
#' rates <- it_security_outcomes_rates %>%
#'   select(event, lambda) %>%
#'   pivot_wider(names_from = event, values_from = lambda)
#'
#' # Four scenarios: no fix, add multi-factor authentication (MN), patch on
#' # time (PO), or both. Each fix removes 90% of that component's failures.
#' scenarios <- stipulate(
#'   rates,
#'   "Fix A only" = c(MN = 0.1),
#'   "Fix B only" = c(PO = 0.1),
#'   "Fix A and B" = c(MN = 0.1, PO = 0.1)
#' )
#' scenarios
#'
#' # The probability that data leaks within one year, per scenario
#' f <- curate(nodes = it_security_nodes, edges = it_security_edges) %>%
#'   equate() %>%
#'   formulate()
#' scenarios %>%
#'   mutate(across(-scenario, ~ pexp(q = 1, rate = .x))) %>%
#'   mutate(p_top = quantify(f, newdata = pick(-scenario), prob = TRUE)) %>%
#'   select(scenario, p_top)
stipulate = function(data, ..., baseline = "Neither") {
  values = one_row_values(data, arg = "data", fun = "stipulate")
  if ("scenario" %in% names(values))
    stop("`data` already has a `scenario` column; give stipulate() one row of ",
         "values without it.", call. = FALSE)

  scenarios = rlang::list2(...)
  if (length(scenarios) == 0)
    stop("Give stipulate() at least one scenario, e.g. ",
         "stipulate(data, \"Fix A\" = c(MN = 0.1)).", call. = FALSE)
  labels = names(scenarios)
  if (is.null(labels) || any(is.na(labels) | labels == ""))
    stop("Every scenario in `...` needs a name, e.g. \"Fix A\" = c(MN = 0.1).",
         call. = FALSE)

  if (!is.null(baseline) &&
      (!is.character(baseline) || length(baseline) != 1 || is.na(baseline) || baseline == ""))
    stop("`baseline` must be a single non-empty name, or NULL to leave the baseline row out.",
         call. = FALSE)
  all_labels = c(baseline, labels)
  if (anyDuplicated(all_labels))
    stop("Scenario names must be unique (the baseline counts). Repeated: ",
         paste(unique(all_labels[duplicated(all_labels)]), collapse = ", "), ".",
         call. = FALSE)

  rows = lapply(labels, function(label) {
    m = scenarios[[label]]
    if (!is.numeric(m) || length(m) == 0 || is.null(names(m)) ||
        any(is.na(names(m)) | names(m) == ""))
      stop("Scenario \"", label, "\" must be a named numeric vector of multipliers, ",
           "e.g. c(MN = 0.1).", call. = FALSE)
    unknown = setdiff(names(m), names(values))
    if (length(unknown) > 0)
      stop("Scenario \"", label, "\" names events not in `data`: ",
           paste(unknown, collapse = ", "), ". `data` has: ",
           paste(names(values), collapse = ", "), ".", call. = FALSE)
    if (anyDuplicated(names(m)))
      stop("Scenario \"", label, "\" names an event twice: ",
           paste(unique(names(m)[duplicated(names(m))]), collapse = ", "), ".",
           call. = FALSE)
    if (any(!is.finite(m)) || any(m < 0))
      stop("Scenario \"", label, "\" multipliers must be finite and non-negative.",
           call. = FALSE)
    v = values
    v[names(m)] = v[names(m)] * m
    v
  })
  if (!is.null(baseline)) rows = c(list(values), rows)

  out = tibble::as_tibble(as.data.frame(do.call(rbind, rows), optional = TRUE))
  out = tibble::tibble(scenario = factor(all_labels, levels = all_labels), out)
  out
}
