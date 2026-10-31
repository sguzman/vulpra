#!/usr/bin/env python3
"""Compare real gfxtest GLX Wayland dynamic-loader checks to pinned VERNEED.

Require exact archived source/compiled package and no user profile, host paths,
raw PIDs or unproven symbol/graphics claims in resulting report.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys
SRC="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
SHA="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
SAFE=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
TRACE=re.compile(r"gfxtest-loader\.[0-9]+\Z")
CHECK=re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def basename(value):
    b=value.rsplit("/",1)[-1]
    if not SAFE.fullmatch(b):
        raise ValueError("Unbounded/sensitive loader basename")
    return b


def expected(report):
    if not isinstance(report,dict) or any((
        report.get("schema_version")!=1,
        report.get("source_commit")!=SRC,
        report.get("original_archive_sha256")!=SHA,
        report.get("native_elf_declared_version_requirements")!=519,
        report.get("scanned_native_elf_files")!=28,
        report.get("actual_symbol_resolution_proven") is not False,
        report.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Untrusted original pinned ELF VERNEED evidence")
    rows=report.get("requirements")
    if not isinstance(rows,list) or len(rows)!=519:
        raise ValueError("Incomplete original version contract data")
    valid=set()
    for x in rows:
        if not isinstance(x,dict) or x.get("version_name_present_in_candidate") is not True:
            raise ValueError("Untrusted original version provider")
        t=(x.get("requester_basename"),x.get("provider_basename"),x.get("version_name"))
        if any(not isinstance(z,str) or not SAFE.fullmatch(z) for z in t):
            raise ValueError("Raw/unsafe version contract")
        if t in valid:raise ValueError("Duplicate static contract")
        valid.add(t)
    selected={x for x in valid if x[0]=="gfxtest"}
    if len(selected)!=8:
        raise ValueError("Original compiled gfxtest static contracts changed")
    return selected


def analyze(folder, static):
    paths=sorted(p for p in folder.iterdir() if p.is_file() and TRACE.fullmatch(p.name))
    if not 1<=len(paths)<=8:
        raise ValueError("Missing/unbounded real gfx probe trace")
    checked=set()
    all_gfx=set()
    for path in paths:
        if not 0<path.stat().st_size<=9_000_000:
            raise ValueError("Oversized/empty gfx loader trace")
        for line in path.read_text(errors="replace").splitlines():
            m=CHECK.search(line)
            if not m:continue
            t=(basename(m.group(3)),basename(m.group(2)),basename(m.group(1)))
            if t[0]!="gfxtest":continue
            all_gfx.add(t)
            if t in static:checked.add(t)
    if not checked:
        raise ValueError("No real gfx ELF version check encountered")
    if all_gfx-static:
        raise ValueError("Original gfxtest emitted unverified extra version contracts")
    return {
        "schema_version":1,
        "original_compiled_source":SRC,
        "original_native_archive_sha256":SHA,
        "native_feature_workload":"original_packaged_gfxtest_glx_wayland_private_Weston",
        "real_wayland_gfxtest_connected_and_completed":True,
        "original_gfxtest_static_version_contracts":len(static),
        "original_gfxtest_version_contracts_observed":len(checked),
        "original_gfxtest_version_contracts_not_observed":len(static-checked),
        "observed_original_version_contracts":[
            {"requester_basename":r,"provider_basename":p,"version_name":v}
            for r,p,v in sorted(checked)],
        "unobserved_original_version_contracts":[
            {"requester_basename":r,"provider_basename":p,"version_name":v}
            for r,p,v in sorted(static-checked)],
        "raw_loader_paths_or_pids_retained":False,
        "successful_gpu_acceleration_proven":False,
        "original_browser_feature_set_fully_exercised":False,
        "actual_symbol_bindings_proven":False,
        "other_packaged_helper_binaries_exercised":False,
        "target_arch_hyprland_proven":False,
        "new_source_removal_authorized":False,
        "m3_sixth_gate_closed":False
    }


def selftest():
    import tempfile
    one=("gfxtest","libc.so.6","GLIBC_2.2.5")
    with tempfile.TemporaryDirectory() as tmp:
        f=Path(tmp)/"gfxtest-loader.123"
        good="123: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /package/gfxtest [0]\n"
        f.write_text(good)
        r=analyze(Path(tmp),{one})
        assert r["original_gfxtest_version_contracts_observed"]==1
        for bad in (
            good.replace("required by file /package/gfxtest","required by file /package/other"),
            good.replace("GLIBC_2.2.5","GLIBC_999"),
            good.replace("/lib/libc.so.6","/private/not:safe"),
        ):
            f.write_text(bad)
            try:analyze(Path(tmp),{one})
            except ValueError:pass
            else:raise AssertionError("Invalid gfxtest version trace accepted")
    return 3


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--traces",type=Path)
    p.add_argument("--static",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"native gfx loader negative fixtures")
        if a.traces is None:return
    if not(a.traces and a.static and a.output):
        p.error("--traces, --static and --output required")
    r=analyze(a.traces,expected(json.loads(a.static.read_text())))
    a.output.write_text(json.dumps(r,indent=2)+"\n")
    print("PASS: original native gfxtest Wayland EGL branch exercised")
    print("OBSERVED ORIGINAL GFX VERSION NEEDS:",r["original_gfxtest_version_contracts_observed"])
    print("NOT OBSERVED:",r["original_gfxtest_version_contracts_not_observed"])
    print("LIMIT: this does not prove GPU acceleration, every feature, or safe pruning")


if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,OSError) as err:
        print("FAIL native gfx helper version coverage:",err,file=sys.stderr)
        raise SystemExit(1)
