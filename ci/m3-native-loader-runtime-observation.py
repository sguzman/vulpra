#!/usr/bin/env python3
"""Fail-closed GNU dynamic loader observation from actual native Vulpra QA.

Never persist raw loader lines, filesystem paths, profile contents, environment,
or untrusted symbols. This is a Linux CI host snapshot of one WebDriver workload,
NOT full dlopen coverage, complete ABI closure, or the user's Arch host graph.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys

PID_FILE = re.compile(r"^m3-loader\.(\d+)$")
INIT = re.compile(r"calling init:\s+(\S+)")
OPEN = re.compile(r"file=(\S+)")
REQUEST = re.compile(r"file=(\S+)\s+\[\d+\];\s+(needed by|dynamically loaded by)\s+(\S+)")
MAX_REQUEST_EDGES = 10000
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.+\-]{0,110}$")
MAX_FILES = 100
MAX_BYTES_PER_FILE = 22_000_000

def basename(value: str) -> str | None:
    name = value.rstrip(";,").split("/")[-1]
    return name if SAFE_NAME.fullmatch(name) else None

def inspect(folder: Path, workload: str = "headless_webdriver") -> dict:
    if workload not in ("headless_webdriver", "private_weston_wayland"):
        raise ValueError("unsupported real native workload mode")
    if not folder.is_dir():
        raise ValueError("Loader output folder missing")
    files=sorted(x for x in folder.iterdir()
                 if x.is_file() and PID_FILE.fullmatch(x.name))
    if not files or len(files)>MAX_FILES:
        raise ValueError("No bounded numeric-PID LD_DEBUG logs")
    browsers=[]
    seen=set()
    recorded_needed_by=set()
    recorded_dynamic_requests=set()
    pre_libxul_request_init=set()
    after_libxul_request_init=set()
    traces_with_first_libxul_request=0
    for f in files:
        if not 0 < f.stat().st_size <= MAX_BYTES_PER_FILE:
            raise ValueError("Empty or oversized loader log")
        text=f.read_text(encoding="utf-8",errors="replace")
        if not ("file=libxul.so" in text or
                "calling init:" in text and "/libxul.so" in text):
            continue
        init=set()
        opened=set()
        candidate_needed_by=set()
        candidate_dynamic=set()
        trace_pre_libxul=set()
        trace_after_libxul=set()
        # Multiple exec() images can append to one glibc LD_DEBUG_OUTPUT.PID
        # file. The launcher is Bash and must not automatically be treated
        # as a browser-origin library request. This marker is a bounded
        # observation boundary, not an infallible proof of native ownership.
        first_libxul_request=None
        for line_index,line in enumerate(text.splitlines()):
            m=OPEN.search(line)
            if m and basename(m.group(1))=="libxul.so" and first_libxul_request is None:
                first_libxul_request=line_index
            m=INIT.search(line)
            if m:
                n=basename(m.group(1))
                if n:
                    init.add(n)
                    if first_libxul_request is None:
                        trace_pre_libxul.add(n)
                    else:
                        trace_after_libxul.add(n)
            m=OPEN.search(line)
            if m:
                n=basename(m.group(1))
                if n:opened.add(n)
            m=REQUEST.search(line)
            if m:
                requested=basename(m.group(1))
                requester=basename(m.group(3))
                if requested and requester and requested!=requester:
                    edge=(requester,requested)
                    if m.group(2)=="needed by":
                        candidate_needed_by.add(edge)
                    elif m.group(2)=="dynamically loaded by":
                        candidate_dynamic.add(edge)
        if "libxul.so" not in opened and "libxul.so" not in init:
            continue
        if len(init)<3:
            raise ValueError("Browser process had too few real loader init events")
        seen.update(init)
        if first_libxul_request is not None:
            traces_with_first_libxul_request+=1
            pre_libxul_request_init.update(trace_pre_libxul)
            after_libxul_request_init.update(trace_after_libxul)
        # A request line by itself does not establish that its library
        # initialized. Retain only edges whose target has an actual native
        # glibc "calling init" event in THIS same browser process trace.
        recorded_needed_by.update((src,dest) for src,dest in candidate_needed_by
                                  if dest in init)
        recorded_dynamic_requests.update((src,dest) for src,dest in candidate_dynamic
                                         if dest in init)
        browsers.append({"observed_loaded_name_count":len(init),
                         "original_compiled_libxul_referenced":True,
                         "glibc_init_events_present":True})
    if not browsers:
        raise ValueError("No actual Vulpra native browser process with libxul")
    for required in ("libxul.so","libc.so.6"):
        if required not in seen and required!="libxul.so":
            raise ValueError("No observed core glibc initialization: "+required)
    # No path, user state, PID or raw message is ever emitted.
    if len(recorded_needed_by)+len(recorded_dynamic_requests)>MAX_REQUEST_EDGES:
        raise ValueError("Too many distinct real loader request relations")
    names=sorted(seen)
    def safe_edges(pairs):
        return [{"requester_basename":src,"requested_library_basename":dest}
                for src,dest in sorted(pairs)]
    return {
        "schema_version":1,
        "status":"actual_native_full_normal_loader_observation",
        "total_pid_trace_files_examined":len(files),
        "browser_process_traces_with_libxul":len(browsers),
        "observed_loader_init_library_basename_count":len(names),
        "observed_loader_init_library_basenames":names,
        # These are the native loader's event-order *segments*, not a
        # definitive process-of-origin classifier. Names before the first
        # libxul request are possible Bash/launcher contamination; names
        # appearing in both segments cannot be assigned exclusively.
        "traces_with_first_libxul_request_boundary":traces_with_first_libxul_request,
        "observed_before_first_libxul_request_basenames":sorted(pre_libxul_request_init),
        "observed_after_first_libxul_request_basenames":sorted(after_libxul_request_init),
        "observed_before_only_basenames":sorted(
            pre_libxul_request_init-after_libxul_request_init),
        "observed_after_only_basenames":sorted(
            after_libxul_request_init-pre_libxul_request_init),
        "post_first_libxul_request_stage_is_proven_exclusive_browser_code":False,
        "pre_first_libxul_request_stage_is_proven_exclusive_launcher_code":False,
        "loader_reported_needed_by_initialized_edge_count":len(recorded_needed_by),
        "loader_reported_needed_by_initialized_edges":safe_edges(recorded_needed_by),
        "loader_reported_dynamic_initialized_edge_count":len(recorded_dynamic_requests),
        "loader_reported_dynamic_initialized_edges":safe_edges(recorded_dynamic_requests),
        "request_relationships_from_same_browser_pid_trace":True,
        "only_initialized_request_targets_included":True,
        "loader_request_edges_complete":False,
        "libxul_requested_in_real_browser_process":True,
        "libc_loader_init_observed":"libc.so.6" in seen,
        "observed_workload_mode":workload,
        "real_native_webdriver_workload_passed":workload=="headless_webdriver",
        "real_native_wayland_surface_commit_passed":workload=="private_weston_wayland",
        "old_normal_native_archive_source":"b1482404dfb8b01342990ee99ea3df0f9756b5f7",
        "old_normal_native_archive_sha256":
            "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a",
        "host":"GitHub Actions Ubuntu 24.04 x86_64; NOT user Arch/Hyprland",
        "raw_loader_traces_retained":False,
        "complete_dlopen_graph_proven":False,
        "unexecuted_feature_routes_proven":False,
        "complete_dynamic_symbol_and_ABI_resolution_proven":False,
        "current_main_browser_recompiled":False,
        "new_source_removal_authorized":False,
        "new_compressed_savings_bytes":None,
        "whole_m3_feature_dependency_gate_completed":False,
    }

def selftest() -> None:
    import tempfile
    with tempfile.TemporaryDirectory(prefix="vulpra-loader-guard-") as tmp:
        folder=Path(tmp)
        f=folder/"m3-loader.123"
        text=(
            "    123: file=libtinfo.so.6 [0]; needed by /usr/bin/bash [0]\n"
            "    123: calling init: /lib/libtinfo.so.6\n"
            "    123: file=libxul.so [0]; needed by /tmp/vulpra/vulpra-bin\n"
            "    123: file=libnss3.so [0]; dynamically loaded by /tmp/vulpra/libxul.so [0]\n"
            "    123: file=not-initialized.so [0]; dynamically loaded by /tmp/vulpra/libxul.so [0]\n"
            "    123: calling init: /lib/x86_64-linux-gnu/libc.so.6\n"
            "    123: calling init: /lib/x86_64-linux-gnu/libnss3.so\n"
            "    123: calling init: /tmp/vulpra/libxul.so\n"
        )
        f.write_text(text)
        v=inspect(folder)
        assert v["browser_process_traces_with_libxul"]==1
        assert "libxul.so" in v["observed_loader_init_library_basenames"]
        assert "libc.so.6" in v["observed_loader_init_library_basenames"]
        assert v["traces_with_first_libxul_request_boundary"]==1
        assert v["observed_before_only_basenames"]==["libtinfo.so.6"]
        assert "libtinfo.so.6" not in v["observed_after_first_libxul_request_basenames"]
        assert "libc.so.6" in v["observed_after_first_libxul_request_basenames"]
        assert "libtinfo.so.6" in v["observed_loader_init_library_basenames"]
        assert v["post_first_libxul_request_stage_is_proven_exclusive_browser_code"] is False
        assert v["loader_reported_needed_by_initialized_edges"]==[
            {"requester_basename":"bash",
             "requested_library_basename":"libtinfo.so.6"},
            {"requester_basename":"vulpra-bin",
             "requested_library_basename":"libxul.so"}]
        assert v["loader_reported_dynamic_initialized_edges"]==[
            {"requester_basename":"libxul.so",
             "requested_library_basename":"libnss3.so"}]
        assert v["loader_reported_needed_by_initialized_edge_count"]==2
        assert v["loader_reported_dynamic_initialized_edge_count"]==1
        assert not v["loader_request_edges_complete"]
        assert all("/" not in str(pair) for pair in
                   v["loader_reported_dynamic_initialized_edges"])
        for altered in [
            text.replace("file=libxul.so","file=other.so").replace(
                "/tmp/vulpra/libxul.so","/tmp/vulpra/other.so"),
            text.replace("calling init: /lib/x86_64-linux-gnu/libc.so.6",
                         "calling init: /unknown/custom.so"),
            text.replace("calling init: /tmp/vulpra/libxul.so",
                         "open: /tmp/vulpra/libxul.so"),
            "file=libxul.so [0]\n",
            "",
        ]:
            f.write_text(altered)
            try:inspect(folder)
            except ValueError:pass
            else:raise AssertionError("Unsafe loader fixture accepted")
        f.write_text(text)
        (folder/"m3-loader.steal").write_text(text)
        assert inspect(folder)["browser_process_traces_with_libxul"]==1
        (folder/"m3-loader.456").write_text("unrelated process\n")
        assert inspect(folder)["total_pid_trace_files_examined"]==2
    print("PASS: six corrupt/misleading loader reports rejected or correctly excluded")

def main() -> int:
    p=argparse.ArgumentParser()
    p.add_argument("folder",type=Path,nargs="?")
    p.add_argument("--output",type=Path)
    p.add_argument("--workload",choices=["headless_webdriver","private_weston_wayland"],default="headless_webdriver")
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        selftest()
        return 0
    if not a.folder or not a.output:
        p.error("actual observation requires folder and --output")
    result=inspect(a.folder,a.workload)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: observed",result["browser_process_traces_with_libxul"],
          "actual browser loader process trace(s),",
          result["observed_loader_init_library_basename_count"],
          "libc/glibc init library basenames")
    print("PASS: sanitized initialized targets with", result["loader_reported_needed_by_initialized_edge_count"], "needed-by and", result["loader_reported_dynamic_initialized_edge_count"], "dynamic-request observed relations")
    print("DIAGNOSTIC first-libxul request boundaries:", result["traces_with_first_libxul_request_boundary"],
          "before-only init basenames:", len(result["observed_before_only_basenames"]),
          "after-boundary init basenames:", len(result["observed_after_first_libxul_request_basenames"]))
    print("DIAGNOSTIC before-only safe basenames:",
          ", ".join(result["observed_before_only_basenames"]) or "(none)")
    print("LIMIT: before/after libxul marker segments are not exclusive process ownership proof")
    print("LIMIT: one", a.workload, "workload on Ubuntu, not complete dlopen, Arch, ABI or feature map")
    return 0

if __name__=="__main__":
    try:raise SystemExit(main())
    except (ValueError,OSError,AssertionError) as e:
        print("FAIL: bounded native-loader contract:",e,file=sys.stderr)
        raise SystemExit(1)
