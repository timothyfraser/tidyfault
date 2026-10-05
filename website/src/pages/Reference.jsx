// One reference page per function, generated from the packages: src/generated/*.json is
// written by scripts/extract-r.R (Rd) and scripts/extract-py.py (docstrings). Never type
// API text here; fix the roxygen or docstring and run `npm run generate`.
import { useEffect } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import NavBar from "../components/NavBar.jsx";
import Footer from "../components/Footer.jsx";
import Code from "../components/Code.jsx";
import R from "../generated/reference-r.json";
import PY from "../generated/reference-py.json";

export const LANGS = {
  R: { key: "R", label: "R", data: R, base: "/reference" },
  Python: { key: "Python", label: "Python", data: PY, base: "/reference-py" },
};

export const hrefFor = (lang, name) => `${LANGS[lang].base}/${name}.html`;
export const displayName = (t) => (t.kind === "function" || t.kind === "S3 method" || t.kind === "class" ? `${t.name}()` : t.name);

// name or alias -> topic, per language (R's mocus_cpp lands on the mocus_rcpp topic)
const lookup = Object.fromEntries(
  Object.keys(LANGS).map((k) => {
    const m = new Map();
    for (const t of LANGS[k].data.topics) for (const a of [t.name, ...t.aliases]) if (!m.has(a)) m.set(a, t);
    return [k, m];
  }),
);
export const findTopic = (lang, name) => lookup[lang].get(name) ?? null;

// The same function in the other language, if the other package has it.
export function counterpart(lang, topic) {
  const other = lang === "R" ? "Python" : "R";
  for (const a of [topic.name, ...topic.aliases]) {
    const t = findTopic(other, a);
    if (t) return { lang: other, name: t.name };
  }
  return null;
}

export function groupTopics(lang) {
  const groups = new Map();
  for (const t of LANGS[lang].data.topics) {
    if (!groups.has(t.group)) groups.set(t.group, []);
    groups.get(t.group).push(t);
  }
  return [...groups.entries()];
}

// Generated HTML carries root-relative links (/reference/<fn>.html); route them in-app.
export function useInternalLinks() {
  const navigate = useNavigate();
  return (e) => {
    const a = e.target.closest?.("a[href]");
    if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const href = a.getAttribute("href");
    if (href.startsWith("/") && !href.startsWith("//")) {
      e.preventDefault();
      navigate(href);
    }
  };
}

export function LangToggle({ lang, targets }) {
  return (
    <div role="group" aria-label="Language" className="toggle ref-toggle">
      {Object.keys(LANGS).map((l) => {
        const to = targets[l];
        if (l === lang) {
          return (
            <button key={l} type="button" aria-pressed="true" className="on">
              {LANGS[l].label}
            </button>
          );
        }
        return to ? (
          <Link key={l} to={to} role="button" aria-pressed="false" className="ref-toggle-link">
            {LANGS[l].label}
          </Link>
        ) : (
          <button key={l} type="button" aria-pressed="false" disabled title={`No ${LANGS[l].label} equivalent`}>
            {LANGS[l].label}
          </button>
        );
      })}
    </div>
  );
}

