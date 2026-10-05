#' `db_nodes` database system failure fault tree nodes dataset
#'
#' An example dataset of nodes in a database system failure fault tree.
#' This fault tree models scenarios where a database system becomes unavailable
#' due to various failure modes including data corruption, access failures,
#' storage issues, network problems, and hardware failures.
#'
#' @format ## `db_nodes`
#' A data frame with 14 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifier (1 to 14) for each node.}
#'   \item{event}{Name of event. `"T"` means top event (Database system unavailable).
#'   `"G0"`, `"G1"`, etc. mean gates; `"G0"` (id 14) is the top event's one gate. `"DC"` = Data corruption, `"AF"` = Access failure,
#'   `"SF"` = Storage failure, `"BF"` = Backup failure, `"NF"` = Network failure,
#'   `"AUF"` = Authentication failure, `"HF"` = Hardware failure, `"MF"` = Monitoring failure.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#' }
#'
#' @details
#' The fault tree structure:
#' - Top event: Database system unavailable. The top event is not a gate: its
#'   one child is G0.
#' - G0 (OR): G1 OR G2 OR G3 OR G4 (any failure mode makes the database unavailable)
#' - G1 (OR): Data corruption OR Access failure
#' - G2 (AND): Storage failure AND Backup failure
#' - G3 (OR): Network failure OR Authentication failure
#' - G4 (AND): Hardware failure AND Monitoring failure
#'
#' Minimal cut sets: `AF`, `AUF`, `DC`, `NF`, `BF*SF`, `HF*MF`.
#'
#' @examples
#' data("db_nodes")
#' head(db_nodes)
#' dim(db_nodes)
#'
#' @seealso \code{\link[tidyfault]{db_edges}} for the corresponding edges dataset
"db_nodes"
