"""Shared input checks for quantify_if() and stipulate(): one row of named,
finite numbers, as R's internal one_row_values()."""

from __future__ import annotations

import numpy as np
import pandas as pd


def is_one_row_like(data):
    return isinstance(data, (pd.DataFrame, pd.Series, dict))


def one_row_values(data, arg, fun):
    """Return a float Series (index = names) from a one-row DataFrame, a Series
    or a dict, with R's error messages."""
    if isinstance(data, pd.DataFrame):
        if len(data) != 1:
            raise ValueError(f"`{arg}` must have exactly one row; it has {len(data)}. "
                             f"Give {fun}() one row of values, one column per basic event.")
        not_num = [str(c) for c in data.columns if not pd.api.types.is_numeric_dtype(data[c])
                   or pd.api.types.is_bool_dtype(data[c])]
        if not_num:
            raise ValueError(f"`{arg}` columns must be numeric. Not numeric: "
                             + ", ".join(not_num) + ".")
        values = data.iloc[0].astype(float)
    elif isinstance(data, (pd.Series, dict)):
        try:
            values = pd.Series(data, dtype=float)
        except (TypeError, ValueError):
            raise ValueError(f"`{arg}` must be a one-row data frame or a named numeric vector, "
                             "one value per basic event.") from None
    else:
        raise ValueError(f"`{arg}` must be a one-row data frame or a named numeric vector, "
                         "one value per basic event.")
    names = [str(n) for n in values.index]
    if any(n == "" for n in names) or len(set(names)) != len(names):
        raise ValueError(f"`{arg}` must name every value once.")
    values.index = names
    bad = [n for n, v in values.items() if not np.isfinite(v)]
    if bad:
        raise ValueError(f"`{arg}` values must be finite. Not finite: " + ", ".join(bad) + ".")
    return values
