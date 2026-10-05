#' quantify_when() Function
#'
#' Asks "when does it fail, and what if we fix something?". Builds what-if
#' scenarios from one row of failure rates, each scenario multiplying the rates
#' of some basic events by a factor (for example \code{0.1} for a fix that
#' removes 90\% of a component's failures), and follows the probability of the
#' top event over time for every scenario, with an uncertainty interval.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event.
#' @param data (Required) One row of failure rates (events per hour, by
#'   default), one column per basic event of \code{f}: a one-row data frame or
#'   tibble, or a named numeric vector. Extra columns are ignored.
#' @param ... (Required) One or more named scenarios. Each is a named numeric
#'   vector of multipliers, \code{c(event = factor)}, such as
#'   \code{"Fix A only" = c(MN = 0.1)}. Events a scenario does not name keep
#'   their rate. Names with spaces need quotes or backticks.
#' @param time (Optional) The times to evaluate, in the same unit as the rates:
#'   one or more finite, non-negative numbers. The default,
#'   \code{seq(0, 87600, by = 4380)}, is 0 to 10 years in half-year steps, in
#'   hours (the reliability-engineering convention; 8,760 hours is one year).
#' @param baseline (Optional) The name of the unchanged scenario placed first.
#'   Default \code{"Neither"}. Use \code{NULL} to leave it out.
#' @param ci (Optional) \code{TRUE} (default) adds an uncertainty interval from
#'   \code{\link{quantify_ci}}; \code{FALSE} returns the exact point estimate
#'   only, and ignores \code{n}, \code{cv}, \code{level} and \code{seed}.
#' @param n,cv,level,seed (Optional) Passed to \code{\link{quantify_ci}} when
#'   \code{ci = TRUE}: the number of draws (default \code{1000}), the
#'   coefficient of variation of each rate (default \code{0.2}), the coverage
#'   of the interval (default \code{0.90}) and a seed for
#'   \code{set.seed()} (default \code{NULL}, the current random stream).
#'
#' @return A tibble with one row per scenario and time (the baseline first,
#'   then the scenarios in the order given; times in the order given), with
#'   columns:
#'   \itemize{
#'     \item \code{scenario}: a factor whose levels follow that order.
#'     \item \code{time}: the time, in the unit of the rates.
#'     \item \code{p_top}: the probability that the top event has happened by
#'       \code{time}. With \code{ci = TRUE}, the median across the draws; with
#'       \code{ci = FALSE}, the exact value at the given rates.
#'     \item \code{lower}, \code{upper}: the central \code{level} interval of
#'       the draws. Only with \code{ci = TRUE}; with \code{ci = FALSE} these
#'       columns are left out.
#'     \item \code{reliability}: \code{1 - p_top}, the chance the system has
#'       not failed by \code{time}.
#'   }
#'
#' @details Multipliers are applied to the rates; each scenario's rates then
#'   become probabilities of failing by each time, \code{pexp(time, rate)}, and
#'   go through \code{quantify(f, prob = TRUE)} in one call. With
#'   \code{ci = TRUE}, every scenario and every time shares the \emph{same}
#'   random draws (common random numbers; see \code{\link{quantify_ci}}), so
#'   the gaps between the scenarios come from the fixes, not from noise.
#'
#' @seealso \code{\link{quantify_ci}} for the uncertainty draws,
#'   \code{\link{quantify_if}} for one-at-a-time cuts,
#'   \code{\link{quantify}} for the top event probability.
#'
#' @keywords fault tree scenarios reliability
#' @importFrom methods formalArgs
#' @importFrom rlang list2
#' @importFrom stats pexp
#' @importFrom tibble as_tibble tibble
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
#' # Four scenarios: no fix, add multi-factor authentication (MN), patch on
#' # time (PO), or both. Each fix removes 90% of that component's failures.
#' # The chance that data leaks within 0 to 10 years, with 90% intervals.
#' over_time <- quantify_when(
#'   f, rates,
#'   "Fix A only" = c(MN = 0.1),
#'   "Fix B only" = c(PO = 0.1),
#'   "Fix A and B" = c(MN = 0.1, PO = 0.1),
#'   n = 200, seed = 1
#' )
#' over_time %>% filter(time == 8760)   # one year
#'
#' # Point estimates only, at one, two and five years
#' quantify_when(f, rates, "Fix A only" = c(MN = 0.1),
#'               time = c(1, 2, 5) * 8760, ci = FALSE)
quantify_when = function(f, data, ..., time = seq(0, 87600, by = 4380),
                         baseline = "Neither", ci = TRUE, n = 1000, cv = 0.2,
                         level = 0.90, seed = NULL) {
  if (!is.function(f))
    stop("`f` must be a function from formulate().", call. = FALSE)
  fargs = methods::formalArgs(f)
  if (!is.data.frame(data) && !(is.numeric(data) && !is.null(names(data))))
    stop("`data` must be a one-row data frame or a named numeric vector, ",
         "one rate per basic event.", call. = FALSE)
  missing = setdiff(fargs, names(data))
  if (length(missing) > 0)
    stop("`data` must have a column for every basic event of `f`. Missing: ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  # Keep data's column order (it fixes the order of the random draws); extra
  # columns (an id, a label) are ignored.
  values = one_row_values(data[names(data)[names(data) %in% fargs]],
                          arg = "data", fun = "quantify_when")
  if (any(values < 0))
    stop("`data` values must be non-negative. Negative: ",
         paste(names(values)[values < 0], collapse = ", "), ".", call. = FALSE)

  if (!valid_times(time))
    stop("`time` must be one or more finite, non-negative numbers (hours, by default).",
         call. = FALSE)
  if (!is.logical(ci) || length(ci) != 1 || is.na(ci))
    stop("`ci` must be TRUE or FALSE.", call. = FALSE)

  scenarios = scenario_table(values, rlang::list2(...), baseline = baseline)
  grid = scenarios[rep(seq_len(nrow(scenarios)), each = length(time)), , drop = FALSE]
  grid$time = rep(as.numeric(time), times = nrow(scenarios))

  if (ci) {
    out = quantify_ci(f = f, data = grid, n = n, cv = cv, level = level, seed = seed)
  } else {
    probs = as.matrix(grid[names(values)])
    probs[] = stats::pexp(q = grid$time, rate = probs)
    out = tibble::tibble(scenario = grid$scenario, time = grid$time,
                         p_top = quantify(f = f, newdata = as.data.frame(probs), prob = TRUE))
  }
  out$reliability = 1 - out$p_top
  out
}

# The scenario table behind quantify_when(): an unchanged baseline row first
# (unless baseline is NULL), then one row per named scenario of multipliers.
# Returns a tibble: scenario (a factor in that order), then one column per value.
scenario_table = function(values, scenarios, baseline = "Neither") {
  if (length(scenarios) == 0)
    stop("Give quantify_when() at least one scenario, e.g. ",
         "quantify_when(f, data, \"Fix A\" = c(MN = 0.1)).", call. = FALSE)
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
      stop("Scenario \"", label, "\" names events that are not basic events of `f`: ",
           paste(unknown, collapse = ", "), ". Choose from: ",
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
  tibble::tibble(scenario = factor(all_labels, levels = all_labels), out)
}
