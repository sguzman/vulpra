# Firefox 160: FIPS initialization returns a device error before any observed NSS integrity-check file access

**Date:** 2026-11-15. **Result:** [Actual original packaged Firefox160 NSS file syscall replay 43769978149 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43769978149), independently source-authenticated by [CI 43770330414 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43770330414). The original NSS runtime fails to initialize a FIPS-marked disposable SQL database with **`SEC_ERROR_PKCS11_DEVICE_ERROR = −8023`**, but the observed test **did not attempt to open any `libsoftokn3.chk` or `libfreeblpriv3.chk` file** before that failure. These checksum files are also absent from the preserved compiled archive. **Do not infer that an actual failed `.chk` open caused the observed failure**; the precise earlier failing check and compile-time FIPS flag remain unproven.

## Exact original source and compiled package

The audit examined the byte-identical browser package built and preserved across all M3 Firefox160 native tests:

- Official Mozilla Firefox160 source commit `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Complete assembled Vulpra candidate tree with 28 overlays `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`.
- Original packaged browser archive SHA-256 `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Original compiled producer [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), immutable byte preservation [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827). No browser, source or NSS provider was recompiled, edited or deleted.

A new [integrity syscall probe](../../ci/m3-firefox160-original-fips-integrity-access.py) authenticated the original complete compressed archive SHA itself and checked its actual member list before extraction. It found both original `libsoftokn3.so` and `libfreeblpriv3.so`, but **zero `libsoftokn3.chk` and `libfreeblpriv3.chk` files**. The missing files are a genuine distribution/packaging property of this preserved original browser package. They are not evidence, by themselves, that a specific `open()` failed in the observed test.

### Original Mozilla source FIPS control flow

The original Firefox160 source was rechecked by exact Mozilla Git blob hashes, in the workflow and independently in the evidence-only verifier. The relevant sources are:

| Original source file | Exact Git blob SHA (abbreviated) | Material result |
| --- | --- | --- |
| `security/nss/lib/softoken/fipstokn.c` | `4f5a4c9...` | `FC_Initialize()` calls `sftk_FIPSEntryOK(rerun)` **before** `nsc_CommonInitialize(..., PR_TRUE)`; returns early on non-OK |
| `security/nss/lib/softoken/fipstest.c` | `cd444f9...` | FIPS startup/self-test gate; the active implementation returns `CKR_DEVICE_ERROR` if startup tests have not succeeded. A separately compiled `NSS_FIPS_DISABLED` branch always returns `CKR_DEVICE_ERROR` |
| `security/nss/lib/softoken/pkcs11.c` | `542da0b...` | General softoken initialization; FIPS entry must pass before this path |
| `security/nss/lib/freebl/shvfy.c` | `4743eb4...` | Integrity helper derives the companion check file using `mkCheckFileName` and opens it through `PR_Open(checkName, PR_RDONLY, 0)`; missing check file would fail verification **if this stage were reached** |
| `security/nss/lib/freebl/shsign.h` | `d1a595a...` | Exact integrity-file suffix `SGN_SUFFIX = ".chk"` |
| `security/nss/lib/util/secerr.h` | `5b7c9cc...` | `SEC_ERROR_PKCS11_DEVICE_ERROR = −8023` |
| `nsprpub/pr/include/prerr.h` | `28bf6d7...` | `PR_LOAD_LIBRARY_ERROR = −5977` |

