# M3 — Original native dynamic requests traced to source candidates (2026-10-30)

## Verified identity, acceptance and evidence

These are three **glibc loader-reported dynamic-load requests** observed only in the **private-Weston graphical workload**, compared with a headless New Tab workload, using the *same original compiled Vulpra archive*. The original Firefox browser source is pinned to `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

- Real native headless [loader run 41137841775](https://github.com/sguzman/vulpra/actions/runs/41137841775) **PASS** with 80 observed initialized-target `needed by` and 18 observed initialized-target dynamic-request relations.
- Real native graphical no-egress [Weston run 41137841911](https://github.com/sguzman/vulpra/actions/runs/41137841911) **PASS** with 147 observed `needed by` and 21 observed dynamic-request relations, plus the actual 10-second non-null Wayland buffer/commit and isolated profile.
- [Pinned source-matched request-edge crosswalk 41138174618](https://github.com/sguzman/vulpra/actions/runs/41138174618) **PASS**; artifact `13016754545`: 80 `needed by` and 18 dynamic requests common to both, 67 and 3 respectively graphical-only, zero headless-only.
- [Audited source-candidate verifier 41138797948](https://github.com/sguzman/vulpra/actions/runs/41138797948) **PASS**, artifact `13018260526`: re-checks the three real dynamic requests against source files in a separate, immutable historical checkout; rejects forged source SHAs, missing or additional loader edges, wrong requester, and invented acceptance. The generated JSON preserves only safe file paths within the public repository, not raw loader files, process IDs, personal paths, or user state.

## Three source-supported candidates

| Observed dynamic requester → requested library | Exact original source/build evidence | Interpretation |
| --- | --- | --- |
| `libnspr4.so → libavcodec.so.60` | [`dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp`](https://github.com/sguzman/vulpra/blob/b1482404dfb8b01342990ee99ea3df0f9756b5f7/dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp) explicitly lists `libavcodec.so.60` and invokes `PR_LoadLibraryWithFlags(... PR_LD_NOW \| PR_LD_LOCAL)`; `dom/media/platforms/ffmpeg/moz.build` includes the linker source. | NSPR is the **reported loader requester**. The application-level candidate is Firefox's FFmpeg runtime linker; this does **not** prove that libnspr4 itself owns a codec feature, nor which media route was invoked. |
| `libxul.so → libgbm.so.1` | [`widget/gtk/DMABufDevice.cpp`](https://github.com/sguzman/vulpra/blob/b1482404dfb8b01342990ee99ea3df0f9756b5f7/widget/gtk/DMABufDevice.cpp) defines `GBMLIB_NAME` as `libgbm.so.1`, calls `dlopen(GBMLIB_NAME, RTLD_LAZY \| RTLD_LOCAL)`, resolves functions with `dlsym`; `widget/gtk/moz.build` includes `DMABufDevice.cpp`. | GTK DMA-BUF/GBM is a direct, strong **source-level dynamic-load candidate**, but a native call stack or instruction trace was not captured. |
| `libxul.so → libpulse.so.0` | `media/libcubeb/src/moz.build` ties `MOZ_PULSEAUDIO` to `USE_PULSE_RUST`; `media/libcubeb/src/cubeb.c` registers `pulse_rust_init`; `toolkit/library/rust/gkrust-features.mozbuild` enables `cubeb_pulse_rust` under the same config; `toolkit/library/rust/shared/Cargo.toml` declares a **pinned external `cubeb-pulse-rs` Git revision** with feature `pulse-dlopen`. | PulseAudio/cubeb is a supported **build/source feature candidate**. The compiled code of the external pinned crate, exact symbol resolution and source line of the runtime call have **not** been independently audited. A local `third_party/rust/cubeb-pulse` copy is **not assumed equivalent** to that external Git revision. |

This crosswalk confirms the **original source contains candidate invocation routes and build declarations**. It does **not** assign a native crash or prove each library is required exclusively by Wayland; FFmpeg, audio and GPU paths may be exercised in other workloads and host environments.

## Explicitly unverified

- Full native source-to-runtime stack attribution and all feature-route invocations.
- Complete `dlopen` relation graph, all transitive host dependencies, symbol-version/ABI resolution, Arch/Hyprland host parity.
- Actual generated `MOZ_PULSEAUDIO` value or the source text at the pinned external `cubeb-pulse-rs` revision from **this source-candidate verifier**. Runtime observed the library, but that alone does not prove a feature flag or concrete call path.
- A fix for the [ordinary Ubuntu network-namespace-sensitive SIGSEGV](M3-WAYLAND-SIGSEGV-20261030.md).
- Any additional feature exclusion, source deletion, package size saving, or full sixth M3 gate closure.

**Progress is unchanged:** M3 **5/6 = 83%**, overall **61%**, current round **Δ+0 percentage points**.
