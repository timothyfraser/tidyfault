test_that("gate shape helpers return x,y coordinates", {
  ga <- gate_and(size = 1, res = 12)
  go <- gate_or(size = 1, res = 12)
  gt <- gate_top(size = 2, res = 12)

  expect_true(all(c("x", "y") %in% names(ga)))
  expect_true(all(c("x", "y") %in% names(go)))
  expect_true(all(c("x", "y") %in% names(gt)))
  expect_true(nrow(ga) >= 4)
  expect_true(nrow(go) >= 4)
  expect_true(nrow(gt) >= 4)
})

test_that("get_gate dispatches on gate type", {
  g <- get_gate(0, 0, gate = "and", size = 1, res = 10)
  expect_true(all(c("x", "y") %in% names(g)))
  go <- get_gate(0, 0, gate = "or", size = 1, res = 10)
  expect_true(nrow(g) >= 1)
  expect_true(nrow(go) >= 1)
})

test_that("gate() builds polygons for and/or/top rows", {
  nodes <- tibble::tibble(
    id = 1:3,
    event = c("T", "G1", "G2"),
    type = factor(c("top", "and", "or"), levels = c("top", "and", "or", "not")),
    x = c(0, -1, 1),
    y = c(1, 0, 0)
  )
  polys <- gate(nodes, size = 0.5, res = 16)
  expect_true(all(c("x", "y", "group", "gate") %in% names(polys)))
  expect_true(nrow(polys) >= 12)
})
