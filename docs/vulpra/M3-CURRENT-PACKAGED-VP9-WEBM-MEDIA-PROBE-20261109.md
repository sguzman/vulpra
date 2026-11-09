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
