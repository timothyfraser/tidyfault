mocus_list_signature <- function(lst) {
  sig <- vapply(lst, function(x) paste(sort(unique(x)), collapse = "*"), character(1))
  sort(sig)
}

test_that("mocus default matches mocus_rcpp", {
  tr <- minimal_or_top_tree()
  gates <- curate(tr$nodes, tr$edges)
  expect_equal(mocus_list_signature(mocus(gates)), mocus_list_signature(mocus_rcpp(gates)))
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
