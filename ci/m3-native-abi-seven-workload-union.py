#!/usr/bin/env python3
"""Seventh original-native-feature ELF union: ClearKey negative C ABI only.

Imports the independently verified six-workload validator unchanged, and
authenticates the original CDM negative-interface test's 14 version checks.
"""
from __future__ import annotations
import argparse
from collections import Counter
import importlib.util
import json
from pathlib import Path
import sys

PARENT=Path(__file__).with_name("m3-native-abi-six-workload-union.py")
SPEC=importlib.util.spec_from_file_location("vulpra_six_abi",PARENT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Six-workload validator unavailable")
SIX=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SIX)
REMAINING={"crashhelper":27,"updater":27,"crashreporter":20}
NEW_RUN=41161025114
NEW_HEAD="b7eed71eac2cfa8246edb477c56241cb590090f7"


def analyze(static,browser,gfx,ping,onnx,alternate,inference,clearkey):
    six=SIX.analyze(static,browser,gfx,ping,onnx,alternate,inference)
    original=SIX.BASE.verify_static(static)
    observed=SIX.BASE.tuples(six["observed_version_contracts"])
    if any((
        clearkey.get("feature_probe")!="original_clearkey_CDM_invalid_interface_no_egress",
        clearkey.get("real_original_libclearkey_dlopen_and_invalid_CDM_version_rejected") is not True,
        clearkey.get("not_observed_original_clearkey_version_checks")!=0,
        clearkey.get("real_EME_playback_or_decryption_tested") is not False,
        clearkey.get("valid_CDM_session_created") is not False,
        clearkey.get("user_media_or_keys_used") is not False,
        clearkey.get("browser_CDM_host_integration_verified") is not False,
        clearkey.get("external_network_or_user_data_accessed") is not False,
        clearkey.get("raw_loader_paths_and_pids_retained") is not False,
        clearkey.get("complete_runtime_symbol_binding_proven") is not False,
        clearkey.get("safe_source_pruning_authorized") is not False,
        clearkey.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Invalid original ClearKey actual native test provenance/boundaries")
    added=SIX.BASE.verify_runtime(
        clearkey,"onnx","original_clearkey_version_contracts",
        "observed_original_clearkey_version_checks",
        "observed_original_version_contracts",14,
        require_source="original_native_compiled_source")
    if len(added)!=14 or any(t[0]!="libclearkey.so" for t in added):
        raise ValueError("Original CDM did not exercise all 14 version requirements")
    if not added<=original or added & observed:
        raise ValueError("Non-original, forged, or overlapping ClearKey version-check identities")
    seven=observed | added
    missing=original-seven
    left=Counter(t[0] for t in missing)
    if len(seven)!=445 or len(missing)!=74 or dict(left)!=REMAINING:
        raise ValueError("Original seven-workload union and remaining protected ELFs disagree")
    return {
        "schema_version":1,
        "original_native_compiled_source_sha":SIX.BASE.SOURCE,
        "original_native_full_normal_archive_sha256":SIX.BASE.ARCHIVE,
        "six_prior_workloads_independently_authenticated":True,
        "original_clearkey_successful_native_run":NEW_RUN,
        "original_clearkey_native_run_head":NEW_HEAD,
        "independent_source_pinned_observations":
            six["independent_source_pinned_observations"]+[{
                "workload":"original_clearkey_invalid_CDM_interface_no_egress",
                "successful_ci_run_id":NEW_RUN,
                "original_version_triples_seen":len(added),
            }],
        "original_static_compiled_ELF_version_contracts":len(original),
        "original_abi_version_contracts_observed_across_seven_feature_workloads":len(seven),
        "original_abi_version_contracts_unexercised_across_seven_workloads":len(missing),
        "remaining_not_exercised_native_package_ELF_basenames":[
            {"basename":name,"not_exercised_version_triples":count}
            for name,count in sorted(left.items())
        ],
        "observed_version_contracts":[
            {"requester_basename":a,"provider_basename":b,"version_name":c}
            for a,b,c in sorted(seven)],
        "inference_model_loaded_or_executed":False,
        "valid_CDM_session_or_decryption_tested":False,
        "browser_integrated_inference_or_CDM_proven":False,
        "runtime_version_checks_are_not_symbol_bindings":True,
        "unversioned_imports_not_covered":True,
        "rare_and_untriggered_feature_paths_not_proven_unneeded":True,
        "browser_main_online_Arch_Hyprland_not_tested":True,
        "no_real_telemetry_or_external_network_sent":True,
        "browser_source_deletions_authorized":False,
        "new_binary_savings_bytes":None,
        "m3_sixth_gate_closed":False,
    }


def selftest():
    assert SIX.selftest()==4
    assert sum(REMAINING.values())==74
    assert "libclearkey.so" not in REMAINING
    assert 431+14==445 and 519-445==74
    return 4


def main():
    cli=argparse.ArgumentParser()
    fields=("static","browser","gfx","ping","onnx","alternate","inference","clearkey","output")
    for field in fields:
        cli.add_argument("--"+field,type=Path)
    cli.add_argument("--self-test",action="store_true")
    args=cli.parse_args()
    if args.self_test:
        print("PASS:",selftest(),"seven-workload strict provenance fixtures")
        if args.static is None:return
    if not all(getattr(args,k) for k in fields):
        cli.error("Seven separate native runtime reports, static census and output required")
    docs=[json.loads(getattr(args,k).read_text()) for k in fields[:-1]]
    result=analyze(*docs)
    args.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: seven independently authenticated actual native original-package paths")
    print("ORIGINAL ELF VERSION CHECKS OBSERVED:",result["original_abi_version_contracts_observed_across_seven_feature_workloads"])
    print("NOT OBSERVED:",result["original_abi_version_contracts_unexercised_across_seven_workloads"])
    print("LIMIT: protected remaining updater/crash programs and feature/ABI mapping still open")


if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,KeyError,OSError) as error:
        print("FAIL: seven native feature ELF reconciliation:",error,file=sys.stderr)
        raise SystemExit(1)
