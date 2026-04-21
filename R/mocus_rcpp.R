#' @name mocus_rcpp
#' @title `mocus_rcpp()` - Rcpp-Backed MOCUS Implementation
#' @description
#' Drop-in replacement for mocus() that delegates the inner expansion loop to
#' compiled C++ via Rcpp. The R layer handles encoding/decoding; C++ handles
#' the queue-based gate expansion with zero R-level allocation in the hot path.
#'
#' @details
#' Encoding strategy:
#'   - Every unique token (gate name or basic event name) is mapped to a
#'     positive integer ID once. All C++ operations work on ints.
#'   - Gate children are stored in a flat integer vector with per-gate start/end
#'     offsets, giving cache-friendly sequential access.
#'   - After C++ returns a list of integer-vector cutsets, R decodes them back
#'     to character vectors in one vectorised pass.
#'
#' @param data data.frame produced by curate(). Must have columns:
#'   gate (chr), type (chr/fct), class (chr/fct), items (list of chr vectors).
#' @return Named list where each element is a character vector of basic events
#'   forming one cutset. Identical structure to mocus() / mocus_r() output.
#' @export
mocus_rcpp <- function(data) {
  if (!exists("mocus_cpp_impl", mode = "function")) {
    stop(
      "mocus_cpp_impl() is not available. ",
      "Reinstall tidyfault so compiled Rcpp routines are registered."
    )
  }

  # 1. Normalise input
  data$type <- as.character(data$type)
  data$class <- as.character(data$class)

  # 2. Build integer encoding
  all_tokens <- unique(c(data$gate, unlist(data$items)))
  tok2id <- seq_along(all_tokens)
  names(tok2id) <- all_tokens
  id2tok <- all_tokens

  # 3. Encode gate table
  n <- nrow(data)
  gate_ids <- tok2id[data$gate]

  # type encoding: 0 = and/top, 1 = or
  gate_types <- ifelse(data$type == "or", 1L, 0L)

  # Flatten children into a single vector with start/end offsets
  children_list <- lapply(data$items, function(x) tok2id[unlist(x)])
  child_lengths <- lengths(children_list)
  child_flat <- unlist(children_list, use.names = FALSE)
  child_end <- cumsum(child_lengths)
  child_start <- c(0L, child_end[-n])
  child_start_0 <- child_start
  child_end_0 <- child_end

  # 4. Top gate ID
  top_id <- tok2id[[data$gate[data$class == "top"][1]]]

  # 5. Call C++
  impl <- get("mocus_cpp_impl", mode = "function", inherits = TRUE)

  raw <- impl(
    gate_ids = gate_ids,
    gate_types = gate_types,
    child_flat = child_flat,
    child_start = child_start_0,
    child_end = child_end_0,
    top_id = top_id
  )

  # 6. Decode integer IDs -> event name strings
  lapply(raw, function(ids) id2tok[ids])
}

#' @rdname mocus_rcpp
#' @export
mocus_cpp <- function(data) {
  mocus_rcpp(data)
}
