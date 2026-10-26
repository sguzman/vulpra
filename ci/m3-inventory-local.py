#!/usr/bin/env python3
"""Read-only M3 Git source footprint; no changes to browser or source tree."""
from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import subprocess
import sys

# Verified path prefixes in the pinned Firefox 159.0b5 tree.
# A matched prefix is NOT proof that any part can be removed safely.
GROUPS = {
    "retain_linux_gtk": ("retain", ("widget/gtk/",)),
    "retain_webextensions": ("retain", ("toolkit/mozapps/extensions/",)),
    "retain_third_party_licenses": ("retain-audit", ("third_party/",)),
    "windows_desktop": ("platform-review", ("widget/windows/", "browser/installer/windows/")),
    "macos_desktop": ("platform-review", ("widget/cocoa/",)),
    "android": ("platform-review", ("mobile/android/", "widget/android/")),
    "sync": ("feature-review", ("services/sync/",)),
    "fxaccounts": ("feature-review", ("services/fxaccounts/",)),
    "telemetry": ("privacy-review", ("toolkit/components/telemetry/",)),
    "newtab": ("privacy-review", ("browser/components/newtab/",)),
    "tests": ("test-build-review", ("testing/",)),
    "localizations": ("localization-review", ("browser/locales/",)),
    "branding": ("trademark-audit", ("browser/branding/",)),
}

def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

def language(path):
    name = path.rsplit("/", 1)[-1].lower()
    if name.endswith(".rs"): return "rust"
    if name.endswith((".py", ".pyi")): return "python"
    if name.endswith((".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".m", ".mm", ".s")):
        return "c_cpp_asm"
    if name.endswith((".js", ".mjs", ".jsx", ".ts", ".tsx", ".html", ".xhtml", ".css")):
        return "web"
    if name in ("moz.build", "moz.configure", "cargo.toml", "cargo.lock", "makefile", "makefile.in"):
        return "build_metadata"
    return "assets_and_other"

def inventory(repo):
    commit = git(repo, "rev-parse", "HEAD").decode().strip()
    raw = git(repo, "ls-tree", "-r", "-l", "-z", "HEAD")
    tops = defaultdict(lambda: {"files": 0, "bytes": 0})
    languages = defaultdict(lambda: {"files": 0, "bytes": 0})
    groups = {k: {"decision": v[0], "prefixes": list(v[1]), "files": 0, "bytes": 0}
              for k, v in GROUPS.items()}
    total = total_bytes = 0
    for record in raw.split(b"\0"):
        if not record:
            continue
        header, path = record.split(b"\t", 1)
        mode, kind, sha, size = header.split()
        if kind != b"blob":
            continue
        if size == b"-":
            raise ValueError("Unmeasurable tracked blob " + repr(path))
        name = path.decode("utf-8", "surrogateescape")
        n = int(size)
        total += 1
        total_bytes += n
        top = name.split("/", 1)[0] if "/" in name else "[root]"
        lang = language(name)
        for item in (tops[top], languages[lang]):
            item["files"] += 1
            item["bytes"] += n
        for k, (_decision, prefixes) in GROUPS.items():
            if any(name.startswith(prefix) for prefix in prefixes):
                groups[k]["files"] += 1
                groups[k]["bytes"] += n
    if total == 0:
        raise ValueError("Git source tree contains no measured blobs")
    return {
        "schema_version": 1, "project": "Vulpra", "commit": commit,
        "source_only": True, "source_files": total, "source_blob_bytes": total_bytes,
        "top_level": dict(sorted(tops.items(), key=lambda x: (-x[1]["bytes"], x[0]))),
        "language": dict(sorted(languages.items())),
        "groups": groups,
        "limitations": [
            "Tracked Git HEAD blob sizes, not working tree modifications or compiled size",
            "Language family classification is suffix-based and approximate",
            "Path groups can overlap and are review candidates, not dead-code proof",
            "No dependency graph traversal, removal, source write or regression run",
            "C/C++ and Python source is a migration inventory, not removable bloat",
        ],
    }

def markdown(data):
    rows = [
        "# Vulpra M3 pinned-source footprint",
        "",
        "Git HEAD: " + data["commit"],
        "Tracked files: " + format(data["source_files"], ","),
        "Git blob bytes: " + format(data["source_blob_bytes"], ","),
        "No removals. No native rebuild. No dependency reachability verified.",
        "",
        "## Top-level source footprint",
        "",
        "| Directory | Files | Blob bytes |",
        "| --- | ---: | ---: |",
    ]
    for path, stat in list(data["top_level"].items())[:30]:
        rows.append("| " + path + " | " + str(stat["files"]) + " | " + str(stat["bytes"]) + " |")
    rows.extend(["", "## Language families", "",
                 "| Family | Files | Blob bytes |", "| --- | ---: | ---: |"])
    for name, stat in data["language"].items():
        rows.append("| " + name + " | " + str(stat["files"]) + " | " + str(stat["bytes"]) + " |")
    rows.extend(["", "## Protected areas and review candidates", "",
                 "| Group | Decision | Files | Blob bytes |", "| --- | --- | ---: | ---: |"])
    for name, stat in data["groups"].items():
        rows.append("| " + name + " | " + stat["decision"] + " | " + str(stat["files"]) +
                    " | " + str(stat["bytes"]) + " |")
    rows.extend(["", "## Non-negotiable removal prerequisites", "",
                 "Inspect build and runtime references; preserve required license records.",
                 "Do not delete WebExtension APIs, GTK/Wayland, or Gecko infrastructure.",
                 "Remove only a proven optional unit, in a reversible commit.",
                 "Rebuild native browser and re-run package, Wayland, navigation and",
                 "WebExtension acceptance checks. Compare metrics before and after.", ""])
    return "\n".join(rows)

def main():
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "Code/Apps/vulpra").resolve()
    data = inventory(repo)
    out = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-path",
                   "vulpra-debloat").decode().strip())
    out.mkdir(parents=True, exist_ok=True)
    jf = out / "m3-source-inventory.json"
    mf = out / "m3-source-inventory.md"
    jf.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n")
    mf.write_text(markdown(data))
    print("PASS: Read-only M3 inventory - " + str(data["source_files"]) +
          " files / " + str(data["source_blob_bytes"]) + " Git blob bytes")
    print("JSON: " + str(jf))
    print("Markdown: " + str(mf))
    print("No source writes, removals, build or functional verification performed.")

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        print("ERROR: M3 inventory failed: " + str(e), file=sys.stderr)
        raise SystemExit(1)
