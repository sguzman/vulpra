#!/usr/bin/env python3
"""Source-pinned real native ELF version-check union across four workloads.

Only compares independently CI-authenticated runtime artifacts with the same
original archived compiled source/ELF VERNEED baseline. A witnessed loader
version check in one feature path is NOT complete symbol/feature/ABI coverage.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
import json
from pathlib import Path
import re
import sys

SOURCE="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
NAME=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
UNSEEN={
    "crashhelper":27,
    "updater":27,
    "libmozinference.so":24,
    "vulpra-bin":21,
    "crashreporter":20,
    "libclearkey.so":14
}


def tuples(rows,unique=True):
    if not isinstance(rows,list) or len(rows)>2000:
        raise ValueError("Missing or unbounded source evidence tuples")
    found=set()
    for row in rows:
        if not isinstance(row,dict):
            raise ValueError("Invalid ELF version tuple")
        triple=tuple(row.get(key) for key in
                     ("requester_basename","provider_basename","version_name"))
        if any(not isinstance(x,str) or not NAME.fullmatch(x) for x in triple):
            raise ValueError("Unsafe raw paths/invalid original ELF names")
        if unique and triple in found:
            raise ValueError("Duplicate source-matched version tuple")
        found.add(triple)
    return found


def verify_static(s):
    if not isinstance(s,dict) or any((
        s.get("schema_version")!=1,
        s.get("source_commit")!=SOURCE,
        s.get("original_archive_sha256")!=ARCHIVE,
        s.get("scanned_native_elf_files")!=28,
        s.get("native_elf_declared_version_requirements")!=519,
        s.get("candidate_version_name_absent_count")!=0,
        s.get("candidate_version_name_unavailable_count")!=0,
        s.get("native_binaries_executed") is not False,
        s.get("actual_symbol_resolution_proven") is not False,
        s.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Original statically declared archive or candidate contract unverifiable")
    result=tuples(s.get("requirements"))
    if len(result)!=519 or any(
        x.get("version_name_present_in_candidate") is not True
        for x in s["requirements"]
    ):
        raise ValueError("Original 519 static library-version tuples are not valid")
    return result


def verify_runtime(data, label, total_key, observed_key, observed_rows,
                   expected_static, require_source=None):
    if not isinstance(data,dict) or data.get("schema_version")!=1:
        raise ValueError("Invalid actual feature runtime report")
    if require_source is not None and data.get(require_source)!=SOURCE:
        raise ValueError("Feature activation compiled-source mismatch")
    if data.get("original_native_archive_sha256" if label in ("gfxtest","pingsender","onnx")
                else "original_archive_sha256")!=ARCHIVE:
        raise ValueError("Feature activation binary archive mismatch")
    if data.get(total_key)!=expected_static:
        raise ValueError("Feature's static version requirement count changed")
    n=data.get(observed_key)
    if not isinstance(n,int) or isinstance(n,bool) or n<=0 or n>expected_static:
        raise ValueError("Invalid count of real loader version checks")
    observed=tuples(data.get(observed_rows))
    if len(observed)!=n:
        raise ValueError("Real check count disagrees with observed source tuples")
    return observed


def analyze(static,browser,gfx,ping,onnx):
    original=verify_static(static)
    if any((
        browser.get("source_commit")!=SOURCE,
        browser.get("browser_libxul_pid_trace_count")!=3,
        browser.get("static_version_name_contracts")!=519,
        browser.get("unobserved_original_static_version_checks")!=183,
        browser.get("new_source_removal_authorized") is not False,
        browser.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Original successful 10-second browser runtime checks not authenticated")
    b=verify_runtime(browser,"browser","static_version_name_contracts",
                     "observed_original_static_version_checks",
                     "observed_original_version_checks",519)
    if len(b)!=336:
        raise ValueError("Different original browser startup workload than accepted")
    if any((
        gfx.get("real_wayland_gfxtest_connected_and_completed") is not True,
        gfx.get("successful_gpu_acceleration_proven") is not False,
        gfx.get("new_source_removal_authorized") is not False,
        gfx.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Native gfx evidence not from successful bounded test")
    g=verify_runtime(gfx,"gfxtest","original_gfxtest_static_version_contracts",
                     "original_gfxtest_version_contracts_observed",
                     "observed_original_version_contracts",8,
                     require_source="original_compiled_source")
    if len(g)!=8 or any(x[0]!="gfxtest" for x in g):
        raise ValueError("Missing/incorrect gfx Wayland source feature activation")
    if any((
        ping.get("real_telemetry_sent") is not False,
        ping.get("network_egress_allowed") is not False,
        ping.get("synthetic_payload_deleted_only_after_local_success") is not True,
        ping.get("safe_source_removal_authorized") is not False,
        ping.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Synthetic pingsender network isolation not proven")
    p=verify_runtime(ping,"pingsender","original_pingsender_static_version_contracts",
                     "original_pingsender_static_version_checks_observed",
                     "observed_original_version_contracts",22,
                     require_source="original_native_source")
    if len(p)!=22 or any(x[0]!="pingsender" for x in p):
        raise ValueError("Missing/incorrect synthetic no-egress helper test")
    if any((
        onnx.get("real_onxx_native_dlopen_and_c_api_version_invoked") is not True,
        onnx.get("model_loaded_or_inference_performed") is not False,
        onnx.get("browser_ml_feature_integrated_and_passed") is not False,
        onnx.get("external_network_or_user_data_exposed") is not False,
        onnx.get("safe_original_source_removal_authorized") is not False,
        onnx.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Untrusted original ONNX C ABI activation")
    o=verify_runtime(onnx,"onnx","original_onnxruntime_version_contracts",
                     "observed_original_onnxruntime_version_checks",
                     "observed_original_version_contracts",20,
                     require_source="original_native_compiled_source")
    if len(o)!=20 or any(x[0]!="libonnxruntime.so" for x in o):
        raise ValueError("Original ONNX C API source-version contract was not fully exercised")
    for label,rows in (("browser",b),("gfxtest",g),("pingsender",p),("onnx",o)):
        if not rows<=original:
            raise ValueError("Real "+label+" version checks are not in exact original static package")
    if b & g or b & p or g & p or b & o or g & o or p & o:
        raise ValueError("Overlapping workload ABI triples counted as novel coverage")
    total=b|g|p|o
    missing=original-total
    absent=Counter(x[0] for x in missing)
    if dict(absent)!=UNSEEN:
        raise ValueError("Original unexercised member list changed unexpectedly")
    if len(total)!=386 or len(missing)!=133:
        raise ValueError("Wrong verified runtime version coverage union")
    return {
        "schema_version":1,
        "original_native_compiled_source_sha":SOURCE,
        "original_native_full_normal_archive_sha256":ARCHIVE,
        "independent_source_pinned_observations":[
            {"workload":"private_Weston_browser_startup_offline",
             "successful_ci_run_id":41157865349,"original_version_triples_seen":len(b)},
            {"workload":"original_gfxtest_Wayland_EGL_roundtrip",
             "successful_ci_run_id":41158839352,"original_version_triples_seen":len(g)},
            {"workload":"original_pingsender_synthetic_local_POST_no_egress",
             "successful_ci_run_id":41159158976,"original_version_triples_seen":len(p)},
            {"workload":"original_onnxruntime_C_API_base_version_no_egress",
             "successful_ci_run_id":41159617600,"original_version_triples_seen":len(o)}
        ],
        "original_static_compiled_ELF_version_contracts":len(original),
        "original_abi_version_contracts_observed_across_four_feature_workloads":len(total),
        "original_abi_version_contracts_unexercised_across_four_workloads":len(missing),
        "remaining_not_exercised_native_package_ELF_basenames":[
            {"basename":name,"not_exercised_version_triples":count}
            for name,count in sorted(absent.items())
        ],
        "observed_version_contracts":[
            {"requester_basename":a,"provider_basename":b,"version_name":c}
            for a,b,c in sorted(total)
        ],
        "runtime_version_checks_are_not_symbol_bindings":True,
        "unversioned_imports_not_covered":True,
        "rare_and_untriggered_feature_paths_not_proven_unneeded":True,
        "browser_main_online_Arch_Hyprland_not_tested":True,
        "no_real_telemetry_or_external_network_sent":True,
        "browser_source_deletions_authorized":False,
        "new_binary_savings_bytes":None,
        "m3_sixth_gate_closed":False
    }


def selftest():
    # Verify malicious duplicate, path, and conflicting tuples are rejected
    valid=[{"requester_basename":"gfxtest",
            "provider_basename":"libc.so.6",
            "version_name":"GLIBC_2.2.5"}]
    assert len(tuples(valid))==1
    for bad in (
        valid*2,
        [dict(valid[0],version_name="../bad")],
        [dict(valid[0],provider_basename="/tmp/library")],
        [dict(valid[0],requester_basename="")] ,
    ):
        try:tuples(bad)
        except ValueError:pass
        else:raise AssertionError("False browser-native loader tuple accepted")
    assert sum(UNSEEN.values())==133
    return 5


def main():
    p=argparse.ArgumentParser()
    for field in ("static","browser","gfx","ping","onnx","output"):
        p.add_argument("--"+field,type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"strict native ELF ABI tuple/provenance fixtures")
        if a.static is None:return
    if not all(getattr(a,k) for k in ("static","browser","gfx","ping","onnx","output")):
        p.error("Need --static, --browser, --gfx, --ping, --onnx and --output")
    docs=[json.loads(getattr(a,k).read_text()) for k in ("static","browser","gfx","ping","onnx")]
    result=analyze(*docs)
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: independently verified real source-matched GUI/helper ABI version coverage union")
    print("ORIGINAL DECLARED VERSION CONTRACTS:",result["original_static_compiled_ELF_version_contracts"])
    print("OBSERVED ACROSS FOUR REAL EXECUTED PATHS:",
          result["original_abi_version_contracts_observed_across_four_feature_workloads"])
    print("NOT OBSERVED ACROSS THESE FOUR PATHS:",
          result["original_abi_version_contracts_unexercised_across_four_workloads"])
    print("LIMIT: 133 not exercised is not permission to prune")
if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,OSError,KeyError) as ex:
        print("FAIL original compiled ABI workload union:",ex,file=sys.stderr)
        raise SystemExit(1)
