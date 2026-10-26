#!/usr/bin/env bash
set -Eeuo pipefail
RUNNER="${1:?Pass absolute M3 Python inventory runner path}"
R=$(mktemp -d)
trap 'rm -rf -- "$R"' EXIT
mkdir -p "$R/repo"/{widget/gtk,widget/windows,widget/cocoa,mobile/android,toolkit/mozapps/extensions,services/sync,toolkit/components/telemetry,third_party,src,doc}
cd "$R/repo"
git init -q
git config user.name Test
git config user.email test@example.invalid
printf 'rust\n' > src/kernel.rs
printf 'C++\n' > widget/gtk/core.cpp
printf 'win\n' > widget/windows/window.cpp
printf 'mac\n' > widget/cocoa/window.mm
printf 'apk\n' > mobile/android/main.js
printf 'ext\n' > toolkit/mozapps/extensions/AddonManager.sys.mjs
printf 'sync\n' > services/sync/Weave.sys.mjs
printf 'telemetry\n' > toolkit/components/telemetry/Telemetry.sys.mjs
printf 'license\n' > third_party/LICENSE
printf 'print("hi")\n' > src/script.py
printf 'readme\n' > doc/readme.txt
ln -s ../doc/readme.txt src/link
git add .
git commit -qm 'Synthetic pinned browser source'
before=$(git status --porcelain)
python3 "$RUNNER" "$R/repo" > "$R/result.log" 2>&1 || {
  cat "$R/result.log"
  exit 1
}
grep -Fq 'PASS: Read-only M3 inventory' "$R/result.log"
test "$(git status --porcelain)" = "$before"
test ! -e "$R/repo/m3-source-inventory.json"
python3 - "$R/repo/.git/vulpra-debloat/m3-source-inventory.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
d = json.loads(path.read_text())
assert d["schema_version"] == 1
assert d["source_only"]
assert d["source_files"] == 12, d["source_files"]
assert d["source_blob_bytes"] > 0
for name in ("windows_desktop", "macos_desktop", "android", "retain_linux_gtk",
             "retain_webextensions", "sync", "telemetry", "retain_third_party_licenses"):
    assert d["groups"][name]["files"] == 1, (name,d["groups"][name])
assert d["language"]["rust"]["files"] == 1
assert d["language"]["python"]["files"] == 1
assert d["language"]["c_cpp_asm"]["files"] >= 3
assert sum(x["files"] for x in d["top_level"].values()) == d["source_files"]
assert sum(x["bytes"] for x in d["top_level"].values()) == d["source_blob_bytes"]
assert len(d["limitations"]) >= 3
PY
test -s "$R/repo/.git/vulpra-debloat/m3-source-inventory.md"
echo 'PASS: synthetic pinned source footprint, all classification groups and zero tracked changes'
git rm -q src/kernel.rs
git commit -qm 'Different source revision'
python3 "$RUNNER" "$R/repo" >/dev/null
python3 - "$R/repo/.git/vulpra-debloat/m3-source-inventory.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert d["source_files"] == 11
assert d["language"].get("rust",{}).get("files",0) == 0
PY
echo 'PASS: inventory follows pinned Git HEAD rather than old output'
echo 'PASS: M3 read-only inventory synthetic regressions'
