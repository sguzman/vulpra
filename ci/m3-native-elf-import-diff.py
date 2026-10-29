#!/usr/bin/env python3
"""Compare two checksum-pinned native package ELF dependency declarations.

This is static evidence only: identical DT_NEEDED declarations do not imply
identical binaries, equivalent behavior, successful loader resolution or any
amount of compressed/feature savings. No ELF code, ldd or dlopen is executed.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import sys

HEX64=re.compile(r"[0-9a-f]{64}\Z")
HEX40=re.compile(r"[0-9a-f]{40}\Z")
NAME=re.compile(r"[A-Za-z0-9_.+-]{1,128}\Z")
# Some normal ELF members live under versioned subdirectories such as
# ./vulpra/gmp-clearkey/0.1/libclearkey.so. Reject traversal, not nested ELF.
PATH=re.compile(r"\./vulpra/(?:[A-Za-z0-9_+-][A-Za-z0-9_.+-]{0,127}/){0,4}[A-Za-z0-9_+-][A-Za-z0-9_.+-]{0,127}\Z")

def validate_graph(graph):
    if not isinstance(graph,dict) or graph.get("schema_version")!=1:
        raise ValueError("Missing native ELF schema")
    if not isinstance(graph.get("archive_sha256"),str) or not HEX64.fullmatch(graph["archive_sha256"]):
        raise ValueError("Unbound original archive checksum")
    if (graph.get("source_removal_authorized") is not False or
        graph.get("host_dependency_resolution_verified") is not False or
        graph.get("all_native_binary_execution_avoided") is not True):
        raise ValueError("Unsupported source, host or execution claim")
    commit=graph.get("source_commit")
    if commit is not None and (not isinstance(commit,str) or not HEX40.fullmatch(commit)):
        raise ValueError("Malformed native source commit")
    items=graph.get("elf_members")
    if not isinstance(items,list) or not 1<=len(items)<=128:
        raise ValueError("Missing bounded package ELF members")
    by_path={}
    for item in items:
        if not isinstance(item,dict) or not isinstance(item.get("path"),str) or not PATH.fullmatch(item["path"]):
            raise ValueError("Unsafe or missing packaged ELF path")
        name=item["path"]
        if name in by_path:
            raise ValueError("Duplicated native ELF path")
        digest=item.get("sha256")
        if not isinstance(digest,str) or not HEX64.fullmatch(digest):
            raise ValueError("Unbound ELF member SHA-256")
        needed=item.get("needed")
        if not isinstance(needed,list) or len(needed)>128 or any(
            not isinstance(x,str) or not NAME.fullmatch(x) for x in needed
        ) or len(needed)!=len(set(needed)):
            raise ValueError("Malformed ELF direct import declarations")
        soname=item.get("soname")
        if soname is not None and (not isinstance(soname,str) or not NAME.fullmatch(soname)):
            raise ValueError("Malformed native SONAME")
        by_path[name]={"sha256":digest,"soname":soname,"needed":needed}
    if graph.get("direct_needed_edges")!=sum(len(x["needed"]) for x in by_path.values()):
        raise ValueError("ELF edge census disagrees with its members")
    return by_path

def compare(old,new):
    earlier=validate_graph(old)
    current=validate_graph(new)
    names_old=set(earlier)
    names_new=set(current)
    common=names_old & names_new
    needed_changes=sorted(p for p in common if
        earlier[p]["needed"]!=current[p]["needed"] or
        earlier[p]["soname"]!=current[p]["soname"])
    content_changes=sorted(p for p in common if
        earlier[p]["sha256"]!=current[p]["sha256"])
    return {
      "schema_version":1,
      "scope":"two SHA256-pinned native archives' per-file direct DT_NEEDED and SONAME declarations",
      "historical_archive_sha256":old["archive_sha256"],
      "current_archive_sha256":new["archive_sha256"],
      "historical_graph_source_commit":old.get("source_commit"),
      "current_graph_source_commit":new.get("source_commit"),
      "earlier_ELF_member_count":len(earlier),
      "current_ELF_member_count":len(current),
      "earlier_direct_needed_edges":old["direct_needed_edges"],
      "current_direct_needed_edges":new["direct_needed_edges"],
      "removed_ELF_file_paths":sorted(names_old-names_new),
      "added_ELF_file_paths":sorted(names_new-names_old),
      "changed_per_file_DT_NEEDED_or_SONAME":needed_changes,
      "changed_ELF_member_SHA256_paths":content_changes,
      "unchanged_ELF_member_SHA256_count":sum(
          earlier[p]["sha256"]==current[p]["sha256"] for p in common),
      "identical_ELF_payloads_claimed":False,
      "actual_host_loader_resolution_proven":False,
      "symbol_or_ABI_compatibility_proven":False,
      "packaged_binary_executed_by_comparison":False,
      "new_compressed_feature_savings_bytes":None,
      "source_removal_authorized":False,
      "limitations":[
          "Identical ELF import declarations cannot prove identical binary semantics.",
          "Host and plugin/dlopen imports, symbol versions and dynamic loader choice are not resolved.",
          "Different source/packaging builds cannot isolate per-feature compressed savings.",
          "Only the upstream native run, not this static metadata comparison, verifies runtime.",
      ]
    }

def selftest():
    def graph(sha):
        return {"schema_version":1,"archive_sha256":sha*64,
                "source_removal_authorized":False,
                "host_dependency_resolution_verified":False,
                "all_native_binary_execution_avoided":True,
                "direct_needed_edges":1,"elf_members":[
                    {"path":"./vulpra/libxul.so","sha256":"c"*64,
                     "soname":"libxul.so","needed":["libc.so.6"]}]}
    a,b=graph("a"),graph("b")
    assert PATH.fullmatch("./vulpra/gmp-clearkey/0.1/libclearkey.so")
    assert not PATH.fullmatch("./vulpra/../libxul.so")
    assert not PATH.fullmatch("./vulpra/gmp-clearkey/../../libxul.so")
    b["source_commit"]="1"*40
    report=compare(a,b)
    assert report["changed_per_file_DT_NEEDED_or_SONAME"]==[]
    assert report["changed_ELF_member_SHA256_paths"]==[]
    assert report["historical_graph_source_commit"] is None
    assert report["current_graph_source_commit"]=="1"*40
    variant=graph("b")
    variant["elf_members"][0]["sha256"]="d"*64
    assert compare(a,variant)["changed_ELF_member_SHA256_paths"]==["./vulpra/libxul.so"]
    variant["elf_members"][0]["needed"]=["libm.so.6"]
    assert compare(a,variant)["changed_per_file_DT_NEEDED_or_SONAME"]==["./vulpra/libxul.so"]
    malformed=[]
    from copy import deepcopy
    for field,value in [("archive_sha256","a"*40),("source_removal_authorized",True),
                        ("host_dependency_resolution_verified",True),("all_native_binary_execution_avoided",False),
                        ("source_commit","nope"),("direct_needed_edges",2)]:
        z=deepcopy(a);z[field]=value;malformed.append(z)
    for field,value in [("path","../libxul.so"),("sha256","f"*40),
                        ("needed",["../bad.so"]),("soname","../bad")]:
        z=deepcopy(a);z["elf_members"][0][field]=value;malformed.append(z)
    z=deepcopy(a);z["elf_members"].append(deepcopy(z["elf_members"][0]));malformed.append(z)
    for fake in malformed:
        try: compare(fake,b)
        except ValueError: continue
        raise AssertionError("Malformed or fabricated ELF dependency graph accepted")
    return len(malformed)+4

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--historical",type=Path)
    p.add_argument("--current",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"ELF import-diff schema and anti-tamper fixtures")
        if not a.historical and not a.current and not a.output:return
    if not (a.historical and a.current and a.output):
        p.error("--historical, --current and --output required")
    old=json.loads(a.historical.read_text())
    new=json.loads(a.current.read_text())
    result=compare(old,new)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: two pinned archive per-ELF import declarations compared, not executed")
    print("NEEDED CHANGES:",len(result["changed_per_file_DT_NEEDED_or_SONAME"]))
    print("ELF CONTENT CHANGES:",len(result["changed_ELF_member_SHA256_paths"]))
    print("ADDED/REMOVED:",len(result["added_ELF_file_paths"]),len(result["removed_ELF_file_paths"]))
    print("No loader, ABI, package delta or safe-removal claim")

if __name__=="__main__":
    try:main()
    except (ValueError,OSError,AssertionError) as e:
        print("FAIL bounded M3 native ELF import diff:",e,file=sys.stderr)
        raise SystemExit(1)
