#' `security_outcomes_binary` security breach binary outcomes
#'
#' A dataset containing hypothetical binary outcomes (0 = event did not occur,
#' 1 = event occurred) for multiple scenarios of the security breach fault tree.
#' Each row represents a different scenario or observation.
#'
#' @format ## `security_outcomes_binary`
#' A data frame with 10 rows and 8 columns:
#' \describe{
#'   \item{scenario}{Scenario identifier (1 to 10).}
#'   \item{VE}{Vulnerability exists (0 = no, 1 = yes).}
#'   \item{ES}{Exploit successful (0 = no, 1 = yes).}
#'   \item{PH}{Phishing (0 = no, 1 = yes).}
#'   \item{MW}{Malware (0 = no, 1 = yes).}
#'   \item{UA}{Unauthorized access (0 = no, 1 = yes).}
#'   \item{WP}{Weak password (0 = no, 1 = yes).}
#'   \item{N2F}{No 2FA (0 = no, 1 = yes).}
#' }
#'
#' @details
#' This dataset provides 10 different scenarios showing which events occurred
#' (1) or did not occur (0) in each scenario. These can be used to test
#' fault tree analysis or train predictive models.
#'
#' @examples
#' data("security_outcomes_binary")
#' data("security_nodes")
#' data("security_edges")
#' library(tidyfault)
#' 
#' # Use binary outcomes in analysis
#' gates <- curate(nodes = security_nodes, edges = security_edges)
#'
#' @seealso [security_nodes] [security_edges] [security_outcomes_prob] [security_outcomes_rates]
"security_outcomes_binary"
