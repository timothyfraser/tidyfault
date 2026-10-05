// webR runtime for the live R chunk (RT-02, SPEC TF5). Mirrors pyodide.js.
//
// Nothing here runs on page load. The first call to runR() checks that the
// tidyfault webR repository answers, then boots webR, installs the package's
// dependencies from repo.r-wasm.org and tidyfault from its own repository.
// Later calls reuse the same R session. Runs are serialised through a promise
// queue and a call that has to wait reports phase "waiting".
//
//   runR(code, onStatus?) -> Promise<{ stdout, stderr, figures }>
//     figures: PNG data URLs of every plot the code drew (webR canvas device)
//     onStatus({ phase, message }): phase is "waiting" | "loading" | "running"
//     An R error rejects with an Error whose .stdout, .stderr and .figures hold
//     whatever was captured. When R cannot be brought up at all (repository
//     unreachable, webR CDN blocked, tidyfault not installable) the Error has
//     .unavailable = true: the caller keeps the static output (the fallback).
//
// The installed library lives in an IndexedDB-backed folder (IDBFS), so a
// second visit restores the packages instead of downloading them again.

// Pinned, not /latest/: the tidyfault binary is built with the same webR
// release (webr-build.yaml), so a webR update cannot break the demo.
export const WEBR_BASE = "https://webr.r-wasm.org/v0.6.0/";
export const R_WASM_REPO = "https://repo.r-wasm.org/";
const DEFAULT_TIDYFAULT_REPO = "https://timothyfraser.github.io/tidyfault/repo";

// tidyfault's Imports (DESCRIPTION) that are not base R. webr::install pulls
// their own dependencies.
const DEPS = ["dplyr", "ggplot2", "ggraph", "purrr", "Rcpp", "rlang", "scales", "stringr", "tibble", "tidyr", "tidygraph"];

// The one place the tidyfault repository URL is decided. A test (or a preview
// build) can point it elsewhere with window.TIDYFAULT_WEBR_REPO or, at build
// time, VITE_TIDYFAULT_WEBR_REPO.
export function tidyfaultRepo() {
  const fromWindow = typeof window !== "undefined" && window.TIDYFAULT_WEBR_REPO;
  const fromEnv = import.meta.env && import.meta.env.VITE_TIDYFAULT_WEBR_REPO;
  return String(fromWindow || fromEnv || DEFAULT_TIDYFAULT_REPO).replace(/\/+$/, "");
}

let bootPromise = null;
let queueTail = Promise.resolve();
let inFlight = 0;
const bootListeners = new Set();
let lastBootMessage = "Loading R…";

function say(message) {
  lastBootMessage = message;
  bootListeners.forEach((fn) => fn(message));
}

function unavailable(message, cause) {
  const e = new Error(message);
  e.unavailable = true;
  if (cause) e.cause = cause;
  return e;
}

const rstr = (s) => JSON.stringify(String(s)); // a JSON string is a valid R string literal here
const rvec = (xs) => `c(${xs.map(rstr).join(", ")})`;

// The repository answers before anything heavy is downloaded. Returns the
// version it serves (or null when PACKAGES does not list tidyfault yet).
async function probeRepo(repo) {
  let res;
  try {
    res = await fetch(`${repo}/src/contrib/PACKAGES`, { cache: "no-cache" });
  } catch (err) {
    throw unavailable("The tidyfault webR repository could not be reached.", err);
  }
  if (!res.ok) throw unavailable(`The tidyfault webR repository is not published yet (HTTP ${res.status}).`);
  const text = await res.text();
  const m = text.match(/^Package:\s*tidyfault\s*\r?\nVersion:\s*(\S+)/m);
  return m ? m[1] : null;
}

