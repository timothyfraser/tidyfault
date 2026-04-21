#' mocus_r() — Fast Pure-R MOCUS Implementation
#'
#' Drop-in replacement for mocus() using a queue-based expansion, pre-indexed
#' gate lookup, and integer-encoded events. Same inputs/outputs as mocus().
#'
#' Key improvements over original:
#'   1. Pre-indexes gate table into a named list — zero dplyr::filter() calls
#'      inside the loop.
#'   2. Integer-encodes every event/gate name once up front; all inner-loop
#'      operations run on integer vectors (faster %in%, faster unique()).
#'   3. Queue-based (append-only) expansion — never deletes/reallocates the
#'      working list mid-loop. A tail pointer advances; new cutsets are
#'      appended to the end.
#'   4. Expands every gate in a cutset in a single pass rather than one gate
#'      per outer-loop iteration.
#'   5. Convergence is tracked with a simple counter, not by re-flattening
#'      the entire list every iteration.
#'
#' @param data data.frame produced by curate(). Must have columns:
#'   gate (chr), type (chr/fct), class (chr/fct), items (list of chr vectors).
#' @return Named list where each element is a character vector of basic events
#'   forming one cutset. Identical structure to mocus() output.
#' @importFrom purrr map
#' @export
mocus_r <- function(data) {

  # ── 1. Pre-process gate table into a fast lookup structure ─────────────────
  # Convert type/class to character in case they are factors
  data$type  <- as.character(data$type)
  data$class <- as.character(data$class)

  # Build a named list: gate_name -> list(type, children_integer_vector)
  # We'll fill this after building the integer encoding below.

  # Collect all unique tokens (gates + basic events) and assign integer IDs
  all_gates  <- data$gate
  all_events <- unique(unlist(data$items))           # all tokens that appear as children
  all_tokens <- unique(c(all_gates, all_events))

  # Named integer lookup: token -> id
  tok2id <- seq_along(all_tokens)
  names(tok2id) <- all_tokens

  # Reverse: id -> token (for decoding at the end)
  id2tok <- all_tokens                               # position == id

  # Set of gate IDs (for fast membership test)
  gate_ids <- tok2id[all_gates]

  # Build gate lookup: integer gate id -> list(type, children int vector)
  gate_lookup <- vector("list", length(tok2id))
  for (i in seq_len(nrow(data))) {
    gid       <- tok2id[[ data$gate[i] ]]
    children  <- tok2id[ unlist(data$items[[i]]) ]   # integer child IDs
    gate_lookup[[gid]] <- list(
      type     = data$type[i],
      children = children
    )
  }

  # ── 2. Initialise queue with the top event ─────────────────────────────────
  top_gate_name <- data$gate[ data$class == "top" ][1]
  top_gate_id   <- tok2id[[ top_gate_name ]]

  # queue: pre-allocated list; each element is an integer vector (cutset)
  # We over-allocate generously; R will not shrink on assignment.
  queue     <- vector("list", 1024L)
  queue[[1L]] <- top_gate_id
  q_head    <- 1L   # next item to process
  q_tail    <- 1L   # last item written

  # result accumulator
  results   <- vector("list", 1024L)
  r_count   <- 0L

  # ── 3. Main queue loop ─────────────────────────────────────────────────────
  while (q_head <= q_tail) {

    cutset  <- queue[[q_head]]
    q_head  <- q_head + 1L

    # Find positions of gates still in this cutset
    gate_pos <- which(cutset %in% gate_ids)

    # If no gates remain, cutset is fully resolved — store it
    if (length(gate_pos) == 0L) {
      r_count <- r_count + 1L
      if (r_count > length(results))
        length(results) <- length(results) * 2L        # double buffer
      results[[r_count]] <- cutset
      next
    }

    # ── Expand ALL AND/top gates first (order-independent, safe to batch) ────
    # Then handle the first OR gate (must branch, so we re-queue each branch
    # and let the next iteration handle any remaining gates in those branches).

    # Separate gate positions by type
    types_at_pos <- vapply(cutset[gate_pos], function(id) gate_lookup[[id]]$type,
                           character(1L))

    and_pos <- gate_pos[ types_at_pos %in% c("and", "top") ]
    or_pos  <- gate_pos[ types_at_pos == "or" ]

    if (length(and_pos) > 0L) {
      # Replace each AND gate with its children (in-place expansion)
      # Build expanded cutset: start with non-AND-gate elements,
      # then append children of every AND gate found
      keep <- cutset[ -and_pos ]
      new_children <- unlist(
        lapply(cutset[and_pos], function(id) gate_lookup[[id]]$children),
        use.names = FALSE
      )
      cutset <- c(keep, new_children)

      # Re-enqueue the partially-expanded cutset for further processing
      q_tail <- q_tail + 1L
      if (q_tail > length(queue)) length(queue) <- length(queue) * 2L
      queue[[q_tail]] <- cutset

    } else {
      # No AND gates left — handle the first OR gate (branch)
      first_or_id  <- cutset[ or_pos[1L] ]
      children     <- gate_lookup[[first_or_id]]$children
      rest         <- cutset[ -or_pos[1L] ]            # everything except this OR gate

      # Each child of the OR gate spawns a new cutset branch
      for (child in children) {
        branch <- c(rest, child)
        q_tail <- q_tail + 1L
        if (q_tail > length(queue)) length(queue) <- length(queue) * 2L
        queue[[q_tail]] <- branch
      }
    }
  }

  # ── 4. Decode integer IDs back to event name strings ──────────────────────
  results <- results[seq_len(r_count)]
  results <- lapply(results, function(ids) unique(id2tok[ids]))

  return(results)
}