#' `it_security_data` Binary scenario data for IT security fault tree
#'
#' A small tibble of binary (0/1) scenarios for the 10 basic events in the
#' IT security fault tree (sensitive data leaves the organization). Used with
#' \code{quantify()} to evaluate whether the top event occurs under each scenario.
#'
#' @format ## `it_security_data`
#' A data frame with 3 rows and 10 columns. Each column is a basic event (two-letter code);
#' 1 indicates the event occurred (condition true), 0 otherwise.
#' \describe{
#'   \item{DA}{No controls to stop data from being copied or sent out.}
#'   \item{EP}{User had more access than needed for their job.}
#'   \item{IM}{Employee did it on purpose or account was taken over.}
#'   \item{LR}{Passwords exposed in a breach or reused elsewhere.}
#'   \item{MN}{No second login step (e.g. code on phone) required.}
#'   \item{PO}{Security updates not applied on time.}
#'   \item{PC}{Passwords obtained via fake email or link (phishing).}
#'   \item{PM}{Admin-level access set up incorrectly.}
#'   \item{VS}{System has a known security hole.}
#'   \item{WB}{Web traffic filter missing or attacker got around it.}
#' }
#'
#' @examples
#' data("it_security_nodes")
#' data("it_security_edges")
#' data("it_security_data")
#' library(tidyfault)
#' gates <- curate(nodes = it_security_nodes, edges = it_security_edges)
#' f <- equate(gates) %>% formulate()
#' quantify(f, newdata = it_security_data)
#'
#' @seealso \code{\link[tidyfault]{it_security_nodes}}, \code{\link[tidyfault]{quantify}}
"it_security_data"
