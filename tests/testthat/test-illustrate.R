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
