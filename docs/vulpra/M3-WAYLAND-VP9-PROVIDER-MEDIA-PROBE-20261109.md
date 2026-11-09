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

## Actual completed native browser result — 2026-11-09 UTC

**The previously in-progress real browser run [42665579538 completed SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42665579538)**. Every step completed: authenticating the retained native package, preparing private Weston, starting Vulpra via Geckodriver, checking VP9 decode/video pixel readback/WebGL2, and uploading the bounded runtime report. The original report was downloaded from artifact **13696587813**, parsed, and checked against its compiled source `a17ac58d694bf77c4da352ed7ab9b37233fbc01e`, harness `f8d16a0cb63686e750d97267d79043fd2b194a5d` and real test-only package SHA-256 `f92fe8c29843e7521ffe1ddd7cbbed8836ff9491228b182628973e8484ed1a41`. No browser rebuild or workstation installation occurred.

| Actual non-headless graphical mode | Baseline | GBM/DRM denied | VA-API denied |
| --- | ---: | ---: | ---: |
| VP9/WebM decoded frames | **8** | **10** | **10** |
| Advancing video `currentTime` | **0.524 s** | **0.522 s** | **0.562 s** |
| Video intrinsic dimensions | 192×108 | 192×108 | 192×108 |
| HTML media errors / rejected `play()` | None | None | None |
| Video frame → 2D canvas pixel readback | **Pass** | **Pass** | **Pass** |
| WebGL2 context creation | **Available** | **Available** | **Available** |
| W3C WebDriver browser screenshot | Pass | Pass | Pass |
| Browser/WebDriver alive, original temporary profile unchanged | Pass | Pass | Pass |
| Denied matched native provider loads **before** media-page navigation | 0 | **1** | **0** |
| Denied matched native provider loads **after** media-page navigation | 0 | **1** | **0** |
| **Additional** matching loads during/after navigation | 0 | **0** | **0** |

**Supported:** A real graphical Wayland Vulpra session with a matching GBM/DRM library request denied nevertheless decoded VP9 frames, advanced playback, read decoded video into a 2D canvas, created a WebGL2 context, produced an actual browser screenshot, and remained responsive with private-profile integrity. The observed **one** GBM/DRM denied request occurred **before page navigation**. Accordingly it is a *same-browser-session observed native load denial and later media playback*; it is not evidence the media page itself attempted GBM, nor identification of the specific `libgbm` versus `libdrm` SONAME.

**Unsupported:** Under `VULPRA_M3_DENY_GROUP=vaapi`, the browser was instrumented but **zero** selected VA-API library requests were observed; the successful playback was not a VA-API denial fallback exercise. A created WebGL2 context is **not** proof of accelerated GPU execution or actual WebGL shader/texture rendering. 2D canvas readback does not identify the VP9 decoder. Pixman Weston is a software compositor; no native GPU/DMABuf allocation or VA-API device/backend was demonstrated. The run also lacks a full graphical same-surface Wayland attach+commit trace in this specific WebDriver experiment; that stronger graphical surface witness comes from the **separate** earlier [Weston graphical startup run 42662005847](https://github.com/sguzman/vulpra/actions/runs/42662005847).

**Independent source/package/denial/media reconciliation:** a new read-only audit action at [`ci/m3-wayland-vp9-provider-outcome-audit.jq`](../../ci/m3-wayland-vp9-provider-outcome-audit.jq) was wired to download the actual successful run artifact after independently checking its run ID, completion status and `headSha`. It requires the exact observed counts above, source/package hashes, decoded-frame and media/canvas consistency, original profile safety, and explicitly false GPU/VA-API/FFI/pruning/release claims. The historical [fixture CI 42666160423 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42666160423) independently rejected 27/27 forged metadata cases. The new actual-run reconciliation must be checked for its **own** success before counting independent acceptance.

**Progress unchanged:** M3 **5/6 gates (83%)**, overall **61%, Δ+0 pp**; the outstanding sixth gate requires more than this single workload, notably target EndeavourOS/Hyprland graphics and complete feature/loader/FFI closure. There is no release approval or safe source-pruning authorization.

## Independent validator execution status

The newly wired [independent report-classifier workflow attempt **42671752562**](https://github.com/sguzman/vulpra/actions/runs/42671752562) and the concurrent [workflow-linter attempt **42671752683**](https://github.com/sguzman/vulpra/actions/runs/42671752683) both concluded **failure with zero jobs in the GitHub Actions REST job listing**. Therefore neither the new independent action nor its linter provides an accepted CI result. There are no job steps/logs on those attempts from which to establish a root cause; do not attribute the failure to the test code, network, quota, or YAML without further evidence.

The **actual browser run 42665579538 remains independently downloadable and successful**. The retained artifact **13696587813** was separately opened and a local structural verifier checked the exact source/harness/package hashes, all three video-frame/time/media-error results, 2D canvas readback and WebGL2-creation fields, screenshot/browser/profile status, and **GBM denial count 1→1 / VA-API count 0→0**. All those local assertions passed. This is **local independent inspection of an actual recorded runtime report**, not a successful independent GitHub Actions reconciliation. The older synthetic 27/27 classifier CI passed separately at 42666160423.

Future follow-up: first establish why Actions produced zero jobs, then rerun the already committed read-only reconciliation without rebuilding Firefox; treat any earlier failing attempt as an unaccepted control. Until then the native run and manually audited artifact support the bounded VP9/Wayland result, while GPU/VA-API/DMABuf fallback and complete M3 gate six remain unverified.
