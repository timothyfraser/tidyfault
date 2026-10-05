// Fail the build when the committed reference JSON has drifted from the packages.
//   node scripts/check-generated.mjs
// Node only (no R, no Python), so it runs in any build container. For each language:
//   1. the JSON's source_hash must equal a fresh hash of its sources (the "is it older than
//      its sources" test, by content rather than mtime, which a git checkout resets);
//   2. every export must have a page, and every page must be an export (or, in R, a
//      documented dataset in data/).
// Regenerate with `npm run generate` (needs Rscript and python3) and commit the JSON.
// The hash recipe must match extract-r.R and extract-py.py:
//   md5( concat over sorted files of `${relpath}  ${md5(bytes without \r)}\n` )
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const site = join(dirname(fileURLToPath(import.meta.url)), "..");
const root = join(site, "..");
const md5 = (buf) => createHash("md5").update(buf).digest("hex");
const byteSort = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

function sourceHash(files) {
  const manifest = files
    .map((f) => {
      const bytes = readFileSync(join(root, f)).filter((b) => b !== 13);
      return `${f}  ${md5(bytes)}\n`;
    })
    .join("");
  return md5(Buffer.from(manifest, "utf8"));
}

const failures = [];
const fail = (m) => failures.push(m);
const ok = (m) => console.log("ok  ", m);

function loadJson(name) {
  const p = join(site, "src", "generated", name);
  if (!existsSync(p)) {
    fail(`${name} is missing; run npm run generate`);
    return null;
  }
  return JSON.parse(readFileSync(p, "utf8"));
}

function setDiff(a, b) {
  return [...a].filter((x) => !b.has(x)).sort(byteSort);
}

// ---- R --------------------------------------------------------------------------------
{
  const json = loadJson("reference-r.json");
  if (json) {
    const rd = readdirSync(join(root, "man")).filter((f) => f.endsWith(".Rd")).sort(byteSort);
    const files = ["DESCRIPTION", "NAMESPACE", "_pkgdown.yml", ...rd.map((f) => `man/${f}`)];
    const hash = sourceHash(files);
    if (json.source_hash !== hash) {
      fail(`reference-r.json is stale: source hash ${json.source_hash} != ${hash} (NAMESPACE, DESCRIPTION, _pkgdown.yml or man/*.Rd changed); run npm run generate`);
    } else ok("reference-r.json matches NAMESPACE + DESCRIPTION + _pkgdown.yml + man/*.Rd");

    const ns = readFileSync(join(root, "NAMESPACE"), "utf8").split(/\r?\n/);
    const exports = new Set(ns.map((l) => l.match(/^export\("?([^")]+)"?\)$/)?.[1]).filter(Boolean));
    const s3 = ns.map((l) => l.match(/^S3method\(([^,]+),\s*([^)]+)\)$/)).filter(Boolean);
    const generics = new Set(s3.map((m) => m[1]));
    const methods = new Set(s3.map((m) => `${m[1]}.${m[2]}`));
    const datasets = new Set(
      (existsSync(join(root, "data")) ? readdirSync(join(root, "data")) : [])
        .filter((f) => /\.(rda|RData|rds)$/.test(f))
        .map((f) => f.replace(/\.(rda|RData|rds)$/, "")),
    );
    const allowed = new Set([...exports, ...generics, ...methods, ...datasets]);
    const aliases = new Set(json.topics.flatMap((t) => t.aliases));
    const names = new Set(json.topics.map((t) => t.name));

    const missing = setDiff(new Set([...exports, ...generics]), aliases);
    if (missing.length) fail(`reference-r.json has no page for export(s): ${missing.join(", ")}`);
    const extraNames = setDiff(names, allowed);
    if (extraNames.length) fail(`reference-r.json lists topic(s) the package does not export: ${extraNames.join(", ")}`);
    const extraAliases = setDiff(aliases, allowed);
    if (extraAliases.length) fail(`reference-r.json lists alias(es) the package does not export: ${extraAliases.join(", ")}`);
    const notData = json.topics.filter((t) => t.kind === "data" && !datasets.has(t.name)).map((t) => t.name);
    if (notData.length) fail(`reference-r.json documents dataset(s) missing from data/: ${notData.join(", ")}`);
    const version = readFileSync(join(root, "DESCRIPTION"), "utf8").match(/^Version:\s*(\S+)/m)?.[1];
    if (json.version !== version) fail(`reference-r.json version ${json.version} != DESCRIPTION ${version}`);
    if (!missing.length && !extraNames.length && !extraAliases.length && !notData.length) {
      ok(`reference-r.json: ${exports.size} exports + ${generics.size} S3 generic(s) covered by ${names.size} topics (${json.topics.filter((t) => t.kind === "data").length} datasets)`);
    }
  }
}

// ---- Python ---------------------------------------------------------------------------
{
  const json = loadJson("reference-py.json");
  if (json) {
    const pkg = join(root, "python", "src", "tidyfault");
    const files = readdirSync(pkg).filter((f) => f.endsWith(".py")).sort(byteSort).map((f) => `python/src/tidyfault/${f}`);
    const hash = sourceHash(files);
    if (json.source_hash !== hash) {
      fail(`reference-py.json is stale: source hash ${json.source_hash} != ${hash} (python/src/tidyfault/*.py changed); run npm run generate`);
    } else ok("reference-py.json matches python/src/tidyfault/*.py");

    // __all__ read statically from __init__.py: `__all__ = [...]` resets, `__all__ += [...]` appends
    const init = readFileSync(join(pkg, "__init__.py"), "utf8").replace(/#[^\n]*/g, "");
    let all = [];
    for (const m of init.matchAll(/__all__\s*(\+?=)\s*\[([\s\S]*?)\]/g)) {
      const names = [...m[2].matchAll(/["']([^"']+)["']/g)].map((x) => x[1]);
      all = m[1] === "=" ? names : all.concat(names);
    }
    if (!all.length) fail("could not read __all__ from python/src/tidyfault/__init__.py");
    const exported = new Set(all);
    const names = new Set(json.topics.map((t) => t.name));
    const missing = setDiff(exported, names);
    const extra = setDiff(names, exported);
    if (missing.length) fail(`reference-py.json has no page for __all__ name(s): ${missing.join(", ")}`);
    if (extra.length) fail(`reference-py.json lists name(s) not in tidyfault.__all__: ${extra.join(", ")}`);
    if (!missing.length && !extra.length) ok(`reference-py.json: all ${exported.size} names in __all__ have a page`);
  }
}

if (failures.length) {
  for (const f of failures) console.error("FAIL", f);
  console.error(`\ncheck-generated: ${failures.length} problem(s). Fix the roxygen/docstring, run npm run generate, commit the JSON.`);
  process.exit(1);
}
console.log("check-generated: reference JSON is current");
