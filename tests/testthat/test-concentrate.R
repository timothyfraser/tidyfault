cutsets_for <- function(nodes, edges, method = "mocus_rcpp") {
  concentrate(curate(nodes, edges), method = method)
}

test_that("concentrate matches the pre-change cutsets on bundled trees", {
  data("fakenodes", "fakeedges", package = "tidyfault")
  data("breach_nodes", "breach_edges", package = "tidyfault")
  data("db_nodes", "db_edges", package = "tidyfault")
  data("security_nodes", "security_edges", package = "tidyfault")
  data("it_security_nodes", "it_security_edges", package = "tidyfault")

  expect_identical(cutsets_for(fakenodes, fakeedges), c("B*C", "A*B*D"))
  expect_identical(
    cutsets_for(breach_nodes, breach_edges),
    c("Insider", "Unauthorized", "Credential*Phishing")
  )
  expect_identical(
    cutsets_for(db_nodes, db_edges),
    c(
      "AF*AUF*BF*HF*MF*SF", "AF*BF*HF*MF*NF*SF",
      "AUF*BF*DC*HF*MF*SF", "BF*DC*HF*MF*NF*SF"
    )
  )
  expect_identical(
    cutsets_for(security_nodes, security_edges),
    c("ES*MW*N2F*VE*WP", "ES*N2F*PH*VE*WP", "ES*N2F*UA*VE*WP")
  )
  expect_identical(
    cutsets_for(it_security_nodes, it_security_edges),
    c("DA*EP*IM", "LR*MN*PM", "MN*PC*PM", "PO*VS*WB")
  )
})

test_that("all MOCUS methods give the same cutsets", {
  data("fakenodes", "fakeedges", package = "tidyfault")
  expected <- cutsets_for(fakenodes, fakeedges)
  expect_identical(cutsets_for(fakenodes, fakeedges, "mocus_r"), expected)
  expect_identical(cutsets_for(fakenodes, fakeedges, "mocus_original"), expected)
})

test_that("concentrate does not warn", {
  data("fakenodes", "fakeedges", package = "tidyfault")
  expect_no_warning(cutsets_for(fakenodes, fakeedges))
})

test_that("a variable named outcome does not change the result", {
  data("db_nodes", "db_edges", package = "tidyfault")
  expected <- cutsets_for(db_nodes, db_edges)

  outcome <- 1
  expect_identical(cutsets_for(db_nodes, db_edges), expected)

  had_global <- exists("outcome", envir = globalenv(), inherits = FALSE)
  old_global <- if (had_global) get("outcome", envir = globalenv())
  assign("outcome", 1, envir = globalenv())
  on.exit(
    if (had_global) {
      assign("outcome", old_global, envir = globalenv())
    } else {
      rm("outcome", envir = globalenv())
    },
    add = TRUE
  )
  expect_identical(cutsets_for(db_nodes, db_edges), expected)
})

test_that("absorption drops duplicates and supersets and orders cutsets", {
  products <- list(c("C", "B"), c("A", "B", "D"), c("B", "C"), c("B", "C", "E"), "Z")
  expect_identical(
    tidyfault:::absorb_cutsets(products),
    c("Z", "B*C", "A*B*D")
  )
  expect_identical(tidyfault:::absorb_cutsets(list()), character(0))
})
