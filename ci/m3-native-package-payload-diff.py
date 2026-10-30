#!/usr/bin/env python3
"""Read-only hash-level diff of two verified native Vulpra tar.xz packages.

Hashes real regular files and the logical entries inside shipped omni.ja.
Never extracts archive entries to disk or executes libraries. Archive-size
changes are not source-match, causal component savings or runtime proof.
"""
from __future__ import annotations

import argparse
from collections import Counter
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import tarfile
import tempfile
import zipfile
import sys

MAX_ITEMS=200_000
MAX_MEMBER_BYTES=1_000_000_000
MAX_ARCHIVE_BYTES=1_000_000_000
MAX_LOGICAL_ZIP_BYTES=2_000_000_000
MAX_SAMPLES=80
BLOCK=1<<20

def safe_name(name: str) -> str:
    if not isinstance(name,str) or not 1<=len(name)<=600 or name.startswith("/") or "\0" in name:
        raise ValueError("Unsafe absolute/invalid archive path")
    parts=name.split("/")
    if ".." in parts or any(p=="" for p in parts[1:-1]):
        raise ValueError("Unsafe traversal/empty archive path")
    clean="/".join(p for p in parts if p not in (".",""))
    if not clean or clean.startswith("../") or clean== "..":
        raise ValueError("Unsafe archive member path")
    return clean

def stream_digest(f, size: int) -> str:
    if size<0 or size>MAX_MEMBER_BYTES:
        raise ValueError("Oversize or negative archive member")
    digest=sha256()
    left=size
    while left:
        block=f.read(min(left,BLOCK))
        if not block:
            raise ValueError("Truncated native package member")
        digest.update(block)
        left-=len(block)
    return digest.hexdigest()

def archive_sha256(path:Path) -> str:
    if not path.is_file() or not 1<=path.stat().st_size<=MAX_ARCHIVE_BYTES:
        raise ValueError("Invalid or too large compressed archive")
    digest=sha256()
    with path.open("rb") as f:
        for block in iter(lambda:f.read(BLOCK),b""):
            digest.update(block)
    return digest.hexdigest()

def inspect(path:Path) -> dict:
    checksum=archive_sha256(path)
    regular={}
    inside={}
    logical=0
    seen=set()
    with tarfile.open(path,"r|xz") as tf:
        for index,member in enumerate(tf,1):
            if index>MAX_ITEMS:
                raise ValueError("Native archive exceeds member bounds")
            if member.isdir() and member.name in (".", "./"):
                # GNU tar may include a harmless root directory header.
                continue
            try:
                name=safe_name(member.name)
            except ValueError as exc:
                raise ValueError(
                    "Unsafe tar member "+repr(member.name)+": "+str(exc)
                ) from exc
            if name in seen:
                raise ValueError("Duplicate native archive member path")
            seen.add(name)
            if member.isdir():
                continue
            if member.isfile():
                if member.size>MAX_MEMBER_BYTES:
                    raise ValueError("Native regular file exceeds per-file bound")
                reader=tf.extractfile(member)
                if reader is None:
                    raise ValueError("Cannot read regular archive member")
                logical+=member.size
                if name.endswith("/omni.ja"):
                    data=reader.read(member.size+1)
                    if len(data)!=member.size:
                        raise ValueError("Truncated omni.ja")
                    digest=sha256(data).hexdigest()
                    try:
                        with zipfile.ZipFile(BytesIO(data)) as jar:
                            for j in jar.infolist():
                                if j.is_dir():continue
                                nested=safe_name(j.filename)
                                logical_key=name+"::"+nested
                                if logical_key in inside:
                                    raise ValueError("Duplicate omni.ja embedded resource")
                                if j.file_size>MAX_MEMBER_BYTES:
                                    raise ValueError("Oversize embedded browser resource")
                                # ZipFile verifies CRC while streaming decompression;
                                # SHA256, not CRC, is used to classify content identity.
                                with jar.open(j,"r") as z:
                                    sha=stream_digest(z,j.file_size)
                                inside[logical_key]={"size":j.file_size,"sha256":sha}
                                if len(inside)>MAX_ITEMS:
                                    raise ValueError("Too many embedded browser resources")
                    except (zipfile.BadZipFile,RuntimeError) as exc:
                        raise ValueError("Unreadable omni.ja") from exc
                else:
                    digest=stream_digest(reader,member.size)
                regular[name]={"kind":"file","size":member.size,"sha256":digest}
                continue
            if member.issym() or member.islnk():
                # Metadata comparison only; never follow archive link targets.
                # Never follow this target, only preserve literal metadata.
                # Relative links containing '..' are legitimate in packaged
                # Linux software but would be unsafe to *extract* blindly.
                link=member.linkname
                if not isinstance(link,str) or len(link)>600 or "\0" in link:
                    raise ValueError("Unsafe link metadata for "+repr(name))
                regular[name]={"kind":"link","target":link,"hardlink":bool(member.islnk())}
                continue
            raise ValueError("Unsupported special archive entry")
    return {"archive_sha256":checksum,"compressed_bytes":path.stat().st_size,
            "regular_logical_bytes":logical,
            "tar_members_seen":len(seen),"regular_files_and_links":regular,
            "embedded_omni_resources":inside}

