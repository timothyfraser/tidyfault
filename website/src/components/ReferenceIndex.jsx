import { Link } from "react-router-dom";

// Display name -> reference page (R package; /reference/<fn>.html keeps the old pkgdown URLs).
const FUNCTIONS = [
  "curate", "quantify",
  "equate", "quantify_prob",
  "formulate", "simulate",
  "calculate", "populate",
  "concentrate", "mocus",
  "tabulate", "illustrate",
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
            <Link className="btn btn-ghost" to="/reference/">
              R reference
            </Link>
            <Link className="btn btn-ghost" to="/reference-py/">
              Python reference
            </Link>
          </div>
        </div>
        <div className="ref-list mono">
          {FUNCTIONS.map((fn) => (
            <Link key={fn} to={`/reference/${fn}.html`}>
              {fn}()
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}
