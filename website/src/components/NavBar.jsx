import { LOGO_HALO } from "./logoHalo.js";

const LINKS = [
  { href: "#start", label: "Get started" },
  { href: "#articles", label: "Articles" },
  { href: "#reference", label: "Reference · R" },
  { href: "#reference", label: "Reference · Python" },
  { href: "https://github.com/timothyfraser/tidyfault", label: "GitHub" },
];

export default function NavBar() {
  return (
    <header className="nav">
      <div className="nav-inner">
        <a className="nav-brand" href="#top">
          <img src="/logo.png" alt="" style={{ filter: LOGO_HALO }} />
          tidyfault
        </a>
        <nav className="nav-links" aria-label="Primary">
          {LINKS.map((l) => (
            <a key={l.label} href={l.href}>
              {l.label}
            </a>
          ))}
        </nav>
      </div>
    </header>
  );
}
