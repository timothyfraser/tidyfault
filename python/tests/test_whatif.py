# python/tests/test_whatif.py
#
# quantify_if(), quantify_when() and quantify_ci() against R. quantify_if() and
# quantify_when(ci=False) are deterministic, so they must equal R's output in
# reference/r_reference.json to 1e-9. quantify_ci() draws from numpy, not R's
# random stream (README, "Deviations from R"), so it (and the ci=True paths) is
# tested on its shape, its statistics and its common-random-numbers property,
# not on identical draws.
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
    _check_quantify_if(tf.quantify_if(_f_its(), _rates(), cut=0.05, time=8760),
                       REF["quantify_if"]["it_security_rates_cut05_t8760"])


def test_quantify_if_subset_matches_r():
    _check_quantify_if(tf.quantify_if(_f_its(), _rates(), cut=0.9, time=43800, events=["PO", "MN"]),
                       REF["quantify_if"]["it_security_rates_cut90_t43800_PO_MN"])


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
    (dict(cut=0, time=8760), r"in \(0, 1\]"),
    (dict(cut=1.5, time=8760), r"in \(0, 1\]"),
    (dict(time=8760, events=["XX"]), "not basic events of `f`: XX"),
    (dict(time=-1), "single positive number"),
    (dict(), "If these are failure rates, pass `time`"),
])
def test_quantify_if_refuses_like_r(kwargs, msg):
    rates = _rates() * (1e5 if not kwargs else 1)
    with pytest.raises(ValueError, match=msg):
        tf.quantify_if(_f_its(), rates, **kwargs)


def test_quantify_if_refuses_missing_and_many_rows():
    f = _f_its()
    with pytest.raises(ValueError, match="Missing: DA"):
        tf.quantify_if(f, _rates().drop(columns="DA"), time=8760)
    with pytest.raises(ValueError, match="exactly one row"):
        tf.quantify_if(f, pd.concat([_rates(), _rates()]), time=8760)


def test_quantify_if_ci_adds_an_interval():
    f, rates = _f_its(), _rates()
    out = tf.quantify_if(f, rates, cut=0.9, time=8760, events=["MN", "PO"], ci=True, n=300, seed=4)
    exact = tf.quantify_if(f, rates, cut=0.9, time=8760, events=["MN", "PO"])
    assert list(out.columns) == ["event", "p_top", "baseline", "change", "pct_change", "lower", "upper"]
    pd.testing.assert_frame_equal(out[exact.columns], exact)
    assert ((out["lower"] < out["p_top"]) & (out["p_top"] < out["upper"])).all()
    mn = rates.copy()
    mn["MN"] = mn["MN"] * 0.1
    ref = tf.quantify_ci(f, mn, n=300, time=8760, seed=4)
    row = out[out["event"] == "MN"].iloc[0]
    assert row["lower"] == pytest.approx(ref["lower"].iloc[0], abs=1e-15)
    assert row["upper"] == pytest.approx(ref["upper"].iloc[0], abs=1e-15)
    with pytest.raises(ValueError, match="TRUE or FALSE"):
        tf.quantify_if(f, rates, time=8760, ci=None)


# --- quantify_when(ci=False): equal to R ---------------------------------------

def _check_when(out, ref):
    assert list(out.columns) == ref["columns"]
    assert list(out["scenario"].cat.categories) == ref["levels"]
    assert [str(x) for x in out["scenario"]] == ref["scenario"]
    for col in ["time", "p_top", "reliability"]:
        assert out[col].to_numpy() == pytest.approx(_num(ref[col]), abs=1e-9), col


def test_quantify_when_matches_r():
    f = _f_its()
    _check_when(tf.quantify_when(f, _rates(), {"Fix A only": {"MN": 0.1}, "Fix B only": {"PO": 0.1},
                                               "Fix A and B": {"MN": 0.1, "PO": 0.1}}, ci=False),
                REF["quantify_when"]["it_security_four_default_time"])
    _check_when(tf.quantify_when(f, _rates(), baseline=None, time=[8760, 43800],
                                 Half={"DA": 0.5, "WB": 2}, ci=False),
                REF["quantify_when"]["it_security_no_baseline"])
    _check_when(tf.quantify_when(_f_min(), {"A": 0.001, "B": 0.002}, {"B off": {"B": 0}},
                                 baseline="As is", time=[0, 100, 1000], ci=False),
                REF["quantify_when"]["minimal_renamed"])


