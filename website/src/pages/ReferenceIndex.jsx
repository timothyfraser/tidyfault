// The reference index for one language, grouped as _pkgdown.yml groups the R topics.
// Generated data only (src/generated/*.json); see Reference.jsx.
import { Fragment, useEffect } from "react";
import { Link } from "react-router-dom";
import NavBar from "../components/NavBar.jsx";
import Footer from "../components/Footer.jsx";
import { LANGS, LangToggle, REF_CSS, displayName, groupTopics, hrefFor } from "./Reference.jsx";

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-");

export default function ReferenceIndex({ lang }) {
  const data = LANGS[lang].data;
  const targets = Object.fromEntries(Object.keys(LANGS).map((l) => [l, `${LANGS[l].base}/`]));

  useEffect(() => {
    document.title = `${LANGS[lang].label} reference · tidyfault`;
  }, [lang]);

  return (
    <div className="page" style={{ gap: "var(--space-6)" }}>
      <style>{REF_CSS}</style>
      <NavBar active={lang} />
      <main className="page-main">
        <div className="section" id="reference">
          <div className="ref-head">
            <div className="stack-sm">
              <span className="eyebrow">Reference</span>
              <h1 className="ref-idx-title">{LANGS[lang].label} reference</h1>
            </div>
            <LangToggle lang={lang} targets={targets} />
          </div>
          <p className="lede-sm">
            Every {lang === "R" ? "exported function and dataset" : "name in tidyfault.__all__"}, generated from the{" "}
            {lang === "R" ? "package's roxygen documentation" : "package's docstrings and signatures"} · package version{" "}
            {data.version}.
          </p>
          <div className="ref-idx">
            {groupTopics(lang).map(([group, topics]) => (
              <section key={group} className="ref-idx-group" id={slug(group)}>
                <h2>{group}</h2>
                <div className="ref-idx-list">
                  {topics.map((t) => (
                    <Fragment key={t.name}>
                      <Link to={hrefFor(lang, t.name)}>{displayName(t)}</Link>
                      <span>{t.summary}</span>
                    </Fragment>
                  ))}
                </div>
              </section>
            ))}
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}
