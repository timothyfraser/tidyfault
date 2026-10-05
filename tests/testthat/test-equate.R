gates_df = function(gate, set, type = "or") {
  tibble::tibble(gate = gate, type = type, set = set)
}

test_that("a gate named T does not match inside the basic event TO", {
  nodes = tibble::tibble(
    id = 1:5,
    event = c("T", "G", "TO", "A", "B"),
    type = factor(
      c("top", "or", "not", "not", "not"),
      levels = c("top", "and", "or", "not")
    )
  )
  edges = tibble::tibble(from = c(1L, 2L, 2L, 2L), to = c(2L, 3L, 4L, 5L))
  gates = curate(nodes = nodes, edges = edges)

  elapsed = system.time(eq <- equate(gates))[["elapsed"]]

  expect_lt(elapsed, 1)
  expect_identical(eq, " ( (TO + A + B) ) ")
})

test_that("a gate name is matched literally, not as a regex", {
  gates = gates_df(
    gate = c("T", "G.1"),
    set = c(" (G.1) ", " (X + GX1) ")
  )
  expect_identical(equate(gates), " ( (X + GX1) ) ")
})

test_that("a two-gate cycle errors and names both gates", {
  gates = gates_df(
    gate = c("T", "G1", "G2"),
    set = c(" (G1) ", " (G2 * A) ", " (G1 + B) ")
  )
  expect_error(equate(gates), "G1.*G2|G2.*G1")
  expect_error(equate(gates), "cycle")
})

test_that("a gate that references itself errors", {
  gates = gates_df(gate = c("T", "G1"), set = c(" (G1) ", " (G1 + A) "))
  expect_error(equate(gates), "G1 -> G1")
})

test_that("output is byte-identical to the previous equate() on bundled trees", {
  expect_identical(
    equate(curate(fakenodes, fakeedges)),
    " ( ( (B *  (C + D) )  *  (A +  (B * C) ) ) ) "
  )
  expect_identical(
    equate(curate(it_security_nodes, it_security_edges)),
    " ( ( ( (PC + LR)  * MN * PM)  +  (VS * PO * WB)  +  (IM * DA * EP) ) ) "
  )
  expect_identical(
    equate(curate(breach_nodes, breach_edges)),
    " ( ( (Phishing * Credential)  +  (Insider + Unauthorized) ) ) "
  )
})

test_that("a gate name does not match inside a dotted event name", {
  nodes <- tibble::tibble(
    id = 1:4,
    event = c("T", "X", "X.1", "B"),
    type = factor(c("top", "or", "not", "not"), levels = c("top", "and", "or", "not"))
  )
  edges <- tibble::tibble(from = c(1L, 2L, 2L), to = c(2L, 3L, 4L))
  eq <- equate(curate(nodes, edges))
  expect_match(eq, "X.1", fixed = TRUE)
  expect_false(grepl("X.1 + B) .1", eq, fixed = TRUE))
})
