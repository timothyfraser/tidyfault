test_that("quantify_when() crosses scenarios with time, baseline first", {
  f = it_security_f()
  rates = it_security_rates()
  out = quantify_when(f, rates, "Fix A" = c(MN = 0.1), "Fix A and B" = c(MN = 0.1, PO = 0.1),
                      time = c(0, 8760, 87600), ci = FALSE)

  expect_named(out, c("scenario", "time", "p_top", "reliability"))
  expect_s3_class(out$scenario, "factor")
  expect_equal(levels(out$scenario), c("Neither", "Fix A", "Fix A and B"))
  expect_equal(as.character(out$scenario), rep(levels(out$scenario), each = 3))
  expect_equal(out$time, rep(c(0, 8760, 87600), times = 3))
  expect_equal(out$p_top[out$time == 0], c(0, 0, 0))
  expect_equal(out$reliability, 1 - out$p_top)

  both = rates
  both$MN = both$MN * 0.1
  both$PO = both$PO * 0.1
  expect_equal(out$p_top[9], quantify(f, stats::pexp(87600, unlist(both)), prob = TRUE))
  expect_equal(out$p_top[2], quantify(f, stats::pexp(8760, unlist(rates)), prob = TRUE))
  expect_true(all(diff(out$p_top[out$scenario == "Neither"]) > 0))
})

test_that("quantify_when(ci = TRUE) matches quantify_ci() on the same draws", {
  f = it_security_f()
  rates = it_security_rates()
  out = quantify_when(f, rates, "Fix A" = c(MN = 0.1), time = c(8760, 17520),
                      n = 200, seed = 5)
  expect_named(out, c("scenario", "time", "p_top", "lower", "upper", "reliability"))
  expect_equal(out$reliability, 1 - out$p_top)

  fixed = rates
  fixed$MN = fixed$MN * 0.1
  ref = quantify_ci(f, fixed, time = c(8760, 17520), n = 200, seed = 5)
  expect_equal(out$p_top[3:4], ref$p_top)
  expect_equal(out$lower[3:4], ref$lower)
  expect_equal(out$upper[3:4], ref$upper)
  expect_true(all(out$p_top[3:4] < out$p_top[1:2]))
})

test_that("quantify_when() renames or drops the baseline and takes vectors", {
  f = it_security_f()
  rates = unlist(it_security_rates())
  out = quantify_when(f, rates, fix = c(PO = 0), baseline = "As is", time = 8760, ci = FALSE)
  expect_equal(levels(out$scenario), c("As is", "fix"))

  out = quantify_when(f, rates, fix = c(PO = 0), baseline = NULL, time = 8760, ci = FALSE)
  expect_equal(nrow(out), 1)
  expect_equal(levels(out$scenario), "fix")
})

test_that("quantify_when() refuses bad scenarios with actionable errors", {
  f = it_security_f()
  rates = it_security_rates()
  expect_error(quantify_when(f, rates, "Fix" = c(Z = 0.1)), "not basic events of `f`: Z")
  expect_error(quantify_when(f, rates), "at least one scenario")
  expect_error(quantify_when(f, rates, c(MN = 0.1)), "needs a name")
  expect_error(quantify_when(f, rates, "Fix" = 0.1), "named numeric vector")
  expect_error(quantify_when(f, rates, "Fix" = c(MN = -1)), "non-negative")
  expect_error(quantify_when(f, rates, "Neither" = c(MN = 0.1)), "unique")
  expect_error(quantify_when(f, rbind(rates, rates), "Fix" = c(MN = 0.1)), "exactly one row")
  expect_error(quantify_when(f, rates[, -1], "Fix" = c(MN = 0.1)), "Missing: DA")
  expect_error(quantify_when(f, rates, "Fix" = c(MN = 0.1), time = -1), "non-negative")
  expect_error(quantify_when(f, rates, "Fix" = c(MN = 0.1), ci = "yes"), "TRUE or FALSE")
})
