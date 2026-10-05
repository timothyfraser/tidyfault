#!/usr/bin/env bash
# Build python/ into a pure-Python wheel for the in-browser Pyodide runtime.
# Writes website/public/py/<wheel> and website/public/py/wheel.json
# ({"wheel": "<filename>"}); pyodide.js fetches wheel.json to find the file.
# Idempotent: older tidyfault-*.whl files in public/py are replaced.
# Run from anywhere:  bash website/scripts/build-wheel.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$REPO/website/public/py"
PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$REPO"
if "$PY" -c "import build" >/dev/null 2>&1; then
  "$PY" -m build --wheel --outdir "$TMP" python/ >&2
else
  # no `build` module: pip builds in an isolated env (needs hatchling from PyPI)
  "$PY" -m pip wheel --no-deps -w "$TMP" python/ >&2
fi

shopt -s nullglob
built=("$TMP"/tidyfault-*.whl)
if [ "${#built[@]}" -ne 1 ]; then
  echo "build-wheel.sh: expected exactly one tidyfault wheel, found ${#built[@]}" >&2
  exit 1
fi
name="$(basename "${built[0]}")"

mkdir -p "$OUT"
rm -f "$OUT"/tidyfault-*.whl
cp "${built[0]}" "$OUT/$name"
printf '{"wheel": "%s"}\n' "$name" > "$OUT/wheel.json"

echo "$OUT/$name"