def test_quantify_when_ci_shares_draws_with_quantify_ci():
    f, rates = _f_its(), _rates()
    out = tf.quantify_when(f, rates, {"Fix A": {"MN": 0.1}}, time=[8760, 17520], n=200, seed=5)
    assert list(out.columns) == ["scenario", "time", "p_top", "lower", "upper", "reliability"]
    assert out["reliability"].to_numpy() == pytest.approx(1 - out["p_top"].to_numpy())
    fixed = rates.copy()
    fixed["MN"] = fixed["MN"] * 0.1
    ref = tf.quantify_ci(f, fixed, time=[8760, 17520], n=200, seed=5)
    for col in ["p_top", "lower", "upper"]:
        assert out[col].to_numpy()[2:] == pytest.approx(ref[col].to_numpy(), abs=1e-15), col
    assert (out["p_top"].to_numpy()[2:] < out["p_top"].to_numpy()[:2]).all()


def test_quantify_when_default_time_is_ten_years_in_hours():
    out = tf.quantify_when(_f_its(), _rates(), {"Fix": {"MN": 0.1}}, ci=False)
    assert list(out["time"].unique()) == [float(h) for h in range(0, 87601, 4380)]
    assert (out.loc[out["time"] == 0, "p_top"] == 0).all()


def test_quantify_when_refuses_like_r():
    f, rates = _f_its(), _rates()
    with pytest.raises(ValueError, match="not basic events of `f`: Z"):
        tf.quantify_when(f, rates, {"Fix": {"Z": 0.1}})
    with pytest.raises(ValueError, match="at least one scenario"):
        tf.quantify_when(f, rates)
    with pytest.raises(ValueError, match="named numeric vector"):
        tf.quantify_when(f, rates, {"Fix": 0.1})
    with pytest.raises(ValueError, match="non-negative"):
        tf.quantify_when(f, rates, {"Fix": {"MN": -1}})
    with pytest.raises(ValueError, match="unique"):
        tf.quantify_when(f, rates, {"Neither": {"MN": 0.1}})
    with pytest.raises(ValueError, match="exactly one row"):
        tf.quantify_when(f, pd.concat([rates, rates]), {"Fix": {"MN": 0.1}})
    with pytest.raises(ValueError, match="Missing: DA"):
        tf.quantify_when(f, rates.drop(columns="DA"), {"Fix": {"MN": 0.1}})
    with pytest.raises(ValueError, match="non-negative"):
        tf.quantify_when(f, rates, {"Fix": {"MN": 0.1}}, time=[-1])
    with pytest.raises(ValueError, match="TRUE or FALSE"):
        tf.quantify_when(f, rates, {"Fix": {"MN": 0.1}}, ci="yes")


# --- quantify_ci(): shape, statistics and common random numbers ----------------

def test_quantify_ci_summarizes_the_draws():
    f, rates = _f_its(), _rates()
    out = tf.quantify_ci(f, rates, time=8760, n=500, seed=1)
    long = tf.quantify_ci(f, rates, time=8760, n=500, seed=1, draws=True)
    assert list(out.columns) == ["time", "p_top", "lower", "upper"]
    assert list(long.columns) == ["time", "sim", "p_top"]
    assert list(long["sim"]) == list(range(1, 501))
    assert out["p_top"].iloc[0] == pytest.approx(long["p_top"].median(), abs=1e-15)
    assert out["lower"].iloc[0] == pytest.approx(long["p_top"].quantile(0.05), abs=1e-15)
    assert out["upper"].iloc[0] == pytest.approx(long["p_top"].quantile(0.95), abs=1e-15)
    point = float(tf.quantify(f, newdata=-np.expm1(-rates * 8760), prob=True))
    assert tf.quantify_ci(f, rates, time=8760, n=3, cv=0)["p_top"].iloc[0] == pytest.approx(point, abs=1e-12)
    assert out["p_top"].iloc[0] == pytest.approx(point, rel=0.1)
    wide = tf.quantify_ci(f, rates, time=8760, n=500, seed=1, level=0.5)
    assert wide["lower"].iloc[0] > out["lower"].iloc[0] and wide["upper"].iloc[0] < out["upper"].iloc[0]


