#!/usr/bin/env python3
"""Reproduce Gecko's ELF packaging copy on a disposable libxul.so.

Run through `./mach python` after a full native build and `./mach package`.
Packaging uses mozpack.files.ExecutableFile.copy (optional STRIP/elfhack).
Never modify dist/bin, staged package, or original browser profiles.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys
import tempfile

# The linked, unstripped libxul may greatly exceed its compressed or stripped
# packaged ELF. Do not bound the former by the latter's observed size.
MAX_LIBXUL=2*1024*1024*1024
MIN_LIBXUL=10_000_000

def valid_binary_size(size):
    return isinstance(size,int) and MIN_LIBXUL<size<=MAX_LIBXUL

def digest(path):
    if not path.is_file():
        raise ValueError(f"Missing native libxul.so: {path}")
    size=path.stat().st_size
    if not valid_binary_size(size):
        raise ValueError(f"Native libxul.so outside {MIN_LIBXUL}..{MAX_LIBXUL} bytes: {path} ({size} bytes)")
    h=sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def replay(objdir,source_commit):
    if subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()!=source_commit:
        raise ValueError("Mismatched exact source commit")
    # Honor the generated buildconfig when mach-python itself has not
    # inserted the current object directory on sys.path.
    if (objdir/"buildconfig.py").is_file():
        sys.path.insert(0,str(objdir))
    # Import only inside a real configured mach-python environment.
    from mozpack.files import ExecutableFile
    from mozpack.executables import may_strip,may_elfhack
    import buildconfig
    built=objdir/"dist/bin/libxul.so"
    stage=objdir/"dist/vulpra/libxul.so"
    before=digest(built)
    stage_hash=digest(stage)
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-packager-replay-") as folder:
        copied=Path(folder)/"libxul.so"
        ExecutableFile(str(built)).copy(str(copied),skip_if_older=False)
        reproduced=digest(copied)
    if digest(built)!=before or digest(stage)!=stage_hash:
        raise ValueError("Packager replay changed an original input")
    if reproduced!=stage_hash:
        raise ValueError("Reproduced mozpack ELF copy differs from staged libxul")
    return {
        "schema_version":1,"source_commit":source_commit,
        "method":"mozpack.files.ExecutableFile.copy",
        "mozpack_copy_ran_on_temporary_file":True,
        "configured_strip_enabled":bool(may_strip(str(stage))),
        "configured_elfhack_enabled":bool(may_elfhack(str(stage))),
        "source_libxul_sha256":before,
        "reproduced_libxul_sha256":reproduced,
        "staged_libxul_sha256":stage_hash,
        "reproduced_matches_staged":True,
        "source_binary_intact_after_replay":True,
        "staged_binary_intact_after_replay":True,
        "packaged_archive_member_verified_by_other_report":False,
        "limitations":[
            "Transformation reproduction is deterministic on this build, not a full resolved symbol map.",
            "Staged file must independently match the SHA256-checked tarball member.",
            "Source and staged library bytes need not be identical after strip/elfhack.",
            "No per-feature byte attribution or removable compressed bytes."
        ],
    }

def selftest():
    assert not valid_binary_size(MIN_LIBXUL)
    assert valid_binary_size(MIN_LIBXUL+1)
    assert valid_binary_size(384*1024*1024+1)
    assert valid_binary_size(MAX_LIBXUL)
    assert not valid_binary_size(MAX_LIBXUL+1)
    assert not valid_binary_size(-1)
    assert not valid_binary_size("4294967296")
    return 7

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--self-test",action="store_true")
    ap.add_argument("--objdir",type=Path)
    ap.add_argument("--source-sha")
    ap.add_argument("--output",type=Path)
    a=ap.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"native unstripped/staged library size boundaries")
        if not (a.objdir or a.source_sha or a.output):
            return
    if not (a.objdir and a.source_sha and a.output):
        ap.error("--objdir, --source-sha and --output required")
    result=replay(a.objdir.resolve(),a.source_sha)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: exact-source Gecko mozpack ELF transformation reproduced")
    print("BUILT and STAGED SHA differ:",result["source_libxul_sha256"]!=result["staged_libxul_sha256"])

if __name__=="__main__":
    try:main()
    except (OSError,ValueError,subprocess.CalledProcessError) as e:
        print("FAIL M3 ELF packager replay:",e,file=sys.stderr)
        raise SystemExit(1)
