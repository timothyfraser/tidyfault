#' `ai_outcomes_prob` AI agent failure event probabilities
#'
#' A dataset containing hypothetical probabilities for each basic event
#' in the AI agent failure fault tree. Probabilities represent
#' the likelihood that each event occurs (0 = never occurs, 1 = always occurs).
#'
#' @format ## `ai_outcomes_prob`
#' A data frame with 4 rows and 2 columns:
#' \describe{
#'   \item{event}{Event name matching the `event` column in `ai_nodes`.}
#'   \item{probability}{Probability that the event occurs (0 to 1).}
#' }
#'
#' @details
#' Event probabilities:
#' - AF (API failure): 0.15
#' - TO (Timeout): 0.20
#' - RL (Rate limit): 0.25
#' - CWE (Context window exceeded): 0.14
#'
#' @examples
#' data("ai_outcomes_prob")
#' data("ai_nodes")
#' data("ai_edges")
#' library(tidyfault)
#' 
#' # Use probabilities in analysis
#' gates <- curate(nodes = ai_nodes, edges = ai_edges)
#'
#' @seealso [ai_nodes] [ai_edges] [ai_outcomes_binary] [ai_outcomes_rates]
"ai_outcomes_prob"
