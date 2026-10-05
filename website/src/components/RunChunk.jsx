import { useState } from "react";
import Code from "./Code.jsx";

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
print(tf.quantify(f, [0.10, 0.20, 0.05, 0.15], prob=True))
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

export default function RunChunk() {
  const [lang, setLang] = useState("R");
  const chunk = CHUNKS[lang];
  const [first, ...rest] = chunk.output.split("\n");
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
        <span className="chip">
          <span className="dot" /> Live runtime coming soon
        </span>
        <button type="button" className="btn btn-run btn-sm" disabled title="Live runtime coming soon">
          ▶ Run
        </button>
      </div>
      <pre className="code code-flush">
        <Code text={chunk.code} />
      </pre>
      <div className="chunk-out">
        <div className="out-text mono">
          {[first, ...rest].map((line) => (
            <div key={line}>
              <span className="muted">#&gt;</span> {line}
            </div>
          ))}
        </div>
        <figure className="out-fig">
          <TreeFigure />
        </figure>
      </div>
    </div>
  );
}
