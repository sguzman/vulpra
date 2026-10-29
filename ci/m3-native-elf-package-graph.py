#!/usr/bin/env python3
"""Read-only SHA256-pinned ELF dependency census for every regular native package member.

No loader invocation, ldconfig, ldd, dlopen, code execution, binary extraction
outside isolated temp files, source deletion or compile. Only direct DT_NEEDED
edges of packaged ELF members are classified; system-library closure is unknown.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

MAX_ENTRY=384*1024*1024
MAX_TOTAL=512*1024*1024
MAX_MEMBERS=1024
NEEDED=re.compile(r"\(NEEDED\)\s+Shared library: \[([^\]\r\n]+)\]")
SONAME=re.compile(r"\(SONAME\)\s+Library soname: \[([^\]\r\n]+)\]")

def verify_archive(path):
    side=Path(str(path)+".sha256")
    if not side.is_file():raise ValueError("Missing pinned archive sidecar")
    lines=side.read_text(encoding="ascii").splitlines()
    if len(lines)!=1:raise ValueError("Unexpected sidecar lines")
    m=re.fullmatch(r"([a-fA-F0-9]{64})\s+\*?(\S+)",lines[0])
    if not m or Path(m.group(2)).name!=path.name:
        raise ValueError("Sidecar checksum or package filename invalid")
    digest=sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(2*1024*1024),b""):
            digest.update(chunk)
    calculated=digest.hexdigest()
    if calculated!=m.group(1).lower():raise ValueError("Wrong archive SHA-256")
    return calculated

def readelf(path,mode):
    p=subprocess.run(["readelf",mode,str(path)],capture_output=True,
                     text=True,timeout=60,check=False)
    if p.returncode:raise ValueError("readelf rejected apparent ELF member")
    return p.stdout

def scan(path):
    archive_sha=verify_archive(path)
    seen=set();regular_count=0;link_count=0;regular_bytes=0
    native=[];link_by_basename={}
    with tempfile.TemporaryDirectory(prefix="vulpra-elf-all-") as folder:
        temp=Path(folder)/"member.bin"
        with tarfile.open(path,"r:xz") as tf:
            for member in tf:
                if member.name in seen:raise ValueError("Duplicate package path")
                seen.add(member.name)
                if len(seen)>MAX_MEMBERS:
                    raise ValueError("Excessively many archive entries")
                if member.issym() or member.islnk():
                    link_count+=1
                    link_by_basename.setdefault(Path(member.name).name,[]).append({
                        "archive_member":member.name,
                        "kind":"link_unresolved"})
                    continue
                if not member.isfile():continue
                regular_count+=1;regular_bytes+=member.size
                if regular_bytes>MAX_TOTAL or not 0<=member.size<=MAX_ENTRY:
                    raise ValueError("Oversize package entry or regular-file sum")
                stream=tf.extractfile(member)
                if stream is None:raise ValueError("Missing file stream")
                first=stream.read(min(4,member.size))
                if first!=b"\x7fELF":continue
                remaining=member.size-len(first)
                hasher=sha256()
                with temp.open("wb") as out:
                    out.write(first);hasher.update(first)
                    while remaining:
                        data=stream.read(min(2*1024*1024,remaining))
                        if not data:raise ValueError("Truncated ELF member")
                        out.write(data);hasher.update(data);remaining-=len(data)
                try:
                    header=readelf(temp,"-hW")
                    if "Class:                             ELF64" not in header or "X86-64" not in header:
                        raise ValueError("Unexpected native package ELF architecture")
                    dynamic=readelf(temp,"-dW")
                finally:
                    temp.unlink(missing_ok=True)
                names=NEEDED.findall(dynamic)
                if len(set(names))!=len(names):raise ValueError("Duplicate DT_NEEDED entry")
                sonames=SONAME.findall(dynamic)
                if len(sonames)>1:raise ValueError("Multiple SONAME declarations")
                native.append({"path":member.name,"name":Path(member.name).name,
                    "logical_bytes":member.size,"sha256":hasher.hexdigest(),
                    "soname":sonames[0] if sonames else None,"needed":names})
    if not any(x["name"]=="libxul.so" for x in native):
        raise ValueError("No packaged native libxul ELF file")
    exact={}
    for x in native:
        keys={x["name"]}
        if x["soname"]:keys.add(x["soname"])
        for key in keys:exact.setdefault(key,[]).append(x["path"])
    edges=[];external=set();local=set();links=set()
    for module in native:
        for dep in module["needed"]:
            matches=sorted(exact.get(dep,[]))
            if matches:
                scope="packaged_elf_declared_name"
                local.add(dep)
            elif dep in link_by_basename:
                scope="archive_link_only_unresolved"
                matches=[x["archive_member"] for x in link_by_basename[dep]]
                links.add(dep)
            else:
                scope="absent_from_archive_loader_resolution_unverified"
                external.add(dep)
            edges.append({"requester":module["path"],"needed":dep,
                          "scope":scope,"possible_members":matches})
    if len(native)<2:raise ValueError("Unreasonably few native ELF objects in package")
    libxul=[x for x in native if x["name"]=="libxul.so"]
    if len(libxul)!=1 or libxul[0]["logical_bytes"]<=0:
        raise ValueError("Expected one native libxul")
    return {"schema_version":1,"scope":"direct DT_NEEDED edges for every packaged ELF regular file",
        "archive_sha256":archive_sha,
        "archive_compressed_bytes":path.stat().st_size,
        "archive_regular_members":regular_count,
        "archive_regular_logical_bytes":regular_bytes,
        "archive_link_members":link_count,
        "elf_members":native,
        "direct_edges":edges,
        "unique_needed_names":len(set(x["needed"] for x in edges)),
        "direct_needed_edges":len(edges),
        "packaged_elf_needed_names":sorted(local),
        "archive_link_only_needed_names":sorted(links),
        "not_packaged_needed_names":sorted(external),
        "no_package_source_edited":True,
        "all_native_binary_execution_avoided":True,
        "host_dependency_resolution_verified":False,
        "dlopen_and_indirect_runtime_dependencies_complete":False,
        "current_main_compiled_source_matched":False,
        "source_removal_authorized":False,
        "marginal_compressed_saving_bytes":None,
        "limitations":[
            "Archive source is historical, not current Git main.",
            "Direct DT_NEEDED on package ELF files does not close host-library transitive imports.",
            "Packaged basename/SONAME match does not prove loader search path or ABI compatibility.",
            "Symlink declarations are not followed; only name and presence are noted.",
            "No dlopen, plugin dynamic loading, runtime fallback or launcher startup verified.",
            "No source change, native compile, package saving or feature-size attribution."
        ]}

def selftest():
    # One small native executable and one shared ELF fixture if provided.
    fixture=Path("/bin/true")
    if not fixture.exists():raise ValueError("No standard ELF fixture")
    payload=fixture.read_bytes()
    if not payload.startswith(b"\x7fELF"):raise ValueError("Non-ELF fixture")
    with tempfile.TemporaryDirectory(prefix="vulpra-elf-all-test-") as d:
        p=Path(d)/"test.tar.xz"
        def make(duplicate=False,symlink=False):
            with tarfile.open(p,"w:xz") as tf:
                for name in ("vulpra/libxul.so","vulpra/vulpra-bin"):
                    ent=tarfile.TarInfo(name);ent.size=len(payload)
                    tf.addfile(ent,BytesIO(payload))
                    if duplicate and name.endswith("vulpra-bin"):
                        tf.addfile(ent,BytesIO(payload))
                if symlink:
                    item=tarfile.TarInfo("vulpra/libc.so.6")
                    item.type=tarfile.SYMTYPE;item.linkname="/outside"
                    tf.addfile(item)
            Path(str(p)+".sha256").write_text(sha256(p.read_bytes()).hexdigest()+"  "+p.name+"\n")
        make()
        x=scan(p)
        assert len(x["elf_members"])==2
        assert x["host_dependency_resolution_verified"] is False
        assert x["marginal_compressed_saving_bytes"] is None
        make(symlink=True)
        x=scan(p)
        assert x["archive_link_members"]==1
        assert "libc.so.6" in x["archive_link_only_needed_names"]
        make(duplicate=True)
        try:scan(p)
        except ValueError as ex:assert "Duplicate" in str(ex)
        else:raise AssertionError("Duplicate regular package name accepted")
        make()
        Path(str(p)+".sha256").write_text("0"*64+"  "+p.name+"\n")
        try:scan(p)
        except ValueError as ex:assert "SHA-256" in str(ex)
        else:raise AssertionError("Tampered full package accepted")
        Path(str(p)+".sha256").write_text(sha256(p.read_bytes()).hexdigest()+"  wrong.tar.xz\n")
        try:scan(p)
        except ValueError as ex:assert "filename" in str(ex)
        else:raise AssertionError("Incorrect sidecar name accepted")
    return 8

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",nargs="?",type=Path)
    ap.add_argument("--self-test",action="store_true")
    ap.add_argument("--output",type=Path)
    args=ap.parse_args()
    if args.self_test:print("PASS:",selftest(),"mock ELF/dependency and archive safety cases")
    if not args.archive:
        if not args.self_test:ap.error("Archive required unless --self-test")
        return
    report=scan(args.archive.resolve())
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: checksum-verified native archive ELF records inspected without code execution")
    print("NATIVE ELF MEMBERS:",len(report["elf_members"]))
    print("DIRECT NEEDED EDGES:",report["direct_needed_edges"])
    print("UNIQUE DIRECT NEEDED:",report["unique_needed_names"])
    print("PACKAGED DIRECT NAMES:",json.dumps(report["packaged_elf_needed_names"]))
    print("ARCHIVE LINK NAMES:",json.dumps(report["archive_link_only_needed_names"]))
    print("ABSENT DIRECT NAMES:",json.dumps(report["not_packaged_needed_names"]))
    print("No host loader resolution, dlopen, source removal, runtime or saved bytes established")
if __name__=="__main__":
    try:main()
    except (OSError,AssertionError,ValueError,subprocess.TimeoutExpired,tarfile.TarError) as e:
        print("FAIL M3 packaged ELF direct graph:",e,file=sys.stderr)
        raise SystemExit(1)
