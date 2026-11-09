# Source-matched real packaged VP9/WebM media independence probe — 2026-11-09 UTC

## Motivation and independently verified prior H.264 result

[Full native packaged H.264 #42553489035 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42553489035) with [independent media audit #42558025681 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42558025681) confirmed nine decoded H.264 frames / 0.642 seconds under normal FFmpeg and zero frames, `HTMLMediaElement.error.code=4`, and `NotSupportedError` under FFmpeg denial. The blocked library requests numbered 14 and all occurred before page navigation. It is not correct to call the H.264 result a successful decoder fallback.

The new experiment tests a **different media codec** using the same real packaged-browser, localhost WebDriver and bounded optional-provider denial infrastructure. Successful VP9/WebM decoding while FFmpeg library loads are denied could establish *tested VP9 playback availability under that denial condition*, not a way to decode H.264 without FFmpeg.

## New VP9 test contract

The [actual packaged VP9/WebM runner](../../ci/m3-packaged-ffmpeg-vp9-video.sh) is derived from the already successful H.264 WebDriver runtime runner. It creates a local original four-second **192×108, 15 fps, `libvpx-vp9`, yuv420p WebM** with FFmpeg (used solely to produce the test clip outside the browser); `ffprobe` validates `codec_name=vp9`, dimensions and pixel format. A small localhost HTTP server delivers it with `video/webm` MIME. Nothing is downloaded from third-party video sites, and no user's Firefox profile or system libraries are changed.

The actual **source-pinned packaged Vulpra ELF** is driven by a local geckodriver W3C session in **two independent temporary HOMEs**, one normal and one with the existing process-scoped opt-in `LD_PRELOAD` library interposer denying selected versioned FFmpeg loads. Each session measures `HTMLMediaElement.currentTime`, `getVideoPlaybackQuality().totalVideoFrames`, frame dimensions, any `MediaError` / rejected `play()`, the responsive browser/WebDriver session, the unchanged temporary profile sentinel, browser interposer attachment, and FFmpeg-denial event counts **before versus after** media navigation.

Passing *actual video playback* requires `currentTime>=0.35`, at least two decoded frames, and 192×108 dimensions. The native workflow requires the **normal baseline** to pass, a real optional-provider denial event and attached browser to be observed in the denied session, and both profiles/sessions to remain safe. It **records** whether the denied VP9 trial passed or failed rather than inventing a successful FFmpeg-independent VP9 path.

The [independent VP9 outcome classifier](../../ci/m3-vp9-webm-outcome-audit.jq) checks DOM-frame/error consistency, authenticates externally expected source/package hashes, distinguishes startup-time FFmpeg denials from newly observed post-navigation loads, and never asserts the VP9 decoder implementation identity, H.264 software fallback, hardware VA-API/GBM/DMABuf/Wayland fallback, full indirect dynamic graph, source pruning or release. [The adversarial fixtures](../../ci/tests/m3-vp9-webm-outcome-audit-tests.sh) run a denied-video error case, a post-navigation denial case, a playable denied-video case, and reject 20 forged media/video/loader/hash/profile/release states.

## Accepted lightweight preflight, pending full native result

**Fast fixture [#42559435587 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42559435587)** compiled an actual bounded WebM/VP9 clip using the Ubuntu runner's FFmpeg/FFprobe, verified MIME and invalid-input rejection, and confirmed **20/20 forged outcome records rejected**. Logs were directly inspected. [Workflow lint #42559435449 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42559435449).

The [new full source-matched native workflow commit `a17ac58`](https://github.com/sguzman/vulpra/commit/a17ac58d694bf77c4da352ed7ab9b37233fbc01e) now runs the baseline and denied VP9 browser comparison **after** all previous native/package/Wayland/FFI and H.264 tests. [Full native run #42559566915](https://github.com/sguzman/vulpra/actions/runs/42559566915) was **in progress** at this checkpoint; [actionlint #42559566424 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42559566424). **No VP9/browser-level playback outcome is accepted yet.**

## Avoiding additional full rebuilds

The updated native workflow also attempts to retain its actual source-pinned packaged archive, `.sha256` sidecar, and bounded source/package report in a separate **`m3-test-only-native-package-not-for-release`** Actions artifact with **seven-day retention** and `include-hidden-files=true`. This is for future sandboxed CI trials, not a user-installable release; its availability is contingent on the actual upload step succeeding. Once verified, future test workflows may download this exact source-identified packaged executable for isolated runtime tests instead of starting a complete new Firefox Rust/C++ build. Any new runtime environment must verify its own platform dependencies, source/package identities and original normal-browser acceptance.

**M3 remains 5/6 gates (83%); overall progress 61% (Δ+0 pp).** Actual VP9 playback outcome, missing GBM/VA-API feature paths, full conditional/indirect dependency closure, EndeavourOS/Hyprland desktop QA, source pruning, security hotfix merge and release remain **unproven/unapproved**.

## Verified corrected replay of retained native package (2026-11-09 UTC)

**The original full-native run [#42559566915](https://github.com/sguzman/vulpra/actions/runs/42559566915) finished FAILURE, but not from a browser compilation or H.264 regression.** Full native compilation, source-linked FFI checks, packaging, private Wayland/JavaScript/WebExtension/Nimbus smoke, optional-provider checks and real H.264 playback all passed. The **new VP9 test step** failed: it generated `vp9.webm` but its `<video>` HTML requested the nonexistent `/vp9.mp4`. The retained report (artifact **13651021378**) therefore recorded baseline **zero frames, zero seconds, media error 4**, and denied **zero frames, zero seconds, media error 4**. Neither failure was a trustworthy VP9 decoder result; the source/path mismatch invalidated the media experiment.

[Fix `901bd6d`](https://github.com/sguzman/vulpra/commit/901bd6d13444d959f61efcd1a772d5c12096c147) creates the actual page and generated VP9 fixture together and checks the exact WebM path in both the lightweight self-test and the real runtime. The [corrected preflight #42660052697 passed](https://github.com/sguzman/vulpra/actions/runs/42660052697); its scope is still **fixture/classifier**, not actual browser playback. The fix also records the **compiled browser source SHA separately from the test harness SHA**, allowing truthful replay of a previously built package.

**Real [source-pinned package replay #42660459080 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42660459080)** reused the retained **test-only**, non-release package from original native source `a17ac58d694bf77c4da352ed7ab9b37233fbc01e` without compiling Firefox again. The workflow independently checked the original run ID **42559566915**, source identity and runtime-success ledger, saved SHA-256 sidecar and actual archive SHA-256 `f92fe8c29843e7521ffe1ddd7cbbed8836ff9491228b182628973e8484ed1a41`. The corrected test harness source was `1da98867b8f074bc116782d9c730508c06582f5c`. The replay artifact **13695320052** contains the raw WebDriver comparison and independently classified report.

| Actual packaged-browser measurement | Normal FFmpeg | FFmpeg deliberately denied |
| --- | ---: | ---: |
| Decoded VP9 frames | **6** | **10** |
| Advanced video time | **0.402 s** | **0.684 s** |
| Video dimensions | 192 × 108 | 192 × 108 |
| HTML media error or rejected play | None | None |
| Responsive WebDriver/browser | Yes | Yes |
| FFmpeg blocked loads **before** video page | 0 | **14** |
| FFmpeg blocked loads **after** video page | 0 | **14** |

**Supported conclusion:** The actual compiled Vulpra package plays VP9/WebM successfully under the bounded FFmpeg-denial condition. The browser was responsive and both temporary profiles were preserved. Since the 14 blocked requests were already present before media navigation and there were **zero additional blocked requests afterward**, this evidence does **not** prove the VP9 page itself requested FFmpeg libraries or identify the working VP9 decoder. It also does not contradict the earlier actual H.264 failure under FFmpeg denial, establish a substitute H.264 software decoder, prove hardware VA-API/GBM/DMABuf/Wayland fallback, grant source pruning, or complete the indirect/conditional native dependency/FFI map.

**Roadmap credit:** M3 remains **5/6 (83%)** and overall Vulpra **61%**, **Δ +0 percentage points**. This closes the pending *VP9 comparison experiment*, not the sixth M3 gate, target workstation acceptance, security hotfix merge or release.
