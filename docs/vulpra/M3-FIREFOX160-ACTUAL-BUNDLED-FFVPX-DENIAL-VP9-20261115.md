# Firefox 160 actual bundled FFVPX native-library denial during real VP9 playback

**Date:** 2026-11-15. **Status:** Source-authenticated *real native browser* positive media-survival observation; not complete feature fallback or dependency gate closure.

## Exact archive and experiment scope

The actual native browser in [CI 43748031202 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43748031202) was the **unchanged** original Firefox160 Vulpra package built at [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), with byte-identical archive preservation [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827):

- Original Mozilla Firefox160 release commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Complete Vulpra 28-overlay Git source tree: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`, with no original upstream removals.
- Actual original compiled native browser artifact SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Source-pinned original browser compiled branch SHA: `0624235fdc956ab18af3c3f310b3588ca72fff61`.
- Ten exact upstream NSS/FFVPX loader/build source files were independently blob-authenticated and shown **outside** Vulpra's 28 overlay paths by [source-owner CI 43745057569](https://github.com/sguzman/vulpra/actions/runs/43745057569).
- Prior independent [real glibc library-request CI 43743231236](https://github.com/sguzman/vulpra/actions/runs/43743231236) saw actual NSPR-requested initialization of bundled `libmozavcodec.so` and `libmozavutil.so` in a separate real WebDriver workload.

The current experiment explicitly opted into `VULPRA_M3_VP9_DENIAL_GROUP=ffvpx` in the existing [native C provider-denial shim](../../ci/m3-deny-optional-native-providers.c) and the [real VP9 WebDriver harness](../../ci/m3-packaged-ffmpeg-vp9-video.sh). The previous **system FFmpeg** group remains the script's default and matches only `libavcodec.so.*` / `libavcodec-ffmpeg.so.*`, not bundled FFVPX.

The opt-in **FFVPX** group targets *only* the basename `libmozavcodec.so` or `libmozavutil.so` during an actual `dlopen`/`dlmopen` from an explicitly matched native browser executable; it substitutes a deliberately missing test-only library name, instead of deleting, moving, replacing, chmod-ing or uninstalling original native or system libraries. The C fixture verified **both named bundled FFVPX calls are denied**, while a separate test verifies the FFmpeg group remains distinct. No user workstation/process/profile was involved.

The CI browser ran a locally generated, `ffprobe`-validated 192×108, 15 fps, four-second VP9/WebM video with both a normal baseline and an FFVPX-denied WebDriver session, isolated disposable `HOME` and profile sentinels, and a locally hosted page. It required actual `getVideoPlaybackQuality().totalVideoFrames` (at least two frames), advancing `currentTime` (at least 0.35 seconds), nonzero video dimensions, browser responsiveness, and unchanged temporary Firefox profile sentinel. The driver was SHA-256 verified. Raw private interposer logs and browser temporary profiles were deleted, not uploaded.

## Actual observed normal versus bundled FFVPX-denied outcome

| Source-authenticated native browser observation | Normal | Bundled FFVPX denied |
| --- | ---: | ---: |
| Real VP9 decoded frames and advancing playback time | **Passed** | **Passed** |
| Denied `libmozavcodec.so` attempts | 0 | **1** |
| Denied `libmozavutil.so` attempts | 0 | **1** |
| Total real FFVPX-targeted native library denials | 0 | **2** |
| New FFVPX denials after video navigation | 0 | **0** |
| Reported video media error | No | No |
| Browser WebDriver responsive after playback | Yes | Yes |
| Temporary profile sentinel preserved | Yes | Yes |

The **specific per-SONAME counts** come from the final [43748031202 successful run](https://github.com/sguzman/vulpra/actions/runs/43748031202): the private native log contained one actual denied `libmozavcodec.so` load and one actual denied `libmozavutil.so` load. The script retained only aggregate and per-name integer counters, never the raw paths, PIDs or log lines. The actual native-browser FFVPX experiment preserved bounded artifact `firefox160-original-bundled-ffvpx-denial-real-vp9-not-full-fallback`, artifact ID **14174059438**, which was independently downloaded and inspected.

This is materially stronger than the earlier [first FFVPX denial run 43747140617](https://github.com/sguzman/vulpra/actions/runs/43747140617), which correctly established **two** actual blocked FFVPX-group loader attempts and continued VP9 decoding but only retained a **total** count. That earlier evidence could not prove that *each particular* bundled library had been denied. The per-name report closes this measurement gap.

## Independent source/package/runtime consistency and false-evidence checks

The earlier independent four-producer [Firefox160 FFmpeg-versus-FFVPX source/media crosswalk 43747660588 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43747660588) authenticated the exact source owner 10 Git blobs, native loader observation and two actual **separate** media workloads. It demonstrated the same original package still decoded VP9 after **14** system-FFmpeg blocked attempts in the earlier system-FFmpeg trial and after **2** FFVPX-group blocked attempts in the separate actual FFVPX trial, with no video errors and all attempts **before video navigation**. It rejected **13/13** forged inputs. This is not a single combined FFmpeg+FFVPX-denial workload.

New [**per-SONAME crosswalk CI 43748375268 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43748375268) authenticated that prior independent four-producer success and the final real original-browser per-library run `43748031202`. It required exact compiled package SHA and source-tree parity, one denied load of **each** `libmozavcodec.so` and `libmozavutil.so`, a total of two denials, zero post-navigation denials, actual decoded VP9 frames under denial, a responsive isolated browser and explicit false release/closure claims. **12/12** forged source/byte/count/codec/util/playback/profile/fallback/gate records were rejected.

Independent retained artifact `firefox160-per-soname-ffvpx-real-denial-crosswalk-not-decoder-proof` (**14175062995**) was downloaded and inspected. Both source-bound producer checks and exact per-name counts passed.

An intermediate attempt at per-library shell-counter instrumentation, [CI 43747859154](https://github.com/sguzman/vulpra/actions/runs/43747859154), failed due to incorrectly constructed shell text during harness editing. The script was restored from the accepted predecessor and corrected at `8c8d7c60`; a successful original replay `43747970212` and final strict per-name acceptance run `43748031202` superseded that failed attempt. **No original compiled Firefox160 artifact bytes or source were changed.**

## What this result does **not** prove

Actual media playback continued after each FFVPX native library name was denied in this bounded WebDriver workload. **That does not identify the decoder**: the browser may have selected a different backend, retained already loaded modules or followed other native code paths. In particular the test did not observe the machine-code branch that corresponds to `FFVPXRuntimeLinker::Init()` returning false, and did **not** prove the exact FFVPX C++ source guard/fallback branch was exercised. The high-level source has an observable `MozAVLink` failure check and `FFmpegLibWrapper::Link()` status, but a source-code guard is not an executed branch witness.

The experiment does not establish all H264, VP9/AV1/FFmpeg, GPU VAAPI, DMABuf, graphics/Wayland, audio/PipeWire, crashreporter/updater, WebExtensions, NSS/Safe Browsing or sandbox behavior; complete Rust/C++ FFI or future dynamic `dlopen/dlsym` closure; the user's EndeavourOS/Hyprland mixed-display NVIDIA/iGPU host; security-current status or public-release readiness.

No original browser rebuild, original Firefox profile change, source pruning, host native-library deletion, worktree mutation, PR merge or user workstation changes occurred.

**Accounting:** M3 dependency mapping still **5/6 (83%)**, sixth dependency/FFI/feature gate OPEN; Vulpra product overall **61%**, session change **Δ +0 percentage points**. Draft [PR #6](https://github.com/sguzman/vulpra/pull/6) stays open and unmerged. Next investigation: exact compiled FFVPX callsite and conditional source guard activation, rather than assuming playback success identifies the decoder or a specific source fallback.