The exact original [NSS build configuration documentation](https://github.com/mozilla-firefox/firefox/blob/2887d9de1f69c0e9776413da80e7ba0d1225dd9b/security/nss/readme.md) (blob `cecbf0f1f6287f435353f39fb77cda7f04e00d73`) states that **gyp-based NSS builds normally define `NSS_FIPS_DISABLED` unless explicitly configured otherwise**. This makes a compile-time disabled-FIPS path **plausible**, but the current diagnostic has **not recovered that macro from the actual compiled Firefox160 ELF**. Neither this documentation nor the absence of `.chk` files proves which path executed in the preserved binary. The source documents a `nss-build-flags` helper, but no authentic exact-original build-flags output was recovered in this test.

Reference: [NSS technical note on .chk integrity files](https://nss-crypto.org/reference/security/nss/legacy/nss_tech_notes/nss_tech_note6/index.html). An integrity file can be necessary for a specific FIPS-capable build without being the observed first failure here.

## Executed real original-library syscall witness

The [actual CI run 43769978149](https://github.com/sguzman/vulpra/actions/runs/43769978149) staged the exact original compiled archive on a disposable Ubuntu 24.04 GitHub runner, compiled only the small existing C NSS readout probe (not original NSS), and installed `strace` and host `certutil`/`modutil` for temporary database preparation. It used **two fresh SQL NSS databases**, under restrictive throwaway `RUNNER_TEMP` paths:

1. **Normal SQL database:** constructed by host `certutil`; host `modutil -chkfips false` confirmed its local DB setting; the *original packaged* `libnss3.so` executed `NSS_Init`.
2. **FIPS-requested SQL database:** constructed separately by host `certutil`; host `modutil -fips true -force -dbdir sql:<temporary-path>` set **only that temporary DB's** FIPS marker, checked by `modutil -chkfips true`. The original packaged `libnss3.so` was then executed with the exact same source-bound probe.

Each original native process was placed under `strace -f -e trace=%file`; the tracer captured *real filesystem syscalls*, including attempts to load original NSS and softoken. An output-allowlisted standard-library Python parser consumed the raw trace within the private temporary directory and exported **only fixed literal original provider basenames, counts and numeric NSS return codes**. It required actual NSS library filename references and positive filesystem syscall totals before accepting an absence of `.chk` accesses. No raw syscall arguments, filesystem paths, PIDs, private NSS SQL database contents, keys, certs, passwords, host logs or user profiles were archived. Temporary DB file hashes were checked unchanged, and all private traces, DBs and temporary files were deleted.

### Exact observed native results

| Verified observation | Normal SQL database | FIPS-marked SQL database |
| --- | --- | --- |
| Original packaged `NSS_Init` result | **0 (success)** | **−1 (failure)** |
| Original NSS error immediately after init | **0** | **−8023 — PKCS#11 device error** |
| `PK11_IsFIPS` readout | **0, non-FIPS** | **Not called** (init failed) |
| Actual filesystem syscalls captured | **254** | **194** |
| Actual original `libnss3.so` filename references | **24** | **24** |
| Actual original `libsoftokn3.so` filename references | **2** | **2** |
| `libsoftokn3.chk` attempted accesses | **0** | **0** |
| `libsoftokn3.chk` `ENOENT` errors | **0** | **0** |
| `libfreeblpriv3.chk` attempted accesses | **0** | **0** |
| `libfreeblpriv3.chk` `ENOENT` errors | **0** | **0** |
| Original `libsoftokn3.so` mapped at probe snapshot | Yes | **Yes** |
| Original `libfreeblpriv3.so` mapped at probe snapshot | Yes | **No** |
| Temporary SQL DB bytes modified by original probe | **No** | **No** |

These results firmly establish actual file syscall tracing was active in **both processes**, even though the original FIPS-requested NSS path returned `−8023` without attempting a filesystem access to either missing `.chk` file.

Importantly, **zero `.chk` attempts does not prove which internal FIPS self-test or compiled preprocessor branch failed**. It does exclude a directly witnessed `openat`/`stat` `ENOENT` of the companion FIPS files as the immediate observed cause. A build-time FIPS-disabled early branch or an earlier startup failure remains possible. The runtime also does **not** establish that adding `.chk` files alone would repair initialization. We did not attempt to generate, import or attach external checksum files to these original NSS libraries.

The [first tracer run 43769534998](https://github.com/sguzman/vulpra/actions/runs/43769534998) captured the initial no-checksum evidence. A subsequent strict-liveness run [43769797943](https://github.com/sguzman/vulpra/actions/runs/43769797943) rejected its own evidence because the parser had not recognized the tracer's prefixed process format. The revised parser **requires** real file syscalls and original NSS/softoken library access witnesses, and only [successful 43769978149](https://github.com/sguzman/vulpra/actions/runs/43769978149) is accepted as the final source/preserved-binary filesystem probe. Its artifact `firefox160-original-fips-chk-file-access-witness-not-FIPS-success`, ID **14183787791**, was downloaded and inspected.

## Independent immutable source/runtime/trace reconciliation

[Independent verifier CI 43770330414 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43770330414) authenticated by full Git commit, workflow name, branch, successful conclusion and exact unexpired artifacts:

- The previous source-attested [actual original FIPS request device-error crosswalk 43767128907](https://github.com/sguzman/vulpra/actions/runs/43767128907), which itself authenticates source-pinned successful **non-FIPS PKCS#11 and trusted localhost TLS** and original failed temporary FIPS-mode initialization;
- The current exact archive/source-backed [real original file syscall run 43769978149](https://github.com/sguzman/vulpra/actions/runs/43769978149), including the actual source-defined `.chk` suffix and original `FC_Initialize`/startup guard ordering.

The strict [original NSS FIPS source/trace jq crosswalk](../../ci/m3-firefox160-fips-integrity-source-trace-crosswalk.jq) requires the exact original compiled archive hash, all observed syscall counts, real ELF file references, `−8023`, **zero** attempted `.chk` accesses and errors, the missing original archive `.chk` files, unchanged disposable DBs and explicit false success/root-cause/FFI-complete/security/release claims. **All 16/16 deliberately falsified source, checksum, FIPS success, syscall trace liveness, invented `.chk` accesses, false causal attribution and milestone-completion records were rejected.**

The accepted bounded independent artifact `firefox160-original-source-attested-fips-device-error-before-chk-access`, ID **14183657611**, was downloaded and inspected.

## Acceptance limits and next useful diagnosis

We **have not identified** the actual C preprocessor configuration used for `NSS_FIPS_DISABLED` in the original Linux build, any specific failed startup KAT/integrity-test substep, or the machine instruction/stack triggering the error. Recreating the exact producer build flags or finding the authentic `nss-build-flags` output could resolve the build-time possibility without rebuilding the original browser. Disassembly of the preserved original softoken constructor/`FC_Initialize` entry may help, but should be treated as bounded binary evidence, not presumed source equivalence.

**Nothing in this diagnostic authorizes** removing softoken or FreeBL, forcing a FIPS module into service, modifying an installed Firefox user profile/system-wide FIPS, pruning original Mozilla source, approving security compliance, or merging/releasing the browser. The previous tested WebDriver/browser startup/PKCS#11 and trusted-local-TLS paths remain accepted only within their limited contexts.

**Accounting unchanged:** Vulpra **61%**, M3 protected native dependency/FFI last sixth gate **OPEN (5/6 = 83%)**, session **Δ +0 percentage points**. [PR #6](https://github.com/sguzman/vulpra/pull/6) remains **draft/open/unmerged**; issues #8/#9 unclosed. No workstation actions or original native source/binary rebuild.

## 2026-11-16 follow-up: exact Firefox GYP FIPS default and preserved ELF witness

[CI 43916636059 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43916636059), at [commit `179226e`](https://github.com/sguzman/vulpra/commit/179226e14537af0e30ecb458444ab12c40c7dde5), authenticated five original Firefox 160 Git source blobs and the **same** archived original compiled browser SHA-256 `530b7958...`. Its sanitized artifact `firefox160-original-nss-gyp-default-and-elf-literal-not-build-flags` (ID **14250596064**) was downloaded and inspected. No original browser rebuild or user profile change occurred.

This strengthens the build-time explanation beyond the previously cited generic NSS README: the exact upstream `security/moz.build` passes `gyp_vars` into `security/nss/nss.gyp`; `build/gyp_base.mozbuild` initializes those variables; the integration checked here has **no explicit `disable_fips` override**; and the included `security/nss/coreconf/config.gypi` defaults `disable_fips%=1`, which selects both `NSS_FIPS_DISABLED` and `NSS_NO_INIT_SUPPORT`. The original `fipstest.c` supplies a `CKR_DEVICE_ERROR`-returning FIPS entry stub under `NSS_FIPS_DISABLED`. These are exact-source GYP configuration facts, **not recovered producer command-line defines**.

The unchanged original `libsoftokn3.so` ELF contained **no** embedded `Known plaintext message utilized` RSA power-up KAT literal; its dynamic symbol table also did not export `FC_Initialize` by that name. Absence of an optimized/stripped ELF literal or dynamic symbol is bounded supporting evidence, **not** machine-code proof of `NSS_FIPS_DISABLED`, a failing instruction, FIPS compliance, or a specific startup-test root cause. The archived contract explicitly records `compiled_NSS_FIPS_DISABLED_macro_definitively_proven=false`, `original_producer_compiler_command_line_or_defines_recovered=false`, `m3_sixth_gate_closed=false`, `security_current=false` and `release_ready=false`.

**Next:** seek original producer-specific evaluated GYP variables/compiler command or a bounded native disassembly/branch witness of the preserved ELF; never claim that GYP defaults alone prove the actual compiled macro. M3 stays **5/6 (83%)**, Vulpra **61%**, delta **+0 percentage points**; draft PR #6 remains unmerged and no source, NSS binary, installation, or workstation crypto setting was altered.
