#!/usr/bin/env python3
"""Bounded readelf-only host transitive DT_NEEDED file-presence crosswalk.

Uses the immutable historical packaged ELF graph and rechecks the Ubuntu CI
host library cache. Does not run package code, invoke ldd/dlopen, prove loader
search order, prove symbol compatibility, or inspect the user's Arch machine.
"""
from __future__ import annotations

import argparse
from collections import deque
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

HERE=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location("vulpra_host_cache",HERE/"m3-native-host-dependency-preflight.py")
HOST=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HOST)
NEEDED=re.compile(r"\(NEEDED\)\s+Shared library: \[([^\]\r\n]+)\]")
MAX_NODES=512
MAX_EDGES=2048
MAX_DEPTH=16

def parse_dynamic(text):
    if not isinstance(text,str) or len(text)>8_000_000:
        raise ValueError("Oversized host ELF dynamic section")
    names=NEEDED.findall(text)
    if len(names)!=len(set(names)):
        raise ValueError("Duplicate DT_NEEDED in host ELF")
    if any(not HOST.NAME.fullmatch(name) for name in names):
        raise ValueError("Unsafe host ELF dependency name")
    return names

def host_deps(path):
    p=subprocess.run(["readelf","-dW",str(path)],capture_output=True,
                     text=True,timeout=25,check=False)
    if p.returncode:
        raise ValueError("Cannot inspect host ELF dynamic section")
    return parse_dynamic(p.stdout)

def trace(graph,ldconfig_output):
    original=HOST.validate_graph(graph)
    # The underlying ELF scanner records source_commit only for a
    # source-pinned native run. Historical archived ELF graphs did not carry
    # one: never stamp their host map with a hardcoded unrelated commit.
    source_commit=graph.get("source_commit")
    if source_commit is not None and (
        not isinstance(source_commit,str) or
        re.fullmatch(r"[0-9a-f]{40}",source_commit) is None
    ):
        raise ValueError("Malformed source-compiled commit provenance")
    cache=HOST.cache_rows(ldconfig_output)
    roots=set(original)
    bundled=set(graph["packaged_elf_needed_names"])
    queue=deque((name,0) for name in original)
    visited={}
    edges=[]
    while queue:
        name,depth=queue.popleft()
        if name in visited:
            continue
        if len(visited)>=MAX_NODES or depth>MAX_DEPTH:
            raise ValueError("Host dependency graph exceeded read-only bounds")
        candidates=[Path(path) for path in cache.get(name,[])
                    if HOST.host_elf64(Path(path))]
        if candidates:
            chosen=candidates[0]
            children=host_deps(chosen)
            state="host_x86_64_ELF_declared_dependency_file_present"
        else:
            chosen=None
            children=[]
            state="no_matching_ldconfig_host_ELF_file_candidate"
        visited[name]={
            "name":name,"depth":depth,"root_external_direct_from_package":name in roots,
            "state":state,"example_host_file":str(chosen) if chosen else None,
            "needed_by_host_file":children,
        }
        for child in children:
            if len(edges)>=MAX_EDGES:
                raise ValueError("Host dependency edges exceeded read-only bounds")
            edges.append({"requester":name,"needed":child})
            if child not in visited:
                queue.append((child,depth+1))
    count=sum(v["state"]=="host_x86_64_ELF_declared_dependency_file_present"
              for v in visited.values())
    missing=sorted(name for name,v in visited.items()
                   if v["state"]=="no_matching_ldconfig_host_ELF_file_candidate")
    return {
        "schema_version":1,
        "source_archive_sha256":graph["archive_sha256"],
        "source_archive_original_compiler_commit":source_commit,
        "source_compiler_commit_in_graph_verified":source_commit is not None,
        "CI_environment":"ubuntu-24.04-x86_64",
        "original_package_external_direct_needs":len(roots),
        "host_direct_and_transitive_unique_names":len(visited),
        "names_with_arch_compatible_ldconfig_file_candidates":count,
        "names_without_ldconfig_file_candidate":missing,
        "host_transitive_direct_DT_NEEDED_edges":len(edges),
        "max_host_dependency_depth_observed":max(v["depth"] for v in visited.values()),
        "dependency_nodes":list(visited.values()),
        "dependency_edges":edges,
        "original_package_ELF_executed":False,
        "host_ELF_executed":False,
        "ldd_or_dlopen_invoked":False,
        "actual_loader_resolution_or_symbol_versions_verified":False,
        "target_Arch_workstation_verified":False,
        "compiled_feature_savings_bytes":None,
        "source_removal_authorized":False,
        "limitations":[
            "Host library file-name presence and ELF architecture are not ABI/symbol-version proof.",
            "ldconfig cache lookup is not actual RPATH/RUNPATH, loader choice or namespace resolution.",
            "Includes only linked DT_NEEDED names, not dlopen/plugin loads or data dependencies.",
            "Host cache represents only this Ubuntu runner, not the user's Arch Linux workstation.",
            "Bounded metadata graph; never executes native libraries, compiles browser or authorizes removal.",
        ],
    }

