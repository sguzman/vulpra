#!/usr/bin/env python3
"""Bounded, read-only ELF VERNEED/VERDEF name inventory for an authenticated native package.

Version-name presence is NOT resolved individual symbols, dlopen coverage,
loader search order, Arch runtime proof, source/feature attribution or removal safety.
Never load a packaged ELF file or retain host filesystem paths.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from hashlib import sha256
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile

SOURCE = "b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
NEEDED = re.compile(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]")
SONAME = re.compile(r"\(SONAME\)\s+Library soname: \[([^\]]+)\]")
VERFILE = re.compile(r"\bFile: (\S+)\s+Cnt: (\d+)")
VERNEED = re.compile(r"\bName: (\S+)\s+Flags:\s+\S+\s+Version:")
VERDEF = re.compile(r"\bRev:\s+\d+\s+Flags:\s+\S+\s+Index:\s+\d+\s+Cnt:\s+\d+\s+Name:\s+(\S+)")
HOSTCACHE = re.compile(r"^\s*(\S+)\s+\(([^)]+)\)\s+=>\s+(/\S+)$")
LIMIT_MEMBERS = 1024
LIMIT_LOGICAL = 512 * 1024 * 1024
LIMIT_SINGLE = 384 * 1024 * 1024
LIMIT_ELFS = 128


def safe_name(name):
    if not isinstance(name, str) or not NAME.fullmatch(name):
        raise ValueError("Unsafe or unbounded ELF symbol/version/library name")
    return name


def readelf(path, option):
    run = subprocess.run(["readelf", option, str(path)], capture_output=True,
                         text=True, timeout=75, check=False)
    if run.returncode or len(run.stdout) > 8_000_000:
        raise ValueError("ELF metadata inspection failed or was oversized")
    return run.stdout


def version_blocks(text):
    if len(text) > 8_000_000:
        raise ValueError("Oversized version metadata")
    mode = None
    file = None
    count = 0
    actual_entries = 0
    needs = defaultdict(set)
    defined = set()
    for line in text.splitlines():
        if line.startswith("Version ") and " section " in line:
            if mode == "needs" and file is not None and count != actual_entries:
                raise ValueError("VERNEED count inconsistent at section boundary")
        if line.startswith("Version needs section "):
            mode, file, count, actual_entries = "needs", None, 0, 0
        elif line.startswith("Version definition section "):
            mode, file, count, actual_entries = "defs", None, 0, 0
        elif line.startswith("Version symbols section "):
            mode, file, count, actual_entries = None, None, 0, 0
        if mode == "needs":
            m = VERFILE.search(line)
            if m:
                if file is not None and count != actual_entries:
                    raise ValueError("VERNEED file count inconsistent")
                file = safe_name(m.group(1))
                count = int(m.group(2))
                actual_entries = 0
                if not 0 <= count <= 1024:
                    raise ValueError("Unbounded VERNEED count")
            m = VERNEED.search(line)
            if m:
                if file is None:
                    raise ValueError("Version need without provider")
                ver = safe_name(m.group(1))
                # Real Firefox/NSS ELF metadata can repeat one version label
                # in the same provider group; Cnt counts Vernaux entries,
                # while the report is a deduplicated set of name contracts.
                actual_entries += 1
                needs[file].add(ver)
        elif mode == "defs":
            m = VERDEF.search(line)
            if m:
                defined.add(safe_name(m.group(1)))
    if mode == "needs" and file is not None and count != actual_entries:
        raise ValueError("Last VERNEED file count inconsistent")
    return {k: sorted(v) for k, v in sorted(needs.items())}, sorted(defined)


def host_library_paths():
    cmd = "/sbin/ldconfig"
    run = subprocess.run([cmd, "-p"], capture_output=True, text=True,
                         timeout=25, check=True)
    cache = defaultdict(list)
    for line in run.stdout.splitlines():
        m = HOSTCACHE.match(line)
        if not m or "x86-64" not in m.group(2):
            continue
        name, path = m.group(1), Path(m.group(3))
        if not NAME.fullmatch(name):
            continue
        # Ubuntu cache paths are trusted *hints*, not proven loader choices.
        if path.is_file() and path.is_absolute():
            cache[name].append(path)
    return cache


def package_versions(archive_path):
    if archive_path.stat().st_size > 150_000_000:
        raise ValueError("Archive exceeds pinned size bound")
    digest = sha256()
    with archive_path.open("rb") as stream:
        for piece in iter(lambda: stream.read(2 * 1024 * 1024), b""):
            digest.update(piece)
    if digest.hexdigest() != ARCHIVE:
        raise ValueError("Wrong source-pinned full-normal archive SHA-256")
    members = []
    seen = set()
    total = 0
    count = 0
    with tempfile.TemporaryDirectory(prefix="vulpra-abi-static-") as directory:
        probe = Path(directory) / "one-elf"
        with tarfile.open(archive_path, "r:xz") as tf:
            for member in tf:
                count += 1
                if count > LIMIT_MEMBERS:
                    raise ValueError("Unbounded archive member count")
                posix = PurePosixPath(member.name)
                if (member.name in seen or posix.is_absolute() or ".." in posix.parts or
                    len(member.name) > 255):
                    raise ValueError("Unsafe/duplicate package path")
                seen.add(member.name)
                if not member.isfile():
                    continue
                total += member.size
                if member.size < 0 or member.size > LIMIT_SINGLE or total > LIMIT_LOGICAL:
                    raise ValueError("Oversized archived package member")
                stream = tf.extractfile(member)
                if stream is None:
                    raise ValueError("Unreadable archive member")
                first = stream.read(4)
                if first != b"\x7fELF":
                    continue
                if len(members) >= LIMIT_ELFS:
                    raise ValueError("Unbounded native ELF member count")
                with probe.open("wb") as target:
                    target.write(first)
                    remain = member.size - len(first)
                    while remain:
                        part = stream.read(min(2 * 1024 * 1024, remain))
                        if not part:
                            raise ValueError("Truncated archive ELF")
                        target.write(part)
                        remain -= len(part)
                header = readelf(probe, "-hW")
                if "ELF64" not in header or "X86-64" not in header:
                    raise ValueError("Unexpected package ELF architecture")
                dynamic = readelf(probe, "-dW")
                names = [safe_name(x) for x in NEEDED.findall(dynamic)]
                sonames = [safe_name(x) for x in SONAME.findall(dynamic)]
                if len(names) != len(set(names)) or len(sonames) > 1:
                    raise ValueError("Duplicate dynamic dependency or SONAME")
                needs, defined = version_blocks(readelf(probe, "-VW"))
                if set(needs) - set(names):
                    raise ValueError("VERNEED references a library not in DT_NEEDED")
                members.append({
                    "member": member.name,
                    "library_basename": safe_name(posix.name),
                    "soname": sonames[0] if sonames else None,
                    "direct_needed": names,
                    "version_needs": needs,
                    "version_definitions": defined
                })
                probe.unlink(missing_ok=True)
    if not any(m["library_basename"] == "libxul.so" for m in members):
        raise ValueError("Missing original native libxul.so")
    return members


def analyze(archive_path):
    modules = package_versions(archive_path)
    providers = defaultdict(list)
    for member in modules:
        for key in {member["library_basename"], member["soname"]} - {None}:
            providers[key].append(member)
    cache = host_library_paths()
    host_definitions = {}
    rows = []
    for module in modules:
        for provider, versions in module["version_needs"].items():
            package = providers.get(provider, [])
            if len(package) > 1:
                raise ValueError("Ambiguous packaged SONAME provider")
            scope = "packaged_declared_version_names" if package else "host_ldconfig_candidate_version_names"
            if package:
                offered = set(package[0]["version_definitions"])
            else:
                if provider not in host_definitions:
                    candidates = cache.get(provider, [])
                    if candidates:
                        selected = candidates[0]
                        hdr = readelf(selected, "-hW")
                        if "ELF64" not in hdr or "X86-64" not in hdr:
                            raise ValueError("Host ELF candidate architecture invalid")
                        host_definitions[provider] = set(version_blocks(readelf(selected, "-VW"))[1])
                    else:
                        host_definitions[provider] = None
                offered = host_definitions[provider]
            for version in versions:
                rows.append({
                    "requester_basename": module["library_basename"],
                    "provider_basename": provider,
                    "version_name": version,
                    "candidate_scope": scope,
                    "version_name_present_in_candidate": None if offered is None else version in offered
                })
    if not rows:
        raise ValueError("Real packaged ELF had no versioned symbol requirements")
    rows.sort(key=lambda r: (r["requester_basename"], r["provider_basename"], r["version_name"]))
    return {
        "schema_version": 1,
        "source_commit": SOURCE,
        "original_archive_sha256": ARCHIVE,
        "host": "GitHub Actions Ubuntu 24.04 x86_64 (not user's Arch/Hyprland)",
        "scanned_native_elf_files": len(modules),
        "native_elf_declared_version_requirements": len(rows),
        "unique_version_provider_basenames": len({r["provider_basename"] for r in rows}),
        "candidate_version_name_present_count": sum(r["version_name_present_in_candidate"] is True for r in rows),
        "candidate_version_name_absent_count": sum(r["version_name_present_in_candidate"] is False for r in rows),
        "candidate_version_name_unavailable_count": sum(r["version_name_present_in_candidate"] is None for r in rows),
        "requirements": rows,
        "native_binaries_executed": False,
        "ldd_or_dynamic_loader_executed": False,
        "actual_symbol_resolution_proven": False,
        "loader_search_path_proven": False,
        "host_provider_is_runtime_selected_proven": False,
        "dlopen_graph_complete": False,
        "source_feature_attribution_proven": False,
        "target_arch_hyprland_abi_proven": False,
        "safe_source_removal_authorized": False,
        "m3_sixth_gate_closed": False
    }


def selftest():
    good = """Version symbols section '.gnu.version' contains 3 entries:
