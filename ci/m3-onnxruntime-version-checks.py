#!/usr/bin/env python3
"""Bounded original libonnxruntime GNU runtime version-check evidence.

This proves loading the original shared ELF into an isolated Rust C ABI probe,
NOT a model run, browser integration, ORT inference correctness, or safe pruning.
"""
import argparse
import json
from pathlib import Path
import re
import sys
SRC="b1482404dfb8b01342990ee99ea3df0f9756b5f7"
SHA="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
SAFE=re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
TRACE=re.compile(r"onnx-loader\.[0-9]+\Z")
CHECK=re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def base(text):
    value=text.rsplit("/",1)[-1]
    if not SAFE.fullmatch(value):raise ValueError("Unsafe raw ELF provider pathname")
    return value


def get_expected(data):
    if not isinstance(data,dict) or any((
        data.get("schema_version")!=1,
        data.get("source_commit")!=SRC,
        data.get("original_archive_sha256")!=SHA,
        data.get("scanned_native_elf_files")!=28,
        data.get("native_elf_declared_version_requirements")!=519,
        data.get("actual_symbol_resolution_proven") is not False,
        data.get("m3_sixth_gate_closed") is not False
    )):
        raise ValueError("Original native source/ELF metadata not authenticated")
    rows=data.get("requirements")
    if not isinstance(rows,list) or len(rows)!=519:raise ValueError("Invalid original VERNEED collection")
    keys=set()
    for row in rows:
        if not isinstance(row,dict) or row.get("version_name_present_in_candidate") is not True:
            raise ValueError("Invalid source ELF declared provider")
        t=tuple(row.get(k) for k in ("requester_basename","provider_basename","version_name"))
        if any(not isinstance(s,str) or not SAFE.fullmatch(s) for s in t):
            raise ValueError("Unbounded/static raw path")
        if t in keys:raise ValueError("Duplicate original native ELF contract")
        keys.add(t)
    expected={x for x in keys if x[0]=="libonnxruntime.so"}
    if len(expected)!=20:raise ValueError("Original ONNX ABI contract count changed")
    return expected


def compare(folder,known):
    files=[x for x in folder.iterdir() if x.is_file() and TRACE.fullmatch(x.name)]
    if not 1<=len(files)<=8:raise ValueError("No bounded original ONNX dynloader trace")
    observed=set()
    unexpected=set()
    for f in files:
        if not 0<f.stat().st_size<=10000000:raise ValueError("Unbounded ONNX dynamic loader record")
        for line in f.read_text(errors="replace").splitlines():
            m=CHECK.search(line)
            if m is None:continue
            t=(base(m.group(3)),base(m.group(2)),base(m.group(1)))
            if t[0]!="libonnxruntime.so":continue
            if t in known:observed.add(t)
            else:unexpected.add(t)
    if not observed or unexpected:
        raise ValueError("Original ONNX ELF version checks missing/mismatched")
    return {
        "schema_version":1,
        "original_native_compiled_source":SRC,
        "original_native_archive_sha256":SHA,
        "feature_probe":"original_onnxruntime_C_API_base_version_no_egress_netns",
        "real_onxx_native_dlopen_and_c_api_version_invoked":True,
        "original_onnxruntime_version_contracts":len(known),
        "observed_original_onnxruntime_version_checks":len(observed),
        "not_observed_original_onnxruntime_version_checks":len(known-observed),
        "observed_original_version_contracts":[
            {"requester_basename":a,"provider_basename":b,"version_name":c}
            for a,b,c in sorted(observed)],
        "model_loaded_or_inference_performed":False,
        "browser_ml_feature_integrated_and_passed":False,
        "external_network_or_user_data_exposed":False,
        "raw_loader_paths_and_pids_retained":False,
        "all_runtime_symbol_bindings_proven":False,
        "safe_original_source_removal_authorized":False,
        "m3_sixth_gate_closed":False
    }


def selftest():
    import tempfile
    wanted={("libonnxruntime.so","libc.so.6","GLIBC_2.2.5")}
    with tempfile.TemporaryDirectory() as folder:
        f=Path(folder)/"onnx-loader.123"
        good="  123: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /pkg/libonnxruntime.so [0]\n"
        f.write_text(good)
        assert compare(Path(folder),wanted)["observed_original_onnxruntime_version_checks"]==1
        for bad in (
            good.replace("/pkg/libonnxruntime.so","/pkg/helper"),
            good.replace("GLIBC_2.2.5","GLIBC_999"),
            good.replace("/lib/libc.so.6","/private/no:provider")
        ):
            f.write_text(bad)
            try:compare(Path(folder),wanted)
            except ValueError:pass
            else:raise AssertionError("False ONNX runtime library evidence accepted")
    return 3


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--traces",type=Path)
    p.add_argument("--static",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"malformed ONNX version trace fixtures")
        if a.traces is None:return
    if not(a.traces and a.static and a.output):
        p.error("--traces, --static and --output required")
    result=compare(a.traces,get_expected(json.loads(a.static.read_text())))
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: compiled original ONNX C ABI probe and static version needs observed")
    print("OBSERVED ONNX VERSION CONTRACTS:",result["observed_original_onnxruntime_version_checks"])
    print("NOT SEEN:",result["not_observed_original_onnxruntime_version_checks"])
    print("LIMIT: no inference, model, runtime browser integration or source deletion")


if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,OSError) as e:
        print("FAIL: bounded ONNX Runtime ABI activation:",e,file=sys.stderr)
        raise SystemExit(1)
