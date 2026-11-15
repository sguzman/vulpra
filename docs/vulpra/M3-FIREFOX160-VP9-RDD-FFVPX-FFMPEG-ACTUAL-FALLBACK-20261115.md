# Firefox 160: actual RDD VP9 decoder fallback from FFVPX to system FFmpeg (2026-11-15)

## Verified acceptance: one concrete protected media fallback, not complete M3

**Independent [CI 43751456133 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43751456133)** conclusively reconciled the immutable upstream source, actual original native browser bytes and real WebDriver media-decoder log observations. It independently verified **ten** upstream Firefox 160 source Git blobs, showed that **none** were in Vulpra's 28 source overlays, and rejected **16/16 deliberately forged source, decoder, native provider, privacy or false-completion evidence variants**.

The original native browser [real FFVPX denied VP9 CI 43750879381 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43750879381) demonstrated this *source-reported, resolved post-frame decoder selection*:

| Verified actual Firefox 160 WebDriver condition | Baseline | Both bundled FFVPX libraries denied |
| --- | --- | --- |
| Initial decoder description, before first video samples | `MediaChangeMonitor decoder (pending)` | `MediaChangeMonitor decoder (pending)` |
| **Resolved video decoder description after video samples** | **`ffvpx video decoder (RDD remote)`** | **`ffmpeg video decoder (RDD remote)`** |
| Validated VP9/WebM 192×108 actual decoded video frames, dimensions and advancing playback time | **PASS** | **PASS** |
| Native `libmozavcodec.so` loads blocked | 0 | **1** |
| Native `libmozavutil.so` loads blocked | 0 | **1** |
| Source-specific `FFVPX: Link result: NoProvidedLib` messages | 0 | **1** |
| New blocked FFVPX attempts after video navigation | 0 | **0** |
| Media error during test | **None** | **None** |
| Browser responsive, disposable private profile sentinel unchanged | **Yes** | **Yes** |

The two FFVPX library load denials and the `NoProvidedLib` message occurred before video navigation. The selected FFmpeg decoder was **observed after video samples** and correlated with actual WebDriver verified VP9 decoding. This is not merely a theoretical source fallback or an inference from successful playback. The exact software decoder name is an official Mozilla `GetDescriptionName()` value passed through a remote RDD decoder wrapper; no modified browser source or injected debugger was required.

The original real run logged **70** MediaFormatReader video update events in baseline and **61** in FFVPX-denied mode. The sanitized observer retained only source-defined decoder-description literals and counters. Transient `uninitialized` labels were observed and are not treated as decoder implementations. Original bounded runtime artifact `firefox160-original-bundled-ffvpx-denial-real-vp9-not-full-fallback` (**14176750695**) was downloaded and inspected.

### Immutable source and native package provenance

