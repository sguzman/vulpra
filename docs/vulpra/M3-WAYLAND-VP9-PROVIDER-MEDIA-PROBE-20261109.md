# Non-headless Wayland VP9/media/graphics provider-denial experiment — 2026-11-09 UTC

## Recovered baseline and unfinished engineering question

The already accepted [native graphical Wayland denial replay 42662005847](https://github.com/sguzman/vulpra/actions/runs/42662005847), independently reconciled by [42664234555](https://github.com/sguzman/vulpra/actions/runs/42664234555), confirmed real browser-process interposer attachment and a valid private Weston/Pixman same-surface Wayland frame in three isolated ten-second trials. It observed **GBM/DRM 1**, **VA-API 0**, **FFmpeg 14** denied library requests. These are **same-session events**, not proven denial-before-frame chronology or hardware fallback. The browser source is `a17ac58d694bf77c4da352ed7ab9b37233fbc01e` with verified native archive SHA-256 `f92fe8c29843e7521ffe1ddd7cbbed8836ff9491228b182628973e8484ed1a41`.

A plain graphical startup did not exercise VA-API. The unfinished authorized task is a **feature-triggered real browser experiment** under GBM/DRM and VA-API denial, while preserving original compiled-browser and test-harness identities and without claiming a GPU or video decoder implementation.

## New implemented runtime probe

[CI harness `ci/m3-packaged-wayland-vp9-providers.sh`](../../ci/m3-packaged-wayland-vp9-providers.sh) was committed in [`50bd89f`](https://github.com/sguzman/vulpra/commit/50bd89fb2e748f9c77ccd8328b5cbaf4b63e284a). It reuses the proven four-second **192×108, 15 fps VP9/WebM** locally generated and `ffprobe`-validated test clip from the previous headless VP9 experiment; unlike the original accidental `vp9.mp4` mismatch, the fixture/page path is explicitly checked. It starts its own private **Weston headless-backend with Pixman renderer** and localhost HTTP server, with no X11 DISPLAY or `MOZ_HEADLESS`, then drives isolated real packaged Vulpra sessions through W3C Geckodriver.

For each of the **baseline**, **GBM/DRM denial**, and **VA-API denial** modes, the harness requests actual video playback, measures `currentTime`, `getVideoPlaybackQuality().totalVideoFrames`, frame dimensions and media error, attempts an actual video-to-2D-canvas pixel readback and a WebGL2 context, requests a genuine WebDriver PNG screenshot, checks browser responsiveness and temporary original-profile sentinel, and counts **matching native provider denials before vs. after video page navigation**. The small C `LD_PRELOAD` interposer denies only selected `dlopen`/`dlmopen` requests in actual browser executables, not system files. Test-only private preferences opt into media hardware-decoding discovery and WebRender but cannot create hardware devices on a Pixman runner.

The separate [replay workflow](../../.github/workflows/m3-wayland-vp9-provider-video-replay.yml), committed in [`f8d16a0`](https://github.com/sguzman/vulpra/commit/f8d16a0cb63686e750d97267d79043fd2b194a5d), authenticates the existing **seven-day, test-only, non-release package artifact** from full native run **42559566915** against compiled source, original native runtime evidence, and actual archive SHA. It performs **no new Firefox compilation, source pruning, workstation modifications, or release**. The explicit strict non-local network guard is retained for this test; any interaction with graphical-online host behavior needs verification rather than relaxing the guard.

**Original runtime [42665579538](https://github.com/sguzman/vulpra/actions/runs/42665579538) was in-progress at this record's initial checkpoint**, with workflow lint [42665579513 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42665579513). Actual graphical VP9/canvas/WebGL and GBM/VA-API denial results **must be read from this run's archived JSON** after the native runtime step, not inferred from workflow starting or lightweight lint.

## Independent evidence validation

The [conservative jq classifier](../../ci/m3-wayland-vp9-provider-outcome-audit.jq) joins *externally supplied* compiled-source, later-harness and packaged archive hashes, validates real decoded-frame measurement consistency, canvas flags, screenshot, browser/profile isolation and per-group denial counter arithmetic. Its outputs distinguish **zero matching provider requests** from an actually exercised missing-provider path and do not equate WebGL2 availability, successful VP9 video, or Pixman software rendering with hardware VA-API/DMABuf/GBM fallback.

The [adversarial fixture suite](../../ci/tests/m3-wayland-vp9-provider-outcome-audit-tests.sh) rejected **27/27 falsified codec, graphics, source/package, denial, profile and release claims** in [lightweight CI 42666160423 PASS](https://github.com/sguzman/vulpra/actions/runs/42666160423), without launching a browser. This is a verified evidence-validator result, **not** runtime acceptance.

## Remaining acceptance and limits

For meaningful graphics evidence, separately establish what native provider loads occurred, whether actual VP9 and canvas worked in each mode, whether a real rendering device and compatible VA-API backend were present, and whether hardware software fallback actually ran. A successful Pixman frame with **VA-API 0** loads is **not** VA-API missing-provider coverage. Even positive matching denies do not prove which media code requested them or the hardware decoder identity without further source/runtime evidence.

Target EndeavourOS/Hyprland acceptance, complete conditional/indirect and Rust/C++ FFI closure, security integration and release are still outstanding. **M3 5/6 (83%); overall 61%, Δ +0 pp.** No milestone gate is credited for a pending CI run.
