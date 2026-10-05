# python/tests/test_mocus.py
#
# mocus(), concentrate(), quantify() / quantify_binary() / quantify_prob_fast()
# and simulate() in the Python port of tidyfault (python/src/tidyfault/), against R.
# Expected values come from python/tests/reference/r_reference.json, made by
# python/tests/reference/make_r_reference.R (the R version is recorded in its r_version field).
#
# The top event is not a gate (SPEC TF4.2): MOCUS starts from its one gate, in R
# and here, so the cut sets match R element for element and agree with equate().
#
# Run: python -m pytest python/tests/test_mocus.py -q

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

import tidyfault as tf

REF = json.loads((Path(__file__).resolve().parent / "reference" / "r_reference.json").read_text(encoding="utf-8"))
TREES = {
    "fake": ("fakenodes", "fakeedges"),
    "db": ("db_nodes", "db_edges"),
    "ai": ("ai_nodes", "ai_edges"),
    "security": ("security_nodes", "security_edges"),
    "it_security": ("it_security_nodes", "it_security_edges"),
    "breach": ("breach_nodes", "breach_edges"),
}
OUTCOMES = ("db", "ai", "security")


def _as_list(v):
    return v if isinstance(v, list) else [v]  # jsonlite unboxes length-1 vectors


def _minimal():
    # T -> G1 (or) -> A, B, as in tests/testthat/helper-trees.R
    nodes = pd.DataFrame({"id": [1, 2, 3, 4], "event": ["T", "G1", "A", "B"],
                          "type": pd.Categorical(["top", "or", "not", "not"], categories=list(tf.NODE_TYPES))})
    edges = pd.DataFrame({"from": [1, 2, 2], "to": [2, 3, 4]})
    return nodes, edges


def _gates(name):
    if name == "minimal":
        return tf.curate(*_minimal())
    n, e = TREES[name]
    return tf.curate(tf.load_data(n), tf.load_data(e))


def _cutsets(ref_list):
    return [_as_list(c) for c in _as_list(ref_list)]


# --- mocus reproduces R, element for element, in R's order -------------------

@pytest.mark.parametrize("name", ["minimal"] + list(TREES))
@pytest.mark.parametrize("fn", ["mocus", "mocus_r", "mocus_rcpp", "mocus_cpp"])
def test_mocus_matches_r(name, fn):
    rec = REF["trees"][name]
    got = getattr(tf, fn)(_gates(name))
    assert got == _cutsets(rec["mocus_r"]), f"{fn}({name}) != R mocus_r()"
    assert got == _cutsets(rec["mocus_rcpp"]), f"{fn}({name}) != R mocus_rcpp()"


@pytest.mark.parametrize("name", ["minimal"] + list(TREES))
def test_concentrate_matches_r(name):
    rec = REF["trees"][name]
    for method in ("mocus_rcpp", "mocus_r", "mocus_original"):
        got = tf.concentrate(_gates(name), method=method)
        assert got == _as_list(rec["concentrate"]), f"concentrate({name}, {method})"
        assert got == _as_list(rec["concentrate_mocus_r"]), f"concentrate({name}, {method})"


# --- the cut sets agree with the equation -------------------------------------

def test_minimal_tree():
    g = _gates("minimal")
    assert tf.equate(g).strip() == "( (A + B) )"
    assert tf.mocus(g) == [["A"], ["B"]]
    assert tf.concentrate(g) == ["A", "B"] == _as_list(REF["trees"]["minimal"]["concentrate"])


def test_mocus_refuses_a_top_with_two_children():
    gates = pd.DataFrame({"gate": ["T"], "type": ["top"], "class": ["top"], "n": [2],
                          "set": [" (A + B) "], "items": [["A", "B"]]})
    with pytest.raises(ValueError, match="top event `T` must have exactly one child"):
        tf.mocus(gates)


@pytest.mark.parametrize("name", ["minimal"] + list(TREES))
def test_or_cutsets_reproduce_the_truth_table(name):
    """A truth-table row fails exactly when it contains some minimal cut set:
    the cut sets and formulate(equate()) describe the same function."""
    g = _gates(name)
    f = tf.formulate(tf.equate(g))
    tt = tf.calculate(f)
    cuts = [c.split("*") for c in tf.concentrate(g)]
    covered = np.zeros(len(tt), dtype=bool)
    for c in cuts:
        covered |= (tt[c] == 1).all(axis=1).to_numpy()
    assert (covered == (tt["outcome"].to_numpy() >= 1)).all(), f"{name}: cut sets disagree with the equation"


