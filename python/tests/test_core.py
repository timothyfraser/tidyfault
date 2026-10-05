# python/tests/test_core.py
#
# The Python port of tidyfault (python/src/tidyfault/) against R, the reference.
# Expected values come from python/tests/reference/r_reference.json, made by
# python/tests/reference/make_r_reference.R, which SOURCES the R functions
# from a tidyfault checkout and runs them (r_version records which R). Two values are also pinned
# literally from the R package's README output.
#
# Run: python -m pytest python/tests/test_core.py -q

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
PROBS = {"db": "db_probs", "ai": "ai_probs", "security": "security_probs", "it_security": "it_security_probs"}


def _as_list(v):
    return v if isinstance(v, list) else [v]  # jsonlite unboxes length-1 vectors


def _minimal():
    # T -> G1 (or) -> A, B: the top event is not a gate (SPEC TF4.2)
    nodes = pd.DataFrame({"id": [1, 2, 3, 4], "event": ["T", "G1", "A", "B"],
                          "type": pd.Categorical(["top", "or", "not", "not"], categories=tf.NODE_TYPES)})
    edges = pd.DataFrame({"from": [1, 2, 2], "to": [2, 3, 4]})
    return nodes, edges


def _tree(name):
    if name == "minimal":
        return _minimal()
    n, e = TREES[name]
    return tf.load_data(n), tf.load_data(e)


ALL = ["minimal"] + list(TREES)


# --- the README values, verbatim ------------------------------------------------

def test_equate_fakenodes_matches_r_readme():
    eq = tf.equate(tf.curate(tf.data.fakenodes, tf.data.fakeedges))
    assert eq == " ( ( (B *  (C + D) )  *  (A +  (B * C) ) ) ) "


def test_quantify_prob_fakenodes_matches_r_readme():
    f = tf.formulate(tf.equate(tf.curate(tf.data.fakenodes, tf.data.fakeedges)))
    assert tf.quantify_prob(f, [0.10, 0.20, 0.05, 0.15]) == pytest.approx(0.01285, abs=1e-12)


# --- every bundled tree against R ------------------------------------------------

@pytest.mark.parametrize("name", ALL)
def test_curate_matches_r(name):
    want = REF["trees"][name]["curate"]
    got = tf.curate(*_tree(name))
    assert list(got.columns) == ["gate", "type", "class", "n", "set", "items"]
    assert got["gate"].tolist() == _as_list(want["gate"])
    assert got["type"].astype(str).tolist() == _as_list(want["type"])
    assert got["class"].astype(str).tolist() == _as_list(want["class"])
    assert got["n"].tolist() == _as_list(want["n"])
    assert got["set"].tolist() == _as_list(want["set"])
    assert [list(x) for x in got["items"]] == [_as_list(x) for x in _as_list(want["items"])]


@pytest.mark.parametrize("name", ALL)
def test_equate_matches_r(name):
    assert tf.equate(tf.curate(*_tree(name))) == REF["trees"][name]["equation"]


@pytest.mark.parametrize("name", ALL)
def test_formulate_matches_r(name):
    f = tf.formulate(REF["trees"][name]["equation"])
    assert tf.formal_args(f) == _as_list(REF["trees"][name]["formals"])
    assert f.body == REF["trees"][name]["body"]          # R's deparse(body(f))


@pytest.mark.parametrize("name", ALL)
def test_calculate_matches_r(name):
    ref = REF["trees"][name]
    tt = tf.calculate(tf.formulate(ref["equation"]))
    fa = _as_list(ref["formals"])
    assert list(tt.columns) == _as_list(ref["calculate_columns"])
    rows = ["".join(str(int(v)) for v in r) + ":" + str(int(o))
            for r, o in zip(tt[fa].to_numpy(), tt["outcome"].to_numpy())]
    assert rows == _as_list(ref["calculate_rows"])
    assert all(tt[c].dtype == float for c in tt.columns)


@pytest.mark.parametrize("name", sorted(PROBS))
def test_top_event_probability_matches_r(name):
    """calculate()'s truth table + the dataset's *_probs fixture -> R's quantify_prob()."""
    ref = REF["trees"][name]
    f = tf.formulate(ref["equation"])
    probs = tf.load_data(PROBS[name])
    newdata = (dict(zip(probs["event"], probs["probability"])) if "event" in probs.columns else probs)
    got = tf.quantify_prob(f, newdata, truth_table=tf.calculate(f))
    assert got == pytest.approx(float(ref["quantify_prob"]), abs=1e-9)


def test_quantify_prob_multi_scenario_matches_single():
    f = tf.formulate(REF["trees"]["db"]["equation"])
    probs = tf.load_data("db_probs")
    p = dict(zip(probs["event"], probs["probability"]))
    df = pd.DataFrame([p, {k: v / 2 for k, v in p.items()}])
    got = tf.quantify_prob(f, df)
    assert got.shape == (2,)
    assert got[0] == pytest.approx(float(REF["trees"]["db"]["quantify_prob"]), abs=1e-9)
    assert got[1] == pytest.approx(tf.quantify_prob(f, df.iloc[[1]]), abs=1e-15)


