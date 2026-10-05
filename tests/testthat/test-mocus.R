mocus_list_signature <- function(lst) {
  sig <- vapply(lst, function(x) paste(sort(unique(x)), collapse = "*"), character(1))
  sort(sig)
}

test_that("mocus default matches mocus_rcpp", {
  tr <- minimal_or_top_tree()
  gates <- curate(tr$nodes, tr$edges)
  expect_equal(mocus_list_signature(mocus(gates)), mocus_list_signature(mocus_rcpp(gates)))
})

test_that("every MOCUS method expands the top event's OR gate into A and B", {
  tr <- minimal_or_top_tree()
  gates <- curate(tr$nodes, tr$edges)
  for (m in c("mocus_rcpp", "mocus_r", "mocus_original")) {
    expect_equal(mocus_list_signature(mocus(gates, method = m)), c("A", "B"))
  }
  expect_equal(concentrate(gates), c("A", "B"))
})

test_that("MOCUS refuses a hand-built gate table whose top has two children", {
  gates <- tibble::tibble(
    gate = "T", type = "top", class = factor("top", levels = c("top", "gate")),
    n = 2L, set = " (A + B) ", items = list(c("A", "B"))
  )
  for (m in c("mocus_rcpp", "mocus_r", "mocus_original")) {
    expect_error(mocus(gates, method = m), "top event `T` must have exactly one child")
  }
})

test_that("mocus methods agree on it_security tree", {
  data("it_security_nodes", package = "tidyfault")
  data("it_security_edges", package = "tidyfault")
  gates <- curate(it_security_nodes, it_security_edges)

  sig_default <- mocus_list_signature(mocus(gates))
  sig_rcpp <- mocus_list_signature(mocus_rcpp(gates))
  sig_r <- mocus_list_signature(mocus_r(gates))
  sig_orig <- mocus_list_signature(mocus(gates, method = "mocus_original"))

  expect_equal(sig_default, sig_rcpp)
  expect_equal(sig_default, sig_r)
  expect_equal(sig_default, sig_orig)
})
