#' @keywords internal
#' @useDynLib tidyfault, .registration = TRUE
"_PACKAGE"

# Column names used through tidy evaluation (dplyr, ggplot2); not real globals.
utils::globalVariables(c(
  ".", ".data", "cutsets", "edge_id", "event", "failures", "from", "from_x",
  "from_y", "id", "label", "mincut", "outcome", "set", "to", "to_event",
  "to_x", "to_y", "type", "value", "x", "xmax", "xmin", "y", "ymax", "ymin"
))

# Re-export the plot() generic so `tidyfault::plot(x)` keeps working, as it did
# when plot() was an exported function rather than an S3 method.
#' @importFrom graphics plot
#' @export plot
#' @importFrom Rcpp sourceCpp
#' @importFrom stats setNames
NULL
