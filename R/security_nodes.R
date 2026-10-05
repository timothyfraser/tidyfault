#' `security_nodes` security breach fault tree nodes dataset
#'
#' An example dataset of nodes in a security breach fault tree.
#' This fault tree models scenarios where a security breach occurs due to
#' external attacks, internal threats, vulnerabilities, and authentication failures.
#'
#' @format ## `security_nodes`
#' A data frame with 12 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 12) for each node.}
#'   \item{event}{Name of event. `"T"` means top event (Security breach detected).
#'   `"G0"`, `"G2"`, `"G3"`, `"G4"` mean gates; `"G0"` (id 12) is the top event's one gate. `"VE"` = Vulnerability exists, `"ES"` = Exploit successful,
#'   `"PH"` = Phishing, `"MW"` = Malware, `"UA"` = Unauthorized access, `"WP"` = Weak password,
#'   `"N2F"` = No 2FA.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: Security breach detected. The top event is not a gate: its one
#'   child is G0.
#' - G0 (OR): G2 OR G3 OR G4 (any attack path is a breach)
#' - G2 (AND): Vulnerability exists AND Exploit successful
#' - G3 (OR): Phishing OR Malware OR Unauthorized access
#' - G4 (AND): Weak password AND No 2FA
#'
#' Minimal cut sets: `MW`, `PH`, `UA`, `ES*VE`, `N2F*WP`.
#'
#' @examples
#' data("security_nodes")
#' head(security_nodes)
#' dim(security_nodes)
#'
#' @seealso \code{\link[tidyfault]{security_edges}} for the corresponding edges dataset
"security_nodes"