@pytest.mark.parametrize("name", [n for n in ALL if "tabulate" in REF["trees"][n]])
def test_tabulate_matches_r(name):
    ref = REF["trees"][name]
    f = tf.formulate(ref["equation"])
    got = tf.tabulate(_as_list(ref["concentrate"]), formula=f, query=True)
    want = ref["tabulate"]
    assert list(got.columns) == ["mincut", "query", "cutsets", "failures", "coverage"]
    assert got["mincut"].tolist() == _as_list(want["mincut"])
    assert got["query"].tolist() == _as_list(want["query"])
    assert got["cutsets"].tolist() == _as_list(want["cutsets"])
    assert got["failures"].tolist() == _as_list(want["failures"])
    assert np.allclose(got["coverage"], [float(x) for x in _as_list(want["coverage"])], atol=1e-12)
    assert list(tf.tabulate(_as_list(ref["concentrate"]), formula=f).columns) == \
        ["mincut", "cutsets", "failures", "coverage"]


def test_populate_matches_r():
    got = tf.populate(tf.data.db_outcomes_binary, tf.data.db_probs)
    assert list(got.columns) == REF["populate_db_columns"]
    for col in got.columns:
        want = [float(x) for x in REF["populate_db"][col]]
        assert np.allclose(got[col].astype(float), want, atol=0), col


def test_populate_r_unit_tests():
    out = tf.populate(pd.DataFrame({"A": [1, 0], "B": [0, 1]}),
                      pd.DataFrame({"event": ["A", "B"], "probability": [0.1, 0.25]}))
    assert out["A"].tolist() == [0.1, 0] and out["B"].tolist() == [0, 0.25]
    out = tf.populate(pd.DataFrame({"scenario": ["s1", "s2"], "A": [1, 0]}),
                      pd.DataFrame({"event": ["A"], "probability": [0.5]}))
    assert out["scenario"].tolist() == ["s1", "s2"] and out["A"].tolist() == [0.5, 0]
    with pytest.raises(ValueError, match="must have columns 'event' and 'probability'"):
        tf.populate(pd.DataFrame({"A": [1]}), pd.DataFrame({"wrong": [1], "cols": [2]}))
    with pytest.raises(ValueError, match="missing probabilities for events: B"):
        tf.populate(pd.DataFrame({"A": [1], "B": [0]}), pd.DataFrame({"event": ["A"], "probability": [0.5]}))


# --- gate polygons ---------------------------------------------------------------

GATE_CALLS = {
    "gate_and_1_12": lambda: tf.gate_and(size=1, res=12),
    "gate_or_1_12": lambda: tf.gate_or(size=1, res=12),
    "gate_top_2_12": lambda: tf.gate_top(size=2, res=12),
    "gate_and_default_50": lambda: tf.gate_and(res=50),
    "get_gate_and": lambda: tf.get_gate(0.5, -1, gate="and", size=1, res=10),
    "get_gate_or": lambda: tf.get_gate(0, 0, gate="or", size=1, res=10),
    "get_gate_top": lambda: tf.get_gate(2, 3, gate="top", size=0.5, res=10),
}


@pytest.mark.parametrize("key", sorted(GATE_CALLS))
def test_gate_shapes_match_r(key):
    got = GATE_CALLS[key]()
    want = REF["gates"][key]
    assert list(got.columns) == ["x", "y"]
    assert np.allclose(got["x"], [float(v) for v in want["x"]], rtol=0, atol=1e-12)
    assert np.allclose(got["y"], [float(v) for v in want["y"]], rtol=0, atol=1e-12)


def test_gate_frame_matches_r():
    nodes = pd.DataFrame({"id": [1, 2, 3], "event": ["T", "G1", "G2"],
                          "type": pd.Categorical(["top", "and", "or"], categories=tf.NODE_TYPES),
                          "x": [0.0, -1.0, 1.0], "y": [1.0, 0.0, 0.0]})
    got = tf.gate(nodes, size=0.5, res=16)
    want = REF["gate_frame"]
    assert list(got.columns) == want["columns"]
    assert got["group"].tolist() == want["group"]
    assert got["gate"].astype(str).tolist() == want["gate"]
    assert np.allclose(got["x"], [float(v) for v in want["x"]], atol=1e-12)
    assert np.allclose(got["y"], [float(v) for v in want["y"]], atol=1e-12)


