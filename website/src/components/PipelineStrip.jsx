const STEPS = [
  ["curate()", "gates from nodes + edges", "gates"],
  ["equate()", "one boolean equation", "equation"],
  ["formulate()", "a function", "function"],
  ["calculate()", "the truth table", "truth table"],
  ["concentrate()", "minimal cut sets", "cut sets"],
  ["tabulate()", "coverage", "coverage"],
];

export default function PipelineStrip() {
  return (
    <div className="pipeline" role="list" aria-label="The tidyfault pipeline">
      {STEPS.map(([fn, long, short], i) => (
        <div key={fn} className={"card pipe-card" + (i === 0 ? " pipe-active" : "")} role="listitem">
          <span className="eyebrow">{i + 1}</span>
          <span className="mono pipe-fn">{fn}</span>
          <span className="pipe-desc">
            <span className="pipe-long">{long}</span>
            <span className="pipe-short">{short}</span>
          </span>
        </div>
      ))}
    </div>
  );
}
