#' `security_nodes` security breach fault tree nodes dataset
#'
#' An example dataset of nodes in a security breach fault tree.
#' This fault tree models scenarios where a security breach occurs due to
#' external attacks, internal threats, vulnerabilities, and authentication failures.
#'
#' @format ## `security_nodes`
#' A data frame with 11 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 11) for each node.}
#'   \item{event}{Name of event. `"T"` means top event (Security breach detected).
#'   `"G2"`, `"G3"`, etc. mean gates. `"VE"` = Vulnerability exists, `"ES"` = Exploit successful,
#'   `"PH"` = Phishing, `"MW"` = Malware, `"UA"` = Unauthorized access, `"WP"` = Weak password,
#'   `"N2F"` = No 2FA.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: Security breach detected
#' - G2 (AND): Vulnerability exists AND Exploit successful
#' - G3 (OR): Phishing OR Malware OR Unauthorized access
#' - G4 (AND): Weak password AND No 2FA
#'
#' @examples
#' data("security_nodes")
#' data("security_edges")
#' library(tidyfault)
#' curate(nodes = security_nodes, edges = security_edges)
#'
#' @seealso [security_edges] for the corresponding edges dataset
"security_nodes"
