#!/usr/bin/env python3
"""Validate archived PromoCard native-pair metadata, never native acceptance itself.

Read-only: cannot fetch the original build artifacts, establish reproducibility,
attribute package bytes to a component, or substitute for browser smoke tests.
"""
from __future__ import annotations

from copy import deepcopy
import json
from math import floor, isclose
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SHA40 = re.compile(r"^[a-f0-9]{40}$")
SHA256 = re.compile(r"^[a-f0-9]{64}$")


def validate(e: dict, register: dict, progress: dict, roadmap: str) -> None:
    assert e["schema_version"] == 1 and e["project"] == "Vulpra"
    assert e["experiment"] == "linux-newtab-promocard-optout"
    source = e["source_commit"]
    assert SHA40.fullmatch(source)
    normal, lean, diff = e["normal"], e["optin"], e["measurements"]
    assert normal["workflow_run"] != lean["workflow_run"]
    assert normal["artifact_id"] != lean["artifact_id"]
    assert all(type(x) is int and x > 0 for x in (
        normal["workflow_run"], lean["workflow_run"],
        normal["artifact_id"], lean["artifact_id"],
        normal["compressed_package_bytes"], lean["compressed_package_bytes"],
        normal["newtab_js_bytes"], lean["newtab_js_bytes"]))
    assert all(SHA256.fullmatch(x) for x in (
        normal["package_sha256"], lean["package_sha256"],
        normal["newtab_js_sha256"], lean["newtab_js_sha256"]))
    assert normal["package_sha256"] != lean["package_sha256"]
    assert normal["newtab_js_sha256"] != lean["newtab_js_sha256"]
    assert normal["original_promocard_included"] is True
    assert lean["original_promocard_included"] is False
    assert normal["protected_newtab_resources"] is True
    assert lean["protected_newtab_resources"] is True
    assert len(lean["runtime_checks"]) >= 5
    assert diff["signed_full_minus_optin_compressed_archive_bytes"] == (
        normal["compressed_package_bytes"] - lean["compressed_package_bytes"])
    assert diff["signed_full_minus_optin_uncompressed_newtab_js_bytes"] == (
        normal["newtab_js_bytes"] - lean["newtab_js_bytes"])
    assert isclose(
        diff["compressed_archive_difference_percent"],
        100 * diff["signed_full_minus_optin_compressed_archive_bytes"]
        / normal["compressed_package_bytes"], abs_tol=0.00000001)
    confidence = e["confidence"]
    for key in ("same_source", "native_build_and_package_both_passed",
                "optin_native_runtime_passed", "source_omission_confirmed_in_packaged_newtab"):
        assert confidence[key] is True
    for key in ("repeatability_established", "component_specific_compressed_saving_established",
                "normal_browser_behavior_changed"):
        assert confidence[key] is False

    candidates = register["candidates"]
    pocket, = (c for c in candidates if c["id"] == "pocket_integration")
    trial = pocket["promocard_native_pair"]
    compared = e["comparison"]
    assert compared["status"] == "passed"
    assert compared["compared_source_sha"] == source
    assert compared["comparator_passed"] is True
    assert compared["signed_byte_delta"] == diff["signed_full_minus_optin_compressed_archive_bytes"]
    assert compared["comparison_percent"] == diff["compressed_archive_difference_percent"]
    assert compared["replay_workflow_run"] not in (
        normal["workflow_run"], lean["workflow_run"])
    assert compared["failed_original_workflow_run"] != compared["replay_workflow_run"]
    assert trial["comparison_run_id"] == compared["replay_workflow_run"]
    assert trial["comparison_artifact_id"] == compared["artifact_id"]
    assert trial["comparison_passed"] is True
    assert trial["initial_comparison_failed_run_id"] == compared["failed_original_workflow_run"]
    assert trial["source_sha"] == source
    assert trial["normal_native_run_id"] == normal["workflow_run"]
    assert trial["optin_native_run_id"] == lean["workflow_run"]
    assert trial["normal_artifact_id"] == normal["artifact_id"]
    assert trial["optin_artifact_id"] == lean["artifact_id"]
    assert trial["normal_compressed_bytes"] == normal["compressed_package_bytes"]
    assert trial["optin_compressed_bytes"] == lean["compressed_package_bytes"]
    assert trial["observed_archive_delta_bytes"] == diff["signed_full_minus_optin_compressed_archive_bytes"]
    assert trial["normal_archive_sha256"] == normal["package_sha256"]
    assert trial["optin_archive_sha256"] == lean["package_sha256"]
    assert trial["normal_newtab_js_bytes"] == normal["newtab_js_bytes"]
    assert trial["optin_newtab_js_bytes"] == lean["newtab_js_bytes"]
    assert trial["newtab_js_delta_bytes"] == diff["signed_full_minus_optin_uncompressed_newtab_js_bytes"]
    assert trial["optin_native_runtime_passed"] is True
    assert trial["original_jsx_present_only_in_normal"] is True
    assert trial["protected_adbanner_adsfeed_and_feeds_retained"] is True
    assert trial["normal_build_unchanged"] is True
    assert trial["permanent_source_deletion_authorized"] is False
    assert trial["repeatability_or_causal_size_established"] is False

    milestones = {m["id"]: m for m in progress["milestones"]}
    m3 = milestones["M3"]
    assert m3["acceptance_gates"]["passed"] == 2
    assert m3["acceptance_gates"]["total"] == 6
    assert m3["percent"] == 33
    assert progress["overall"]["percent"] == floor(
        (milestones["M2"]["percent"] + m3["percent"] + milestones["M4"]["percent"]) / 3)
    records = [r for r in m3["verified_removals"] if r["id"] == "opt-in-newtab-promocard-jsx"]
    assert len(records) == 1
    record = records[0]
    assert record["comparison_run"] == compared["replay_workflow_run"]
    assert record["comparison_artifact_id"] == compared["artifact_id"]
    assert record["comparison_passed"] is True
    assert record["initial_comparison_failed_run"] == compared["failed_original_workflow_run"]
    assert record["source_commit"] == source
    assert record["candidate_run"] == lean["workflow_run"]
    assert record["matched_full_run"] == normal["workflow_run"]
    assert record["full_compressed_bytes"] == normal["compressed_package_bytes"]
    assert record["lean_compressed_bytes"] == lean["compressed_package_bytes"]
    assert record["observed_signed_archive_delta_bytes"] == diff["signed_full_minus_optin_compressed_archive_bytes"]
    assert record["observed_uncompressed_js_delta_bytes"] == diff["signed_full_minus_optin_uncompressed_newtab_js_bytes"]
    assert "2/6 (33%)" in roadmap and "overall 44%" in roadmap
    assert "M3-PROMOCARD-NATIVE-PAIR.json" in roadmap


