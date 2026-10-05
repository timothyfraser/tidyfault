# make_r_reference.R -- regenerate r_reference.json, the R outputs that the
# Python port of tidyfault is tested against (python/tests/test_core.py,
# python/tests/test_mocus.py).
#
# R is the reference. This script SOURCES the R functions the port mirrors
# straight from a tidyfault source checkout (https://github.com/timothyfraser/tidyfault),
# so the fixtures describe exactly that source, not whatever build is installed.
# The installed tidyfault is used only for what needs its compiled routines:
# concentrate() and mocus_rcpp() (compiled MOCUS) and quantify(prob = TRUE,
# fast = TRUE) (compiled quantify_prob_fast(), which the sourced quantify_if()
# calls).
#
# Usage (from the repository root):
#   Rscript python/tests/reference/make_r_reference.R . python/tests/reference/r_reference.json
# Needs: dplyr, stringr, tidyr, tibble, scales, jsonlite, tidyfault.

args <- commandArgs(trailingOnly = TRUE)
src <- if (length(args) >= 1) args[[1]] else "."
out <- if (length(args) >= 2) args[[2]] else "r_reference.json"

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(tidyr); library(tibble)
  library(scales); library(jsonlite)
})
for (f in c("curate", "equate", "formulate", "calculate", "tabulate", "populate",
            "quantify_prob", "gate", "gate_and", "gate_or", "gate_top", "get_gate",
            "mocus", "mocus_fast_r", "quantify_binary", "quantify_binary_fast",
            "quantify_if", "quantify_ci", "quantify_when")) {
  source(file.path(src, "R", paste0(f, ".R")))
}
# mocus_rcpp(), quantify_prob_fast() and quantify(prob = TRUE, fast = TRUE) need
# the compiled routines, so they come from the installed tidyfault.
ld <- function(name) { e <- new.env(); load(file.path(src, "data", paste0(name, ".rda")), envir = e); e[[name]] }
num <- function(x) sprintf("%.17g", x)   # full double precision, parsed back with float()

# the minimal tree from tests/testthat/helper-trees.R: T -> G1 (or) -> A, B
minimal <- list(
  nodes = tibble(id = 1:4, event = c("T", "G1", "A", "B"),
                 type = factor(c("top", "or", "not", "not"), levels = c("top", "and", "or", "not"))),
  edges = tibble(from = c(1L, 2L, 2L), to = c(2L, 3L, 4L)))

trees <- list(
  minimal     = list(nodes = minimal$nodes, edges = minimal$edges, probs = NULL),
  fake        = list(nodes = ld("fakenodes"), edges = ld("fakeedges"), probs = NULL),
  db          = list(nodes = ld("db_nodes"), edges = ld("db_edges"), probs = ld("db_probs")),
  ai          = list(nodes = ld("ai_nodes"), edges = ld("ai_edges"), probs = ld("ai_probs")),
  security    = list(nodes = ld("security_nodes"), edges = ld("security_edges"), probs = ld("security_probs")),
  it_security = list(nodes = ld("it_security_nodes"), edges = ld("it_security_edges"), probs = ld("it_security_probs")),
  breach      = list(nodes = ld("breach_nodes"), edges = ld("breach_edges"), probs = NULL))

