test_that("illustrate() tags both/all results with class tidyfault_tree", {
  tr <- minimal_or_top_tree()
  both <- illustrate(tr$nodes, tr$edges, type = "both")
  all <- illustrate(tr$nodes, tr$edges, type = "all")
  expect_s3_class(both, "tidyfault_tree")
  expect_s3_class(all, "tidyfault_tree")
  expect_identical(class(both), c("tidyfault_tree", "list"))
  expect_named(both, c("nodes", "edges", "gates"))
  expect_named(all, c("nodes", "edges", "gates", "pairwise"))
})

test_that("illustrate() nodes and edges stay plain data frames", {
  tr <- minimal_or_top_tree()
  nodes <- illustrate(tr$nodes, tr$edges, type = "nodes")
  edges <- illustrate(tr$nodes, tr$edges, type = "edges")
  expect_false(inherits(nodes, "tidyfault_tree"))
  expect_false(inherits(edges, "tidyfault_tree"))
  expect_s3_class(nodes, "data.frame")
  expect_s3_class(edges, "data.frame")
})

test_that("plot() dispatches to plot.tidyfault_tree and returns a ggplot", {
  tr <- minimal_or_top_tree()
  ill <- illustrate(tr$nodes, tr$edges, type = "both")
  expect_true(is.function(getS3method("plot", "tidyfault_tree")))
  p <- suppressWarnings(plot(ill))
  expect_s3_class(p, "ggplot")
  p_all <- suppressWarnings(plot(illustrate(tr$nodes, tr$edges, type = "all")))
  expect_s3_class(p_all, "ggplot")
})

test_that("the exported plot() is graphics' generic, not a masking function", {
  expect_true("plot" %in% getNamespaceExports("tidyfault"))
  expect_identical(body(tidyfault::plot), body(graphics::plot))
})

test_that("plot() on other objects is base R's", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp)
  on.exit({
    grDevices::dev.off()
    unlink(tmp)
  })
  expect_null(plot(1:3))
  expect_error(plot.tidyfault_tree(list(a = 1)), "illustrate")
})

test_that("plot() defaults use the house colours", {
  f <- formals(getS3method("plot", "tidyfault_tree"))
  expect_equal(
    eval(f$gate_fill),
    c(top = "#382a54", and = "#395d9c", or = "#3eb4ad", "basic event" = "#def5e5")
  )
  expect_identical(f$outline_colour, "#0b0405")
  expect_identical(f$edge_colour, "#b7c1cb")
})

test_that("tidyfault::plot() still works as a namespaced call", {
  tree <- illustrate(fakenodes, fakeedges, type = "both")
  expect_s3_class(tidyfault::plot(tree), "ggplot")
})
