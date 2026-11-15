#!/usr/bin/env python3
"""Readonly original ELF versioned undefined-symbol provider candidates.

Authenticates original browser archive with existing VERNEED inspector before
extracting ELF bytes. Exact candidate dynsym names do not prove actual loader
resolution, symbol semantics, unversioned/weak imports, dlopen or safe deletion.
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

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "vulpra_verneed_contract", HERE / "m3-native-elf-version-contract.py")
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)

FILE = re.compile(r"\bFile:\s+(\S+)\s+Cnt:\s+(\d+)")
AUX = re.compile(r"\bName:\s+(\S+)\s+Flags:\s+\S+\s+Version:\s+(\d+)")
SYMBOL = re.compile(r"[A-Za-z_$?][A-Za-z0-9_.$?+:~%-]{0,254}\Z")
GROUPS = {"libpthread.so.0", "libdl.so.2", "librt.so.1", "libresolv.so.2"}
MAX_DYNSYM_OUTPUT = 16_000_000


def need_indexes(version_text):
    if len(version_text) > 8_000_000:
        raise ValueError("Oversized source ELF version index metadata")
    mode = False
    provider = None
    result = {}
    for line in version_text.splitlines():
        if line.startswith("Version needs section "):
            mode, provider = True, None
        elif line.startswith(("Version symbols section ", "Version definition section ")):
            mode, provider = False, None
        if not mode:
            continue
        m = FILE.search(line)
        if m:
            provider = BASE.safe_name(m.group(1))
        m = AUX.search(line)
        if m:
            if provider is None:
                raise ValueError("Version-index auxiliary entry has no provider")
            ver, index = BASE.safe_name(m.group(1)), int(m.group(2))
            if not 2 <= index <= 32767:
                raise ValueError("Unbounded GNU version index")
            if index in result and result[index] != (provider, ver):
                raise ValueError("Reused GNU version index with conflicting provider")
            result[index] = (provider, ver)
    return result


def dynsym(path):
    output = subprocess.run(
        ["readelf", "-W", "--dyn-syms", str(path)], capture_output=True,
        text=True, timeout=90, check=False
    )
    if output.returncode or len(output.stdout) > MAX_DYNSYM_OUTPUT:
        raise ValueError("Invalid/oversized ELF dynamic symbol table")
    defined = set()
    undefined = []
    for line in output.stdout.splitlines():
        parts = line.split()
        if len(parts) < 8 or not parts[0].endswith(":") or not parts[0][:-1].isdigit():
            continue
        bind, visibility, ndx = parts[4], parts[5], parts[6]
        if bind not in ("GLOBAL", "WEAK") or visibility not in ("DEFAULT", "PROTECTED"):
            continue
        decorated = parts[7]
        if "@" not in decorated:
            continue
        name, version = decorated.split("@", 1)
        version = version.lstrip("@")
        if not SYMBOL.fullmatch(name) or not BASE.NAME.fullmatch(version):
            raise ValueError("Unsupported versioned ELF symbol name")
        if ndx == "UND":
            if len(parts) < 9 or not re.fullmatch(r"\([0-9]+\)", parts[8]):
                raise ValueError("Versioned undefined symbol missing GNU index")
            undefined.append((name, version, int(parts[8][1:-1]), bind))
        else:
            defined.add((name, version))
    return defined, undefined


def inspect_original(archive):
    # First scan checks exact immutable SHA, all 28 ELF headers, archive
    # traversal bounds, DT_NEEDED provenance and VERNEED/VERDEF count sanity.
    source = BASE.package_versions(archive)
    modules_by_path = {m["member"]: m for m in source}
    if len(source) != 28 or len(modules_by_path) != 28:
        raise ValueError("Original compiled package ELF census changed")
    declared = {}
    exports = {}
    seen = set()
    with tempfile.TemporaryDirectory(prefix="vulpra-symbol-static-") as folder:
        probe = Path(folder) / "one-elf"
        with tarfile.open(archive, "r:xz") as tar:
            for member in tar:
                if member.name not in modules_by_path:
                    continue
                if not member.isfile() or member.size > BASE.LIMIT_SINGLE or member.name in seen:
                    raise ValueError("Invalid source ELF archive identity")
                seen.add(member.name)
                stream = tar.extractfile(member)
                if stream is None:
                    raise ValueError("Missing source ELF stream")
                with probe.open("wb") as target:
                    remain = member.size
                    while remain:
                        chunk = stream.read(min(2 * 1024 * 1024, remain))
                        if not chunk:
                            raise ValueError("Truncated source ELF stream")
                        target.write(chunk)
                        remain -= len(chunk)
                indexes = need_indexes(BASE.readelf(probe, "-VW"))
                offered, imported = dynsym(probe)
                module = modules_by_path[member.name]
                basename = module["library_basename"]
                if basename in declared:
                    raise ValueError("Ambiguous packaged ELF requester basename")
                exports[basename] = offered
                if module["soname"]:
                    if module["soname"] in exports and module["soname"] != basename:
                        raise ValueError("Conflicting packaged SONAME")
                    exports[module["soname"]] = offered
                rows = []
                for name, ver, index, bind in imported:
                    key = indexes.get(index)
                    if key is None or key[1] != ver:
                        raise ValueError("GNU imported symbol does not match VERNEED index")
                    if key[0] not in module["direct_needed"]:
                        raise ValueError("GNU symbol provider absent from DT_NEEDED")
                    rows.append((key[0], name, ver, bind))
                declared[basename] = rows
                probe.unlink(missing_ok=True)
    if seen != set(modules_by_path):
        raise ValueError("Incomplete original ELF dynamic symbol inspection")
    return declared, exports, source


def analyze(archive):
    userspace_id, userspace_version, userspace_label = BASE.recorded_userspace()
    imported, packaged_exports, source = inspect_original(archive)
    host_cache = BASE.host_library_paths()
    candidates = dict(packaged_exports)
    for rows in imported.values():
        for provider, _, _, _ in rows:
            if provider in candidates:
                continue
            matches = host_cache.get(provider, [])
            if not matches:
                candidates[provider] = None
                continue
            selected = matches[0]
            hdr = BASE.readelf(selected, "-hW")
            if "ELF64" not in hdr or "X86-64" not in hdr:
                raise ValueError("Invalid host ELF symbol provider candidate")
            candidates[provider] = dynsym(selected)[0]
    if "libc.so.6" not in candidates or candidates["libc.so.6"] is None:
        raise ValueError("No host libc ELF metadata candidate")
    libc = candidates["libc.so.6"]
    findings = []
    for requester, rows in sorted(imported.items()):
        for provider, symbol, version, bind in rows:
            exported = candidates.get(provider)
            if exported is not None and (symbol, version) in exported:
                status = "declared_provider_candidate_export_name_match"
            elif (provider in GROUPS and
                  (symbol, version) in libc):
                status = "modern_glibc_libc_consolidation_export_name_candidate"
            elif exported is None:
                status = "provider_candidate_unavailable"
            else:
                status = "versioned_symbol_candidate_name_not_found"
            findings.append({
                "requester_basename": requester,
                "declared_provider_basename": provider,
                "undefined_symbol": symbol,
                "required_version_name": version,
                "undefined_symbol_bind": bind,
                "candidate_class": status,
            })
    if not findings:
        raise ValueError("No actual source-pinned undefined dynamic symbols")
    findings.sort(key=lambda x: (
        x["requester_basename"], x["declared_provider_basename"],
        x["undefined_symbol"], x["required_version_name"]))
    counts = Counter(f["candidate_class"] for f in findings)
    return {
        "schema_version": 1,
        "original_native_source_commit": BASE.SOURCE,
        "original_archive_sha256": BASE.ARCHIVE,
        "host": userspace_label,
        "scanned_userspace_id": userspace_id,
        "scanned_userspace_version": userspace_version,
        "target_host_kernel_verified": False,
        "original_native_elf_members": len(source),
        "versioned_undefined_dynamic_symbol_imports": len(findings),
        "declared_provider_candidate_export_name_matches": counts[
            "declared_provider_candidate_export_name_match"],
        "modern_glibc_libc_consolidation_name_candidates": counts[
            "modern_glibc_libc_consolidation_export_name_candidate"],
        "provider_candidate_unavailable": counts[
            "provider_candidate_unavailable"],
        "versioned_symbol_candidate_name_not_found": counts[
            "versioned_symbol_candidate_name_not_found"],
        "versioned_import_candidate_details": findings,
        "unversioned_imports_examined": False,
        "weak_symbol_runtime_binding_guaranteed": False,
        "actual_elf_symbol_bindings_resolved": False,
        "host_ldconfig_candidate_is_runtime_selected_proven": False,
        "glibc_merged_symbol_loader_compatibility_proven": False,
        "runtime_dlopen_or_feature_coverage_complete": False,
        "target_arch_hyprland_symbol_abi_proven": False,
        "browser_or_host_elf_executed": False,
        "new_source_removal_authorized": False,
        "m3_sixth_gate_closed": False,
    }



def parse_bare_dynsym(text):
    """Bare undefined imports plus unversioned/default-version name candidates.

    This is not evidence of actual binding: transitive, preloaded, weak or
    dynamic-scope providers may matter independently of DT_NEEDED candidates.
    """
    if len(text) > MAX_DYNSYM_OUTPUT:
        raise ValueError("Oversized ELF dynamic symbol table")
    offered, imported = set(), []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 8 or not parts[0].endswith(":") or not parts[0][:-1].isdigit():
            continue
        bind, visibility, ndx = parts[4], parts[5], parts[6]
        if bind not in ("GLOBAL", "WEAK") or visibility not in ("DEFAULT", "PROTECTED"):
            continue
        decorated = parts[7]
        if "@@" in decorated and ndx != "UND":
            name = decorated.split("@@", 1)[0]  # default version only
        elif "@" not in decorated:
            name = decorated
        else:
            continue  # versioned imports and nondefault exports are separate
        if not SYMBOL.fullmatch(name):
            raise ValueError("Unsupported bare ELF dynamic symbol name: " + repr(name)[:96])
        if ndx == "UND":
            imported.append((name, bind))
        else:
            offered.add(name)
    return offered, imported


def dynsym_bare(path):
    run = subprocess.run(
        ["readelf", "-W", "--dyn-syms", str(path)], capture_output=True,
        text=True, timeout=90, check=False
    )
    if run.returncode or len(run.stdout) > MAX_DYNSYM_OUTPUT:
        raise ValueError("Invalid/oversized bare ELF dynamic symbol table")
    return parse_bare_dynsym(run.stdout)


def inspect_unversioned_original(archive):
    source = BASE.package_versions(archive)  # exact archive SHA and bounds
    modules_by_path = {m["member"]: m for m in source}
    if len(source) != 28 or len(modules_by_path) != 28:
        raise ValueError("Original compiled package ELF census changed")
    imported, exports, seen = {}, {}, set()
    with tempfile.TemporaryDirectory(prefix="vulpra-bare-symbol-static-") as folder:
        probe = Path(folder) / "one-elf"
        with tarfile.open(archive, "r:xz") as tar:
            for member in tar:
                if member.name not in modules_by_path:
                    continue
                if not member.isfile() or member.size > BASE.LIMIT_SINGLE or member.name in seen:
                    raise ValueError("Invalid source ELF archive identity")
                seen.add(member.name)
                stream = tar.extractfile(member)
                if stream is None:
                    raise ValueError("Missing source ELF stream")
                with probe.open("wb") as target:
                    remaining = member.size
                    while remaining:
                        chunk = stream.read(min(2 * 1024 * 1024, remaining))
                        if not chunk:
                            raise ValueError("Truncated source ELF stream")
                        target.write(chunk)
                        remaining -= len(chunk)
                offered, needs = dynsym_bare(probe)
                module = modules_by_path[member.name]
                basename = module["library_basename"]
                if basename in imported:
                    raise ValueError("Ambiguous packaged ELF requester basename")
                if basename in exports and exports[basename] != offered:
                    raise ValueError("Conflicting packaged ELF export candidate")
                imported[basename] = {
                    "direct_needed": module["direct_needed"],
                    "symbols": needs,
                }
                exports[basename] = offered
                if module["soname"]:
                    soname = module["soname"]
                    if soname in exports and exports[soname] != offered:
                        raise ValueError("Conflicting packaged ELF SONAME")
                    exports[soname] = offered
                probe.unlink(missing_ok=True)
    if seen != set(modules_by_path):
        raise ValueError("Incomplete original ELF bare symbol inspection")
    return imported, exports, source


def analyze_unversioned(archive):
    userspace_id, userspace_version, userspace_label = BASE.recorded_userspace()
    imported, packaged_exports, source = inspect_unversioned_original(archive)
    host_cache = BASE.host_library_paths()
    candidates = dict(packaged_exports)
    needed = {provider for request in imported.values()
              for provider in request["direct_needed"]}
    for provider in sorted(needed):
        if provider in candidates:
            continue
        matches = host_cache.get(provider, [])
        if not matches:
            candidates[provider] = None
            continue
        selected = matches[0]
        header = BASE.readelf(selected, "-hW")
        if "ELF64" not in header or "X86-64" not in header:
            raise ValueError("Invalid host bare ELF provider candidate")
        candidates[provider] = dynsym_bare(selected)[0]
    findings = []
    for requester, request in sorted(imported.items()):
        providers = sorted(set(request["direct_needed"]))
        for symbol, bind in request["symbols"]:
            matches = [provider for provider in providers
                       if candidates.get(provider) is not None and
                       symbol in candidates[provider]]
            if matches:
                status = "direct_needed_export_name_candidate"
            elif bind == "WEAK":
                status = "weak_import_without_direct_candidate"
            else:
                status = "strong_import_without_direct_candidate"
            findings.append({
                "requester_basename": requester,
                "undefined_symbol": symbol,
                "undefined_symbol_bind": bind,
                "direct_needed_candidate_provider_basenames": matches,
                "candidate_class": status,
            })
    findings.sort(key=lambda x: (x["requester_basename"],
                                 x["undefined_symbol"],
                                 x["undefined_symbol_bind"]))
    if not findings or len(findings) > 150_000:
        raise ValueError("Invalid original bare undefined-symbol census")
    counts = Counter(f["candidate_class"] for f in findings)
    return {
        "schema_version": 1,
        "original_native_source_commit": BASE.SOURCE,
        "original_archive_sha256": BASE.ARCHIVE,
        "host": userspace_label,
        "scanned_userspace_id": userspace_id,
        "scanned_userspace_version": userspace_version,
        "target_host_kernel_verified": False,
        "original_native_elf_members": len(source),
        "unversioned_undefined_dynamic_symbol_imports": len(findings),
        "direct_needed_export_name_candidates": counts[
            "direct_needed_export_name_candidate"],
        "weak_imports_without_direct_candidate": counts[
            "weak_import_without_direct_candidate"],
        "strong_imports_without_direct_candidate": counts[
            "strong_import_without_direct_candidate"],
        "unversioned_import_candidate_details": findings,
        "unversioned_imports_examined": True,
        "all_unversioned_imports_loader_resolved": False,
        "weak_symbol_runtime_binding_guaranteed": False,
        "actual_elf_symbol_bindings_resolved": False,
        "host_ldconfig_candidate_is_runtime_selected_proven": False,
        "transitive_preload_and_dynamic_scope_complete": False,
        "runtime_dlopen_or_feature_coverage_complete": False,
        "target_arch_hyprland_symbol_abi_proven": False,
        "browser_or_host_elf_executed": False,
        "new_source_removal_authorized": False,
        "m3_sixth_gate_closed": False,
    }


def selftest():
    text = """Version needs section '.gnu.version_r' contains 1 entry:
  0x0030: Version: 1 File: libpthread.so.0 Cnt: 2
  0x0040: Name: GLIBC_2.2.5 Flags: none Version: 7
  0x0050: Name: GLIBC_2.2.5 Flags: none Version: 9
