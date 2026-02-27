#' `it_security_edges` IT security (data leak) fault tree edge dataset
#'
#' An example dataset of edges (connections) in an IT security fault tree
#' for sensitive data leaving the organization.
#'
#' @format ## `it_security_edges`
#' A data frame with 15 rows and 2 columns:
#' \describe{
#'   \item{from}{Source node \code{id}.}
#'   \item{to}{Destination node \code{id}.}
#' }
#'
#' @seealso \code{\link[tidyfault]{it_security_nodes}} for the corresponding nodes dataset
"it_security_edges"
