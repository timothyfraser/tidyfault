// Agent-facing content (WEB-06). Runs after `vite build` and writes into dist/:
//   llms.txt                 the llmstxt.org index (links point at the Markdown pages below)
//   llms-full.txt            every page below, concatenated
//   reference/<name>.md      one Markdown page per R topic
//   reference-py/<name>.md   one per Python topic
//   articles/<name>.md       one per article
// Everything is generated from src/generated/ (the reference JSON and the article HTML
// fragments), so it cannot drift from the packages. The "Copy as Markdown" button fetches
// these same files. Dependency-free: a small HTML -> Markdown converter lives below.
// Usage: node scripts/build-llms.mjs [--out dist]
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outArg = process.argv.indexOf("--out");
const out = join(root, outArg > 0 ? process.argv[outArg + 1] : "dist");
const BASE = "https://tidyfault.netlify.app";
const REPO = "https://github.com/timothyfraser/tidyfault";
const gen = (...p) => join(root, "src/generated", ...p);

// ---- HTML -> Markdown -------------------------------------------------------------------
const VOID = new Set(["img", "br", "hr", "col", "input", "meta", "link"]);
const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", ndash: "-", mdash: "-", hellip: "..." };
const decode = (s) =>
  s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
    if (e[0] === "#") return String.fromCodePoint(e[1].toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10));
    return ENTITIES[e.toLowerCase()] ?? m;
  });

// MathML -> its TeX annotation, before parsing.
function mathToTex(html) {
  return html.replace(/<math\b([^>]*)>([\s\S]*?)<\/math>/g, (_, attrs, body) => {
    const tex = /<annotation[^>]*application\/x-tex[^>]*>([\s\S]*?)<\/annotation>/.exec(body)?.[1];
    const text = tex ?? body.replace(/<[^>]+>/g, "");
    const d = /display="block"/.test(attrs) ? "$$" : "$";
    return `\u0001${d}${decode(text).trim()}${d}\u0002`;
  });
}

