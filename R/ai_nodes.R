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
#'   `"G3"` is a gate. The basic events are `"AF"` = API failure, `"TO"` = Timeout,
#'   `"RL"` = Rate limit, and `"CWE"` = Context window exceeded.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: AI agent task failure
#' - T (AND): G3 AND Context window exceeded
#' - G3 (OR): API failure OR Timeout OR Rate limit
#'
#' @examples
#' data("ai_nodes")
#' head(ai_nodes)
#' dim(ai_nodes)
#'
#' @seealso \code{\link[tidyfault]{ai_edges}} for the corresponding edges dataset
"ai_nodes"
