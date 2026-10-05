// Routes. BrowserRouter (see main.jsx), so deep links like /reference/concentrate.html
// need the host to fall back to index.html: netlify.toml (DEP-01) needs
//   [[redirects]] from = "/*"  to = "/index.html"  status = 200
// (`vite preview` and `vite dev` already do this.) /reference/<fn>.html and /articles/<name>.html keep
// the old pkgdown URLs working.
import { Suspense, lazy, useEffect } from "react";
import { Link, Route, Routes, useLocation } from "react-router-dom";
import Home from "./pages/Home.jsx";
import NavBar from "./components/NavBar.jsx";
import Footer from "./components/Footer.jsx";

const Reference = lazy(() => import("./pages/Reference.jsx"));
const ReferenceIndex = lazy(() => import("./pages/ReferenceIndex.jsx"));
const Articles = lazy(() => import("./pages/Articles.jsx")); // WEB-03
const Article = lazy(() => import("./pages/Article.jsx")); // WEB-03; strips a trailing .html itself

// Scroll to the top on a new page, or to #id when the URL carries one (e.g. /#start).
function ScrollOnNavigate() {
  const { pathname, hash } = useLocation();
  useEffect(() => {
    if (!hash) {
      window.scrollTo(0, 0);
      return;
    }
    const id = decodeURIComponent(hash.slice(1));
    const t = setTimeout(() => document.getElementById(id)?.scrollIntoView(), 0);
    return () => clearTimeout(t);
  }, [pathname, hash]);
  return null;
}

function NotFound() {
  useEffect(() => {
    document.title = "Not found · tidyfault";
  }, []);
  return (
    <div className="page">
      <NavBar />
      <main className="page-main">
        <section className="section" id="reference" data-notfound="">
          <h1>Page not found</h1>
          <p className="lede-sm">
            Try the <Link to="/">home page</Link>, the <Link to="/reference/">R reference</Link> or the{" "}
            <Link to="/reference-py/">Python reference</Link>.
          </p>
        </section>
      </main>
      <Footer />
    </div>
  );
}

export default function App() {
  return (
    <>
      <ScrollOnNavigate />
      <Suspense fallback={<div className="page" />}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/index.html" element={<Home />} />
          <Route path="/articles/" element={<Articles />} />
          <Route path="/articles/:name" element={<Article />} />
          <Route path="/reference" element={<ReferenceIndex lang="R" />} />
          <Route path="/reference/index.html" element={<ReferenceIndex lang="R" />} />
          <Route path="/reference/:file" element={<Reference lang="R" />} />
          <Route path="/reference-py" element={<ReferenceIndex lang="Python" />} />
          <Route path="/reference-py/index.html" element={<ReferenceIndex lang="Python" />} />
          <Route path="/reference-py/:file" element={<Reference lang="Python" />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Suspense>
    </>
  );
}
