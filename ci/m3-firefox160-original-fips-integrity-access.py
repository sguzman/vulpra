#!/usr/bin/env python3
"""Source-pinned Firefox160 NSS FIPS-request file-access witness, in throwaway CI.

Traces only file syscall names with strace on two independent temporary NSS
SQL databases. Exports only exact allowlisted checksum basenames, bounded
counts and original NSS error codes. Raw trace paths/logs/DBs never archived.
No FIPS mode changes outside a disposable runner directory.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

EXPECTED_SOURCE="2887d9de1f69c0e9776413da80e7ba0d1225dd9b"
EXPECTED_TREE="42dd7439a27dde92f89ac5eed13f88117a4d7ab5"
EXPECTED_ARCHIVE="530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb"
ALLOW_CHECKS=("libsoftokn3.chk","libfreeblpriv3.chk")
# No field contains a path, PID, token, timestamp, crypto output or error text.
FIELDS=(
    "original_nss_open","exact_symbols","init","fips","system_fips",
    "internal_slot","internal_key_slot","slot_present","key_slot_present",
    "sha256_mechanism","rng","rng_nonzero","shutdown","softoken_mapped",
    "freebl_mapped","same_slot","init_error",
)
PROBE_PATTERN=re.compile(
    r"^PKCS11_TEMP_FIPS_V1(?: [a-z0-9_]+=-?[0-9]{1,6}){17}$"
)


def run_checked(argv, env=None, outfile=None):
    kwargs={"check":True,"timeout":50}
    if env is not None:
        kwargs["env"]=env
    if outfile is None:
        kwargs["stdout"]=subprocess.DEVNULL
        kwargs["stderr"]=subprocess.DEVNULL
        subprocess.run(argv,**kwargs)
    else:
        with outfile.open("wb") as log:
            kwargs["stdout"]=log
            kwargs["stderr"]=subprocess.STDOUT
            subprocess.run(argv,**kwargs)


def parsed_probe(path):
    if path.stat().st_size>8192:
        raise RuntimeError("private NSS probe output exceeds bounded allowlist")
    line=path.read_text(errors="strict").strip()
    if not PROBE_PATTERN.fullmatch(line):
        raise RuntimeError("invalid original NSS probe output format")
    pairs=dict(token.split("=",1) for token in line.split(" ")[1:])
    if set(pairs)!=set(FIELDS):
        raise RuntimeError("unexpected original NSS probe field")
    values={name:int(pairs[name]) for name in FIELDS}
    if values["original_nss_open"]!=1 or values["exact_symbols"]!=1:
        raise RuntimeError("original packaged NSS symbol ownership not verified")
    return values


def access_witness(path):
    if path.stat().st_size>16_000_000:
        raise RuntimeError("strace private file access log too large")
    attempts={name:0 for name in ALLOW_CHECKS}
    missing={name:0 for name in ALLOW_CHECKS}
    recognized=0
    total_file_syscall_lines=0
    original_softoken_so_syscall_mentions=0
    original_nss_so_syscall_mentions=0
    # strace -e trace=%file writes one line per syscall; only check literal,
    # not export syscall numbers, raw paths, flags, PIDs or directory names.
    for line in path.read_text(errors="replace").splitlines():
        # The real source package must cause library file access under strace.
        # Export only counts, not raw arguments or any per-process identifiers.
        if re.search(r'^(?:(?:\[pid\s+[0-9]+\]|[0-9]+)\s+)?(?:open|openat|openat2|newfstatat|stat|statx|access|faccessat|faccessat2|readlink|readlinkat)\(',line):
            total_file_syscall_lines+=1
        if "libsoftokn3.so" in line:
            original_softoken_so_syscall_mentions+=1
        if "libnss3.so" in line:
            original_nss_so_syscall_mentions+=1
        if not any(s in line for s in ALLOW_CHECKS):
            continue
        recognized+=1
        if recognized>2000:
            raise RuntimeError("too many original FIPS checksum file accesses")
        for name in ALLOW_CHECKS:
            if name not in line:
                continue
            # Only accept the literal .chk as final basename, not e.g. .chk.tmp.
            if not re.search(r'/(?:'+re.escape(name)+r')["]',line):
                continue
            attempts[name]+=1
            if re.search(r"=\s*-1\s+ENOENT(?:\s|$)",line):
                missing[name]+=1
    return attempts,missing,total_file_syscall_lines,original_softoken_so_syscall_mentions,original_nss_so_syscall_mentions


def main():
    if sys.argv[1:]==["--self-test"]:
        assert set(FIELDS)==set("original_nss_open exact_symbols init fips system_fips internal_slot internal_key_slot slot_present key_slot_present sha256_mechanism rng rng_nonzero shutdown softoken_mapped freebl_mapped same_slot init_error".split())
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"trace"
            p.write_text('openat(AT_FDCWD, "/tmp/pkg/libsoftokn3.chk", O_RDONLY) = -1 ENOENT (No such file or directory)\n')
            a,m,_,_,_=access_witness(p)
            assert a["libsoftokn3.chk"]==1 and m["libsoftokn3.chk"]==1
        print("PASS: bounded original NSS FIPS source-error and checksum-only syscall parser")
        return 0
    if len(sys.argv)!=5:
        raise SystemExit("usage: witness.py ORIGINAL_NATIVE_APPDIR ORIGINAL_PROBE ARCHIVE_TAR_XZ REPORT_JSON")
    appdir,probe,archive,report=map(Path,sys.argv[1:])
    if not all(x.is_absolute() for x in (appdir,probe,archive,report)):
        raise RuntimeError("absolute CI paths required")
    if report.exists():
        raise RuntimeError("refusing to replace existing evidence")
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=EXPECTED_ARCHIVE:
        raise RuntimeError("original compiled package checksum changed")
    with tarfile.open(archive,"r:xz") as tar:
        names=[Path(member.name).name for member in tar.getmembers()
               if member.isfile()]
    package_contains={name:name in names for name in ALLOW_CHECKS}
    if any(package_contains.values()):
        raise RuntimeError("original package unexpectedly already includes an integrity check file")
    for name in ("libnss3.so","libsoftokn3.so","libfreeblpriv3.so","libnspr4.so"):
        p=appdir/name
        if not p.is_file() or p.is_symlink() or p.open("rb").read(4)!=b"\x7fELF":
            raise RuntimeError("original packaged NSS ELF missing")
    if not probe.is_file() or not os.access(probe,os.X_OK):
        raise RuntimeError("original NSS source-bound native probe missing")
    if "Name=Vulpra" not in (appdir/"application.ini").read_text().splitlines():
        raise RuntimeError("original Vulpra native browser identity mismatch")
    temp=os.environ["RUNNER_TEMP"]
    evidence=[]
    with tempfile.TemporaryDirectory(prefix="firefox160-fips-access-",dir=temp) as root:
        d=Path(root)
        hostenv=os.environ.copy()
        hostenv.pop("LD_PRELOAD",None)
        hostenv.pop("LD_LIBRARY_PATH",None)
        hostenv.pop("VULPRA_M3_DENY_GROUP",None)
        for name,fips in (("normal",False),("fips_requested",True)):
            db=d/(name+"-sql")
            db.mkdir(mode=0o700)
            run_checked(["certutil","-N","-d",f"sql:{db}","--empty-password"],env=hostenv)
            if fips:
                run_checked(["modutil","-fips","true","-force","-dbdir",f"sql:{db}"],env=hostenv)
                run_checked(["modutil","-chkfips","true","-force","-dbdir",f"sql:{db}"],env=hostenv)
            else:
                run_checked(["modutil","-chkfips","false","-force","-dbdir",f"sql:{db}"],env=hostenv)
            originaldb={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in db.iterdir() if p.is_file()}
            if not all(name in originaldb for name in ("cert9.db","key4.db","pkcs11.txt")):
                raise RuntimeError("temporary SQL database construction incomplete")
            out=d/(name+"-private-probe-out")
            trace=d/(name+"-private-strace-out")
            env=hostenv.copy()
            env["LD_LIBRARY_PATH"]=str(appdir)
            env["HOME"]=str(d)
            env["XDG_DATA_HOME"]=str(d/".local")
            run_checked(["strace","-qq","-f","-e","trace=%file",
                         "-s","256","-o",str(trace),
                         str(probe),str(appdir/"libnss3.so"),f"sql:{db}"],
                        env=env,outfile=out)
            parsed=parsed_probe(out)
            tries,missing,syscalls,softoken_so_mentions,nss_so_mentions=access_witness(trace)
            print("AUDIT: sanitized strace liveness "+name+
                  " file_calls="+str(syscalls)+
                  " softoken_elf_mentions="+str(softoken_so_mentions)+
                  " nss_elf_mentions="+str(nss_so_mentions))
            if syscalls==0 or softoken_so_mentions==0 or nss_so_mentions==0:
                raise RuntimeError("file syscall tracing inactive or missing original NSS binary loading")
            unchanged=all((db/k).is_file() and
                          hashlib.sha256((db/k).read_bytes()).hexdigest()==v
                          for k,v in originaldb.items())
            evidence.append({
                "mode":name,
                "host_modutil_marked_disposable_database_FIPS":fips,
                "original_packaged_NSS_Init_return_code":parsed["init"],
                "original_packaged_NSS_Init_error_code":parsed["init_error"],
                "original_PK11_IsFIPS_observed_or_minus2_if_not_attempted":parsed["fips"],
                "original_packaged_softoken_ELF_mapped":parsed["softoken_mapped"]==1,
                "original_packaged_freebl_ELF_mapped":parsed["freebl_mapped"]==1,
                "actual_file_syscalls_observed_in_source_pinned_original_process":syscalls,
                "original_softoken_so_file_syscall_mentions":softoken_so_mentions,
                "original_nss_so_file_syscall_mentions":nss_so_mentions,
                "actual_softoken_chk_filesystem_attempts":tries["libsoftokn3.chk"],
                "actual_softoken_chk_ENOENT_missing_events":missing["libsoftokn3.chk"],
                "actual_freebl_chk_filesystem_attempts":tries["libfreeblpriv3.chk"],
                "actual_freebl_chk_ENOENT_missing_events":missing["libfreeblpriv3.chk"],
                "temporary_database_bytes_unchanged":unchanged,
                "no_raw_strace_paths_process_ids_keys_or_profiles_archived":True,
            })
    normal, fips=evidence
    reportdata={
        "schema_version":1,
        "status":"original_firefox160_nss_fips_integrity_missing_chk_filesystem_trace",
        "official_firefox160_source_commit":EXPECTED_SOURCE,
        "candidate_vulpra_28_overlay_git_tree":EXPECTED_TREE,
        "original_native_browser_archive_sha256":EXPECTED_ARCHIVE,
        "original_native_build_producer_run":43138458940,
        "diagnostic_harness_commit":os.environ["GITHUB_SHA"],
        "original_native_package_contains_libsoftokn3_chk":package_contains["libsoftokn3.chk"],
        "original_native_package_contains_libfreeblpriv3_chk":package_contains["libfreeblpriv3.chk"],
        "official_NSS_FIPS_integrity_check_source_routing_verified_externally":True,
        "original_NSS_standard_temporary_SQL_baseline_succeeded":
            normal["original_packaged_NSS_Init_return_code"]==0 and
            normal["original_PK11_IsFIPS_observed_or_minus2_if_not_attempted"]==0,
        "original_NSS_FIPS_requested_SQL_Init_failed_device_error":
            fips["original_packaged_NSS_Init_return_code"]==-1 and
            fips["original_packaged_NSS_Init_error_code"]==-8023 and
            fips["original_PK11_IsFIPS_observed_or_minus2_if_not_attempted"]==-2,
        "missing_integrity_chk_is_directly_witnessed_during_FIPS_mode_request":
            fips["actual_softoken_chk_ENOENT_missing_events"]>0 or
            fips["actual_freebl_chk_ENOENT_missing_events"]>0,
        "no_original_chk_files_present_in_byte_preserved_archive":not any(package_contains.values()),
        "both_disposable_profile_database_bytes_unchanged":all(
            e["temporary_database_bytes_unchanged"] for e in evidence),
        "actual_syscall_tracing_executed_and_original_NSS_ELFs_accessed":all(
            e["actual_file_syscalls_observed_in_source_pinned_original_process"]>0 and
            e["original_softoken_so_file_syscall_mentions"]>0 and
            e["original_nss_so_file_syscall_mentions"]>0 for e in evidence),
        "original_NSS_FIPS_mode_worked":False,
        "all_FIPS_selftests_or_integrity_checks_individually_attributed":False,
        "missing_chk_was_proven_the_only_possible_fatal_cause":False,
        "original_FIPS_build_flags_completely_recovered":False,
        "read_only_external_signatures_imported_or_generated":False,
        "host_or_user_NSS_global_system_FIPS_activated":False,
        "full_crypto_FIPS_140_validation_or_certification_proven":False,
        "direct_NSS_FIPS_native_callstack_or_full_Rust_CXX_FFI_closure_proven":False,
        "original_upstream_source_or_native_provider_removal_allowed":False,
        "security_current":False,"release_ready":False,"m3_sixth_gate_closed":False,
        "modes":evidence,
    }
    report.write_text(json.dumps(reportdata,indent=2,sort_keys=True)+"\n")
    for e in evidence:
        print(f"AUDIT: original NSS FIPS filesystem {e['mode']} init={e['original_packaged_NSS_Init_return_code']} error={e['original_packaged_NSS_Init_error_code']} softoken_chk_ENOENT={e['actual_softoken_chk_ENOENT_missing_events']} freebl_chk_ENOENT={e['actual_freebl_chk_ENOENT_missing_events']}")
    if not reportdata["original_NSS_standard_temporary_SQL_baseline_succeeded"]:
        raise RuntimeError("original packaged normal SQL baseline failed")
    if not reportdata["original_NSS_FIPS_requested_SQL_Init_failed_device_error"]:
        raise RuntimeError("expected actual original NSS FIPS-device-error regression witness missing")
    if not reportdata["both_disposable_profile_database_bytes_unchanged"]:
        raise RuntimeError("NSS temporary database changed under read-only FIPS evidence")
    if not reportdata["actual_syscall_tracing_executed_and_original_NSS_ELFs_accessed"]:
        raise RuntimeError("original NSS FIPS syscall witness was not actually captured")
    print("PASS: original packaged Firefox160 NSS SQL FIPS-mode actual syscall observations bounded and privacy-safe")
    return 0


if __name__=="__main__":
    raise SystemExit(main())