function parse(html) {
  const rootNode = { tag: "#root", attrs: {}, children: [] };
  const stack = [rootNode];
  const re = /<!--[\s\S]*?-->|<(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:"[^"]*"|'[^']*'|[^>"'])*)>|([^<]+|<)/g;
  for (const m of mathToTex(html).matchAll(re)) {
    const top = stack[stack.length - 1];
    if (m[4] !== undefined) top.children.push({ text: m[4] });
    else if (m[2]) {
      const tag = m[2].toLowerCase();
      if (m[1]) {
        const i = stack.map((n) => n.tag).lastIndexOf(tag);
        if (i > 0) stack.length = i;
      } else {
        const attrs = {};
        for (const a of m[3].matchAll(/([a-zA-Z_:-][\w:.-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g)) attrs[a[1].toLowerCase()] = decode(a[2] ?? a[3] ?? a[4] ?? "");
        const node = { tag, attrs, children: [] };
        top.children.push(node);
        if (!VOID.has(tag) && !/\/\s*$/.test(m[3])) stack.push(node);
      }
    }
  }
  return rootNode.children;
}

const textOf = (nodes) => nodes.map((n) => (n.text !== undefined ? decode(n.text) : textOf(n.children))).join("");
const BLOCK = new Set(["p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "ul", "ol", "dl", "table", "hr", "div", "section", "figure", "blockquote", "article", "header", "footer", "nav", "main", "aside", "details", "summary"]);
const INLINE_BREAKS = /\s+/g;

function fenced(code, lang = "") {
  const body = code.replace(/\n+$/, "");
  const fence = "`".repeat(Math.max(3, ...[...body.matchAll(/`+/g)].map((m) => m[0].length + 1)));
  return `${fence}${lang}\n${body}\n${fence}`;
}

// Resolves a link found in generated HTML to an absolute URL, preferring the Markdown twin.
let linkResolver = (href) => href;
function absolutize(href) {
  if (!href || href.startsWith("#") || /^[a-z][a-z0-9+.-]*:/i.test(href)) return href;
  return linkResolver(href);
}

function inline(nodes) {
  let s = "";
  for (const n of nodes) {
    if (n.text !== undefined) {
      s += decode(n.text).replace(INLINE_BREAKS, " ");
      continue;
    }
    const kids = () => inline(n.children);
    switch (n.tag) {
      case "code": {
        const only = n.children.length === 1 && n.children[0].tag === "a" ? n.children[0] : null;
        if (only) {
          const t = textOf(only.children).replace(INLINE_BREAKS, " ");
          const href = absolutize(only.attrs.href);
          s += href && t ? `[\`${t}\`](${href})` : `\`${t}\``;
          break;
        }
        const t = textOf(n.children).replace(INLINE_BREAKS, " ");
        const tick = "`".repeat(Math.max(1, ...[...t.matchAll(/`+/g)].map((m) => m[0].length + 1)));
        s += t ? `${tick}${t.startsWith("`") || t.endsWith("`") ? ` ${t} ` : t}${tick}` : "";
        break;
      }
      case "strong": case "b": { const t = kids().trim(); s += t ? `**${t}**` : ""; break; }
      case "em": case "i": { const t = kids().trim(); s += t ? `*${t}*` : ""; break; }
      case "a": {
        const t = kids().trim();
        const href = absolutize(n.attrs.href);
        s += href && t ? `[${t}](${href})` : t;
        break;
      }
      case "br": s += "  \n"; break;
      case "img": s += n.attrs.alt ? `[image: ${n.attrs.alt}]` : ""; break;
      default: s += kids();
    }
  }
  return s.replace(/\u0001|\u0002/g, "");
}

function listBlock(node, depth = 0) {
  const ordered = node.tag === "ol";
  let i = Number(node.attrs.start ?? 1);
  const items = node.children.filter((c) => c.tag === "li");
  return items
    .map((li) => {
      const marker = ordered ? `${i++}. ` : "- ";
      const pad = " ".repeat(marker.length);
      const parts = blocks(li.children);
      let text = "";
      parts.forEach((p, k) => {
        const isList = /^(?:[-*] |\d+\. )/.test(p) && li.children.some((c) => (c.tag === "ul" || c.tag === "ol") && k > 0);
        text += k === 0 ? p : isList ? `\n${p}` : `\n\n${p}`;
      });
      return marker + text.split("\n").map((l, k) => (k === 0 || l === "" ? l : pad + l)).join("\n");
    })
    .join("\n");
}

function dlBlock(node) {
  const lines = [];
  let term = null;
  for (const c of node.children) {
    if (c.tag === "dt") term = inline(c.children).trim();
    else if (c.tag === "dd") {
      const d = blocks(c.children).join(" ").replace(/\s*\n\s*/g, " ").trim();
      lines.push(term ? `- ${term}: ${d}` : `- ${d}`);
      term = null;
    }
  }
  return lines.join("\n");
}

function tableBlock(node) {
  const rows = [];
  let caption = "";
  const walk = (ns) => {
    for (const c of ns) {
      if (c.tag === "caption") caption = inline(c.children).trim();
      else if (c.tag === "tr") rows.push(c.children.filter((x) => x.tag === "th" || x.tag === "td").map((x) => inline(x.children).replace(/\|/g, "\\|").trim() || " "));
      else if (c.children) walk(c.children);
    }
  };
  walk(node.children);
  if (!rows.length) return caption ? `**${caption}**` : "";
  const width = Math.max(...rows.map((r) => r.length));
  const fmt = (r) => `| ${[...r, ...Array(width - r.length).fill(" ")].join(" | ")} |`;
  const md = [fmt(rows[0]), fmt(Array(width).fill("---")), ...rows.slice(1).map(fmt)].join("\n");
  return caption ? `**${caption}**\n\n${md}` : md;
}

// Block-level nodes -> an array of Markdown blocks (one string per paragraph, list, fence, ...).
function blocks(nodes) {
  const out = [];
  let buf = [];
  const flush = () => {
    const t = inline(buf).replace(/[ \t]*\n[ \t]*/g, (m) => (m.includes("  ") ? m : " ")).trim();
    if (t) out.push(t);
    buf = [];
  };
  for (const n of nodes) {
    if (n.text !== undefined || !BLOCK.has(n.tag)) {
      buf.push(n);
      continue;
    }
    flush();
    switch (n.tag) {
      case "p": { const t = inline(n.children).trim(); if (t) out.push(t); break; }
      case "h1": case "h2": case "h3": case "h4": case "h5": case "h6":
        out.push(`${"#".repeat(Number(n.tag[1]))} ${inline(n.children).trim()}`);
        break;
      case "pre": {
        const cls = `${n.attrs.class ?? ""} ${n.children.find((c) => c.tag === "code")?.attrs.class ?? ""}`;
        const lang = /\b(r|python|py|bash|sh|yaml|json)\b/i.exec(cls)?.[1]?.toLowerCase();
        out.push(fenced(textOf(n.children).replace(/\u0001|\u0002/g, ""), lang === "py" ? "python" : (lang ?? "text")));
        break;
      }
      case "ul": case "ol": out.push(listBlock(n)); break;
      case "dl": out.push(dlBlock(n)); break;
      case "table": { const t = tableBlock(n); if (t) out.push(t); break; }
      case "hr": out.push("---"); break;
      case "blockquote": out.push(blocks(n.children).join("\n\n").split("\n").map((l) => `> ${l}`.trimEnd()).join("\n")); break;
      default: out.push(...blocks(n.children));
    }
  }
  flush();
  return out.filter(Boolean);
}

const toMd = (html) => (html ? blocks(parse(html)).join("\n\n") : "");

// ---- pages ------------------------------------------------------------------------------
const refData = {
  R: JSON.parse(readFileSync(gen("reference-r.json"), "utf8")),
  Python: JSON.parse(readFileSync(gen("reference-py.json"), "utf8")),
};
const REF = {
  R: { dir: "reference", label: "R", fence: "r" },
  Python: { dir: "reference-py", label: "Python", fence: "python" },
};
const articles = JSON.parse(readFileSync(gen("articles/index.json"), "utf8"));

// Same rule as src/pages/Reference.jsx displayName().
const displayName = (t) => (t.kind === "function" || t.kind === "S3 method" || t.kind === "class" ? `${t.name}()` : t.name);

// Known Markdown pages, so links in generated HTML can point at the .md twin.
const known = new Map(); // "reference/foo" -> "reference/foo.md"
for (const [lang, { dir }] of Object.entries(REF))
  for (const t of refData[lang].topics) for (const a of [t.name, ...t.aliases]) if (!known.has(`${dir}/${a}`)) known.set(`${dir}/${a}`, `${dir}/${t.name}.md`);
for (const a of articles) known.set(`articles/${a.name}`, `articles/${a.name}.md`);

// base: the site path of the page the HTML came from ("articles/" or "reference/"), for ../ links.
function makeResolver(basePath) {
  return (href) => {
    const u = new URL(href, `${BASE}/${basePath}`);
    const path = u.pathname.replace(/^\//, "").replace(/\.html$/, "");
    const md = known.get(path);
    return md ? `${BASE}/${md}${u.hash}` : u.href;
  };
}

const firstSentence = (s, max = 180) => {
  const t = s.replace(/\s+/g, " ").trim();
  const m = /^(.+?(?<!\bvs|\be\.g|\bi\.e)[.!?])(?=\s+[A-Z]|\s*$)/.exec(t);
  const one = m ? m[1] : t;
  return one.length > max ? `${one.slice(0, max - 3).trimEnd()}...` : one;
};

function topicMd(lang, topic) {
  const { dir, label, fence } = REF[lang];
  const data = refData[lang];
  linkResolver = makeResolver(`${dir}/`);
  const parts = [`# ${displayName(topic)}`];
  parts.push(`*${label} reference, ${data.package} ${data.version}. Web page: ${BASE}/${dir}/${topic.name}.html*`);
  const desc = toMd(topic.description) || topic.summary;
  if (desc) parts.push(desc);
  const section = (title, body) => body && parts.push(`## ${title}\n\n${body}`);
  if (topic.usage) section("Usage", fenced(topic.usage, fence));
  if (topic.arguments.length)
    section("Arguments", topic.arguments.map((a) => `- \`${a.name}\`: ${toMd(a.description).replace(/\s*\n+\s*/g, " ")}`.trimEnd()).join("\n"));
  section("Format", toMd(topic.format));
  section("Value", toMd(topic.value));
  section("Details", toMd(topic.details));
  for (const s of topic.sections) section(s.title, toMd(s.html));
  if (topic.examples) section("Examples", fenced(topic.examples, fence));
  section("See also", toMd(topic.seealso));
  return `${parts.join("\n\n")}\n`;
}

function articleMd(meta) {
  linkResolver = makeResolver("articles/");
  const html = readFileSync(gen("articles", meta.file), "utf8");
  let n = 0;
  const withFigures = html.replace(/<img\b[^>]*>/g, () => `<p>[Figure ${++n}: drawn on the web page, ${BASE}/articles/${meta.name}.html]</p>`);
  return `# ${meta.title}\n\n*Article, tidyfault. Web page: ${BASE}/articles/${meta.name}.html*\n\n${toMd(withFigures)}\n`;
}

// ---- emit -------------------------------------------------------------------------------
if (!existsSync(out)) {
  console.error(`build-llms: ${out} does not exist; run vite build first`);
  process.exit(1);
}
const write = (rel, text) => {
  const p = join(out, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, text);
};

const pages = []; // { rel, title, note, md, section }
for (const a of articles) pages.push({ section: "Articles", rel: `articles/${a.name}.md`, title: a.title, note: firstSentence(a.description), md: articleMd(a) });
for (const lang of ["R", "Python"])
  for (const t of refData[lang].topics)
    pages.push({ section: `${lang} reference`, rel: `${REF[lang].dir}/${t.name}.md`, title: displayName(t), note: firstSentence(t.summary || toMd(t.description)), md: topicMd(lang, t) });
for (const p of pages) write(p.rel, p.md);

// Package one-liner from DESCRIPTION when it is there (the website lives inside the package repo).
function packageSummary() {
  const fallback = "Fault tree analysis with tidy data. Represents a fault tree as tables of nodes and edges, derives minimal cut sets and top event probabilities, evaluates binary and probabilistic scenarios, and draws the tree.";
  try {
    const d = readFileSync(join(root, "..", "DESCRIPTION"), "utf8");
    const m = /^Description:\s*((?:.*\n)(?:[ \t]+.*\n?)*)/m.exec(d);
    return m ? m[1].replace(/\s+/g, " ").replace(/'/g, "").trim() : fallback;
  } catch {
    return fallback;
  }
}

const version = refData.R.version;
const link = (p) => `- [${p.title}](${BASE}/${p.rel})${p.note ? `: ${p.note}` : ""}`;
const sectionOf = (name) => pages.filter((p) => p.section === name).map(link).join("\n");
const llms = `# tidyfault

> tidyfault is an R package, with a Python twin. ${packageSummary()} Version ${version}.

Every link below is a plain Markdown page generated from the package documentation at build time. The top event of a tree is not a gate. Use the R reference for R code and the Python reference for Python code; the two share function names.

## Install

- R: \`remotes::install_github("timothyfraser/tidyfault")\`
- Python: \`pip install "git+https://github.com/timothyfraser/tidyfault#subdirectory=python"\`

## Articles

${sectionOf("Articles")}

## R reference

${sectionOf("R reference")}

## Python reference

${sectionOf("Python reference")}

## Optional

- [Everything in one file](${BASE}/llms-full.txt): all articles and reference pages above, concatenated
- [Website](${BASE}/): the same content as web pages, with a Copy as Markdown button on each page
- [Source on GitHub](${REPO}): the R package, the Python package and this website
`;
write("llms.txt", llms);

const full = `${llms.split("\n## ")[0].trimEnd()}\n\n${pages.map((p) => p.md.trimEnd()).join("\n\n---\n\n")}\n`;
write("llms-full.txt", full);

console.log(`build-llms: wrote llms.txt, llms-full.txt and ${pages.length} Markdown pages (${articles.length} articles, ${refData.R.topics.length} R topics, ${refData.Python.topics.length} Python topics) into ${out}`);
