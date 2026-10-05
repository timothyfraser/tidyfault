"""R's quantify_ci(): an uncertainty interval around the probability of the top
event, with common random numbers across every row (scenario, time)."""

from __future__ import annotations

import numpy as np
import pandas as pd

from .formulate import formal_args
from .quantify import quantify

# quantify() checks every possible state of the tree for every row. With many
# basic events and tens of thousands of draws that is a large array, so the
# draws go through in chunks of rows: the same answer, lighter on memory (this
# matters in the browser).
_CHUNK = 1000


def _is_number(x):
    return not isinstance(x, (bool, np.bool_)) and isinstance(x, (int, float, np.number))


def _valid_times(x):
    a = np.atleast_1d(np.asarray(x))
    if a.size == 0 or a.dtype == bool or not np.issubdtype(a.dtype, np.number):
        return False
    a = a.astype(float)
    return bool(np.all(np.isfinite(a)) and np.all(a >= 0))


def check_ci_args(n, cv, level, seed):
    """R's internal check_ci_args(): the uncertainty arguments shared by
    quantify_ci(), quantify_if() and quantify_when()."""
    if not _is_number(n) or not np.isfinite(n) or n < 1 or n != round(n):
        raise ValueError("`n` must be a single whole number >= 1, the number of draws.")
    if not _is_number(cv) or not np.isfinite(cv) or cv < 0:
        raise ValueError("`cv` must be a single non-negative number (0.2 means +/- 20%).")
    if not _is_number(level) or not np.isfinite(level) or level <= 0 or level >= 1:
        raise ValueError("`level` must be a single number in (0, 1), the coverage of the interval "
                         "(0.90 gives the 5th to 95th percentiles).")
    if seed is not None and not isinstance(seed, np.random.Generator) and (
            not _is_number(seed) or not np.isfinite(seed)):
        raise ValueError("`seed` must be a single number, or NULL.")


def _evaluate(f, big, events):
    """P(top) for every row of the matrix ``big`` (columns = events), in chunks."""
    out = [np.atleast_1d(quantify(f, newdata=pd.DataFrame(big[i:i + _CHUNK], columns=events),
                                  prob=True)).astype(float)
           for i in range(0, big.shape[0], _CHUNK)]
    return np.concatenate(out)


