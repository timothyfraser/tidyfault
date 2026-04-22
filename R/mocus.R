#' mocus() Function
#'
#' This function *simplifies* a `data.frame` of gates and their sets identified
#' by `curate()`, generating each cutset in the fault tree using the MOCUS
#' (Method of Obtaining Cutsets) algorithm.
#'
#' @param data (Required) data.frame containing gates and their sets, outputted
#'   by `curate()`. Must contain columns `gate`, `type`, `class`, and `items`
#'   (list column of event vectors). The data.frame should have at least one
#'   row with `class == "top"` representing the top event.
#' @param method (Optional) Character string specifying which implementation to
#'   run. Default is `"mocus_rcpp"`. Supported values are `"mocus_rcpp"`,
#'   `"mocus_r"`, and `"mocus_original"` (same labels as `concentrate()` and
#'   `tabulate()`).
#'
#' @return A list where each element is a character vector representing a cutset
#'   (a set of basic events that can cause system failure). Each cutset vector
#'   contains the names of basic events. The list includes all cutsets found in
#'   the fault tree, not just minimum cutsets. Duplicate events within each
#'   cutset are removed (each event appears only once per cutset).
#'
#' @details This function implements the MOCUS (Method of Obtaining Cutsets)
#'   algorithm, which systematically expands gates in a fault tree to identify
#'   all cutsets. The algorithm works as follows:
#'   \itemize{
#'     \item \strong{Initialization}: Starts with the top event as the first cutset
#'     \item \strong{Iterative Expansion}: For each cutset containing gate references:
#'       \itemize{
#'         \item Identifies gates that appear in the current cutset
#'         \item For AND gates: Replaces the gate with all its input events (events are combined)
#'         \item For OR gates: Creates separate cutsets for each input path (events are alternatives)
#'         \item Removes the expanded gate from consideration
#'       }
#'     \item \strong{Convergence}: Continues until no gates remain in any cutset (only basic events)
#'     \item \strong{Deduplication}: Removes duplicate events within each cutset
#'   }
#'   The algorithm handles nested gate structures by repeatedly expanding gates
#'   until all references are resolved. AND gates represent events that must all
#'   occur together, while OR gates represent alternative failure paths. The
#'   result includes all possible cutsets, which can then be minimized using
#'   boolean algebra (e.g., via `concentrate()` with `method = "mocus_original"`).
#'
#'   The default method (`"mocus_rcpp"`) uses the compiled implementation for
#'   speed. Use `"mocus_r"` for a pure-R queue-based variant, or `"mocus_original"`
#'   for the historical R loop used in early versions of the package.
#'
#' @seealso [curate()] for preparing the gates data.frame, [concentrate()] for
#'   finding minimum cutsets from the generated cutsets, [mocus_rcpp()],
#'   [mocus_r()]
#'
#' @keywords boolean cutset fault tree
#' @importFrom dplyr %>% filter
#' @importFrom purrr map
#' @export
mocus <- function(data, method = c("mocus_rcpp", "mocus_r", "mocus_original")) {
  method <- match.arg(method)
  switch(
    method,
    mocus_rcpp = mocus_rcpp(data),
    mocus_r = mocus_r(data),
    mocus_original = mocus_original_impl(data)
  )
}

#' Original R-loop MOCUS (internal)
#'
#' @param data Gates data.frame from [curate()].
#' @return Same structure as [mocus_rcpp()].
#' @noRd
mocus_original_impl <- function(data) {
  m <- list()

  m[[1]] <- data %>%
    filter(class == "top") %>%
    with(gate)

  continue <- TRUE
  system.time(
    while (continue) {
      for (k in seq_along(m)) {
        isgate <- m[[k]] %in% data$gate

        if (sum(isgate) > 0) {
          mygates <- m[[k]][isgate]
          holder <- list()

          for (j in 1) {
            jgate <- data %>%
              filter(gate == mygates[j])

            myset <- jgate$items %>% unlist()
            mytype <- jgate$type
            isgatej <- m[[k]] %in% mygates[j]
            notgatej <- m[[k]][!isgatej]

            if (mytype == "and" | mytype == "top") {
              if (length(notgatej) > 0) {
                holder <- notgatej %>% matrix(ncol = length(.)) %>%
                  c(myset) %>% list(.)
              } else {
                holder <- list(myset)
              }
            } else if (mytype == "or") {
              holder <- mapply(FUN = rep, notgatej, length(myset)) %>%
                cbind(myset) %>%
                unname() %>%
                split(seq_len(nrow(.))) %>%
                unname()
            }

            m[k] <- NULL
            m <- c(m, holder)
          }
        }
      }

      remaining <- sum(unlist(m) %in% data$gate)
      continue <- remaining > 0
    }
  )

  m <- m %>%
    map(~ unique(.))

  m
}
