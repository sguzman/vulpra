# Firefox 160: real original NSS PKCS#11 slots, SHA-256 mechanism and FIPS state (read-only)

**Date:** 2026-11-15. **Acceptance:** [Actual original packaged NSS PKCS#11 read-only CI 43765136534 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43765136534), independently verified by [source/authentic trusted-TLS crosswalk CI 43765487245 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43765487245). This is an **observational, non-FIPS native PKCS#11 test**. **No FIPS mode activation, certification claim, original library removal, full dependency gate closure or release authorization.**

## Immutable original NSS/Firefox160 source and binary provenance

The real native C probe reused only the original compiled Firefox160 Vulpra package whose source/build provenance and bytes were previously established:

- Original official Mozilla Firefox 160 source commit `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Vulpra candidate assembled Git tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5` with exactly **28 authenticated Vulpra source-overlay paths**, no deleted original upstream source files.
- Exact preserved original native Firefox160 package archive SHA-256 `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Native original build producer [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), independently byte-preserved [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827).

The [new standalone original NSS PKCS#11 CI workflow](https://github.com/sguzman/vulpra/blob/upgrade/firefox-160-overlay-prototype/.github/workflows/m3-firefox160-original-pkcs11-fips-readonly.yml) explicitly checked **ten exact original Mozilla Git blobs** at this Firefox160 revision, including the original softoken/FreeBL loading source and manifests plus `security/nss/lib/pk11wrap/pk11slot.c`, `pk11util.c`, `pk11pub.h`, and `security/nss/lib/util/pkcs11t.h`. It separately checked that **none** of those ten source paths overlapped any of the 28 Vulpra overlays. The same original preserved package archive was downloaded with checksums validated before the native C probe ran.

The critical source-defined behavior:

- `PK11_GetInternalSlot()` returns an owned reference to the internal default slot, or the FIPS key slot when the internal module's `isFIPS` bit is set.
- `PK11_GetInternalKeySlot()` returns the separate internal key slot when not in FIPS mode; the original source declares that FIPS uses one common internal slot.
- `PK11_IsPresent()` checks actual internal token availability; `PK11_FreeSlot()` releases references safely.
- `PK11_DoesMechanism()` checks the slot's mechanisms, and the exact official original `pkcs11t.h` defines `CKM_SHA256 = 0x00000250UL`.
- `PK11_IsFIPS()` reads the internal NSS module's **`isFIPS` mode flag**; `SECMOD_GetSystemFIPSEnabled()` reads the NSS system FIPS indicator. Neither getter validates FIPS certification or compliance.

All ten original source/blob, constructor and method-name anchors are pinned by exact Git SHA in CI. This does not assert every compiled C/C++/Rust callstack has been traced.

## Real, isolated original native NSS API execution

[The native C observer](../../ci/m3-firefox160-original-pkcs11-fips-readonly-probe.c) opens the original archive's absolute `libnss3.so` path, dynamically resolves `NSS_NoDB_Init`, `NSS_Shutdown`, `PK11_IsFIPS`, `SECMOD_GetSystemFIPSEnabled`, `PK11_GetInternalSlot`, `PK11_GetInternalKeySlot`, `PK11_FreeSlot`, `PK11_IsPresent`, `PK11_DoesMechanism`, and `PK11_GenerateRandom`, and verifies **all ten symbols** resolve to the exact original packaged `libnss3.so` file rather than the Ubuntu runner's system NSS. With NSS initialized, the observer reads the module/system FIPS status, obtains and inspects both internal slots, checks `CKM_SHA256` support, frees slot references, generates transient random bytes, and shuts down NSS. The random sample, source paths, PID, slot labels, token names, keys and passwords are **never exported**; only allowlisted integers and booleans are retained.

Four independent throwaway native processes run the [narrowly scoped replay script](../../ci/m3-firefox160-original-pkcs11-fips-readonly-replay.sh) with the original source-pinned `libsoftokn3.so` and `libfreeblpriv3.so` libraries physically intact. The existing C interposer is *only* enabled for missing-provider modes and only denies exact native `dlopen/dlmopen` requests, never removes or changes actual shared libraries.

### Genuine observed results

| Original NSS condition | Normal | Softoken denied | FreeBL denied | Both targeted |
| --- | --- | --- | --- | --- |
| Native `NSS_NoDB_Init` result | **0 (success)** | **−1** | **−1** | **−1** |
| Internal PKCS#11 default slot | **Present** | Not queried after failed init | Not queried | Not queried |
| Internal PKCS#11 key slot | **Present** | Not queried | Not queried | Not queried |
| Internal default slot `CKM_SHA256` mechanism | **Available** | Not queried | Not queried | Not queried |
| Module `PK11_IsFIPS` (read-only) | **0 (not in FIPS mode)** | Not queried | Not queried | Not queried |
| Runner system FIPS indicator (read-only) | **0** | Not queried | Not queried | Not queried |
| Original PKCS#11 RNG | **Success**; sample nonzero | Not called | Not called | Not called |
| NSS shutdown | **Success** | Not called | Not called | Not called |
| Actual blocked `libsoftokn3.so` native loads | 0 | **2** | 0 | **2** |
| Actual blocked `libfreeblpriv3.so` native loads | 0 | 0 | **3** | **0** |
| Original softoken ELF mapped before teardown | Yes | No | Yes | No |
| Original FreeBL ELF mapped before teardown | Yes | No | No | No |
| Native test process | Exited 0 | Exited 0 | Exited 0 | Exited 0 |

**Meaning:** With both packaged NSS providers present, the original Firefox160 NSS PKCS#11 internal slots are functional and report SHA-256 mechanism support in this controlled Linux CI configuration. Their FIPS-mode flag is **off**. With either exact provider denied, NSS initialization returns failure **before** PKCS#11/FIPS status queries can be executed. The combined-denial mode again attempts **only softoken**, failing earlier than the FreeBL load.

The original private probe counted exactly **1 native shim attachment witness** for each denied subprocess. All four original probe processes completed without crashing or timing out. The source-defined probe result uses `-2` for **not attempted**—not a negative FIPS/slot result.

Original bounded artifact `firefox160-original-native-pkcs11-sha256-fips-readonly-not-certified`, ID **14182286496**, was downloaded, inspected and its numeric/boolean fields verified. The first attempt [43765055983](https://github.com/sguzman/vulpra/actions/runs/43765055983) failed **solely in the new test's output allowlist**, whose field-name regex accidentally excluded digits in `sha256_mechanism`. The parser was corrected at commit `66599cc889a854de41bf5912159ee8056cc981ef`, and only the subsequent [successful native run 43765136534](https://github.com/sguzman/vulpra/actions/runs/43765136534) is used as evidence.

## Independent original source/native PKCS#11 to trusted-HTTPS crosswalk

[Independent CI 43765487245 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43765487245) separately authenticated by exact workflow names, successful original run conclusion, full producer Git SHAs, original branch, and unexpired exact artifacts:

- Earlier independent [source/native original Firefox160 certificate-authenticated trusted localhost TLS proof 43763693842](https://github.com/sguzman/vulpra/actions/runs/43763693842): the actual preserved browser rejected untrusted localhost HTTPS and **successfully completed** local HTTPS, secure document and JavaScript execution once an ephemeral RSA test CA was trusted **only** in the disposable NSS profile; provider denials prevent browser startup.
- New [actual original PKCS#11 read-only native observation 43765136534](https://github.com/sguzman/vulpra/actions/runs/43765136534): original NSS source/blob/package identity, internal slot/key-slot existence and presence, SHA-256 mechanism, FIPS mode `0` in both recorded read-only contexts, RNG/shutdown, actual 2/3/2+0 missing-native-provider failure counts and no private data changes.

The independent [strict `jq` crosswalk](../../ci/m3-firefox160-pkcs11-readonly-vs-trusted-tls-crosswalk.jq) requires all of those exact original source/package, API outcome and conservative non-FIPS/no-pruning claims. **All 16/16 deliberately forged source, original compiled byte SHA, PKCS#11 slot/mechanism/RNG, native provider count/ELF mapping, FIPS state, false security-compliance and false-M3-completion reports were rejected.**

The final accepted evidence artifact, `firefox160-source-attested-original-pkcs11-sha256-fips-readonly-not-FIPS-certified`, **ID 14182550088**, was downloaded and independently inspected. The two workflows' successful status and exact archive/source references were verified after the evidence was committed.

## Explicit limits and next distinct acceptance target

This native API test only **reads** FIPS mode; it **does not enable FIPS mode**, run the FIPS power-up self-test sequence, establish FIPS-140 validation/certification, enumerate external PKCS#11 HSMs, test external tokens or PINs, generate/import private keys, or write any slot/module policy. It does not test FIPS-approved crypto service enforcement, broad cipher/TLS suites or complete Gecko sandbox/security behavior.

The previously verified real-browser local HTTPS baseline is **separate evidence**. It is not claimed that the new PKCS#11 probe ran inside Firefox's browser process or that disabled NSS providers could sustain HTTPS. Neither softoken nor FreeBL may be removed: their actual absence prevented NSS initialization, and prior WebDriver tests showed browser session creation failed.

No machine-code native loader callstacks, complete generated/Rust/C++ `dlopen`/`dlsym` FFI graph, whole original browser dependency closure, target EndeavourOS/Hyprland NVIDIA+iGPU testing, current security acceptance, or release readiness has been demonstrated. There is **no authorization to prune original Mozilla source files or native NSS providers**.

**Progress remains:** M3 last dependency/FFI/protected-feature sixth gate **OPEN: 5/6 (83%)**. Overall Vulpra **61%, session Δ +0 percentage points**. [Draft PR #6](https://github.com/sguzman/vulpra/pull/6) remains open and unmerged; issues #8/#9 remain open. No workstation or personal Firefox profile modified, source removal, original browser recompilation, or release.
