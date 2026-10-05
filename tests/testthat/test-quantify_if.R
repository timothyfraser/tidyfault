test_that("quantify_if() cuts each rate in turn and matches quantify()", {
  f = it_security_f()
  rates = it_security_rates()
  out = quantify_if(f, rates, cut = 0.05, time = 8760)

  expect_named(out, c("event", "p_top", "baseline", "change", "pct_change"))
  expect_setequal(out$event, formalArgs(f))
  expect_false(is.unsorted(out$pct_change))

  probs = stats::pexp(8760, unlist(rates))
  expect_equal(out$baseline, rep(quantify(f, probs, prob = TRUE), nrow(out)))

  mn = rates
  mn$MN = mn$MN * 0.95
  expect_equal(out$p_top[out$event == "MN"],
               quantify(f, stats::pexp(8760, unlist(mn)), prob = TRUE))
  expect_equal(out$change, out$p_top - out$baseline)
  expect_equal(out$pct_change, 100 * (out$p_top / out$baseline - 1))
  expect_true(all(out$change < 0))
})

test_that("quantify_if() works on probabilities, subsets and vectors", {
  f = it_security_f()
  out = quantify_if(f, it_security_probs, cut = 1, events = c("PO", "MN"))
  expect_equal(nrow(out), 2)
  expect_equal(out$event, c("MN", "PO"))

  p = unlist(it_security_probs)
  p0 = p
  p0["PO"] = 0
  expect_equal(out$p_top[out$event == "PO"], quantify(f, p0, prob = TRUE))

  expect_equal(quantify_if(f, p, cut = 1, events = c("PO", "MN")), out)

  extra = dplyr::mutate(it_security_probs, label = "x")
  expect_equal(quantify_if(f, extra, cut = 1, events = c("PO", "MN")), out)
})

test_that("quantify_if() refuses bad input with actionable errors", {
  f = it_security_f()
  rates = it_security_rates()
  expect_error(quantify_if(f, rates[, -1], time = 8760), "Missing: DA")
  expect_error(quantify_if(f, rbind(rates, rates), time = 8760), "exactly one row")
  expect_error(quantify_if(f, rates, cut = 0, time = 8760), "in \\(0, 1\\]")
  expect_error(quantify_if(f, rates, cut = 1.5, time = 8760), "in \\(0, 1\\]")
  expect_error(quantify_if(f, rates, time = 8760, events = "XX"), "not basic events of `f`: XX")
  expect_error(quantify_if(f, rates, time = -1), "single positive number")
  expect_error(quantify_if(f, rates * 1e5), "If these are failure rates, pass `time`")
  expect_error(quantify_if(f, "MN"), "one-row data frame or a named numeric vector")
})

test_that("quantify_if(ci = TRUE) adds an interval from quantify_ci()", {
  f = it_security_f()
  rates = it_security_rates()
  out = quantify_if(f, rates, cut = 0.9, time = 8760, events = c("MN", "PO"),
                    ci = TRUE, n = 300, seed = 4)
  exact = quantify_if(f, rates, cut = 0.9, time = 8760, events = c("MN", "PO"))

  expect_named(out, c("event", "p_top", "baseline", "change", "pct_change", "lower", "upper"))
  expect_equal(out[names(exact)], exact)
  expect_true(all(out$lower < out$p_top & out$p_top < out$upper))

  mn = rates
  mn$MN = mn$MN * 0.1
  ref = quantify_ci(f, mn, n = 300, time = 8760, seed = 4)
  expect_equal(out$lower[out$event == "MN"], ref$lower)
  expect_equal(out$upper[out$event == "MN"], ref$upper)

  expect_error(quantify_if(f, rates, time = 8760, ci = NA), "TRUE or FALSE")
  expect_error(quantify_if(f, rates, time = 8760, ci = TRUE, level = 1), "level")
})
