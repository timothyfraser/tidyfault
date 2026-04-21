test_that("minimal OR-top tree: curate through tabulate", {
  tr <- minimal_or_top_tree()
  gates <- curate(tr$nodes, tr$edges)

  expect_named(
    gates,
    c("gate", "type", "class", "n", "set", "items")
  )
  expect_equal(nrow(gates), 1)
  expect_equal(as.character(gates$gate[[1]]), "T")

  eq <- equate(gates)
  expect_type(eq, "character")
  expect_length(eq, 1)
  expect_match(eq, "A")
  expect_match(eq, "B")

  f <- formulate(eq)
  fa <- formalArgs(f)
  expect_equal(sort(fa), c("A", "B"))

  tt <- calculate(f)
  expect_equal(nrow(tt), 4)
  expect_true(all(tt$outcome %in% c(0, 1)))
  top_fail <- subset(tt, A == 1 & B == 1)$outcome
  expect_equal(unique(top_fail), 1)

  cuts_rcpp <- concentrate(gates, method = "mocus_rcpp")
  cuts_r <- concentrate(gates, method = "mocus_r")
  cuts_orig <- concentrate(gates, method = "mocus_original")

  sig_rcpp <- cutset_signature(cuts_rcpp)
  sig_r <- cutset_signature(cuts_r)
  sig_orig <- cutset_signature(cuts_orig)
  expect_equal(sig_rcpp, sig_r)
  expect_equal(sig_rcpp, sig_orig)
  expect_length(cuts_rcpp, 1L)
  expect_equal(cuts_rcpp, cuts_r)
  expect_equal(cuts_rcpp, cuts_orig)

  tab <- tabulate(cuts_rcpp, formula = f, method = "mocus_rcpp")
  expect_named(tab, c("mincut", "cutsets", "failures", "coverage"))
  expect_true(all(tab$coverage >= 0 & tab$coverage <= 1))
  expect_equal(length(unique(tab$failures)), 1)

  tab_q <- tabulate(cuts_rcpp, formula = f, method = "mocus_rcpp", query = TRUE)
  expect_true("query" %in% names(tab_q))
})

test_that("it_security example: gates through calculate", {
  data("it_security_nodes", package = "tidyfault")
  data("it_security_edges", package = "tidyfault")

  gates <- curate(it_security_nodes, it_security_edges)
  expect_true(nrow(gates) >= 1)

  f <- formulate(equate(gates))
  fa <- formalArgs(f)
  tt <- calculate(f)
  expect_equal(nrow(tt), 2^length(fa))
  expect_true(all(tt$outcome %in% c(0, 1)))
})

test_that("simulate small tree: concentrate and tabulate", {
  sim <- simulate(n_gates = 1L, n_basic = 4L, seed = 11L)
  gates <- curate(sim$nodes, sim$edges)
  f <- formulate(equate(gates))

  cuts <- concentrate(gates, method = "mocus_rcpp")
  expect_true(length(cuts) >= 1)

  tab <- tabulate(cuts, formula = f, method = "mocus_rcpp")
  expect_equal(nrow(tab), length(cuts))
  expect_true(all(tab$failures > 0))
})
