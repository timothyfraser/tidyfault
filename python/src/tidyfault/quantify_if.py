"""R's quantify_if(): which fix buys the most? Cut each basic event's failure
rate (or probability) by the same share in turn and measure the drop in the
probability of the top event."""

from __future__ import annotations

import numpy as np
import pandas as pd

from ._values import is_one_row_like, one_row_values
from .formulate import formal_args
from .quantify import quantify


def quantify_if(f, data, cut=0.05, time=None, events=None):
    """Which fix buys the most? A one-at-a-time sensitivity analysis of the top event.

    Cuts the failure rate (or probability) of each basic event in turn by the
    same share, keeps every other event as it is, and measures how much the
    probability of the top event drops.

    Parameters
    ----------
    f : Formula
        From ``formulate()``, with one argument per basic event.
    data : DataFrame, Series or dict
        One row of values, one per basic event of ``f`` (extra columns are
        ignored). With ``time``, the values are failure rates (events per unit
        of time); without it, failure probabilities.
    cut : float
        The share to cut each value by, in (0, 1]: each event's value is
        multiplied by ``1 - cut``. Default 0.05 (a 5% cut). ``cut=1`` removes
        the event entirely.
    time : float or None
        If given (a positive number), ``data`` holds failure rates and each
        (cut) rate becomes the probability of failing by ``time``,
        ``1 - exp(-rate * time)`` (R's ``pexp(time, rate)``). If None
        (default), ``data`` holds probabilities and is used as is.
    events : list of str or None
        The basic events to cut. Default None cuts every basic event of ``f``,
        in ``formal_args(f)`` order.

    Returns
    -------
    DataFrame
        One row per cut event, sorted by ``pct_change`` from the biggest drop to
        the smallest (ties keep the order of ``events``), with columns
        ``event``, ``p_top`` (after the cut), ``baseline`` (no cut, the same in
        every row), ``change`` (``p_top - baseline``) and ``pct_change``
        (``100 * (p_top / baseline - 1)``).

    Notes
    -----
    The baseline and every what-if go through ``quantify(f, prob=True)`` in
    one call, so the exact (truth-table) probability is used throughout. The
    cut is applied before any conversion: with ``time``, the rate is cut and
    then turned into a probability, which is what a fix to a component does.

    Examples
    --------
    >>> import tidyfault as tf
    >>> f = tf.formulate(tf.equate(tf.curate(tf.data.it_security_nodes, tf.data.it_security_edges)))
    >>> r = tf.data.it_security_outcomes_rates
    >>> rates = dict(zip(r["event"], r["lambda"]))
    >>> tf.quantify_if(f, rates, cut=0.05, time=1)                       # doctest: +SKIP
    >>> tf.quantify_if(f, rates, cut=0.9, time=1, events=["MN", "PO"])   # doctest: +SKIP
    >>> tf.quantify_if(f, tf.data.it_security_probs)                     # doctest: +SKIP
    """
    if not callable(f):
        raise ValueError("`f` must be a function from formulate().")
    fargs = formal_args(f)
    if not is_one_row_like(data):
        raise ValueError("`data` must be a one-row data frame or a named numeric vector, "
                         "one value per basic event.")
    have = list(data.columns) if isinstance(data, pd.DataFrame) else list(data.keys())
    missing = [a for a in fargs if a not in have]
    if missing:
        raise ValueError("`data` must have a column for every basic event of `f`. Missing: "
                         + ", ".join(missing) + ".")
    # Extra columns (an id, a label) are ignored.
    sub = data[fargs] if isinstance(data, pd.DataFrame) else {a: data[a] for a in fargs}
    values = one_row_values(sub, "data", "quantify_if")

    if events is None:
        events = list(fargs)
    else:
        if isinstance(events, str):
            events = [events]
        events = list(events)
        if len(events) == 0 or not all(isinstance(e, str) for e in events):
            raise ValueError("`events` must be a character vector of basic event names, "
                             "or NULL for all of them.")
        unknown = [e for e in events if e not in fargs]
        if unknown:
            raise ValueError("`events` names events that are not basic events of `f`: "
                             + ", ".join(unknown) + ". Choose from: " + ", ".join(fargs) + ".")
        dup = sorted({e for e in events if events.count(e) > 1}, key=events.index)
        if dup:
            raise ValueError("`events` must not repeat an event: " + ", ".join(dup) + ".")

    if (isinstance(cut, bool) or not isinstance(cut, (int, float, np.number))
            or not np.isfinite(cut) or cut <= 0 or cut > 1):
        raise ValueError("`cut` must be a single number in (0, 1], the share to cut each value by "
                         "(0.05 cuts it by 5%).")
    if time is not None and (isinstance(time, bool) or not isinstance(time, (int, float, np.number))
                             or not np.isfinite(time) or time <= 0):
        raise ValueError("`time` must be a single positive number, or NULL when `data` holds "
                         "probabilities.")

    neg = [n for n, v in values.items() if v < 0]
    if neg:
        raise ValueError("`data` values must be non-negative. Negative: " + ", ".join(neg) + ".")
    if time is None:
        above = [n for n, v in values.items() if v > 1]
        if above:
            raise ValueError("Without `time`, `data` must hold probabilities in [0, 1]. Above 1: "
                             + ", ".join(above) + ". If these are failure rates, pass `time`.")

    # Row 0 is the baseline; row i + 1 cuts events[i] alone.
    m = np.tile(values.to_numpy(dtype=float), (len(events) + 1, 1))
    for i, e in enumerate(events):
        j = fargs.index(e)
        m[i + 1, j] = m[i + 1, j] * (1 - cut)
    if time is not None:
        m = -np.expm1(-m * time)   # R's pexp(time, rate)

    p = np.atleast_1d(quantify(f, newdata=pd.DataFrame(m, columns=fargs), prob=True)).astype(float)
    baseline = p[0]
    out = pd.DataFrame({
        "event": events,
        "p_top": p[1:],
        "baseline": baseline,
        "change": p[1:] - baseline,
        "pct_change": 100 * (p[1:] / baseline - 1),
    })
    return out.sort_values("pct_change", kind="stable").reset_index(drop=True)
