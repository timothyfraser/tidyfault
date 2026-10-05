"""R's quantify_when(): what-if scenarios followed over time, with common random
numbers across every scenario and time when ci=True."""

from __future__ import annotations

import numpy as np
import pandas as pd

from ._values import is_one_row_like, one_row_values
from .formulate import formal_args
from .quantify_ci import _evaluate, _valid_times, quantify_ci


def scenario_table(values, items, baseline="Neither"):
    """R's internal scenario_table(): an unchanged baseline row first (unless
    ``baseline`` is None), then one row per named scenario of multipliers.
    ``items`` is a list of ``(label, multipliers)`` pairs."""
    if not items:
        raise ValueError("Give quantify_when() at least one scenario, e.g. "
                         "quantify_when(f, data, \"Fix A\" = c(MN = 0.1)).")
    labels = [k for k, _ in items]
    if any(not isinstance(k, str) or k == "" for k in labels):
        raise ValueError("Every scenario in `...` needs a name, e.g. \"Fix A\" = c(MN = 0.1).")
    if baseline is not None and (not isinstance(baseline, str) or baseline == ""):
        raise ValueError("`baseline` must be a single non-empty name, or NULL to leave the "
                         "baseline row out.")
    all_labels = ([baseline] if baseline is not None else []) + labels
    dup = sorted({k for k in all_labels if all_labels.count(k) > 1}, key=all_labels.index)
    if dup:
        raise ValueError("Scenario names must be unique (the baseline counts). Repeated: "
                         + ", ".join(dup) + ".")

    rows = [values.to_numpy(dtype=float)] if baseline is not None else []
    for label, m in items:
        if isinstance(m, pd.Series):
            m = m.to_dict()
        if not isinstance(m, dict) or len(m) == 0 or any(not isinstance(k, str) or k == "" for k in m):
            raise ValueError(f"Scenario \"{label}\" must be a named numeric vector of multipliers, "
                             "e.g. c(MN = 0.1).")
        try:
            mult = {k: float(v) for k, v in m.items()}
        except (TypeError, ValueError):
            raise ValueError(f"Scenario \"{label}\" must be a named numeric vector of multipliers, "
                             "e.g. c(MN = 0.1).") from None
        unknown = [k for k in mult if k not in values.index]
        if unknown:
            raise ValueError(f"Scenario \"{label}\" names events that are not basic events of `f`: "
                             + ", ".join(unknown) + ". Choose from: "
                             + ", ".join(values.index) + ".")
        if any(not np.isfinite(v) or v < 0 for v in mult.values()):
            raise ValueError(f"Scenario \"{label}\" multipliers must be finite and non-negative.")
        v = values.copy()
        for k, x in mult.items():
            v[k] = v[k] * x
        rows.append(v.to_numpy(dtype=float))

    out = pd.DataFrame(np.vstack(rows), columns=list(values.index))
    out.insert(0, "scenario", pd.Categorical(all_labels, categories=all_labels))
    return out


# R's default time grid, seq(0, 87600, by = 4380): 0 to 10 years in half-year
# steps, in hours.
DEFAULT_TIME = tuple(float(h) for h in range(0, 87600 + 1, 4380))


