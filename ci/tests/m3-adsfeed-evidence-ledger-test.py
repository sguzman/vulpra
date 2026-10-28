#!/usr/bin/env python3
"""Fail closed on contradictory Vulpra AdsFeed package evidence metadata.

This is a READ-ONLY ledger consistency test. It does not fetch CI artifacts,
re-hash original archives, run Vulpra, prove repeatability, or imply that
a positive independent-build archive difference is caused by AdsFeed.
"""
from __future__ import annotations

from copy import deepcopy
import json
from math import floor, isclose
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HEX64 = re.compile(r"^[a-f0-9]{64}$")


def validate(candidate: dict, progress: dict) -> dict:
    assert candidate["id"] == "newtab_adsfeed_optout"
    assert candidate["opt_in_packaged_omission_accepted"] is True
    assert candidate["normal_browser_changed"] is False
    assert candidate["permanent_source_removal_authorized"] is False
    assert candidate["removal_authorized"] is False

    latest = candidate["final_evidence"]
    history = candidate.get("historical_matched_native_trials")
    assert isinstance(history, list) and len(history) >= 1
    trials = [*history, latest]

    seen_sources = set()
    for evidence in trials:
        sha = evidence["source_sha"]
        assert HEX64.fullmatch(sha), "Noncanonical source SHA"
        assert sha not in seen_sources, "Two independent trial records have the same source SHA"
        seen_sources.add(sha)
        full = evidence["full_bytes"]
        lean = evidence["lean_bytes"]
        delta = evidence["delta_bytes"]
        assert all(type(value) is int and value > 0
                   for value in (full, lean, delta)), "Invalid archive bytes"
        assert full - lean == delta, "Archive subtraction mismatch"
        assert isclose(evidence["delta_percent"], 100 * delta / full,
                       abs_tol=0.000001), "Percent incompatible with measured bytes"
        assert all(HEX64.fullmatch(evidence[key]) for key in
                   ("full_sha256", "lean_sha256")), "Invalid SHA-256 checksum"
        assert evidence["full_sha256"] != evidence["lean_sha256"]
        assert all(type(evidence[key]) is int and evidence[key] > 0 for key in
                   ("lean_native_run", "full_native_run", "comparison_run",
                    "comparison_artifact_id"))
        assert len({evidence["lean_native_run"], evidence["full_native_run"],
                    evidence["comparison_run"]}) == 3
        assert evidence["same_source"] is True
        assert evidence["accepted_native_runtime"] is True
        assert evidence["verified_absence_of_adsfeed_in_lean"] is True
        assert evidence["verified_adsfeed_present_in_full"] is True

    assert candidate["source_commit"] == latest["source_sha"]
    assert candidate["native_trial_run_id"] == latest["lean_native_run"]
    assert candidate["matched_baseline_run_id"] == latest["full_native_run"]
    assert candidate["matched_baseline_delta_bytes"] == latest["delta_bytes"]
    assert candidate["compressed_package_bytes"] == latest["lean_bytes"]
    assert candidate["full_compressed_package_bytes"] == latest["full_bytes"]
    assert candidate["native_package_sha256"] == latest["lean_sha256"]
    assert candidate["full_package_sha256"] == latest["full_sha256"]

    values = [evidence["delta_bytes"] for evidence in trials]
    assessment = candidate["variability_assessment"]
    assert assessment["earlier_delta_bytes"] == history[0]["delta_bytes"]
    assert assessment["guarded_delta_bytes"] == latest["delta_bytes"]
    assert assessment["earlier_source_sha"] == history[0]["source_sha"]
    assert assessment["guarded_source_sha"] == latest["source_sha"]
    assert assessment["observed_delta_spread_bytes"] == max(values) - min(values)
    assert len(set(values)) > 1, "No observed variation to attribute uncertainty to"

    review = candidate["residual_sponsored_path_review"]
    assert "pending_trial" not in review, "Completed run still marked pending"
    accepted = review["completed_trial"]
    assert accepted["status"].startswith("PASSED")
    assert accepted["source_commit"] == latest["source_sha"]
    assert accepted["comparison_run_id"] == latest["comparison_run"]
    assert accepted["matched_delta_bytes"] == latest["delta_bytes"]

    m2 = next(x for x in progress["milestones"] if x["id"] == "M2")
    m3 = next(x for x in progress["milestones"] if x["id"] == "M3")
    m4 = next(x for x in progress["milestones"] if x["id"] == "M4")
    gates = m3["acceptance_gates"]
    assert gates["passed"] == 2 and gates["total"] == 6, "Unexpected M3 gates"
    assert m3["percent"] == floor(100 * gates["passed"] / gates["total"])
    assert progress["overall"]["percent"] == floor(
        (m2["percent"] + m3["percent"] + m4["percent"]) / 3
    ), "Unjustified project percentage credit"

    return {
        "observed_trials": len(trials),
        "source_commits": sorted(seen_sources),
        "measured_archive_deltas": values,
        "observed_spread_bytes": max(values) - min(values),
        "conclusion": "Separate source-matched trials are valid but not repeat builds; "
                      "no per-resource causal or repeatability claim.",
    }


def test_mutation_failures(candidate: dict, progress: dict) -> None:
    """The fixture checks that common ways to overstate savings fail closed."""
    mutations = (
        lambda c, p: c["final_evidence"].update(delta_bytes=219360),
        lambda c, p: c["final_evidence"].update(
            source_sha=c["historical_matched_native_trials"][0]["source_sha"]),
        lambda c, p: c.update(matched_baseline_delta_bytes=219360),
        lambda c, p: c["variability_assessment"].update(
            observed_delta_spread_bytes=0),
        lambda c, p: c.update(normal_browser_changed=True),
        lambda c, p: p["overall"].update(percent=p["overall"]["percent"] + 1),
        lambda c, p: p["milestones"][2]["acceptance_gates"].update(passed=3),
    )
    for mutate in mutations:
        bad_candidate = deepcopy(candidate)
        bad_progress = deepcopy(progress)
        mutate(bad_candidate, bad_progress)
        try:
            validate(bad_candidate, bad_progress)
        except (AssertionError, KeyError, TypeError):
            continue
        raise AssertionError("Failed to reject manipulated report")


def main() -> None:
    register = json.loads(
        (ROOT / "docs/vulpra/DEBLOAT-CANDIDATES.json").read_text()
    )
    progress = json.loads((ROOT / "docs/vulpra/PROGRESS.json").read_text())
    candidate, = (x for x in register["candidates"]
                  if x["id"] == "newtab_adsfeed_optout")
    report = validate(candidate, progress)
    test_mutation_failures(candidate, progress)
    print("PASS: ledger measurements, source SHA, paired CI runs and checksums consistent")
    print("PASS: deliberate byte/source/progress tampering rejected")
    print(json.dumps(report, indent=2))
    print("METADATA CHECK ONLY: cannot infer marginal component bytes or reproducible savings")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, AssertionError, KeyError, TypeError) as e:
        print("FAIL: AdsFeed evidence ledger inconsistency:", e, file=sys.stderr)
        raise SystemExit(1)
