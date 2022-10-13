#' `fakenodes` fault tree nodes dataset
#'
#' An example dataset of nodes in a demonstration fault tree.
#'
#' @format ## `fakenodes`
#' A data frame with 12 rows and 3 columns:
#' \describe{
#'   \item{id}{Unique identifer (1 to N) for each node. Some events occur multiple times, but each time they have a unique `id`}
#'   \item{event}{name of event. `"T"` mean top event. `"G1"`, `"G2"`, etc. mean gates.}
#'   \item{type}{`factor` classification as "top", "and", "or", or "not" (meaning "not" a gate).}
#'   ...
#' }
"fakenodes"
