"""R's fluctuate(): uncertainty draws around failure rates (or probabilities),
with common random numbers across the scenarios of a stipulate() table."""

from __future__ import annotations

import numpy as np
import pandas as pd


def fluctuate(data, n=1000, cv=0.2, seed=None):
    """Draw uncertainty around failure rates (or probabilities).

    We rarely know a failure rate exactly, so ``fluctuate()`` draws ``n``
    plausible values for each basic event from a Normal centred on its
    estimate, with a standard deviation of ``cv`` times the estimate, floored
    at zero.

    Parameters
    ----------
    data : DataFrame
        Either one row of values, one column per basic event, or a scenario
        table from ``stipulate()``: a ``scenario`` column plus one column per
        basic event, one row per scenario.
    n : int
        The number of draws (simulations) per scenario. Default 1000.
    cv : float
        The coefficient of variation: each draw's standard deviation as a share
        of its value. Default 0.2 (+/- 20%). Use 0 for no uncertainty.
    seed : int, numpy Generator or None
        Passed to ``numpy.random.default_rng()``, so an int makes the draws
        reproducible and a Generator continues its own stream. Default None.
        The draws come from numpy, not R's random stream, so the same seed gives
        different (but equally distributed) draws in R and Python.

    Returns
    -------
    DataFrame
        ``n`` rows per scenario: ``scenario`` (if ``data`` has it, a Categorical
        as in ``data``), ``sim`` (1 to ``n``), then one column per basic event
        holding the drawn values. Rows are ordered by scenario, then ``sim``.

    Notes
    -----
    For each event and simulation one standard Normal value ``z`` gives the
    noise factor ``max(1 + cv * z, 0)``; each value is multiplied by it, which
    is the same as drawing from Normal(value, cv * value) floored at zero.

    Common random numbers: with a scenario table, every scenario reuses the
    same noise factors, so simulation 5 of "Fix A" and simulation 5 of
    "Neither" share one draw per event. Each scenario keeps its own spread, but
    the differences between scenarios come only from the scenarios, not from
    different random draws, which makes comparisons much sharper for the same
    ``n``.

    The draws are not capped above: if ``data`` holds probabilities a draw can
    exceed 1, so fluctuate rates and convert them afterwards, or clip at 1.

    Examples
    --------
    >>> import tidyfault as tf
    >>> r = tf.data.it_security_outcomes_rates
    >>> rates = dict(zip(r["event"], r["lambda"]))
    >>> tf.fluctuate(pd.DataFrame([rates]), n=1000, cv=0.2, seed=1)                 # doctest: +SKIP
    >>> tf.fluctuate(tf.stipulate(rates, {"Fix A": {"MN": 0.1}}), n=200, seed=1)  # doctest: +SKIP
    """
    if not isinstance(data, pd.DataFrame):
        raise ValueError("`data` must be a one-row data frame of values, or a scenario table "
                         "from stipulate().")
    has_scenario = "scenario" in data.columns
    if not has_scenario and len(data) != 1:
        raise ValueError("`data` must have exactly one row, or a `scenario` column (from "
                         f"stipulate()); it has {len(data)} rows and no `scenario` column.")
    if len(data) == 0:
        raise ValueError("`data` has no rows.")
    if "sim" in data.columns:
        raise ValueError("`data` already has a `sim` column; fluctuate() adds it.")

    events = [c for c in data.columns if c != "scenario"]
    if not events:
        raise ValueError("`data` has no event columns to fluctuate.")
    not_num = [str(c) for c in events if not pd.api.types.is_numeric_dtype(data[c])
               or pd.api.types.is_bool_dtype(data[c])]
    if not_num:
        raise ValueError("`data` event columns must be numeric. Not numeric: "
                         + ", ".join(not_num) + ".")
    values = data[events].to_numpy(dtype=float)
    if not np.all(np.isfinite(values)) or np.any(values < 0):
        raise ValueError("`data` values must be finite and non-negative.")

    if (isinstance(n, bool) or not isinstance(n, (int, float, np.number)) or not np.isfinite(n)
            or n < 1 or n != round(n)):
        raise ValueError("`n` must be a single whole number >= 1, the number of draws.")
    n = int(n)
    if (isinstance(cv, bool) or not isinstance(cv, (int, float, np.number)) or not np.isfinite(cv)
            or cv < 0):
        raise ValueError("`cv` must be a single non-negative number (0.2 means +/- 20%).")
    rng = np.random.default_rng(seed)

    # One noise factor per sim (row) x event (column). Every scenario row
    # reuses these same factors: common random numbers.
    z = rng.standard_normal(size=(n, len(events)))
    noise = np.maximum(1 + cv * z, 0)
    draws = np.vstack([noise * values[r] for r in range(values.shape[0])])

    out = pd.DataFrame(draws, columns=events)
    out.insert(0, "sim", np.tile(np.arange(1, n + 1, dtype="int64"), values.shape[0]))
    if has_scenario:
        out.insert(0, "scenario", np.repeat(data["scenario"].to_numpy(), n))
        if isinstance(data["scenario"].dtype, pd.CategoricalDtype):
            out["scenario"] = pd.Categorical(out["scenario"],
                                             categories=data["scenario"].cat.categories)
    return out
