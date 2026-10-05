// Live-runtime check of the home-page RunChunk's R tab (RT-02), in real Chromium.
// Usage: node scripts/verify-live.mjs [--url http://host:port] [--r-repo <url>] [--skip-deps]
//
//   default  R tab, the built-in repository URL. If the tidyfault webR repository
//            answers, the full output is asserted; if it does not, the SPEC TF5
//            fallback is asserted (static output kept, "coming soon" chip, no error,
//            webR never downloaded).
//   deps     (skip with --skip-deps) points the repository at repo.r-wasm.org, which
//            answers but has no tidyfault: webR must boot, install every dependency,
//            then fall back cleanly. A reload must restore the packages from IDBFS.
//   --r-repo the full run against a tidyfault webR repository at <url>:
//            [1] "B*C"   "A*B*D", [1] 0.01285 and a plot from the canvas device.
//
// Starts `vite preview` unless --url is given. Needs a chromium under /opt/pw-browsers
// (or CHROME_PATH). Uses HTTPS_PROXY for the CDN fetches when it is set.
import { chromium } from "playwright-core";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const shots = "/tmp/rt02-live-shots";
const arg = (name) => (process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : null);
const argUrl = arg("--url");
const rRepo = arg("--r-repo");
const skipDeps = process.argv.includes("--skip-deps");
const DEPS = ["dplyr", "ggplot2", "ggraph", "purrr", "Rcpp", "rlang", "scales", "stringr", "tibble", "tidyr", "tidygraph"];
const BOOT_TIMEOUT = 8 * 60 * 1000;

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
const secs = (t0) => `${((Date.now() - t0) / 1000).toFixed(1)} s`;

// Open the home page with optional window globals set before the app runs.
async function openHome(ctx, url, globals = {}) {
  const page = await ctx.newPage();
  await page.addInitScript((g) => Object.assign(window, g), globals);
  const pageErrors = [];
  const webrRequests = [];
  page.on("pageerror", (e) => pageErrors.push(String(e)));
  page.on("request", (r) => { if (r.url().startsWith("https://webr.r-wasm.org/")) webrRequests.push(r.url()); });
  await page.goto(url, { waitUntil: "load" });
  await page.waitForSelector(".chunk .btn-run");
  if (await page.$('.chunk button[aria-pressed="true"]:has-text("Python")')) await page.click('.chunk button:has-text("R")');
  return { page, pageErrors, webrRequests };
}

// Click Run on the R tab and wait for a terminal phase; collect every progress line seen.
async function runR(page) {
  const t0 = Date.now();
  await page.click(".chunk .btn-run");
  const progress = [];
  const poll = setInterval(async () => {
    const t = await page.$eval('[data-testid="r-progress"]', (el) => el.textContent).catch(() => null);
    if (t && progress[progress.length - 1] !== t) progress.push(t);
  }, 250);
  try {
    await page.waitForFunction(() => ["done", "error", "unavailable"].includes(document.querySelector(".chunk .chip")?.dataset.phase), null, { timeout: BOOT_TIMEOUT, polling: 250 });
  } finally {
    clearInterval(poll);
  }
  const state = await page.evaluate(() => ({
    phase: document.querySelector(".chunk .chip").dataset.phase,
    chip: document.querySelector(".chunk .chip").textContent.trim(),
    live: document.querySelector(".chunk-out").dataset.live,
    out: document.querySelector(".chunk-out .out-text").textContent,
    detail: document.querySelector('[data-testid="r-progress"]')?.textContent ?? "",
    alert: document.querySelector('.chunk [role="alert"]')?.textContent ?? null,
    svg: !!document.querySelector(".chunk-out figure svg"),
    img: (() => { const i = document.querySelector(".chunk-out figure img"); return i ? { w: i.naturalWidth, h: i.naturalHeight } : null; })(),
    report: window.__tidyfaultWebRReport ?? null,
  }));
  return { ...state, progress, elapsed: secs(t0) };
}

function assertFallback(label, s, extra = "") {
  const staticOk = s.out.includes('[1] "B*C"') && s.out.includes("[1] 0.01285");
  if (s.phase !== "unavailable") return fail(`${label}: expected the fallback, got phase ${s.phase} (${s.alert || s.detail})`);
  if (!/coming soon/i.test(s.chip)) fail(`${label}: chip "${s.chip}" is not the coming-soon chip`);
  if (s.live !== "false" || !staticOk || !s.svg || s.img) fail(`${label}: static output/figure not kept (live=${s.live}, svg=${s.svg})`);
  if (s.alert) fail(`${label}: an error is shown in fallback: ${s.alert}`);
  if (s.live === "false" && staticOk && s.svg && !s.alert && /coming soon/i.test(s.chip)) ok(`${label}: fallback after ${s.elapsed}: chip "${s.chip}", static output and figure kept, no error; note "${s.detail}"${extra}`);
}

