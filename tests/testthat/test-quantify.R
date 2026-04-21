test_that("quantify_binary_fast matches quantify_binary", {
  data("it_security_nodes", package = "tidyfault")
  data("it_security_edges", package = "tidyfault")

  f <- curate(it_security_nodes, it_security_edges) |>
    equate() |>
    formulate()

  fa <- formalArgs(f)
  set.seed(1)
  n <- 1500L
  batch <- as.data.frame(setNames(lapply(fa, function(.) rbinom(n, 1L, 0.25)), fa))

  expect_equal(
    quantify_binary_fast(f, batch),
    quantify_binary(f, batch)
  )

  v <- setNames(sample(0:1, length(fa), replace = TRUE), fa)
  expect_equal(
    quantify_binary_fast(f, v),
    quantify_binary(f, v)
  )
})

test_that("quantify_prob_fast matches quantify_prob", {
  data("it_security_nodes", package = "tidyfault")
  data("it_security_edges", package = "tidyfault")

  f <- curate(it_security_nodes, it_security_edges) |>
    equate() |>
    formulate()

  fa <- formalArgs(f)
  tt <- calculate(f)

  set.seed(2)
  probs1 <- setNames(runif(length(fa), 0, 0.3), fa)
  expect_equal(
    quantify_prob_fast(f, probs1, truth_table = tt),
    quantify_prob(f, probs1, truth_table = tt)
  )

  set.seed(3)
  n <- 2000L
  batch <- as.data.frame(setNames(lapply(fa, function(.) runif(n, 0, 0.3)), fa))
  expect_equal(
    quantify_prob_fast(f, batch, truth_table = tt),
    quantify_prob(f, batch, truth_table = tt)
  )
})

test_that("quantify minimal OR tree: binary and probability", {
  tr <- minimal_or_top_tree()
  f <- curate(tr$nodes, tr$edges) |>
    equate() |>
    formulate()

  pa <- 0.2
  pb <- 0.3
  expected_p <- pa + pb - pa * pb

  expect_equal(
    quantify(f, c(pa, pb), prob = TRUE),
    expected_p,
    tolerance = 1e-12
  )

  row1 <- tibble::tibble(A = 1L, B = 0L)
  expect_equal(quantify(f, row1), quantify(f, c(A = 1L, B = 0L)))
  expect_true(quantify(f, c(1L, 0L)))
})

test_that("quantify fast flag dispatches consistently", {
  data("it_security_nodes", package = "tidyfault")
  data("it_security_edges", package = "tidyfault")

  f <- curate(it_security_nodes, it_security_edges) |>
    equate() |>
    formulate()

  fa <- formalArgs(f)

  set.seed(4)
  batch_bin <- as.data.frame(setNames(lapply(fa, function(.) rbinom(800L, 1L, 0.25)), fa))
  set.seed(4)
  batch_pr <- as.data.frame(setNames(lapply(fa, function(.) runif(800L, 0, 0.3)), fa))

  expect_equal(
    quantify(f, batch_bin, fast = TRUE),
    quantify(f, batch_bin, fast = FALSE)
  )

  expect_equal(
    quantify(f, batch_pr, prob = TRUE, fast = TRUE),
    quantify(f, batch_pr, prob = TRUE, fast = FALSE)
  )
})
