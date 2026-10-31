#!/usr/bin/env python3
"""Bounded original pingsender native GNU loader version needs audit.

Uses the exact SHA-pinned source and static ELF VERNEED report. No raw packet
capture or loader paths retained; a local POST is not proof of real telemetry.
"""
import argparse
import json
from pathlib import Path
import re
import sys

SRC="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
SAFE=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
TRACE=re.compile(r"pingsender-loader\.[0-9]+\Z")
CHECK=re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def base(value):
    name=value.rsplit("/",1)[-1]
    if not SAFE.fullmatch(name):
        raise ValueError("Raw/private or invalid basename")
    return name


def static_source(report):
    if not isinstance(report,dict) or any([
        report.get("schema_version")!=1,
        report.get("source_commit")!=SRC,
        report.get("original_archive_sha256")!=ARCHIVE,
        report.get("native_elf_declared_version_requirements")!=519,
        report.get("scanned_native_elf_files")!=28,
        report.get("m3_sixth_gate_closed") is not False,
        report.get("actual_symbol_resolution_proven") is not False
    ]):
        raise ValueError("Wrong original native version source")
    rows=report.get("requirements")
    if not isinstance(rows,list) or len(rows)!=519:
        raise ValueError("Partial static version evidence")
    seen=set()
    for item in rows:
        if not isinstance(item,dict) or item.get("version_name_present_in_candidate") is not True:
            raise ValueError("Original version candidates not verified")
        triple=tuple(item.get(k) for k in ("requester_basename","provider_basename","version_name"))
        if any(not isinstance(z,str) or not SAFE.fullmatch(z) for z in triple):
            raise ValueError("Unsafe original static version row")
        if triple in seen:raise ValueError("Duplicate original static version")
        seen.add(triple)
    chosen={x for x in seen if x[0]=="pingsender"}
    if len(chosen)!=22:
        raise ValueError("Original pingsender static ABI count changed")
    return chosen


def compare(folder,static):
    traces=[p for p in folder.iterdir() if p.is_file() and TRACE.fullmatch(p.name)]
    if not 1<=len(traces)<=16:
        raise ValueError("Missing/unbounded original pingsender loader PID traces")
    seen=set()
    extra=set()
    for p in traces:
        if not 0<p.stat().st_size<=9_000_000:
            raise ValueError("Unbounded native pingsender loader trace")
        for row in p.read_text(errors="replace").splitlines():
            m=CHECK.search(row)
            if m is None:continue
            triple=(base(m.group(3)),base(m.group(2)),base(m.group(1)))
            if triple[0]!="pingsender":continue
            if triple in static:seen.add(triple)
            else:extra.add(triple)
    if not seen or extra:
        raise ValueError("No real matching pingsender GNU version checks or unexpected source")
    return {
        "schema_version":1,
        "original_native_source":SRC,
        "original_native_archive_sha256":ARCHIVE,
        "workload":"real_original_pingsender_synthetic_gzip_POST_to_localhost_no_egress_netns",
        "original_pingsender_static_version_contracts":len(static),
        "original_pingsender_static_version_checks_observed":len(seen),
        "original_pingsender_static_version_checks_not_seen":len(static-seen),
        "observed_original_version_contracts":[
            {"requester_basename":a,"provider_basename":b,"version_name":c}
            for a,b,c in sorted(seen)],
        "raw_loader_paths_and_pids_retained":False,
        "real_telemetry_sent":False,
        "synthetic_payload_deleted_only_after_local_success":True,
        "actual_symbol_bindings_proven":False,
        "production_telemetry_service_behavior_proven":False,
        "other_unused_helper_features_activated":False,
        "network_egress_allowed":False,
        "safe_source_removal_authorized":False,
        "m3_sixth_gate_closed":False
    }


def selftest():
    import tempfile
    wanted={("pingsender","libc.so.6","GLIBC_2.2.5")}
    with tempfile.TemporaryDirectory() as d:
        f=Path(d)/"pingsender-loader.54"
        good="54: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /package/pingsender [0]\n"
        f.write_text(good)
        assert compare(Path(d),wanted)["original_pingsender_static_version_checks_observed"]==1
        for bad in (
            good.replace("/package/pingsender","/package/firefox"),
            good.replace("GLIBC_2.2.5","GLIBC_200.0"),
            good.replace("/lib/libc.so.6","/lib/bad:path")
        ):
            f.write_text(bad)
            try:compare(Path(d),wanted)
            except ValueError:pass
            else:raise AssertionError("Spoofed pingsender loader evidence accepted")
    return 3


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--traces",type=Path)
    p.add_argument("--static",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"synthetic source/trace rejection fixtures")
        if a.traces is None:return
    if not(a.traces and a.static and a.output):
        p.error("--traces, --static and --output required")
    data=compare(a.traces,static_source(json.loads(a.static.read_text())))
    a.output.write_text(json.dumps(data,indent=2)+"\n")
    print("PASS: authenticated original native synthetic pingsender POST, no egress")
    print("ORIGINAL GNU VERSION NEEDS CHECKED:",data["original_pingsender_static_version_checks_observed"])
    print("ORIGINAL VERSION NEEDS NOT SEEN:",data["original_pingsender_static_version_checks_not_seen"])
    print("LIMIT: not actual browser telemetry, no direct-user network or source removal")


if __name__=="__main__":
    try:main()
    except (ValueError,OSError,AssertionError) as ex:
        print("FAIL: original pingsender ELF version activation:",ex,file=sys.stderr)
        raise SystemExit(1)
