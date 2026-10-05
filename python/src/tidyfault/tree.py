"""The tidyfault data model: a fault tree is two tidy tables.

``nodes``  one row per node: ``id`` (unique), ``event`` (name; a basic event may
           appear on several nodes, each with its own id), ``type`` (``"top"``,
           ``"and"``, ``"or"`` or ``"not"``; ``"not"`` means "not a gate", i.e. a
           basic event).
``edges``  one row per directed link, ``from`` (parent id) -> ``to`` (child id).

R stores ``type`` as a factor with levels ``top, and, or, not``; here it is a
pandas Categorical with the same categories in the same order.

The top event is not a gate (SPEC TF4.2): there is exactly one ``top`` node, it
has exactly one child, and that child is an ``and``/``or`` gate. R's
``curate()`` refuses anything else; :func:`top_problem` builds the same message
word for word, ``curate()`` raises it and :func:`validate_tree` lists it among
every other problem it finds.
"""

from __future__ import annotations

import pandas as pd

NODE_COLUMNS = ("id", "event", "type")
EDGE_COLUMNS = ("from", "to")
NODE_TYPES = ("top", "and", "or", "not")   # R factor levels, in R's order
GATE_TYPES = ("top", "and", "or")          # node types that have children


def _frame(data, what):
    if isinstance(data, pd.DataFrame):
        return data.copy()
    try:
        return pd.DataFrame(data)
    except Exception as exc:  # pragma: no cover - pandas error text is enough
        raise TypeError(f"{what} must be a DataFrame or something pandas can build one from") from exc


def as_nodes(data) -> pd.DataFrame:
    """Return ``data`` as a nodes table: columns ``id, event, type`` (extra columns
    kept), ``type`` as a Categorical with R's levels ``top, and, or, not``."""
    df = _frame(data, "nodes")
    missing = [c for c in NODE_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"nodes is missing column(s) {missing}; need {list(NODE_COLUMNS)}")
    bad = sorted(set(df["type"].astype(str)) - set(NODE_TYPES))
    if bad:
        raise ValueError(f"nodes$type has value(s) {bad}; allowed: {list(NODE_TYPES)}")
    df["type"] = pd.Categorical(df["type"].astype(str), categories=list(NODE_TYPES))
    df["event"] = df["event"].astype(str)
    return df


def as_edges(data) -> pd.DataFrame:
    """Return ``data`` as an edges table with columns ``from, to`` (extra columns kept)."""
    df = _frame(data, "edges")
    missing = [c for c in EDGE_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"edges is missing column(s) {missing}; need {list(EDGE_COLUMNS)}")
    return df


def _fmt_id(v):
    """An id as R's paste0() prints it: 5, not 5.0."""
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def top_problem(nodes, edges):
    """The TF4.2 problem with this tree's top event, as R's ``curate()`` words it
    (without R's ``"curate(): "`` prefix), or ``None`` when the top event has
    exactly one child and that child is an ``and``/``or`` gate."""
    types = nodes["type"].astype(str).tolist()
    events = nodes["event"].astype(str).tolist()
    ids = nodes["id"].tolist()
    tops = [i for i, t in enumerate(types) if t == "top"]
    if len(tops) != 1:
        found = f"found {len(tops)}"
        if tops:
            found += ": " + ", ".join(f"`{events[i]}`" for i in tops)
        return ('a fault tree needs exactly one top event (type "top"), but ' + found +
                '. Give one node type "top" and connect it to the tree through one '
                "`and` or `or` gate.")
    top_id, top = ids[tops[0]], events[tops[0]]
    pos_of = {}
    for i, v in enumerate(ids):
        pos_of.setdefault(v, i)
    child_ids = [b for a, b in zip(edges["from"].tolist(), edges["to"].tolist()) if a == top_id]
    names = [events[pos_of[c]] if c in pos_of else f"id {_fmt_id(c)}" for c in child_ids]
    n = len(child_ids)
    listing = ", ".join(f"`{x}`" for x in names)
    head = f"the top event `{top}` must connect to the tree through exactly one gate, but "
    if n == 0:
        return head + f"it has 0 children. Add an edge from `{top}` to one `and` or `or` gate."
    if n > 1:
        return (head + f"it has {n} children: {listing}. The top event carries no logic of its "
                "own. Insert an `or` gate (any child fails the system) or an `and` gate (all "
                f"children must fail) between `{top}` and its {n} children.")
    child = child_ids[0]
    if child in pos_of and types[pos_of[child]] in ("and", "or"):
        return None
    if child not in pos_of:
        what = "is not in `nodes`"
    elif types[pos_of[child]] == "not":
        what = 'is a basic event (type "not"), not a gate'
    else:
        what = f'is of type "{types[pos_of[child]]}", not a gate'
    return (head + f"its only child, {listing}, {what}. "
            f"Insert an `or` or `and` gate between `{top}` and {listing}.")


def validate_tree(nodes, edges) -> bool:
    """Check that ``nodes``/``edges`` describe a well-formed fault tree.

    Fails closed: raises ``ValueError`` listing every problem found, returns
    ``True`` otherwise. Checks: required columns and node types; unique node
    ids; exactly one ``top`` node, whose one child is an ``and``/``or`` gate
    (SPEC TF4.2, R's ``curate()`` message); every edge endpoint is a known id; every gate
    (``top``/``and``/``or``) has at least one child; basic events (``not``)
    have no children; and the graph has no cycle. A basic event shared by two
    branches is modelled as in R: the same ``event`` name on two distinct ids.
    """
    nodes = as_nodes(nodes)
    edges = as_edges(edges)
    problems = []

    dup = nodes["id"][nodes["id"].duplicated()].tolist()
    if dup:
        problems.append(f"duplicate node id(s): {dup}")

    top = top_problem(nodes, edges)
    if top is not None:
        problems.append(top)

    ids = set(nodes["id"].tolist())
    for col in EDGE_COLUMNS:
        unknown = sorted({v for v in edges[col].tolist() if v not in ids}, key=str)
        if unknown:
            problems.append(f"edges${col} refers to unknown node id(s): {unknown}")

    parents = set(edges["from"].tolist())
    type_of = dict(zip(nodes["id"].tolist(), nodes["type"].astype(str).tolist()))
    childless = [i for i, t in type_of.items() if t in GATE_TYPES and i not in parents]
    if childless:
        problems.append(f"gate/top node id(s) with no children: {childless}")
    leafy = sorted({i for i in parents if type_of.get(i) == "not"}, key=str)
    if leafy:
        problems.append(f"basic-event ('not') node id(s) with children: {leafy}")

    # cycle check (iterative DFS)
    children = {}
    for a, b in zip(edges["from"].tolist(), edges["to"].tolist()):
        children.setdefault(a, []).append(b)
    state = {}
    for start in children:
        if state.get(start):
            continue
        stack = [(start, iter(children.get(start, ())))]
        state[start] = 1
        while stack:
            node, it = stack[-1]
            nxt = next(it, None)
            if nxt is None:
                state[node] = 2
                stack.pop()
            elif state.get(nxt) == 1:
                problems.append(f"cycle through node id {nxt}")
                stack = []
            elif not state.get(nxt):
                state[nxt] = 1
                stack.append((nxt, iter(children.get(nxt, ()))))
        if problems and problems[-1].startswith("cycle"):
            break

    if problems:
        raise ValueError("invalid fault tree:\n  - " + "\n  - ".join(problems))
    return True
