import { useRef, useState } from "react";
import Code from "./Code.jsx";
import { runPython } from "../runtime/pyodide.js";

const CHUNKS = {
  R: {
    code: `# The package's example tree: 12 nodes, 11 edges
library(tidyfault)
gates <- curate(nodes = fakenodes, edges = fakeedges)
f     <- gates |> equate() |> formulate()
concentrate(gates)
quantify(f, c(0.10, 0.20, 0.05, 0.15), prob = TRUE)
plot(illustrate(fakenodes, fakeedges, type = "both"))`,
    output: `[1] "B*C"   "A*B*D"\n[1] 0.01285`,
  },
  Python: {
    code: `# The package's example tree: 12 nodes, 11 edges
import tidyfault as tf
nodes, edges = tf.data.fakenodes, tf.data.fakeedges
gates = tf.curate(nodes, edges)
f     = tf.formulate(tf.equate(gates))
print(tf.concentrate(gates))
print(round(tf.quantify(f, [0.10, 0.20, 0.05, 0.15], prob=True), 5))
tf.plot(tf.illustrate(nodes, edges, type="both"))`,
    output: `['B*C', 'A*B*D']\n0.01285`,
  },
};

function TreeFigure() {
  return (
    <svg viewBox="0 0 520 420" width="300" height="242" role="img" aria-label="The example fault tree drawn by plot()">
      <g stroke="var(--edge)" strokeWidth="3" fill="none" strokeLinecap="round">
        <path d="M260 56 V86" /><path d="M260 140 L150 190" /><path d="M260 140 L370 190" />
        <path d="M150 240 L90 290" /><path d="M150 240 L210 290" /><path d="M370 240 L310 290" />
        <path d="M370 240 L430 290" /><path d="M90 340 L50 380" /><path d="M90 340 L130 380" />
        <path d="M310 340 L270 380" /><path d="M310 340 L350 380" />
      </g>
      <g stroke="var(--gate-outline)" strokeWidth="2">
        <rect x="210" y="16" width="100" height="40" rx="4" fill="var(--gate-top)" />
        <path d="M232 140 V112 A28 28 0 0 1 288 112 V140 Z" fill="var(--gate-and)" />
        <path d="M122 240 V212 A28 28 0 0 1 178 212 V240 Z" fill="var(--gate-and)" />
        <path d="M340 242 Q370 228 400 242 Q400 210 370 186 Q340 210 340 242 Z" fill="var(--gate-or)" />
        <path d="M60 342 Q90 328 120 342 Q120 310 90 286 Q60 310 60 342 Z" fill="var(--gate-or)" />
        <circle cx="210" cy="312" r="20" fill="var(--gate-basic)" />
        <path d="M282 340 V312 A28 28 0 0 1 338 312 V340 Z" fill="var(--gate-and)" />
        <circle cx="430" cy="312" r="20" fill="var(--gate-basic)" />
        <circle cx="50" cy="396" r="18" fill="var(--gate-basic)" />
        <circle cx="130" cy="396" r="18" fill="var(--gate-basic)" />
        <circle cx="270" cy="396" r="18" fill="var(--gate-basic)" />
        <circle cx="350" cy="396" r="18" fill="var(--gate-basic)" />
      </g>
    </svg>
  );
}

// RT-02 wires webR here. Until then R keeps its static output and the Run
// button stays disabled for the R tab.
// eslint-disable-next-line no-unused-vars
async function runR(code, onStatus) {
  throw new Error("The R runtime is not wired yet (RT-02).");
}

const IDLE = { phase: "idle", message: "", result: null, error: null };

const CHIP = {
  idle: "Python runs in your browser",
  waiting: "Waiting",
  loading: "Loading Python…",
  running: "Running…",
  done: "Done",
  error: "Error",
};

function splitLines(text) {
  return text ? text.replace(/\s+$/, "").split("\n") : [];
}

export default function RunChunk() {
  const [lang, setLang] = useState("R");
  const [py, setPy] = useState(IDLE);
  const runId = useRef(0);
  const chunk = CHUNKS[lang];
  const isPy = lang === "Python";

  function onRun() {
    if (!isPy) return runR(chunk.code);
    // Only the newest click drives the display; the interpreter itself queues
    // every click (a second click while one is in flight reports "waiting").
    const id = ++runId.current;
    const current = () => id === runId.current;
    setPy({ phase: "loading", message: "Loading Python…", result: null, error: null });
    runPython(chunk.code, ({ phase, message }) => {
      if (current()) setPy((p) => ({ ...p, phase, message }));
    }).then(
      (result) => current() && setPy({ phase: "done", message: "", result, error: null }),
      (e) =>
        current() &&
        setPy({
          phase: "error",
          message: "",
          result: { stdout: e.stdout || "", stderr: e.stderr || "", figures: e.figures || [] },
          error: e.message,
        })
    );
    return undefined;
  }

  const live = isPy && py.result;
  const lines = live ? splitLines(py.result.stdout) : chunk.output.split("\n");
  const stderrLines = live ? splitLines(py.result.stderr) : [];
  const figure = live && py.result.figures[0];
  const busy = isPy && ["waiting", "loading", "running"].includes(py.phase);
  const chipText = isPy ? CHIP[py.phase] : "R runtime coming soon";
  const detail = isPy && py.phase === "loading" ? py.message : "";

  return (
    <div className="chunk">
      <div className="chunk-bar">
        <div role="group" aria-label="Language" className="toggle">
          {Object.keys(CHUNKS).map((l) => (
            <button
              key={l}
              type="button"
              aria-pressed={lang === l}
              className={lang === l ? "on" : ""}
              onClick={() => setLang(l)}
            >
              {l}
            </button>
          ))}
        </div>
        <span className="chip" role="status" aria-live="polite" data-phase={isPy ? py.phase : "r-static"}>
          <span className="dot" /> {chipText}
        </span>
        <button
          type="button"
          className="btn btn-run btn-sm"
          disabled={!isPy}
          title={isPy ? "Run this code in your browser" : "R runtime coming soon"}
          onClick={onRun}
        >
          {busy ? "▶ Run again" : "▶ Run"}
        </button>
      </div>
      <pre className="code code-flush">
        <Code text={chunk.code} />
      </pre>
      {detail && (
        <div className="muted mono" style={{ padding: "6px var(--space-4)", fontSize: 12 }} data-testid="py-progress">
          {detail}
        </div>
      )}
      <div className="chunk-out" data-live={live ? "true" : "false"}>
        <div className="out-text mono">
          {lines.map((line, i) => (
            <div key={i}>
              <span className="muted">#&gt;</span> {line}
            </div>
          ))}
          {stderrLines.map((line, i) => (
            <div key={`e${i}`} className="muted">
              {line}
            </div>
          ))}
          {isPy && py.error && (
            <div style={{ color: "var(--danger)", whiteSpace: "pre-wrap" }} role="alert">
              Error: {py.error}
            </div>
          )}
        </div>
        <figure className="out-fig" style={figure ? { flexBasis: 420 } : undefined}>
          {figure ? (
            <img
              src={figure}
              alt="The example fault tree drawn by plot()"
              style={{ maxWidth: "100%", height: "auto", display: "block" }}
            />
          ) : (
            !(live && py.error) && <TreeFigure />
          )}
        </figure>
      </div>
    </div>
  );
}
