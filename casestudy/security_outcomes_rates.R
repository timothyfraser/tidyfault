#' `security_outcomes_rates` security breach exponential failure rates
#'
#' A dataset containing exponential distribution parameters (lambda) for each
#' basic event in the security breach fault tree. The failure rate
#' lambda represents the rate parameter of an exponential distribution,
#' where the probability of failure by time t is 1 - exp(-lambda * t).
#'
#' @format ## `security_outcomes_rates`
#' A data frame with 7 rows and 3 columns:
#' \describe{
#'   \item{event}{Event name matching the `event` column in `security_nodes`.}
#'   \item{lambda}{Exponential distribution rate parameter (failures per unit time).}
#'   \item{time_unit}{Time unit for the lambda parameter (e.g., "days", "weeks").}
#' }
#'
#' @details
#' Failure rates (lambda) per day:
#' - VE (Vulnerability exists): 0.005 failures/day
#' - ES (Exploit successful): 0.0025 failures/day
#' - PH (Phishing): 0.004 failures/day
#' - MW (Malware): 0.0035 failures/day
#' - UA (Unauthorized access): 0.002 failures/day
#' - WP (Weak password): 0.006 failures/day
#' - N2F (No 2FA): 0.0045 failures/day
#'
#' The probability of failure by time t is: P(T <= t) = 1 - exp(-lambda * t)
#'
#' @examples
#' data("security_outcomes_rates")
#' data("security_nodes")
#' data("security_edges")
#' library(tidyfault)
#' 
#' # Calculate failure probability at time t = 30 days
#' t <- 30
#' security_outcomes_rates$prob_at_t <- 1 - exp(-security_outcomes_rates$lambda * t)
#'
#' @seealso [security_nodes] [security_edges] [security_outcomes_prob] [security_outcomes_binary]
"security_outcomes_rates"
