#!/usr/bin/env python3
"""Reconcile actual loader version checks of original mozinference with immutable ELF census.

Not model inference, browser ML integration, complete symbol binding, or permission to debloat.
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
TRACE = re.compile(r"mozinference-loader\.[0-9]+\Z")
CHECK = re.compile(r"checking for version [\x60']([^']+)' in file (\S+) \[\d+\] required by file (\S+) \[\d+\]")


def basename(raw):
    value = raw.rsplit("/", 1)[-1]
    if not SAFE.fullmatch(value):
        raise ValueError("Untrusted ELF basename")
    return value


def static_contracts(doc):
    if not isinstance(doc, dict) or any((
        doc.get("schema_version") != 1,
        doc.get("source_commit") != SOURCE,
        doc.get("original_archive_sha256") != ARCHIVE,
        doc.get("scanned_native_elf_files") != 28,
        doc.get("native_elf_declared_version_requirements") != 519,
        doc.get("actual_symbol_resolution_proven") is not False,
        doc.get("m3_sixth_gate_closed") is not False,
    )):
        raise ValueError("Unverified original native ELF census provenance")
    rows = doc.get("requirements")
    if not isinstance(rows, list) or len(rows) != 519:
        raise ValueError("Unbounded or incomplete original ELF requirements")
    keys = set()
    for row in rows:
        if not isinstance(row, dict) or row.get("version_name_present_in_candidate") is not True:
            raise ValueError("Non-authenticated original ELF requirement")
        triple = tuple(row.get(k) for k in (
            "requester_basename", "provider_basename", "version_name"))
        if any(not isinstance(s, str) or not SAFE.fullmatch(s) for s in triple):
            raise ValueError("Untrusted original ELF contract")
        if triple in keys:
            raise ValueError("Duplicate original ELF version contract")
        keys.add(triple)
    expected = {triple for triple in keys if triple[0] == "libmozinference.so"}
    if len(expected) != 24:
        raise ValueError("Unexpected compiled original mozinference contract count")
    return expected


def inspect(folder, expected):
    traces = [p for p in folder.iterdir() if p.is_file() and TRACE.fullmatch(p.name)]
    if not 1 <= len(traces) <= 8:
        raise ValueError("Expected bounded real mozinference loader trace")
    observed = set()
    extra = set()
    for path in traces:
        if not 0 < path.stat().st_size <= 10_000_000:
            raise ValueError("Invalid loader trace size")
        for line in path.read_text(errors="replace").splitlines():
            hit = CHECK.search(line)
            if hit is None:
                continue
            triple = (basename(hit.group(3)), basename(hit.group(2)), basename(hit.group(1)))
            if triple[0] != "libmozinference.so":
                continue
            if triple in expected:
                observed.add(triple)
            else:
                extra.add(triple)
    if not observed or extra:
        raise ValueError("No original library loader checks or foreign checks encountered")
    if observed != expected:
        raise ValueError("Some original compiled mozinference ELF version checks were absent")
    return {
        "schema_version": 1,
        "original_native_compiled_source": SOURCE,
        "original_native_archive_sha256": ARCHIVE,
        "feature_probe": "original_mozinference_llama_backend_C_API_no_egress",
        "real_original_libmozinference_dlopen_and_llama_api_invoked": True,
        "original_mozinference_version_contracts": len(expected),
        "observed_original_mozinference_version_checks": len(observed),
        "not_observed_original_mozinference_version_checks": len(expected - observed),
        "observed_original_version_contracts": [
            {"requester_basename": a, "provider_basename": b, "version_name": c}
            for a, b, c in sorted(observed)],
        "model_loaded_or_inference_performed": False,
        "browser_ml_integration_tested": False,
        "external_network_or_user_profile_accessed": False,
        "raw_loader_paths_and_pids_retained": False,
        "complete_runtime_symbol_binding_proven": False,
        "safe_source_pruning_authorized": False,
        "m3_sixth_gate_closed": False,
    }


def selftest():
    expected = {("libmozinference.so", "libc.so.6", "GLIBC_2.2.5")}
    good = "  42: checking for version \x60GLIBC_2.2.5' in file /lib/libc.so.6 [0] required by file /pkg/libmozinference.so [0]\n"
    with tempfile.TemporaryDirectory() as tmp:
        f = Path(tmp) / "mozinference-loader.42"
        f.write_text(good)
        assert inspect(Path(tmp), expected)["observed_original_mozinference_version_checks"] == 1
        for invalid in (
            good.replace("GLIBC_2.2.5", "GLIBC_999"),
            good.replace("libmozinference.so", "different.so"),
            good.replace("/lib/libc.so.6", "/bad/lib!c.so.6"),
        ):
            f.write_text(invalid)
            try:
                inspect(Path(tmp), expected)
            except ValueError:
                pass
            else:
                raise AssertionError("Forged loader record was accepted")
    return 3


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--traces", type=Path)
    cli.add_argument("--static", type=Path)
    cli.add_argument("--output", type=Path)
    cli.add_argument("--self-test", action="store_true")
    args = cli.parse_args()
    if args.self_test:
        print("PASS:", selftest(), "adversarial mozinference loader trace fixtures")
        if args.traces is None:
            return
    if not (args.traces and args.static and args.output):
        cli.error("--traces, --static and --output required")
    result = inspect(args.traces, static_contracts(json.loads(args.static.read_text())))
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: original compiled mozinference C API activation and all 24 GNU version checks")
    print("LIMIT: no model, no browser ML integration, no source removal")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, AssertionError, OSError, KeyError) as error:
        print("FAIL: original native inference ABI audit:", error, file=sys.stderr)
        raise SystemExit(1)
