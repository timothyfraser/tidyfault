#' `ai_nodes` AI agent failure fault tree nodes dataset
#'
#' An example dataset of nodes in an AI agent failure fault tree.
#' This fault tree models scenarios where an AI agent fails to complete a task
#' due to model errors, prompt issues, API failures, and context limitations.
#'
#' @format ## `ai_nodes`
#' A data frame with 14 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 14) for each node.}
#'   \item{event}{Name of event. `"T"` means top event (AI agent task failure).
#'   `"G1"`, `"G2"`, etc. mean gates. `"ME"` = Model error, `"PE"` = Prompt error,
#'   `"TDI"` = Training data issue, `"VF"` = Validation failure, `"AF"` = API failure,
#'   `"TO"` = Timeout, `"RL"` = Rate limit, `"CWE"` = Context window exceeded, `"NFB"` = No fallback.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: AI agent task failure
#' - G1 (OR): Model error OR Prompt error
#' - G2 (AND): Training data issue AND Validation failure
#' - G3 (OR): API failure OR Timeout OR Rate limit
#' - G4 (AND): Context window exceeded AND No fallback
#'
#' @examples
#' data("ai_nodes")
#' data("ai_edges")
#' library(tidyfault)
#' curate(nodes = ai_nodes, edges = ai_edges)
#'
#' @seealso \code{\link[tidyfault]{ai_edges}} for the corresponding edges dataset
"ai_nodes"