async function boot() {
  const repo = tidyfaultRepo();
  say("Checking the tidyfault webR repository…");
  const repoVersion = await probeRepo(repo);

  say("Loading webR…");
  let webR;
  try {
    const { WebR, ChannelType } = await import(/* @vite-ignore */ `${WEBR_BASE}webr.mjs`);
    // PostMessage needs no cross-origin isolation headers, so plain static
    // hosting works. The cost: a running chunk cannot be interrupted.
    webR = new WebR({ baseUrl: WEBR_BASE, channelType: ChannelType.PostMessage });
    await webR.init();
  } catch (err) {
    throw unavailable("webR could not be loaded.", err);
  }
  // A test can read what the boot did (window.TIDYFAULT_WEBR_DEBUG = true).
  const report = { webR: true, persist: false, restored: [], installed: [], tidyfault: null };
  if (typeof window !== "undefined" && window.TIDYFAULT_WEBR_DEBUG) window.__tidyfaultWebRReport = report;

  try {
    // Persistent library: an IDBFS folder first on .libPaths(). If the mount or
    // the restore fails (private browsing), packages install for this visit only.
    const rver = await webR.evalRString('paste(R.version$major, sub("\\\\..*", "", R.version$minor), sep = ".")');
    const lib = `/home/web_user/tidyfault-lib-R${rver}`;
    let persist = false;
    try {
      try {
        await webR.FS.mkdir(lib);
      } catch (_) {
        /* already there */
      }
      await webR.FS.mount("IDBFS", {}, lib);
      await webR.FS.syncfs(true);
      await webR.evalRVoid(`.libPaths(c(${rstr(lib)}, .libPaths()))`);
      persist = true;
      report.persist = true;
    } catch (_) {
      persist = false;
    }
    const target = persist ? `, lib = ${rstr(lib)}, mount = FALSE` : "";
    const sync = async () => {
      if (!persist) return;
      try {
        await webR.FS.syncfs(false);
      } catch (_) {
        /* the next visit downloads again; nothing else breaks */
      }
    };
    const installed = async () => {
      const s = await webR.evalRString('paste(rownames(installed.packages()), collapse = ",")');
      return new Set(s.split(",").filter(Boolean));
    };

    let have = await installed();
    const missing = DEPS.filter((p) => !have.has(p));
    report.restored = DEPS.filter((p) => have.has(p));
    if (persist && missing.length < DEPS.length) say(`Restored ${DEPS.length - missing.length} packages from this browser's cache`);
    for (let i = 0; i < missing.length; i++) {
      if (have.has(missing[i])) continue; // arrived as a dependency of an earlier one
      say(`Installing ${missing[i]} (${i + 1} of ${missing.length})…`);
      await webR.evalRVoid(`webr::install(${rstr(missing[i])}, repos = ${rstr(R_WASM_REPO)}, quiet = TRUE${target})`);
      have = await installed();
    }
    report.installed = [...have].sort();
    const stillMissing = DEPS.filter((p) => !have.has(p));
    if (stillMissing.length) throw unavailable(`Could not install ${stillMissing.join(", ")} from repo.r-wasm.org.`);
    await sync();

    // tidyfault itself: reinstall when the repository serves a different version.
    let cached = null;
    if (have.has("tidyfault")) cached = await webR.evalRString('as.character(utils::packageVersion("tidyfault"))');
    if (!cached || (repoVersion && cached !== repoVersion)) {
      say("Installing tidyfault…");
      await webR.evalRVoid(`webr::install("tidyfault", repos = ${rvec([repo, R_WASM_REPO])}, quiet = TRUE${target})`);
    }
    const ok = await webR.evalRBoolean('requireNamespace("tidyfault", quietly = TRUE)');
    if (!ok) throw unavailable("tidyfault is not in the webR repository yet.");
    report.tidyfault = await webR.evalRString('as.character(utils::packageVersion("tidyfault"))');
    await sync();
  } catch (err) {
    try {
      webR.close();
    } catch (_) {
      /* already gone */
    }
    throw err.unavailable ? err : unavailable("R packages could not be installed.", err);
  }

  say("R ready");
  return webR;
}

function getWebR() {
  if (!bootPromise) {
    bootPromise = boot().catch((err) => {
      bootPromise = null; // let the next click retry
      throw err;
    });
  }
  return bootPromise;
}

// R's canvas device draws on a transparent background; flatten onto white.
function bitmapToPng(bmp) {
  const c = document.createElement("canvas");
  c.width = bmp.width;
  c.height = bmp.height;
  const ctx = c.getContext("2d");
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, c.width, c.height);
  ctx.drawImage(bmp, 0, 0);
  if (typeof bmp.close === "function") bmp.close();
  return c.toDataURL("image/png");
}

async function execute(code, onStatus) {
  const emit = (phase, message) => onStatus && onStatus({ phase, message });
  let webR;
  if (!bootPromise) {
    emit("loading", lastBootMessage);
    const listener = (m) => emit("loading", m);
    bootListeners.add(listener);
    try {
      webR = await getWebR();
    } finally {
      bootListeners.delete(listener);
    }
  } else {
    webR = await getWebR();
  }

  emit("running", "Running…");
  const shelter = await new webR.Shelter();
  try {
    // captureConditions: false keeps messages, warnings and an error on the
    // stderr stream in the order R printed them. An R error does not reject
    // here: evaluation stops and "Error..." is the last stderr line.
    let cap;
    try {
      cap = await shelter.captureR(code, {
        withAutoprint: true,
        captureStreams: true,
        captureConditions: false,
        captureGraphics: { width: 540, height: 480 },
      });
    } catch (e) {
      const wrapped = new Error(String(e && e.message ? e.message : e));
      Object.assign(wrapped, { stdout: "", stderr: "", figures: [] });
      throw wrapped;
    }
    const out = [];
    const err = [];
    let rError = null;
    for (const o of cap.output) {
      if (o.type === "stdout") out.push(o.data);
      else if (o.type === "stderr") {
        if (/^Error\b/.test(o.data)) rError = o.data.replace(/^Error( in [^:]*)?:\s*/, "");
        else err.push(o.data);
      }
    }
    const result = { stdout: out.join("\n"), stderr: err.join("\n"), figures: (cap.images || []).map(bitmapToPng) };
    if (rError !== null) throw Object.assign(new Error(rError), result);
    return result;
  } finally {
    shelter.purge();
  }
}

export function runR(code, onStatus) {
  if (inFlight > 0 && onStatus) onStatus({ phase: "waiting", message: "Waiting for the earlier run…" });
  inFlight += 1;
  const result = queueTail.then(() => execute(code, onStatus));
  const settled = () => {
    inFlight -= 1;
  };
  queueTail = result.then(settled, settled);
  return result;
}
