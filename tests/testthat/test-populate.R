test_that("populate replaces ones with probabilities", {
  bin <- tibble::tibble(A = c(1L, 0L), B = c(0L, 1L))
  ep <- tibble::tibble(event = c("A", "B"), probability = c(0.1, 0.25))
  out <- populate(bin, ep)
  expect_equal(out$A, c(0.1, 0))
  expect_equal(out$B, c(0, 0.25))
})

test_that("populate preserves scenario column", {
  bin <- tibble::tibble(scenario = c("s1", "s2"), A = c(1L, 0L))
  ep <- tibble::tibble(event = "A", probability = 0.5)
  out <- populate(bin, ep)
  expect_equal(out$scenario, c("s1", "s2"))
  expect_equal(out$A, c(0.5, 0))
})

test_that("populate(): invalid event_probs columns", {
  expect_snapshot(error = TRUE, {
    populate(tibble::tibble(A = 1L), data.frame(wrong = 1, cols = 2))
  })
})

test_that("populate(): missing probability for event", {
  expect_snapshot(error = TRUE, {
    populate(
      tibble::tibble(A = 1L, B = 0L),
      tibble::tibble(event = "A", probability = 0.5)
    )
  })
})
