#' `ai_edges` AI agent failure fault tree edge dataset
#'
#' An example dataset of edges (connections) in an AI agent failure fault tree.
#'
#' @format ## `ai_edges`
#' A data frame with 6 rows and 2 columns (the top event `T`, id 1, links only to
#' its one gate `G0`, id 7, which links to gate `G3` and to `CWE`):
#' \describe{
#'   \item{from}{Unique `id` of the source/`from` node from which edge originates.}
#'   \item{to}{Unique `id` of the destination/`to` node that edge connects to.}
#' }
#'
#' @examples
#' data("ai_edges")
#' head(ai_edges)
#' dim(ai_edges)
#'
#' @seealso \code{\link[tidyfault]{ai_nodes}} for the corresponding nodes dataset
"ai_edges"