- Original Mozilla Firefox 160 source commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Source-assembled Vulpra candidate tree with exactly 28 verified overlay paths: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`.
- Original unchanged native Firefox160 Vulpra archive SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- [Original native browser producer 43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), compiled branch `0624235fdc956ab18af3c3f310b3588ca72fff61`.
- [Independent original archive and materialized source-tree proof 43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827), exact preservation branch `54728803f058c3edf54d2e8d3f6e0a7d2af0aec6`.

The exact official source checks used **10 matching original Git blobs**, all shown not to overlap the 28 authentic Vulpra patches: `dom/media/MediaFormatReader.cpp`, `dom/media/platforms/wrappers/MediaChangeMonitor.h` and `.cpp`, `dom/media/platforms/agnostic/VPXDecoder.h` and `AgnosticDecoderModule.cpp`, `dom/media/platforms/ffmpeg/FFmpegVideoDecoder.h`, `FFmpegLibWrapper.cpp`, `FFmpegLog.h`, `ffvpx/FFVPXRuntimeLinker.cpp`, and `dom/media/ipc/RemoteDecoderChild.cpp`. Their SHA identity was checked directly against the separate official Firefox160 release checkout's `HEAD:path` and disk `git hash-object` values, rather than Vulpra's working tree.

These exact sources explain the observed output:

- `FFVPXRuntimeLinker::Init()` attempts both bundled `libmozav*` libraries, calls `FFmpegLibWrapper::Link()`, logs its result and only initializes FFVPX if linking succeeds.
- `FFmpegLibWrapper::Link()` returns `NoProvidedLib` if either native provider is missing.
- `MediaFormatReader::DecoderFactory::DoInitDecoder()` initially logs the wrapper's `GetDescriptionName()`. The `MediaChangeMonitor` wrapper returns `MediaChangeMonitor decoder (pending)` until a child decoder is ready.
- After the first decoded video sample, `MediaFormatReader` refreshes its stored decoder description from `mVideo.mDecoder->GetDescriptionName()`, and its `Update(video)` verbose trace exposes the resolved value.
- `FFmpegVideoDecoder::GetDescriptionName()` returns `ffvpx video decoder` under `USING_MOZFFVPX`, and `ffmpeg video decoder` for system FFmpeg.
- `RemoteDecoderChild` appends ` (RDD remote)` to the real decoder's description from the remote parent. Therefore, these exact distinct observed post-frame strings identify the FFVPX baseline and FFmpeg fallback in the RDD process, not just a generic remote-wrapper placeholder.

The native browser was **never recompiled**, and there was no original source deletion, host library removal, permanent profile modification, target Arch workstation access or browser reinstall.

### Independent reconciliation and falsification

The independent [source + two native media-denial experiments crosswalk CI 43747660588 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43747660588) validated that the original Firefox160 package decoded VP9 when system FFmpeg was separately denied (**14** early blocked system loads), and separately when bundled FFVPX was denied (**2** early loads). These were different browser workloads. The earlier [exact FFVPX per-library check CI 43748375268 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43748375268) confirmed **one blocked codec library and one blocked util library**. Its original source/ABI credentials and false-claim flags remained intact.

The final [artifact-only post-frame decoder-source reconciliation 43751456133 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43751456133) matched those two independent reports to [real post-frame decoder run 43750879381](https://github.com/sguzman/vulpra/actions/runs/43750879381), authenticated successful CI producer names, full commit SHAs and unexpired artifacts, checked the additional ten exact source blobs and their non-overlap with Vulpra overlays, then required the exact **FFVPX → system FFmpeg** post-frame descriptions along with genuine VP9 frames, two blocked `libmozav*` calls, the native `NoProvidedLib` diagnostic, private profile survival and conservative M3 completion flags.

**All 16/16 deliberately corrupted original source, prior-denial, per-SONAME, decoder-description, link-result, playback, privacy and false-gate records failed validation.** The archived independent report is `firefox160-verified-post-frame-rdd-ffvpx-to-ffmpeg-vp9-not-full-m3-closure` (artifact **14176208580**, downloaded and checked).

### What is still NOT proven

The **one** RDD VP9 fallback route is now actually observed with source-derived decoder identities. That does **not** prove system FFmpeg will be available in every environment, both FFVPX and FFmpeg denied simultaneously, all VP8/VP9/AV1/H264/H265 variants, VAAPI/Vulkan/DMABuf/video zero-copy, GPU acceleration, multi-display NVIDIA/iGPU, or the target EndeavourOS/Hyprland host. It also does not prove every NSS/FFVPX/NSPR/glibc `dlopen`/`dlsym` callsite with machine disassembly, all Rust/C++ and generated FFI consumers, complete static/dynamic library dependency closure, sandbox/security-current acceptance, or permission to remove source files.

Actual FFVPX's **NoProvidedLib** source-specific log and selected working FFmpeg decoder are real runtime evidence; a separate machine-code branch/callstack tracing claim remains false. No original GitHub PR merge or public release is authorized.

**Accounting unchanged:** M3 last dependency/FFI/protected-feature gate remains **OPEN: 5/6 (83%)**; Vulpra overall remains **61%**, session **Δ +0 pp**. [Draft PR #6](https://github.com/sguzman/vulpra/pull/6) remains open/unmerged and issues #8/#9 remain unresolved. Next bounded work should test either FFVPX and system FFmpeg simultaneously unavailable or the NSS FreeBL/softoken guarded failure behavior, still preserving all system libraries and exact original source files.
