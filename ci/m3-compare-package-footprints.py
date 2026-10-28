#!/usr/bin/env python3
"""Compare exact New Tab ZIP entries in two verified package census reports.

The original census SHA256-checks each input tar.xz before emitting JSON. This
offline comparison does not fetch or rehash either original package and does
not prove source-match, repeatability, or XZ byte attribution.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

TARGET = "builtin-addons/newtab/lib/AdsFeed.sys.mjs"


def read_report(path: Path) -> dict:
    d = json.loads(path.read_text())
    if d.get("test") != "read_only_real_archive_resource_census":
        raise ValueError(f"Not a Vulpra package census: {path}")
    if not re.fullmatch(r"[0-9a-f]{64}", d.get("sha256", "")):
        raise ValueError(f"No SHA256 attestation in census: {path}")
    if not isinstance(d.get("compressed_archive_bytes"), int) or d["compressed_archive_bytes"] <= 0:
        raise ValueError(f"Invalid compressed package bytes: {path}")
    return d


def index_jar_records(report: dict) -> dict:
    result = {}
    found = 0
    for jar in report.get("omni_resources", []):
        idx = jar.get("resource_index", {})
        if idx.get("status") != "readable":
            raise ValueError(f"Unreadable/partial omni.ja census: {jar.get('archive_path')}")
        newtab = idx.get("newtab_lib_resources")
        if not isinstance(newtab, dict) or not isinstance(newtab.get("entries"), list):
            raise ValueError("Census predates exact New Tab ZIP resource accounting")
        entries = newtab["entries"]
        if newtab.get("count") != len(entries):
            raise ValueError("Inconsistent New Tab ZIP entry count")
        if newtab.get("logical_bytes") != sum(x["logical_bytes"] for x in entries):
            raise ValueError("Inconsistent New Tab uncompressed byte total")
        if newtab.get("zip_compressed_entry_bytes") != sum(
            x["zip_compressed_entry_bytes"] for x in entries
        ):
            raise ValueError("Inconsistent New Tab ZIP compressed byte total")
        for entry in entries:
            path = entry.get("path")
            if not isinstance(path, str) or not path.startswith("builtin-addons/newtab/lib/"):
                raise ValueError(f"Unexpected indexed New Tab resource: {entry!r}")
            if path in result:
                raise ValueError(f"Resource duplicated across omni.ja indexes: {path}")
            if (not isinstance(entry.get("logical_bytes"), int)
                    or not isinstance(entry.get("zip_compressed_entry_bytes"), int)
                    or not re.fullmatch(r"[0-9a-f]{8}", entry.get("zip_crc32", ""))):
                raise ValueError(f"Malformed resource metadata: {path}")
            result[path] = entry
        found += 1
    if found < 1 or not result:
        raise ValueError("No complete New Tab resource index from any readable omni.ja archive")
    return result


def compare(baseline: dict, candidate: dict) -> dict:
    full = index_jar_records(baseline)
    lean = index_jar_records(candidate)
    removed = sorted(set(full) - set(lean))
    added = sorted(set(lean) - set(full))
    changed = sorted(
        name for name in set(full) & set(lean)
        if full[name]["zip_crc32"] != lean[name]["zip_crc32"]
        or full[name]["logical_bytes"] != lean[name]["logical_bytes"]
        or full[name]["zip_compressed_entry_bytes"] != lean[name]["zip_compressed_entry_bytes"]
    )
    unchanged = len(set(full) & set(lean)) - len(changed)
    removed_details = [
        {"path": name, "logical_bytes": full[name]["logical_bytes"],
         "zip_compressed_entry_bytes": full[name]["zip_compressed_entry_bytes"]}
        for name in removed
    ]
    return {
        "schema_version": 1,
        "source": "already-generated read-only package census reports",
        "baseline_archive_sha256": baseline["sha256"],
        "candidate_archive_sha256": candidate["sha256"],
        "baseline_compressed_package_bytes": baseline["compressed_archive_bytes"],
        "candidate_compressed_package_bytes": candidate["compressed_archive_bytes"],
        "observed_outer_archive_byte_difference": (
            baseline["compressed_archive_bytes"] - candidate["compressed_archive_bytes"]
        ),
        "newtab_lib_resources_in_baseline": len(full),
        "newtab_lib_resources_in_candidate": len(lean),
        "removed": removed_details,
        "added": added,
        "changed": changed,
        "unchanged_count": unchanged,
        "adsfeed_resource_removed": TARGET in removed,
        "removed_zip_entry_compressed_bytes": sum(
            x["zip_compressed_entry_bytes"] for x in removed_details
        ),
        "limitations": [
            "Census reports are not original archives; this script does not recheck binary SHA256.",
            "Source commit and matched build options are not recorded by these reports; confirm independently.",
            "ZIP entry compressed bytes are not the marginal bytes in an outer compressed tar.xz.",
            "Other changes outside indexed New Tab resources can affect the observed outer archive delta.",
            "ZIP CRC32 is an accidental-change check, not a cryptographic identity or content proof.",
            "This is packaging evidence only; removal safety requires real browser runtime tests.",
        ],
    }


def main() -> None:
    if len(sys.argv) != 4:
        raise ValueError(
            "Usage: m3-compare-package-footprints.py BASELINE.json CANDIDATE.json OUTPUT.json"
        )
    baseline = read_report(Path(sys.argv[1]))
    candidate = read_report(Path(sys.argv[2]))
    result = compare(baseline, candidate)
    Path(sys.argv[3]).write_text(json.dumps(result, indent=2) + "\n")
    print(
        "PASS: exact ZIP resource diff: "
        f"{len(result['removed'])} removed, {len(result['added'])} added, "
        f"{len(result['changed'])} changed, {result['unchanged_count']} unchanged"
    )
    print(
        f"Outer archive difference: {result['observed_outer_archive_byte_difference']} B; "
        f"removed ZIP entry bytes: {result['removed_zip_entry_compressed_bytes']} B"
    )
    print("NO SOURCE-MATCH, NATIVE RUNTIME, REPRODUCIBILITY OR REMOVAL CREDIT from census JSON.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
        print("FAIL:", e, file=sys.stderr)
        raise SystemExit(1)
