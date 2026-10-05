import { Link } from "react-router-dom";
import { LOGO_HALO } from "./logoHalo.js";

const LINKS = [
  { to: "/#start", label: "Get started" },
  { to: "/articles/", label: "Articles" },
  { to: "/reference/", label: "Reference · R", lang: "R" },
  { to: "/reference-py/", label: "Reference · Python", lang: "Python" },
];

// `active` is "R" or "Python" on reference pages (underlines that link, as the design does).
export default function NavBar({ active }) {
  const current = { borderBottom: "2px solid var(--mako-10)" };
  return (
    <header className="nav">
      <div className="nav-inner">
        <Link className="nav-brand" to="/">
          <img src="/logo.png" alt="" style={{ filter: LOGO_HALO }} />
          tidyfault
        </Link>
        <nav className="nav-links" aria-label="Primary">
          {LINKS.map((l) => {
            const on = Boolean(active) && l.lang === active;
            return (
              <Link key={l.label} to={l.to} aria-current={on ? "page" : undefined} style={on ? current : undefined}>
                {l.label}
              </Link>
            );
          })}
          <a href="https://github.com/timothyfraser/tidyfault">GitHub</a>
          {/* A plain link, not a router Link: /slides/ is a static deck in public/slides/. */}
          <a className="nav-slides" href="/slides/">Slides</a>
        </nav>
      </div>
    </header>
  );
}
