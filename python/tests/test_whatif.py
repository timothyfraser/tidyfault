# python/tests/test_whatif.py
#
# quantify_if(), stipulate() and fluctuate() against R. quantify_if() and
# stipulate() are deterministic, so they must equal R's output in
# reference/r_reference.json to 1e-9. fluctuate() draws from numpy, not R's
# random stream (README, "Deviations from R"), so it is tested on its shape,
# its statistics and its common-random-numbers property, not on identical draws.
#
# Run: python -m pytest python/tests/test_whatif.py -q

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

import tidyfault as tf

REF = json.loads((Path(__file__).resolve().parent / "reference" / "r_reference.json").read_text(encoding="utf-8"))


def _f_its():
    return tf.formulate(tf.equate(tf.curate(tf.load_data("it_security_nodes"), tf.load_data("it_security_edges"))))


def _f_min():
    nodes = pd.DataFrame({"id": [1, 2, 3, 4], "event": ["T", "G1", "A", "B"],
                          "type": pd.Categorical(["top", "or", "not", "not"], categories=tf.NODE_TYPES)})
    edges = pd.DataFrame({"from": [1, 2, 2], "to": [2, 3, 4]})
    return tf.formulate(tf.equate(tf.curate(nodes, edges)))


def _rates():
    r = tf.load_data("it_security_outcomes_rates")
    return pd.DataFrame([dict(zip(r["event"], r["lambda"].astype(float)))])


def _num(v):
    return [float(x) for x in (v if isinstance(v, list) else [v])]


def _check_quantify_if(out, ref):
    assert list(out.columns) == ["event", "p_top", "baseline", "change", "pct_change"]
    ev = ref["event"] if isinstance(ref["event"], list) else [ref["event"]]
    assert list(out["event"]) == ev
    for col in ["p_top", "baseline", "change", "pct_change"]:
        assert out[col].to_numpy() == pytest.approx(_num(ref[col]), abs=1e-9), col


# --- quantify_if(): equal to R ------------------------------------------------

def test_quantify_if_rates_matches_r():
    _check_quantify_if(tf.quantify_if(_f_its(), _rates(), cut=0.05, time=1),
                       REF["quantify_if"]["it_security_rates_cut05_t1"])


def test_quantify_if_subset_matches_r():
    _check_quantify_if(tf.quantify_if(_f_its(), _rates(), cut=0.9, time=5, events=["PO", "MN"]),
                       REF["quantify_if"]["it_security_rates_cut90_t5_PO_MN"])


def test_quantify_if_probs_matches_r():
    _check_quantify_if(tf.quantify_if(_f_its(), tf.load_data("it_security_probs"), cut=1),
                       REF["quantify_if"]["it_security_probs_cut1"])


def test_quantify_if_minimal_matches_r():
    _check_quantify_if(tf.quantify_if(_f_min(), {"A": 0.1, "B": 0.2}, cut=0.5),
                       REF["quantify_if"]["minimal_probs_cut50"])


def test_quantify_if_accepts_series_and_extra_columns():
    f = _f_its()
    probs = tf.load_data("it_security_probs")
    out = tf.quantify_if(f, probs, cut=1)
    pd.testing.assert_frame_equal(tf.quantify_if(f, probs.iloc[0], cut=1), out)
    pd.testing.assert_frame_equal(tf.quantify_if(f, probs.assign(label="x"), cut=1), out)


@pytest.mark.parametrize("kwargs, msg", [
    (dict(cut=0, time=1), r"in \(0, 1\]"),
    (dict(cut=1.5, time=1), r"in \(0, 1\]"),
    (dict(time=1, events=["XX"]), "not basic events of `f`: XX"),
    (dict(time=-1), "single positive number"),
    (dict(), "If these are failure rates, pass `time`"),
])
def test_quantify_if_refuses_like_r(kwargs, msg):
    rates = _rates() * (10 if not kwargs else 1)
    with pytest.raises(ValueError, match=msg):
        tf.quantify_if(_f_its(), rates, **kwargs)


def test_quantify_if_refuses_missing_and_many_rows():
    f = _f_its()
    with pytest.raises(ValueError, match="Missing: DA"):
        tf.quantify_if(f, _rates().drop(columns="DA"), time=1)
    with pytest.raises(ValueError, match="exactly one row"):
        tf.quantify_if(f, pd.concat([_rates(), _rates()]), time=1)


# --- stipulate(): equal to R ----------------------------------------------------

def _check_stipulate(out, ref):
    assert list(out.columns) == ref["columns"]
    levels = ref["levels"] if isinstance(ref["levels"], list) else [ref["levels"]]
    assert isinstance(out["scenario"].dtype, pd.CategoricalDtype)
    assert list(out["scenario"].cat.categories) == levels
    assert list(out["scenario"].astype(str)) == levels
    for col, vals in ref["values"].items():
        assert out[col].to_numpy() == pytest.approx(_num(vals), abs=1e-12), col


