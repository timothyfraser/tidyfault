// Playwright check of the built home page. Usage: node scripts/verify-site.mjs [--url http://host:port]
// Starts `vite preview` unless --url is given. Needs a chromium under /opt/pw-browsers (or CHROME_PATH).
import { chromium } from "playwright-core";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readdirSync } from "node:fs";
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
const fail = (m) => { failures.push(m); console.error("FAIL", m); };
const ok = (m) => console.log("ok  ", m);

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

    // links: hash targets exist; external are absolute https
    const links = await page.$$eval("a[href]", (as) => as.map((a) => a.getAttribute("href")));
    const bad = [];
    for (const href of new Set(links)) {
      if (href.startsWith("#")) {
        const id = href.slice(1);
        if (!id || !(await page.$(`[id="${id}"]`))) bad.push(href);
      } else if (!/^https:\/\//.test(href)) bad.push(href);
    }
    if (bad.length) fail(`${name}: unresolved links: ${bad.join(", ")}`); else ok(`${name}: ${new Set(links).size} distinct links resolve`);

    // toggle R/Python switches the code and output
    await page.click('button[aria-pressed="false"]:has-text("Python")');
    const py = await page.textContent(".chunk");
    if (!py.includes("['B*C', 'A*B*D']") || !py.includes("0.01285")) fail(`${name}: Python chunk output missing`);
    await page.click('button:has-text("R")');
    const r = await page.textContent(".chunk");
    if (!r.includes('[1] "B*C"') || !r.includes("[1] 0.01285")) fail(`${name}: R chunk output missing`);
    if (!(await page.$eval(".chunk .btn-run", (b) => b.disabled))) fail(`${name}: Run button should be disabled`);
    ok(`${name}: language toggle and disabled Run button`);

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
} finally {
  await browser.close();
  if (preview) preview.kill();
}

if (failures.length) { console.error(`\n${failures.length} check(s) failed`); process.exit(1); }
console.log("\nverify-site: all checks passed");
process.exit(0);
