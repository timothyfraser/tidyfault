#' quantify_ci() Function
#'
#' Puts an uncertainty interval around the probability of the top event. We
#' rarely know a failure rate exactly, so \code{quantify_ci()} draws \code{n}
#' plausible values for each basic event from a Normal distribution centred on
#' its estimate (standard deviation \code{cv} times the estimate, floored at
#' zero), evaluates the top event for every draw, and reports the median and
#' the central \code{level} interval. It is the uncertainty engine behind
#' \code{quantify_if(ci = TRUE)} and \code{quantify_when(ci = TRUE)}.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event.
#' @param data (Required) One or more rows of values, one column per basic
#'   event of \code{f}: a data frame or tibble, or a named numeric vector for a
#'   single row. With \code{time} (or a \code{time} column), the values are
#'   failure rates (events per hour, by default); without it, they are failure
#'   probabilities. An optional \code{scenario} column and an optional
#'   \code{time} column pass through to the result; other extra columns are
#'   ignored.
#' @param n (Optional) The number of draws (simulated worlds) per row. Default
#'   \code{1000}.
#' @param cv (Optional) The coefficient of variation: the standard deviation of
#'   each draw as a share of its value. Default \code{0.2} (+/- 20\%). Use
#'   \code{0} for no uncertainty.
#' @param time (Optional) One or more non-negative times, in the same unit as
#'   the rates (hours, the reliability-engineering convention; 8,760 hours is
#'   one year). If given, \code{data} holds failure rates, every row is
#'   evaluated at every time, and each drawn rate becomes the probability of
#'   failing by that time, \code{pexp(time, rate)}. Leave it \code{NULL} when
#'   \code{data} already has a \code{time} column (per-row times), or when
#'   \code{data} holds probabilities.
#' @param level (Optional) The coverage of the interval, in \code{(0, 1)}.
#'   Default \code{0.90}: \code{lower} and \code{upper} are the 5th and 95th
#'   percentiles of the draws.
#' @param seed (Optional) A single number passed to \code{set.seed()} before
#'   drawing, as in \code{\link{simulate}}, so the draws are reproducible.
#'   Default \code{NULL} uses the current random stream.
#' @param draws (Optional) \code{FALSE} (default) returns one summary row per
#'   input row (and time). \code{TRUE} returns every draw instead.
#'
#' @return A tibble. With \code{draws = FALSE}, one row per row of \code{data}
#'   (times each value of \code{time}, if given), in that order, with columns:
#'   \itemize{
#'     \item \code{scenario}: if \code{data} has it (a factor stays a factor).
#'     \item \code{time}: when the values are rates.
#'     \item \code{p_top}: the median probability of the top event across the
#'       draws.
#'     \item \code{lower}, \code{upper}: the central \code{level} interval of
#'       the draws (\code{quantile()}, type 7).
#'   }
#'   With \code{draws = TRUE}, \code{n} rows per input row: \code{scenario}
#'   and \code{time} as above, \code{sim} (the draw, \code{1} to \code{n}) and
#'   \code{p_top} for that draw.
#'
#' @details For each basic event and each draw, \code{quantify_ci()} draws one
#'   standard Normal value \code{z} and forms the noise factor
#'   \code{max(1 + cv * z, 0)}. Each value is multiplied by its noise factor,
#'   which is the same as drawing from \code{Normal(mean = value, sd = cv *
#'   value)} and flooring at zero. Drawn probabilities are capped at 1; drawn
#'   rates need no cap, because \code{pexp()} turns them into probabilities.
#'
#'   \strong{Common random numbers.} The noise factors are drawn \emph{once},
#'   an \code{n} by events matrix, and every row of \code{data} (every
#'   scenario, every time) reuses them: draw 5 of "Fix A" and draw 5 of
#'   "Neither" share one noise factor per event. Each row still gets the right
#'   spread, but the differences between rows come only from the rows
#'   themselves, not from different random draws, which makes comparisons much
#'   sharper for the same \code{n}.
#'
#'   The noise is drawn event by event (all \code{n} draws for the first event
#'   column of \code{data}, then the next), in the order the events' columns
#'   appear in \code{data}, so the same seed and the same \code{data} give the
#'   same draws. All \code{n * nrow(data)} rows go through \code{quantify(f,
#'   prob = TRUE)} in one call.
#'
#' @seealso \code{\link{quantify_when}} for scenarios over time,
#'   \code{\link{quantify_if}} for one-at-a-time cuts,
#'   \code{\link{quantify}} for the top event probability.
#'
#' @keywords fault tree uncertainty simulation
#' @importFrom methods formalArgs
#' @importFrom stats median pexp quantile rnorm
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
#' # The chance that data leaks within one year (8,760 hours), with a 90%
#' # interval from 1,000 plausible sets of failure rates, each +/- 20%
#' quantify_ci(f, rates, time = 8760, seed = 1)
#'
#' # The same draws at three horizons: one, two and five years
#' quantify_ci(f, rates, time = c(1, 2, 5) * 8760, seed = 1)
#'
#' # Every draw, for a histogram of the risk
#' quantify_ci(f, rates, time = 8760, n = 200, seed = 1, draws = TRUE)
#'
#' # Probabilities instead of rates: leave out `time`
#' quantify_ci(f, it_security_probs, n = 200, seed = 1)
quantify_ci = function(f, data, n = 1000, cv = 0.2, time = NULL, level = 0.90,
                       seed = NULL, draws = FALSE) {
  if (!is.function(f))
    stop("`f` must be a function from formulate().", call. = FALSE)
  fargs = methods::formalArgs(f)
  if (is.numeric(data) && !is.null(names(data)) && !is.data.frame(data))
    data = tibble::as_tibble(as.list(data))
  if (!is.data.frame(data))
    stop("`data` must be a data frame (one row per scenario) or a named numeric vector, ",
         "one value per basic event.", call. = FALSE)
  if (nrow(data) == 0)
    stop("`data` has no rows.", call. = FALSE)

  missing = setdiff(fargs, names(data))
  if (length(missing) > 0)
    stop("`data` must have a column for every basic event of `f`. Missing: ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  # The events in the order their columns appear in `data`: this fixes which
  # column of noise goes to which event, so the same seed gives the same draws.
  events = names(data)[names(data) %in% fargs]
  is_num = vapply(data[events], is.numeric, logical(1))
  if (!all(is_num))
    stop("`data` event columns must be numeric. Not numeric: ",
         paste(events[!is_num], collapse = ", "), ".", call. = FALSE)
  values = as.matrix(data[events])
  storage.mode(values) = "double"
  if (any(!is.finite(values)) || any(values < 0))
    stop("`data` values must be finite and non-negative.", call. = FALSE)

  has_scenario = "scenario" %in% names(data)
  has_time = "time" %in% names(data) && !("time" %in% fargs)
  if (has_time && !is.null(time))
    stop("`data` already has a `time` column; leave `time` NULL, or drop the column.",
         call. = FALSE)
  if (!is.null(time) && !valid_times(time))
    stop("`time` must be one or more finite, non-negative numbers (hours, by default), ",
         "or NULL when `data` holds probabilities.", call. = FALSE)
  if (has_time && !valid_times(data$time))
    stop("The `time` column of `data` must hold finite, non-negative numbers.", call. = FALSE)
  rates = has_time || !is.null(time)
  if (!rates && any(values > 1))
    stop("Without `time`, `data` must hold probabilities in [0, 1]. Above 1: ",
         paste(events[colSums(values > 1) > 0], collapse = ", "),
         ". If these are failure rates, pass `time`.", call. = FALSE)

  check_ci_args(n = n, cv = cv, level = level, seed = seed)
  if (!is.logical(draws) || length(draws) != 1 || is.na(draws))
    stop("`draws` must be TRUE or FALSE.", call. = FALSE)
  n = as.integer(n)

  # The rows to evaluate: every row of `data`, crossed with `time` if given.
  keys = list()
  if (!is.null(time)) {
    row = rep(seq_len(nrow(data)), each = length(time))
    t = rep(as.numeric(time), times = nrow(data))
  } else {
    row = seq_len(nrow(data))
    t = if (has_time) as.numeric(data$time) else NULL
  }
  if (has_scenario) keys$scenario = data$scenario[row]
  if (rates) keys$time = t
  keys = tibble::as_tibble(keys, .rows = length(row))
  values = values[row, , drop = FALSE]
  r = nrow(values)

  if (!is.null(seed)) set.seed(seed)
  # One noise factor per draw (row) x event (column), drawn event by event.
  # Every row of `data` reuses these same factors: common random numbers.
  k = length(events)
  z = matrix(stats::rnorm(n * k), nrow = n, ncol = k)
  noise = pmax(1 + cv * z, 0)

  # Rows ordered by input row, then by draw.
  big = noise[rep(seq_len(n), times = r), , drop = FALSE] *
    values[rep(seq_len(r), each = n), , drop = FALSE]
  if (rates) {
    big[] = stats::pexp(q = rep(t, each = n), rate = big)
  } else {
    big[] = pmin(big, 1)
  }
  colnames(big) = events
  p = quantify(f = f, newdata = as.data.frame(big), prob = TRUE)

  if (draws)
    return(tibble::tibble(keys[rep(seq_len(r), each = n), , drop = FALSE],
                          sim = rep(seq_len(n), times = r), p_top = p))

  probs = round(c((1 - level) / 2, (1 + level) / 2), 12)
  pm = matrix(p, nrow = n)   # column j holds the n draws of row j
  tibble::tibble(
    keys,
    p_top = apply(pm, 2, stats::median),
    lower = apply(pm, 2, stats::quantile, probs = probs[1], names = FALSE),
    upper = apply(pm, 2, stats::quantile, probs = probs[2], names = FALSE)
  )
}

# TRUE when x is a non-empty numeric vector of finite, non-negative times.
valid_times = function(x) {
  is.numeric(x) && length(x) >= 1 && all(is.finite(x)) && all(x >= 0)
}

# The uncertainty arguments shared by quantify_ci(), quantify_if() and
# quantify_when(); seeds nothing, only checks.
check_ci_args = function(n, cv, level, seed) {
  if (!is.numeric(n) || length(n) != 1 || !is.finite(n) || n < 1 || n != round(n))
    stop("`n` must be a single whole number >= 1, the number of draws.", call. = FALSE)
  if (!is.numeric(cv) || length(cv) != 1 || !is.finite(cv) || cv < 0)
    stop("`cv` must be a single non-negative number (0.2 means +/- 20%).", call. = FALSE)
  if (!is.numeric(level) || length(level) != 1 || !is.finite(level) || level <= 0 || level >= 1)
    stop("`level` must be a single number in (0, 1), the coverage of the interval ",
         "(0.90 gives the 5th to 95th percentiles).", call. = FALSE)
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1 || !is.finite(seed)))
    stop("`seed` must be a single number, or NULL.", call. = FALSE)
  invisible(TRUE)
}
