#!/usr/bin/env python3
"""Read-only, SHA-256 pinned Vulpra libxul ELF layout and DT_NEEDED census.

Never load/execute the library. ELF section sizes do not attribute feature size.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

MAX_LIB=384*1024*1024
TARGETS={"./vulpra/libxul.so","vulpra/libxul.so"}
SECTION=re.compile(
    r"^\s*\[\s*(\d+)\]\s+(\S+)\s+(\S+)\s+"
    r"([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+"
    r"([0-9a-fA-F]+)\s+([\w-]+)\s+\d+\s+\d+\s+\d+\s*$")
NEEDED=re.compile(r"\(NEEDED\)\s+Shared library: \[([^\]\r\n]+)\]")

def digest(path):
    side=Path(str(path)+".sha256")
    if not side.is_file(): raise ValueError("Missing SHA-256 sidecar")
    lines=side.read_text(encoding="ascii").splitlines()
    if len(lines)!=1: raise ValueError("Invalid SHA-256 sidecar line count")
    match=re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?(\S+)",lines[0])
    if not match or Path(match.group(2)).name != path.name:
        raise ValueError("Invalid checksum or archive filename")
    h=sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda:stream.read(2*1024*1024),b""):
            h.update(chunk)
    value=h.hexdigest()
    if value!=match.group(1).lower():
        raise ValueError("SHA-256 mismatch: refusing native package")
    return value

def copy_lib(archive,target):
    found=[]
    with tarfile.open(archive,"r:xz") as tf:
        for entry in tf:
            if entry.name not in TARGETS: continue
            if not entry.isfile() or not 0<entry.size<=MAX_LIB:
                raise ValueError("libxul is not bounded regular-file tar member")
            if found: raise ValueError("Duplicate libxul member")
            src=tf.extractfile(entry)
            if src is None: raise ValueError("Unextractable libxul member")
            h=sha256();remaining=entry.size
            with target.open("wb") as out:
                while remaining:
                    data=src.read(min(2*1024*1024,remaining))
                    if not data: raise ValueError("Truncated libxul member")
                    out.write(data);h.update(data);remaining-=len(data)
            found.append({"path":entry.name,"logical_bytes":entry.size,"sha256":h.hexdigest()})
    if len(found)!=1: raise ValueError("Expected exactly one libxul.so")
    return found[0]

def readelf(path,*flags):
    result=subprocess.run(["readelf",*flags,str(path)],capture_output=True,
                          text=True,timeout=90,check=False)
    if result.returncode: raise ValueError("readelf failed: "+result.stderr[-200:])
    return result.stdout

def group(name):
    if name in (".text",".plt",".plt.got",".plt.sec",".init",".fini"):
        return "executable_sections"
    if name in (".rodata",".data.rel.ro",".data.rel.ro.local"):
        return "read_only_or_relocated_data"
    if name in (".data",".bss",".tdata",".tbss",".got",".got.plt"):
        return "writable_or_tls_data"
    if name.startswith((".debug",".zdebug")): return "debug_metadata"
    if name.startswith(".eh_frame") or name==".gcc_except_table":
        return "unwind_exception_metadata"
    if name.startswith((".rela",".rel.")): return "relocations"
    if name.startswith((".dynsym",".dynstr",".symtab",".strtab",".gnu.version")):
        return "symbols_and_names"
    return "other_named_sections"

def parse_sections(source):
    rows=[]
    buckets=defaultdict(lambda:{"count":0,"file_backed_bytes":0,
                                "virtual_section_bytes":0})
    for line in source.splitlines():
        m=SECTION.match(line)
        if not m: continue
        _,name,typ,_addr,_offset,hsize,_entsize,flags=m.groups()
        size=int(hsize,16);file_size=0 if typ=="NOBITS" else size
        bucket=group(name)
        rows.append({"name":name,"type":typ,"flags":flags,"virtual_bytes":size,
                     "file_backed_bytes":file_size,"bucket":bucket})
        buckets[bucket]["count"]+=1
        buckets[bucket]["file_backed_bytes"]+=file_size
        buckets[bucket]["virtual_section_bytes"]+=size
    if not rows or not any(r["name"]==".text" and r["virtual_bytes"]>0 for r in rows):
        raise ValueError("Missing nonempty ELF .text section")
    return {"section_count_excluding_null":len(rows),
            "file_backed_section_sum_bytes":sum(x["file_backed_bytes"] for x in rows),
            "groups":dict(sorted(buckets.items())),
            "largest_sections":sorted(rows,key=lambda x:-x["file_backed_bytes"])[:25],
            "nobits_sections":[x for x in rows if x["type"]=="NOBITS"]}

def header(raw):
    data={}
    for line in raw.splitlines():
        m=re.match(r"^\s*(Class|Data|Type|Machine):\s+(.+?)\s*$",line)
        if m:data[m.group(1).lower()]=m.group(2)
    if data.get("class")!="ELF64" or "X86-64" not in data.get("machine",""):
        raise ValueError("Not ELF64 x86-64")
    if not data.get("type","").startswith("DYN"):
        raise ValueError("Not ELF dynamic object")
    return data

def inspect(archive):
    archive=archive.resolve()
    checked=digest(archive)
    with tempfile.TemporaryDirectory(prefix="vulpra-readelf-") as temp:
        tmp=Path(temp)/"libxul.so"
        member=copy_lib(archive,tmp)
        elf=header(readelf(tmp,"-hW"))
        sections=parse_sections(readelf(tmp,"-SW"))
        names=NEEDED.findall(readelf(tmp,"-dW"))
        if not names or len(names)!=len(set(names)):
            raise ValueError("No unique DT_NEEDED dependencies")
    return {"schema_version":1,"test":"sha256_verified_archived_native_elf_metadata",
            "archive_name":archive.name,"archive_sha256":checked,
            "archive_compressed_bytes":archive.stat().st_size,
            "libxul":member,"elf_header":elf,"elf_sections":sections,
            "dt_needed":names,"runtime_library_loaded":False,
            "feature_bytes_attributed":False,"source_removal_authorized":False,
            "compressed_package_savings_bytes":None,
            "limitations":[
              "Historical native package not a current-source-matched compiled binary.",
              "DT_NEEDED names are declarations, not verified dependency resolution.",
              "ELF sections can overlap; section sizes are not per-feature removable bytes.",
              "NOBITS virtual section bytes are not equivalent physical file length.",
              "No native execution, linker map, Rust/C++ symbol attribution or alternative build."]}

def self_test():
    fixture=Path("/bin/true")
    if not fixture.is_file():raise ValueError("Missing Linux ELF fixture")
    assert header(readelf(fixture,"-hW"))["class"]=="ELF64"
    assert parse_sections(readelf(fixture,"-SW"))["section_count_excluding_null"]>5
    assert "libc.so.6" in NEEDED.findall(readelf(fixture,"-dW"))
    assert group(".bss")=="writable_or_tls_data"
    with tempfile.TemporaryDirectory(prefix="vulpra-elf-fixtures-") as tmp:
        path=Path(tmp)/"fixture.tar.xz"
        def make(duplicate=False,symlink=False):
            with tarfile.open(path,"w:xz") as tf:
                member=tarfile.TarInfo("./vulpra/libxul.so")
                if symlink:
                    member.type=tarfile.SYMTYPE;member.linkname="/bin/true"
                    tf.addfile(member)
                else:
                    blob=fixture.read_bytes();member.size=len(blob)
                    tf.addfile(member,BytesIO(blob))
                    if duplicate: tf.addfile(member,BytesIO(blob))
            Path(str(path)+".sha256").write_text(
                sha256(path.read_bytes()).hexdigest()+"  "+path.name+"\n")
        make();answer=inspect(path)
        assert answer["libxul"]["logical_bytes"]==fixture.stat().st_size
        assert answer["runtime_library_loaded"] is False
        assert answer["compressed_package_savings_bytes"] is None
        Path(str(path)+".sha256").write_text("0"*64+"  "+path.name+"\n")
        try:inspect(path)
        except ValueError as e:assert "SHA-256 mismatch" in str(e)
        else:raise AssertionError("Tampered archive accepted")
        make(duplicate=True)
        try:inspect(path)
        except ValueError as e:assert "Duplicate" in str(e)
        else:raise AssertionError("Duplicate archive member accepted")
        make(symlink=True)
        try:inspect(path)
        except ValueError as e:assert "regular-file" in str(e)
        else:raise AssertionError("Untrusted symlink accepted")
    return 9

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("archive",nargs="?",type=Path)
    ap.add_argument("--self-test",action="store_true")
    ap.add_argument("--output",type=Path)
    args=ap.parse_args()
    if args.self_test:print("PASS:",self_test(),"ELF/archive/anti-tamper fixture checks")
    if not args.archive:
        if not args.self_test:ap.error("Archive required unless self-test")
        return
    data=inspect(args.archive)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(data,indent=2)+"\n")
    print("PASS: verified real historical libxul ELF without executing binary")
    print("LIBXUL LOGICAL BYTES:",data["libxul"]["logical_bytes"])
    print("DT_NEEDED:",json.dumps(data["dt_needed"]))
    print("ELF SECTION BUCKETS:",json.dumps(data["elf_sections"]["groups"],sort_keys=True))
    print("No feature attribution, new removal, current build or compressed savings")
if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,subprocess.TimeoutExpired,tarfile.TarError) as e:
        print("FAIL native ELF census:",e,file=sys.stderr)
        raise SystemExit(1)
