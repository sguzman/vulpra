#!/usr/bin/env python3
"""Authenticated original-browser runtime LD_DEBUG=versions versus static VERNEED.

Runtime glibc version checks are not proof of relocations, bindings, exhaustive
lazy feature routes, independent Bash/browser ownership, or safe source removal.
"""
import argparse
import json
from pathlib import Path
import re
import sys

SOURCE="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
NAME=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
PID=re.compile(r"m3-loader\.[0-9]+\Z")
CHECK=re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")
INIT=re.compile(r"calling init:\s+(\S+)")


def base(text):
    value=text.rsplit("/",1)[-1]
    if not NAME.fullmatch(value):
        raise ValueError("Unsafe or invalid loader basename")
    return value


def expected(report):
    if not isinstance(report,dict) or any((
        report.get("schema_version") != 1,
        report.get("source_commit") != SOURCE,
        report.get("original_archive_sha256") != ARCHIVE,
        report.get("scanned_native_elf_files") != 28,
        report.get("native_elf_declared_version_requirements") != 519,
        report.get("actual_symbol_resolution_proven") is not False,
        report.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Unverified original static version contract")
    records=report.get("requirements")
    if not isinstance(records,list) or len(records)!=519:
        raise ValueError("Missing original ELF VERNEED requirements")
    tuples=set()
    for record in records:
        if not isinstance(record,dict) or record.get("version_name_present_in_candidate") is not True:
            raise ValueError("Unmatched/untrusted ELF static version report")
        triple=tuple(record.get(key) for key in (
            "requester_basename","provider_basename","version_name"))
        if any(not isinstance(s,str) or not NAME.fullmatch(s) for s in triple):
            raise ValueError("Raw path or unsafe static name")
        if triple in tuples:
            raise ValueError("Duplicate original static version requirement")
        tuples.add(triple)
    return tuples


def compare(folder, original):
    files=[p for p in folder.iterdir() if p.is_file() and PID.fullmatch(p.name)]
    if not 1<=len(files)<=80:
        raise ValueError("Missing/unbounded real PID loader traces")
    observed=set()
    other=set()
    genuine=0
    for file in files:
        size=file.stat().st_size
        if not 0<size<=18000000:
            raise ValueError("Empty/oversized runtime loader file")
        lines=file.read_text(encoding="utf-8",errors="replace").splitlines()
        if not any((m:=INIT.search(line)) and base(m.group(1))=="libxul.so" for line in lines):
            continue
        genuine+=1
        checks=0
        for line in lines:
            m=CHECK.search(line)
            if not m: continue
            triple=(base(m.group(3)),base(m.group(2)),base(m.group(1)))
            if triple in original:
                observed.add(triple)
                checks+=1
            else:
                other.add(triple)
        if checks==0:
            raise ValueError("Real libxul browser had no matching static version checks")
    if genuine==0 or not observed:
        raise ValueError("No real browser glibc-loader version observation")
    def rows(values):
        return [{"requester_basename":r,"provider_basename":p,"version_name":v}
                for r,p,v in sorted(values)]
    return {
        "schema_version":1,
        "source_commit":SOURCE,
        "original_archive_sha256":ARCHIVE,
        "workload":"real_offline_host_original_full_normal_private_Weston_10s",
        "browser_libxul_pid_trace_count":genuine,
        "static_version_name_contracts":len(original),
        "observed_original_static_version_checks":len(observed),
        "unobserved_original_static_version_checks":len(original-observed),
        "additional_runtime_version_checks":len(other),
        "observed_original_version_checks":rows(observed),
        "unobserved_original_version_checks":rows(original-observed),
        "additional_runtime_checks":rows(other),
        "raw_loader_paths_or_pids_retained":False,
        "actual_dynamic_symbol_bindings_proven":False,
        "unexecuted_feature_routes_proven":False,
        "complete_loader_and_dlopen_graph_proven":False,
        "target_arch_hyprland_proven":False,
        "new_source_removal_authorized":False,
        "m3_sixth_gate_closed":False
    }


def selftest():
    import tempfile
    original={("libxul.so","libc.so.6","GLIBC_2.2.5")}
    with tempfile.TemporaryDirectory() as t:
        f=Path(t)/"m3-loader.123"
        good=(" 123: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] "
              "required by file /test/libxul.so [0]\n"
              " 123: calling init: /test/libxul.so\n")
        f.write_text(good)
        assert compare(Path(t),original)["observed_original_static_version_checks"]==1
        for bad in (
            good.replace("calling init: /test/libxul.so","calling init: /test/bash"),
            good.replace("GLIBC_2.2.5","GLIBC_999.0"),
            good.replace("required by file /test/libxul.so","required by file /test/other.so"),
            good.replace("/lib/libc.so.6","/private/secret/bad:name"),
        ):
            f.write_text(bad)
            try: compare(Path(t),original)
            except ValueError: pass
            else: raise AssertionError("Malformed real loader observation accepted")
    return 4


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--actual",type=Path)
    p.add_argument("--static",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"loader version negative fixtures")
        if a.actual is None:return
    if not (a.actual and a.static and a.output):
        p.error("--actual, --static and --output required")
    report=compare(a.actual,expected(json.loads(a.static.read_text())))
    a.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: authenticated native libxul loader version checks from actual Wayland browser")
    print("BROWSER PID TRACES:",report["browser_libxul_pid_trace_count"])
    print("ORIGINAL STATIC REQUIREMENTS CHECKED:",report["observed_original_static_version_checks"])
    print("ORIGINAL STATIC REQUIREMENTS NOT SEEN:",report["unobserved_original_static_version_checks"])
    print("EXTRA ACTUAL GLIBC LOADER VERSION CHECKS:",report["additional_runtime_version_checks"])
    print("LIMIT: no per-symbol binding, lazy-route coverage or M3 source-removal credit")


if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,OSError) as e:
        print("FAIL: bounded native loader version mapping:",e,file=sys.stderr)
        raise SystemExit(1)