res <- list(r_version = R.version.string, trees = list())
for (nm in names(trees)) {
  t <- trees[[nm]]
  gates <- curate(t$nodes, t$edges)
  eq <- equate(gates)
  f <- formulate(eq)
  fa <- formalArgs(f)
  tt <- calculate(f)
  rec <- list(
    curate = list(gate = as.character(gates$gate), type = as.character(gates$type),
                  class = as.character(gates$class), n = gates$n, set = gates$set,
                  items = lapply(gates$items, as.character)),
    equation = eq,
    formals = fa,
    body = paste(deparse(body(f)), collapse = " "),
    calculate_columns = names(tt),
    calculate_rows = paste0(apply(as.matrix(tt[fa]), 1, paste, collapse = ""), ":", tt$outcome))
  if (!is.null(t$probs)) {
    p <- if (all(c("event", "probability") %in% names(t$probs))) {
      setNames(t$probs$probability, t$probs$event)
    } else {
      unlist(t$probs[1, ])
    }
    rec$quantify_prob <- num(quantify_prob(f, newdata = p))
  }
  {
    cuts <- tidyfault::concentrate(gates)
    tab <- tabulate(cuts, formula = f, query = TRUE)
    rec$concentrate <- cuts
    rec$tabulate <- list(mincut = tab$mincut, query = tab$query, cutsets = tab$cutsets,
                         failures = tab$failures, coverage = num(tab$coverage))
    # every (non-minimal) cut set, in R's order: the pure-R queue and the compiled
    # one, both starting from the top event's one gate (SPEC TF4.2).
    rec$mocus_r <- lapply(mocus_r(gates), as.character)
    rec$mocus_rcpp <- lapply(tidyfault::mocus_rcpp(gates), as.character)
    rec$concentrate_mocus_r <- tidyfault::concentrate(gates, method = "mocus_r")
  }
  ob <- tryCatch(ld(paste0(sub("^minimal$", "none", nm), "_outcomes_binary")), error = function(e) NULL)
  op <- tryCatch(ld(paste0(sub("^minimal$", "none", nm), "_outcomes_prob")), error = function(e) NULL)
  if (!is.null(ob)) {
    rec$quantify_binary <- quantify_binary(f, ob)
    rec$quantify_binary_fast <- quantify_binary_fast(f, ob)
    rec$quantify_binary_row1 <- quantify_binary(f, unlist(ob[1, fa]))   # one unnamed scenario
  }
  if (!is.null(op)) {
    p2 <- setNames(op$probability, op$event)[fa]
    scen <- as.data.frame(rbind(p2, p2 / 2, pmin(p2 * 2, 1)))
    rec$quantify_prob_scenarios <- lapply(as.list(scen), num)
    rec$quantify_prob_one <- num(quantify_prob(f, newdata = p2))
    rec$quantify_prob_one_fast <- num(tidyfault::quantify(f, p2, prob = TRUE, fast = TRUE))
    rec$quantify_prob_multi <- num(quantify_prob(f, newdata = scen))
    rec$quantify_prob_multi_fast <- num(tidyfault::quantify(f, scen, prob = TRUE, fast = TRUE))
  }
  res$trees[[nm]] <- rec
}

# curate()'s TF4.2 refusals, word for word: the Python twin must raise the same text.
lvl <- c("top", "and", "or", "not")
bad <- list(
  two_children = list(nodes = tibble(id = 1:3, event = c("T", "A", "B"), type = factor(c("top", "not", "not"), lvl)),
                      edges = tibble(from = c(1L, 1L), to = c(2L, 3L))),
  zero_children = list(nodes = tibble(id = 1:2, event = c("T", "A"), type = factor(c("top", "not"), lvl)),
                       edges = tibble(from = integer(), to = integer())),
  basic_child = list(nodes = tibble(id = 1:2, event = c("T", "A"), type = factor(c("top", "not"), lvl)),
                     edges = tibble(from = 1L, to = 2L)),
  unknown_child = list(nodes = tibble(id = 1:2, event = c("T", "A"), type = factor(c("top", "not"), lvl)),
                       edges = tibble(from = 1L, to = 9L)),
  two_tops = list(nodes = tibble(id = 1:3, event = c("T", "U", "A"), type = factor(c("top", "top", "not"), lvl)),
                  edges = tibble(from = c(1L, 2L), to = c(3L, 3L))),
  no_top = list(nodes = tibble(id = 1:2, event = c("G", "A"), type = factor(c("or", "not"), lvl)),
                edges = tibble(from = 1L, to = 2L)),
  db_old = list(nodes = filter(ld("db_nodes"), event != "G0"),
                edges = ld("db_edges") %>% filter(from != 1) %>%
                  mutate(from = ifelse(from == 14, 1, from))))
