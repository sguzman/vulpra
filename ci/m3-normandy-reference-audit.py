#!/usr/bin/env python3
"""Inventory Normandy references in a complete Vulpra Git checkout.

Reports source references for review; a hit is not evidence of a runtime
failure or a removability decision. Does not mutate source or browser files.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys

PATTERNS = (
    r"resource://normandy(-content|-vendor)?/",
    r"Normandy\.(init|uninit)\s*\(",
    r"MOZ_NORMANDY",
    r"shield-init-complete",
    r"app\.normandy",
    r"normandy/",
)

def classify(path):
    name = path.lower()
    if name.startswith("toolkit/components/normandy/"):
        return "removed-subtree"
    if name.startswith(("docs/", "ci/", ".github/")) or name.endswith((".md", ".rst")):
        return "project-documentation-or-tooling"
    if (name.startswith("testing/") or "/test/" in name or "/tests/" in name
            or name.endswith((".toml", ".ini")) and ("test" in name or "xpcshell" in name)):
        return "test-only-or-test-manifest"
    return "other-source-review"

def scan(root):
    if not (root / ".git").exists() or not (root / "mach").is_file():
        raise RuntimeError("Requires a complete Git checkout of Vulpra with mach")
    cmd = ["git", "grep", "-n", "-I", "-E", "--full-name"]
    for pattern in PATTERNS:
        cmd.extend(("-e", pattern))
    cmd.extend(("--", "."))
    proc = subprocess.run(cmd, cwd=root, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if proc.returncode not in (0, 1):
        raise RuntimeError(f"git grep failed ({proc.returncode}): {proc.stderr[-1000:]}")
    entries = []
    for line in proc.stdout.splitlines():
        try:
            path, line_no, content = line.split(":", 2)
            int(line_no)
        except ValueError as error:
            raise RuntimeError(f"Unexpected git grep line: {line[:200]}") from error
        entries.append({"path": path, "line": int(line_no),
                        "classification": classify(path),
                        "snippet": content.strip()[:300]})
    return {"schema_version": 1, "scope": "Git-tracked Normandy spelling and import audit",
            "patterns": list(PATTERNS), "match_count": len(entries),
            "counts_by_class": dict(sorted(Counter(e["classification"] for e in entries).items())),
            "other_source_paths": dict(Counter(e["path"] for e in entries
                                               if e["classification"] == "other-source-review").most_common()),
            "matches": entries,
            "limitations": ["String matching is not a module-dependency graph",
                            "Some test files outside conventional test paths may be classified as other-source",
                            "Dynamic URI construction and symbol references without these literals can be missed",
                            "An unguarded shipped caller requires manual audit before accepting any build"]}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", nargs="?", default=".")
    parser.add_argument("--output", default="")
    args = parser.parse_args()
    root = Path(args.repo).resolve()
    report = scan(root)
    report["source_commit"] = subprocess.check_output(["git", "rev-parse", "HEAD"],
                                                      cwd=root, text=True).strip()
    if args.output:
        destination = Path(args.output).resolve()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Vulpra Normandy reference audit HEAD {report['source_commit']}")
    print(f"Total matching lines: {report['match_count']}")
    for group, count in report["counts_by_class"].items():
        print(f"  {group}: {count}")
    print("Source paths outside removed subtree, tests and project docs:")
    for path, count in report["other_source_paths"].items():
        print(f"  {count:5} {path}")
    print("Relevant lines in first 70 other-source paths (up to 3 per path):")
    shown = Counter()
    for entry in report["matches"]:
        if entry["classification"] == "other-source-review" and shown[entry["path"]] < 3 and len(shown) <= 70:
            shown[entry["path"]] += 1
            print(f"  {entry['path']}:{entry['line']}: {entry['snippet']}")
    if args.output:
        print(f"Full JSON audit: {args.output}")
    print("AUDIT ONLY: no source edits, alternate native build, or size reduction verified.")

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
