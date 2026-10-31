#!/usr/bin/env python3
"""Guarded original compiled ELF non-startup coverage -> pinned moz.build anchors.

A missing loader version check during about:blank is NOT a removable component.
Only literal source declarations under exact historical source are accepted.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys

SOURCE="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
MODULES={
 "crashhelper":(27,[
  ("toolkit/crashreporter/crash_helper/moz.build",'GeckoProgram("crashhelper", linkage=None)'),
  ("toolkit/crashreporter/moz.build",'"crash_helper",')]),
 "updater":(27,[
  ("toolkit/mozapps/update/updater/moz.build",'Program("updater")'),
  ("toolkit/mozapps/update/moz.build",'"updater",')]),
 "libmozinference.so":(24,[
  ("third_party/llama.cpp/moz.build","FINAL_LIBRARY = 'mozinference'"),
  ("toolkit/components/ml/backends/llama/moz.build",'"/third_party/llama.cpp"')]),
 "pingsender":(22,[
  ("toolkit/components/telemetry/pingsender/moz.build",'GeckoProgram("pingsender", linkage=None)'),
  ("toolkit/components/telemetry/moz.build",'"pingsender",')]),
 "vulpra-bin":(21,[
  ("browser/app/moz.build",'GeckoProgram(CONFIG["MOZ_APP_NAME"] + "-bin", linkage=browser_linkage)'),
  ("browser/app/moz.build",'CONFIG["MOZ_APP_NAME"] + "-bin" + CONFIG["BIN_SUFFIX"]')]),
 "crashreporter":(20,[
  ("toolkit/crashreporter/client/app/moz.build",'RustProgram("crashreporter")'),
  ("toolkit/crashreporter/moz.build",'"client/app",')]),
 "libonnxruntime.so":(20,[
  ("toolkit/components/ml/moz.build",'if CONFIG["ONNX_RUNTIME"]:'),
  ("toolkit/components/ml/moz.build",'FINAL_TARGET_FILES += ["%" + CONFIG["ONNX_RUNTIME"]]')]),
 "libclearkey.so":(14,[
  ("media/gmp-clearkey/0.1/moz.build",'GeckoSharedLibrary("clearkey")'),
  ("media/gmp-clearkey/0.1/moz.build",'FINAL_TARGET = "dist/bin/gmp-clearkey/0.1"')]),
 "gfxtest":(8,[
  ("toolkit/xre/gfxtest/moz.build",'Program("gfxtest")'),
  ("toolkit/xre/moz.build",'DIRS += ["gfxtest"]')])
}


def analyze(root, observed):
    sha=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],
                                text=True).strip()
    if sha!=SOURCE:
        raise ValueError("The build anchor checkout is not the exact original Firefox source")
    if any((observed.get("schema_version")!=1,
            observed.get("source_commit")!=SOURCE,
            observed.get("original_archive_sha256")!=ARCHIVE,
            observed.get("static_version_name_contracts")!=519,
            observed.get("observed_original_static_version_checks")!=336,
            observed.get("unobserved_original_static_version_checks")!=183,
            observed.get("raw_loader_paths_or_pids_retained") is not False,
            observed.get("new_source_removal_authorized") is not False,
            observed.get("m3_sixth_gate_closed") is not False)):
        raise ValueError("Not an accepted actual native Wayland observation")
    extras=observed.get("unobserved_original_version_checks")
    if not isinstance(extras,list) or len(extras)!=183:
        raise ValueError("Incomplete bounded unexercised ELF list")
    counts=Counter()
    safe=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
    for row in extras:
        if not isinstance(row,dict) or any(
            not isinstance(row.get(key),str) or not safe.fullmatch(row[key])
            for key in ("requester_basename","provider_basename","version_name")):
            raise ValueError("Unsafe original ELF loader observation")
        counts[row["requester_basename"]]+=1
    if counts!={name:spec[0] for name,spec in MODULES.items()}:
        raise ValueError("Historical inactive source roles changed from real version logs")
    results=[]
    for name,(amount,anchors) in MODULES.items():
        evidence=[]
        for rel,needle in anchors:
            source=(root/rel).resolve()
            if not source.is_relative_to(root.resolve()) or not source.is_file():
                raise ValueError("Unsafe/missing historical source manifest")
            raw=source.read_text(encoding="utf-8")
            if raw.count(needle)!=1:
                raise ValueError("Historical build source anchor absent/duplicated")
            evidence.append({"source_manifest":rel,
                             "line":raw[:raw.index(needle)].count("\n")+1,
                             "literal_build_anchor":needle})
        results.append({
            "original_native_elf_basename":name,
            "original_version_contracts_unexercised_in_this_startup":amount,
            "original_source_build_declaration_anchors":evidence,
            "not_executed_in_one_about_blank_graphical_startup":True,
            "source_removal_proven_safe":False
        })
    return {
        "schema_version":1,
        "original_compiled_browser_source":SOURCE,
        "original_compiled_archive_sha256":ARCHIVE,
        "observed_real_gui_version_check_run":41157865349,
        "unexercised_native_elf_member_count":len(results),
        "unexercised_original_elf_version_contract_count":sum(v["original_version_contracts_unexercised_in_this_startup"] for v in results),
        "map":results,
        "runtime_activation_of_these_modules_proven":False,
        "symbol_bindings_when_features_activate_proven":False,
        "full_abi_and_feature_map_proven":False,
        "no_source_files_deleted":True,
        "source_removal_authorized":False,
        "m3_sixth_gate_closed":False
    }


def selftest():
    assert len(MODULES)==9
    assert sum(x[0] for x in MODULES.values())==183
    assert len({p for _,a in MODULES.values() for p,_ in a})>=9
    assert all(0<v[0]<=30 and all("moz.build" in x for x,_ in v[1])
               for v in MODULES.values())
    return 4


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--original-source",type=Path)
    p.add_argument("--runtime-report",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"source role/total fixture guards")
        if a.original_source is None:return
    if not (a.original_source and a.runtime_report and a.output):
        p.error("--original-source, --runtime-report, --output required")
    report=analyze(a.original_source,json.loads(a.runtime_report.read_text()))
    a.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: exact source-pinned 9 unexercised native ELF members mapped to moz.build anchors")
    print("UNEXERCISED LOADER VERSION CONTRACTS:",report["unexercised_original_elf_version_contract_count"])
    print("LIMIT: never interpret one startup's inactivity as deletion/feature safety")


if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL: historical native ELF role provenance:",e,file=sys.stderr)
        raise SystemExit(1)