"""
    result = need_indexes(text)
    assert result == {
        7: ("libpthread.so.0", "GLIBC_2.2.5"),
        9: ("libpthread.so.0", "GLIBC_2.2.5")
    }
    for fake in (
        text.replace("File: libpthread.so.0", "File: ../../outside"),
        text.replace("Version: 7", "Version: 0"),
        text.replace("Name: GLIBC_2.2.5", "Name: /private", 1),
        text.replace("Version: 9", "Version: 7").replace(
            "libpthread.so.0 Cnt:", "libpthread.so.0 Cnt:"
        ).replace("0x0050: Name: GLIBC_2.2.5",
                  "0x0050: Name: GLIBC_2.18"),
    ):
        try:
            need_indexes(fake)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid GNU version index mapping accepted")
    sample = """Symbol table '.dynsym' contains 7 entries:
  1: 0000000000000000     0 FUNC GLOBAL DEFAULT UND direct_name
  2: 0000000000000000     0 FUNC WEAK DEFAULT UND optional_name
  3: 0000000000000100     1 FUNC GLOBAL DEFAULT 14 plain_export
  4: 0000000000000200     1 FUNC GLOBAL DEFAULT 14 default_export@@GLIBC_2.34
  5: 0000000000000300     1 FUNC GLOBAL DEFAULT 14 old_export@GLIBC_2.2.5
  6: 0000000000000000     0 FUNC GLOBAL DEFAULT UND indexed@GLIBC_2.34 (2)
