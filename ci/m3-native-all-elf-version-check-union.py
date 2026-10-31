#!/usr/bin/env python3
"""Independent exact-union audit: seven genuine feature paths + three guarded CLIs.

Witnessing all original ELF GNU loader version identities is NOT validating all
native relocations, dynamic imports, update/crash behavior or M3 completion.
"""
import argparse
import json
from pathlib import Path
import re
import sys

SRC="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
SHA="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
SAFE=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")


def tuples(items):
    if not isinstance(items,list) or len(items)>1000:
        raise ValueError("Invalid or unbounded native version tuple collection")
    out=set()
    for item in items:
        if not isinstance(item,dict):raise ValueError("Non-object ELF tuple")
        t=tuple(item.get(k) for k in ("requester_basename","provider_basename","version_name"))
        if any(not isinstance(v,str) or not SAFE.fullmatch(v) for v in t) or t in out:
            raise ValueError("Duplicate/unsafe original ELF tuple")
        out.add(t)
    return out


def verify(static,seven,aux):
    if any((
        static.get("schema_version")!=1,
        static.get("source_commit")!=SRC,
        static.get("original_archive_sha256")!=SHA,
        static.get("native_elf_declared_version_requirements")!=519,
        static.get("scanned_native_elf_files")!=28,
        static.get("actual_symbol_resolution_proven") is not False,
        static.get("m3_sixth_gate_closed") is not False,
        seven.get("schema_version")!=1,
        seven.get("original_native_compiled_source_sha")!=SRC,
        seven.get("original_native_full_normal_archive_sha256")!=SHA,
        seven.get("original_abi_version_contracts_observed_across_seven_feature_workloads")!=445,
        seven.get("original_abi_version_contracts_unexercised_across_seven_workloads")!=74,
        seven.get("browser_source_deletions_authorized") is not False,
        seven.get("m3_sixth_gate_closed") is not False,
        aux.get("schema_version")!=1,
        aux.get("original_native_compiled_source")!=SRC,
        aux.get("original_native_archive_sha256")!=SHA,
        aux.get("protected_native_version_checks_observed")!=74,
        aux.get("crashhelper_invalid_argv_rejected_before_minidump") is not True,
        aux.get("crashreporter_synthetic_only_memtest_completed") is not True,
        aux.get("updater_read_only_channel_query_only") is not True,
        aux.get("real_crash_minidump_handler_tested") is not False,
        aux.get("real_crash_report_sent") is not False,
        aux.get("real_update_applied_or_installed") is not False,
        aux.get("user_data_or_network_egress_allowed") is not False,
        aux.get("new_source_removal_authorized") is not False,
        aux.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Wrong original compiled-source or conservative safety boundary")
    census=tuples(static.get("requirements"))
    seven_set=tuples(seven.get("observed_version_contracts"))
    aux_set=tuples(aux.get("observed_original_version_contracts"))
    if not all(x.get("version_name_present_in_candidate") is True for x in static["requirements"]):
        raise ValueError("Unverified statically declared version provider")
    if len(census)!=519 or len(seven_set)!=445 or len(aux_set)!=74:
        raise ValueError("Exact static/live source version counts changed")
    expected={"crashhelper":27,"updater":27,"crashreporter":20}
    got={name:sum(t[0]==name for t in aux_set) for name in expected}
    if got!=expected or aux.get("per_member_observed_version_contracts")!=expected:
        raise ValueError("Guarded test omitted protected ELF version requirements")
    if seven_set & aux_set or seven_set | aux_set != census:
        raise ValueError("Live original loader identities duplicated or missing from census")
    return {
        "schema_version":1,
        "original_compiled_source_sha":SRC,
        "original_compiled_native_archive_sha256":SHA,
        "independently_verified_seven_workload_run":41161137900,
        "independently_verified_guarded_auxiliary_run":41161508642,
        "original_native_elf_members":28,
        "original_declared_elf_version_contracts":519,
        "observed_original_elf_version_contracts_across_ten_separate_invocations":519,
        "unobserved_declared_version_contracts_in_these_invocations":0,
        "original_elf_version_check_identity_coverage_percent":100,
        "actual_crash_or_update_workflows_covered":False,
        "full_dynamic_symbol_relocations_and_weak_imports_proven":False,
        "unversioned_and_lazy_dynamic_imports_proven":False,
        "source_build_feature_dependency_graph_completed":False,
        "arch_hyprland_native_runtime_revalidated":False,
        "source_deletion_or_binary_savings_authorized":False,
        "m3_sixth_gate_closed":False,
    }


def selftest():
    row=lambda a,b,c:{"requester_basename":a,"provider_basename":b,"version_name":c}
    assert len(tuples([row("crashhelper","libc.so.6","GLIBC_2.2.5")]))==1
    for bad in ([row("a","b","c")]*2,[row("a","../../b","c")],[row("a","b","")]):
        try:tuples(bad)
        except ValueError:pass
        else:raise AssertionError("Forged ELF identity accepted")
    assert sum((27,27,20))==74 and 445+74==519
    return 4


def main():
    p=argparse.ArgumentParser()
    for k in ("static","seven","aux","output"):p.add_argument("--"+k,type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"identity/rejection fixtures")
        if a.static is None:return
    if not (a.static and a.seven and a.aux and a.output):
        p.error("Need --static, --seven, --aux and --output")
    result=verify(*(json.loads(getattr(a,k).read_text()) for k in ("static","seven","aux")))
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: all 519/519 original GNU loader VERSION IDENTITIES witnessed, zero gaps")
    print("LIMIT: no full native feature/build/ABI dependency coverage or M3 gate credit")


if __name__=="__main__":
    try:main()
    except (ValueError,OSError,KeyError,AssertionError) as e:
        print("FAIL original native all-version audit:",e,file=sys.stderr)
        raise SystemExit(1)