Version needs section '.gnu.version_r' contains 1 entry:
  0x0010: Version: 1  File: libc.so.6  Cnt: 2
  0x0020:   Name: GLIBC_2.34  Flags: none  Version: 3
  0x0030:   Name: GLIBC_2.2.5  Flags: none  Version: 2
Version definition section '.gnu.version_d' contains 2 entries:
  0x0010: Rev: 1  Flags: BASE  Index: 1  Cnt: 1  Name: libxul.so
  0x0020: Rev: 1  Flags: none  Index: 2  Cnt: 1  Name: SOME_1.0
"""
    needs, defs = version_blocks(good)
    assert needs == {"libc.so.6": ["GLIBC_2.2.5", "GLIBC_2.34"]}
    assert defs == ["SOME_1.0", "libxul.so"]
    duplicate_elf_aux = good.replace(
        "Cnt: 2", "Cnt: 3", 1
    ).replace(
        "  0x0030:   Name: GLIBC_2.2.5  Flags: none  Version: 2",
        "  0x0030:   Name: GLIBC_2.2.5  Flags: none  Version: 2\\n"
        "  0x0040:   Name: GLIBC_2.34  Flags: none  Version: 4"
    )
    assert version_blocks(duplicate_elf_aux)[0] == needs
    for fake in (
        good.replace("Cnt: 2", "Cnt: 3", 1),
        good.replace("File: libc.so.6", "File: ../../secret"),
        good.replace("Name: GLIBC_2.34", "Name: ../../private"),
        good.replace("Name: GLIBC_2.34", "Name: ../../hidden"),
        "Version needs section '.gnu.version_r'\n  Name: GLIBC_2.2.5  Flags: none  Version: 3",
    ):
        try:
            version_blocks(fake)
        except ValueError:
            pass
        else:
            raise AssertionError("Spoofed version metadata accepted")
    return 5


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        print("PASS:", selftest(), "malformed version provenance fixtures rejected")
        if args.archive is None:
            return
    if args.archive is None or args.output is None:
        parser.error("--archive and --output required for native ABI audit")
    report = analyze(args.archive)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print("PASS: SHA256-authenticated original native package readelf version metadata")
    print("PACKAGED ELF:", report["scanned_native_elf_files"])
    print("VERNEED REQUIREMENTS:", report["native_elf_declared_version_requirements"])
    print("VERSION NAME CANDIDATE PRESENT / ABSENT / UNAVAILABLE:",
          report["candidate_version_name_present_count"],
          report["candidate_version_name_absent_count"],
          report["candidate_version_name_unavailable_count"])
    print("LIMIT: name-level static host candidates, never actual ABI/symbol resolution or source removal")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, AssertionError, subprocess.TimeoutExpired,
            subprocess.CalledProcessError, tarfile.TarError) as exc:
        print("FAIL: source-pinned native version inventory:", exc, file=sys.stderr)
        raise SystemExit(1)
