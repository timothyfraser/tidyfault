#' `db_nodes` database system failure fault tree nodes dataset
#'
#' An example dataset of nodes in a database system failure fault tree.
#' This fault tree models scenarios where a database system becomes unavailable
#' due to various failure modes including data corruption, access failures,
#' storage issues, network problems, and hardware failures.
#'
#' @format ## `db_nodes`
#' A data frame with 13 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 13) for each node.}
#'   \item{event}{Name of event. `"T"` means top event (Database system unavailable).
#'   `"G1"`, `"G2"`, etc. mean gates. `"DC"` = Data corruption, `"AF"` = Access failure,
#'   `"SF"` = Storage failure, `"BF"` = Backup failure, `"NF"` = Network failure,
#'   `"AUF"` = Authentication failure, `"HF"` = Hardware failure, `"MF"` = Monitoring failure.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: Database system unavailable
#' - G1 (OR): Data corruption OR Access failure
#' - G2 (AND): Storage failure AND Backup failure
#' - G3 (OR): Network failure OR Authentication failure
#' - G4 (AND): Hardware failure AND Monitoring failure
#'
#' @examples
#' data("db_nodes")
#' data("db_edges")
#' library(tidyfault)
#' curate(nodes = db_nodes, edges = db_edges)
#'
#' @seealso \code{\link[tidyfault]{db_edges}} for the corresponding edges dataset
"db_nodes"