def selftest():
    assert parse_dynamic("0x00000001 (NEEDED) Shared library: [libc.so.6]\n")==["libc.so.6"]
    assert parse_dynamic("Dynamic section at offset 0 has 0 entries:\n")==[]
    bad=[
      "0x1 (NEEDED) Shared library: [../evil]\n",
      "0x1 (NEEDED) Shared library: [libc.so.6]\n0x1 (NEEDED) Shared library: [libc.so.6]\n",
      "0x1 (NEEDED) Shared library: [/lib/c.so]\n",
    ]
    for data in bad:
        try: parse_dynamic(data)
        except ValueError: continue
        raise AssertionError("Unsafe dynamic link entry accepted")
    graph={
        "schema_version":1,
        "archive_sha256":"a"*64,
        "source_removal_authorized":False,
        "host_dependency_resolution_verified":False,
        "all_native_binary_execution_avoided":True,
        "not_packaged_needed_names":["libnotreal.so.1"],
        "packaged_elf_needed_names":["libxul.so"],
    }
    r=trace(graph,"")
    assert r["original_package_external_direct_needs"]==1
    assert r["host_direct_and_transitive_unique_names"]==1
    assert r["names_without_ldconfig_file_candidate"]==["libnotreal.so.1"]
    assert r["source_removal_authorized"] is False
    assert r["source_archive_original_compiler_commit"] is None
    assert r["source_compiler_commit_in_graph_verified"] is False
    pinned=dict(graph,source_commit="b"*40)
    tagged=trace(pinned,"")
    assert tagged["source_archive_original_compiler_commit"]=="b"*40
    assert tagged["source_compiler_commit_in_graph_verified"] is True
    for forged in ("b"*64,"oops",True):
        try:trace(dict(graph,source_commit=forged),"")
        except ValueError:pass
        else:raise AssertionError("False native source commitment accepted")
    return 12

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--graph",type=Path)
    ap.add_argument("--output",type=Path)
    ap.add_argument("--self-test",action="store_true")
    args=ap.parse_args()
    if args.self_test:
        print("PASS:",selftest(),"static host-transitive graph safety fixtures")
    if args.graph is None:
        if args.self_test:return
        ap.error("--graph and --output required")
    if args.output is None:
        ap.error("--output required")
    with args.graph.open(encoding="utf-8") as f:
        graph=json.load(f)
    output=subprocess.run(["/sbin/ldconfig","-p"],capture_output=True,
                          text=True,timeout=25,check=True).stdout
    report=trace(graph,output)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: bounded host DT_NEEDED name-presence graph, never native binary execution")
    print("ROOT EXTERNAL NAMES:",report["original_package_external_direct_needs"])
    print("HOST NAMES:",report["host_direct_and_transitive_unique_names"])
    print("HOST ELF FILE CANDIDATES:",report["names_with_arch_compatible_ldconfig_file_candidates"])
    print("NO HOST CACHE CANDIDATES:",len(report["names_without_ldconfig_file_candidate"]))
    print("HOST DIRECT EDGES:",report["host_transitive_direct_DT_NEEDED_edges"])
    print("No actual dynamic-loader resolution, symbol version, dlopen, Arch or saving claim.")

if __name__=="__main__":
    try:main()
    except (OSError,subprocess.CalledProcessError,subprocess.TimeoutExpired,
            ValueError,AssertionError) as e:
        print("FAIL M3 bounded host transitive map:",e,file=sys.stderr)
        raise SystemExit(1)