"""
    offered, imports = parse_bare_dynsym(sample)
    assert offered == {"plain_export", "default_export"}
    assert imports == [("direct_name", "GLOBAL"), ("optional_name", "WEAK")]
    for malformed in ("!", "/", "bad\\value", "x" * 256):
        try:
            parse_bare_dynsym(sample.replace("direct_name", malformed))
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid bare ELF symbol accepted")
    return 8


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--archive", type=Path)
    p.add_argument("--output", type=Path)
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--mode", choices=("versioned", "unversioned"), default="versioned")
    p.add_argument("--source-commit",
                   choices=["2887d9de1f69c0e9776413da80e7ba0d1225dd9b"])
    p.add_argument("--archive-sha256")
    args = p.parse_args()
    if (args.source_commit is None) != (args.archive_sha256 is None):
        p.error("Opt-in Firefox160 source and native archive SHA must be paired")
    if args.source_commit is not None:
        if not re.fullmatch(r"[0-9a-f]{64}", args.archive_sha256):
            p.error("Invalid exact Firefox160 package SHA-256")
        BASE.SOURCE, BASE.ARCHIVE = args.source_commit, args.archive_sha256
    if args.self_test:
        print("PASS:", selftest(), "spoofed version index/provider fixtures")
        if args.archive is None:
            return
    if args.archive is None or args.output is None:
        p.error("--archive and --output are required")
    report = analyze_unversioned(args.archive) if args.mode == "unversioned" else analyze(args.archive)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    if args.mode == "unversioned":
        print("PASS: authenticated ELF bare undefined symbol candidate census inspected")
        keys = ("original_native_elf_members", "unversioned_undefined_dynamic_symbol_imports",
                "direct_needed_export_name_candidates",
                "weak_imports_without_direct_candidate",
                "strong_imports_without_direct_candidate")
    else:
        print("PASS: authenticated original ELF GNU version-indexed undefined symbols inspected")
        keys = ("original_native_elf_members", "versioned_undefined_dynamic_symbol_imports",
                "declared_provider_candidate_export_name_matches",
                "modern_glibc_libc_consolidation_name_candidates",
                "provider_candidate_unavailable", "versioned_symbol_candidate_name_not_found")
    for key in keys:
        print(key.upper() + ":", report[key])
    print("LIMIT: candidate export names, NOT actual loader binding or ABI closure")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, AssertionError, subprocess.TimeoutExpired,
            subprocess.CalledProcessError, tarfile.TarError) as exc:
        print("FAIL: bounded original ELF symbol candidate audit:", exc, file=sys.stderr)
        raise SystemExit(1)