def test_repaired_trees_expected_sets():
    assert tf.concentrate(_gates("db")) == ["AF", "AUF", "DC", "NF", "BF*SF", "HF*MF"]
    assert tf.concentrate(_gates("security")) == ["MW", "PH", "UA", "ES*VE", "N2F*WP"]
    assert tf.concentrate(_gates("ai")) == ["AF", "CWE", "RL", "TO"]


def test_concentrate_feeds_tabulate():
    g = _gates("fake")
    f = tf.formulate(tf.equate(g))
    tab = tf.tabulate(tf.concentrate(g), formula=f)
    assert list(tab["mincut"]) == sorted(_as_list(REF["trees"]["fake"]["concentrate"]))


def test_mocus_rejects_bad_arguments():
    g = _gates("fake")
    with pytest.raises(ValueError, match="method"):
        tf.mocus(g, method="nope")
    with pytest.raises(TypeError):
        tf.mocus(g, top="or")          # no top= argument: the top event has no logic
    with pytest.raises(TypeError):
        tf.concentrate(g, top="and")
    with pytest.raises(ValueError, match="method"):
        tf.concentrate(g, method="nope")


# --- quantify -----------------------------------------------------------------

def _formula(name):
    return tf.formulate(tf.equate(_gates(name)))


def _scenarios(rec):
    return pd.DataFrame({k: [float(x) for x in v] for k, v in rec["quantify_prob_scenarios"].items()})


@pytest.mark.parametrize("name", OUTCOMES)
def test_quantify_binary_outcomes_match_r(name):
    rec = REF["trees"][name]
    f = _formula(name)
    ob = tf.load_data(f"{name}_outcomes_binary")
    for got in (tf.quantify_binary(f, ob), tf.quantify_binary_fast(f, ob),
                tf.quantify(f, ob), tf.quantify(f, ob, fast=False)):
        assert got.dtype == bool
        assert list(got) == rec["quantify_binary"] == rec["quantify_binary_fast"]
    row = list(ob[tf.formal_args(f)].iloc[0])
    assert tf.quantify(f, row) is rec["quantify_binary_row1"]
    assert tf.quantify(f, [bool(v) for v in row]) is rec["quantify_binary_row1"]
    assert tf.quantify(f, dict(ob[tf.formal_args(f)].iloc[0])) is rec["quantify_binary_row1"]


@pytest.mark.parametrize("name", OUTCOMES)
def test_quantify_prob_matches_r(name):
    rec = REF["trees"][name]
    f = _formula(name)
    sc = _scenarios(rec)
    one = sc.iloc[0].to_dict()
    for got in (tf.quantify(f, one, prob=True), tf.quantify(f, one, prob=True, fast=False),
                tf.quantify_prob_fast(f, one)):
        assert isinstance(got, float)
        assert got == pytest.approx(float(rec["quantify_prob_one"]), abs=1e-9)
        assert got == pytest.approx(float(rec["quantify_prob_one_fast"]), abs=1e-9)
    multi = tf.quantify(f, sc, prob=True)
    assert np.allclose(multi, [float(x) for x in rec["quantify_prob_multi"]], atol=1e-9, rtol=0)
    assert np.allclose(multi, [float(x) for x in rec["quantify_prob_multi_fast"]], atol=1e-9, rtol=0)


def test_quantify_prob_reads_the_outcomes_prob_dataset():
    f = _formula("db")
    op = tf.load_data("db_outcomes_prob")
    p = dict(zip(op["event"], op["probability"]))
    assert tf.quantify(f, p, prob=True) == pytest.approx(float(REF["trees"]["db"]["quantify_prob_one"]), abs=1e-9)


def test_quantify_rejects_bad_arguments():
    f = _formula("fake")
    with pytest.raises(ValueError, match="prob"):
        tf.quantify(f, [1, 0, 1, 0], prob="yes")
    with pytest.raises(ValueError, match="fast"):
        tf.quantify(f, [1, 0, 1, 0], fast=None)
    with pytest.raises(ValueError, match="length"):
        tf.quantify(f, [1, 0, 1])
    with pytest.raises(ValueError, match="Missing: D"):
        tf.quantify(f, pd.DataFrame({"A": [1], "B": [1], "C": [1]}))


