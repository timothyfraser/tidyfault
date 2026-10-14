test_that("illustrate returns ggplot-ready components", {
  tr <- minimal_or_top_tree()
  res <- illustrate(tr$nodes, tr$edges, type = "both")

  expect_type(res, "list")
  expect_named(res, c("nodes", "edges", "gates"))

  expect_true(all(c("x", "y") %in% names(res$nodes)))
  expect_true(nrow(res$nodes) >= 1)

  expect_true(all(c("x", "y") %in% names(res$edges)))
  expect_true(nrow(res$edges) >= 1)

  expect_true(all(c("x", "y") %in% names(res$gates)))
  expect_true(nrow(res$gates) >= 1)
})

test_that("illustrate() lays out the tree with igraph and returns a tibble", {
  res <- illustrate(db_nodes, db_edges, type = "nodes")
  g <- tidygraph::tbl_graph(db_nodes, db_edges, directed = TRUE, node_key = "id")
  xy <- igraph::layout_as_tree(g)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("x", "y", names(db_nodes)))
  expect_equal(res$x, xy[, 1])
  expect_equal(res$y, xy[, 2])
})

test_that("illustrate() resolves short igraph layout names", {
  g <- tidygraph::tbl_graph(db_nodes, db_edges, directed = TRUE, node_key = "id")
  res <- illustrate(db_nodes, db_edges, type = "nodes", layout = "sugiyama")
  expect_equal(res$y, igraph::layout_with_sugiyama(g)$layout[, 2])
})
