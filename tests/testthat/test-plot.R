test_that("plot.tidyfault returns a ggplot object", {
  tr <- minimal_or_top_tree()
  ill <- illustrate(tr$nodes, tr$edges, type = "both")
  p <- suppressWarnings(plot(ill))
  expect_s3_class(p, "ggplot")
})
