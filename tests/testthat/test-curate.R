top_tree <- function(child_events, child_types, extra_nodes = NULL, extra_edges = NULL) {
  n <- length(child_events)
  nodes <- tibble::tibble(
    id = seq_len(1L + n),
    event = c("T", child_events),
    type = factor(c("top", child_types), levels = c("top", "and", "or", "not"))
  )
  edges <- tibble::tibble(from = rep(1L, n), to = 1L + seq_len(n))
  list(nodes = dplyr::bind_rows(nodes, extra_nodes), edges = dplyr::bind_rows(edges, extra_edges))
}

test_that("curate() refuses a top event with zero children", {
  tr <- top_tree(character(), character())
  expect_error(curate(tr$nodes, tr$edges), "top event `T`.*0 children")
})

test_that("curate() refuses a top event with three children and names the fix", {
  tr <- top_tree(c("A", "B", "C"), rep("not", 3))
  expect_error(
    curate(tr$nodes, tr$edges),
    "top event `T` must connect to the tree through exactly one gate, but it has 3 children: `A`, `B`, `C`.*Insert an `or` gate.*or an `and` gate.*between `T` and its 3 children"
  )
})

test_that("curate() refuses a top event whose only child is a basic event", {
  tr <- top_tree("A", "not")
  expect_error(
    curate(tr$nodes, tr$edges),
    "only child, `A`, is a basic event.*not a gate.*Insert an `or` or `and` gate between `T` and `A`"
  )
})

test_that("curate() refuses a tree without exactly one top event", {
  tr <- minimal_or_top_tree()
  no_top <- tr$nodes
  no_top$type[1] <- "or"
  expect_error(curate(no_top, tr$edges), "exactly one top event.*found 0")
  two_tops <- tr$nodes
  two_tops$type[3] <- "top"
  expect_error(curate(two_tops, tr$edges), "exactly one top event.*found 2: `T`, `A`")
})

test_that("curate() accepts a top event with one gate child", {
  tr <- minimal_or_top_tree()
  gates <- curate(tr$nodes, tr$edges)
  expect_equal(as.character(gates$gate), c("T", "G1"))
  expect_equal(gates$set, c(" (G1) ", " (A + B) "))
  expect_equal(gates$n, c(1L, 2L))
})

test_that("curate() accepts all six bundled trees", {
  trees <- list(
    c("fakenodes", "fakeedges"), c("db_nodes", "db_edges"),
    c("ai_nodes", "ai_edges"), c("security_nodes", "security_edges"),
    c("it_security_nodes", "it_security_edges"), c("breach_nodes", "breach_edges")
  )
  for (tr in trees) {
    e <- new.env()
    data(list = tr, package = "tidyfault", envir = e)
    gates <- curate(e[[tr[1]]], e[[tr[2]]])
    top <- gates[gates$class == "top", ]
    expect_equal(nrow(top), 1L)
    expect_equal(top$n, 1L)
  }
})
