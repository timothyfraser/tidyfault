const FEATURES = [
  {
    icon: <path d="M12 56 V32 A20 20 0 0 1 52 32 V56 Z" fill="var(--gate-and)" />,
    title: "Minimal cut sets",
    body: (
      <>
        MOCUS expansion in C++ through Rcpp, minimised by absorption.{" "}
        <a href="#reference">concentrate()</a> returns a character vector you can filter and join.
      </>
    ),
  },
  {
    icon: <path d="M10 56 Q32 44 54 56 Q54 28 32 8 Q10 28 10 56 Z" fill="var(--gate-or)" />,
    title: "Scenarios and probabilities",
    body: (
      <>
        <a href="#reference">quantify()</a> evaluates binary scenarios or exact top-event
        probabilities over many rows at once; <a href="#reference">simulate()</a> adds uncertainty.
      </>
    ),
  },
  {
    icon: <rect x="8" y="16" width="48" height="32" rx="2" fill="var(--gate-top)" />,
    title: "Publication-ready figures",
    body: (
      <>
        <a href="#reference">illustrate()</a> lays the tree out; <a href="#reference">plot()</a>{" "}
        draws gates as polygons in ggplot2 or matplotlib, so the figure is code, not a drawing.
      </>
    ),
  },
];

export default function FeatureCards() {
  return (
    <section className="section" id="features">
      <div className="stack-sm">
        <span className="eyebrow">What it does</span>
        <h2>Three things a fault tree should give you</h2>
      </div>
      <div className="grid-3">
        {FEATURES.map((f) => (
          <article className="card" key={f.title}>
            <svg viewBox="0 0 64 64" width="40" height="40" aria-hidden="true">
              {f.icon}
            </svg>
            <h3>{f.title}</h3>
            <p className="card-text">{f.body}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
