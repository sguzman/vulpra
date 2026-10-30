#!/usr/bin/env python3
"""Reconcile immutable real native ELF imports with live GNU loader init names.

Input #1: direct DT_NEEDED graph of SHA-256-verified normal native archive.
Input #2: SANITIZED PID-aggregated glibc loader result from same archive.
Never infer dependency edges, dynamic symbol ABI, conditional features or
complete dlopen coverage from overlap of library basenames.
"""
import argparse
import copy
import json
from pathlib import Path
import sys

SOURCE="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"

def validate(elf, runtime):
    if elf.get("schema_version")!=1 or runtime.get("schema_version")!=1:
        raise ValueError("unexpected schema")
    if elf.get("archive_sha256")!=ARCHIVE or runtime.get("old_normal_native_archive_sha256")!=ARCHIVE:
        raise ValueError("source-mismatched ELF and native loader archives")
    if runtime.get("old_normal_native_archive_source")!=SOURCE:
        raise ValueError("native loader trace compiled source mismatch")
    if elf.get("scope")!="direct DT_NEEDED edges for every packaged ELF regular file":
        raise ValueError("unapproved ELF dependency scope")
    if len(elf.get("elf_members",[]))!=28 or elf.get("direct_needed_edges")!=268:
        raise ValueError("incomplete original native ELF inventory")
    edges=elf.get("direct_edges")
    if not isinstance(edges,list) or len(edges)!=268:
        raise ValueError("missing original native ELF direct edges")
    if any(not isinstance(x,dict) or not isinstance(x.get("needed"),str)
           for x in edges):
        raise ValueError("invalid native ELF edge")
    names={x["needed"] for x in edges}
    if len(names)!=50 or elf.get("unique_needed_names")!=50:
        raise ValueError("unexpected ELF direct-needed name inventory")
    packaged=elf.get("packaged_elf_needed_names")
    missing=elf.get("not_packaged_needed_names")
    if not isinstance(packaged,list) or not isinstance(missing,list):
        raise ValueError("missing packaged/host direct dependency partition")
    if len(packaged)!=14 or len(missing)!=36 or set(packaged)&set(missing):
        raise ValueError("invalid packaged versus host direct-needed partition")
    if set(packaged)|set(missing)!=names:
        raise ValueError("ELF direct-needed names not covered by partition")
    observed=runtime.get("observed_loader_init_library_basenames")
    if not isinstance(observed,list) or len(observed)!=94 or len(set(observed))!=94:
        raise ValueError("unsupported actual observed runtime library set")
    if not all(isinstance(name,str) and name and "/" not in name and "\\" not in name
               for name in observed):
        raise ValueError("raw filesystem paths or invalid runtime library names")
    for k in ("libxul_requested_in_real_browser_process",
              "libc_loader_init_observed","real_native_webdriver_workload_passed"):
        if runtime.get(k) is not True:
            raise ValueError("loader not observed in real browser: "+k)
    for k in ("raw_loader_traces_retained",
              "complete_dlopen_graph_proven",
              "unexecuted_feature_routes_proven",
              "complete_dynamic_symbol_and_ABI_resolution_proven",
              "current_main_browser_recompiled",
              "new_source_removal_authorized",
              "whole_m3_feature_dependency_gate_completed"):
        if runtime.get(k) is not False:
            raise ValueError("unsupported native loader completeness claim: "+k)
    if runtime.get("new_compressed_savings_bytes") is not None:
        raise ValueError("unproven native package savings")
    live=set(observed)
    if "libxul.so" not in live or not names<=live:
        raise ValueError("not all direct ELF imported names appeared in native startup")
    if not set(packaged)<=live:
        raise ValueError("a physical packaged library not initialized in native smoke")
    if runtime.get("browser_process_traces_with_libxul",0)<1:
        raise ValueError("no real native libxul PID trace")
    extra=sorted(live-names)
    if len(extra)!=44:
        raise ValueError("unexpected additional host/transitive/runtime library names")
    return {
        "schema_version":1,
        "status":"immutable_static_and_real_loader_basename_reconciliation_passed",
        "actual_compiled_source":SOURCE,
        "original_native_archive_sha256":ARCHIVE,
        "native_elf_members":28,
        "direct_dt_needed_edges":268,
        "distinct_direct_needed_soname_names":50,
        "direct_names_seen_in_some_observed_native_loader_process":len(names&live),
        "all_packaged_direct_needed_names_seen_during_workload":len(set(packaged)&live),
        "packaged_direct_needed_name_total":14,
        "host_external_direct_needed_name_total":36,
        "observed_native_loader_initialized_library_names":len(live),
        "observed_not_in_any_packaged_ELF_direct_needed_names":extra,
        "observed_extra_library_name_count":len(extra),
        "libxul_dynamically_loaded_in_real_browser":True,
        "headless_about_newtab_and_asrouter_workload_passed":True,
        "source_inventory_scans_ever_executed_browser":False,
        "native_runtime_observation_did_execute_browser":True,
        "each_declared_edge_loader_resolution_proven":False,
        "extra_names_attributed_to_dlopen_not_proven":True,
        "complete_conditional_dynamic_dependency_closure":False,
        "full_abi_version_or_symbol_resolution_map":False,
        "ubuntu_ci_is_user_arch_host":False,
        "default_browser_or_user_profile_modified":False,
        "new_source_pruning_authorized":False,
        "new_compressed_savings_bytes":None,
        "sixth_m3_feature_map_gate_closed":False,
    }