def quantify_ci(f, data, n=1000, cv=0.2, time=None, level=0.90, seed=None, draws=False):
    """An uncertainty interval around the probability of the top event.

    We rarely know a failure rate exactly, so ``quantify_ci()`` draws ``n``
    plausible values for each basic event from a Normal centred on its
    estimate (standard deviation ``cv`` times the estimate, floored at zero),
    evaluates the top event for every draw, and reports the median and the
    central ``level`` interval. It is the uncertainty engine behind
    ``quantify_if(ci=True)`` and ``quantify_when(ci=True)``.

    Parameters
    ----------
    f : Formula
        From ``formulate()``, with one argument per basic event.
    data : DataFrame, Series or dict
        One or more rows of values, one column per basic event of ``f`` (a
        Series or dict is one row). With ``time`` (or a ``time`` column) the
        values are failure rates (events per hour, by default); without it,
        failure probabilities. An optional ``scenario`` column and an optional
        ``time`` column pass through to the result; other extra columns are
        ignored.
    n : int
        The number of draws (simulated worlds) per row. Default 1000.
    cv : float
        The coefficient of variation: each draw's standard deviation as a share
        of its value. Default 0.2 (+/- 20%). Use 0 for no uncertainty.
    time : float, list or None
        One or more non-negative times, in the unit of the rates (hours, the
        reliability-engineering convention; 8,760 hours is one year). If given,
        ``data`` holds failure rates, every row is evaluated at every time, and
        each drawn rate becomes ``1 - exp(-rate * time)`` (R's
        ``pexp(time, rate)``). Leave it None when ``data`` already has a
        ``time`` column, or holds probabilities.
    level : float
        The coverage of the interval, in (0, 1). Default 0.90: ``lower`` and
        ``upper`` are the 5th and 95th percentiles of the draws.
    seed : int, numpy Generator or None
        Passed to ``numpy.random.default_rng()``, so an int makes the draws
        reproducible and a Generator continues its own stream. Default None.
        The draws come from numpy, not R's random stream, so the same seed gives
        different (but equally distributed) draws in R and Python.
    draws : bool
        False (default) returns one summary row per input row (and time). True
        returns every draw instead.

    Returns
    -------
    DataFrame
        With ``draws=False``, one row per row of ``data`` (times each value of
        ``time``), in that order: ``scenario`` (if ``data`` has it; a
        Categorical stays one), ``time`` (when the values are rates), ``p_top``
        (the median across the draws), ``lower`` and ``upper`` (the central
        ``level`` interval; numpy's linear quantile, R's type 7). With
        ``draws=True``, ``n`` rows per input row: ``scenario`` and ``time`` as
        above, ``sim`` (1 to ``n``) and ``p_top`` for that draw.

    Notes
    -----
    For each event and draw one standard Normal value ``z`` gives the noise
    factor ``max(1 + cv * z, 0)``; each value is multiplied by it. Drawn
    probabilities are capped at 1; drawn rates need no cap.

    Common random numbers: the ``n`` by events noise matrix is drawn once, and
    every row of ``data`` (every scenario, every time) reuses it, so the
    differences between rows come only from the rows themselves. The noise is
    drawn as one ``(n, events)`` array, events in the order their columns
    appear in ``data``.

    Examples
    --------
    >>> import tidyfault as tf
    >>> f = tf.formulate(tf.equate(tf.curate(tf.data.it_security_nodes, tf.data.it_security_edges)))
    >>> r = tf.data.it_security_outcomes_rates
    >>> rates = dict(zip(r["event"], r["lambda"]))
    >>> tf.quantify_ci(f, rates, time=8760, seed=1)                        # doctest: +SKIP
    >>> tf.quantify_ci(f, rates, time=[8760, 17520, 43800], seed=1)        # doctest: +SKIP
    >>> tf.quantify_ci(f, rates, time=8760, n=200, seed=1, draws=True)     # doctest: +SKIP
    """
    if not callable(f):
        raise ValueError("`f` must be a function from formulate().")
    fargs = formal_args(f)
    if isinstance(data, (pd.Series, dict)):
        data = pd.DataFrame([dict(data)])
    if not isinstance(data, pd.DataFrame):
        raise ValueError("`data` must be a data frame (one row per scenario) or a named numeric "
                         "vector, one value per basic event.")
    if len(data) == 0:
        raise ValueError("`data` has no rows.")
    missing = [a for a in fargs if a not in data.columns]
    if missing:
        raise ValueError("`data` must have a column for every basic event of `f`. Missing: "
                         + ", ".join(missing) + ".")
    # The events in the order their columns appear in `data`: this fixes which
    # column of noise goes to which event, so the same seed gives the same draws.
    events = [c for c in data.columns if c in fargs]
    not_num = [str(c) for c in events if not pd.api.types.is_numeric_dtype(data[c])
               or pd.api.types.is_bool_dtype(data[c])]
    if not_num:
        raise ValueError("`data` event columns must be numeric. Not numeric: "
                         + ", ".join(not_num) + ".")
    values = data[events].to_numpy(dtype=float)
    if not np.all(np.isfinite(values)) or np.any(values < 0):
        raise ValueError("`data` values must be finite and non-negative.")

    has_scenario = "scenario" in data.columns
    has_time = "time" in data.columns and "time" not in fargs
    if has_time and time is not None:
        raise ValueError("`data` already has a `time` column; leave `time` NULL, or drop the column.")
    if time is not None and not _valid_times(time):
        raise ValueError("`time` must be one or more finite, non-negative numbers (hours, by "
                         "default), or NULL when `data` holds probabilities.")
    if has_time and not _valid_times(data["time"].to_numpy()):
        raise ValueError("The `time` column of `data` must hold finite, non-negative numbers.")
    rates = has_time or time is not None
    if not rates and np.any(values > 1):
        above = [e for j, e in enumerate(events) if np.any(values[:, j] > 1)]
        raise ValueError("Without `time`, `data` must hold probabilities in [0, 1]. Above 1: "
                         + ", ".join(above) + ". If these are failure rates, pass `time`.")

    check_ci_args(n, cv, level, seed)
    if not isinstance(draws, (bool, np.bool_)):
        raise ValueError("`draws` must be TRUE or FALSE.")
    n = int(n)

    # The rows to evaluate: every row of `data`, crossed with `time` if given.
    if time is not None:
        tt = np.atleast_1d(np.asarray(time, dtype=float))
        row = np.repeat(np.arange(len(data)), len(tt))
        t = np.tile(tt, len(data))
    else:
        row = np.arange(len(data))
        t = data["time"].to_numpy(dtype=float) if has_time else None
    keys = pd.DataFrame(index=range(len(row)))
    if has_scenario:
        sc = data["scenario"].iloc[row].reset_index(drop=True)
        keys["scenario"] = sc
    if rates:
        keys["time"] = t
    values = values[row]
    r = values.shape[0]

    rng = np.random.default_rng(seed)
    # One noise factor per draw (row) x event (column). Every row of `data`
    # reuses these same factors: common random numbers.
    z = rng.standard_normal(size=(n, len(events)))
    noise = np.maximum(1 + cv * z, 0)

    # Rows ordered by input row, then by draw.
    big = np.tile(noise, (r, 1)) * np.repeat(values, n, axis=0)
    if rates:
        big = -np.expm1(-big * np.repeat(t, n)[:, None])   # R's pexp(time, rate)
    else:
        big = np.minimum(big, 1)
    p = _evaluate(f, big, events)

    if draws:
        out = keys.iloc[np.repeat(np.arange(r), n)].reset_index(drop=True)
        out["sim"] = np.tile(np.arange(1, n + 1, dtype="int64"), r)
        out["p_top"] = p
        return out

    probs = np.round([(1 - level) / 2, (1 + level) / 2], 12)
    pm = p.reshape(r, n)   # row j holds the n draws of input row j
    out = keys.copy()
    out["p_top"] = np.median(pm, axis=1)
    out["lower"] = np.quantile(pm, probs[0], axis=1)
    out["upper"] = np.quantile(pm, probs[1], axis=1)
    return out
