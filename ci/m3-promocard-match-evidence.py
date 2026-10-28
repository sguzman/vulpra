#!/usr/bin/env python3
"""Compare real same-source normal and opt-in PromoCard package evidence.

A signed outer archive byte delta is recorded; positive savings are NOT
required, and no causality or repeatability is implied.
"""
from __future__ import annotations

import argparse
import json
from math import isfinite
from pathlib import Path
import re
import sys

def verify(full: dict, lean: dict, source_sha: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise ValueError("Invalid source SHA")
    if full["source_commit"] != lean["source_commit"] or full["source_commit"] != source_sha:
        raise ValueError("Not the same source commit")
    if full["variant"] != "linux-newtab-promocard-normal":
        raise ValueError("Invalid full variant")
    if lean["variant"] != "linux-newtab-promocard-optin":
        raise ValueError("Invalid opt-in variant")
    if full["status"] != "full normal baseline native compile and package verified":
        raise ValueError("Full browser not verified")
    if lean["status"] != "native runtime accepted; matched comparison pending":
        raise ValueError("Opt-in browser not runtime accepted")
    if full["promocard_original_code_present"] is not True or lean["promocard_original_code_present"] is not False:
        raise ValueError("PromoCard original module presence mismatch")
    if not (full["adsfeed_resource_present"] and lean["adsfeed_resource_present"]
            and full["protected_resources_present"] and lean["protected_resources_present"]):
        raise ValueError("Protected New Tab resources not verified")
    if not all(lean["tested"].get(x) is True for x in
               ("wayland", "js", "newtab", "webextensions", "nimbus", "firefox_profile_isolation")):
        raise ValueError("Native runtime gates not all successful")
    for item in (full, lean):
        if not re.fullmatch(r"[a-f0-9]{64}", item["sha256"]):
            raise ValueError("Invalid package SHA256")
        if not isinstance(item["compressed_package_bytes"], int) or item["compressed_package_bytes"] <= 0:
            raise ValueError("Invalid archive bytes")
        if not isinstance(item["real_newtab_bundle"]["size"], int) or item["real_newtab_bundle"]["size"] <= 0:
            raise ValueError("Invalid bundle bytes")
        if not re.fullmatch(r"[a-f0-9]{64}", item["real_newtab_bundle"]["sha256"]):
            raise ValueError("Invalid bundle SHA256")
    full_bytes, lean_bytes = (full["compressed_package_bytes"],
                              lean["compressed_package_bytes"])
    delta = full_bytes - lean_bytes
    percent = delta / full_bytes * 100
    if not isfinite(percent):
        raise ValueError("Nonfinite byte percent")
    return {
        "schema_version": 1,
        "source_commit": source_sha,
        "full_compressed_package_bytes": full_bytes,
        "lean_compressed_package_bytes": lean_bytes,
        "observed_full_minus_optin_package_bytes": delta,
        "observed_package_difference_percent": round(percent, 8),
        "full_bundle_bytes": full["real_newtab_bundle"]["size"],
        "optin_bundle_bytes": lean["real_newtab_bundle"]["size"],
        "observed_uncompressed_newtab_js_difference": (
            full["real_newtab_bundle"]["size"] - lean["real_newtab_bundle"]["size"]
        ),
        "normal_package_sha256": full["sha256"],
        "optin_package_sha256": lean["sha256"],
        "normal_newtab_js_sha256": full["real_newtab_bundle"]["sha256"],
        "optin_newtab_js_sha256": lean["real_newtab_bundle"]["sha256"],
        "native_optin_runtime_passed": True,
        "same_source": True,
        "limitations": [
            "Independent same-source builds can vary for reasons other than the optional component.",
            "Positive, zero and negative archive deltas are all reported; none prove intrinsic resource size.",
            "Component-level attribution and reproducibility require controlled repeat builds.",
        ],
    }

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("full", type=Path)
    p.add_argument("lean", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--source-commit", required=True)
    args = p.parse_args()
    report = verify(json.loads(args.full.read_text()), json.loads(args.lean.read_text()),
                    args.source_commit)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print("PASS: same-source PromoCard real native package evidence, signed difference (not causal saving)")

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
        print("FAIL: PromoCard source-matched evidence:", e, file=sys.stderr)
        raise SystemExit(1)
