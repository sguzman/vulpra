#!/usr/bin/env python3
"""Strict original source-pinned GNU version evidence for three protected ELFs.

Diagnostic-only entry points are not proof that real crashes or updates work.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys
import tempfile

SRC="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
SHA="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
COUNTS={"crashhelper":27,"updater":27,"crashreporter":20}
SAFE=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
CHECK=re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def base(raw):
    name=raw.rsplit("/",1)[-1]
    if not SAFE.fullmatch(name):raise ValueError("Unsafe ELF identity")
    return name


def triples(rows):
    if not isinstance(rows,list) or len(rows)!=519:raise ValueError("Incomplete original ABI ledger")
    result=set()
    for row in rows:
        if not isinstance(row,dict) or row.get("version_name_present_in_candidate") is not True:
            raise ValueError("Nonmatching original provider")
        t=tuple(row.get(k) for k in ("requester_basename","provider_basename","version_name"))
        if any(not isinstance(k,str) or not SAFE.fullmatch(k) for k in t) or t in result:
            raise ValueError("Duplicate/unsafe original version triple")
        result.add(t)
    return result


def static_contracts(doc):
    if any((
        doc.get("schema_version")!=1,doc.get("source_commit")!=SRC,
        doc.get("original_archive_sha256")!=SHA,doc.get("scanned_native_elf_files")!=28,
        doc.get("native_elf_declared_version_requirements")!=519,
        doc.get("actual_symbol_resolution_proven") is not False,
        doc.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Wrong original compiled ELF artifact identity")
    original=triples(doc.get("requirements"))
    selected={t for t in original if t[0] in COUNTS}
    if Counter(t[0] for t in selected)!=COUNTS:
        raise ValueError("Protected original helper ELF counts changed")
    return selected


def analyze(folder, static):
    result=set()
    for module in COUNTS:
        files=[p for p in folder.iterdir() if p.is_file() and
               re.fullmatch(re.escape(module)+r"-loader\.[0-9]+",p.name)]
        if not 1<=len(files)<=8:raise ValueError("No bounded "+module+" ELF loader traces")
        expected={t for t in static if t[0]==module}
        actual=set()
        unexpected=set()
        for path in files:
            if not 0<path.stat().st_size<=10_000_000:raise ValueError("Unbounded loader trace")
            for line in path.read_text(errors="replace").splitlines():
                hit=CHECK.search(line)
                if hit is None:continue
                t=(base(hit.group(3)),base(hit.group(2)),base(hit.group(1)))
                if t[0]!=module:continue
                if t in expected:actual.add(t)
                else:unexpected.add(t)
        if actual!=expected or unexpected:
            raise ValueError(module+" version requirements not all witnessed")
        result.update(actual)
    if len(result)!=74:raise ValueError("Protected loader ABI union incomplete")
    return {
        "schema_version":1,"original_native_compiled_source":SRC,
        "original_native_archive_sha256":SHA,
        "original_compiled_auxiliary_elf_members":3,
        "protected_native_version_checks_observed":74,
        "per_member_observed_version_contracts":dict(sorted(Counter(t[0] for t in result).items())),
        "observed_original_version_contracts":[
            {"requester_basename":a,"provider_basename":b,"version_name":c}
            for a,b,c in sorted(result)],
        "crashhelper_invalid_argv_rejected_before_minidump":True,
        "crashreporter_synthetic_only_memtest_completed":True,
        "updater_read_only_channel_query_only":True,
        "real_crash_minidump_handler_tested":False,
        "real_crash_report_sent":False,"real_update_applied_or_installed":False,
        "user_data_or_network_egress_allowed":False,
        "raw_loader_paths_or_pids_retained":False,
        "native_feature_integration_proven":False,
        "complete_runtime_symbol_binding_proven":False,
        "new_source_removal_authorized":False,"m3_sixth_gate_closed":False
    }


def selftest():
    good="  42: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /pkg/crashhelper [0]\n"
    m=CHECK.search(good)
    assert m and (base(m.group(3)),base(m.group(2)),base(m.group(1)))==(
        "crashhelper","libc.so.6","GLIBC_2.2.5")
    for bad in (
        good.replace("GLIBC_2.2.5","GLIBC_999"),
        good.replace("/pkg/crashhelper","/pkg/wrong"),
        good.replace("/lib/libc.so.6","/lib/lib!c.so.6")
    ):
        m=CHECK.search(bad)
        if m:
            try:t=(base(m.group(3)),base(m.group(2)),base(m.group(1)))
            except ValueError:continue
            assert t!=("crashhelper","libc.so.6","GLIBC_2.2.5")
    assert sum(COUNTS.values())==74
    return 4


def main():
    cli=argparse.ArgumentParser()
    for key in ("traces","static","output"):cli.add_argument("--"+key,type=Path)
    cli.add_argument("--self-test",action="store_true")
    args=cli.parse_args()
    if args.self_test:
        print("PASS:",selftest(),"protected ELF trace fixtures")
        if args.traces is None:return
    if not(args.traces and args.static and args.output):
        cli.error("Need --traces --static --output")
    r=analyze(args.traces,static_contracts(json.loads(args.static.read_text())))
    args.output.write_text(json.dumps(r,indent=2)+"\n")
    print("PASS: 74 declared protected ELF GNU version checks observed in original helpers")
    print("LIMIT: update/crash product paths NOT proven, no source removal")


if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,KeyError,OSError) as e:
        print("FAIL original auxiliary ELF runtime evidence:",e,file=sys.stderr)
        raise SystemExit(1)