def test_quantify_ci_draws_normal_noise_event_by_event():
    f = _f_its()
    probs = tf.load_data("it_security_probs")
    z = np.random.default_rng(3).standard_normal(size=(50, probs.shape[1]))
    drawn = np.minimum(np.maximum(1 + 0.2 * z, 0) * probs.to_numpy(dtype=float)[0], 1)
    long = tf.quantify_ci(f, probs, n=50, cv=0.2, seed=3, draws=True)
    want = tf.quantify(f, newdata=pd.DataFrame(drawn, columns=probs.columns), prob=True)
    assert long["p_top"].to_numpy() == pytest.approx(np.asarray(want), abs=1e-15)
    pd.testing.assert_frame_equal(tf.quantify_ci(f, probs.iloc[0], n=50, seed=3, draws=True), long)
    # A Generator continues its stream, as in R without a seed.
    rng = np.random.default_rng(9)
    a = tf.quantify_ci(f, probs, n=20, seed=rng, draws=True)
    b = tf.quantify_ci(f, probs, n=20, seed=rng, draws=True)
    assert not np.allclose(a["p_top"], b["p_top"])


def test_quantify_ci_common_random_numbers():
    f, rates = _f_its(), _rates()
    fixed = rates.copy()
    fixed["MN"] = fixed["MN"] * 0.1
    scen = pd.concat([rates, fixed], ignore_index=True)
    scen.insert(0, "scenario", pd.Categorical(["Neither", "Fix A"], categories=["Neither", "Fix A"]))
    out = tf.quantify_ci(f, scen, time=[8760, 43800], n=200, seed=2)
    assert list(out.columns) == ["scenario", "time", "p_top", "lower", "upper"]
    assert [str(s) for s in out["scenario"]] == ["Neither", "Neither", "Fix A", "Fix A"]
    assert list(out["scenario"].cat.categories) == ["Neither", "Fix A"]
    assert list(out["time"]) == [8760, 43800, 8760, 43800]
    one = tf.quantify_ci(f, fixed, time=8760, n=200, seed=2)
    for col in ["p_top", "lower", "upper"]:
        assert out[col].iloc[2] == pytest.approx(one[col].iloc[0], abs=1e-15)
    grid = scen.iloc[[0, 0, 1, 1]].reset_index(drop=True)
    grid["time"] = [8760.0, 43800.0, 8760.0, 43800.0]
    pd.testing.assert_frame_equal(tf.quantify_ci(f, grid, n=200, seed=2), out)
    long = tf.quantify_ci(f, scen, time=8760, n=200, seed=2, draws=True)
    assert list(long.columns) == ["scenario", "time", "sim", "p_top"]
    assert len(long) == 400
    a = long.loc[long["scenario"] == "Fix A", "p_top"].to_numpy()
    b = long.loc[long["scenario"] == "Neither", "p_top"].to_numpy()
    assert (a <= b).all()


@pytest.mark.parametrize("kwargs, msg", [
    (dict(time=-1), "non-negative"),
    (dict(time=1, n=0), "whole number"),
    (dict(time=1, cv=-1), "non-negative"),
    (dict(time=1, level=0), "level"),
    (dict(time=1, draws=None), "TRUE or FALSE"),
    (dict(), "If these are failure rates, pass `time`"),
])
def test_quantify_ci_refuses_like_r(kwargs, msg):
    rates = _rates() * (1e5 if not kwargs else 1)
    with pytest.raises(ValueError, match=msg):
        tf.quantify_ci(_f_its(), rates, **kwargs)


def test_quantify_ci_refuses_bad_data():
    f, rates = _f_its(), _rates()
    with pytest.raises(ValueError, match="Missing: DA"):
        tf.quantify_ci(f, rates.drop(columns="DA"), time=1)
    with pytest.raises(ValueError, match="already has a `time`"):
        tf.quantify_ci(f, rates.assign(time=1.0), time=1)
    with pytest.raises(ValueError, match="no rows"):
        tf.quantify_ci(f, rates.iloc[0:0], time=1)
    with pytest.raises(ValueError, match="data frame"):
        tf.quantify_ci(f, "MN")
