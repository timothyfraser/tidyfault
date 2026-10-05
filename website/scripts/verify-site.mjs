// Playwright check of the built site. Usage: node scripts/verify-site.mjs [--url http://host:port]
// Home page at 1280 and 390 px, then every reference page: each R export (NAMESPACE export()
// and S3method() generics, plus documented datasets) and each name in tidyfault.__all__ must
// have a reachable page (deep link, as a visitor would land) with zero console errors and no
// horizontal overflow, and every internal link found on the way must resolve.
// Starts `vite preview` unless --url is given. Needs a chromium under /opt/pw-browsers (or CHROME_PATH).
import { chromium } from "playwright-core";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const shots = "/tmp/web01-shots";
const argUrl = process.argv.includes("--url") ? process.argv[process.argv.indexOf("--url") + 1] : null;

function findChrome() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  const base = "/opt/pw-browsers";
  for (const d of existsSync(base) ? readdirSync(base).sort() : []) {
    for (const rel of ["chrome-linux/chrome", "chrome-linux/headless_shell"]) {
      const p = join(base, d, rel);
      if (d.startsWith("chromium-") && existsSync(p)) return p;
    }
  }
  throw new Error("no chromium found under /opt/pw-browsers (set CHROME_PATH)");
}

async function startPreview() {
  const port = 4173 + Math.floor(Math.random() * 500);
  const proc = spawn(process.execPath, [join(root, "node_modules/vite/bin/vite.js"), "preview", "--port", String(port), "--strictPort", "--host", "127.0.0.1"], { cwd: root, stdio: "ignore" });
  const url = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 100; i++) {
    try { if ((await fetch(url)).ok) return { proc, url }; } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 200));
  }
  proc.kill();
  throw new Error("vite preview did not start (run npm run build first)");
}

const failures = [];
const internalLinks = new Set();
const fail = (m) => { failures.push(m); console.error("FAIL", m); };
const ok = (m) => console.log("ok  ", m);

const realErrors = (errors) =>
  errors.filter((e) => !/fonts\.(googleapis|gstatic)\.com|ERR_(BLOCKED|TUNNEL|CONNECTION|NAME|INTERNET|PROXY|CERT)/i.test(e) && !/Failed to load resource/.test(e));

function watch(page) {
  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("requestfailed", (r) => {
    // ERR_ABORTED = the previous page's request cancelled by our own next goto(), not a page error
    if (/ERR_ABORTED/.test(r.failure()?.errorText ?? "")) return;
    if (!/fonts\.(googleapis|gstatic)\.com/.test(r.url())) errors.push(`request failed: ${r.url()}`);
  });
  return errors;
}

async function overflow(page, width) {
  const sw = await page.evaluate(() => document.documentElement.scrollWidth);
  const over = await page.evaluate((w) => {
    const out = [];
    for (const el of document.querySelectorAll("body *")) {
      if (el.closest("pre")) continue; // code panes scroll inside themselves
      const rc = el.getBoundingClientRect();
      if (rc.width && rc.right > w + 1) out.push(`${el.tagName.toLowerCase()}.${String(el.className).slice(0, 30)} right=${Math.round(rc.right)}`);
    }
    return out.slice(0, 8);
  }, width);
  return sw > width ? [`scrollWidth ${sw}`, ...over] : over;
}

