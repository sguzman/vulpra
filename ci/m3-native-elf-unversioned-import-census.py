#!/usr/bin/env python3
"""Read-only original ELF *unversioned* undefined dynsym / provider-name census.

This complements the existing 4,611 versioned-import name audit, but does not
execute browser code, resolve actual relocations or prove safe source deletions.
"""
from __future__ import annotations
import argparse
from collections import Counter
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

HERE=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location(
    "vulpra_static_versioned_candidate",HERE/"m3-native-elf-symbol-provider-candidates.py")
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Missing original secure symbol inspector")
VERSIONED=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERSIONED)
ELF=VERSIONED.BASE
MAX_SYMS=16000000
# C++ template instantiations in original libxul have mangled names >254 bytes.
# Preserve them without weakening pathname, control-char or output size bounds.
PLAIN_SYMBOL=re.compile(r"[A-Za-z_$?][A-Za-z0-9_.$?+:~%-]{0,8191}\Z")
GROUPS={"libpthread.so.0","libdl.so.2","librt.so.1","libresolv.so.2"}


def all_dynsym(path):
    p=subprocess.run(["readelf","-W","--dyn-syms",str(path)],
                     capture_output=True,text=True,timeout=90,check=False)
    if p.returncode or len(p.stdout)>MAX_SYMS:
        raise ValueError("Bad/oversized original ELF .dynsym metadata")
    undefined=[]
    exports=set()
    for line in p.stdout.splitlines():
        f=line.split()
        if len(f)<8 or not f[0].endswith(":") or not f[0][:-1].isdigit():
            continue
        kind,visibility,index=f[4],f[5],f[6]
        if kind not in ("GLOBAL","WEAK") or visibility not in ("DEFAULT","PROTECTED"):
            continue
        decorated=f[7]
        name=decorated.split("@",1)[0]
        if not PLAIN_SYMBOL.fullmatch(name):
            raise ValueError("Unsupported ELF dynsym spelling: "+repr(decorated[:90]))
        if index=="UND":
            if "@" not in decorated:
                undefined.append((name,kind))
        else:
            # Defined default-version exports also potentially satisfy a plain
            # dynamic symbol import; name match is NOT proof of runtime binding.
            exports.add(name)
    return exports,undefined


def inspect(archive):
    modules=ELF.package_versions(archive)
    if len(modules)!=28:raise ValueError("Wrong immutable compiled source ELF census")
    mod_by_path={m["member"]:m for m in modules}
    original_exports={}
    original_imports={}
    processed=set()
    with tempfile.TemporaryDirectory(prefix="vulpra-unversioned-imports-") as d:
        temp=Path(d)/"current-elf"
        with tarfile.open(archive,"r:xz") as tf:
            for entry in tf:
                if entry.name not in mod_by_path:continue
                if not entry.isfile() or entry.size>ELF.LIMIT_SINGLE or entry.name in processed:
                    raise ValueError("Unsafe original compiled ELF package member")
                processed.add(entry.name)
                stream=tf.extractfile(entry)
                if stream is None:raise ValueError("Missing original compiled ELF stream")
                with temp.open("wb") as f:
                    remaining=entry.size
                    while remaining:
                        chunk=stream.read(min(2*1024*1024,remaining))
                        if not chunk:raise ValueError("Original ELF package truncated")
                        f.write(chunk);remaining-=len(chunk)
                offered,imports=all_dynsym(temp)
                module=mod_by_path[entry.name]
                name=module["library_basename"]
                if name in original_imports:raise ValueError("Duplicated compiled requester ELF basename")
                original_imports[name]=(imports,module["direct_needed"])
                for provider in set((name,module["soname"]))-{None}:
                    if provider in original_exports and original_exports[provider]!=offered:
                        raise ValueError("Conflicting compiled ELF SONAME metadata")
                    original_exports[provider]=offered
                temp.unlink(missing_ok=True)
    if processed!=set(mod_by_path):
        raise ValueError("Incomplete immutable source ELF .dynsym coverage")
    return original_imports,original_exports


