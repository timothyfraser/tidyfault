"""Generate website/src/generated/reference-py.json from the Python package.

    python3 website/scripts/extract-py.py      (from anywhere; paths resolve from this file)

Imports tidyfault from python/src (no install needed), walks tidyfault.__all__, and
reads each name's inspect.signature and docstring. NumPy-style sections (Parameters,
Returns, Examples, See Also, Notes) are split out; otherwise the whole docstring is the
description. Groups follow _pkgdown.yml's reference sections where the name (or an Rd
alias of it) matches an R topic. The JSON is committed; scripts/check-generated.mjs
fails the build when its source hash no longer matches python/src/tidyfault/*.py.
Never edit the JSON by hand: fix the docstring and rerun this.
"""

from __future__ import annotations

import hashlib
import html
import inspect
import json
import re
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent
ROOT = SITE.parent
SRC = ROOT / "python" / "src"
PKG = SRC / "tidyfault"
sys.dont_write_bytecode = True  # importing from python/src must not leave __pycache__ behind
sys.path.insert(0, str(SRC))

import tidyfault  # noqa: E402


# ---- source hash (must match check-generated.mjs) -------------------------------------
def md5(b: bytes) -> str:
    return hashlib.md5(b).hexdigest()


def py_sources() -> list[str]:
    return sorted(f"python/src/tidyfault/{p.name}" for p in PKG.glob("*.py"))


def source_hash(files: list[str]) -> str:
    cr = b"\r"
    manifest = "".join(f"{f}  {md5((ROOT / f).read_bytes().replace(cr, b''))}\n" for f in files)
    return md5(manifest.encode("utf-8"))


# ---- groups from _pkgdown.yml + Rd aliases ---------------------------------------------
def pkgdown_groups() -> dict[str, str]:
    out: dict[str, str] = {}
    lines = (ROOT / "_pkgdown.yml").read_text(encoding="utf-8").splitlines()
    if "reference:" not in lines:
        return out
    title = None
    for line in lines[lines.index("reference:") + 1 :]:
        if re.match(r"^\S", line):
            break
        m = re.match(r"^\s*-\s*title:\s*(.+)$", line)
        if m:
            title = m.group(1).strip().strip("\"'")
            continue
        m = re.match(r"^\s+-\s+([A-Za-z0-9._-]+)\s*$", line)
        if m and title:
            out[m.group(1)] = title
    return out


def alias_groups(groups: dict[str, str]) -> dict[str, tuple[str, str]]:
    """alias -> (R topic, group) for every alias in man/*.Rd."""
    out: dict[str, tuple[str, str]] = {}
    for rd in sorted((ROOT / "man").glob("*.Rd")):
        topic = rd.stem
        if topic not in groups:
            continue
        for a in re.findall(r"\\alias\{([^}]*)\}", rd.read_text(encoding="utf-8")):
            out.setdefault(a, (topic, groups[topic]))
    return out


# ---- docstring -> HTML ------------------------------------------------------------------
NAMES = set(tidyfault.__all__)
SECTION_RE = re.compile(r"^(Parameters|Returns|Yields|Raises|Examples|See Also|Notes|References|Attributes)\n-{3,}\n", re.M)


def inline(text: str) -> str:
    """Escape, then ``code`` -> <code>, :func:`x` -> <code>x()</code>, link known names."""
    out = html.escape(text, quote=True)
    out = re.sub(r":(?:func|meth|class|mod|attr):`~?(?:tidyfault\.)?(?:[\w]+\.)*?([\w]+)`",
                 lambda m: f"<code>{m.group(1)}()</code>", out)
    out = re.sub(r"``(.+?)``", lambda m: f"<code>{m.group(1)}</code>", out, flags=re.S)

    def link(m: re.Match) -> str:
        fn = m.group(1)
        if fn in NAMES:
            return f'<code><a href="/reference-py/{fn}.html">{fn}()</a></code>'
        return m.group(0)

    out = re.sub(r"<code>([A-Za-z_]\w*)\(\)</code>", link, out)
    # bare name() in prose (e.g. "the output of curate()")
    out = re.sub(r"(?<![\w>./:])([A-Za-z_]\w*)\(\)(?![\w<])",
                 lambda m: f'<code><a href="/reference-py/{m.group(1)}.html">{m.group(1)}()</a></code>'
                 if m.group(1) in NAMES else m.group(0), out)
    return re.sub(r"\s+", " ", out).strip()


def paragraphs(text: str) -> str:
    paras = [p for p in re.split(r"\n\s*\n", text.strip()) if p.strip()]
    return "".join(f"<p>{inline(p)}</p>" for p in paras)


def unwrap_p(h: str) -> str:
    return h[3:-4] if h.startswith("<p>") and h.endswith("</p>") and h.count("<p>") == 1 else h


def split_sections(doc: str) -> tuple[str, dict[str, str]]:
    parts = SECTION_RE.split(doc)
    head, sections = parts[0], {}
    for i in range(1, len(parts) - 1, 2):
        sections[parts[i]] = parts[i + 1]
    return head, sections


