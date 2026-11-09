# Real packaged H.264 WebDriver media probe — 2026-11-09 UTC

## Why this new test exists

The previous source-matched [full native Vulpra #42546880350 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42546880350) and independently verified [provider reconciliation #42552316905 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42552316905) showed **14 real FFmpeg `libavcodec` loader attempts denied**, while the actual packaged browser still produced an ordinary headless localhost screenshot. The GBM and VA-API probes observed **zero** requested matching libraries. That establishes neither H.264 playback nor a working fallback decoder.

## New bounded media acceptance protocol

- The new [`ci/m3-packaged-ffmpeg-h264-video.sh`](../../ci/m3-packaged-ffmpeg-h264-video.sh) uses the existing packaged native `vulpra`/`firefox` ELF, not the protective user launcher. It checks the normal package archive SHA-256, then extracts the package only into a temporary private directory.
- On the GitHub runner, `ffmpeg` generates an original **4-second, 192×108, 15 fps H.264/AVC yuv420p MP4** test video from `testsrc2`. `ffprobe` verifies codec/dimensions. Only a local `127.0.0.1` HTTP server serves the test page/media.
- Using the already proven geckodriver localhost W3C WebDriver workflow and **two independent disposable browser HOME/profile sessions**, one trial uses normal available host libraries; the other uses the previously validated opt-in `LD_PRELOAD` FFmpeg denial interposer. Neither changes system libraries or the user's Firefox profile.
- Each session queries the **actual HTML video element** for `currentTime`, `getVideoPlaybackQuality().totalVideoFrames`, `videoWidth/Height`, any HTML `MediaError`, and continued W3C WebDriver responsiveness. A playable video is accepted **only** when time advanced at least 0.35 s, dimensions match 192×108, and at least two decoded frames are recorded.
- The denied run records **FFmpeg loader interception counts before and after the H.264 page navigation separately**, preserving the distinction between startup-only attempts and a new media-triggered attempt. It also records whether the denied media played or produced a real browser media error; neither outcome is silently reclassified as a working software decoder fallback.
- The bounded report retains `false` for alternative software decoder fallback, VA-API/GPU/DMABuf, full indirect dynamic loader closure, M3 sixth-gate closure, source pruning, and release. The test fails closed if the normal baseline cannot decode actual H.264, the private browser is not responsive, the profile sentinel changes, or no FFmpeg denial occurs.

**Lightweight preflight:** [M3 H264 Media Fixture Preflight #42553348297 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42553348297) generated a real clip with FFmpeg/ffprobe and rejected missing or forged browser inputs without a browser build. Its [workflow lint #42553348272 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42553348272) passed.

**Live native workflow:** [commit `0914995`](https://github.com/sguzman/vulpra/commit/091499590cabe2426df96b5b735af64ebdd4ba23) adds FFmpeg as an explicit Ubuntu CI fixture dependency and runs the real packaged H.264 trial **after** original build/packaging/Wayland/JS/WebExtension/Nimbus/FFI evidence and native artifact persistence. The new full native [run #42553489035](https://github.com/sguzman/vulpra/actions/runs/42553489035) is **in progress at this checkpoint** (not an accepted media result). [Actionlint #42553489040 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42553489040).

**Pending required evidence:** the actual original browser's new bounded `m3-packaged-h264-video-ffmpeg-denial-evidence` artifact, baseline vs denied media DOM states, intercepted provider counts **before and after H.264 navigation**, package digest, source SHA, and independent source/package/runtime reconciliation. If denied H.264 playback fails with a `MediaError`, that is concrete dependency behavior rather than a software-fallback pass. A normal headless video decode also is not a private Weston/Wayland GPU/DMABuf rendering fallback test.

**Overall 61% (Δ +0 pp), M3 5/6 (83%)**, final dependency closure, security-hotfix merge and browsing release all remain blocked. No current source pruning or target workstation changes.
