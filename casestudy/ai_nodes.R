#' `ai_nodes` AI agent failure fault tree nodes dataset
#'
#' An example dataset of nodes in an AI agent failure fault tree.
#' This fault tree models scenarios where an AI agent fails to complete a task
#' due to model errors, prompt issues, API failures, and context limitations.
#'
#' @format ## `ai_nodes`
#' A data frame with 6 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 6) for each node.}
#'   \item{event}{Name of event. `"T"` means top event (AI agent task failure).
#'   `"G3"` means gate. `"AF"` = API failure, `"TO"` = Timeout, `"RL"` = Rate limit,
#'   `"CWE"` = Context window exceeded.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: AI agent task failure
#' - G3 (OR): API failure OR Timeout OR Rate limit
#' - Context window exceeded (direct child of Top)
#'
#' @examples
#' data("ai_nodes")
#' data("ai_edges")
#' library(tidyfault)
#' curate(nodes = ai_nodes, edges = ai_edges)
#'
#' @seealso [ai_edges] for the corresponding edges dataset
"ai_nodes"
