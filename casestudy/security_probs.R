#' `security_probs` security breach event probabilities
#'
#' A dataset containing hypothetical probabilities for each basic event
#' in the security breach fault tree. Probabilities represent
#' the likelihood that each event occurs (0 = never occurs, 1 = always occurs).
#'
#' @format ## `security_probs`
#' A data frame with 7 rows and 2 columns:
#' \describe{
#'   \item{event}{Event name matching the `event` column in `security_nodes`.}
#'   \item{probability}{Probability that the event occurs (0 to 1).}
#' }
#'
#' @details
#' Event probabilities:
#' - VE (Vulnerability exists): 0.25
#' - ES (Exploit successful): 0.12
#' - PH (Phishing): 0.20
#' - MW (Malware): 0.18
#' - UA (Unauthorized access): 0.10
#' - WP (Weak password): 0.30
#' - N2F (No 2FA): 0.22
#'
#' @examples
#' data("security_probs")
#' data("security_nodes")
#' data("security_edges")
#' library(tidyfault)
#' 
#' # Use probabilities in analysis
#' gates <- curate(nodes = security_nodes, edges = security_edges)
#'
#' @seealso [security_nodes] [security_edges] [security_outcomes_binary] [security_outcomes_rates]
"security_probs"
