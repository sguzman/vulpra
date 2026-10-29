#!/usr/bin/env python3
"""Strict bounded acceptance of one exact-source Vulpra native link evidence set.

The full native run must succeed separately; this script never builds, loads a
shared library or infers a feature's recoverable bytes. All package hashes and
source identities must agree across independently produced JSON reports.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import json
from pathlib import Path
import re
import sys

HEX=re.compile(r"[0-9a-f]{64}\Z")
COMMIT_SHA=re.compile(r"[0-9a-f]{40}\Z")
def require(cond,message):
    if not cond:raise ValueError(message)
def sha(value):
    return isinstance(value,str) and HEX.fullmatch(value) is not None
def check(config,link,elf,localhost,extension,sidecar,source_sha,run_id):
    require(isinstance(source_sha,str) and COMMIT_SHA.fullmatch(source_sha) is not None,
            "Invalid 40-character Git source commit")
    require(isinstance(run_id,int) and run_id>0,"Invalid build run ID")
    for name,data in (("configuration",config),("link",link),("ELF",elf),
                      ("localhost",localhost),("WebExtension",extension)):
        require(isinstance(data,dict) and data.get("schema_version")==1,
                "Invalid "+name+" evidence schema")
    require(config.get("source_commit")==source_sha,"Configure source SHA mismatch")
    require(link.get("source_commit")==source_sha,"Link source SHA mismatch")
    require(elf.get("source_commit")==source_sha,"ELF source SHA mismatch")
    require(link.get("workflow_run_id")==run_id,"Link workflow run ID mismatch")
    # The generic ELF package scanner does not know its GitHub Actions run ID.
    # Bind it to the ID-pinned linker report by exact source, package SHA-256,
    # and compiled-versus-packaged libxul hash instead. Reject a mismatching
    # run ID if an enriched ELF report actually declares one.
    if "workflow_run_id" in elf:
        require(elf["workflow_run_id"]==run_id,"ELF workflow run ID mismatch")
    require(config.get("type")=="exact_source_configure_only_generated_substitution_snapshot",
            "Missing native configure snapshot provenance")
    require(config.get("configure_executed_in_this_run") is True,
            "Native configure not observed")
    flags=config.get("observed_generated_substs",{})
    for k,v in {"MOZ_BUILD_APP":"browser","MOZ_WIDGET_TOOLKIT":"gtk",
                "MOZ_APP_BASENAME":"Vulpra","MOZ_DEVTOOLS":"all"}.items():
        require(flags.get(k)=={"state":"recorded","value":v},"Protected flag: "+k)
    for k in ("MOZ_SANDBOX","MOZ_WAYLAND","MOZ_X11","MOZ_SERVICES_SYNC","MOZ_NORMANDY"):
        require(flags.get(k)=={"state":"recorded","value":"1"},"Protected native flag: "+k)
    require(flags.get("VULPRA_NO_ASROUTER_PROMOS")=={"state":"empty_string","value":""},
            "Non-default ASRouter experiment detected")
    require(config.get("native_browser_compiled") is False,
            "Phase-local configure snapshot changed its semantics")
    require(config.get("compiled_package_delta_bytes") is None,
            "Source-only configure JSON asserts package savings")
    require(link.get("source_removal_authorized") is False,
            "Unverified source deletion authorized")
    require(link.get("linker_full_map_recorded") is False,
            "Response list falsely represented as full resolved linker map")
    require(link.get("per_feature_native_bytes_attributed") is False,
            "Unverified per-feature byte attribution")
    require(link.get("compressed_package_savings_claimed") is None,
            "Unverified native omission savings claimed")
    require(link.get("built_libxul_matches_packaged_libxul") is True,
            "Native libxul does not hash-match packaged binary")
    response=link.get("libxul_link_input_response",{})
    require(sha(response.get("sha256")),"Link response checksum missing")
    require(isinstance(response.get("entry_count"),int) and
            response["entry_count"]>100,"Implausibly few source linker inputs")
    require(response.get("raw_input_paths_retained_in_report") is False,
            "Raw generated native source input paths unexpectedly retained")
    package=link.get("package",{})
    digest=package.get("package_sha256")
    require(sha(digest) and digest==elf.get("archive_sha256"),
            "Native package and ELF archive digest mismatch")
    require(package.get("package_compressed_bytes")==elf.get("archive_compressed_bytes"),
            "Compressed package file size mismatch")
    require(package.get("packaged_native_loader_order")==link.get("dist_native_loader_order"),
            "Packaged dependency order differs from compiled dist")
    order=link.get("dist_native_loader_order",{})
    names=order.get("ordered_names",[])
    require(isinstance(names,list) and len(names)==len(set(names)) and len(names)>5,
            "Malformed native loader order")
    require("libmozgtk.so" in names and "libmozwayland.so" in names and
            names.index("libmozgtk.so")<names.index("libmozwayland.so") and
            order.get("mozgtk_before_mozwayland") is True,
            "GTK/Wayland load order not retained")
    require(link.get("runtime_passed_after_link_audit") is True,
            "Native runtime acceptance did not complete")
    gates=link.get("runtime_gates",[])
    require(isinstance(gates,list) and len(gates)==4 and
            {"Wayland private Weston","localhost JS navigation",
             "isolated profile and WebExtension","Nimbus check"}==set(gates),
            "Missing native runtime gate")
    lib=package.get("libxul_member",{})
    require(sha(lib.get("sha256")) and lib["sha256"]==link.get("built_libxul_sha256"),
            "Compiled and packaged libxul digest mismatch")
    require(isinstance(lib.get("bytes"),int) and lib["bytes"]>10_000_000,
            "Invalid compiled native libxul size")
    elfs=elf.get("elf_members",[])
    require(len(elfs)>=20 and sum(x.get("name")=="libxul.so" for x in elfs)==1,
            "Missing unique packaged native libxul")
    xul=next(x for x in elfs if x["name"]=="libxul.so")
    require(xul.get("sha256")==lib["sha256"] and xul.get("logical_bytes")==lib["bytes"],
            "ELF metadata does not match packaged libxul")
    require(elf.get("source_removal_authorized") is False and
            elf.get("marginal_compressed_saving_bytes") is None and
            elf.get("host_dependency_resolution_verified") is False,
            "ELF audit asserts unsupported removal/host resolution")
    require(elf.get("all_native_binary_execution_avoided") is True,
            "ELF auditor unexpectedly executed binary")
    pieces=sidecar.strip().split()
    require(len(pieces)==2 and pieces[0]==digest and
            pieces[1]=="vulpra-local-m3-native-link-ci.tar.xz",
            "Package SHA256 sidecar mismatch")
    require(localhost.get("result")=="pass" and localhost.get("sha256")==digest,
            "Localhost runtime exercised different archive")
    for k in ("profile_isolation","screenshot_png_signature",
              "screenshot_png_complete_and_crc_valid"):
        require(localhost.get(k) is True,"Localhost runtime safety failed: "+k)
    require(extension.get("status")=="pass" and
            extension.get("package")=="vulpra-local-m3-native-link-ci.tar.xz",
            "WebExtension runtime exercised different package")
    require(extension.get("javascript_navigation",{}).get("verified") is True,
            "Native JavaScript navigation unverified")
    for k in ("temporary_unsigned_install","content_scripts","background_messaging",
              "storage_local","uninstall"):
        require(extension.get("webextension",{}).get(k) is True,
                "Missing packaged extension acceptance "+k)
    require(extension.get("security",{}).get("original_firefox_profile_preserved") is True and
            extension.get("security",{}).get("temporary_home") is True,
            "Firefox profile isolation not proven")
    require(extension.get("nimbus")=={"store_ready":True,"api_ready":True,
             "access":"CI-only isolated chrome context"},"Nimbus runtime not verified")
    return {"schema_version":1,"status":"passed_full_native_evidence_reconciliation",
            "source_commit":source_sha,"workflow_run_id":run_id,
            "package_sha256":digest,"package_compressed_bytes":package["package_compressed_bytes"],
            "libxul_bytes":lib["bytes"],"libxul_sha256":lib["sha256"],
            "link_response_sha256":response["sha256"],
            "link_response_entry_count":response["entry_count"],
            "native_elf_member_count":len(elfs),
            "native_direct_needed_edges":elf["direct_needed_edges"],
            "GTK_before_Wayland":True,
            "Wayland_JS_WebExtension_Nimbus_passed":True,
            "complete_resolved_linker_symbol_map":False,
            "host_transitive_and_dlopen_dependencies_closed":False,
            "per_feature_native_bytes_recoverable":None,
            "lean_full_source_matched_pair_done":False,
            "compiled_package_savings_bytes":None,
            "additional_source_removal_authorized":False,
            "limitations":["Success of original native workflow separately required, not inferred from JSON alone.",
                           "Compiled source commit is pinned, not automatically latest main.",
                           "Generated response object-list is not a resolved linker symbol map.",
                           "Does not include host ELF transitive dependencies or dlopen.",
                           "No opt-in feature omitted or paired compression comparison."]}

def synthetic():
    sha0="a"*40;sha1="b"*64;sha2="c"*64
    fs={k:{"state":"recorded","value":v} for k,v in
        {"MOZ_BUILD_APP":"browser","MOZ_WIDGET_TOOLKIT":"gtk",
         "MOZ_APP_BASENAME":"Vulpra","MOZ_DEVTOOLS":"all"}.items()}
    for k in ("MOZ_SANDBOX","MOZ_WAYLAND","MOZ_X11","MOZ_SERVICES_SYNC","MOZ_NORMANDY"):
        fs[k]={"state":"recorded","value":"1"}
    fs["VULPRA_NO_ASROUTER_PROMOS"]={"state":"empty_string","value":""}
    cfg={"schema_version":1,"source_commit":sha0,
         "type":"exact_source_configure_only_generated_substitution_snapshot",
         "configure_executed_in_this_run":True,"observed_generated_substs":fs,
         "native_browser_compiled":False,"compiled_package_delta_bytes":None}
    order={"ordered_names":["libnspr4.so","libnss3.so","libmozgtk.so",
             "libmozwayland.so","libxul.so","libssl3.so"],
           "count":6,"mozgtk_before_mozwayland":True}
    lib={"path":"./vulpra/libxul.so","bytes":189486920,"sha256":sha2}
    link={"schema_version":1,"source_commit":sha0,"workflow_run_id":1234,
          "source_removal_authorized":False,"linker_full_map_recorded":False,
          "per_feature_native_bytes_attributed":False,"compressed_package_savings_claimed":None,
          "built_libxul_matches_packaged_libxul":True,"built_libxul_sha256":sha2,
          "libxul_link_input_response":{"sha256":sha1,"entry_count":300,
             "raw_input_paths_retained_in_report":False},
          "package":{"package_sha256":sha1,"package_compressed_bytes":80000000,
             "libxul_member":lib,"packaged_native_loader_order":order},
          "dist_native_loader_order":order,"runtime_passed_after_link_audit":True,
          "runtime_gates":["Wayland private Weston","localhost JS navigation",
                           "isolated profile and WebExtension","Nimbus check"]}
    elf={"schema_version":1,"source_commit":sha0,"workflow_run_id":1234,
         "archive_sha256":sha1,"archive_compressed_bytes":80000000,
         "elf_members":[{"name":"libxul.so","sha256":sha2,"logical_bytes":189486920}]+
          [{"name":"native"+str(i),"sha256":sha2,"logical_bytes":1234} for i in range(22)],
         "source_removal_authorized":False,"marginal_compressed_saving_bytes":None,
         "host_dependency_resolution_verified":False,"all_native_binary_execution_avoided":True,
         "direct_needed_edges":268}
    local={"schema_version":1,"result":"pass","sha256":sha1,"profile_isolation":True,
           "screenshot_png_signature":True,"screenshot_png_complete_and_crc_valid":True}
    ext={"schema_version":1,"status":"pass","package":"vulpra-local-m3-native-link-ci.tar.xz",
         "javascript_navigation":{"verified":True},
         "webextension":{k:True for k in ("temporary_unsigned_install",
                        "content_scripts","background_messaging","storage_local","uninstall")},
         "security":{"original_firefox_profile_preserved":True,"temporary_home":True},
         "nimbus":{"store_ready":True,"api_ready":True,"access":"CI-only isolated chrome context"}}
    return cfg,link,elf,local,ext,sha1+"  vulpra-local-m3-native-link-ci.tar.xz",sha0,1234

def tests():
    arguments=synthetic()
    check(*arguments)
    with_declared_elf_run=deepcopy(arguments)
    with_declared_elf_run[2]["workflow_run_id"]=1234
    check(*with_declared_elf_run)
    cases=[
      lambda c,l,e,o,x,s:l.update(source_commit="b"*40),
      lambda c,l,e,o,x,s:c.update(source_commit="b"*64),
      lambda c,l,e,o,x,s:e.update(workflow_run_id=9999),
      lambda c,l,e,o,x,s:e.update(workflow_run_id="1234"),
      lambda c,l,e,o,x,s:c["observed_generated_substs"]["MOZ_WAYLAND"].update(value=""),
      lambda c,l,e,o,x,s:c["observed_generated_substs"]["VULPRA_NO_ASROUTER_PROMOS"].update(state="absent"),
      lambda c,l,e,o,x,s:l.update(built_libxul_matches_packaged_libxul=False),
      lambda c,l,e,o,x,s:l["package"]["libxul_member"].update(sha256="b"*64),
      lambda c,l,e,o,x,s:l["package"]["packaged_native_loader_order"].update(mozgtk_before_mozwayland=False),
      lambda c,l,e,o,x,s:l.update(runtime_passed_after_link_audit=False),
      lambda c,l,e,o,x,s:l.update(linker_full_map_recorded=True),
      lambda c,l,e,o,x,s:e.update(host_dependency_resolution_verified=True),
      lambda c,l,e,o,x,s:o.update(profile_isolation=False),
      lambda c,l,e,o,x,s:x["webextension"].update(storage_local=False),
      lambda c,l,e,o,x,s:x["nimbus"].update(store_ready=False),
      lambda c,l,e,o,x,s:l.update(compressed_package_savings_claimed=5000),
    ]
    for mutate in cases:
        cfg,link,elf,loc,ext,side,sha0,run=deepcopy(arguments)
        mutate(cfg,link,elf,loc,ext,side)
        try:check(cfg,link,elf,loc,ext,side,sha0,run)
        except ValueError:continue
        raise AssertionError("Falsified same-source native evidence accepted")
    return len(cases)

def main():
    p=argparse.ArgumentParser()
    for name in ("config","link","elf","localhost","webextension","sidecar"):
        p.add_argument("--"+name,type=Path)
    p.add_argument("--source-sha")
    p.add_argument("--run-id",type=int)
    p.add_argument("--self-test",action="store_true")
    p.add_argument("--output",type=Path)
    a=p.parse_args()
    if a.self_test:print("PASS:",tests(),"false native acceptance mutations rejected")
    names=("config","link","elf","localhost","webextension","sidecar")
    if not all(getattr(a,name) for name in names) or not a.source_sha or not a.run_id:
        if a.self_test:return
        p.error("Six evidence paths, --source-sha and --run-id required")
    payload=[getattr(a,n).read_text() for n in names]
    result=check(*(json.loads(s) for s in payload[:5]),payload[5],a.source_sha,a.run_id)
    if a.output:
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: exact-source compiled native configuration, ELF, library checksum and runtime reports agree")
    print("Run:",a.run_id,"source:",a.source_sha,
          "archive bytes:",result["package_compressed_bytes"])
    print("No linker symbol map, false compression savings or new removal")

if __name__=="__main__":
    try:main()
    except (ValueError,OSError,AssertionError,json.JSONDecodeError) as exc:
        print("FAIL source-matched native acceptance:",exc,file=sys.stderr)
        raise SystemExit(1)
