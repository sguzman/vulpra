#!/usr/bin/env python3
"""Independent 6th-workload reconciliation of real compiled source ELF checks.

Reuses the already accepted five-workload contract validator without changing
its source-pinned historical evidence or claiming that ML inference was tested.
"""
from __future__ import annotations

import argparse
from collections import Counter
import importlib.util
import json
from pathlib import Path
import sys

PARENT = Path(__file__).with_name("m3-native-abi-feature-workload-union.py")
SPEC = importlib.util.spec_from_file_location("vulpra_five_abi", PARENT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Original five-workload validator was not found")
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
REMAINING = {"crashhelper": 27, "updater": 27, "crashreporter": 20, "libclearkey.so": 14}
NEW_RUN = 41160836283
NEW_HEAD = "3b90b825f43e34e022592fe10b1ed6bc676f1a59"


def analyze(static, browser, gfx, ping, onnx, alternate, inference):
    five = BASE.analyze(static, browser, gfx, ping, onnx, alternate)
    original = BASE.verify_static(static)
    old = BASE.tuples(five["observed_version_contracts"])
    if any((
        inference.get("feature_probe") != "original_mozinference_llama_backend_C_API_no_egress",
        inference.get("real_original_libmozinference_dlopen_and_llama_api_invoked") is not True,
        inference.get("not_observed_original_mozinference_version_checks") != 0,
        inference.get("model_loaded_or_inference_performed") is not False,
        inference.get("browser_ml_integration_tested") is not False,
        inference.get("external_network_or_user_profile_accessed") is not False,
        inference.get("raw_loader_paths_and_pids_retained") is not False,
        inference.get("complete_runtime_symbol_binding_proven") is not False,
        inference.get("safe_source_pruning_authorized") is not False,
        inference.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Original compiled isolated inference test has invalid guarantees")
    added = BASE.verify_runtime(
        inference, "onnx", "original_mozinference_version_contracts",
        "observed_original_mozinference_version_checks",
        "observed_original_version_contracts", 24,
        require_source="original_native_compiled_source"
    )
    if len(added) != 24 or any(x[0] != "libmozinference.so" for x in added):
        raise ValueError("24 original inference library ELF checks were not all observed")
    if not added <= original or old & added:
        raise ValueError("Forged, non-original or double-counted inference loader checks")
    six = old | added
    missing = original - six
    absent = Counter(x[0] for x in missing)
    if len(six) != 431 or len(missing) != 88 or dict(absent) != REMAINING:
        raise ValueError("Original six-workload coverage or remaining modules disagree")
    return {
        "schema_version": 1,
        "original_native_compiled_source_sha": BASE.SOURCE,
        "original_native_full_normal_archive_sha256": BASE.ARCHIVE,
        "five_prior_workloads_independently_authenticated": True,
        "original_mozinference_successful_native_run": NEW_RUN,
        "original_mozinference_native_run_head": NEW_HEAD,
        "independent_source_pinned_observations":
            five["independent_source_pinned_observations"] + [{
                "workload": "original_mozinference_production_C_API_no_egress",
                "successful_ci_run_id": NEW_RUN,
                "original_version_triples_seen": len(added),
            }],
        "original_static_compiled_ELF_version_contracts": len(original),
        "original_abi_version_contracts_observed_across_six_feature_workloads": len(six),
        "original_abi_version_contracts_unexercised_across_six_workloads": len(missing),
        "remaining_not_exercised_native_package_ELF_basenames": [
            {"basename": name, "not_exercised_version_triples": count}
            for name, count in sorted(absent.items())
        ],
        "observed_version_contracts": [
            {"requester_basename": a, "provider_basename": b, "version_name": c}
            for a, b, c in sorted(six)
        ],
        "inference_model_loaded": False,
        "browser_integrated_inference_proven": False,
        "runtime_version_checks_are_not_symbol_bindings": True,
        "unversioned_imports_not_covered": True,
        "rare_and_untriggered_feature_paths_not_proven_unneeded": True,
        "browser_main_online_Arch_Hyprland_not_tested": True,
        "no_real_telemetry_or_external_network_sent": True,
        "browser_source_deletions_authorized": False,
        "new_binary_savings_bytes": None,
        "m3_sixth_gate_closed": False,
    }


def selftest():
    assert BASE.selftest() == 5
    assert sum(REMAINING.values()) == 88
    assert set(REMAINING).isdisjoint({"libmozinference.so"})
    assert 407 + 24 == 431 and 519 - 431 == 88
    for forged in (
        [{"requester_basename": "libmozinference.so", "provider_basename": "/root/p",
          "version_name": "GLIBC_2.2.5"}],
        [{"requester_basename": "libmozinference.so", "provider_basename": "libc.so.6",
          "version_name": "../bad"}],
    ):
        try:
            BASE.tuples(forged)
        except ValueError:
            pass
        else:
            raise AssertionError("Forged inference-version triple accepted")
    return 4


def main():
    cli = argparse.ArgumentParser()
    fields = ("static", "browser", "gfx", "ping", "onnx", "alternate", "inference", "output")
    for field in fields:
        cli.add_argument("--" + field, type=Path)
    cli.add_argument("--self-test", action="store_true")
    args = cli.parse_args()
    if args.self_test:
        print("PASS:", selftest(), "six-workload union adversarial/provenance fixtures")
        if args.static is None:
            return
    if not all(getattr(args, x) for x in fields):
        cli.error("All six runtime reports, original static census and output are required")
    docs = [json.loads(getattr(args, x).read_text()) for x in fields[:-1]]
    result = analyze(*docs)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: six original compiled native feature workloads reconciled")
    print("OBSERVED:", result["original_abi_version_contracts_observed_across_six_feature_workloads"])
    print("UNOBSERVED:", result["original_abi_version_contracts_unexercised_across_six_workloads"])
    print("LIMIT: no full inference or M3 acceptance gate credit")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, AssertionError, KeyError, OSError) as error:
        print("FAIL: source-pinned six-workload ELF evidence:", error, file=sys.stderr)
        raise SystemExit(1)
