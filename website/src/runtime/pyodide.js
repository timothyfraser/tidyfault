// Pyodide runtime for the live Python chunks (RT-01, SPEC TF5).
//
// Nothing here runs on page load. The interpreter boots on the FIRST call to
// runPython(); later calls reuse it. One interpreter, so runs are serialised
// through a promise queue and a call that has to wait reports phase "waiting".
//
//   runPython(code, onStatus?) -> Promise<{ stdout, stderr, figures }>
//     figures: PNG data URLs of every matplotlib figure left open by the code
//     onStatus({ phase, message }): phase is "waiting" | "loading" | "running"
//     A Python exception (or a failed boot) rejects with an Error whose
//     .stdout, .stderr and .figures hold whatever was captured before it.

export const PYODIDE_VERSION = "v0.29.4";
export const PYODIDE_BASE = `https://cdn.jsdelivr.net/pyodide/${PYODIDE_VERSION}/full/`;
const PACKAGES = ["pandas", "numpy", "igraph", "matplotlib", "micropip"];

let bootPromise = null;
let queueTail = Promise.resolve();
let inFlight = 0;
const bootListeners = new Set();
let lastBootMessage = "Loading Python…";

function say(message) {
  lastBootMessage = message;
  bootListeners.forEach((fn) => fn(message));
}

function loadScriptTag(src) {
  return new Promise((resolve, reject) => {
    const el = document.createElement("script");
    el.src = src;
    el.onload = resolve;
    el.onerror = () => reject(new Error(`Could not load ${src}`));
    document.head.appendChild(el);
  });
}

// matplotlib is pinned to Agg BEFORE anything imports it: Pyodide's default
// backend draws into the DOM and removes figures from pyplot's manager, so
// there would be nothing left to capture. MPLBACKEND is read at import time.
const PY_SETUP = `
import os, warnings
os.environ["MPLBACKEND"] = "Agg"
warnings.filterwarnings("ignore", message=".*non-interactive.*")
warnings.filterwarnings("ignore", message=".*cannot be shown.*")

def _tf_figures():
    import sys, io, base64, json
    if "matplotlib" not in sys.modules:
        return "[]"
    import matplotlib.pyplot as plt
    out = []
    for n in plt.get_fignums():
        buf = io.BytesIO()
        plt.figure(n).savefig(buf, format="png", dpi=300, bbox_inches="tight")
        out.append("data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii"))
    plt.close("all")
    return json.dumps(out)
`;

async function wheelUrl() {
  const base = import.meta.env.BASE_URL;
  const manifest = new URL(`${base}py/wheel.json`, location.href);
  const res = await fetch(manifest);
  if (!res.ok) throw new Error(`Could not read ${manifest.pathname} (HTTP ${res.status})`);
  const { wheel } = await res.json();
  return new URL(`${base}py/${wheel}`, location.href).href;
}

async function boot() {
  say("Loading Python…");
  if (typeof window.loadPyodide !== "function") await loadScriptTag(`${PYODIDE_BASE}pyodide.js`);
  const pyodide = await window.loadPyodide({ indexURL: PYODIDE_BASE });
  await pyodide.runPythonAsync(PY_SETUP);
  say("Loading pandas, numpy, igraph, matplotlib…");
  await pyodide.loadPackage(PACKAGES, {
    messageCallback: (m) => say(m),
    errorCallback: (m) => say(m),
  });
  say("Installing tidyfault…");
  const micropip = pyodide.pyimport("micropip");
  try {
    await micropip.install(await wheelUrl());
  } finally {
    micropip.destroy();
  }
  say("Python ready");
  return pyodide;
}

function getPyodide() {
  if (!bootPromise) {
    bootPromise = boot().catch((err) => {
      bootPromise = null; // let the next click retry
      throw err;
    });
  }
  return bootPromise;
}

async function execute(code, onStatus) {
  const emit = (phase, message) => onStatus && onStatus({ phase, message });
  let pyodide;
  if (!bootPromise) {
    emit("loading", lastBootMessage);
    const listener = (m) => emit("loading", m);
    bootListeners.add(listener);
    try {
      pyodide = await getPyodide();
    } finally {
      bootListeners.delete(listener);
    }
  } else {
    pyodide = await getPyodide();
  }

  emit("running", "Running…");
  const out = [];
  const err = [];
  pyodide.setStdout({ batched: (s) => out.push(s) });
  pyodide.setStderr({ batched: (s) => err.push(s) });
  const ns = pyodide.globals.get("dict")();
  const collect = async () => {
    try {
      const figs = pyodide.runPython("_tf_figures()");
      return JSON.parse(figs);
    } catch (_) {
      return [];
    }
  };
  try {
    const value = await pyodide.runPythonAsync(code, { globals: ns });
    if (value && typeof value.destroy === "function") value.destroy();
    return { stdout: out.join("\n"), stderr: err.join("\n"), figures: await collect() };
  } catch (e) {
    const wrapped = new Error(String(e && e.message ? e.message : e));
    wrapped.stdout = out.join("\n");
    wrapped.stderr = err.join("\n");
    wrapped.figures = await collect();
    throw wrapped;
  } finally {
    ns.destroy();
  }
}

export function runPython(code, onStatus) {
  if (inFlight > 0 && onStatus) onStatus({ phase: "waiting", message: "Waiting for the earlier run…" });
  inFlight += 1;
  const result = queueTail.then(() => execute(code, onStatus));
  const settled = () => {
    inFlight -= 1;
  };
  queueTail = result.then(settled, settled);
  return result;
}