def quantify_when(f, data, /, scenarios=None, time=DEFAULT_TIME, baseline="Neither", ci=True,
                  n=1000, cv=0.2, level=0.90, seed=None, **kwargs):
    """When does it fail, and what if we fix something?

    Builds what-if scenarios from one row of failure rates, each scenario
    multiplying the rates of some basic events by a factor (for example 0.1
    for a fix that removes 90% of a component's failures), and follows the
    probability of the top event over time for every scenario, with an
    uncertainty interval.

    Parameters
    ----------
    f : Formula
        From ``formulate()``, with one argument per basic event.
    data : DataFrame, Series or dict
        One row of failure rates (events per hour, by default), one per basic
        event of ``f``. Extra columns are ignored.
    scenarios : dict
        Named scenarios in order, ``{"Fix A only": {"MN": 0.1}, ...}``: each a
        dict (or Series) of multipliers, ``{event: factor}``. Events a scenario
        does not name keep their rate. This is R's ``...``; pass it by
        position or as ``scenarios=``.
    time : float or list
        The times to evaluate, in the unit of the rates: one or more finite,
        non-negative numbers. The default, 0 to 87,600 by 4,380 (R's
        ``seq(0, 87600, by = 4380)``), is 0 to 10 years in half-year steps, in
        hours (the reliability-engineering convention; 8,760 hours is one
        year).
    baseline : str or None
        The name of the unchanged scenario placed first. Default ``"Neither"``.
        None leaves it out.
    ci : bool
        True (default) adds an uncertainty interval from ``quantify_ci()``;
        False returns the exact point estimate only and ignores ``n``, ``cv``,
        ``level`` and ``seed``.
    n, cv, level, seed
        Passed to ``quantify_ci()`` when ``ci=True``.
    **kwargs
        More named scenarios, as in R: ``quantify_when(f, rates, fix_a={"MN": 0.1})``.
        They follow those in ``scenarios``. A scenario named like an argument
        (``time``, ``ci``, ...) has to go in ``scenarios``.

    Returns
    -------
    DataFrame
        One row per scenario and time (the baseline first, then the scenarios
        in the order given; times in the order given): ``scenario`` (a
        Categorical in that order), ``time``, ``p_top`` (with ``ci=True`` the
        median across the draws, with ``ci=False`` the exact value), ``lower``
        and ``upper`` (only with ``ci=True``) and ``reliability``
        (``1 - p_top``).

    Notes
    -----
    Every scenario and every time shares the same random draws (common random
    numbers), so the gaps between the scenarios come from the fixes, not from
    noise.

    Examples
    --------
    >>> import tidyfault as tf
    >>> f = tf.formulate(tf.equate(tf.curate(tf.data.it_security_nodes, tf.data.it_security_edges)))
    >>> r = tf.data.it_security_outcomes_rates
    >>> rates = dict(zip(r["event"], r["lambda"]))
    >>> tf.quantify_when(f, rates, {"Fix A only": {"MN": 0.1},
    ...                             "Fix B only": {"PO": 0.1},
    ...                             "Fix A and B": {"MN": 0.1, "PO": 0.1}},
    ...                  n=200, seed=1)                                   # doctest: +SKIP
    """
    if not callable(f):
        raise ValueError("`f` must be a function from formulate().")
    fargs = formal_args(f)
    if not is_one_row_like(data):
        raise ValueError("`data` must be a one-row data frame or a named numeric vector, "
                         "one rate per basic event.")
    have = list(data.columns) if isinstance(data, pd.DataFrame) else list(data.keys())
    missing = [a for a in fargs if a not in have]
    if missing:
        raise ValueError("`data` must have a column for every basic event of `f`. Missing: "
                         + ", ".join(missing) + ".")
    # Keep data's column order (it fixes the order of the random draws); extra
    # columns (an id, a label) are ignored.
    keep = [c for c in have if c in fargs]
    sub = data[keep] if isinstance(data, pd.DataFrame) else {a: data[a] for a in keep}
    values = one_row_values(sub, "data", "quantify_when")
    neg = [k for k, v in values.items() if v < 0]
    if neg:
        raise ValueError("`data` values must be non-negative. Negative: " + ", ".join(neg) + ".")

    if time is None or not _valid_times(time):
        raise ValueError("`time` must be one or more finite, non-negative numbers (hours, by default).")
    time = np.atleast_1d(np.asarray(time, dtype=float))
    if not isinstance(ci, (bool, np.bool_)):
        raise ValueError("`ci` must be TRUE or FALSE.")

    items = []
    if scenarios is not None:
        if not isinstance(scenarios, dict):
            raise ValueError("Every scenario in `...` needs a name, e.g. \"Fix A\" = c(MN = 0.1).")
        items += list(scenarios.items())
    items += list(kwargs.items())
    table = scenario_table(values, items, baseline=baseline)

    grid = table.iloc[np.repeat(np.arange(len(table)), len(time))].reset_index(drop=True)
    grid["time"] = np.tile(time, len(table))

    if ci:
        out = quantify_ci(f, grid, n=n, cv=cv, level=level, seed=seed)
    else:
        events = list(values.index)
        probs = -np.expm1(-grid[events].to_numpy(dtype=float) * grid[["time"]].to_numpy())
        out = pd.DataFrame({"scenario": grid["scenario"], "time": grid["time"],
                            "p_top": _evaluate(f, probs, events)})
    out["reliability"] = 1 - out["p_top"]
    return out
