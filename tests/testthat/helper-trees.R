# The smallest valid tree: the top event T hands off to one OR gate G1 over
# basic events A and B (the top event is not a gate, SPEC TF4.2).
minimal_or_top_tree <- function() {
  nodes <- tibble::tibble(
    id = 1:4,
    event = c("T", "G1", "A", "B"),
    type = factor(c("top", "or", "not", "not"), levels = c("top", "and", "or", "not"))
  )
  edges <- tibble::tibble(
    from = c(1L, 2L, 2L),
    to = c(2L, 3L, 4L)
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

# The IT security tree as a formula, and its failure rates (per hour) as one
# row, one column per basic event: shared by the quantify_if/_when/_ci tests.
it_security_f <- function() {
  curate(it_security_nodes, it_security_edges) %>% equate() %>% formulate()
}

it_security_rates <- function() {
  r <- it_security_outcomes_rates
  tibble::as_tibble(as.list(stats::setNames(r$lambda, r$event)))
}
