#' quantify() Function
#'
#' Unified wrapper function for evaluating fault trees. Evaluates whether the top
#' event occurs (binary evaluation) or computes top event failure probability
#' (probabilistic evaluation) based on the \code{prob} parameter.
#'
#' @param f (Required) Function from \code{formulate()}, with one argument per
#'   basic event. Used to identify event names and to evaluate the fault tree.
#' @param newdata (Required) Data for evaluation. When \code{prob = FALSE}, this
#'   represents binary scenarios (0/1 or TRUE/FALSE) for each basic event. When
#'   \code{prob = TRUE}, this represents failure probabilities (0 to 1) for each
#'   basic event. Can be a tibble/data frame with one column per basic event, a
#'   single vector/list, or (for \code{prob = TRUE}) a matrix. See details below.
#' @param prob (Optional) Logical. If \code{FALSE} (default), performs binary
#'   evaluation using \code{quantify_binary()}. If \code{TRUE}, computes failure
#'   probability using \code{quantify_prob()}.
#'
#' @return A vector of outcomes. The type depends on \code{prob}:
#'   \itemize{
#'     \item If \code{prob = FALSE}: Returns a logical vector (TRUE = system failure,
#'       FALSE = no failure). If \code{newdata} is a data frame with multiple rows,
#'       returns a vector with one outcome per row. If \code{newdata} is a single
#'       scenario, returns a single logical value.
#'     \item If \code{prob = TRUE}: Returns a numeric vector of top event failure
#'       probabilities. If \code{newdata} is a single scenario, returns a single
#'       numeric value. If \code{newdata} has multiple rows, returns a numeric
#'       vector with one probability per scenario.
#'   }
#'   Both modes return vectors in \code{predict()}-style format.
#'
#' @details This function provides a unified interface for both binary and
#'   probabilistic fault tree evaluation:
#'   \itemize{
#'     \item \strong{Binary evaluation} (\code{prob = FALSE}): Uses \code{quantify_binary()}
#'       to evaluate whether the top event occurs given binary event states. Each
#'       event is 0 (did not occur) or 1 (occurred). No probabilities are used.
#'     \item \strong{Probabilistic evaluation} (\code{prob = TRUE}): Uses \code{quantify_prob()}
#'       to compute the top event failure probability from basic event failure
#'       probabilities. Assumes independent basic events and uses the complete
#'       truth table for exact computation (O(2^n) complexity).
#'   }
#'   When \code{prob = FALSE}, \code{newdata} can be:
#'   \itemize{
#'     \item A data frame with one column per basic event (names from \code{formalArgs(f)})
#'     \item A single vector/list (unnamed = positional, or named)
#'     \item Values are logical (TRUE/FALSE) or numeric (0/1)
#'   }
#'   When \code{prob = TRUE}, \code{newdata} can be:
#'   \itemize{
#'     \item A single vector or list (one scenario) with probabilities in \code{[0, 1]}
#'     \item A data frame or matrix with one row per scenario and columns for each
#'       basic event (names must match \code{formalArgs(f)})
#'     \item Unnamed vectors are interpreted in \code{formalArgs(f)} order
#'   }
#'
#' @seealso \code{\link{formulate}} for creating the function, \code{\link{calculate}}
#'   for the full truth table, \code{\link{quantify_binary}} for binary evaluation,
#'   \code{\link{quantify_prob}} for probabilistic evaluation
#'
#' @keywords fault tree evaluation quantification
#' @importFrom rlang enquo eval_tidy quo_get_expr is_symbol as_string call2
#' @importFrom dplyr pick everything
#' @export
#' @examples
#' library(tidyverse)
#' library(tidyfault)
#' library(QCA)
#' data("fakenodes")
#' data("fakeedges")
#'
#' f <- curate(nodes = fakenodes, edges = fakeedges) %>%
#'   equate() %>%
#'   formulate()
#'
#' # Binary evaluation (default): single scenario
#' f %>% quantify(c(T, T, T, F))
#' f %>% quantify(c(TRUE, FALSE, TRUE, FALSE))
#'
#' # Binary evaluation: multiple scenarios
#' scenarios_tbl <- tibble(
#'   A = c(1L, 0L, 1L),
#'   B = c(0L, 1L, 1L),
#'   C = c(1L, 0L, 0L),
#'   D = c(0L, 1L, 1L)
#' )
#' f %>% quantify(scenarios_tbl)
#'
#' # Probabilistic evaluation: single scenario
#' f %>% quantify(c(0.1, 0.2, 0.05, 0.15), prob = TRUE)
#'
#' # Probabilistic evaluation: multiple scenarios
#' probs_df <- as.data.frame(replicate(4, runif(100), simplify = FALSE))
#' names(probs_df) <- formalArgs(f)
#' f %>% quantify(probs_df, prob = TRUE)
quantify = function(f, newdata, prob = FALSE) {
  
  # Capture newdata as a quosure to handle both pipes (%>% and |>)
  # The magrittr pipe evaluates . automatically, but the base pipe doesn't
  newdata_quo = rlang::enquo(newdata)
  parent_env = parent.frame()
  
  # Check if newdata is the . symbol (unevaluated)
  newdata_expr = rlang::quo_get_expr(newdata_quo)
  is_dot = rlang::is_symbol(newdata_expr) && rlang::as_string(newdata_expr) == "."
  
  if (is_dot) {
    # We're dealing with . - need to get the data frame from mutate context
    # The base pipe doesn't evaluate . so we need to get it from the data mask
    # Look for the data mask in the parent frame
    parent_env = parent.frame()
    
    # Try multiple strategies to get the data frame
    newdata = NULL
    
    # Strategy 1: Look for .data in parent frame (dplyr's data mask)
    if (exists(".data", envir = parent_env, inherits = FALSE)) {
      tryCatch({
        data_mask = get(".data", envir = parent_env, inherits = FALSE)
        # Evaluate pick(everything()) in the data mask context
        if (requireNamespace("dplyr", quietly = TRUE)) {
          pick_call = rlang::call2(dplyr::pick, rlang::call2(dplyr::everything))
          newdata = rlang::eval_tidy(pick_call, data = data_mask, env = parent_env)
        }
      }, error = function(e) {})
    }
    
    # Strategy 2: If that didn't work, try to find the data frame in the call stack
    if (is.null(newdata)) {
      # Look for the data argument in the mutate call
      # Walk up the call stack to find mutate's .data argument
      for (i in 1:sys.nframe()) {
        frame_env = sys.frame(i)
        if (exists(".data", envir = frame_env, inherits = FALSE)) {
          tryCatch({
            data_mask = get(".data", envir = frame_env, inherits = FALSE)
            if (requireNamespace("dplyr", quietly = TRUE)) {
              pick_call = rlang::call2(dplyr::pick, rlang::call2(dplyr::everything))
              newdata = rlang::eval_tidy(pick_call, data = data_mask, env = frame_env)
              if (!is.null(newdata)) break
            }
          }, error = function(e) {})
        }
      }
    }
    
    # Strategy 3: Last resort - try standard evaluation (works with magrittr pipe)
    if (is.null(newdata)) {
      newdata = rlang::eval_tidy(newdata_quo, env = parent_env)
    }
  } else {
    # newdata is not . - evaluate normally (works for both pipes)
    newdata = rlang::eval_tidy(newdata_quo, env = parent_env)
  }
  
  if (prob) {
    # Probabilistic evaluation: call quantify_prob()
    quantify_prob(f, newdata = newdata, truth_table = NULL)
  } else {
    # Binary evaluation: call quantify_binary()
    quantify_binary(f, newdata = newdata)
  }
}
