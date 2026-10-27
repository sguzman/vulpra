#!/usr/bin/env python3
"""Read-only Git source audit of optional Firefox GenAI/LinkPreview resources.

Does not assert that any matched component can be removed. Reports external
callers and package registrations that must be evaluated before a build optout.
Runs against real checked-out files, not GitHub code-search indexing.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys

PATTERNS = (
    r"moz-src:///browser/components/genai/",
    r"chrome://browser/content/genai/",
    r"browser/components/genai/",
    r"GenAI\.sys\.mjs",
    r"LinkPreview(Model|Parent|Child)?\.sys\.mjs",
    r"PageAssist(Parent|Child)?\.sys\.mjs",
    r"GenAI(Parent|Child)\.sys\.mjs",
    r"LinkPreview\.(init|uninit|enable|block)",
    r"browser\.ml\.(chat|linkPreview)",
)
GROUPS = {
    "genai-owned": ("browser/components/genai/",),
    "test-only": ("testing/", "browser/components/test/", "ci/tests/"),
    "project-docs-tooling": ("docs/", "ci/", ".github/"),
    "localization": ("browser/locales/", "l10n/",),
}

def classify(path: str) -> str:
    lower = path.lower()
    if (path.startswith(GROUPS["test-only"]) or "/test/" in path or
            "/tests/" in path):
        return "test-only"
    if path.startswith(GROUPS["genai-owned"]):
        return "genai-owned"
    if path.startswith(GROUPS["project-docs-tooling"]) or lower.endswith((".md", ".rst")):
        return "project-docs-tooling"
    if path.startswith(GROUPS["localization"]) or lower.endswith((".ftl", ".dtd")):
        return "localization"
    return "external-source-review"

def audit(root: Path) -> dict:
    if not (root / ".git").exists() or not (root / "mach").is_file():
        raise RuntimeError("Expected a Git checkout of Vulpra with mach")
    args = ["git", "grep", "--full-name", "-I", "-n", "-E"]
    for pattern in PATTERNS:
        args += ["-e", pattern]
    args += ["--", "."]
    proc = subprocess.run(args, cwd=root, text=True, capture_output=True,
                          encoding="utf-8", errors="replace")
    if proc.returncode not in (0, 1):
        raise RuntimeError("Git grep failed: " + proc.stderr[-1500:])
    matches = []
    for line in proc.stdout.splitlines():
        try:
            path, number, snippet = line.split(":", 2)
            line_number = int(number)
        except ValueError as exc:
            raise RuntimeError("Invalid git grep output: " + line[:160]) from exc
        matches.append({"path": path, "line": line_number,
                        "class": classify(path), "snippet": snippet.strip()[:240]})
    outside = [m for m in matches if m["class"] == "external-source-review"]
    src = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root,
                                  text=True).strip()
    return {
        "schema_version": 1, "phase": "M3", "candidate": "browser_genai",
        "source_commit": src, "patterns": list(PATTERNS),
        "matching_lines": len(matches),
        "counts_by_class": dict(sorted(Counter(m["class"] for m in matches).items())),
        "external_source_paths": dict(Counter(m["path"] for m in outside).most_common()),
        "matches": matches,
        "removal_authorized": False,
        "next_gate": "Review every external caller, actor, startup registration, prefs and UI fallback before opt-in native change",
        "limitations": [
            "Literal patterns are not complete dynamic import or dependency analysis",
            "False positives from static text and missed computed URIs are possible",
            "No source files removed or native runtime/size results inferred",
        ],
    }

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("root", nargs="?", default=".")
    p.add_argument("--output", required=True)
    a = p.parse_args()
    result = audit(Path(a.root).resolve())
    out = Path(a.output).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("GenAI source audit:", result["source_commit"])
    print("Matching lines:", result["matching_lines"])
    for group, count in result["counts_by_class"].items():
        print(f"  {group}: {count}")
    print("External source callers / registrations (first 80):")
    for path, count in list(result["external_source_paths"].items())[:80]:
        print(f"  {count:4} {path}")
    print("Saved audit:", out)
    print("AUDIT ONLY; NO REMOVAL ACCEPTED")

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as exc:
        print("FAIL:", exc, file=sys.stderr)
        raise SystemExit(1)
