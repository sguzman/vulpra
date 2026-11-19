# Firefox 160 RDD VP9: real libvpx decoding under combined FFVPX + system FFmpeg denial (2026-11-15)

**Result:** [Real original native Firefox160 combined-denial WebDriver CI 43758489134 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43758489134), and [independent authenticated decoder/source crosswalk CI 43758897535 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43758897535). One concrete observed protected video decoder fallback; **not** M3 completion.

## Original archive and source scope

This experiment reused exactly the existing unmodified Firefox160 Vulpra compiled native browser preview:

- Official Mozilla Firefox160 upstream commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Assembled Vulpra candidate source tree: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`; exactly **28 original Vulpra overlay paths**; no original upstream removals.
- Native Firefox160 compiled archive SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Original native producer: [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), SHA `0624235fdc956ab18af3c3f310b3588ca72fff61`. Original archive and source ledger independently preserved: [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827).
- The real combined-denial CI independently matched **10 exact official Firefox160 Git source blobs** from the immutable upstream checkout: `MediaFormatReader.cpp`, `MediaChangeMonitor.h/.cpp`, `AgnosticDecoderModule.cpp`, `VPXDecoder.h`, `FFmpegVideoDecoder.h`, `FFmpegLibWrapper.cpp`, `FFmpegLog.h`, `FFVPXRuntimeLinker.cpp`, and `RemoteDecoderChild.cpp`. All were verified against the exact official commit. Their original owning source/build was previously shown outside Vulpra's 28 overlay paths by [the full 10-blob source/decoder CI 43751456133](https://github.com/sguzman/vulpra/actions/runs/43751456133).

No original browser source, installed native file, system package, running personal Firefox Developer Edition profile or the user's EndeavourOS workstation was modified. Linux-only CI used an isolated browser executable, disposable `HOME`/WebDriver profile, temporary local VP9/WebM 192×108 fixture, native denial shim, and private Mozilla logs which were sanitized to bounded counters and source-defined decoder names before deletion.

## Experiment: the same actual browser, combined native FFVPX + system FFmpeg provider denial

The existing [C `dlopen`/`dlmopen` provider-denial shim](../../ci/m3-deny-optional-native-providers.c) gained a strictly opt-in `ffvpx_ffmpeg` group. It denies exactly the two bundled FFVPX basename candidates `libmozavcodec.so` and `libmozavutil.so` **and** the existing system `libavcodec.so.*`/`libavcodec-ffmpeg.so.*` candidate allowlist. A compiled C fixture demonstrated all **three named** test-provider loads blocked together, while the existing FFVPX-only and system-FFmpeg-only controls retained their separate behavior. No file removal or renaming occurred.

The actual [combined-browser CI 43758489134 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43758489134) counted the following **real native denied loader requests** in its private process-scoped shim log; only integer counts were exported:

| Actual source/basename-scoped native observation | Baseline | Combined provider-denied browser |
| --- | ---: | ---: |
| Bundled `libmozavcodec.so` denied native loads | 0 | **1** |
| Bundled `libmozavutil.so` denied native loads | 0 | **1** |
| System FFmpeg `libavcodec*` denied native loads | 0 | **14** |
| **Total explicitly denied** `dlopen`/`dlmopen` requests | **0** | **16** |
| Source-specific `FFVPX: Link result: NoProvidedLib` seen | No | **Yes** |
| New blocked loads after video navigation | 0 | **0** |
| Actual VP9 decoded frames (at least two), advancing media time, video dimensions | **Pass** | **Pass** |
| Media error | No | No |
| Browser still responsive and disposable Firefox profile sentinel intact | Yes | Yes |
| **Post-frame resolved MediaFormatReader video decoder description** | **`ffvpx video decoder (RDD remote)`** | **`libvpx video decoder (RDD remote)`** |

The browser initially reports `MediaChangeMonitor decoder (pending)`; it is a wrapper, not the actual video codec engine. After decoded frames, Firefox160 `MediaFormatReader` refreshes its video decoder description, and the source-defined `GetDescriptionName()` reports the final engine. Transient `uninitialized` trace values are not treated as real decoder selections. `RemoteDecoderChild` appends ` (RDD remote)`. The **libvpx** description comes directly from Firefox160 `VPXDecoder.h`; `AgnosticDecoderModule.cpp` constructs the `VPXDecoder` for eligible VPX video.

The selected libvpx backend and actual decoded frames in the combined-denied browser were **directly observed**, not inferred from mere playback success. The FFVPX `NoProvidedLib` link-result message was also observed in the same native browser test.

The earlier independently source-attested [FFVPX-only real native media run 43750879381](https://github.com/sguzman/vulpra/actions/runs/43750879381) had already shown that with only `libmozavcodec.so` and `libmozavutil.so` denied, Firefox160 selected `ffmpeg video decoder (RDD remote)`, decoded VP9 and had no media error. The combined-denial experiment is **a different real workload**, not a claim that all three decoder states appeared in one session.

### The three real observed VP9 paths

| Test condition | Actual post-frame decoder in RDD | Result |
| --- | --- | --- |
| No provider denied | **FFVPX** | VP9 decoded |
| Bundled FFVPX denied, system FFmpeg not denied | **system FFmpeg** | VP9 decoded |
| Bundled FFVPX **and** requested system FFmpeg library names denied | **libvpx** | VP9 decoded |

All three refer to the same original compiled package bytes, tested in controlled, separate headless Linux CI sessions. The system FFmpeg-denial count of 14 verifies that the tested library load candidates were **actually requested and blocked**. It does **not** by itself prove every conceivable FFmpeg native load path or separately configured decoder was absent.

## Independent source/native reconciliation and negative controls

The final evidence-only [CI 43758897535 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43758897535) authenticated complete producer run IDs, exact full head commit SHAs, successful results and the precise unexpired GitHub artifact names for both:

- Prior source-attested real FFVPX → system FFmpeg RDD fallback crosswalk: [43751456133](https://github.com/sguzman/vulpra/actions/runs/43751456133), artifact **14176208580**.
- New original native FFVPX+system FFmpeg denied → libvpx RDD experiment: [43758489134](https://github.com/sguzman/vulpra/actions/runs/43758489134), artifact **14178683448**.

The strict [independent jq verifier](../../ci/m3-firefox160-combined-ffvpx-ffmpeg-libvpx-crosswalk.jq) required exact official original source and compiled archive identity, prior authentic RDD FFmpeg backend selection when only FFVPX was denied, combined observed 1+1+14 blocked loads, source-specific `NoProvidedLib`, both actual successful VP9 playback outcomes, an exact final libvpx decoder description and all explicit false complete-security/FFI/source-pruning flags. **All 16/16 deliberately falsified source, checksum, codec/utility/FFmpeg-count, decoder, media, profile, logging, and completion reports were rejected.**

Final accepted, downloaded and inspected bounded artifact: `firefox160-actual-combined-ffvpx-ffmpeg-libvpx-source-crosswalk-not-full-m3` (**14179651140**).

## Hard limitations retained

This experiment establishes an actually selected **libvpx** VP9 decoder in the RDD process **with the observed FFVPX and system FFmpeg load requests blocked**. It does **not** prove all possible libavcodec loading paths or FFmpeg implementations absent on every target system; exact direct machine-code caller stack and every `dlopen/dlsym` branch; all Rust/C++/generated FFI dependency consumers; H264/AV1/VP8 and other media types, VAAPI/Vulkan/DMABuf hardware and zero-copy behavior, Wayland/Hyprland mixed NVIDIA/iGPU behavior; all security/sandbox/Safe Browsing and NSS module fallback outcomes; or release readiness.

Neither these successful media tests nor the 10 pinned original upstream blobs authorize source pruning. No full M3 acceptance conclusion may be drawn. Draft PR #6 stays open and unmerged; issues #8/#9 remain open. No workstation actions or original browser rebuild were performed.

**Progress:** M3 last complete dependency/FFI/conditional-feature gate remains **OPEN, 5/6 = 83%**. Overall Vulpra **61%, Δ +0 percentage points**. Next work should use source-pinned disposable CI to exercise the NSS FreeBL/softoken loader failure or more specific missing-codec media cases, and **not** repeat the now-authenticated VP9 fallback tests without a new coverage target.
