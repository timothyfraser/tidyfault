import { useEffect } from "react";
import { Link } from "react-router-dom";
import NavBar from "../components/NavBar.jsx";
import Footer from "../components/Footer.jsx";
import articles from "../generated/articles/index.json";

const CLAMP = {
  display: "-webkit-box",
  WebkitLineClamp: 4,
  WebkitBoxOrient: "vertical",
  overflow: "hidden",
};

export default function Articles() {
  useEffect(() => {
    document.title = "Articles · tidyfault";
  }, []);

  return (
    <div className="page">
      <NavBar />
      <main className="page-main">
        <section className="section" id="articles">
          <div className="stack-sm">
            <span className="eyebrow">Articles</span>
            <h1 style={{ fontSize: "var(--text-display-sm-size)", lineHeight: "var(--text-display-sm-leading)" }}>
              Learn the workflow, one vignette at a time
            </h1>
            <p className="lede-sm">
              Every article is a package vignette, rendered at 300 dpi. The code is the code that ships with
              tidyfault.
            </p>
          </div>
          <div className="grid-3">
            {articles.map((a) => (
              <Link className="card card-link" to={`/articles/${a.name}.html`} key={a.name}>
                <span className="eyebrow">Article</span>
                <span className="card-title">{a.title}</span>
                <span className="card-text" style={CLAMP}>
                  {a.description}
                </span>
              </Link>
            ))}
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
}
