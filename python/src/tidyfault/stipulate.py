"""R's stipulate(): a table of what-if scenarios, one row per scenario, built
from one row of failure rates and named multipliers."""

from __future__ import annotations

import numpy as np
import pandas as pd

from ._values import one_row_values


def stipulate(data, scenarios=None, /, baseline="Neither", **kwargs):
    """Build a table of what-if scenarios.

    Each scenario multiplies the failure rates (or probabilities) of some basic
    events by a factor, for example 0.1 for a fix that removes 90% of a
    component's failures, and keeps every other event as it is. An unchanged
    baseline row comes first.

    Parameters
    ----------
    data : DataFrame, Series or dict
        One row of values, one per basic event. Usually failure rates, but any
        non-negative values work.
    scenarios : dict, optional
        Named scenarios in order, ``{"Fix A only": {"MN": 0.1}, ...}``: each a
        dict (or Series) of multipliers, ``{event: factor}``. Events a scenario
        does not name keep their value. This is R's ``...``; names with spaces
        go here (or through ``**{"Fix A": {...}}``).
    baseline : str or None
        The name of the unchanged row placed first. Default ``"Neither"``.
        ``None`` leaves the baseline row out.
    **kwargs
        More named scenarios, as in R: ``stipulate(rates, fix_a={"MN": 0.1})``.
        They follow those in ``scenarios``.

    Returns
    -------
    DataFrame
        One row per scenario (the baseline first, then the scenarios in the
        order given). Its first column, ``scenario``, is a Categorical whose
        categories follow that order (R's factor levels); then one column per
        value of ``data``, holding that scenario's values.

    Notes
    -----
    Multipliers are applied to the values as they are. For rates, 0.1 means the
    event happens a tenth as often; convert to probabilities afterwards. Pass
    the result to ``fluctuate()`` to add uncertainty, with every scenario
    sharing the same random draws.

    Examples
    --------
    >>> import tidyfault as tf
    >>> r = tf.data.it_security_outcomes_rates
    >>> rates = dict(zip(r["event"], r["lambda"]))
    >>> tf.stipulate(rates, {"Fix A only": {"MN": 0.1},
    ...                      "Fix B only": {"PO": 0.1},
    ...                      "Fix A and B": {"MN": 0.1, "PO": 0.1}})   # doctest: +SKIP
    """
    values = one_row_values(data, "data", "stipulate")
    if "scenario" in values.index:
        raise ValueError("`data` already has a `scenario` column; give stipulate() one row of "
                         "values without it.")

    items = []
    if scenarios is not None:
        if not isinstance(scenarios, dict):
            raise ValueError("Every scenario in `...` needs a name, e.g. \"Fix A\" = c(MN = 0.1).")
        items += list(scenarios.items())
    items += list(kwargs.items())
    if not items:
        raise ValueError("Give stipulate() at least one scenario, e.g. "
                         "stipulate(data, \"Fix A\" = c(MN = 0.1)).")
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
            raise ValueError(f"Scenario \"{label}\" names events not in `data`: "
                             + ", ".join(unknown) + ". `data` has: "
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
