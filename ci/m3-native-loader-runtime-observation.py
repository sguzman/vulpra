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
    for f in files:
        if not 0 < f.stat().st_size <= MAX_BYTES_PER_FILE:
            raise ValueError("Empty or oversized loader log")
        text=f.read_text(encoding="utf-8",errors="replace")
        if not ("file=libxul.so" in text or
                "calling init:" in text and "/libxul.so" in text):
            continue
        init=set()
        opened=set()
        for line in text.splitlines():
            m=INIT.search(line)
            if m:
                n=basename(m.group(1))
                if n:init.add(n)
            m=OPEN.search(line)
            if m:
                n=basename(m.group(1))
                if n:opened.add(n)
        if "libxul.so" not in opened and "libxul.so" not in init:
            continue
        if len(init)<3:
            raise ValueError("Browser process had too few real loader init events")
        seen.update(init)
        browsers.append({"observed_loaded_name_count":len(init),
                         "original_compiled_libxul_referenced":True,
                         "glibc_init_events_present":True})
    if not browsers:
        raise ValueError("No actual Vulpra native browser process with libxul")
    for required in ("libxul.so","libc.so.6"):
        if required not in seen and required!="libxul.so":
            raise ValueError("No observed core glibc initialization: "+required)
    # No path, user state, PID or raw message is ever emitted.
    names=sorted(seen)
    return {
        "schema_version":1,
        "status":"actual_native_full_normal_loader_observation",
        "total_pid_trace_files_examined":len(files),
        "browser_process_traces_with_libxul":len(browsers),
        "observed_loader_init_library_basename_count":len(names),
        "observed_loader_init_library_basenames":names,
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
            "    123: file=libxul.so [0]; needed by /tmp/vulpra/vulpra-bin\n"
            "    123: calling init: /lib/x86_64-linux-gnu/libc.so.6\n"
            "    123: calling init: /lib/x86_64-linux-gnu/libnss3.so\n"
            "    123: calling init: /tmp/vulpra/libxul.so\n"
        )
        f.write_text(text)
        v=inspect(folder)
        assert v["browser_process_traces_with_libxul"]==1
        assert "libxul.so" in v["observed_loader_init_library_basenames"]
        assert "libc.so.6" in v["observed_loader_init_library_basenames"]
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
    print("LIMIT: one headless workload on Ubuntu, not complete dlopen, Arch, ABI or feature map")
    return 0

if __name__=="__main__":
    try:raise SystemExit(main())
    except (ValueError,OSError,AssertionError) as e:
        print("FAIL: bounded native-loader contract:",e,file=sys.stderr)
        raise SystemExit(1)
