#' `db_outcomes_binary` database system failure binary outcomes
#'
#' A dataset containing hypothetical binary outcomes (0 = event did not occur,
#' 1 = event occurred) for multiple scenarios of the database system failure
#' fault tree. Each row represents a different scenario or observation.
#'
#' @format ## `db_outcomes_binary`
#' A data frame with 10 rows and 9 columns:
#' \describe{
#'   \item{scenario}{Scenario identifier (1 to 10).}
#'   \item{DC}{Data corruption (0 = no, 1 = yes).}
#'   \item{AF}{Access failure (0 = no, 1 = yes).}
#'   \item{SF}{Storage failure (0 = no, 1 = yes).}
#'   \item{BF}{Backup failure (0 = no, 1 = yes).}
#'   \item{NF}{Network failure (0 = no, 1 = yes).}
#'   \item{AUF}{Authentication failure (0 = no, 1 = yes).}
#'   \item{HF}{Hardware failure (0 = no, 1 = yes).}
#'   \item{MF}{Monitoring failure (0 = no, 1 = yes).}
#' }
#'
#' @details
#' This dataset provides 10 different scenarios showing which events occurred
#' (1) or did not occur (0) in each scenario. These can be used to test
#' fault tree analysis or train predictive models.
#'
#' @examples
#' data("db_outcomes_binary")
#' data("db_nodes")
#' data("db_edges")
#' library(tidyfault)
#' 
#' # Use binary outcomes in analysis
#' gates <- curate(nodes = db_nodes, edges = db_edges)
#'
#' @seealso [db_nodes] [db_edges] [db_outcomes_prob] [db_outcomes_rates]
"db_outcomes_binary"
