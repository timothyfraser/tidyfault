"""tidyfault.illustrate / tidyfault.plot against R tidyfault's illustrate() and plot().

The expected numbers below were produced by running R itself (R 4.5.2, tidyfault
0.0.0.9, igraph 2.2.2, ggraph 2.2.2) on the bundled datasets:

    a <- illustrate(nodes, edges, type = "all")                       # layout, edges, gates
    s <- illustrate(nodes, edges, type = "both", scale_size = TRUE)   # scaled gates
    jsonlite::toJSON(..., digits = NA)                                # 15 significant digits

and pinning, per dataset, every node's (x, y), the edge count, and for each gate
polygon its row count, sum of x, sum of y and x/y range. R's tree layout is
deterministic (igraph Reingold-Tilford), so these are exact; the comparison
tolerance is 1e-9. The same comparison also held on ai, security and
it_security when the port was written.
"""

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from tidyfault.data import load_data
from tidyfault.illustrate import illustrate

TOL = 1e-9

DATASETS = {"fake": ("fakenodes", "fakeedges"), "db": ("db_nodes", "db_edges")}

# (id, x, y) per node; gates: (group, gate, rows, sum x, sum y, min x, max x, min y, max y);
# scaled_gates: (group, sum x, sum y) with scale_size=True.
R = {
    'fake': {
        "nodes": [(1, 0.0, 4.0), (2, 0.0, 3.0), (3, -1.0, 2.0), (4, 1.0, 2.0), (5, 0.5, 1.0), (6, -1.5, 1.0), (7, 1.5, 1.0), (8, -0.5, 1.0), (9, 0.0, 0.0), (10, -2.0, 0.0), (11, 1.0, 0.0), (12, -1.0, 0.0)],
        "gates_n": 361,
        "gates": [
            (1, 'top', 8, 0.0, 32.0, -0.375, 0.375, 3.75, 4.25),
            (2, 'and', 51, -0.249999999999999, 156.70930147547, -0.25, 0.25, 2.75, 3.25),
            (3, 'and', 51, -51.25, 105.70930147547, -1.25, -0.75, 1.75, 2.25),
            (4, 'or', 100, 100.0, 192.488007817687, 0.75, 1.25, 1.75, 2.25),
            (5, 'and', 51, 25.25, 54.7093014754697, 0.25, 0.75, 0.75, 1.25),
            (6, 'or', 100, -150.0, 92.4880078176866, -1.75, -1.25, 0.75, 1.25),
        ],
        "scaled_gates": [(1, 0.0, 32.0), (2, -0.218749999999999, 156.245638791036), (3, -51.21875, 105.245638791036), (4, 100.0, 193.216041672638), (5, 25.28125, 54.245638791036), (6, -150.0, 93.2160416726383)],
    },
    'db': {
        "nodes": [(1, 0.0, 2.0), (2, -3.0, 1.0), (3, -1.0, 1.0), (4, 1.0, 1.0), (5, 3.0, 1.0), (6, -3.5, 0.0), (7, -2.5, 0.0), (8, -1.5, 0.0), (9, -0.5, 0.0), (10, 0.5, 0.0), (11, 1.5, 0.0), (12, 2.5, 0.0), (13, 3.5, 0.0)],
        "gates_n": 310,
        "gates": [
            (1, 'top', 8, 0.0, 16.0, -0.375, 0.375, 1.75, 2.25),
            (2, 'or', 100, -300.0, 92.4880078176866, -3.25, -2.75, 0.75, 1.25),
            (3, 'and', 51, -51.25, 54.7093014754697, -1.25, -0.75, 0.75, 1.25),
            (4, 'or', 100, 100.0, 92.4880078176866, 0.75, 1.25, 0.75, 1.25),
            (5, 'and', 51, 152.75, 54.7093014754697, 2.75, 3.25, 0.75, 1.25),
        ],
        "scaled_gates": [(1, 0.0, 16.0), (2, -300.0, 95.858239030512), (3, -51.125, 52.8546507377349), (4, 100.0, 95.858239030512), (5, 152.875, 52.8546507377349)],
    },
}


def _load(name):
    n, e = DATASETS[name]
    return load_data(n), load_data(e)


def _gate_summary(g):
    rows = []
    for (grp, gt), sub in g.groupby(["group", "gate"], sort=True, observed=True):
        x, y = sub["x"].to_numpy(float), sub["y"].to_numpy(float)
        rows.append((int(grp), str(gt), len(sub), x.sum(), y.sum(), x.min(), x.max(), y.min(), y.max()))
    return rows


@pytest.mark.parametrize("name", list(DATASETS))
def test_node_layout_matches_r(name):
    nodes, edges = _load(name)
    got = illustrate(nodes, edges)  # R's actual default type is "nodes"
    assert list(got.columns) == ["x", "y", "id", "event", "type"], got.columns
    exp = R[name]["nodes"]
    assert got["id"].tolist() == [i for i, _, _ in exp]
    np.testing.assert_allclose(got["x"].to_numpy(float), [x for _, x, _ in exp], atol=TOL, rtol=0,
                               err_msg=f"{name}: node x differs from R")
    np.testing.assert_allclose(got["y"].to_numpy(float), [y for _, _, y in exp], atol=TOL, rtol=0,
                               err_msg=f"{name}: node y differs from R")
    # original node columns are carried through untouched
    pd.testing.assert_series_equal(got["event"], nodes["event"], check_names=False)


