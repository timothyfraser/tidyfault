"""R's mocus(), mocus_r(), mocus_rcpp() / mocus_cpp(): MOCUS (Method of Obtaining
Cutsets). Pure Python; the queue algorithm is R's mocus_r() / the C++ in
mocus_rcpp() step for step, so cut sets come back in R's order.

The top event is not a gate (SPEC TF4.2): the expansion starts from the top
event's one child, an AND/OR gate, exactly as R does.
"""

from __future__ import annotations

from collections import deque

METHODS = ("mocus_rcpp", "mocus_r", "mocus_original")


def _gate_table(data):
    for col in ("gate", "type", "class", "items"):
        if col not in data.columns:
            raise ValueError(f"mocus(): data is missing column '{col}' (pass the output of curate())")
    table = {}
    for gate, typ, items in zip(data["gate"].astype(str), data["type"].astype(str), data["items"]):
        children = [str(i) for i in (items if items is not None else []) if i is not None]
        table[gate] = (typ, children)
    classes = data["class"].astype(str).tolist()
    tops = [g for g, c in zip(data["gate"].astype(str), classes) if c == "top"]
    if len(tops) != 1:
        raise ValueError(f'MOCUS needs exactly one top event row (class "top"); found {len(tops)}. '
                         "Build the gate table with curate().")
    child = table[tops[0]][1]
    gates = {g for g, c in zip(data["gate"].astype(str), classes) if c == "gate"}
    if len(child) != 1 or child[0] not in gates:
        raise ValueError(f"MOCUS: the top event `{tops[0]}` must have exactly one child and it must "
                         "be a gate; found " + ", ".join(f"`{c}`" for c in child) +
                         ". Build the gate table with curate(), which explains the fix.")
    return table, child[0]


def _mocus(data):
    table, start = _gate_table(data)

    queue = deque([[start]])
    results = []
    while queue:
        cutset = queue.popleft()
        and_pos, or_pos = [], []
        for p, tok in enumerate(cutset):
            if tok in table:
                (and_pos if table[tok][0] == "and" else or_pos).append(p)
        if not and_pos and not or_pos:
            results.append(list(dict.fromkeys(cutset)))     # R's unique(): first occurrence order
            continue
        if and_pos:                                         # expand every AND gate in one pass
            drop = set(and_pos)
            nc = [t for p, t in enumerate(cutset) if p not in drop]
            for p in and_pos:
                nc.extend(table[cutset[p]][1])
            queue.append(nc)
        else:                                               # branch on the first OR gate
            p0 = or_pos[0]
            rest = [t for p, t in enumerate(cutset) if p != p0]
            for child in table[cutset[p0]][1]:
                queue.append(rest + [child])
    return results


def mocus(data, method="mocus_rcpp"):
    """Every cut set of the tree in ``data`` (the output of curate()).

    Returns a list of lists of basic-event names, one list per cut set (not yet
    minimal; concentrate() minimises). ``method`` takes R's labels; all three run
    the same pure-Python queue algorithm, which reproduces mocus_rcpp() and
    mocus_r() element for element ("mocus_original", R's historical loop, is
    accepted as a label only).
    """
    if method not in METHODS:
        raise ValueError("'method' should be one of " + ", ".join(repr(m) for m in METHODS))
    return _mocus(data)


def mocus_r(data):
    """R's mocus_r(): the pure queue-based MOCUS. Same output as mocus()."""
    return _mocus(data)


def mocus_rcpp(data):
    """R's mocus_rcpp(): compiled in R, pure Python here. Same output as mocus()."""
    return _mocus(data)


mocus_cpp = mocus_rcpp