def compare_maps(full:dict,lean:dict):
    a=set(full)
    b=set(lean)
    common=a&b
    removed=sorted(a-b)
    added=sorted(b-a)
    changed=sorted(k for k in common if full[k]!=lean[k])
    return {"removed_count":len(removed),"added_count":len(added),
            "changed_count":len(changed),
            "identical_count":len(common)-len(changed),
            "removed_paths_sample":removed[:MAX_SAMPLES],
            "added_paths_sample":added[:MAX_SAMPLES],
            "changed_paths_sample":changed[:MAX_SAMPLES],
            "paths_truncated_for_report":any(len(q)>MAX_SAMPLES for q in (removed,added,changed))}

def report(a,b):
    return {"schema_version":1,"comparison":"sha256 content of native tar regular files and embedded omni.ja resources",
            "full_archive_sha256":a["archive_sha256"],
            "lean_archive_sha256":b["archive_sha256"],
            "full_compressed_bytes":a["compressed_bytes"],
            "lean_compressed_bytes":b["compressed_bytes"],
            "observed_outer_compressed_difference_bytes":a["compressed_bytes"]-b["compressed_bytes"],
            "full_tar_member_count":a["tar_members_seen"],
            "lean_tar_member_count":b["tar_members_seen"],
            "full_regular_logical_bytes":a["regular_logical_bytes"],
            "lean_regular_logical_bytes":b["regular_logical_bytes"],
            "native_tar_content_diff":compare_maps(a["regular_files_and_links"],b["regular_files_and_links"]),
            "embedded_omni_content_diff":compare_maps(a["embedded_omni_resources"],b["embedded_omni_resources"]),
            "full_normandy_runner_resource_found":any(
                p.endswith("res/normandy/Normandy.sys.mjs") for p in a["embedded_omni_resources"]),
            "lean_normandy_runner_resource_found":any(
                p.endswith("res/normandy/Normandy.sys.mjs") for p in b["embedded_omni_resources"]),
            "lean_shared_nimbus_helpers_found":all(any(
                p.endswith("res/normandy/lib/"+module) for p in b["embedded_omni_resources"])
                for module in ("ClientEnvironment.sys.mjs","NormandyUtils.sys.mjs","NormandyApi.sys.mjs")),
            "all_browser_source_hashes_proven_equal":False,
            "binary_runtime_equivalence_proven":False,
            "archive_reproducibility_across_builds_proven":False,
            "causal_source_feature_byte_savings_proven":False,
            "native_executable_run_by_comparison":False,
            "new_source_removal_authorized":False,
            "new_m3_roadmap_gate_passed":False,
            "limitations":[
                "Physical member and inner ZIP SHA256 identities only; file metadata, XZ order and compression can vary.",
                "Independent source and compiler flag identity must be authenticated from separate original CI runs.",
                "Changing built native binaries may reflect compiler build IDs, nondeterminism or feature flags.",
                "A compressed archive delta is not by itself causal savings for the omitted feature.",
                "This offline comparison does not execute Wayland, JavaScript, Sync, Glean or the browser.",
            ]}

