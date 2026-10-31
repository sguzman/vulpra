#!/usr/bin/env python3
"""Read only the source-pinned alternate vulpra-bin ELF version checks.

The real package's binary is run in a private Weston browser test; cannot
conclude installed browser launch strategy, complete symbol binding, all
features, or source-removal permission from the observed loader check names.
"""
import argparse
import json
from pathlib import Path
import re
import sys

SRC="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
SHA="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
SAFE=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
TRACE=re.compile(r"vulpra-bin-loader\.[0-9]+\Z")
CHECK=re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def base(text):
    b=text.rsplit("/",1)[-1]
    if not SAFE.fullmatch(b):
        raise ValueError("Unexpected sensitive/invalid GLIBC loader name")
    return b


def static_requirements(raw):
    if not isinstance(raw,dict) or any((
        raw.get("schema_version")!=1,
        raw.get("source_commit")!=SRC,
        raw.get("original_archive_sha256")!=SHA,
        raw.get("scanned_native_elf_files")!=28,
        raw.get("native_elf_declared_version_requirements")!=519,
        raw.get("actual_symbol_resolution_proven") is not False,
        raw.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Unauthenticated source-pinned native ELF archive")
    rows=raw.get("requirements")
    if not isinstance(rows,list) or len(rows)!=519:
        raise ValueError("Original native version declarations missing")
    wanted=set()
    for r in rows:
        if not isinstance(r,dict) or r.get("version_name_present_in_candidate") is not True:
            raise ValueError("Unsigned/unavailable original version candidate")
        triple=tuple(r.get(k) for k in ("requester_basename","provider_basename","version_name"))
        if any(not isinstance(s,str) or not SAFE.fullmatch(s) for s in triple):
            raise ValueError("Source ELF triple includes untrusted pathname")
        if triple[0]=="vulpra-bin":
            if triple in wanted:raise ValueError("Duplicate alternate executable ELF version triple")
            wanted.add(triple)
    if len(wanted)!=21:
        raise ValueError("Original alternate executable version-need inventory changed")
    return wanted


def compare(folder,original):
    files=[p for p in folder.iterdir() if p.is_file() and TRACE.fullmatch(p.name)]
    if not 1<=len(files)<=32:
        raise ValueError("Missing/unbounded source alternate browser loader trace")
    observed=set()
    extras=set()
    for file in files:
        if not 0<file.stat().st_size<=15_000_000:
            raise ValueError("Unbounded alternate native loader trace")
        for row in file.read_text(errors="replace").splitlines():
            m=CHECK.search(row)
            if m is None:continue
            triple=(base(m.group(3)),base(m.group(2)),base(m.group(1)))
            if triple[0]!="vulpra-bin":continue
            if triple in original:observed.add(triple)
            else:extras.add(triple)
    if not observed or extras:
        raise ValueError("Actual compiled alternate ELF version requirements not checked or unexpected")
    return {
        "schema_version":1,
        "original_compiled_native_source":SRC,
        "original_compiled_native_archive_sha256":SHA,
        "feature_workload":"real_original_vulpra_bin_private_Weston_two_ten_second_frame_checks",
        "real_original_alt_elf_native_graphical_wayland_frame_proven":True,
        "original_alternate_native_elf_version_contracts":len(original),
        "original_alternate_native_elf_version_contracts_observed":len(observed),
        "original_alternate_native_elf_version_contracts_not_observed":len(original-observed),
        "observed_original_version_contracts":[
            {"requester_basename":a,"provider_basename":b,"version_name":c}
            for a,b,c in sorted(observed)],
        "raw_loader_paths_or_process_ids_retained":False,
        "installed_default_launcher_changed":False,
        "installed_user_browser_profile_changed":False,
        "online_host_and_arch_hyprland_runtime_proven":False,
        "actual_individual_symbol_bindings_proven":False,
        "all_lazy_feature_routes_proven":False,
        "new_source_removal_authorized":False,
        "m3_sixth_gate_closed":False
    }


def selftest():
    import tempfile
    sample={("vulpra-bin","libc.so.6","GLIBC_2.2.5")}
    with tempfile.TemporaryDirectory() as folder:
        file=Path(folder)/"vulpra-bin-loader.42"
        good="42: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /pkg/vulpra-bin [0]\n"
        file.write_text(good)
        assert compare(Path(folder),sample)["original_alternate_native_elf_version_contracts_observed"]==1
        for bad in (
            good.replace("/pkg/vulpra-bin","/pkg/firefox"),
            good.replace("GLIBC_2.2.5","GLIBC_999"),
            good.replace("/lib/libc.so.6","/bad/with:colon")
        ):
            file.write_text(bad)
            try:compare(Path(folder),sample)
            except ValueError:pass
            else:raise AssertionError("Fake alternate binary ELF version trace accepted")
    return 3


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--traces",type=Path)
    p.add_argument("--static",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"fake native executable loader fixtures rejected")
        if a.traces is None:return
    if not (a.traces and a.static and a.output):
        p.error("--traces, --static, --output required")
    result=compare(a.traces,static_requirements(json.loads(a.static.read_text())))
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: original alternate source-matched compiled browser native Wayland frame")
    print("ALTERNATE ELF GNU VERSION NEEDS OBSERVED:",result["original_alternate_native_elf_version_contracts_observed"])
    print("ALTERNATE ELF GNU VERSION NEEDS NOT OBSERVED:",result["original_alternate_native_elf_version_contracts_not_observed"])
    print("LIMIT: temp shim not replacement for installed native launcher, no overall ABI closure")


if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError) as ex:
        print("FAIL: bounded native Vulpra alternate ELF experiment:",ex,file=sys.stderr)
        raise SystemExit(1)