// What the packages export, read from the sources (not from the generated JSON).
function rExports() {
  const ns = readFileSync(join(root, "..", "NAMESPACE"), "utf8").split(/\r?\n/);
  const out = ns.map((l) => l.match(/^export\("?([^")]+)"?\)$/)?.[1]).filter(Boolean);
  for (const l of ns) { const m = l.match(/^S3method\(([^,]+),/); if (m) out.push(m[1]); }
  const gen = JSON.parse(readFileSync(join(root, "src/generated/reference-r.json"), "utf8"));
  for (const t of gen.topics) if (t.kind === "data") out.push(t.name);
  return [...new Set(out)];
}
function pyExports() {
  const init = readFileSync(join(root, "..", "python/src/tidyfault/__init__.py"), "utf8").replace(/#[^\n]*/g, "");
  let all = [];
  for (const m of init.matchAll(/__all__\s*(\+?=)\s*\[([\s\S]*?)\]/g)) {
    const names = [...m[2].matchAll(/["']([^"']+)["']/g)].map((x) => x[1]);
    all = m[1] === "=" ? names : all.concat(names);
  }
  return [...new Set(all)];
}

mkdirSync(shots, { recursive: true });
let preview = null;
let url = argUrl;
if (!url) ({ proc: preview, url } = await startPreview());
const browser = await chromium.launch({ executablePath: findChrome(), args: ["--no-sandbox"] });

try {
  for (const [name, width, height] of [["desktop", 1280, 900], ["phone", 390, 844]]) {
    const ctx = await browser.newContext({ viewport: { width, height } });
    const page = await ctx.newPage();
    const errors = [];
    page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    page.on("pageerror", (e) => errors.push(String(e)));
    page.on("requestfailed", (r) => {
      // Google Fonts is blocked in sandboxed runs; the font stack falls back. Not a page error.
      if (!/fonts\.(googleapis|gstatic)\.com/.test(r.url())) errors.push(`request failed: ${r.url()}`);
    });
    await page.goto(url, { waitUntil: "load" });
    await page.waitForSelector("h1");

    // console errors (a failed font fetch logs a console error in chromium; filter those only)
    const real = errors.filter((e) => !/fonts\.(googleapis|gstatic)\.com|ERR_(BLOCKED|TUNNEL|CONNECTION|NAME|INTERNET|PROXY|CERT)/i.test(e) && !/Failed to load resource/.test(e));
    if (real.length) fail(`${name}: console errors: ${real.join(" | ")}`); else ok(`${name}: zero console errors`);

    // links: hash targets exist; external are absolute https; internal routes resolved below
    const links = await page.$$eval("a[href]", (as) => as.map((a) => a.getAttribute("href")));
    const bad = [];
    for (const href of new Set(links)) {
      if (href.startsWith("#")) {
        const id = href.slice(1);
        if (!id || !(await page.$(`[id="${id}"]`))) bad.push(href);
      } else if (href.startsWith("/") && !href.startsWith("//")) internalLinks.add(href);
      else if (!/^https:\/\//.test(href)) bad.push(href);
    }
    if (bad.length) fail(`${name}: unresolved links: ${bad.join(", ")}`); else ok(`${name}: ${new Set(links).size} distinct links (in-page and external resolve; internal checked below)`);

    // toggle R/Python switches the code and output
    await page.click('button[aria-pressed="false"]:has-text("Python")');
    const py = await page.textContent(".chunk");
    if (!py.includes("['B*C', 'A*B*D']") || !py.includes("0.01285")) fail(`${name}: Python chunk output missing`);
    await page.click('button:has-text("R")');
    const r = await page.textContent(".chunk");
    if (!r.includes('[1] "B*C"') || !r.includes("[1] 0.01285")) fail(`${name}: R chunk output missing`);
    // Both tabs run live now (Pyodide RT-01, webR RT-02); the R tab keeps its saved output until run.
    if (await page.$eval(".chunk .btn-run", (b) => b.disabled)) fail(`${name}: R Run button should be enabled`);
    ok(`${name}: language toggle; R Run button enabled with the saved output shown`);

    // horizontal overflow
    const sw = await page.evaluate(() => document.documentElement.scrollWidth);
    const over = await page.evaluate((w) => {
      const out = [];
      for (const el of document.querySelectorAll("body *")) {
        if (el.closest("pre")) continue; // code panes scroll inside themselves
        const rc = el.getBoundingClientRect();
        if (rc.width && rc.right > w + 1) out.push(`${el.tagName.toLowerCase()}.${String(el.className).slice(0, 30)} right=${Math.round(rc.right)}`);
      }
      return out.slice(0, 8);
    }, width);
    if (sw > width) fail(`${name}: page scrollWidth ${sw} > ${width}`);
    if (over.length) fail(`${name}: elements overflow: ${over.join("; ")}`);
    if (sw <= width && !over.length) ok(`${name}: no horizontal overflow (scrollWidth ${sw})`);

    await page.screenshot({ path: join(shots, `${name}.png`), fullPage: true });
    console.log(`shot ${join(shots, `${name}.png`)}`);
    await ctx.close();
  }

  // ---- reference pages ------------------------------------------------------------------
  const pages = [
    ...rExports().map((n) => ["R", n, `/reference/${n}.html`]),
    ...pyExports().map((n) => ["Python", n, `/reference-py/${n}.html`]),
  ];
  for (const [name, width, height] of [["desktop", 1280, 900], ["phone", 390, 844]]) {
    const ctx = await browser.newContext({ viewport: { width, height } });
    const page = await ctx.newPage();
    const errors = watch(page);
    const broken = [];
    for (const [lang, fn, path] of pages) {
      errors.length = 0;
      await page.goto(url + path, { waitUntil: "load" });
      const h1 = await page.waitForSelector("h1", { timeout: 10000 }).catch(() => null);
      const missing = await page.$("[data-notfound]");
      const real = realErrors(errors);
      const over = await overflow(page, width);
      if (!h1 || missing) broken.push(`${path} (no page)`);
      if (real.length) broken.push(`${path} console: ${real.join(" | ")}`);
      if (over.length) broken.push(`${path} overflow: ${over.join("; ")}`);
      for (const href of await page.$$eval("a[href]", (as) => as.map((a) => a.getAttribute("href")))) {
        if (href.startsWith("/") && !href.startsWith("//")) internalLinks.add(href);
        else if (!href.startsWith("#") && !/^https:\/\//.test(href)) broken.push(`${path} bad link ${href}`);
      }
      if (lang === "R" && fn === "concentrate") await page.screenshot({ path: join(shots, `ref-concentrate-${name}.png`), fullPage: true });
    }
    const nR = pages.filter((p) => p[0] === "R").length;
    if (broken.length) fail(`${name}: reference pages: ${broken.slice(0, 12).join(" || ")}`);
    else ok(`${name}: ${pages.length} reference pages (${nR} R, ${pages.length - nR} Python) load with zero console errors and no overflow`);

    // the R | Python toggle switches language and keeps the function; Run stays disabled
    await page.goto(`${url}/reference/concentrate.html`, { waitUntil: "load" });
    await page.waitForSelector("#ref-title");
    await page.click('.ref-head [role="group"] >> text=Python');
    await page.waitForURL("**/reference-py/concentrate.html");
    const h1 = await page.textContent("#ref-title");
    const pyUsage = await page.textContent(".ref-article pre");
    if (h1 !== "concentrate()" || !pyUsage.includes("top='or'")) fail(`${name}: toggle to Python did not show the Python concentrate() page`);
    await page.click('.ref-head [role="group"] >> text=R');
    await page.waitForURL("**/reference/concentrate.html");
    const runDisabled = await page.$eval(".ref-section .btn-run", (b) => b.disabled);
    if (!runDisabled) fail(`${name}: reference Run button should be disabled`);
    ok(`${name}: reference R | Python toggle and disabled Run button`);

    for (const [lang, path] of [["r", "/reference/"], ["py", "/reference-py/"]]) {
      errors.length = 0;
      await page.goto(url + path, { waitUntil: "load" });
      await page.waitForSelector("h1");
      const n = await page.$$eval(".ref-idx-list a", (as) => as.length);
      const real = realErrors(errors);
      const over = await overflow(page, width);
      if (!n || real.length || over.length) fail(`${name}: ${path} index: ${n} links, errors ${real.join(" | ")}, overflow ${over.join("; ")}`);
      else ok(`${name}: ${path} index lists ${n} pages`);
      await page.screenshot({ path: join(shots, `ref-index-${lang}-${name}.png`), fullPage: true });
    }
    console.log(`shot ${join(shots, `ref-concentrate-${name}.png`)}`);
    await ctx.close();
  }

  // ---- every internal link seen on any page resolves (route renders, #id exists) --------
  {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await ctx.newPage();
    const bad = [];
    for (const href of [...internalLinks].sort()) {
      const [path, id] = href.split("#");
      await page.goto(url + path, { waitUntil: "load" });
      await page.waitForSelector("h1, h2", { timeout: 10000 }).catch(() => null);
      if (await page.$("[data-notfound]")) bad.push(href);
      else if (id && !(await page.$(`[id="${id}"]`))) bad.push(href);
    }
    if (bad.length) fail(`internal links do not resolve: ${bad.join(", ")}`);
    else ok(`${internalLinks.size} distinct internal links resolve`);
    await ctx.close();
  }

  // ---- articles (WEB-03): every /articles/<name>.html renders; no figure under 1600 px wide ----
  {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await ctx.newPage();
    const idx = JSON.parse(readFileSync(new URL("../src/generated/articles/index.json", import.meta.url), "utf8"));
    const names = (Array.isArray(idx) ? idx : idx.articles || []).map((a) => a.name || a.slug || a);
    const bad = [];
    let figs = 0;
    for (const n of names) {
      await page.goto(`${url}/articles/${n}.html`, { waitUntil: "networkidle" });
      if (await page.$("[data-notfound]")) { bad.push(`${n}: not found`); continue; }
      const widths = await page.$$eval("main img", (is) => is.map((i) => i.naturalWidth));
      figs += widths.length;
      widths.filter((w) => w < 1600).forEach((w) => bad.push(`${n}: figure ${w}px`));
    }
    if (!names.length) fail("articles: index.json lists no articles");
    else if (bad.length) fail(`articles: ${bad.join(", ")}`);
    else ok(`articles: ${names.length} pages render; ${figs} figures, all >= 1600 px wide`);
    await ctx.close();
  }

  // ---- agent-facing content (WEB-06): /llms.txt, /llms-full.txt, per-page .md, Copy as Markdown ----
  {
    const bad = [];
    const getText = async (path) => {
      const res = await fetch(url + path);
      const body = await res.text();
      const ct = res.headers.get("content-type") ?? "";
      if (res.status !== 200) bad.push(`${path}: HTTP ${res.status}`);
      else if (!body.trim()) bad.push(`${path}: empty`);
      else if (/html/i.test(ct) || /^\s*<(!doctype|html)/i.test(body)) bad.push(`${path}: answers HTML (${ct}), not text`);
      return body;
    };
    const llms = await getText("/llms.txt");
    const full = await getText("/llms-full.txt");
    if (!llms.startsWith("# tidyfault")) bad.push("/llms.txt: does not start with '# tidyfault'");
    if (!/^> /m.test(llms)) bad.push("/llms.txt: no '> ' summary line");
    for (const needle of ['remotes::install_github("timothyfraser/tidyfault")', 'pip install "git+https://github.com/timothyfraser/tidyfault#subdirectory=python"'])
      if (!llms.includes(needle)) bad.push(`/llms.txt: missing install line ${needle}`);
    if (!full.includes("# concentrate()") || full.length < llms.length * 5) bad.push("/llms-full.txt: does not concatenate the pages");
    // every Markdown link in llms.txt answers 200 with text (the site's own paths)
    const mdLinks = [...llms.matchAll(/\]\((https:\/\/tidyfault\.netlify\.app(\/[^)\s]+\.md))\)/g)].map((m) => m[2]);
    for (const path of new Set(mdLinks)) await getText(path);
    if (mdLinks.length < 20) bad.push(`/llms.txt: only ${mdLinks.length} Markdown links`);
    const idx = JSON.parse(readFileSync(new URL("../src/generated/articles/index.json", import.meta.url), "utf8"));
    const art0 = idx[0];
    const refMd = await getText("/reference/concentrate.md");
    const pyMd = await getText("/reference-py/concentrate.md");
    const artMd = await getText(`/articles/${art0.name}.md`);
    if (!refMd.startsWith("# concentrate()")) bad.push("/reference/concentrate.md: wrong heading");
    if (!pyMd.startsWith("# concentrate()")) bad.push("/reference-py/concentrate.md: wrong heading");
    if (!artMd.startsWith(`# ${art0.title}`)) bad.push(`/articles/${art0.name}.md: wrong heading`);
    if (bad.length) fail(`llms/markdown: ${bad.join(" | ")}`);
    else ok(`/llms.txt and /llms-full.txt answer 200 as text; ${new Set(mdLinks).size} Markdown links in llms.txt answer 200; reference, reference-py and article .md answer 200`);

    // the Copy as Markdown button copies exactly that page's Markdown
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await ctx.grantPermissions(["clipboard-read", "clipboard-write"], { origin: url });
    const page = await ctx.newPage();
    const errors = watch(page);
    const copyBad = [];
    for (const [path, md] of [
      ["/reference/concentrate.html", refMd],
      ["/reference-py/concentrate.html", pyMd],
      [`/articles/${art0.name}.html`, artMd],
    ]) {
      errors.length = 0;
      await page.goto(url + path, { waitUntil: "load" });
      const btn = page.locator("button", { hasText: "Copy as Markdown" });
      await page.waitForSelector("h1", { timeout: 10000 }).catch(() => null);
      await btn.first().waitFor({ timeout: 5000 }).catch(() => null);
      if (!(await btn.count())) { copyBad.push(`${path}: no Copy as Markdown button`); continue; }
      const h1 = (await page.textContent("h1")).trim();
      await btn.first().click();
      await page.locator("button", { hasText: /^Copied$/ }).waitFor({ timeout: 5000 }).catch(() => copyBad.push(`${path}: button never said Copied`));
      const clip = await page.evaluate(() => navigator.clipboard.readText());
      if (!clip.startsWith(`# ${h1}`)) copyBad.push(`${path}: clipboard starts ${JSON.stringify(clip.slice(0, 40))}, wanted "# ${h1}"`);
      else if (clip.trim() !== md.trim()) copyBad.push(`${path}: clipboard text differs from the .md file`);
      const real = realErrors(errors);
      if (real.length) copyBad.push(`${path}: console ${real.join(" | ")}`);
    }
    await page.waitForTimeout(2300);
    if (!(await page.locator("button", { hasText: "Copy as Markdown" }).count())) copyBad.push("label did not return to 'Copy as Markdown' after 2 s");
    if (copyBad.length) fail(`copy as markdown: ${copyBad.join(" | ")}`);
    else ok("Copy as Markdown on a reference page (R and Python) and an article page puts that page's Markdown on the clipboard");
    await ctx.close();
  }

  // ---- home page: the reference links route in-app (WEB-06) ----
  {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await ctx.newPage();
    await page.goto(url + "/", { waitUntil: "load" });
    const hrefs = await page.$$eval("#reference a", (as) => as.map((a) => a.getAttribute("href")));
    const want = ["/reference/", "/reference-py/", "/reference/curate.html", "/reference/illustrate.html"];
    const miss = want.filter((h) => !hrefs.includes(h));
    if (miss.length || hrefs.includes("#reference")) fail(`home reference section links: missing ${miss.join(", ")}; hrefs ${hrefs.join(" ")}`);
    else ok(`home reference section: ${hrefs.length} links point at /reference/ routes, none at #reference`);
    for (const h of hrefs) internalLinks.add(h);
    await ctx.close();
  }

  // ---- the published deck (ADR in the private repo; public copy in public/slides/) ----
  {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = await ctx.newPage();
    await page.goto(url + "/", { waitUntil: "load" });
    const navHref = await page.$eval("header .nav-slides", (a) => a.getAttribute("href")).catch(() => null);
    if (navHref !== "/slides/") fail(`nav Slides link missing or wrong (${navHref})`);
    else ok("nav: Slides link at the top right points to /slides/");
    await page.goto(url + "/slides/", { waitUntil: "load" });
    const n = await page.$$eval("section.slide", (s) => s.length).catch(() => 0);
    const frames = await page.$$eval("iframe.tf-live-frame", (f) => f.map((x) => x.getAttribute("src")));
    if (n !== 14) fail(`/slides/: expected 14 slides, found ${n}`);
    else if (!frames.length || frames.some((s) => s !== "/")) fail(`/slides/: live iframes not same-origin (${frames.join(", ")})`);
    else ok(`/slides/: 14 slides; ${frames.length} live iframes point at the site itself`);
    await page.screenshot({ path: join(shots, "slides-01.png") });
    console.log(`shot ${join(shots, "slides-01.png")}`);
    await ctx.close();
  }
} finally {
  await browser.close();
  if (preview) preview.kill();
}

if (failures.length) { console.error(`\n${failures.length} check(s) failed`); process.exit(1); }
console.log("\nverify-site: all checks passed");
process.exit(0);