def test_quantify_readme_examples():
    f = _formula("fake")
    assert tf.quantify(f, [True, True, True, False]) is True
    scen = pd.DataFrame({"A": [1, 0, 1], "B": [0, 1, 1], "C": [1, 0, 0], "D": [0, 1, 1]})
    assert list(tf.quantify(f, scen)) == [False, False, True]
    assert tf.quantify(f, [0.10, 0.20, 0.05, 0.15], prob=True) == pytest.approx(0.01285, abs=1e-12)


# --- simulate -----------------------------------------------------------------

def test_simulate_shape_matches_r():
    sim = tf.simulate(seed=1)
    assert list(sim) == ["nodes", "edges", "prob"]
    nodes, edges, prob = sim["nodes"], sim["edges"], sim["prob"]
    assert list(nodes.columns) == ["id", "event", "type"]
    assert list(nodes["type"].cat.categories) == ["top", "and", "or", "not"]
    assert list(edges.columns) == ["from", "to"]
    assert list(prob.columns) == ["event", "probability"]
    assert list(nodes["event"]) == ["T", "G1", "G2", "G3"] + [f"E{i}" for i in range(1, 9)] + ["G0"]
    assert list(nodes["type"].astype(str))[0] == "top"
    assert set(nodes["type"].astype(str)[1:4]) <= {"and", "or"}
    assert list(prob["event"]) == [f"E{i}" for i in range(1, 9)]
    assert prob["probability"].between(0.01, 0.2).all()
    assert tf.validate_tree(nodes, edges)
    # the top event's one child is the OR gate G0 (last id), over the three gates
    assert list(edges.loc[edges["from"] == 1, "to"]) == [13]
    assert str(nodes["type"].iloc[-1]) == "or"
    assert list(edges.loc[edges["from"] == 13, "to"]) == [2, 3, 4]
    # every other gate has at least two basic events below it
    kids = edges[~edges["from"].isin([1, 13])].groupby("from").size()
    assert (kids >= 2).all() and len(kids) == 3


def test_simulate_is_seeded():
    a, b, c = tf.simulate(seed=42), tf.simulate(seed=42), tf.simulate(seed=7, n_basic=12)
    for k in ("nodes", "edges", "prob"):
        pd.testing.assert_frame_equal(a[k], b[k])
    assert not a["prob"].equals(c["prob"])


def test_simulate_runs_through_the_pipeline():
    sim = tf.simulate(n_gates=4, n_basic=10, seed=3)
    g = tf.curate(sim["nodes"], sim["edges"])
    f = tf.formulate(tf.equate(g))
    p = dict(zip(sim["prob"]["event"], sim["prob"]["probability"]))
    val = tf.quantify(f, p, prob=True)
    assert 0 < val < 1
    assert len(tf.concentrate(g)) >= 1


def test_simulate_caps_gates_and_degenerate_case():
    capped = tf.simulate(n_gates=10, n_basic=5, seed=0)          # 5 // 2 = 2 gates
    assert list(capped["nodes"]["event"][:3]) == ["T", "G1", "G2"]
    flat = tf.simulate(n_gates=3, n_basic=1, seed=0)             # no room for a gate
    assert list(flat["nodes"]["type"].astype(str)) == ["top", "not", "or"]
    assert list(flat["edges"]["from"]) == [1, 3] and list(flat["edges"]["to"]) == [3, 2]
    one = tf.simulate(n_gates=1, n_basic=4, seed=0)              # one gate: the top's only child
    assert list(one["nodes"]["event"]) == ["T", "G1", "E1", "E2", "E3", "E4"]
    assert list(one["edges"].loc[one["edges"]["from"] == 1, "to"]) == [2]
    for k in range(1, 9):
        sim = tf.simulate(n_gates=k, n_basic=k, seed=k)
        assert tf.validate_tree(sim["nodes"], sim["edges"])


def test_simulate_rejects_bad_arguments():
    with pytest.raises(ValueError, match="p_range"):
        tf.simulate(p_range=(0.2, 0.1))
    with pytest.raises(ValueError, match="p_range"):
        tf.simulate(p_range=(0.1,))
    with pytest.raises(ValueError, match="n_gates"):
        tf.simulate(n_gates=0)
    with pytest.raises(ValueError, match="n_basic"):
        tf.simulate(n_basic=0)
