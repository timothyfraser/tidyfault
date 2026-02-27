#' `it_security_nodes` IT security (data leak) fault tree nodes dataset
#'
#' An example dataset of nodes in a fault tree for sensitive data leaving the
#' organization. The tree models three ways a breach can happen: an outsider gets
#' high-level access, an attacker uses a known flaw that was not fixed, or
#' someone inside sends data out.
#'
#' @format ## `it_security_nodes`
#' A data frame with 16 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 16) for each node.}
#'   \item{event}{Two-letter event code. \code{"DE"} = Sensitive data leaves the organization (top).
#'   Gates: \code{"BP"} = Ways a breach can happen (OR), \code{"EA"} = Outsider gets high-level access (AND),
#'   \code{"UE"} = Attacker uses a known flaw that was not fixed (AND), \code{"IE"} = Someone inside sends data out (AND),
#'   \code{"CC"} = Log-in details stolen or misused (OR). Basic events: \code{"PC"} = Passwords obtained via fake email or link,
#'   \code{"LR"} = Passwords exposed in a breach or reused elsewhere, \code{"MN"} = No second login step required,
#'   \code{"PM"} = Admin-level access set up incorrectly, \code{"VS"} = System has a known security hole,
#'   \code{"PO"} = Security updates not applied on time, \code{"WB"} = Web traffic filter missing or bypassed,
#'   \code{"IM"} = Employee did it on purpose or account was taken over, \code{"DA"} = No controls to stop data from being copied out,
#'   \code{"EP"} = User had more access than needed for their job.}
#'   \item{type}{Factor classification as "top", "and", "or", or "not".}
#' }
#'
#' @details
#' The fault tree structure (event codes):
#' - Top event: DE (Sensitive data leaves the organization)
#' - BP (OR): EA OR UE OR IE
#' - EA (AND): CC AND MN AND PM
#' - UE (AND): VS AND PO AND WB
#' - IE (AND): IM AND DA AND EP
#' - CC (OR): PC OR LR
#'
#' @examples
#' data("it_security_nodes")
#' data("it_security_edges")
#' library(tidyfault)
#' curate(nodes = it_security_nodes, edges = it_security_edges)
#'
#' @seealso \code{\link[tidyfault]{it_security_edges}} for the corresponding edges dataset
"it_security_nodes"
