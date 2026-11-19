# Firefox 160: exact upstream NSS/FFVPX native source owners and real VP9 under FFmpeg denial (2026-11-15)

## Results accepted by independently authenticated original native evidence

The original Firefox160 Vulpra source and compiled browser remain unchanged. The latest work adds two source-/runtime-scoped verification layers without rebuilding the native browser, modifying its user profiles, or granting permission to remove protected modules.

**Exact release/source/package identity:**

- Official Mozilla Firefox160 source commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b` from `mozilla-firefox/firefox`.
- Materialized Vulpra 28-overlay candidate source Git tree: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`.
- Unmodified original compiled Firefox160 archive SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Original native producer: [CI 43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), source branch SHA `0624235fdc956ab18af3c3f310b3588ca72fff61`.
- Independently preserved original complete-tree ledger/source proof: [CI 43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827), preservation branch SHA `54728803f058c3edf54d2e8d3f6e0a7d2af0aec6`.

## 1. Ten original NSS/FFVPX source blobs checked at exact Firefox160 release

[**Source-ownership CI 43745057569 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43745057569) used a separate, sparse, immutable **official** Firefox160 checkout. The new std-only [Rust source verifier](../../ci/m3-firefox160-nss-ffvpx-source-owners.rs) authenticated its exact `HEAD`, its *ten exact original Git blob hashes*, byte-identical checked-out files and per-owner runtime loader/failure branch source anchors. It compared their ten paths against the preserved **28 exact Vulpra overlay paths**, and proved **zero** of these ten official files were changed by Vulpra. The original source-tree assembly attestation remained 26 modified plus 2 added overlay paths and zero removed upstream files. All three verifier unit tests passed, including mutation rejection for the anchored source fragments.

| Actual source/build candidate, read-only source attribution | Corresponding source code / build metadata |
| --- | --- |
| NSS `libsoftokn3.so` | `security/nss/lib/pk11wrap/pk11load.c` and `security/nss/lib/softoken/manifest.mn` |
| NSS `libfreeblpriv3.so` | `security/nss/lib/freebl/loader.c`, `genload.c`, `blname.c`, and `manifest.mn` |
| Bundled `libmozavcodec.so` | `dom/media/platforms/ffmpeg/ffvpx/FFVPXRuntimeLinker.cpp`, `PDMFactory.cpp` and `media/ffvpx/libavcodec/moz.build` |
| Bundled `libmozavutil.so` | Same FFVPX runtime linker/factory and `media/ffvpx/libavutil/moz.build` |

The exact source contains NSS `PORT_LoadLibraryFromOrigin` / `PR_FindSymbol`, FreeBL `loader_LoadLibrary` / `PR_FindFunctionSymbol`, FFVPX's NSPR `PR_LoadLibraryWithFlags` and separate codec/util link status guards, plus PDMFactory decoder dispatch and both native FFVPX `SharedLibrary` declarations. These are **actual pinned source candidates**, not executable callstacks. Failure/guard **source text** was verified, not the actual runtime branch/fallback outcome.

The same CI checked four NSS/FFVPX library names against the separate authentic real [glibc initialized-loader CI 43743231236 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43743231236). Those actual initialization-confirmed dynamic requests were reported from `libnspr4.so` to `libsoftokn3.so`, `libfreeblpriv3.so`, `libmozavcodec.so`, and `libmozavutil.so`. glibc requester labels do not themselves prove the higher-level source function or the complete symbol resolution path. The source/runtime crosswalk is artifact **14174125369**.

A first genuine CI iteration [43744961328 — FAIL](https://github.com/sguzman/vulpra/actions/runs/43744961328) caught one incorrectly transcribed 39-digit `security/nss/lib/freebl/manifest.mn` Git blob hash. Commit `b43a2309` restored its exact 40-digit value; the verified tests and official-source checks then passed. There was no source or original native archive mutation.

## 2. Independent functional evidence: real VP9 decoding while system FFmpeg loader was denied

An existing, independent, original Firefox160 packaged browser [real WebDriver VP9 CI 43724363730 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43724363730) used a disposable video fixture and optional native provider-denial interposer. Its authenticated bounded JSON was re-examined read-only:

| Measured actual browser media behavior | Baseline | System FFmpeg denied |
| --- | ---: | ---: |
| Validated generated VP9/WebM test clip | Yes | Yes |
| Decoded frames, advancing playback time and video dimensions verified | Yes | Yes |
| Browser responded; disposable Firefox profile sentinel preserved | Yes | Yes |
| FFmpeg loader denials in this mode | 0 | **14** |
| New FFmpeg denials **after navigation** | 0 | **0** |
| Reported media error | No | No |

The denied-run shim explicitly attached to the actual native browser. All **14** denied attempts were counted **before** test video navigation; successful real VP9 playback was observed afterward. This is **not** proof a specific VP9 decoder was used, an FFVPX missing-provider path was exercised, an FFmpeg failure began during navigation, or a particular media fallback path actually executed. VP9 was decoded despite those denied system FFmpeg loads; that is the maximum justified conclusion. The original media artifact is **14165354069**.

[**Independent 3-evidence crosswalk 43745714250 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43745714250) authenticated the three independent producer runs and source/archive identities, joined the exact ten source blobs, four initialized NSS/FFVPX request candidates and the real original Firefox160 VP9 FFmpeg-denial behavior. It required both actual playback outcomes, 14 pre-navigation blocked FFmpeg attempts, zero subsequent attempts, and all explicit non-claim flags. It rejected **10/10 forged** source/byte/playback/provider/runtime/false-completion variants. Its bounded retained proof is artifact **14173613968**, inspected after the green run.

The first crosswalk [43745515028](https://github.com/sguzman/vulpra/actions/runs/43745515028) rejected a number-vs-string mismatch for the historical native producer run ID; after correction the genuine report passed but negative-control [43745633803](https://github.com/sguzman/vulpra/actions/runs/43745633803) exposed a forged field that the historical report never used. The fake was changed to tamper with the **real** `normal_packaged_archive_sha256` field. Full successful acceptance is **only** from 43745714250; failed interim runs were not accepted as evidence.

## 3. Exact remaining boundaries

The original Firefox160 packaged ELF set contains 28 members with 268 declared direct `DT_NEEDED` edges. Separate real native request traces contain 18 initialization-confirmed dynamic library request relationships; those are not all optional or future loader paths, and their counts cannot be combined into a source-pruning conclusion. This source/runtime/media work **does not** establish the machine-level direct caller/argument for NSS or FFVPX, the FFVPX missing-provider failure and specific fallback, all transitive/indirect `dlopen`/`dlsym`, every Rust/C++ static archive or generated FFI consumer, all protected feature activations, full H264/VAAPI/Wayland/DMABuf behavior, or the target EndeavourOS/Hyprland NVIDIA/iGPU device/kernel ABI.

Likewise no CVE/MFSA security-current acceptance, Safe Browsing readiness, sandbox gate closure, native artifact release eligibility or controlled Vulpra source pruning follows from these successful tests. PR #6 remains **draft and unmerged**; security issues #8 and #9 stay open. No workstation, user Firefox Developer Edition, personal Vulpra profile, browser source, compiled browser bytes, `main` or native host packages were changed.

**Progress ledger:** M3 last dependency/FFI/conditional-feature gate **OPEN**, M3 **83% (5/6)**, overall **61% (session Δ +0 percentage points)**. Next experiment should resolve specific stripped native caller/FFI ownership or separately exercise the *FFVPX missing-library* failure in disposable CI, without reinterpreting the system FFmpeg denial as equivalent.