def selftest():
    # Exact small fixtures with required cardinality and partitions; mutation
    # count is bounded and does not depend on private/system paths.
    packages=[f"libp{i}.so" for i in range(14)]
    hosts=[f"libh{i}.so" for i in range(36)]
    deps=packages+hosts
    extra=[f"extra{i}.so" for i in range(43)]+["libxul.so"]
    elf={"schema_version":1,"scope":"direct DT_NEEDED edges for every packaged ELF regular file",
         "archive_sha256":ARCHIVE,"elf_members":[{} for _ in range(28)],
         "direct_needed_edges":268,"unique_needed_names":50,
         "direct_edges":[{"needed":deps[i%50]} for i in range(268)],
         "packaged_elf_needed_names":packages,"not_packaged_needed_names":hosts}
    loader={"schema_version":1,"old_normal_native_archive_sha256":ARCHIVE,
        "old_normal_native_archive_source":SOURCE,
        "observed_loader_init_library_basenames":deps+extra,
        "browser_process_traces_with_libxul":2,
        "libxul_requested_in_real_browser_process":True,
        "libc_loader_init_observed":True,
        "real_native_webdriver_workload_passed":True,
        "raw_loader_traces_retained":False,"complete_dlopen_graph_proven":False,
        "unexecuted_feature_routes_proven":False,
        "complete_dynamic_symbol_and_ABI_resolution_proven":False,
        "current_main_browser_recompiled":False,"new_source_removal_authorized":False,
        "whole_m3_feature_dependency_gate_completed":False,
        "new_compressed_savings_bytes":None}
    assert validate(elf,loader)["observed_extra_library_name_count"]==44
    mutations=[
        ("archive_sha256","bad","elf"),
        ("unique_needed_names",49,"elf"),
        ("direct_needed_edges",269,"elf"),
        ("packaged_elf_needed_names",[],"elf"),
        ("old_normal_native_archive_source","different","loader"),
        ("observed_loader_init_library_basenames",deps+extra[:-1]+["/private"],"loader"),
        ("libxul_requested_in_real_browser_process",False,"loader"),
        ("complete_dlopen_graph_proven",True,"loader"),
        ("new_source_removal_authorized",True,"loader"),
        ("new_compressed_savings_bytes",5000,"loader"),
        ("observed_loader_init_library_basenames",deps[:-1]+extra+["rogue.so"],"loader"),
        ("browser_process_traces_with_libxul",0,"loader")
    ]
    for key,bad,where in mutations:
        e=copy.deepcopy(elf)
        l=copy.deepcopy(loader)
        (e if where=="elf" else l)[key]=bad
        try:validate(e,l)
        except ValueError:pass
        else:raise AssertionError("False native/static bridge acceptance: "+key)
    print("PASS: 12 deliberate false source/archive/loader/removal claims rejected")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--elf",type=Path)
    p.add_argument("--loader",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        selftest()
        return
    if not a.elf or not a.loader or not a.output:
        p.error("need exact --elf, --loader and --output")
    e=json.loads(a.elf.read_text())
    l=json.loads(a.loader.read_text())
    report=validate(e,l)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: 50/50 distinct direct names and 14/14 packaged names seen during real native workload")
    print("PASS: 44 extra live library names are NOT misclassified as proven dlopen")
    print("LIMIT: no complete per-edge resolution, ABI, unexecuted feature, Arch, or feature savings proof")

if __name__=="__main__":
    try:main()
    except (ValueError,OSError,AssertionError,KeyError) as e:
        print("FAIL: static/native loader crosswalk:",e,file=sys.stderr)
        raise SystemExit(1)