def test_stipulate_matches_r():
    out = tf.stipulate(_rates(), {"Fix A only": {"MN": 0.1}, "Fix B only": {"PO": 0.1},
                                  "Fix A and B": {"MN": 0.1, "PO": 0.1}})
    _check_stipulate(out, REF["stipulate"]["it_security_four"])
    _check_stipulate(tf.stipulate(_rates(), baseline=None, Half={"DA": 0.5, "WB": 2}),
                     REF["stipulate"]["it_security_no_baseline"])
    _check_stipulate(tf.stipulate({"A": 0.1, "B": 0.2}, {"B off": {"B": 0}}, baseline="As is"),
                     REF["stipulate"]["minimal_renamed"])


def test_stipulate_refuses_like_r():
    rates = pd.DataFrame({"A": [1.0], "B": [2.0]})
    with pytest.raises(ValueError, match="names events not in `data`: Z"):
        tf.stipulate(rates, {"Fix": {"Z": 0.1}})
    with pytest.raises(ValueError, match="at least one scenario"):
        tf.stipulate(rates)
    with pytest.raises(ValueError, match="named numeric vector"):
        tf.stipulate(rates, {"Fix": 0.1})
    with pytest.raises(ValueError, match="non-negative"):
        tf.stipulate(rates, {"Fix": {"A": -1}})
    with pytest.raises(ValueError, match="unique"):
        tf.stipulate(rates, {"Neither": {"A": 0.1}})
    with pytest.raises(ValueError, match="exactly one row"):
        tf.stipulate(pd.concat([rates, rates]), {"Fix": {"A": 0.1}})


# --- fluctuate(): shape, statistics and common random numbers ------------------

def test_fluctuate_shape_and_statistics():
    rates = pd.DataFrame({"A": [1.0], "B": [10.0]})
    out = tf.fluctuate(rates, n=20000, cv=0.2, seed=1)
    assert list(out.columns) == ["sim", "A", "B"]
    assert list(out["sim"]) == list(range(1, 20001))
    assert out["A"].mean() == pytest.approx(1, rel=0.01)
    assert out["B"].std() / out["B"].mean() == pytest.approx(0.2, rel=0.02)
    assert (tf.fluctuate(rates, n=1000, cv=2, seed=1)["A"] >= 0).all()
    assert (tf.fluctuate(rates, n=5, cv=0)["B"] == 10).all()


def test_fluctuate_is_reproducible():
    rates = pd.DataFrame({"A": [1.0], "B": [10.0]})
    pd.testing.assert_frame_equal(tf.fluctuate(rates, n=50, seed=3), tf.fluctuate(rates, n=50, seed=3))
    rng = np.random.default_rng(3)
    a = tf.fluctuate(rates, n=50, seed=rng)
    b = tf.fluctuate(rates, n=50, seed=rng)   # a Generator continues its stream
    assert not np.allclose(a["A"], b["A"])


def test_fluctuate_common_random_numbers():
    scen = tf.stipulate({"A": 1.0, "B": 10.0}, {"Fix A": {"A": 0.1}, "Fix B": {"B": 0.5}})
    out = tf.fluctuate(scen, n=100, seed=2)
    assert list(out.columns) == ["scenario", "sim", "A", "B"]
    assert len(out) == 300
    assert list(out["scenario"].cat.categories) == ["Neither", "Fix A", "Fix B"]
    assert list(out["scenario"].astype(str).unique()) == ["Neither", "Fix A", "Fix B"]
    neither = out[out["scenario"] == "Neither"].reset_index(drop=True)
    fix_a = out[out["scenario"] == "Fix A"].reset_index(drop=True)
    fix_b = out[out["scenario"] == "Fix B"].reset_index(drop=True)
    assert fix_a["A"].to_numpy() == pytest.approx(0.1 * neither["A"].to_numpy(), abs=1e-15)
    assert fix_a["B"].to_numpy() == pytest.approx(neither["B"].to_numpy(), abs=0)
    assert fix_b["B"].to_numpy() == pytest.approx(0.5 * neither["B"].to_numpy(), abs=1e-15)
    one = tf.fluctuate(pd.DataFrame({"A": [1.0], "B": [10.0]}), n=100, seed=2)
    assert neither[["sim", "A", "B"]].equals(one)


def test_fluctuate_refuses_like_r():
    rates = pd.DataFrame({"A": [1.0], "B": [10.0]})
    with pytest.raises(ValueError, match="exactly one row, or a `scenario` column"):
        tf.fluctuate(pd.concat([rates, rates]))
    with pytest.raises(ValueError, match="whole number"):
        tf.fluctuate(rates, n=0)
    with pytest.raises(ValueError, match="non-negative"):
        tf.fluctuate(rates, cv=-1)
    with pytest.raises(ValueError, match="non-negative"):
        tf.fluctuate(pd.DataFrame({"A": [-1.0]}))
    with pytest.raises(ValueError, match="data frame"):
        tf.fluctuate({"A": 1.0})
