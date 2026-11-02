# M3 — Original packaged Vulpra WebAudio to isolated PulseAudio null sink (2026-11-02)

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
