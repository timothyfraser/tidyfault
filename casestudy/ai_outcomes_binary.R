#' `ai_outcomes_binary` AI agent failure binary outcomes
#'
#' A dataset containing hypothetical binary outcomes (0 = event did not occur,
#' 1 = event occurred) for multiple scenarios of the AI agent failure fault tree.
#' Each row represents a different scenario or observation.
#'
#' @format ## `ai_outcomes_binary`
#' A data frame with 10 rows and 5 columns:
#' \describe{
#'   \item{scenario}{Scenario identifier (1 to 10).}
#'   \item{AF}{API failure (0 = no, 1 = yes).}
#'   \item{TO}{Timeout (0 = no, 1 = yes).}
#'   \item{RL}{Rate limit (0 = no, 1 = yes).}
#'   \item{CWE}{Context window exceeded (0 = no, 1 = yes).}
#' }
#'
#' @details
#' This dataset provides 10 different scenarios showing which events occurred
#' (1) or did not occur (0) in each scenario. These can be used to test
#' fault tree analysis or train predictive models.
#'
#' @examples
#' data("ai_outcomes_binary")
#' data("ai_nodes")
#' data("ai_edges")
#' library(tidyfault)
#' 
#' # Use binary outcomes in analysis
#' gates <- curate(nodes = ai_nodes, edges = ai_edges)
#'
#' @seealso [ai_nodes] [ai_edges] [ai_outcomes_prob] [ai_outcomes_rates]
"ai_outcomes_binary"
