test_that("simulate is reproducible with seed", {
  s1 <- simulate(n_gates = 2L, n_basic = 6L, seed = 42L)
  s2 <- simulate(n_gates = 2L, n_basic = 6L, seed = 42L)
  expect_equal(s1$nodes, s2$nodes)
  expect_equal(s1$edges, s2$edges)
  expect_equal(s1$prob, s2$prob)
})

test_that("simulate returns expected structure", {
  sim <- simulate(n_gates = 3L, n_basic = 8L, seed = 7L)
  expect_named(sim, c("nodes", "edges", "prob"))
  expect_equal(sum(sim$nodes$type == "top"), 1)
  expect_true(all(sim$edges$from %in% sim$nodes$id))
  expect_true(all(sim$edges$to %in% sim$nodes$id))
  expect_named(sim$prob, c("event", "probability"))
})

test_that("simulate(): invalid p_range", {
  expect_snapshot(error = TRUE, {
    simulate(p_range = c(0, 0.5), seed = 1L)
  })
})

test_that("simulate(): invalid n_basic", {
  expect_snapshot(error = TRUE, {
    simulate(n_basic = 0L, seed = 1L)
  })
})
