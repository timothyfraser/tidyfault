#' `db_outcomes_rates` database system failure exponential failure rates
#'
#' A dataset containing exponential distribution parameters (lambda) for each
#' basic event in the database system failure fault tree. The failure rate
#' lambda represents the rate parameter of an exponential distribution,
#' where the probability of failure by time t is 1 - exp(-lambda * t).
#'
#' @format ## `db_outcomes_rates`
#' A data frame with 8 rows and 3 columns:
#' \describe{
#'   \item{event}{Event name matching the `event` column in `db_nodes`.}
#'   \item{lambda}{Exponential distribution rate parameter (failures per unit time).}
#'   \item{time_unit}{Time unit for the lambda parameter (e.g., "hours", "days").}
#' }
#'
#' @details
#' Failure rates (lambda) per hour:
#' - DC (Data corruption): 0.0001 failures/hour
#' - AF (Access failure): 0.0002 failures/hour
#' - SF (Storage failure): 0.00015 failures/hour
#' - BF (Backup failure): 0.0003 failures/hour
#' - NF (Network failure): 0.00025 failures/hour
#' - AUF (Authentication failure): 0.00012 failures/hour
#' - HF (Hardware failure): 0.00008 failures/hour
#' - MF (Monitoring failure): 0.0004 failures/hour
#'
#' The probability of failure by time t is: P(T <= t) = 1 - exp(-lambda * t)
#'
#' @examples
#' data("db_outcomes_rates")
#' data("db_nodes")
#' data("db_edges")
#' library(tidyfault)
#' 
#' # Calculate failure probability at time t = 100 hours
#' t <- 100
#' db_outcomes_rates$prob_at_t <- 1 - exp(-db_outcomes_rates$lambda * t)
#'
#' @seealso [db_nodes] [db_edges] [db_probs] [db_outcomes_binary]
"db_outcomes_rates"
