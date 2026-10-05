test_that("stipulate() builds one row per scenario with the baseline first", {
  rates = tibble::tibble(A = 1, B = 2, C = 4)
  out = stipulate(rates, "Fix A" = c(A = 0.1), "Fix A and B" = c(A = 0.1, B = 0.5))

  expect_named(out, c("scenario", "A", "B", "C"))
  expect_s3_class(out$scenario, "factor")
  expect_equal(levels(out$scenario), c("Neither", "Fix A", "Fix A and B"))
  expect_equal(as.character(out$scenario), levels(out$scenario))
  expect_equal(out$A, c(1, 0.1, 0.1))
  expect_equal(out$B, c(2, 2, 1))
  expect_equal(out$C, c(4, 4, 4))
})

test_that("stipulate() renames or drops the baseline and takes vectors", {
  out = stipulate(c(A = 1, B = 2), fix = c(B = 0), baseline = "As is")
  expect_equal(levels(out$scenario), c("As is", "fix"))
  expect_equal(out$B, c(2, 0))

  out = stipulate(c(A = 1, B = 2), fix = c(B = 0), baseline = NULL)
  expect_equal(nrow(out), 1)
  expect_equal(levels(out$scenario), "fix")
})

test_that("stipulate() refuses bad scenarios with actionable errors", {
  rates = tibble::tibble(A = 1, B = 2)
  expect_error(stipulate(rates, "Fix" = c(Z = 0.1)), "names events not in `data`: Z")
  expect_error(stipulate(rates), "at least one scenario")
  expect_error(stipulate(rates, c(A = 0.1)), "needs a name")
  expect_error(stipulate(rates, "Fix" = 0.1), "named numeric vector")
  expect_error(stipulate(rates, "Fix" = c(A = -1)), "non-negative")
  expect_error(stipulate(rates, "Neither" = c(A = 0.1)), "unique")
  expect_error(stipulate(rbind(rates, rates), "Fix" = c(A = 0.1)), "exactly one row")
})
