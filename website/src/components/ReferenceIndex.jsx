const FUNCTIONS = [
  "curate()", "quantify()",
  "equate()", "quantify_prob()",
  "formulate()", "simulate()",
  "calculate()", "populate()",
  "concentrate()", "mocus()",
  "tabulate()", "illustrate()",
];

export default function ReferenceIndex() {
  return (
    <section className="section" id="reference">
      <div className="ref">
        <div className="ref-copy">
          <span className="eyebrow">Reference</span>
          <h2>Every function, generated from the package</h2>
          <p className="lede-sm">
            Reference pages are built from the R package's roxygen and the Python package's
            docstrings at build time, so the site cannot drift from the code.
          </p>
          <div className="row">
            <a className="btn btn-ghost" href="#reference">
              R reference
            </a>
            <a className="btn btn-ghost" href="#reference">
              Python reference
            </a>
          </div>
        </div>
        <div className="ref-list mono">
          {FUNCTIONS.map((fn) => (
            <a key={fn} href="#reference">
              {fn}
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
