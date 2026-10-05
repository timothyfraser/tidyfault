#' fluctuate() Function
#'
#' Draws uncertainty around failure rates (or probabilities). We rarely know a
#' failure rate exactly, so \code{fluctuate()} draws \code{n} plausible values
#' for each basic event from a Normal distribution centred on its estimate,
#' with a standard deviation of \code{cv} times the estimate, floored at zero.
#'
#' @param data (Required) Either one row of values, one column per basic event
#'   (a one-row data frame or tibble), or a scenario table from
#'   \code{\link{stipulate}}: a \code{scenario} column plus one column per basic
#'   event, one row per scenario.
#' @param n (Optional) The number of draws (simulations) per scenario. Default
#'   \code{1000}.
#' @param cv (Optional) The coefficient of variation: the standard deviation of
#'   each draw as a share of its value. Default \code{0.2} (+/- 20\%). Use
#'   \code{0} for no uncertainty.
#' @param seed (Optional) A single number passed to \code{set.seed()} before
#'   drawing, as in \code{\link{simulate}}, so the draws are reproducible.
#'   Default \code{NULL} uses the current random stream.
#'
#' @return A tibble with \code{n} rows per scenario: \code{scenario} (if
#'   \code{data} has it, a factor as in \code{data}), \code{sim} (the draw,
#'   \code{1} to \code{n}), then one column per basic event holding the drawn
#'   values. Rows are ordered by scenario, then by \code{sim}.
#'
#' @details For each basic event and each simulation, \code{fluctuate()} draws
#'   one standard Normal value \code{z} and forms the noise factor
#'   \code{max(1 + cv * z, 0)}. Each value is multiplied by its noise factor,
#'   which is the same as drawing from \code{Normal(mean = value, sd = cv *
#'   value)} and flooring at zero.
#'
#'   \strong{Common random numbers.} With a scenario table, every scenario
#'   reuses the \emph{same} noise factors: simulation 5 of "Fix A" and
#'   simulation 5 of "Neither" share one draw per event. Each scenario still
#'   gets the right spread (its own values times the noise), but the
#'   differences between scenarios come only from the scenarios themselves, not
#'   from different random draws. This makes comparisons between scenarios much
#'   sharper for the same \code{n}.
#'
#'   The draws are made event by event (all \code{n} draws for the first event
#'   column, then the next), so the same seed and columns give the same draws.
#'   The draws are not capped above: if \code{data} holds probabilities, a draw
#'   can exceed 1, so fluctuate rates and convert them to probabilities
#'   afterwards (for example with \code{pexp()}), or cap them with
#'   \code{pmin(x, 1)}.
#'
#' @seealso \code{\link{stipulate}} for scenario tables,
#'   \code{\link{quantify}} for the top event probability,
#'   \code{\link{quantify_if}} for one-at-a-time cuts.
#'
#' @keywords fault tree uncertainty simulation
#' @importFrom stats rnorm
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
#' # One row of failure rates (events per year), one column per basic event
#' rates <- it_security_outcomes_rates %>%
#'   select(event, lambda) %>%
#'   pivot_wider(names_from = event, values_from = lambda)
#'
#' # 1,000 plausible sets of failure rates, each rate +/- 20%
#' worlds <- fluctuate(rates, n = 1000, cv = 0.2, seed = 1)
#' worlds
#'
#' # The spread of the chance that data leaks within one year
#' worlds %>%
#'   mutate(across(-sim, ~ pexp(q = 1, rate = .x))) %>%
#'   mutate(p_top = quantify(f, newdata = pick(-sim), prob = TRUE)) %>%
#'   summarize(lower = quantile(p_top, 0.05), median = median(p_top),
#'             upper = quantile(p_top, 0.95))
#'
#' # Scenarios share the same draws (common random numbers)
#' stipulate(rates, "Fix A" = c(MN = 0.1), "Fix B" = c(PO = 0.1)) %>%
#'   fluctuate(n = 200, seed = 1) %>%
#'   mutate(across(-c(scenario, sim), ~ pexp(q = 1, rate = .x))) %>%
#'   mutate(p_top = quantify(f, newdata = pick(-c(scenario, sim)), prob = TRUE)) %>%
#'   group_by(scenario) %>%
#'   summarize(median = median(p_top))
fluctuate = function(data, n = 1000, cv = 0.2, seed = NULL) {
  if (!is.data.frame(data))
    stop("`data` must be a one-row data frame of values, or a scenario table from stipulate().",
         call. = FALSE)
  has_scenario = "scenario" %in% names(data)
  if (!has_scenario && nrow(data) != 1)
    stop("`data` must have exactly one row, or a `scenario` column (from stipulate()); ",
         "it has ", nrow(data), " rows and no `scenario` column.", call. = FALSE)
  if (nrow(data) == 0)
    stop("`data` has no rows.", call. = FALSE)
  if ("sim" %in% names(data))
    stop("`data` already has a `sim` column; fluctuate() adds it.", call. = FALSE)

  events = setdiff(names(data), "scenario")
  if (length(events) == 0)
    stop("`data` has no event columns to fluctuate.", call. = FALSE)
  is_num = vapply(data[events], is.numeric, logical(1))
  if (!all(is_num))
    stop("`data` event columns must be numeric. Not numeric: ",
         paste(events[!is_num], collapse = ", "), ".", call. = FALSE)
  values = as.matrix(data[events])
  storage.mode(values) = "double"
  if (any(!is.finite(values)) || any(values < 0))
    stop("`data` values must be finite and non-negative.", call. = FALSE)

  if (!is.numeric(n) || length(n) != 1 || !is.finite(n) || n < 1 || n != round(n))
    stop("`n` must be a single whole number >= 1, the number of draws.", call. = FALSE)
  n = as.integer(n)
  if (!is.numeric(cv) || length(cv) != 1 || !is.finite(cv) || cv < 0)
    stop("`cv` must be a single non-negative number (0.2 means +/- 20%).", call. = FALSE)
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1 || !is.finite(seed))
      stop("`seed` must be a single number, or NULL.", call. = FALSE)
    set.seed(seed)
  }

  # One noise factor per sim (row) x event (column), drawn event by event.
  # Every scenario row reuses these same factors: common random numbers.
  k = length(events)
  z = matrix(stats::rnorm(n * k), nrow = n, ncol = k)
  noise = pmax(1 + cv * z, 0)

  draws = lapply(seq_len(nrow(values)), function(r) {
    noise * rep(values[r, ], each = n)
  })
  draws = do.call(rbind, draws)
  colnames(draws) = events

  out = tibble::tibble(sim = rep(seq_len(n), times = nrow(values)),
                       tibble::as_tibble(draws))
  if (has_scenario)
    out = tibble::tibble(scenario = rep(data$scenario, each = n), out)
  out
}