def analyze(archive):
    imports,packaged=inspect(archive)
    host=ELF.host_library_paths()
    providers=dict(packaged)
    dependencies={name for _,need in imports.values() for name in need}
    for dep in sorted(dependencies):
        if dep in providers:continue
        candidates=host.get(dep,[])
        if not candidates:providers[dep]=None;continue
        path=candidates[0]
        if "ELF64" not in ELF.readelf(path,"-hW") or "X86-64" not in ELF.readelf(path,"-hW"):
            raise ValueError("Host candidate is wrong ELF architecture")
        providers[dep]=all_dynsym(path)[0]
    libc=providers.get("libc.so.6")
    result=[]
    for req,(rows,needed) in sorted(imports.items()):
        for symbol,kind in rows:
            matches=sorted(provider for provider in needed
                           if providers.get(provider) is not None and symbol in providers[provider])
            consolidated=sorted(provider for provider in needed
                                if provider in GROUPS and libc is not None
                                and symbol in libc and provider not in matches)
            missing=sorted(provider for provider in needed if providers.get(provider) is None)
            classification=("at_least_one_declared_needed_name_candidate" if matches
                            else "glibc_consolidation_name_candidate" if consolidated
                            else "optional_weak_no_direct_name_candidate" if kind=="WEAK"
                            else "no_direct_provider_name_candidate")
            result.append({
                "requester_basename":req,
                "undefined_unversioned_symbol_name":symbol,
                "binding":kind,
                "candidate_class":classification,
                "declared_needed_provider_name_matches":matches,
                "glibc_consolidated_fallback_names":consolidated,
                "direct_needed_host_candidates_unavailable":missing,
            })
    if not result:
        raise ValueError("No unversioned original ELF undefined symbol imports")
    result.sort(key=lambda row:(row["requester_basename"],row["undefined_unversioned_symbol_name"],row["binding"]))
    counts=Counter(row["candidate_class"] for row in result)
    return {
        "schema_version":1,
        "original_native_source_commit":ELF.SOURCE,
        "original_archive_sha256":ELF.ARCHIVE,
        "original_compiled_ELF_members_examined":len(imports),
        "unversioned_undefined_dynamic_symbol_import_occurrences":len(result),
        "unversioned_undefined_dynamic_symbol_imports_weak":sum(x["binding"]=="WEAK" for x in result),
        "unversioned_undefined_dynamic_symbol_imports_global":sum(x["binding"]=="GLOBAL" for x in result),
        "at_least_one_direct_needed_name_candidate":counts["at_least_one_declared_needed_name_candidate"],
        "glibc_consolidation_name_candidate":counts["glibc_consolidation_name_candidate"],
        "optional_weak_no_direct_name_candidate":counts["optional_weak_no_direct_name_candidate"],
        "no_direct_provider_name_candidate":counts["no_direct_provider_name_candidate"],
        "symbol_name_candidates":result,
        "host":"Ubuntu 24.04 x86_64 ldconfig name hints, NOT Arch runtime resolution",
        "versioned_imports_in_this_report":False,
        "direct_DT_NEEDED_only_not_transitive_or_lazy_dlopen":True,
        "runtime_symbol_relocations_proven":False,
        "missing_direct_symbol_candidate_implies_failure":False,
        "host_ldconfig_candidate_is_actual_loader_provider_proven":False,
        "upstream_binaries_executed":False,
        "source_deletion_authorized":False,
        "m3_sixth_gate_closed":False,
    }


def selftest():
    example="""Symbol table '.dynsym' contains 5 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND
     1: 0000000000000000     0 FUNC    GLOBAL DEFAULT UND fake_unversioned
     2: 0000000000000000     0 NOTYPE  WEAK   DEFAULT UND optional_weak
     3: 0000000000000000     0 FUNC    GLOBAL DEFAULT UND printf@GLIBC_2.2.5 (2)
     4: 0000000000004000    64 FUNC    GLOBAL DEFAULT 12 fake_export@@V1
"""
    # Exact readelf token semantics, avoiding an artificial host provider.
    parsed=[l.split() for l in example.splitlines() if re.match(r"^\s+[1-4]:",l)]
    assert len(parsed)==4
    assert [p[7] for p in parsed]==[
        "fake_unversioned","optional_weak","printf@GLIBC_2.2.5","fake_export@@V1"]
    assert PLAIN_SYMBOL.fullmatch("fake_unversioned")
    assert not PLAIN_SYMBOL.fullmatch("../bad")
    return 4


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--archive",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",selftest(),"original unversioned dynamic symbol fixtures")
        if a.archive is None:return
    if not(a.archive and a.output):p.error("--archive and --output required")
    report=analyze(a.archive)
    a.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: original packaged 28-ELF unversioned undefined symbol name census")
    print("TOTAL:",report["unversioned_undefined_dynamic_symbol_import_occurrences"])
    print("PROTECTED LIMIT: static candidate names only; no loader bindings or feature decisions")


if __name__=="__main__":
    try:main()
    except (ValueError,AssertionError,KeyError,OSError) as e:
        print("FAIL: original native unversioned ELF symbol audit:",e,file=sys.stderr)
        raise SystemExit(1)