def parse_params(body: str) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    cur = None
    for line in body.splitlines():
        if line and not line[0].isspace():
            name, _, typ = line.partition(" : ")
            cur = {"name": name.strip(), "type": typ.strip(), "lines": []}
            out.append(cur)
        elif cur is not None:
            cur["lines"].append(line.strip())
    args = []
    for a in out:
        desc = unwrap_p(paragraphs("\n".join(a["lines"])))
        if a["type"]:
            desc = f"<code>{html.escape(a['type'])}</code>. {desc}".strip()
        args.append({"name": a["name"], "description": desc})
    return args


def signature_args(sig: inspect.Signature) -> list[dict[str, str]]:
    args = []
    for p in sig.parameters.values():
        name = {p.VAR_POSITIONAL: "*", p.VAR_KEYWORD: "**"}.get(p.kind, "") + p.name
        if p.default is inspect.Parameter.empty:
            desc = "Required." if p.kind not in (p.VAR_POSITIONAL, p.VAR_KEYWORD) else ""
        else:
            desc = f"Default <code>{html.escape(repr(p.default))}</code>."
        args.append({"name": name, "description": desc})
    return args


def first_sentence(h: str) -> str:
    text = html.unescape(re.sub(r"<[^>]+>", "", re.sub(r"</(p|li|dd)>", " ", h))).strip()
    m = re.match(r"^(.*?(?<!e\.g)(?<!i\.e)(?<!\bvs)[.!?])(\s|$)", text, re.S)
    return (m.group(1) if m else text).strip()


def constant_source(name: str) -> tuple[str, str]:
    for f in sorted(PKG.glob("*.py")):
        for line in f.read_text(encoding="utf-8").splitlines():
            m = re.match(rf"^{re.escape(name)}\s*=.*?(?:#\s*(.*))?$", line)
            if m:
                return f"python/src/tidyfault/{f.name}", (m.group(1) or "").strip()
    return "", ""


def topic(name: str, aliases: dict[str, tuple[str, str]]) -> dict:
    obj = getattr(tidyfault, name)
    r_topic, group = aliases.get(name, ("", "Python helpers"))
    is_callable = inspect.isfunction(obj) or inspect.isclass(obj) or inspect.isbuiltin(obj)
    if not is_callable:
        src, comment = constant_source(name)
        desc = f"<p>{inline(comment[0].upper() + comment[1:])}.</p>" if comment else ""
        return {
            "name": name, "aliases": [name], "kind": "constant", "title": name,
            "summary": first_sentence(desc) or f"Constant {name}.",
            "description": desc, "usage": f"tidyfault.{name}  # {obj!r}", "arguments": [],
            "format": "", "value": f"<p><code>{html.escape(repr(obj))}</code></p>", "details": "",
            "sections": [], "examples": "", "seealso": "", "source_file": src,
            "r_topic": r_topic, "group": group,
        }
    doc = inspect.getdoc(obj) or ""
    head, sections = split_sections(doc)
    try:
        sig = inspect.signature(obj)
    except (TypeError, ValueError):
        sig = None
    description = paragraphs(head)
    arguments = parse_params(sections.pop("Parameters")) if "Parameters" in sections else (
        signature_args(sig) if sig else [])
    value = paragraphs(sections.pop("Returns", ""))
    examples = inspect.cleandoc(sections.pop("Examples", ""))
    seealso = paragraphs(sections.pop("See Also", ""))
    extra = [{"title": k, "html": paragraphs(v)} for k, v in sections.items()]
    try:
        src = Path(inspect.getsourcefile(obj)).resolve().relative_to(ROOT).as_posix()
    except (TypeError, ValueError):
        src = ""
    return {
        "name": name,
        "aliases": [name],
        "kind": "class" if inspect.isclass(obj) else "function",
        "title": name,
        "summary": first_sentence(description),
        "description": description,
        "usage": f"{name}{sig}" if sig else name,
        "arguments": arguments,
        "format": "",
        "value": value,
        "details": "",
        "sections": extra,
        "examples": examples,
        "seealso": seealso,
        "source_file": src,
        "r_topic": r_topic,
        "group": group,
    }


def main() -> None:
    groups = pkgdown_groups()
    aliases = alias_groups(groups)
    order = [g for g in dict.fromkeys(groups.values()) if g != "Data"] + ["Python helpers", "Data"]
    names = list(dict.fromkeys(tidyfault.__all__))
    topics = [topic(n, aliases) for n in names]
    pk = list(groups)

    def rank(t: dict) -> tuple:
        rt = t["r_topic"]
        return (order.index(t["group"]), pk.index(rt) if rt in pk else 9999, t["name"])

    topics.sort(key=rank)
    out = {
        "language": "Python",
        "package": "tidyfault",
        "version": tidyfault.__version__,
        "generated_by": "website/scripts/extract-py.py",
        "source_files": ["python/src/tidyfault/*.py"],
        "source_hash": source_hash(py_sources()),
        "exports": sorted(names),
        "topics": topics,
    }
    dest = SITE / "src" / "generated" / "reference-py.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"extract-py: {len(topics)} names -> {dest}")


if __name__ == "__main__":
    main()
