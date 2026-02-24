#' simulate() Function
#'
#' This function *simulates* a fault tree structure with nodes, edges, and basic event probabilities. Generates a valid fault tree with one top event, multiple gates (AND/OR), and basic events, ensuring each gate has at least two input events.
#'
#' @param n_gates (Optional) Integer specifying the desired number of internal gates. Default is `3L`. The actual number of gates may be reduced if `n_basic` is insufficient to provide at least two basic events per gate.
#' @param n_basic (Optional) Integer specifying the number of basic events (leaf nodes) in the fault tree. Default is `8L`. Must be at least 1.
#' @param p_range (Optional) Numeric vector of length 2 specifying the minimum and maximum probability values for basic events. Default is `c(0.01, 0.2)`. Must satisfy `0 < p_range[1] < p_range[2] < 1`.
#' @param seed (Optional) Integer seed for random number generation to ensure reproducibility. Default is `NULL` (no seed set).
#'
#' @return A list with three components:
#'   \itemize{
#'     \item `nodes`: Data frame with columns `id`, `event`, and `type`. Contains one top event (type `"top"`), `n_gates_eff` internal gates (type `"and"` or `"or"`), and `n_basic` basic events (type `"not"`). The `type` column is a factor with levels `c("top", "and", "or", "not")`.
#'     \item `edges`: Data frame with columns `from` and `to`, representing connections between nodes. The top event connects to all gates, and gates connect to their assigned basic events.
#'     \item `prob`: Data frame with columns `event` and `probability`, containing probability values for each basic event, sampled uniformly from `p_range`.
#'   }
#'
#' @details This function generates a valid fault tree structure suitable for use with other `tidyfault` functions:
#'   \itemize{
#'     \item **Gate constraint**: Each gate (AND/OR) is guaranteed to have at least two input events. If `n_basic < 2 * n_gates`, the number of gates is automatically reduced to `floor(n_basic / 2)`.
#'     \item **Degenerate case**: If `n_basic < 2`, no internal gates are created; the top event connects directly to all basic events.
#'     \item **Gate types**: Gate types (AND/OR) are randomly assigned using `sample()`.
#'     \item **Event allocation**: Basic events are allocated to gates such that each gate receives at least two events, with any remaining events randomly distributed.
#'     \item **Event naming**: Top event is named `"T"`, gates are named `"G1"`, `"G2"`, etc., and basic events are named `"E1"`, `"E2"`, etc.
#'   }
#'   The generated fault tree can be used directly with `curate()`, `equate()`, `formulate()`, and other `tidyfault` workflow functions.
#'
#' @seealso \code{\link{curate}} for processing the simulated nodes and edges, \code{\link{illustrate}} for visualizing the generated fault tree structure
#'
#' @keywords simulation fault tree
#' @importFrom stats runif
#' @export
#' @examples
#'
#' # Load dependencies
#' library(tidyfault)
#'
#' # Simulate a fault tree with default parameters
#' sim <- simulate(n_gates = 4L, n_basic = 10L, seed = 12345)
#' sim$nodes
#' sim$edges
#' sim$prob
#'
#' # Use the simulated tree in the tidyfault workflow
#' gates <- curate(nodes = sim$nodes, edges = sim$edges)
#' equation <- equate(gates)
#' formula <- formulate(equation)
#' cutsets <- concentrate(gates)
#'
#' # Simulate a larger tree
#' sim_large <- simulate(n_gates = 10L, n_basic = 25L, 
#'                      p_range = c(0.05, 0.3), seed = 42)
#'
simulate = function(n_gates = 3L,
                    n_basic = 8L,
                    p_range = c(0.01, 0.2),
                    seed = NULL) {

  if (!is.null(seed)) {
    set.seed(seed)
  }

  n_gates <- as.integer(n_gates)
  n_basic <- as.integer(n_basic)

  if (length(p_range) != 2L || any(!is.finite(p_range))) {
    stop("p_range must be a numeric vector of length 2 with finite values.")
  }
  if (p_range[1] <= 0 || p_range[2] >= 1 || p_range[1] >= p_range[2]) {
    stop("p_range must satisfy 0 < p_range[1] < p_range[2] < 1.")
  }
  if (is.na(n_gates) || n_gates < 1L) {
    stop("n_gates must be an integer >= 1.")
  }
  if (is.na(n_basic) || n_basic < 1L) {
    stop("n_basic must be an integer >= 1.")
  }

  # Maximum number of gates such that each can have at least two basic-event inputs
  max_gates_possible <- n_basic %/% 2L
  if (max_gates_possible < 1L) {
    n_gates_eff <- 0L
  } else {
    n_gates_eff <- min(n_gates, max_gates_possible)
  }

  if (n_gates_eff == 0L) {
    # Degenerate case: no internal gates, just top event and basic events
    total_nodes <- 1L + n_basic

    id <- seq_len(total_nodes)
    type <- character(total_nodes)
    event <- character(total_nodes)

    type[1] <- "top"
    event[1] <- "T"

    basic_ids <- 1L + seq_len(n_basic)
    type[basic_ids] <- "not"
    event[basic_ids] <- paste0("E", seq_len(n_basic))

    nodes <- data.frame(
      id = id,
      event = event,
      type = factor(type, levels = c("top", "and", "or", "not")),
      stringsAsFactors = FALSE
    )

    edges <- data.frame(
      from = rep(1L, n_basic),
      to = basic_ids,
      stringsAsFactors = FALSE
    )

    prob <- data.frame(
      event = event[basic_ids],
      probability = stats::runif(n_basic, min = p_range[1], max = p_range[2]),
      stringsAsFactors = FALSE
    )

    return(list(nodes = nodes, edges = edges, prob = prob))
  }

  # Total nodes: 1 top + n_gates_eff internal gates + n_basic basic events
  total_nodes <- 1L + n_gates_eff + n_basic

  id <- seq_len(total_nodes)
  type <- character(total_nodes)
  event <- character(total_nodes)

  # Top event
  type[1] <- "top"
  event[1] <- "T"

  # Gates (AND / OR)
  gate_ids <- 1L + seq_len(n_gates_eff)
  type[gate_ids] <- sample(c("and", "or"), size = n_gates_eff, replace = TRUE)
  event[gate_ids] <- paste0("G", seq_len(n_gates_eff))

  # Basic events (NOT)
  basic_ids <- max(gate_ids) + seq_len(n_basic)
  type[basic_ids] <- "not"
  event[basic_ids] <- paste0("E", seq_len(n_basic))

  nodes <- data.frame(
    id = id,
    event = event,
    type = factor(type, levels = c("top", "and", "or", "not")),
    stringsAsFactors = FALSE
  )

  # Allocate each basic event to a gate, ensuring at least two basic children per gate
  assignment <- integer(n_basic)
  basic_index <- 1L
  for (g in seq_len(n_gates_eff)) {
    assignment[basic_index:(basic_index + 1L)] <- g
    basic_index <- basic_index + 2L
  }
  if (basic_index <= n_basic) {
    remaining <- basic_index:n_basic
    assignment[remaining] <- sample.int(n_gates_eff, length(remaining), replace = TRUE)
  }

  # Edges: top -> each gate
  edges_from <- rep(1L, n_gates_eff)
  edges_to <- gate_ids

  # Edges: gate -> basic events
  edges_from <- c(edges_from, gate_ids[assignment])
  edges_to <- c(edges_to, basic_ids)

  edges <- data.frame(
    from = edges_from,
    to = edges_to,
    stringsAsFactors = FALSE
  )

  # Probabilities only for basic events (leaf nodes)
  prob <- data.frame(
    event = event[basic_ids],
    probability = stats::runif(n_basic, min = p_range[1], max = p_range[2]),
    stringsAsFactors = FALSE
  )

  list(nodes = nodes, edges = edges, prob = prob)
}
