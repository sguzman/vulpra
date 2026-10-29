#!/usr/bin/env python3
"""Read-only CI host-cache crosswalk for packaged Vulpra direct DT_NEEDED.

Uses an independently checksum-verified packaged ELF census, ldconfig -p and
readelf -hW. Does NOT run any package ELF, invoke ldd, load a library,
resolve transitive imports, emulate the dynamic loader, or check the user's PC.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

HEX64 = re.compile(r"[0-9a-f]{64}\Z")
NAME = re.compile(r"[A-Za-z0-9_.+-]{1,128}\Z")
CACHE_ROW = re.compile(r"^\s*([^\s]+)\s+\(([^)]+)\)\s+=>\s+(/\S+)\s*$")


def validate_graph(graph):
    if not isinstance(graph, dict) or graph.get("schema_version") != 1:
        raise ValueError("Invalid upstream graph")
    if not isinstance(graph.get("archive_sha256"), str) or not HEX64.fullmatch(graph["archive_sha256"]):
        raise ValueError("Missing checksum-verified archive identity")
    if graph.get("source_removal_authorized") is not False or (
        graph.get("host_dependency_resolution_verified") is not False
    ) or graph.get("all_native_binary_execution_avoided") is not True:
        raise ValueError("Unsupported upstream host resolution or source-deletion claims")
    absent = graph.get("not_packaged_needed_names")
    packaged = graph.get("packaged_elf_needed_names")
    if not isinstance(absent, list) or not absent or not isinstance(packaged, list):
        raise ValueError("Incomplete graph direct import collections")
    for label, items in (("external", absent), ("packaged", packaged)):
        if len(set(items)) != len(items) or any(not isinstance(s, str) or not NAME.fullmatch(s) for s in items):
            raise ValueError("Invalid or duplicate " + label + " loader names")
    if set(absent) & set(packaged):
        raise ValueError("External and bundled library sets overlap")
    return absent


def cache_rows(text):
    if not isinstance(text, str) or len(text) > 8_000_000:
        raise ValueError("Invalid or oversized host ldconfig output")
    matches = {}
    for row in text.splitlines():
        m = CACHE_ROW.fullmatch(row)
        if m is None:
            continue
        soname, platform, location = m.groups()
        if not NAME.fullmatch(soname) or not platform.strip() or (
            "x86-64" not in platform.lower() and "x86_64" not in platform.lower()
        ):
            continue
        if Path(location).name != soname or "\0" in location:
            continue
        matches.setdefault(soname, set()).add(location)
    return {k: sorted(v) for k, v in sorted(matches.items())}


def host_elf64(path):
    try:
        resolved = path.resolve(strict=True)
        if not resolved.is_file() or not any(
            resolved.is_relative_to(prefix) for prefix in (Path("/usr/lib"), Path("/lib"), Path("/lib64"))
        ):
            return False
        p = subprocess.run(
            ["readelf", "-hW", str(resolved)], capture_output=True, text=True,
            timeout=20, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return p.returncode == 0 and "ELF64" in p.stdout and "X86-64" in p.stdout


def inspect(graph, output):
    imports = validate_graph(graph)
    cache = cache_rows(output)
    rows = []
    matched = 0
    for name in imports:
        configured = cache.get(name, [])
        candidates = [p for p in configured if host_elf64(Path(p))]
        matched += bool(candidates)
        rows.append({
            "requested_soname": name,
            "ldconfig_arch_compatible_regular_ELF_file_present": bool(candidates),
            "matching_ldconfig_entries": len(candidates),
            "matching_host_example": candidates[0] if candidates else None,
        })
    return {
        "schema_version": 1,
        "source_archive_sha256": graph["archive_sha256"],
        "scope": "Ubuntu CI host ldconfig cache file-presence preflight for external direct package ELF needs",
        "host_platform": "ubuntu-24.04-x86_64-ci",
        "direct_unbundled_names_checked": len(imports),
        "names_with_host_elf64_cache_candidates": matched,
        "names_with_no_compatible_host_cache_candidate": len(imports) - matched,
        "candidate_rows": rows,
        "native_package_binary_executed": False,
        "ldd_or_dlopen_called": False,
        "host_transitive_and_searchpath_closure_proven": False,
        "target_workstation_library_resolution_proven": False,
        "compiled_feature_savings_claimed": None,
        "source_removal_authorized": False,
        "limitations": [
            "Presence in ldconfig -p is neither dynamic loader resolution nor ABI compatibility.",
            "dlopen, RPATH/RUNPATH, namespace effects, symlink semantics and transitive imports not resolved.",
            "CI Ubuntu is not the user's Arch/Wayland installation.",
            "Missing from ldconfig cache is not proof of failure to load by other search mechanisms.",
            "No feature attribution, compilation, executed Vulpra, or removable byte claim.",
        ],
    }


def selftest():
    graph = {
        "schema_version": 1, "archive_sha256": "a" * 64,
        "source_removal_authorized": False, "host_dependency_resolution_verified": False,
        "all_native_binary_execution_avoided": True,
        "not_packaged_needed_names": ["libfoo.so.1"], "packaged_elf_needed_names": ["libxul.so"],
    }
    sample = "123 libs found in cache\n\tlibfoo.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libfoo.so.1\n\tlibbar.so.1 (libc6) => /lib/libbar.so.1\n"
    assert cache_rows(sample)["libfoo.so.1"] == ["/lib/x86_64-linux-gnu/libfoo.so.1"]
    assert "libbar.so.1" not in cache_rows(sample)
    assert validate_graph(graph) == ["libfoo.so.1"]
    malformed = [
        dict(graph, archive_sha256="a" * 40),
        dict(graph, source_removal_authorized=True),
        dict(graph, host_dependency_resolution_verified=True),
        dict(graph, all_native_binary_execution_avoided=False),
        dict(graph, not_packaged_needed_names=["libfoo.so.1", "libfoo.so.1"]),
        dict(graph, not_packaged_needed_names=["../libfoo.so.1"]),
        dict(graph, packaged_elf_needed_names=["libfoo.so.1"]),
    ]
    from copy import deepcopy
    for changed in malformed:
        try:
            validate_graph(deepcopy(changed))
        except ValueError:
            continue
        raise AssertionError("False host crosswalk accepted")
    assert not cache_rows("libfoo.so.1 (libc6,x86-64) => /tmp/libfoo.so.1") == {}
    assert cache_rows("libfoo.so.1 (libc6,x86-64) => /tmp/other.so.1") == {}
    return len(malformed) + 4


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--graph", type=Path)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        print("PASS:", selftest(), "host-cache input/parsing boundaries")
    if not a.graph:
        if a.self_test:
            return
        ap.error("--graph required")
    if not a.output:
        ap.error("--output required")
    graph = json.loads(a.graph.read_text(encoding="utf-8"))
    run = subprocess.run(["/sbin/ldconfig", "-p"], capture_output=True, text=True, check=True, timeout=25)
    report = inspect(graph, run.stdout)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: host cache direct dependency file-presence preflight (not complete loader closure)")
    print("EXTERNAL:", report["direct_unbundled_names_checked"])
    print("HOST FILE CANDIDATES:", report["names_with_host_elf64_cache_candidates"])
    print("NO CACHE FILE CANDIDATE:", report["names_with_no_compatible_host_cache_candidate"])


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError, AssertionError) as e:
        print("FAIL M3 native host preflight:", e, file=sys.stderr)
        raise SystemExit(1)
