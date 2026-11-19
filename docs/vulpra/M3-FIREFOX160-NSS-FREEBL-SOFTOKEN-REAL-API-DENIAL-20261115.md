# Firefox 160: actual original NSS softoken and FreeBL missing-provider API behavior

**Date:** 2026-11-15. **Acceptance:** Real source-attested NSS native API failure-mode observations. **Not** a Firefox browser HTTPS test, a successful cryptographic fallback, complete M3 native dependency acceptance, a security release or a source-removal authorization.

## Original source and native package identities

[Original NSS provider-denial CI 43760051406 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43760051406) used the same exact original, preserved, **unmodified** Firefox160 compiled native archive tested in prior M3 media CI:

- Official Mozilla Firefox160 commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Vulpra 28-overlay candidate source Git tree: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`.
- Preserved complete original native browser archive SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Original native archive producer [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), independently preserved without rebuilding at [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827).
- Authentic exact-upstream [10-source NSS/FFVPX ownership CI 43745057569 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43745057569) verified all ten Git blobs, their build manifests, the original 28 Vulpra overlays not touching the files, and four NSS/FFVPX source-to-native-loader candidates.

The new NSS test separately checked **six exact upstream Git source blobs** against the official Firefox160 `HEAD:path` and file `git hash-object` for `security/nss/lib/pk11wrap/pk11load.c`, `security/nss/lib/softoken/manifest.mn`, `security/nss/lib/freebl/loader.c`, `genload.c`, `blname.c`, and `manifest.mn`. Guard source anchors were required. Their exact build output names remain `libsoftokn3.so` and `libfreeblpriv3.so`.

### Source-defined protected behavior

`pk11load.c` attempts to load the internal `softokn3` PKCS#11 module through `PORT_LoadLibraryFromOrigin` and `PR_CallOnce`. If that fails, the internal module function list returns `SECFailure`.

`freebl/loader.c` obtains the platform-specific `freeblpriv3` basename from `blname.c`, loads it through `genload.c` using `PR_LoadLibraryWithFlags`, and resolves the `FREEBL_GetVector` interface. NSS guarded FreeBL callers return failure when the loader cannot initialize the vector.

These are the exact upstream sources, not guessed from generic NSS documentation; however, source anchors alone do **not** establish exact compiled callstacks.

## Executed original native NSS APIs, not a mock

The new [C probe](../../ci/m3-firefox160-original-nss-api-probe.c) opens the **absolute path** of original packaged `libnss3.so` and resolves `NSS_NoDB_Init`, `PK11_GenerateRandom`, and `NSS_Shutdown` through `dlsym`. Each resolved symbol's `dladdr`/real path must match this actual preserved original library, not the Ubuntu runner system NSS package.

The probe checks the original `libsoftokn3.so` and `libfreeblpriv3.so` ELF image paths with `dl_iterate_phdr` while NSS is active, comparing the canonical parent directory to the packaged original `libnss3.so`. It archives only two booleans, never resolved paths, loaded maps, random bytes, private process IDs or raw interposer lines.

The [existing Linux native provider-denial shim](../../ci/m3-deny-optional-native-providers.c) gained **separate opt-in** `nss_softoken`, `nss_freebl` and `nss_both` groups. It only targets those exact two sonames for a named disposable probe executable. Existing `ffvpx`, `ffmpeg`, `ffvpx_ffmpeg`, VAAPI and GBM groups remain independent. The probe is run separately, in a fresh disposable process and NSS initialization state, for baseline and each denial. No original shared library was deleted or renamed, and no personal Firefox instance or profile was accessed.

### Actual native results (verified from downloaded bounded CI artifact)

| Isolated native API condition | Original library loads blocked | `NSS_NoDB_Init` | `PK11_GenerateRandom` | Probe process |
| --- | --- | --- | --- | --- |
| Baseline, no provider denied | 0 | **0 (success)** | **0 (success)**, nonzero bytes generated | Exit 0 |
| Softoken explicitly unavailable | **2 `libsoftokn3.so`** | **−1 (failure)** | Not called (init failed) | Exit 0 |
| FreeBL explicitly unavailable | **3 `libfreeblpriv3.so`** | **−1 (failure)** | Not called (init failed) | Exit 0 |
| Both provider names placed in denylist | **2 `libsoftokn3.so`; 0 FreeBL** | **−1 (failure)** | Not called (init failed) | Exit 0 |

The baseline mapped both original packaged providers while generating cryptographically managed random bytes, and `NSS_Shutdown` returned success. Under softoken denial, **neither** provider was mapped. Under FreeBL-only denial, original softoken **was** mapped while original FreeBL was absent. All three missing-provider NSS calls returned failure to the probe, with no native process crash or timeout. The cryptographic failures were **not** treated as successful fallback behavior.

The combined-denial case is particularly important: once the internal softoken cannot load, the code returns failure without reaching a FreeBL load request. Although the shim would also deny `libfreeblpriv3.so` if requested, no actual FreeBL denial occurred in that run. We preserve the **observed 2/0 count**, not a fictitious 2/3.

Original actual runtime artifact `firefox160-original-packaged-nss-freebl-softoken-native-api-missing-provider-not-TLS`, ID **14179014854**, was downloaded and inspected. It contains only finite numeric return codes, original-mapping booleans, sanitized process completion outcomes and source/archive identifiers.

## Independent immutable source/native crosswalk

[Independent NSS real API crosswalk CI 43760419551 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43760419551) separately authenticated original upstream NSS source-owner CI `43745057569` and the actual native API producer `43760051406` by exact full original producer commit SHAs, branch, names, success status and exact unexpired artifacts.

The verifier [`ci/m3-firefox160-nss-freebl-softoken-real-api-crosswalk.jq`](../../ci/m3-firefox160-nss-freebl-softoken-real-api-crosswalk.jq) required the exact original upstream source/compiled archive identities, true NSS API binding to original `libnss3.so`, both original provider ELF mappings in baseline, successful baseline NSS init/random/shutdown, actual **2** denied softoken calls, **3** denied FreeBL calls, **2** combined-mode softoken calls and **zero** combined-mode FreeBL requests, all clean returned failure states, and explicit false TLS/full-FFI/whole-M3 claims. **All 16/16 forged source-owner, native byte identity, initialization status, entropy, provider count, library map, browser/TLS claim and completion records were rejected.**

Independent bounded accepted artifact: `firefox160-original-source-verified-nss-freebl-softoken-api-failure-not-TLS`, ID **14179499567**, downloaded and inspected.

## Boundaries and next acceptance work

This is a **real native C API test**, not WebDriver running the complete Firefox160 browser against HTTPS, and not a full TLS/FIPS/PKCS#11 feature survey. The named shim's executable allowance is restricted to the disposable `vulpra_nss_probe`; browser-process loader semantics beyond the original source remain unverified for this negative case. No test establishes the exact binary instruction or callstack producing a denied NSS load, nor all future conditional `dlopen/dlsym`, Rust/C++/generated FFI dependencies, complete NSS cryptography, hardware acceleration, target EndeavourOS/Hyprland mixed NVIDIA/iGPU environment, or current security/sandbox acceptance.

A missing internal NSS provider **prevented successful initialization** in the measured API configuration. It is therefore **not safe** to infer either library could be removed from Vulpra. The next bounded test should attempt disposable **full Firefox browser HTTPS or browser startup behavior** under these exact NSS provider denials, accepting explicit expected failures rather than pretending the browser should succeed, while leaving original byte-pinned packages and system NSS installed.

**Accounting unchanged:** M3 native dependency/FFI/conditional-feature sixth gate OPEN; M3 **5/6 (83%)**, Vulpra overall **61%**, session **Δ +0 percentage points**. [PR #6](https://github.com/sguzman/vulpra/pull/6) remains draft/open/unmerged; issues #8/#9 remain open. No source pruning, no browser profile change, no workstation actions and no release.