def negative_tests(e: dict, register: dict, progress: dict, roadmap: str) -> None:
    cases = (
        lambda a, b, c: a["measurements"].update(signed_full_minus_optin_compressed_archive_bytes=99999),
        lambda a, b, c: a["normal"].update(package_sha256="a" * 64),
        lambda a, b, c: a["optin"].update(original_promocard_included=True),
        lambda a, b, c: a["confidence"].update(repeatability_established=True),
        lambda a, b, c: a["comparison"].update(comparator_passed=False),
        lambda a, b, c: a["comparison"].update(signed_byte_delta=219360),
        lambda a, b, c: b["candidates"][next(i for i, x in enumerate(b["candidates"])
                                                  if x["id"] == "pocket_integration")]["promocard_native_pair"].update(normal_build_unchanged=False),
        lambda a, b, c: c["overall"].update(percent=45),
        lambda a, b, c: c["milestones"][2]["acceptance_gates"].update(passed=3),
    )
    for mutate in cases:
        a, b, c = deepcopy(e), deepcopy(register), deepcopy(progress)
        mutate(a, b, c)
        try:
            validate(a, b, c, roadmap)
        except (AssertionError, KeyError, TypeError, ZeroDivisionError):
            continue
        raise AssertionError("Invalid PromoCard evidence accepted")


def main() -> None:
    evidence = json.loads((ROOT / "docs/vulpra/M3-PROMOCARD-NATIVE-PAIR.json").read_text())
    register = json.loads((ROOT / "docs/vulpra/DEBLOAT-CANDIDATES.json").read_text())
    progress = json.loads((ROOT / "docs/vulpra/PROGRESS.json").read_text())
    roadmap = (ROOT / "docs/vulpra/ROADMAP.md").read_text()
    validate(evidence, register, progress, roadmap)
    negative_tests(evidence, register, progress, roadmap)
    print("PASS: source-matched native PromoCard metadata, bytes, hashes and protected paths")
    print("PASS: nine mutation cases rejected and no unjustified M3 credit")
    print("METADATA ONLY: real browser evidence remains in immutable native workflow artifacts")


if __name__ == "__main__":
    main()
