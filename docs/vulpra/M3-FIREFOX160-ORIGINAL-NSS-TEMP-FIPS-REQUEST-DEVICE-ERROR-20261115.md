# Firefox 160: temporary NSS FIPS-mode request fails in original packaged NSS

**Date:** 2026-11-15. **Outcome:** [Original source/byte-pinned native Firefox160 NSS temporary FIPS-request run 43766793297 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43766793297) as an **authenticated negative test**; [independent source/runtime/error-code reconciliation 43767128907 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43767128907) rejected **16/16 falsified reports**. **The original NSS runtime did NOT enter FIPS mode in this test.** This result must not be represented as successful FIPS initialization or FIPS certification.

## Exact original Mozilla source and compiled browser package

- Official Mozilla Firefox 160 source commit `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Vulpra assembled candidate Git tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`, with exactly 28 source overlays and **no deleted original Firefox source**.
- Unmodified original compiled Linux browser package archive SHA256 `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`, from original native producer run [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), byte-preserved in [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827).
- The new native FIPS-request workflow verified **11 exact official Firefox160 NSS source Git blobs** (including the NSS `NSS_Init` implementation, internal PKCS#11 slot/FIPS getters, FreeBL and softoken native loader source/build manifests), and independently checked that none are among Vulpra's 28 overlays.
- The independent verifier additionally checked exact original Mozilla `security/nss/lib/util/secerr.h` and `nsprpub/pr/include/prerr.h` Git blobs to establish the numeric error-code identities. The source defines `SEC_ERROR_BASE=-0x2000`, `SEC_ERROR_PKCS11_DEVICE_ERROR=SEC_ERROR_BASE+169=-8023`, and `PR_LOAD_LIBRARY_ERROR=-5977`.

The original source was **not** recompiled, and no original native shared library was modified or deleted.

## Strictly isolated temporary FIPS setup

The [NSS SQL-database replay](../../ci/m3-firefox160-original-pkcs11-ephemeral-fips-db-replay.sh) created **two brand-new, independent SQL NSS databases** under a disposable GitHub Actions runner directory with restrictive permissions:

1. **Plain SQL NSS database:** Created by host `certutil -N --empty-password`. The host `modutil -chkfips false` command confirmed its default FIPS setting was disabled.
2. **Temporary FIPS-request SQL database:** Also created by host `certutil`, and modified **only in its temporary directory** with host `modutil -fips true -force -dbdir sql:<temporary-path>`. Host `modutil -chkfips true` confirmed the temporary database was marked FIPS-enabled.

These utilities ran with inherited `LD_LIBRARY_PATH` and `LD_PRELOAD` cleared. They were used **only to prepare test databases**, not to substitute their current system NSS libraries for original Firefox160 native runtime functions. The original NSS test then loaded `libnss3.so` from the unmodified preserved Firefox160 archive by exact absolute path and resolved all original NSS/PKCS#11 exports using `dlsym` with per-function canonical `dladdr` identity checks.

The [source-bound original NSS SQL probe](../../ci/m3-firefox160-original-pkcs11-ephemeral-fips-db-probe.c) executed `NSS_Init("sql:<temporary-path>")` in **five separate ephemeral processes**, with `PK11_IsFIPS`, internal slot/key-slot presence, `CKM_SHA256`, transient RNG and shutdown queried **only if initialization succeeds**. The probe obtains `PORT_GetError` immediately after failed `NSS_Init`, and exports only bounded numeric return codes, source-defined booleans and literal mode names. No private DB contents, token name/PIN, keys, logs, source paths or process IDs were archived.

The original database file hashes (`cert9.db`, `key4.db`, `pkcs11.txt`) were checked before/after the original native calls and were **unchanged**. All temporary databases, host-generated keys (none were required), profiles, error logs and diagnostic files were deleted when the runner exited. No OS/system FIPS flag, global NSS module, certificate trust store or personal Firefox configuration was changed.

**Interpretation limit:** Because the DB was created by the Ubuntu runner's host NSS tools, but executed with **the preserved Firefox160-packaged NSS**, version/build compatibility remains one possible explanation for the failure. The error code alone does not identify the originating failing internal instruction, module or self-test.

### Exact observed original native results

| Separate original NSS runtime condition | `NSS_Init` | `PORT_GetError` | Actual native loads denied | PKCS#11 mode query |
| --- | --- | --- | --- | --- |
| Plain disposable SQL database | **0 (success)** | **0** | 0 | **`PK11_IsFIPS=0`**; both slots present, SHA-256 and RNG passed |
| FIPS-marked disposable SQL database | **−1 (failure)** | **−8023 — `SEC_ERROR_PKCS11_DEVICE_ERROR`** | 0 | **Not reached** |
| FIPS DB + softoken denied | **−1** | **−5977 — `PR_LOAD_LIBRARY_ERROR`** | **2 softoken requests** | Not reached |
| FIPS DB + FreeBL denied | **−1** | **−8023** | **0 blocked FreeBL requests** | Not reached |
| FIPS DB + both names targeted | **−1** | **−5977** | **2 softoken, 0 FreeBL requests** | Not reached |

Additional original native ELF observations:

- In the normal SQL mode, both original packaged `libsoftokn3.so` and `libfreeblpriv3.so` loaded. Internal default/key slots were **distinct**, consistent with observed non-FIPS mode; `CKM_SHA256` was available; transient RNG and shutdown passed.
- In the FIPS-requested mode without injected denials, original `libsoftokn3.so` **was mapped** but original `libfreeblpriv3.so` was **not mapped** when `NSS_Init` returned the device error. This does **not** prove the device error was caused by FreeBL.
- With only softoken denied, `2` real native `dlopen/dlmopen` requests were blocked and the source-defined load-library error was returned. With **only FreeBL** targeted, NSS still failed with the device error **before any FreeBL load request**, so **no missing-FreeBL test occurred on that FIPS initialization path**.
- With both names targeted, softoken failed first: **2 observed softoken denials, zero FreeBL denials**.
- All five isolated native processes exited normally; the failure was a returned NSS initialization error, not a process crash or a successful fallback.

The accepted [bounded actual original native artifact 14182746452](https://github.com/sguzman/vulpra/actions/runs/43766793297) was downloaded and inspected, confirming exact five-mode codes, actual loader-denial counts, non-FIPS success, no original FIPS getter invocation and unchanged temporary SQL databases.

### Why the test workflow changed

The first test version **incorrectly expected** that a host `modutil`-marked database would necessarily initialize as FIPS in the original packaged NSS. The real runtime contradicted that premise in [43766327035](https://github.com/sguzman/vulpra/actions/runs/43766327035). A new original-library `PORT_GetError` probe narrowed the failure to **−8023** in actual native run [43766553438](https://github.com/sguzman/vulpra/actions/runs/43766553438). The workflow was then corrected to **require the negative result**, rather than force a false positive or treat an NSS failure as a build error.

The final successful [43766793297](https://github.com/sguzman/vulpra/actions/runs/43766793297) asserts the exact observed returned errors, blocked loads and false FIPS-completion flag. No previous failed test run is treated as an accepted successful FIPS transition.

## Independent authenticated original baseline/source/FIPS-negative crosswalk

[Evidence-only CI 43767128907 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43767128907) independently authenticates two exact successful immutable producers by full original run commit SHA, branch, job name, producer completion and unexpired artifact names:

- [43765487245](https://github.com/sguzman/vulpra/actions/runs/43765487245): independently source-verified original successful **non-FIPS** PKCS#11 internal slots/SHA-256/RNG and original-browser temporary-CA **trusted localhost HTTPS**.
- [43766793297](https://github.com/sguzman/vulpra/actions/runs/43766793297): original byte-pinned NSS `NSS_Init` on fresh plain/FIPS-requested SQL databases with exact `PORT_GetError` and observed provider load requests.

The [strict jq verifier](../../ci/m3-firefox160-original-ephemeral-fips-failure-crosswalk.jq) requires the original source/archive identities, all five actual modes, `−8023` for the unmodified FIPS request, `−5977` only when softoken loads were actually blocked, **zero FreeBL denials**, exact original ELF mappings, real non-FIPS success, no user/system FIPS edits, and explicit false FIPS-mode success/certification/completion flags. It verified **16/16 deliberately falsified source, browser archive, DB mode, cryptographic initialized state, errors, native loader counts, false-FIPS-getter and full-M3-closure reports were rejected**.

The final independent accepted artifact `firefox160-authenticated-original-FIPS-request-device-error-not-validated-FIPS`, ID **14183150466**, was downloaded and inspected.

## Conservative interpretation and remaining work

**Established:** This exact compiled Firefox160 NSS runtime succeeds with a fresh non-FIPS SQL database but returned `SEC_ERROR_PKCS11_DEVICE_ERROR` when asked to initialize a separate FIPS-marked temporary database prepared by host NSS tools. Real native load denial of softoken changes the failure to `PR_LOAD_LIBRARY_ERROR`. The original database contents and source/archive are unchanged.

**Not established:** That Firefox160's packaged NSS definitively cannot support FIPS in any valid configuration, that this result is a FIPS self-test failure, that host-versus-packaged NSS version compatibility is or is not responsible, which exact machine-code instruction returned the error, successful FIPS-mode PKCS#11 operation, FIPS 140-2/140-3 validation, protected algorithm policy, any external HSM/PIN/private-key operation, all Gecko crypto/security behavior, or the full generated/Rust/C++ `dlopen`/`dlsym` graph.

**Next distinct source-level diagnostic:** Trace the original native `NSS_Init` FIPS path through softoken and `SEC_ERROR_PKCS11_DEVICE_ERROR` ownership, or try a database prepared by the exact same original packaged NSS build where a compatible tool exists. Do **not** turn on global FIPS, change real user profiles or edit original source to make the test pass.

**Project accounting unchanged:** M3 sixth conditional-dependency/protected-feature/FFI gate **OPEN**, **5/6 = 83%**; overall Vulpra **61%, session Δ +0 percentage points**. [Draft PR #6](https://github.com/sguzman/vulpra/pull/6) remains open and unmerged; issues #8/#9 remain open. No original native browser rebuild, source pruning, workstation/OS FIPS change, personal Firefox profile edit, merge or release.