def test_gate_helpers_round_trip():
    # get_gate() is gate_*() rescaled onto a centre: undo the shift and the
    # rescale and you are back on the base shape's own range.
    for kind, base in (("and", tf.gate_and), ("or", tf.gate_or)):
        g = base(size=1, res=20)
        placed = tf.get_gate(3.0, -2.0, gate=kind, size=1, res=20)
        assert len(placed) == len(g)
        back_x = (placed["x"] - 3.0 + 1) / 2 * (g["x"].max() - g["x"].min()) + g["x"].min()
        assert np.allclose(back_x, g["x"], atol=1e-12)
    assert tf.get_gate(0, 0, gate="not") is None
    with pytest.raises(TypeError, match='argument "res" is missing'):
        tf.gate_and(size=1)


# --- Python-side behaviour ---------------------------------------------------------

def test_ai_tree_equation():
    """Gate names match as whole tokens in both R and Python, so gate "T" never
    matches inside basic event "TO"."""
    eq = tf.equate(tf.curate(tf.data.ai_nodes, tf.data.ai_edges))
    assert eq == " ( ( (AF + TO + RL)  + CWE) ) " == REF["trees"]["ai"]["equation"]


# --- the top event is not a gate (SPEC TF4.2): R's message, word for word ----------

def _bad_trees():
    t = list(tf.NODE_TYPES)

    def n(ids, events, types):
        return pd.DataFrame({"id": ids, "event": events, "type": pd.Categorical(types, categories=t)})

    def e(frm, to):
        return pd.DataFrame({"from": pd.Series(frm, dtype="int64"), "to": pd.Series(to, dtype="int64")})

    db_nodes, db_edges = tf.data.db_nodes, tf.data.db_edges
    db_old_nodes = db_nodes[db_nodes["event"] != "G0"].reset_index(drop=True)
    db_old_edges = db_edges[db_edges["from"] != 1].replace({"from": {14: 1}}).reset_index(drop=True)
    return {
        "two_children": (n([1, 2, 3], ["T", "A", "B"], ["top", "not", "not"]), e([1, 1], [2, 3])),
        "zero_children": (n([1, 2], ["T", "A"], ["top", "not"]), e([], [])),
        "basic_child": (n([1, 2], ["T", "A"], ["top", "not"]), e([1], [2])),
        "unknown_child": (n([1, 2], ["T", "A"], ["top", "not"]), e([1], [9])),
        "two_tops": (n([1, 2, 3], ["T", "U", "A"], ["top", "top", "not"]), e([1, 2], [3, 3])),
        "no_top": (n([1, 2], ["G", "A"], ["or", "not"]), e([1], [2])),
        "db_old": (db_old_nodes, db_old_edges),
    }


@pytest.mark.parametrize("case", sorted(REF["curate_errors"]))
def test_curate_refuses_like_r(case):
    nodes, edges = _bad_trees()[case]
    with pytest.raises(ValueError) as err:
        tf.curate(nodes, edges)
    assert str(err.value) == REF["curate_errors"][case]
    with pytest.raises(ValueError) as err:
        tf.validate_tree(nodes, edges)
    assert REF["curate_errors"][case].removeprefix("curate(): ") in str(err.value)


@pytest.mark.parametrize("name", list(TREES))
def test_every_bundled_tree_is_valid(name):
    nodes, edges = _tree(name)
    assert tf.validate_tree(nodes, edges)
    gates = tf.curate(nodes, edges)
    assert gates.loc[gates["class"] == "top", "n"].tolist() == [1]


def test_formula_calls_like_r():
    f = tf.formulate(" ( ( (B *  (C + D) )  *  (A +  (B * C) ) ) ) ")
    assert f(1, 1, 1, 1) == 4.0                     # arithmetic, as in R
    assert f(A=0, B=1, C=1, D=0) == 1.0
    assert repr(f).startswith("function (A, B, C, D)")
    with pytest.raises(TypeError, match='argument "D" is missing'):
        f(1, 1, 1)
    with pytest.raises(ValueError):
        tf.formulate("A + __import__('os')")


def test_validate_tree():
    assert tf.validate_tree(tf.data.db_nodes, tf.data.db_edges)
    nodes = tf.data.fakenodes
    bad_edges = pd.concat([tf.data.fakeedges, pd.DataFrame({"from": [7, 99], "to": [2, 1]})])
    with pytest.raises(ValueError) as err:
        tf.validate_tree(nodes, bad_edges)
    msg = str(err.value)
    assert "unknown node id(s): [99]" in msg and "('not') node id(s) with children: [7]" in msg


def test_equate_refuses_a_cycle():
    gates = pd.DataFrame({"gate": ["T", "G1", "G2"], "set": [" (G1) ", " (G2 + A) ", " (G1 * B) "]})
    with pytest.raises(ValueError, match="cycle"):
        tf.equate(gates)


def test_every_r_dataset_is_bundled():
    names = set(tf.data.available())
    for n in ("fakenodes", "fakeedges", "db_nodes", "db_edges", "db_probs", "db_outcomes_binary",
              "db_outcomes_prob", "db_outcomes_rates", "ai_nodes", "ai_edges", "ai_probs"):
        assert n in names
    assert tf.data.fakenodes["type"].cat.categories.tolist() == ["top", "and", "or", "not"]