function assertFull(label, s) {
  const lines = s.out.split("#>").map((l) => l.trim()).filter(Boolean);
  if (s.phase !== "done") return fail(`${label}: phase ${s.phase}: ${s.alert || s.detail}`);
  if (!lines.includes('[1] "B*C"   "A*B*D"')) fail(`${label}: concentrate() line missing: ${JSON.stringify(lines)}`);
  if (!lines.includes("[1] 0.01285")) fail(`${label}: quantify() line missing: ${JSON.stringify(lines)}`);
  if (!s.img || s.img.w < 100) fail(`${label}: no plot from the canvas device (${JSON.stringify(s.img)})`);
  if (s.live !== "true" || s.alert) fail(`${label}: live=${s.live} alert=${s.alert}`);
  if (lines.includes('[1] "B*C"   "A*B*D"') && lines.includes("[1] 0.01285") && s.img && s.img.w >= 100)
    ok(`${label}: live run in ${s.elapsed}: ${JSON.stringify(lines)}; plot ${s.img.w}x${s.img.h}; tidyfault ${s.report?.tidyfault ?? "?"}`);
}

mkdirSync(shots, { recursive: true });
let preview = null;
let url = argUrl;
if (!url) ({ proc: preview, url } = await startPreview());
const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
const browser = await chromium.launch({
  executablePath: findChrome(),
  args: ["--no-sandbox"],
  ...(proxy ? { proxy: { server: proxy, bypass: "localhost,127.0.0.1" } } : {}),
});

try {
  // ---- default repository URL ---------------------------------------------------------
  {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const { page, pageErrors, webrRequests } = await openHome(ctx, url, { TIDYFAULT_WEBR_DEBUG: true });
    const btnDisabled = await page.$eval(".chunk .btn-run", (b) => b.disabled);
    if (btnDisabled) fail("default: R Run button is disabled");
    if (webrRequests.length) fail(`default: webR was fetched on page load (${webrRequests[0]})`);
    else ok("default: R Run button enabled; nothing fetched from webr.r-wasm.org before the click");
    const s = await runR(page);
    if (s.phase === "unavailable") {
      assertFallback("default (repository unreachable)", s);
      if (webrRequests.length) fail(`default: webR was downloaded although the repository did not answer (${webrRequests.length} requests)`);
      else ok("default: the repository probe failed first, so webR was never downloaded");
    } else assertFull("default (repository live)", s);
    if (pageErrors.length) fail(`default: uncaught page errors: ${pageErrors.join(" | ")}`);
    await page.screenshot({ path: join(shots, "r-default.png"), fullPage: false });
    console.log(`shot ${join(shots, "r-default.png")}`);
    await ctx.close();
  }

  // ---- deps: a repository that answers but has no tidyfault ----------------------------
  if (!skipDeps) {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const globals = { TIDYFAULT_WEBR_REPO: "https://repo.r-wasm.org", TIDYFAULT_WEBR_DEBUG: true };
    const first = await openHome(ctx, url, globals);
    const s = await runR(first.page);
    const r = s.report;
    console.log(`     progress: ${s.progress.join(" | ")}`);
    if (!r || !r.webR) fail(`deps: webR did not boot (${s.detail})`);
    else {
      const missing = DEPS.filter((p) => !r.installed.includes(p));
      if (missing.length) fail(`deps: not installed: ${missing.join(", ")}`);
      else ok(`deps: webR booted (PostMessage channel) and installed all ${DEPS.length} dependencies from repo.r-wasm.org (${r.installed.length} packages in the library; IDBFS persist=${r.persist})`);
    }
    assertFallback("deps (no tidyfault in the repository)", s);
    if (first.pageErrors.length) fail(`deps: uncaught page errors: ${first.pageErrors.join(" | ")}`);
    await first.page.screenshot({ path: join(shots, "r-deps-fallback.png") });
    console.log(`shot ${join(shots, "r-deps-fallback.png")}`);
    await first.page.close();

    // Same browser profile, new page: the library comes back from IndexedDB.
    const second = await openHome(ctx, url, globals);
    const s2 = await runR(second.page);
    const restored = s2.report?.restored ?? [];
    if (restored.length !== DEPS.length) fail(`deps (reload): only ${restored.length} of ${DEPS.length} restored from IDBFS: ${restored.join(", ")}`);
    else ok(`deps (reload): all ${DEPS.length} dependencies restored from IDBFS, no reinstall (${s2.elapsed} vs ${s.elapsed} first time)`);
    assertFallback("deps (reload)", s2);
    await ctx.close();
  }

  // ---- full run against a real tidyfault webR repository ---------------------------------
  if (rRepo) {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const { page, pageErrors } = await openHome(ctx, url, { TIDYFAULT_WEBR_REPO: rRepo, TIDYFAULT_WEBR_DEBUG: true });
    const s = await runR(page);
    console.log(`     progress: ${s.progress.join(" | ")}`);
    assertFull(`--r-repo ${rRepo}`, s);
    if (pageErrors.length) fail(`--r-repo: uncaught page errors: ${pageErrors.join(" | ")}`);
    await page.screenshot({ path: join(shots, "r-live.png") });
    console.log(`shot ${join(shots, "r-live.png")}`);
    await ctx.close();
  } else {
    console.log("skip --r-repo not given: the full R output assertion needs a tidyfault webR repository");
  }
} finally {
  await browser.close();
  if (preview) preview.kill();
}

if (failures.length) { console.error(`\n${failures.length} check(s) failed`); process.exit(1); }
console.log("\nverify-live: all checks passed");
process.exit(0);
