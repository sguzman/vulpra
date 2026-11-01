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

## Exact external Rust PulseAudio source closure (2026-10-31)

[Two-revision, source-only CI 41262201541](https://github.com/sguzman/vulpra/actions/runs/41262201541) **PASSED** with bounded artifact **13065244306**; [workflow lint 41262201517](https://github.com/sguzman/vulpra/actions/runs/41262201517) **PASSED**. The verifier `ci/m3-pinned-pulse-dlopen-source.rs` checks two exact, separately authenticated Git trees and rejects missing source anchors. The original Gecko source `b1482404` pins `mozilla/cubeb-pulse-rs` at `88194f91c8778fa608a19af7b91306094525595d` with feature `pulse-dlopen`.

The exact external source closes the previously uninspected *source candidate* chain: Gecko `USE_PULSE_RUST` / `cubeb.c` selects the C ABI `pulse_rust_init`; the external [`src/capi.rs`](https://github.com/mozilla/cubeb-pulse-rs/blob/88194f91c8778fa608a19af7b91306094525595d/src/capi.rs) dispatches to `PulseContext`. Its [`src/backend/context.rs`](https://github.com/mozilla/cubeb-pulse-rs/blob/88194f91c8778fa608a19af7b91306094525595d/src/backend/context.rs) feature-gates `open()` and has an explicit failure branch if libpulse is absent. The external root `pulse-dlopen` Cargo feature enables `pulse-ffi/dlopen`, whose [`pulse-ffi/src/lib.rs`](https://github.com/mozilla/cubeb-pulse-rs/blob/88194f91c8778fa608a19af7b91306094525595d/pulse-ffi/src/lib.rs) calls `LibLoader::open()`; [`pulse-ffi/src/ffi_funcs.rs`](https://github.com/mozilla/cubeb-pulse-rs/blob/88194f91c8778fa608a19af7b91306094525595d/pulse-ffi/src/ffi_funcs.rs) explicitly invokes `dlopen("libpulse.so.0", RTLD_LAZY)` and resolves PulseAudio functions with `dlsym`.

This proves the *exact-revision source route*, not that the observed glibc request executed that specific call site. It does not verify the exact compiled `MOZ_PULSEAUDIO` value, native FFI/linker binding, runtime call stacks, Arch host compatibility, or the complete conditional dynamic-loading graph. It authorizes no source removal or new M3 gate credit.

## Original pinned PulseAudio function ABI against an actual Ubuntu host (2026-10-31)

[Real host ELF audit 41262701646](https://github.com/sguzman/vulpra/actions/runs/41262701646) **PASSED**, artifact **13064984891**; [workflow lint 41262701481](https://github.com/sguzman/vulpra/actions/runs/41262701481) **PASSED**. The new `ci/m3-pinned-pulse-host-abi.rs` parses all **82** literal `dlsym` function requests in the exact pinned `mozilla/cubeb-pulse-rs` commit `88194f91` and compares them to the **actual** little-endian x86-64 dynamic function exports of Ubuntu 24.04's `libpulse.so.0`, using binutils `nm -D`. **82/82 function names were found; zero were missing.** The source revision, x86-64 ELF identity, unique symbol names, fixture failures and bounded output are checked in CI.

This establishes only one **source-revision-to-Ubuntu-host library ABI**. It does **not** confirm the original browser's exact evaluated `MOZ_PULSEAUDIO`, the compiled caller's actual `dlopen` route, successful initialization of PulseAudio, compatible symbol versions on other hosts, Arch/Hyprland compatibility, or the complete native graph. No additional source can be pruned and the M3 sixth gate remains open.

## Original GTK DMA-BUF GBM/DRM host-function ABI (2026-10-31)

[Real Ubuntu ELF CI 41262872037](https://github.com/sguzman/vulpra/actions/runs/41262872037) **PASSED**, artifact **13065778386**. The bounded `ci/m3-pinned-dmabuf-host-abi.rs` verifies original Gecko commit `b1482404` and examines its authentic `widget/gtk/DMABufDevice.cpp` literal runtime requests. The source loads both `libgbm.so.1` and `libdrm.so.2` conditionally. All **18/18** required GBM functions and **1/1** DRM function are present in the respective real Ubuntu 24.04 little-endian x86-64 host ELF dynamic export tables; zero missing. Fail-closed Rust parser and missing-export fixtures passed; [workflow lint 41262837965](https://github.com/sguzman/vulpra/actions/runs/41262837965) **PASSED**. The initial CI run failed on a Rust symbol-set type inference error, which was corrected at commit `01a022ec`; only the later successful run is accepted.

This resolves the *source-to-specific-host dynamic function-name ABI* for both DMA-BUF libraries; it is **not** evidence of the browser's exact linked callsite, successful device operation, broader `dlopen` closure, full host/Arch symbol versions, or safe source removal. No whole M3 sixth-gate credit.

## Real host glibc dynamic symbol resolution (2026-10-31)

The scoped host ABI studies were independently strengthened beyond static symbol-table presence:

- [PulseAudio runtime loader CI 41263023348 PASS](https://github.com/sguzman/vulpra/actions/runs/41263023348), artifact **13065394897**: glibc successfully `dlopen`ed `libpulse.so.0` with `RTLD_LAZY` and returned non-null `dlsym` pointers for all **82/82** functions requested by the exact pinned external Rust source.
- [GTK DMA-BUF runtime loader CI 41263026786 PASS](https://github.com/sguzman/vulpra/actions/runs/41263026786), artifact **13065927862**: glibc successfully `dlopen`ed `libgbm.so.1` and `libdrm.so.2` with `RTLD_LAZY | RTLD_LOCAL` and resolved all **18 GBM** plus **1 DRM** requested functions. [Lint 41263026719 PASS](https://github.com/sguzman/vulpra/actions/runs/41263026719).

These are genuine host-side loader operations on disposable Ubuntu 24.04 CI runners, not executed inside the compiled Vulpra process. They establish callable pointer *resolution*, **not** function correctness or successful device/audio initialization, original compiled feature activation, root-cause diagnosis for graphical SIGSEGV, or target Arch/Hyprland ABI. The sixth M3 gate remains open; no pruning or new savings.

## Original FFmpeg 60 loader and host-version function (2026-10-31)

[Exact original source + real Ubuntu host loader CI 41263175174](https://github.com/sguzman/vulpra/actions/runs/41263175174) **PASSED**, artifact **13065749110**; [workflow lint 41263175182](https://github.com/sguzman/vulpra/actions/runs/41263175182) **PASSED**. The new Rust verifier `ci/m3-pinned-ffmpeg60-host-loader.rs` checks exact Gecko source `b1482404` for the `libavcodec.so.60` candidate, NSPR `PR_LoadLibraryWithFlags(... PR_LD_NOW | PR_LD_LOCAL)`, handoff to `FFmpegLibWrapper::Link()`, C ABI declaration and `PR_FindSymbol(... "avcodec_version")`. Against actual Ubuntu 24.04 x86-64 `libavcodec.so.60`, glibc `dlopen` with `RTLD_NOW | RTLD_LOCAL` succeeded, `dlsym` resolved `avcodec_version`, and calling that C ABI function returned major version **60**. Rust negative fixtures reject missing original source or host inputs.

This is actual **host-library initialization and one function call**, but it neither proves the original Vulpra process traversed this callsite nor resolves every version-gated required/optional FFmpeg function. It does not establish video-decoding behavior, Arch compatibility or other `dlopen` routes; no source removal or full M3 acceptance is authorized.

Together, the scoped FFmpeg 60, PulseAudio and GTK DMA-BUF host experiments now cover the **three library names observed only in the original graphical loader workload**, but they do **not** turn three observed requests into a complete browser feature/dependency map. Their original source candidates, supported host bindings and incomplete runtime attribution remain explicitly separate.

## FFmpeg 60 mandatory version-gated native bindings (2026-10-31)

[Expanded exact-source + actual Ubuntu host CI 41263719499](https://github.com/sguzman/vulpra/actions/runs/41263719499) **PASSED**, artifact **13065844546**, with 3 Rust regression fixtures passed. The expanded `ci/m3-pinned-ffmpeg60-host-loader.rs` parses the original pinned `FFmpegLibWrapper.cpp` `AV_FUNC` (mandatory, not `AV_FUNC_OPTION`) macro call list, evaluates the major-60 version-bit selectors, excludes the Android-only section, and checks the real glibc `dlsym` bindings from Ubuntu 24.04 `libavcodec.so.60`. Of **51** mandatory macro declarations across version families, **44** apply to FFmpeg major 60, and **44/44** resolved successfully with zero missing; the audited RTLD_NOW open and `avcodec_version` invocation still passed. A first expanded-run failure identified an incorrectly cased audit source assertion (`MissingFFmpegFunction` versus original `MissingFFMpegFunction`), corrected before the accepted run.

This verifies the **version-60 mandatory function-name resolution for the pinned original loader source on one Ubuntu host**, not optional GPU/media feature paths, actual video decode, complete FFmpeg version-family parity, originating browser call stacks, Arch/Hyprland host closure, or whole M3 completion.

## Major-60 optional source-declared FFmpeg capabilities (2026-10-31)

[Extended original-source + real-host check 41263892872 PASS](https://github.com/sguzman/vulpra/actions/runs/41263892872), artifact **13066377046**, [lint 41263892759 PASS](https://github.com/sguzman/vulpra/actions/runs/41263892759). The accepted JSON artifact reports **27/27** optional major-60 `AV_FUNC_OPTION` or `AV_FUNC_OPTION_SILENT` native function names resolved, with **zero unavailable**, separately from the already accepted **44/44 mandatory** bindings. The original Linux GTK-specific option block is included; Android-only functions are excluded. **71/71** in-scope original major-60 mandatory-plus-optional named function bindings resolved from actual Ubuntu 24.04 `libavcodec.so.60` through glibc. Source macro-scope count and original `avcodec_version` major verification are preserved.

The report deliberately retains `complete_ffmpeg_function_set_verified:false`: it does not test every codec version, non-`AV_FUNC` dynamic loading, actual decoding, or actual original Vulpra callsites and Arch/Hyprland host parity. No source removal or sixth-gate acceptance follows from this scoped result.

## Independent disposable Arch Linux dynamic host ABI (2026-10-31)

[Arch Linux x86-64 container CI 41266577521](https://github.com/sguzman/vulpra/actions/runs/41266577521) **PASSED** after a first attempt exposed an isolated bind-volume UID/permissions error; the corrected run executed the probes as the unprivileged CI volume owner with a **read-only root filesystem, no container network, all Linux capabilities dropped and `no-new-privileges`**. [Workflow lint 41266577514](https://github.com/sguzman/vulpra/actions/runs/41266577514) **PASSED**. The artifact **13067860323** preserves two bounded JSON reports and base image provenance, verified by independent artifact inspection.

- Exact external pinned `cubeb-pulse-rs` revision `88194f91`: actual Arch `libpulse.so.0` exports and glibc `dlopen`/`dlsym` resolved **82/82** literal dynamic function requests, **0 missing**.
- Exact original Gecko `b1482404` GTK DMA-BUF: actual Arch `libgbm.so.1` **18/18** and `libdrm.so.2` **1/1** source-declared glibc dynamic function requests resolved, **0 missing**.
- **101/101** in-scope named dynamic functions resolved across the independent Arch container's actual libraries; source and runtime identity verified. Base image pulled at immutable recorded digest `archlinux@sha256:e82623936fa1a69700b48e98b058df6eaab18b737c27473a7234a40fdecb9413`, while downstream rolling package versions are not pinned.

The **Arch container is not the user's EndeavourOS workstation**. Successful symbol binding does not establish an actual Wayland/Hyprland GPU or audio device, source feature activation in the compiled Firefox, full dynamic load dependency coverage, Arch host package-version reproducibility, or entire M3 gate completion. Explicit artifact flags `arch_container_abi_verified=true`, `arch_host_abi_verified=false`, and `m3_sixth_gate_closed=false` preserve these boundaries. No code was pruned.

## Explicitly unverified

- Full native source-to-runtime stack attribution and all feature-route invocations.
- Complete `dlopen` relation graph, all transitive host dependencies, symbol-version/ABI resolution, Arch/Hyprland host parity.
- Actual generated `MOZ_PULSEAUDIO` value and the compiled/runtime call stack. The separately accepted exact-revision external source audit above proves a conditional code route, not that the observed native request traversed it.
- A fix for the [ordinary Ubuntu network-namespace-sensitive SIGSEGV](M3-WAYLAND-SIGSEGV-20261030.md).
- Any additional feature exclusion, source deletion, package size saving, or full sixth M3 gate closure.

**Progress is unchanged:** M3 **5/6 = 83%**, overall **61%**, current round **Δ+0 percentage points**.
