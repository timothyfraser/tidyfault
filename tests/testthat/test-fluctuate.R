test_that("fluctuate() draws Normal(value, cv * value), floored at zero", {
  rates = tibble::tibble(A = 1, B = 10)
  out = fluctuate(rates, n = 20000, cv = 0.2, seed = 1)

  expect_named(out, c("sim", "A", "B"))
  expect_equal(out$sim, 1:20000)
  expect_equal(mean(out$A), 1, tolerance = 0.01)
  expect_equal(stats::sd(out$B) / mean(out$B), 0.2, tolerance = 0.02)
  expect_true(all(fluctuate(rates, n = 1000, cv = 2, seed = 1)$A >= 0))
  expect_equal(fluctuate(rates, n = 5, cv = 0)$B, rep(10, 5))
})

test_that("fluctuate() is reproducible and draws event by event", {
  rates = tibble::tibble(A = 1, B = 10)
  expect_equal(fluctuate(rates, n = 50, seed = 3), fluctuate(rates, n = 50, seed = 3))

  set.seed(3)
  z = stats::rnorm(100)
  out = fluctuate(rates, n = 50, cv = 0.2, seed = 3)
  expect_equal(out$A, pmax(1 * (1 + 0.2 * z[1:50]), 0))
  expect_equal(out$B, pmax(10 * (1 + 0.2 * z[51:100]), 0))
})

test_that("fluctuate() gives every scenario the same draws (common random numbers)", {
  scen = stipulate(tibble::tibble(A = 1, B = 10), "Fix A" = c(A = 0.1), "Fix B" = c(B = 0.5))
  out = fluctuate(scen, n = 100, seed = 2)

  expect_named(out, c("scenario", "sim", "A", "B"))
  expect_equal(nrow(out), 300)
  expect_equal(levels(out$scenario), levels(scen$scenario))
  expect_equal(as.character(unique(out$scenario)), levels(scen$scenario))

  neither = out[out$scenario == "Neither", ]
  fix_a = out[out$scenario == "Fix A", ]
  fix_b = out[out$scenario == "Fix B", ]
  expect_equal(fix_a$A, 0.1 * neither$A)
  expect_equal(fix_a$B, neither$B)
  expect_equal(fix_b$B, 0.5 * neither$B)
  expect_equal(neither, fluctuate(tibble::tibble(A = 1, B = 10), n = 100, seed = 2) %>%
                 dplyr::mutate(scenario = neither$scenario, .before = 1))
})

test_that("fluctuate() refuses bad input with actionable errors", {
  rates = tibble::tibble(A = 1, B = 10)
  expect_error(fluctuate(rbind(rates, rates)), "exactly one row, or a `scenario` column")
  expect_error(fluctuate(rates, n = 0), "whole number")
  expect_error(fluctuate(rates, cv = -1), "non-negative")
  expect_error(fluctuate(tibble::tibble(A = -1)), "non-negative")
  expect_error(fluctuate(c(A = 1)), "data frame")
})
