# M3 — Original packaged Vulpra WebAudio to isolated PulseAudio null sink (2026-11-02)

## Actual original-browser Rust PulseAudio backend selection (2026-11-02)

[**Source-pinned native browser CI 41487961096 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41487961096). **Artifact 13162449750** was independently downloaded and the sanitized JSON inspected. The real original packaged browser in a disposable, no-network Arch Linux + Weston session started a live WebAudio oscillator following a WebDriver button click, established a fresh PulseAudio null-sink input, and exposed its own **native cubeb backend ID `pulse-rust`**. The JSON specifically records `reported_cubeb_backend: "pulse-rust"` and `reported_cubeb_backend_is_pulse_rust: true`, alongside the existing positive stream / mapped-library observations and negative permission/pruning claims. The new CI acceptance requires **both** exact runtime value and true boolean; no other backend counts as an accepted Rust PulseAudio witness.

The CI authenticated the listed source/build relationships; the conditional Rust crate import was separately inspected in the same pinned source:

- `media/libcubeb/src/cubeb.c` includes `pulse_rust_init` as its first conditional default cubeb backend.
- `media/libcubeb/src/moz.build` defines `USE_PULSE_RUST` when `MOZ_PULSEAUDIO` is enabled.
- `toolkit/library/rust/gkrust-features.mozbuild` requests `cubeb_pulse_rust` under that same configuration switch.
- `toolkit/library/rust/shared/Cargo.toml` declares optional `cubeb-pulse` with `pulse-dlopen`, pulled in by the `cubeb_pulse_rust` feature; `toolkit/library/rust/shared/lib.rs` conditionally declares `extern crate cubeb_pulse`.
- `dom/media/CubebUtils.cpp` obtains `cubeb_get_backend_id`; `toolkit/modules/Troubleshoot.sys.mjs` exposes `windowUtils.currentAudioBackend`, subsequently displayed by `toolkit/content/aboutSupport.js` in Firefox's media diagnostics.

This follow-up reads the same native **browser window `window.windowUtils.currentAudioBackend`** in GeckoDriver's privileged `chrome` context. Direct navigation to `about:support` was rejected by GeckoDriver as `unsupported operation` in preliminary diagnostic CI, and switching to `chrome` without privileged opt-in was likewise rejected. Final CI explicitly enabled `--allow-system-access` and `MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1` **only** for the disposable browser inside `docker run --network none`, with WebDriver bound to `127.0.0.1`, no physical audio/USB/device passthrough and no installed browser/profile access. The setting is absent from normal production launchers. The source and resulting ID together support **actual native runtime selection of the Rust PulseAudio backend**. The status is more precise than the first audio-stream CI, which proved only the sink stream.

**Scope limits:** The selected backend ID does **not** establish an exact C-to-Rust FFI call stack, static linker map, precise `dlopen` origin, complete transitive dependency closure, standalone hardware audio fidelity, microphone behavior, WebRTC, the host PipeWire server or target EndeavourOS/Hyprland behavior. `libpulse.so.0` was **already mapped before** the WebAudio action: do not call it a first-load transition. No files were pruned, no bytes saved, and M3 gate six remains open at **5/6 (83%)**, overall **61%**, session **Δ +0 percentage points**. The expensive workflow was restored to manual dispatch after verified acceptance.

## Original source, binary and execution evidence

[**Native browser CI 41483634953 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41483634953). The immutable **full-normal original** Vulpra archive was compiled at source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, verified using its original successful build [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527) and exact archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

**Artifact 13160971856** (`m3-original-browser-pulse-null-sink.json`) was independently downloaded and inspected. The job authenticated the exact original source checkout: `media/libcubeb/src/cubeb.c` contains `pulse_rust_init` as the first conditional default backend, `media/libcubeb/src/moz.build` defines `USE_PULSE_RUST` under `MOZ_PULSEAUDIO`, and the original `toolkit/library/rust/shared/Cargo.toml` declares the `pulse-dlopen` feature. This is a **source/feature possibility**, not a verified original compiled `USE_PULSE_RUST` value or identified native caller stack.

The actual original packaged browser ran through GeckoDriver in a disposable **Arch Linux + private Weston** environment. A new local-only Rust origin served a page with a user-clicked `AudioContext`, oscillator and destination connection. The job launched a separate PulseAudio server with only a virtual `module-null-sink`; no physical audio output, capture device, host audio socket or credentials were attached. The audio server was fresh and had **zero sink inputs before browser playback**. During the browser's successfully running live `AudioContext`, the test observed a **PulseAudio sink-input** and `libpulse.so.0` in Vulpra's native process mappings. All three native acceptance steps (workload, bounded JSON assertions, artifact upload) passed.

### Independently observed values

| Assertion | Value |
| --- | --- |
| Original packaged native browser executed | **true** |
| Real browser click started live `AudioContext` | **true** |
| Isolated PulseAudio null sink available | **true** |
| Sink inputs absent before browser action | **true** |
| PulseAudio sink input present during browser audio | **true** |
| `libpulse.so.0` mapped **before** browser click | **true** |
| `libpulse.so.0` mapped during audio | **true** |
| Exact native Rust PulseAudio callsite proved | **false** |
| Physical sound, microphone or host networking used | **false** |
| Target user's EndeavourOS/Hyprland verified | **false** |
| Source pruning authorized / M3 sixth gate closed | **false / false** |

The `libpulse` mapping was **already present before playback**; this run establishes **audio-stream integration with a PulseAudio server**, **not a newly triggered `dlopen` transition**. A fresh null-sink input in the isolated namespace is strong scoped evidence the original browser created an audio client stream, but the diagnostic does not authenticate stream attribution via PulseAudio's per-client process properties or a native C++→Rust call stack. It also does not verify successful physical speaker output, device timing, microphone, WebRTC, host PipeWire interoperation, a full feature-build/FFI/dynamic-dependency graph, or exact target workstation behavior.

The browser and its installed profile were untouched. Only disposable CI code and documentation changed; no source file was pruned, no package-size reduction credited, and this **does not close M3 gate six**. The expensive native audio workflow is restored to **manual dispatch**.

**Project progress remains M3 5/6 (83%), overall 61%, session Δ+0 percentage points.**