def fixture_archive(path:Path,*,runner:bool,evil:str|None=None):
    jar_bytes=BytesIO()
    with zipfile.ZipFile(jar_bytes,"w",compression=zipfile.ZIP_DEFLATED) as jar:
        if runner:jar.writestr("res/normandy/Normandy.sys.mjs","runner!")
        for module in ("ClientEnvironment.sys.mjs","NormandyUtils.sys.mjs","NormandyApi.sys.mjs"):
            jar.writestr("res/normandy/lib/"+module,module)
    with tarfile.open(path,"w:xz") as tf:
        items=[("vulpra/libxul.so",b"same native binary"),("vulpra/omni.ja",jar_bytes.getvalue())]
        if evil: items.append((evil,b"unsafe"))
        for name,data in items:
            obj=tarfile.TarInfo(name)
            obj.size=len(data)
            tf.addfile(obj,BytesIO(data))

def selftest():
    with tempfile.TemporaryDirectory() as tmp:
        full=Path(tmp)/"full.tar.xz"
        lean=Path(tmp)/"lean.tar.xz"
        fixture_archive(full,runner=True)
        fixture_archive(lean,runner=False)
        a,b=inspect(full),inspect(lean)
        d=report(a,b)
        assert d["full_normandy_runner_resource_found"] is True
        assert d["lean_normandy_runner_resource_found"] is False
        assert d["lean_shared_nimbus_helpers_found"] is True
        assert d["embedded_omni_content_diff"]["removed_count"]==1
        assert d["embedded_omni_content_diff"]["changed_count"]==0
        assert d["native_tar_content_diff"]["changed_count"]==1
        assert d["native_tar_content_diff"]["identical_count"]==1
        assert d["causal_source_feature_byte_savings_proven"] is False
        for bad in ("../secret","vulpra/../secret","/etc/passwd"):
            fixture_archive(Path(tmp)/"bad.tar.xz",runner=True,evil=bad)
            try:inspect(Path(tmp)/"bad.tar.xz")
            except ValueError:pass
            else: raise AssertionError("Unsafe tar archive path accepted: "+bad)
        for bad in ("../evil", "/secret", "vulpra//bad", ""):
            try:safe_name(bad)
            except ValueError:pass
            else: raise AssertionError("Invalid name accepted: "+repr(bad))
        assert not (Path(tmp)/"secret").exists()
    return 7

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--full",type=Path)
    ap.add_argument("--lean",type=Path)
    ap.add_argument("--output",type=Path)
    ap.add_argument("--self-test",action="store_true")
    a=ap.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"native tar/omni content identity boundary fixtures")
        if not a.full and not a.lean and not a.output:return
    if not (a.full and a.lean and a.output):
        ap.error("--full --lean --output are required")
    result=report(inspect(a.full),inspect(a.lean))
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: hashed real tar regular-file and embedded ZIP content, not executed")
    print("OUTER BYTES DELTA:",result["observed_outer_compressed_difference_bytes"])
    print("TAR CONTENT:",result["native_tar_content_diff"])
    print("INNER OMNI:",result["embedded_omni_content_diff"])
    print("No runtime/feature causal savings or source deletion is proven")

if __name__=="__main__":
    try:main()
    except (OSError,ValueError,tarfile.TarError,AssertionError,zipfile.BadZipFile) as error:
        print("FAIL bounded M3 native package content diff:",error,file=sys.stderr)
        raise SystemExit(1)
