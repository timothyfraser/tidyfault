minimal_or_top_tree <- function() {
  nodes <- tibble::tibble(
    id = 1:3,
    event = c("T", "A", "B"),
    type = factor(c("top", "not", "not"), levels = c("top", "and", "or", "not"))
  )
  edges <- tibble::tibble(
    from = c(1L, 1L),
    to = c(2L, 3L)
  )
  list(nodes = nodes, edges = edges)
}

strip_outer_parens <- function(s) {
  s <- trimws(s)
  while (
    nzchar(s) &&
      substr(s, 1L, 1L) == "(" &&
      substr(s, nchar(s), nchar(s)) == ")"
  ) {
    s <- trimws(substr(s, 2L, nchar(s) - 1L))
  }
  trimws(s)
}

normalize_cutset_token <- function(s) {
  strip_outer_parens(trimws(s))
}

cutset_signature <- function(cuts) {
  sig <- vapply(cuts, function(one) {
    inner <- normalize_cutset_token(one)
    parts <- strsplit(inner, "\\s*\\*\\s*", perl = TRUE)[[1]]
    paste(sort(trimws(parts)), collapse = "*")
  }, character(1))
  sort(unique(sig))
}
