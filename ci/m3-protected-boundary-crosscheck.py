#!/usr/bin/env python3
"""Fail-closed, source-pinned joint Pocket / Sync / Telemetry boundary register.

Consumes independent existing source audits, never assumes their grep/anchor
observations prove runtime behavior or source-removal safety. Runs no browser.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import re
import sys

SHA = re.compile(r"[0-9a-f]{40}\Z")
PATH = re.compile(r"(?!/)(?!.*(?:^|/)\.\.(?:/|$))[a-zA-Z0-9_./+-]{1,256}\Z")
EXPECTED = {
    "pocket": ("live_source_boundaries", "id", (
        "legacy_topstories_fallback",
        "modern_discovery_recommendations",
        "sponsored_discovery_path",
        "pocket_promo_preferences",
        "promo_card_banner_import",
    )),
    "sync": ("boundaries", "name", (
        "sync_source_vs_fxa_source",
        "browser_sync_tab_ui",
        "accounts_startup_and_commands",
        "account_sync_preferences",
        "webextension_sync_storage",
        "firefox_view_synced_tabs",
        "ai_window_account_auth",
    )),
    "telemetry": ("source_boundaries", "name", (
        "telemetry_controller_startup_shutdown",
        "sender_policy_deletion_request",
        "native_telemetry_and_pingsender",
        "glean_separate_bindings",
        "crashreporter_separate_config",
        "browser_preferences_and_privacy_ui",
    )),
    "deletion": ("source_boundaries", "name", (
        "distinct_master_policy_and_upload_preferences",
        "upload_pref_observer_and_old_queue_purge",
        "identifier_rotation_and_deletion_request",
        "uncontrollable_deletion_type_in_nimbus",
        "official_build_gate_and_type_specific_upload_optout",
        "sender_policy_scheduler_and_pending_queues",
    )),
}
RISKS = (
    ("pocket_fallback_and_sponsored_share_feed",
     "pocket", ("legacy_topstories_fallback", "modern_discovery_recommendations", "sponsored_discovery_path"),
     "New Tab has independent legacy and modern recommendations plus shared sponsored AdsClient; no broad Pocket removal."),
    ("sync_has_account_and_extension_callers",
     "sync", ("sync_source_vs_fxa_source", "webextension_sync_storage", "ai_window_account_auth"),
     "Sync and FxAccounts are not the same source gate; WebExtension storage and AIWindow account auth are protected."),
    ("upload_policy_and_deletion_must_be_separate",
     "deletion", ("distinct_master_policy_and_upload_preferences",
                  "identifier_rotation_and_deletion_request", "official_build_gate_and_type_specific_upload_optout"),
     "Upload suppression must not erase identifier rotation, queued-ping cleanup or deletion request handling."),
    ("telemetry_native_and_glean_not_transport_only",
     "telemetry", ("native_telemetry_and_pingsender",
                   "glean_separate_bindings", "crashreporter_separate_config"),
     "Local metrics, Glean native bindings and crash reporter are not interchangeable with legacy ping transport."),
    ("telemetry_policy_is_crosschecked_with_deletion",
     "telemetry", ("sender_policy_deletion_request", "browser_preferences_and_privacy_ui"),
     "Telemetry sender, policy/UI and separate deletion flow require a native/loopback guarded integration test."),
)

def check(report: dict, family: str, expected_source: str) -> list[dict]:
    if not isinstance(report, dict):
        raise ValueError("Malformed " + family + " report")
    if report.get("schema_version") != 1:
        raise ValueError("Unrecognized " + family + " audit schema")
    if report.get("source_commit") != expected_source:
        raise ValueError("Cross-source audit mismatch: " + family)
    if report.get("removal_authorized") is not False:
        raise ValueError("Unapproved " + family + " source deletion")
    collection, id_field, known = EXPECTED[family]
    rows = report.get(collection)
    if not isinstance(rows, list) or len(rows) != len(known):
        raise ValueError("Incomplete audited boundaries: " + family)
    names = [row.get(id_field) for row in rows if isinstance(row, dict)]
    if len(names) != len(known) or set(names) != set(known):
        raise ValueError("Unexpected or duplicated audit scope: " + family)
    for row in rows:
        proofs = row.get("evidence")
        if not isinstance(proofs, list) or not proofs:
            raise ValueError("Missing source evidence for " + str(row.get(id_field)))
        if family == "pocket" and row.get("classification") not in (
            "retain", "retain_pending_guard_audit",
            "narrow_optional_pref_only_no_removal",
            "narrow_jsx_opt_in_candidate_not_removal_ready",
        ):
            raise ValueError("Unsafe Pocket classification")
        if family == "sync" and row.get("decision") != "retain":
            raise ValueError("Unsafe Sync classification")
        if family == "telemetry" and row.get("classification") != "retain_protected":
            raise ValueError("Unsafe Telemetry classification")
        for proof in proofs:
            if (not isinstance(proof, dict) or
                not isinstance(proof.get("path"), str) or
                PATH.fullmatch(proof["path"]) is None or
                not isinstance(proof.get("line"), int) or
                isinstance(proof["line"], bool) or proof["line"] < 1 or
                not isinstance(proof.get("anchor"), str) or
                not 1 <= len(proof["anchor"]) <= 256):
                raise ValueError("Unverifiable source anchor in " + family)
    return rows

def combine(reports: dict[str, dict]) -> dict:
    if set(reports) != set(EXPECTED):
        raise ValueError("Expected all four independent source audits")
    commits = [r.get("source_commit") for r in reports.values() if isinstance(r, dict)]
    if len(commits) != 4 or len(set(commits)) != 1 or (
        not isinstance(commits[0], str) or SHA.fullmatch(commits[0]) is None
    ):
        raise ValueError("Audits were not executed at one canonical source SHA")
    source = commits[0]
    checked = {key: check(reports[key], key, source) for key in EXPECTED}
    families = {k: {r[EXPECTED[k][1]]: r for r in rows} for k, rows in checked.items()}
    risks = []
    for slug, family, ids, why in RISKS:
        references = []
        for key in ids:
            row = families[family][key]
            references.append({
                "boundary": key,
                "representative_source_anchor": row["evidence"][0],
            })
        risks.append({
            "risk": slug, "source_audit": family,
            "disposition": "retain_until_specific_guard_and_native_fallback_verified",
            "source_evidence": references, "reason": why,
        })
    return {
        "schema_version": 1,
        "phase": "M3",
        "source_commit": source,
        "mode": "joined_pinned_source_contract_not_dynamic_dependency_graph",
        "independent_source_audit_counts": {k:len(v) for k,v in checked.items()},
        "total_protected_source_boundaries": sum(len(v) for v in checked.values()),
        "high_impact_crosscheck_risks": risks,
        "all_four_source_audits_same_git_commit": True,
        "normal_browser_source_modified": False,
        "native_browser_compiled_or_executed_by_crosscheck": False,
        "generated_runtime_caller_graph_proven": False,
        "actual_network_upload_privacy_proven": False,
        "source_removal_authorized": False,
        "new_package_savings_bytes": None,
        "new_M3_whole_gate_passed": False,
        "next_acceptance_evidence": [
            "Observe native protected fallbacks independently, not only source anchors.",
            "For telemetry, distinguish upload-disabled policy, deletion request and local Glean.",
            "For Sync, preserve account, tab and WebExtension storage consumers.",
            "For Pocket, separately prove legacy top stories, modern recommendations and sponsored paths.",
        ],
    }

def synthetic():
    source = "a" * 40
    example = {"path":"browser/components/moz.build","line":11,"anchor":"MOZ_BUILD_APP"}
    report = {}
    for family, (collection, field, names) in EXPECTED.items():
        rows = []
        for name in names:
            row = {field:name, "evidence":[dict(example)]}
            if family == "pocket": row["classification"]="retain"
            if family == "sync": row["decision"]="retain"
            if family == "telemetry": row["classification"]="retain_protected"
            rows.append(row)
        report[family] = {
            "schema_version":1,"source_commit":source,"removal_authorized":False,
            collection:rows,
        }
    result=combine(report)
    assert result["total_protected_source_boundaries"]==24
    assert len(result["high_impact_crosscheck_risks"])==5
    assert result["new_package_savings_bytes"] is None
    assert result["source_removal_authorized"] is False

    mutations = [
        lambda x: x["pocket"].update(source_commit="b"*40),
        lambda x: x["sync"].update(removal_authorized=True),
        lambda x: x["deletion"].update(schema_version=2),
        lambda x: x["telemetry"].pop("source_boundaries"),
        lambda x: x["pocket"]["live_source_boundaries"][0].update(id="fake_boundary"),
        lambda x: x["sync"]["boundaries"][0].update(decision="remove"),
        lambda x: x["telemetry"]["source_boundaries"][0].update(classification="remove"),
        lambda x: x["pocket"]["live_source_boundaries"][0]["evidence"].clear(),
        lambda x: x["deletion"]["source_boundaries"][0]["evidence"][0].update(path="../steal"),
        lambda x: x["deletion"]["source_boundaries"][0]["evidence"][0].update(line=True),
        lambda x: x["sync"]["boundaries"][0]["evidence"][0].update(anchor=""),
        lambda x: x["pocket"].update(source_commit="c"*64),
    ]
    for index, mutate in enumerate(mutations,1):
        changed=deepcopy(report)
        mutate(changed)
        try: combine(changed)
        except (ValueError, KeyError, TypeError, AssertionError):
            continue
        raise AssertionError("False source safety claim accepted: " + str(index))
    return len(mutations)

def main():
    p=argparse.ArgumentParser()
    for family in EXPECTED:
        p.add_argument("--"+family, type=Path)
    p.add_argument("--output", type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",synthetic(),"malformed, missing and false-removal source fixture rejections")
        if not any(getattr(a,k) for k in EXPECTED) and not a.output:return
    if not all(getattr(a,k) for k in EXPECTED) or a.output is None:
        p.error("All four independent JSON inputs and --output required")
    reports={key:json.loads(getattr(a,key).read_text()) for key in EXPECTED}
    joined=combine(reports)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(joined,indent=2)+"\n",encoding="utf-8")
    print("PASS: matched",joined["source_commit"],"four source audits and",
          joined["total_protected_source_boundaries"],"protected boundaries")
    print("No runtime, package, privacy or deletion claim")

if __name__=="__main__":
    try: main()
    except (ValueError,OSError,TypeError,KeyError,AssertionError) as e:
        print("FAIL M3 four-way protected source boundary crosscheck:",e,file=sys.stderr)
        raise SystemExit(1)
