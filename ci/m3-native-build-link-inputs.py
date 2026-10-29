#!/usr/bin/env python3
"""Read-only native build link-input and packaged dependency-order provenance.

Requires a complete same-source objdir and a staged SHA256-verified package.
The response file is the backend's object-input list, NOT a full linker map or
attribution of object bytes to source features.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

MAX_LIST=16*1024*1024
MAX_MEMBERS=100000
ORDER=("libmozgtk.so","libmozwayland.so")

def file_digest(path):
    h=sha256()
    with path.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):
            h.update(block)
    return h.hexdigest()

def inspect_response(path):
    if not path.is_file():raise ValueError("Missing libxul generated linker input list")
    raw=path.read_bytes()
    if not 64<len(raw)<=MAX_LIST:raise ValueError("Unbounded/empty linker input list")
    try:rows=[x.strip() for x in raw.decode("utf-8").splitlines() if x.strip()]
    except UnicodeDecodeError as e:raise ValueError("Non-UTF-8 response file") from e
    if not 100<=len(rows)<=MAX_MEMBERS:
        raise ValueError("Implausible count of normal libxul linker input objects")
    if len(set(rows))!=len(rows):
        raise ValueError("Duplicate object-list entries")
    if any("\0" in row or "\t" in row or len(row)>2048 or row.startswith("/") for row in rows):
        raise ValueError("Unsafe or unbounded object-list entry")
    suffixes={}
    for row in rows:
        suffix=Path(row).suffix or "(none)"
        suffixes[suffix]=suffixes.get(suffix,0)+1
    return {"sha256":sha256(raw).hexdigest(),"entry_count":len(rows),
            "entry_extension_counts":dict(sorted(suffixes.items())),
            "contains_rust_archive_reference":any("gkrust" in x for x in rows),
            "contains_archive_references":any(x.endswith(".a") for x in rows),
            "total_response_file_bytes":len(raw),
            "raw_input_paths_retained_in_report":False}

def parse_loader_order(raw):
    try:items=[x.strip() for x in raw.decode("utf-8").splitlines() if x.strip()]
    except UnicodeDecodeError as e:raise ValueError("Invalid loader dependency list") from e
    if not 5<=len(items)<=256 or len(set(items))!=len(items):
        raise ValueError("Missing/ambiguous native dependency ordering")
    if any(not x.startswith("lib") or "/" in x or "\0" in x or len(x)>128 for x in items):
        raise ValueError("Unsafe native dependency names")
    actual=[x for x in ORDER if x in items]
    if actual!=list(ORDER):
        raise ValueError("Critical GTK/Wayland native preloading order changed")
    if items.index(ORDER[0])>=items.index(ORDER[1]):
        raise ValueError("libmozgtk must load before libmozwayland")
    return {"ordered_names":items,"count":len(items),
            "mozgtk_before_mozwayland":True}

def inside_package(path):
    side=Path(str(path)+".sha256")
    if not side.is_file():raise ValueError("Staged package missing SHA256 sidecar")
    line=side.read_text(encoding="ascii").strip()
    cols=line.split()
    if len(cols)!=2 or cols[1].lstrip("*")!=path.name:
        raise ValueError("Incorrect staged package sidecar")
    actual=file_digest(path)
    if actual!=cols[0].lower():raise ValueError("Staged package SHA256 mismatch")
    matched=[];target_deps=[];member_sha=None;count=0
    with tarfile.open(path,"r:xz") as t:
        for info in t:
            if not info.isfile():continue
            count+=1
            if count>1024:raise ValueError("Unbounded browser package members")
            if info.name.endswith("/libxul.so"):
                if info.size>384*1024*1024:raise ValueError("Oversize libxul")
                f=t.extractfile(info)
                if f is None:raise ValueError("Missing libxul file content")
                h=sha256();head=f.read(4);h.update(head)
                if head!=b"\x7fELF":raise ValueError("Not an ELF libxul")
                for block in iter(lambda:f.read(1024*1024),b""):h.update(block)
                matched.append({"path":info.name,"bytes":info.size,"sha256":h.hexdigest()})
            if info.name.endswith("/dependentlibs.list"):
                if info.size>16384:raise ValueError("Unbounded native preload list")
                f=t.extractfile(info)
                if f is None:raise ValueError("Cannot read dependentlibs.list")
                target_deps.append(parse_loader_order(f.read()))
    if len(matched)!=1 or len(target_deps)!=1:
        raise ValueError("Expected one packaged libxul and dependentlibs.list")
    return {"package_sha256":actual,"package_compressed_bytes":path.stat().st_size,
            "regular_member_count":count,"libxul_member":matched[0],
            "packaged_native_loader_order":target_deps[0],
            "native_binary_executed":False}

def accept_replay(link_report, replay):
    if not isinstance(replay,dict) or replay.get("schema_version")!=1:
        raise ValueError("Missing typed packaging transformation replay")
    if replay.get("source_commit")!=link_report["source_commit"]:
        raise ValueError("Transform source commit mismatch")
    if replay.get("method")!="mozpack.files.ExecutableFile.copy":
        raise ValueError("Unrecognized packaging transformation method")
    for key in ("mozpack_copy_ran_on_temporary_file","reproduced_matches_staged",
                "source_binary_intact_after_replay","staged_binary_intact_after_replay"):
        if replay.get(key) is not True:
            raise ValueError("Unverified packaging replay: "+key)
    if replay.get("packaged_archive_member_verified_by_other_report") is not False:
        raise ValueError("Replay falsely claims independent tar verification")
    if replay.get("source_libxul_sha256")!=link_report["built_libxul_sha256"]:
        raise ValueError("Transform original binary SHA256 mismatch")
    package_sha=link_report["package"]["libxul_member"]["sha256"]
    if replay.get("staged_libxul_sha256")!=package_sha or (
        replay.get("reproduced_libxul_sha256")!=package_sha
    ):
        raise ValueError("Reproduced libxul differs from actual packaged tar member")
    link_report["packaging_transform_replay"]={
        "method":replay["method"],"source_commit":replay["source_commit"],
        "original_libxul_sha256":replay["source_libxul_sha256"],
        "staged_and_reproduced_libxul_sha256":package_sha,
        "configured_strip_enabled":replay.get("configured_strip_enabled"),
        "configured_elfhack_enabled":replay.get("configured_elfhack_enabled"),
        "deterministic_reproduction_verified":True,
        "original_and_packaged_hash_equal":link_report["built_libxul_matches_packaged_libxul"],
        "complete_linker_map_claimed":False,
        "compiled_feature_bytes_attributed":False,
    }
    return link_report


def audit(objdir,package,expected_sha,replay_report=None):
    actual=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
    if actual!=expected_sha:raise ValueError("Source HEAD differs from claimed native build SHA")
    links=inspect_response(objdir/"toolkit/library/build/libxul_so.list")
    deps=objdir/"dist/bin/dependentlibs.list"
    if not deps.is_file():raise ValueError("No complete native build dependency list")
    from_dist=parse_loader_order(deps.read_bytes())
    archive=inside_package(package)
    if archive["packaged_native_loader_order"]["ordered_names"]!=from_dist["ordered_names"]:
        raise ValueError("Packaged dependency order differs from native build dist")
    binary=objdir/"dist/bin/libxul.so"
    if not binary.is_file():raise ValueError("No native compiled libxul.so")
    built_lib_hash=file_digest(binary)
    report={"schema_version":1,"project":"Vulpra",
      "scope":"same-source successful generated libxul response object list and native preload order",
      "source_commit":actual,
      "objdir":objdir.name,
      "libxul_link_input_response":links,
      "dist_native_loader_order":from_dist,
      "package":archive,
      "built_libxul_sha256":built_lib_hash,
      "built_libxul_matches_packaged_libxul":built_lib_hash==archive["libxul_member"]["sha256"],
      "native_build_required":True,
      "native_build_status_proved_by_this_script_alone":False,
      "runtime_smoke_accepted_by_this_script":False,
      "linker_full_map_recorded":False,
      "per_feature_native_bytes_attributed":False,
      "compressed_package_savings_claimed":None,
      "source_removal_authorized":False,
      "limitations":[
        "Response-file input names and ordering are not a full resolved linker symbol map.",
        "Object input list may omit separately passed linker arguments and archives.",
        "The native binary cannot itself identify marginal removable feature bytes.",
        "Package matches build library only if observed hashes are identical.",
        "Runtime GTK/Wayland behavior needs separate graphics/browser smoke.",
        "No feature omission or normal/lean paired archive comparison."]}
    if replay_report is not None:
        report=accept_replay(report,replay_report)
    return report

def selftest():
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-native-link-test-") as d:
        p=Path(d)/"libxul_so.list"
        p.write_text("".join(f"../../source/file_{i:04d}.o\n" for i in range(125)))
        x=inspect_response(p)
        assert x["entry_count"]==125 and x["entry_extension_counts"][".o"]==125
        try:parse_loader_order(b"libmozwayland.so\nlibmozgtk.so\nlibxul.so\nlibnss3.so\nlibnspr4.so\n")
        except ValueError:pass
        else:raise AssertionError("Backwards Wayland shim order accepted")
        correct=b"libmozgtk.so\nlibmozwayland.so\nlibxul.so\nlibnss3.so\nlibnspr4.so\n"
        assert parse_loader_order(correct)["mozgtk_before_mozwayland"]
        p.write_text(p.read_text()+"../../source/file_0001.o\n")
        try:inspect_response(p)
        except ValueError as ex:assert "Duplicate" in str(ex)
        else:raise AssertionError("Duplicated linker input accepted")
        p.write_text("one.o\n")
        try:inspect_response(p)
        except ValueError as ex:assert "Unbounded/empty" in str(ex) or "Implausible" in str(ex)
        else:raise AssertionError("Incomplete linker input accepted")
        fake={
            "schema_version":1,"source_commit":"a"*40,
            "built_libxul_sha256":"b"*64,
            "built_libxul_matches_packaged_libxul":False,
            "package":{"libxul_member":{"sha256":"c"*64}},
        }
        proof={
            "schema_version":1,"source_commit":"a"*40,
            "method":"mozpack.files.ExecutableFile.copy",
            "mozpack_copy_ran_on_temporary_file":True,
            "reproduced_matches_staged":True,
            "source_binary_intact_after_replay":True,
            "staged_binary_intact_after_replay":True,
            "packaged_archive_member_verified_by_other_report":False,
            "source_libxul_sha256":"b"*64,
            "staged_libxul_sha256":"c"*64,
            "reproduced_libxul_sha256":"c"*64,
            "configured_strip_enabled":False,
            "configured_elfhack_enabled":True,
        }
        assert accept_replay(dict(fake),proof)["packaging_transform_replay"]["deterministic_reproduction_verified"]
        for field,value in (("source_commit","d"*40),
                            ("source_libxul_sha256","d"*64),
                            ("reproduced_libxul_sha256","d"*64),
                            ("reproduced_matches_staged",False),
                            ("method","unverified")):
            bad=dict(proof);bad[field]=value
            try:accept_replay(dict(fake),bad)
            except ValueError:pass
            else:raise AssertionError("Falsified packager proof accepted: "+field)
    return 11

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--objdir",type=Path)
    p.add_argument("--package",type=Path)
    p.add_argument("--source-sha")
    p.add_argument("--transform-report",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    args=p.parse_args()
    if args.self_test:print("PASS:",selftest(),"native response/GTK loader negative fixtures")
    if not (args.objdir and args.package and args.source_sha):
        if args.self_test:return
        p.error("--objdir, --package and --source-sha required")
    replay_report=json.loads(args.transform_report.read_text()) if args.transform_report else None
    report=audit(args.objdir.resolve(),args.package.resolve(),args.source_sha,replay_report)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: exact-source compiled libxul response list and packaged loader dependency order")
    print("OBJECT INPUTS:",report["libxul_link_input_response"]["entry_count"])
    print("PACKAGE BYTES:",report["package"]["package_compressed_bytes"])
    print("LIBXUL RAW MATCH:",report["built_libxul_matches_packaged_libxul"])
    print("LIBXUL PACKAGER REPLAY:",report.get("packaging_transform_replay",{}).get("deterministic_reproduction_verified"))
    print("No full linker symbol map, runtime, causal savings or source removal")
if __name__=="__main__":
    try:main()
    except (OSError,AssertionError,ValueError,subprocess.CalledProcessError,tarfile.TarError) as e:
        print("FAIL M3 link provenance:",e,file=sys.stderr);raise SystemExit(1)