// Page styles live with the page (tokens only, no hex values).
export const REF_CSS = `
.ref-page { display: flex; flex-wrap: wrap; gap: 40px; align-items: flex-start; flex-direction: row; }
.ref-index { flex: 1 1 200px; max-width: 240px; display: flex; flex-direction: column; gap: var(--space-4); font-size: 15px; line-height: 22px; }
.ref-index-group { display: flex; flex-direction: column; gap: 6px; }
.ref-index a { font-family: var(--font-mono); overflow-wrap: anywhere; }
.ref-index a[aria-current="page"] { color: var(--ink); font-weight: 500; }
.ref-article { flex: 999 1 560px; min-width: 0; display: flex; flex-direction: column; gap: 28px; }
.ref-head { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-4); }
.ref-head h1 { font-family: var(--font-mono); font-size: 32px; line-height: 40px; font-weight: 500; overflow-wrap: anywhere; min-width: 0; }
.ref-toggle { margin-left: auto; }
.ref-head h1.ref-idx-title { font-family: var(--font-sans); font-weight: 700; }
.ref-toggle .ref-toggle-link { display: inline-flex; align-items: center; font: 600 13px/18px var(--font-sans); min-height: 32px; padding: 0 14px; color: var(--ink-muted); }
.ref-toggle .ref-toggle-link:hover { text-decoration: none; background: var(--surface-sunken); color: var(--ink); }
.ref-toggle button:disabled { cursor: not-allowed; opacity: 0.5; }
.ref-prose { font-size: 17px; line-height: 27px; max-width: 720px; display: flex; flex-direction: column; gap: var(--space-3); }
.ref-prose p, .ref-prose ul, .ref-prose ol, .ref-prose dl { margin: 0; }
.ref-prose ul, .ref-prose ol { padding-left: 1.4em; display: flex; flex-direction: column; gap: 4px; }
.ref-prose li > p { display: inline; }
.ref-prose li > ul { margin-top: 4px; }
.ref-prose dt { font-family: var(--font-mono); font-size: 15px; }
.ref-prose dd { margin: 0 0 var(--space-2) var(--space-5); }
.ref-prose h4 { margin: 0; font-size: 17px; }
.ref-prose code, .ref-args code { font-family: var(--font-mono); font-size: 0.9em; overflow-wrap: anywhere; }
.ref-source { font-size: 13px; line-height: 18px; color: var(--ink-muted); overflow-wrap: anywhere; }
.ref-section { display: flex; flex-direction: column; gap: 10px; min-width: 0; }
.ref-section h2 { font-size: 24px; line-height: 32px; font-weight: 600; }
.ref-section-head { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
.ref-section-head .btn { margin-left: auto; }
.ref-args { border-collapse: collapse; width: 100%; table-layout: fixed; }
.ref-args th, .ref-args td { padding: 10px 12px; text-align: left; vertical-align: top; font-size: 15px; line-height: 22px; border-bottom: 1px solid var(--line); overflow-wrap: anywhere; }
.ref-args th { font-size: 13px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--ink-muted); background: var(--surface-sunken); font-weight: 600; }
.ref-args th:first-child { width: 190px; }
.ref-args td:first-child { font-family: var(--font-mono); }
.ref-empty { color: var(--ink-muted); }
.ref-idx { display: flex; flex-direction: column; gap: var(--space-6); }
.ref-idx-group { display: flex; flex-direction: column; gap: var(--space-3); }
.ref-idx-group h2 { font-size: 24px; line-height: 32px; font-weight: 600; }
.ref-idx-list { display: grid; grid-template-columns: minmax(180px, 260px) minmax(0, 1fr); border-top: 1px solid var(--line); }
.ref-idx-list > * { padding: 10px 12px 10px 0; border-bottom: 1px solid var(--line); font-size: 15px; line-height: 22px; min-width: 0; }
.ref-idx-list a { font-family: var(--font-mono); overflow-wrap: anywhere; }
.ref-idx-list span { color: var(--ink-muted); }
@media (max-width: 760px) {
  .ref-page { gap: var(--space-6); }
  .ref-index { order: 2; max-width: none; flex-basis: 100%; border-top: 1px solid var(--line); padding-top: var(--space-4); }
  .ref-article { gap: var(--space-5); flex-basis: 100%; }
  .ref-head h1 { font-size: 26px; line-height: 32px; }
  .ref-prose { font-size: 16px; line-height: 25px; }
  .ref-section h2 { font-size: 21px; line-height: 28px; }
  .ref-args th:first-child { width: 38%; }
  .ref-args th, .ref-args td { padding: 8px; font-size: 14px; line-height: 20px; }
  .ref-idx-list { grid-template-columns: 1fr; }
  .ref-idx-list a { border-bottom: 0; padding-bottom: 0; }
}
`;

function Html({ html, className = "ref-prose" }) {
  return <div className={className} dangerouslySetInnerHTML={{ __html: html }} />;
}

function Section({ title, children, action }) {
  return (
    <section className="ref-section">
      {action ? (
        <div className="ref-section-head">
          <h2>{title}</h2>
          {action}
        </div>
      ) : (
        <h2>{title}</h2>
      )}
      {children}
    </section>
  );
}

