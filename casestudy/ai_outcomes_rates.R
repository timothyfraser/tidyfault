#' `ai_outcomes_rates` AI agent failure exponential failure rates
#'
#' A dataset containing exponential distribution parameters (lambda) for each
#' basic event in the AI agent failure fault tree. The failure rate
#' lambda represents the rate parameter of an exponential distribution,
#' where the probability of failure by time t is 1 - exp(-lambda * t).
#'
#' @format ## `ai_outcomes_rates`
#' A data frame with 4 rows and 3 columns:
#' \describe{
#'   \item{event}{Event name matching the `event` column in `ai_nodes`.}
#'   \item{lambda}{Exponential distribution rate parameter (failures per unit time).}
#'   \item{time_unit}{Time unit for the lambda parameter (e.g., "requests", "hours").}
#' }
#'
#' @details
#' Failure rates (lambda) per 1000 requests:
#' - AF (API failure): 0.30 failures/1000 requests
#' - TO (Timeout): 0.40 failures/1000 requests
#' - RL (Rate limit): 0.50 failures/1000 requests
#' - CWE (Context window exceeded): 0.28 failures/1000 requests
#'
#' The probability of failure by time t is: P(T <= t) = 1 - exp(-lambda * t)
#'
#' @examples
#' data("ai_outcomes_rates")
#' data("ai_nodes")
#' data("ai_edges")
#' library(tidyfault)
#' 
#' # Calculate failure probability at t = 5000 requests
#' t <- 5000
#' ai_outcomes_rates$prob_at_t <- 1 - exp(-ai_outcomes_rates$lambda * t / 1000)
#'
#' @seealso [ai_nodes] [ai_edges] [ai_outcomes_prob] [ai_outcomes_binary]
"ai_outcomes_rates"
