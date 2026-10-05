#' `db_edges` database system failure fault tree edge dataset
#'
#' An example dataset of edges (connections) in a database system failure fault tree.
#'
#' @format ## `db_edges`
#' A data frame with 13 rows and 2 columns (the top event `T`, id 1, links only to
#' its one gate `G0`, id 14, which links to gates `G1` to `G4`):
#' \describe{
#'   \item{from}{Unique `id` of the source/`from` node from which edge originates.}
#'   \item{to}{Unique `id` of the destination/`to` node that edge connects to.}
#' }
#'
#' @examples
#' data("db_edges")
#' head(db_edges)
#' dim(db_edges)
#'
#' @seealso \code{\link[tidyfault]{db_nodes}} for the corresponding nodes dataset
"db_edges"
