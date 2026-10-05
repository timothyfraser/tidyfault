test_that("quantify_ci() summarizes the draws: median and central interval", {
  f = it_security_f()
  rates = it_security_rates()
  out = quantify_ci(f, rates, time = 8760, n = 500, seed = 1)
  long = quantify_ci(f, rates, time = 8760, n = 500, seed = 1, draws = TRUE)

  expect_named(out, c("time", "p_top", "lower", "upper"))
  expect_equal(nrow(out), 1)
  expect_named(long, c("time", "sim", "p_top"))
  expect_equal(long$sim, 1:500)
  expect_equal(out$p_top, stats::median(long$p_top))
  expect_equal(out$lower, unname(stats::quantile(long$p_top, 0.05)))
  expect_equal(out$upper, unname(stats::quantile(long$p_top, 0.95)))

  wide = quantify_ci(f, rates, time = 8760, n = 500, seed = 1, level = 0.5)
  expect_true(wide$lower > out$lower && wide$upper < out$upper)

  point = quantify(f, stats::pexp(8760, unlist(rates)), prob = TRUE)
  expect_equal(quantify_ci(f, rates, time = 8760, n = 3, cv = 0)$p_top, point)
  expect_equal(out$p_top, point, tolerance = 0.1)
})

test_that("quantify_ci() draws Normal(value, cv * value) noise event by event", {
  f = it_security_f()
  probs = it_security_probs
  set.seed(3)
  z = matrix(stats::rnorm(50 * 10), nrow = 50)
  long = quantify_ci(f, probs, n = 50, cv = 0.2, seed = 3, draws = TRUE)

  drawn = sweep(pmax(1 + 0.2 * z, 0), 2, unlist(probs), "*")
  colnames(drawn) = names(probs)
  expect_equal(long$p_top, quantify(f, as.data.frame(pmin(drawn, 1)), prob = TRUE))

  # A named vector is one row; the same seed gives the same draws.
  expect_equal(quantify_ci(f, unlist(probs), n = 50, seed = 3, draws = TRUE), long)
})

test_that("quantify_ci() gives every row the same draws (common random numbers)", {
  f = it_security_f()
  rates = it_security_rates()
  fixed = rates
  fixed$MN = fixed$MN * 0.1
  scen = dplyr::bind_rows(rates, fixed)
  scen = tibble::tibble(scenario = factor(c("Neither", "Fix A"), levels = c("Neither", "Fix A")),
                        scen)

  out = quantify_ci(f, scen, time = c(8760, 43800), n = 200, seed = 2)
  expect_named(out, c("scenario", "time", "p_top", "lower", "upper"))
  expect_equal(as.character(out$scenario), c("Neither", "Neither", "Fix A", "Fix A"))
  expect_equal(levels(out$scenario), c("Neither", "Fix A"))
  expect_equal(out$time, c(8760, 43800, 8760, 43800))

  # Each row matches a one-row call with the same seed: one shared noise matrix.
  expect_equal(out[3, c("p_top", "lower", "upper")],
               quantify_ci(f, fixed, time = 8760, n = 200, seed = 2)[c("p_top", "lower", "upper")])

  # Per-row times in a `time` column give the same answer as crossing.
  grid = scen[c(1, 1, 2, 2), ]
  grid$time = c(8760, 43800, 8760, 43800)
  expect_equal(quantify_ci(f, grid, n = 200, seed = 2), out)

  long = quantify_ci(f, scen, time = 8760, n = 200, seed = 2, draws = TRUE)
  expect_named(long, c("scenario", "time", "sim", "p_top"))
  expect_equal(nrow(long), 400)
  expect_true(all(long$p_top[long$scenario == "Fix A"] <= long$p_top[long$scenario == "Neither"]))
})

test_that("quantify_ci() refuses bad input with actionable errors", {
  f = it_security_f()
  rates = it_security_rates()
  expect_error(quantify_ci(f, rates[, -1], time = 1), "Missing: DA")
  expect_error(quantify_ci(f, rates * 1e5), "If these are failure rates, pass `time`")
  expect_error(quantify_ci(f, rates, time = -1), "non-negative")
  expect_error(quantify_ci(f, dplyr::mutate(rates, time = 1), time = 1), "already has a `time`")
  expect_error(quantify_ci(f, rates, time = 1, n = 0), "whole number")
  expect_error(quantify_ci(f, rates, time = 1, cv = -1), "non-negative")
  expect_error(quantify_ci(f, rates, time = 1, level = 0), "level")
  expect_error(quantify_ci(f, rates, time = 1, draws = NA), "TRUE or FALSE")
  expect_error(quantify_ci(f, -rates, time = 1), "non-negative")
  expect_error(quantify_ci(f, rates[0, ], time = 1), "no rows")
  expect_error(quantify_ci(f, "MN"), "data frame")
  expect_error(quantify_ci("f", rates), "formulate")
})
