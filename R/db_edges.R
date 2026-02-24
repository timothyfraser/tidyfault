#' `db_edges` database system failure fault tree edge dataset
#'
#' An example dataset of edges (connections) in a database system failure fault tree.
#'
#' @format ## `db_edges`
#' A data frame with 11 rows and 2 columns:
#' \describe{
#'   \item{from}{Unique `id` of the source/`from` node from which edge originates.}
#'   \item{to}{Unique `id` of the destination/`to` node that edge connects to.}
#' }
#'
#' @seealso \code{\link[tidyfault]{db_nodes}} for the corresponding nodes dataset
"db_edges"
