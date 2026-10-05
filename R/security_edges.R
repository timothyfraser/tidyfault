#' `security_edges` security breach fault tree edge dataset
#'
#' An example dataset of edges (connections) in a security breach fault tree.
#'
#' @format ## `security_edges`
#' A data frame with 11 rows and 2 columns (the top event `T`, id 1, links only to
#' its one gate `G0`, id 12, which links to gates `G2`, `G3` and `G4`):
#' \describe{
#'   \item{from}{Unique `id` of the source/`from` node from which edge originates.}
#'   \item{to}{Unique `id` of the destination/`to` node that edge connects to.}
#' }
#'
#' @examples
#' data("security_edges")
#' head(security_edges)
#' dim(security_edges)
#'
#' @seealso \code{\link[tidyfault]{security_nodes}} for the corresponding nodes dataset
"security_edges"
