#' `db_probs` database system failure event probabilities
#'
#' A dataset containing hypothetical probabilities for each basic event
#' in the database system failure fault tree. Probabilities represent
#' the likelihood that each event occurs (0 = never occurs, 1 = always occurs).
#'
#' @format ## `db_probs`
#' A data frame with 8 rows and 2 columns:
#' \describe{
#'   \item{event}{Event name matching the `event` column in `db_nodes`.}
#'   \item{probability}{Probability that the event occurs (0 to 1).}
#' }
#'
#' @details
#' Event probabilities:
#' - DC (Data corruption): 0.05
#' - AF (Access failure): 0.10
#' - SF (Storage failure): 0.08
#' - BF (Backup failure): 0.15
#' - NF (Network failure): 0.12
#' - AUF (Authentication failure): 0.06
#' - HF (Hardware failure): 0.04
#' - MF (Monitoring failure): 0.20
#'
#' @examples
#' data("db_probs")
#' data("db_nodes")
#' data("db_edges")
#' library(tidyfault)
#' 
#' # Use probabilities in analysis
#' gates <- curate(nodes = db_nodes, edges = db_edges)
#'
#' @seealso [db_nodes] [db_edges] [db_outcomes_binary] [db_outcomes_rates]
"db_probs"