function SideIndex({ lang, current }) {
  return (
    <nav aria-label="Reference index" className="ref-index">
      {groupTopics(lang).map(([group, topics]) => (
        <div key={group} className="ref-index-group">
          <span className="eyebrow">{group}</span>
          {topics.map((t) => (
            <Link key={t.name} to={hrefFor(lang, t.name)} aria-current={t.name === current ? "page" : undefined}>
              {displayName(t)}
            </Link>
          ))}
        </div>
      ))}
    </nav>
  );
}

function NotFound({ lang, name }) {
  return (
    <article className="ref-article" data-notfound="">
      <div className="ref-head">
        <h1>{name}</h1>
      </div>
      <p className="ref-prose">
        The {LANGS[lang].label} package has no topic called <code>{name}</code>.{" "}
        <Link to={`${LANGS[lang].base}/`}>Browse the {LANGS[lang].label} reference</Link>.
      </p>
    </article>
  );
}

export function TopicPage({ lang, topic }) {
  const data = LANGS[lang].data;
  const other = counterpart(lang, topic);
  const targets = { [lang]: hrefFor(lang, topic.name) };
  if (other) targets[other.lang] = hrefFor(other.lang, other.name);
  const exampleLang = lang === "R" ? "R" : "Python";
  return (
    <article className="ref-article" aria-labelledby="ref-title">
      <div className="ref-head">
        <h1 id="ref-title">{displayName(topic)}</h1>
        <LangToggle lang={lang} targets={targets} />
      </div>
      {topic.description ? <Html html={topic.description} /> : null}
      <span className="ref-source">
        Generated from <span className="mono">{topic.source_file}</span> · package version {data.version}
      </span>
      {topic.usage ? (
        <Section title="Usage">
          <pre className="code">
            <Code text={topic.usage} />
          </pre>
        </Section>
      ) : null}
      {topic.arguments.length ? (
        <Section title="Arguments">
          <table className="ref-args">
            <thead>
              <tr>
                <th scope="col">Argument</th>
                <th scope="col">Description</th>
              </tr>
            </thead>
            <tbody>
              {topic.arguments.map((a) => (
                <tr key={a.name}>
                  <td>{a.name}</td>
                  <td dangerouslySetInnerHTML={{ __html: a.description }} />
                </tr>
              ))}
            </tbody>
          </table>
        </Section>
      ) : null}
      {topic.format ? (
        <Section title="Format">
          <Html html={topic.format} />
        </Section>
      ) : null}
      {topic.value ? (
        <Section title="Value">
          <Html html={topic.value} />
        </Section>
      ) : null}
      {topic.details ? (
        <Section title="Details">
          <Html html={topic.details} />
        </Section>
      ) : null}
      {topic.sections.map((s) => (
        <Section key={s.title} title={s.title}>
          <Html html={s.html} />
        </Section>
      ))}
      {topic.examples ? (
        <Section
          title="Examples"
          action={
            <button type="button" className="btn btn-run btn-sm" disabled title="Live runtime coming soon">
              ▶ Run
            </button>
          }
        >
          <pre className="code" aria-label={`${exampleLang} example`}>
            <Code text={topic.examples} />
          </pre>
        </Section>
      ) : null}
      {topic.seealso ? (
        <Section title="See also">
          <Html html={topic.seealso} />
        </Section>
      ) : null}
    </article>
  );
}

export default function Reference({ lang }) {
  const { file = "" } = useParams();
  const name = decodeURIComponent(file).replace(/\.html$/, "");
  const topic = findTopic(lang, name);
  const onClick = useInternalLinks();
  const canonical = topic ? topic.name : name;

  useEffect(() => {
    document.title = topic
      ? `${displayName(topic)} · tidyfault ${LANGS[lang].label} reference`
      : `Not found · tidyfault ${LANGS[lang].label} reference`;
  }, [lang, topic]);

  return (
    <div className="page" style={{ gap: "var(--space-6)" }}>
      <style>{REF_CSS}</style>
      <NavBar active={lang} />
      <main className="page-main" onClick={onClick}>
        <div className="section ref-page" id="reference">
          <SideIndex lang={lang} current={canonical} />
          {topic ? <TopicPage lang={lang} topic={topic} /> : <NotFound lang={lang} name={name} />}
        </div>
      </main>
      <Footer />
    </div>
  );
}
