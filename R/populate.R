#' populate() Function
#'
#' Converts binary outcomes (0/1) to probability outcomes by replacing 1s with
#' event failure probabilities. The output has the same structure as the input
#' binary outcomes, but with probabilities instead of binary values.
#'
#' @param binary_outcomes (Required) Data frame with binary (0/1) event states.
#'   Must have one column per basic event (with event names as column names) and
#'   optionally a `scenario` column. Each row represents one scenario.
#' @param event_probs (Required) Data frame with two columns: `event` (event names)
#'   and `probability` (failure probabilities in \code{[0, 1]}). Must contain probabilities
#'   for all events present in `binary_outcomes`.
#'
#' @return A tibble with the same structure as `binary_outcomes`, where:
#'   \itemize{
#'     \item Values of 1 are replaced with P(event) from `event_probs`
#'     \item Values of 0 remain as 0
#'   }
#'   The `scenario` column (if present) is preserved unchanged.
#'
#' @details This function transforms binary event states by replacing occurrences
#'   (1s) with their corresponding failure probabilities. For each event column,
#'   if the binary value is 1 (event occurred), it is replaced with the failure
#'   probability P(event) from `event_probs`. If the binary value is 0 (event did
#'   not occur), it remains 0. This creates a data frame suitable for probabilistic
#'   evaluation where only occurring events have probability values.
#'
#' @seealso \code{\link{quantify}} for evaluating fault trees with binary or
#'   probabilistic inputs, \code{\link{quantify_prob}} for computing top event
#'   failure probability
#'
#' @keywords fault tree scenario probability
#' @importFrom tibble as_tibble
#' @export
#' @examples
#' library(tidyverse)
#' library(tidyfault)
#'
#' data("db_outcomes_binary")
#' data("db_probs")
#'
#' # Convert binary outcomes to probability outcomes
#' populate(db_outcomes_binary, db_probs)
#'
#' # Compare: binary has 0/1, probability version has P(event) where binary was 1, 0 otherwise
#' db_outcomes_binary
#' populate(db_outcomes_binary, db_probs)
populate = function(binary_outcomes, event_probs) {
  
  # Validate inputs
  if (!is.data.frame(binary_outcomes))
    stop("binary_outcomes must be a data frame.")
  if (!is.data.frame(event_probs))
    stop("event_probs must be a data frame.")
  
  # Check required columns in event_probs
  if (!all(c("event", "probability") %in% colnames(event_probs)))
    stop("event_probs must have columns 'event' and 'probability'.")
  
  # Get event names from binary_outcomes (exclude scenario column if present)
  event_cols = setdiff(colnames(binary_outcomes), "scenario")
  
  # Check that all events in binary_outcomes have probabilities
  missing_probs = setdiff(event_cols, event_probs$event)
  if (length(missing_probs) > 0L)
    stop("event_probs missing probabilities for events: ",
         paste(missing_probs, collapse = ", "))
  
  # Create named vector of probabilities for easy lookup
  prob_vec = setNames(event_probs$probability, event_probs$event)
  
  # Create result data frame with same structure
  result = binary_outcomes %>%
    tibble::as_tibble()
  
  # Replace each event column: 1 -> P(event), 0 stays 0
  for (evt in event_cols) {
    result[[evt]] = ifelse(
      binary_outcomes[[evt]] == 1L,
      prob_vec[evt],
      0
    )
  }
  
  return(result)
}
