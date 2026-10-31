#!/usr/bin/env python3
"""Original packaged ClearKey negative CDM call: strict source-pinned ELF ABI records.

No media keys, decrypt, EME browser integration, DRM bypass, or source removal.
"""
import argparse
import json
from pathlib import Path
import re
import sys
import tempfile

SOURCE = "b1482404dfb8b01342990ee99ea3df0f9756b5f7"
ARCHIVE = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a"
SAFE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.+\-]{0,127}\Z")
TRACE = re.compile(r"clearkey-loader\.[0-9]+\Z")
CHECK = re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def basename(raw):
    name = raw.rsplit("/", 1)[-1]
    if not SAFE.fullmatch(name):
        raise ValueError("Non-basename ELF identity in loader trace")
    return name


def expected_contracts(doc):
    if not isinstance(doc, dict) or any((
        doc.get("schema_version") != 1,
        doc.get("source_commit") != SOURCE,
        doc.get("original_archive_sha256") != ARCHIVE,
        doc.get("scanned_native_elf_files") != 28,
        doc.get("native_elf_declared_version_requirements") != 519,
        doc.get("actual_symbol_resolution_proven") is not False,
        doc.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Untrusted source-pinned original GNU ELF census")
    rows = doc.get("requirements")
    if not isinstance(rows, list) or len(rows) != 519:
        raise ValueError("Incomplete or unbounded static original ELF contracts")
    triples = set()
    for row in rows:
        if not isinstance(row, dict) or row.get("version_name_present_in_candidate") is not True:
            raise ValueError("Unverified ELF version provider candidate")
        triple = tuple(row.get(k) for k in (
            "requester_basename", "provider_basename", "version_name"))
        if any(not isinstance(v, str) or not SAFE.fullmatch(v) for v in triple):
            raise ValueError("Unsafe static native ELF identities")
        if triple in triples:
            raise ValueError("Duplicate original static ELF version triple")
        triples.add(triple)
    expected = {t for t in triples if t[0] == "libclearkey.so"}
    if len(expected) != 14:
        raise ValueError("Wrong original ClearKey GNU version contract count")
    return expected


def inspect(folder, expected):
    paths = [p for p in folder.iterdir() if p.is_file() and TRACE.fullmatch(p.name)]
    if not 1 <= len(paths) <= 8:
        raise ValueError("No bounded real native ClearKey loader traces")
    seen = set()
    foreign = set()
    for path in paths:
        if not 0 < path.stat().st_size <= 10_000_000:
            raise ValueError("Bad actual ClearKey ELF loader trace bounds")
        for line in path.read_text(errors="replace").splitlines():
            match = CHECK.search(line)
            if not match:
                continue
            triple = (basename(match.group(3)), basename(match.group(2)), basename(match.group(1)))
            if triple[0] != "libclearkey.so":
                continue
            if triple in expected:
                seen.add(triple)
            else:
                foreign.add(triple)
    if seen != expected or foreign:
        raise ValueError("Original ClearKey ELF loader checks missing or foreign")
    return {
        "schema_version": 1,
        "original_native_compiled_source": SOURCE,
        "original_native_archive_sha256": ARCHIVE,
        "feature_probe": "original_clearkey_CDM_invalid_interface_no_egress",
        "real_original_libclearkey_dlopen_and_invalid_CDM_version_rejected": True,
        "original_clearkey_version_contracts": len(expected),
        "observed_original_clearkey_version_checks": len(seen),
        "not_observed_original_clearkey_version_checks": len(expected - seen),
        "observed_original_version_contracts": [
            {"requester_basename": a, "provider_basename": b, "version_name": c}
            for a, b, c in sorted(seen)],
        "real_EME_playback_or_decryption_tested": False,
        "valid_CDM_session_created": False,
        "user_media_or_keys_used": False,
        "browser_CDM_host_integration_verified": False,
        "external_network_or_user_data_accessed": False,
        "raw_loader_paths_and_pids_retained": False,
        "complete_runtime_symbol_binding_proven": False,
        "safe_source_pruning_authorized": False,
        "m3_sixth_gate_closed": False,
    }


def selftest():
    expected = {("libclearkey.so", "libc.so.6", "GLIBC_2.2.5")}
    good = "  42: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /pkg/libclearkey.so [0]\n"
    with tempfile.TemporaryDirectory() as tmp:
        file = Path(tmp) / "clearkey-loader.42"
        file.write_text(good)
        assert inspect(Path(tmp), expected)["observed_original_clearkey_version_checks"] == 1
        for bad in (
            good.replace("GLIBC_2.2.5", "GLIBC_999"),
            good.replace("libclearkey.so", "different.so"),
            good.replace("/lib/libc.so.6", "/bad/l!bc.so.6"),
        ):
            file.write_text(bad)
            try:
                inspect(Path(tmp), expected)
            except ValueError:
                pass
            else:
                raise AssertionError("Forged ClearKey ELF runtime trace accepted")
    return 3


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--traces", type=Path)
    cli.add_argument("--static", type=Path)
    cli.add_argument("--output", type=Path)
    cli.add_argument("--self-test", action="store_true")
    args = cli.parse_args()
    if args.self_test:
        print("PASS:", selftest(), "adversarial ClearKey GNU loader trace fixtures")
        if args.traces is None:
            return
    if not (args.traces and args.static and args.output):
        cli.error("--traces, --static and --output required")
    result = inspect(args.traces, expected_contracts(json.loads(args.static.read_text())))
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: original native ClearKey negative CDM ABI and 14/14 compiled version checks")
    print("LIMIT: no EME playback, keys, session, integration or source removal")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, AssertionError, KeyError) as error:
        print("FAIL: original ClearKey CDM ELF evidence:", error, file=sys.stderr)
        raise SystemExit(1)
