import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import NavBar from "../components/NavBar.jsx";
import Footer from "../components/Footer.jsx";
import articles from "../generated/articles/index.json";

// Fragments are loaded lazily (one chunk per article); figure URLs are resolved
// eagerly so Vite hashes and emits the PNGs and we can rewrite <img src>.
const FRAGMENTS = import.meta.glob("../generated/articles/*/*.html", {
  query: "?raw",
  import: "default",
});
const FIGURES = import.meta.glob("../generated/articles/*/figures/*.png", {
  query: "?url",
  import: "default",
  eager: true,
});

function stripExt(s) {
  return String(s || "").replace(/\.html$/, "");
}

// Point each relative figure at its hashed build URL and give it an alt text.
function prepare(html, name, title) {
  let n = 0;
  return html.replace(/<img\b[^>]*>/g, (tag) => {
    n += 1;
    const src = /src="figures\/([^"]+)"/.exec(tag);
    if (!src) return tag;
    const url = FIGURES[`../generated/articles/${name}/figures/${src[1]}`];
    if (!url) return tag;
    return `<img src="${url}" alt="Figure ${n} from the article ${title}" decoding="async" />`;
  });
}

export const ARTICLE_CSS = `
.article { align-items: stretch; }
.article-col { width: 100%; max-width: 72ch; margin: 0 auto; display: flex; flex-direction: column; gap: var(--space-5); min-width: 0; }
.article-head { display: flex; flex-direction: column; gap: var(--space-3); padding-top: var(--space-6); }
.article-head h1 { font-size: var(--text-display-sm-size); line-height: var(--text-display-sm-leading); font-weight: var(--text-display-sm-weight); letter-spacing: var(--text-display-sm-tracking); overflow-wrap: anywhere; }
.article-head .lede-sm { max-width: none; }
.article-body { font-size: var(--text-body-size); line-height: var(--text-body-leading); min-width: 0; overflow-wrap: break-word; }
.article-body h2 { font-size: var(--text-h2-size); line-height: var(--text-h2-leading); font-weight: var(--text-h2-weight); margin: var(--space-7) 0 var(--space-3); }
.article-body h3 { margin: var(--space-6) 0 var(--space-2); }
.article-body p, .article-body ul, .article-body ol, .article-body table, .article-body img, .article-body figure { margin: 0 0 var(--space-4); }
.article-body ul, .article-body ol { padding-left: 1.4em; }
.article-body li + li { margin-top: var(--space-1); }
.article-body a { text-decoration: underline; text-underline-offset: 2px; }
.article-body code { font-family: var(--font-mono); font-size: var(--text-code-inline-size); font-weight: var(--text-code-inline-weight); background: var(--surface-sunken); padding: 1px 5px; border-radius: var(--radius-sm); }
.article-body pre { margin: 0 0 var(--space-4); padding: 20px var(--space-5); background: var(--code-surface); color: var(--code-ink); border-radius: var(--radius-md); overflow: auto; font-family: var(--font-mono); font-size: var(--text-code-size); line-height: var(--text-code-leading); }
.article-body pre code { background: none; padding: 0; font-size: inherit; font-weight: var(--text-code-weight); border-radius: 0; }
.article-body pre.r { border-bottom-left-radius: 0; border-bottom-right-radius: 0; margin-bottom: 0; }
.article-body pre.r + pre { border-top: 1px solid var(--mako-2); border-top-left-radius: 0; border-top-right-radius: 0; }
.article-body pre.r:not(:has(+ pre)) { border-radius: var(--radius-md); margin-bottom: var(--space-4); }
.article-body table { display: block; max-width: 100%; overflow-x: auto; border-collapse: collapse; font-size: var(--text-body-sm-size); line-height: var(--text-body-sm-leading); }
.article-body caption { caption-side: top; text-align: left; padding-bottom: var(--space-2); color: var(--ink-muted); font-size: var(--text-caption-size); font-weight: var(--text-caption-weight); letter-spacing: var(--text-caption-tracking); text-transform: uppercase; }
.article-body th, .article-body td { padding: 6px 14px 6px 0; border-bottom: 1px solid var(--line); white-space: nowrap; }
.article-body th { font-weight: 600; border-bottom-color: var(--edge); }
.article-body img { display: block; max-width: 100%; height: auto; margin-left: auto; margin-right: auto; border-radius: var(--radius-md); background: var(--surface); }
.article-body math { font-size: 1.05em; }
.article-foot { display: flex; flex-wrap: wrap; justify-content: space-between; gap: var(--space-3); padding-top: var(--space-5); border-top: 1px solid var(--line); }
@media (max-width: 760px) {
  .article-head { padding-top: var(--space-4); }
  .article-head h1 { font-size: 32px; line-height: 38px; }
  .article-body h2 { margin-top: var(--space-6); }
  .article-body pre { padding: var(--space-4); font-size: 13px; line-height: 20px; }
}
`;

// Route component: /articles/:name  (a trailing ".html" is ignored), or pass
// the article name as the `name` prop.
export default function Article({ name: nameProp }) {
  const params = useParams();
  const name = stripExt(nameProp ?? params.name ?? params.file);
  const meta = articles.find((a) => a.name === name);
  const loader = FRAGMENTS[`../generated/articles/${name}/${name}.html`];

  const [raw, setRaw] = useState(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let live = true;
    setRaw(null);
    setFailed(false);
    if (!loader) {
      setFailed(true);
      return undefined;
    }
    loader()
      .then((html) => live && setRaw(html))
      .catch(() => live && setFailed(true));
    return () => {
      live = false;
    };
  }, [name, loader]);

  useEffect(() => {
    if (meta) document.title = `${meta.title} · tidyfault`;
  }, [meta]);

  const html = useMemo(() => (raw ? prepare(raw, name, meta?.title ?? name) : ""), [raw, name, meta]);

  return (
    <div className="page">
      <style>{ARTICLE_CSS}</style>
      <NavBar />
      <main className="page-main">
        <article className="section article">
          <div className="article-col">
            {meta ? (
              <header className="article-head">
                <span className="eyebrow">
                  <Link to="/articles/">Articles</Link>
                </span>
                <h1>{meta.title}</h1>
              </header>
            ) : (
              <header className="article-head">
                <span className="eyebrow">
                  <Link to="/articles/">Articles</Link>
                </span>
                <h1>Article not found</h1>
                <p className="lede-sm">There is no article called {name || "(empty)"}.</p>
              </header>
            )}
            {failed && meta && <p className="muted">This article could not be loaded.</p>}
            {html && <div className="article-body" dangerouslySetInnerHTML={{ __html: html }} />}
            <footer className="article-foot">
              <Link className="link-strong" to="/articles/">
                All articles
              </Link>
              <a className="link-strong" href="https://github.com/timothyfraser/tidyfault">
                Source on GitHub
              </a>
            </footer>
          </div>
        </article>
      </main>
      <Footer />
    </div>
  );
}