@pytest.mark.parametrize("name", list(DATASETS))
def test_edges_and_pairwise_match_r(name):
    nodes, edges = _load(name)
    out = illustrate(nodes, edges, type="all")
    assert set(out) == {"nodes", "edges", "gates", "pairwise"}
    pos = {i: (x, y) for i, x, y in R[name]["nodes"]}

    pw = out["pairwise"]
    assert list(pw.columns) == list(edges.columns) + ["from_x", "from_y", "to_x", "to_y", "edge_id"]
    assert pw["edge_id"].tolist() == list(range(1, len(edges) + 1))
    exp = np.array([pos[f] + pos[t] for f, t in zip(edges["from"], edges["to"])], dtype=float)
    np.testing.assert_allclose(pw[["from_x", "from_y", "to_x", "to_y"]].to_numpy(float), exp, atol=TOL, rtol=0)

    ge = out["edges"]
    assert list(ge.columns) == ["edge_id", "direction", "id", "x", "y"]
    assert len(ge) == 2 * len(edges)
    assert ge["direction"].tolist() == ["from", "to"] * len(edges)
    ids = np.column_stack([edges["from"], edges["to"]]).ravel()
    assert ge["id"].tolist() == ids.tolist()
    np.testing.assert_allclose(ge[["x", "y"]].to_numpy(float), np.array([pos[i] for i in ids], float), atol=TOL, rtol=0)

    assert illustrate(nodes, edges, type="edges").equals(ge)
    both = illustrate(nodes, edges, type="both")
    assert set(both) == {"nodes", "edges", "gates"}


@pytest.mark.parametrize("name", list(DATASETS))
def test_gate_polygons_match_r(name):
    nodes, edges = _load(name)
    g = illustrate(nodes, edges, type="both")["gates"]
    assert list(g.columns) == ["group", "gate", "x", "y"]
    assert len(g) == R[name]["gates_n"]
    got, exp = _gate_summary(g), R[name]["gates"]
    assert [r[:3] for r in got] == [r[:3] for r in exp]
    np.testing.assert_allclose(np.array([r[3:] for r in got]), np.array([r[3:] for r in exp]), atol=TOL, rtol=0)


@pytest.mark.parametrize("name", list(DATASETS))
def test_scale_size_matches_r(name):
    nodes, edges = _load(name)
    g = illustrate(nodes, edges, type="both", scale_size=True)["gates"]
    got = [(r[0], r[3], r[4]) for r in _gate_summary(g)]
    exp = R[name]["scaled_gates"]
    assert [r[0] for r in got] == [r[0] for r in exp]
    np.testing.assert_allclose(np.array([r[1:] for r in got]), np.array([r[1:] for r in exp]), atol=TOL, rtol=0)


def test_children_ordered_by_node_row_not_edge_row():
    # fakeedges lists 3 -> 8 before 3 -> 6; igraph still places node 6 (G5) left of node 8 (B)
    nodes, edges = _load("fake")
    got = illustrate(nodes, edges).set_index("id")
    assert got.loc[6, "x"] < got.loc[8, "x"]


def test_character_ids_match_by_key():
    nodes, edges = _load("fake")
    n2 = nodes.assign(id="n" + nodes["id"].astype(str))
    e2 = edges.assign(**{"from": "n" + edges["from"].astype(str), "to": "n" + edges["to"].astype(str)})
    a, b = illustrate(nodes, edges), illustrate(n2, e2)
    np.testing.assert_allclose(a[["x", "y"]].to_numpy(float), b[["x", "y"]].to_numpy(float), atol=TOL, rtol=0)


def test_bad_input_fails_loudly():
    nodes, edges = _load("fake")
    with pytest.raises(ValueError, match="type"):
        illustrate(nodes, edges, type="everything")
    with pytest.raises(NotImplementedError, match="tree"):
        illustrate(nodes, edges, layout="kk")
    with pytest.raises(ValueError, match="exactly one top event"):
        illustrate(nodes, edges[edges["from"] != 1])
    with pytest.raises(ValueError, match="do not name a node"):
        illustrate(nodes, pd.concat([edges, pd.DataFrame({"from": [1], "to": [99]})], ignore_index=True))


@pytest.mark.parametrize("name", list(DATASETS))
def test_plot_writes_png(name, tmp_path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    from tidyfault.plot import plot, to_png

    nodes, edges = _load(name)
    fig = plot(illustrate(nodes, edges, type="both"))
    assert isinstance(fig, matplotlib.figure.Figure)
    ax = fig.axes[0]
    n_gate = int(nodes["type"].astype(str).isin(["and", "or", "top"]).sum())
    assert len(ax.patches) == len(nodes)  # one polygon per gate + one circle per basic event
    assert len(ax.lines) == len(edges)
    assert sorted(t.get_text() for t in ax.texts) == sorted(nodes["event"].astype(str))
    legend = [t.get_text() for t in ax.get_legend().get_texts()]
    assert legend[:1] == ["Top Event"] and legend[-1] == "Basic Event"
    assert n_gate > 0
    out = to_png(fig, tmp_path / f"{name}.png")
    plt.close(fig)
    data = Path(out).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    assert len(data) > 1024, f"{name}.png is only {len(data)} bytes"


def test_plot_rejects_nodes_only_table():
    from tidyfault.plot import plot

    nodes, edges = _load("fake")
    with pytest.raises(ValueError, match="illustrate"):
        plot(illustrate(nodes, edges))