res$curate_errors <- lapply(bad, function(t) tryCatch({ curate(t$nodes, t$edges); NA_character_ },
                                                     error = conditionMessage))

pop <- populate(ld("db_outcomes_binary"), ld("db_probs"))
res$populate_db <- lapply(as.list(pop), function(col) if (is.numeric(col)) num(col) else col)
res$populate_db_columns <- names(pop)

poly <- function(d) list(x = num(d$x), y = num(d$y))
res$gates <- list(
  gate_and_1_12 = poly(gate_and(size = 1, res = 12)),
  gate_or_1_12  = poly(gate_or(size = 1, res = 12)),
  gate_top_2_12 = poly(gate_top(size = 2, res = 12)),
  gate_and_default_50 = poly(gate_and(res = 50)),
  get_gate_and  = poly(get_gate(0.5, -1, gate = "and", size = 1, res = 10)),
  get_gate_or   = poly(get_gate(0, 0, gate = "or", size = 1, res = 10)),
  get_gate_top  = poly(get_gate(2, 3, gate = "top", size = 0.5, res = 10)))
gnodes <- tibble(id = 1:3, event = c("T", "G1", "G2"),
                 type = factor(c("top", "and", "or"), levels = c("top", "and", "or", "not")),
                 x = c(0, -1, 1), y = c(1, 0, 0))
gp <- gate(gnodes, size = 0.5, res = 16)
res$gate_frame <- list(columns = names(gp), group = gp$group, gate = as.character(gp$gate),
                       x = num(gp$x), y = num(gp$y))

# quantify_if() and quantify_when(ci = FALSE): deterministic, so Python must
# equal R to 1e-9. Rates are per hour; 8,760 hours is one year.
quantify <- tidyfault::quantify   # the compiled quantify() that quantify_if() calls
its <- ld("it_security_outcomes_rates")
its_rates <- as_tibble(as.list(setNames(its$lambda, its$event)))
f_its <- formulate(equate(curate(ld("it_security_nodes"), ld("it_security_edges"))))
f_min <- formulate(equate(curate(minimal$nodes, minimal$edges)))
qi <- function(x) list(event = x$event, p_top = num(x$p_top), baseline = num(x$baseline),
                       change = num(x$change), pct_change = num(x$pct_change))
res$quantify_if <- list(
  it_security_rates_cut05_t8760 = qi(quantify_if(f_its, its_rates, cut = 0.05, time = 8760)),
  it_security_rates_cut90_t43800_PO_MN = qi(quantify_if(f_its, its_rates, cut = 0.9, time = 43800,
                                                        events = c("PO", "MN"))),
  it_security_probs_cut1 = qi(quantify_if(f_its, ld("it_security_probs"), cut = 1)),
  minimal_probs_cut50 = qi(quantify_if(f_min, c(A = 0.1, B = 0.2), cut = 0.5)))
qw <- function(x) list(columns = names(x), levels = I(levels(x$scenario)),
                       scenario = I(as.character(x$scenario)), time = num(x$time),
                       p_top = num(x$p_top), reliability = num(x$reliability))
res$quantify_when <- list(
  it_security_four_default_time = qw(quantify_when(f_its, its_rates, "Fix A only" = c(MN = 0.1),
                                                   "Fix B only" = c(PO = 0.1),
                                                   "Fix A and B" = c(MN = 0.1, PO = 0.1), ci = FALSE)),
  it_security_no_baseline = qw(quantify_when(f_its, its_rates, "Half" = c(DA = 0.5, WB = 2),
                                             baseline = NULL, time = c(8760, 43800), ci = FALSE)),
  minimal_renamed = qw(quantify_when(f_min, c(A = 0.001, B = 0.002), "B off" = c(B = 0),
                                     baseline = "As is", time = c(0, 100, 1000), ci = FALSE)))

writeLines(toJSON(res, auto_unbox = TRUE, pretty = TRUE, digits = NA), out, useBytes = TRUE)
cat("wrote", out, "\n")
