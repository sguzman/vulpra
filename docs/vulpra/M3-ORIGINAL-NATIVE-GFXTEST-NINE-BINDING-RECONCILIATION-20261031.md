# M3 — Original gfxtest private Wayland bindings and nine-requester reconciliation (2026-10-31 UTC)

## Authenticated graphical helper observation

[Original compiled `gfxtest` private Weston glibc binding workflow 41165690323 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41165690323), [workflow lint 41165690101 PASS](https://github.com/sguzman/vulpra/actions/runs/41165690101). The original exact compiled Vulpra package came from source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, tar.xz SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

The existing targeted `ci/m3-gfxtest-private-wayland.sh` created a private headless Weston/pixman compositor, disposable HOME and Wayland socket and invoked the original `gfxtest glx --wayland` diagnostic path with opt-in `LD_DEBUG=versions,bindings`. The original test asserts a real Wayland connection and EGL probe roundtrip. It **does not** prove hardware GPU acceleration, full graphical browser functionality, or no network egress. This workload explicitly reports `no_network_egress=false`: unlike the restricted auxiliary and synthetic ML test fixtures, this Weston probe was not run in a separate network namespace.

The bounded std-only Rust observer recorded **64 actual original `gfxtest` normal-symbol binding events**, **59 distinct symbol/provider pairs** and **5 provider basenames** from a real requester PID trace. No raw loader traces, symbol names, absolute paths, process IDs, installed browser settings or profiles were uploaded.

## Independent original nine-requester reconciliation

[Independent nine-requester reconciliation 41165821665 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41165821665), [global workflow lint 41165821693 PASS](https://github.com/sguzman/vulpra/actions/runs/41165821693). This new report verifies exact source/archive identity and success/head-commit provenance for five independent source-pinned CI workflow artifacts. Its `ci/m3-original-real-binding-nine-requester-union.jq` checks the private-Weston/non-netns evidence flags separately from genuine no-egress paths, refuses unexpected provider names or counts, and never reads raw logs.

| Original compiled ELF requester group | Actual glibc normal binding events | Distinct requester/symbol/provider combinations |
|---|---:|---:|
| `libxul.so` headless browser | 6,328 | 2,862 |
| `crashhelper`, `crashreporter`, `updater` restricted diagnostics | 797 | 760 |
| `libmozinference.so` C API | 184 | 182 |
| `libclearkey.so` invalid CDM version | 71 | 70 |
| `libonnxruntime.so` C API | 246 | 244 |
| `pingsender` synthetic localhost gzip POST | 170 | 170 |
| `gfxtest` private Weston EGL diagnostic | 64 | 59 |
| **Nine distinct original ELF requesters** | **7,860** | **4,347** |

Exactly **50 distinct provider basenames** were observed across the six separately authenticated native binding reports. `gfxtest` introduced no additional provider basename beyond the previous eight-requester union. Distinct symbol/provider combinations are qualified by original requester; event counts can contain repeats, and none is a denominator for full dependency coverage.

## What remains open

There are 28 original regular ELF package members; this explicitly bounded native binding observation now covers nine different original requester names on limited real invocations, not exhaustive bindings for all paths, all 28, all transitive/lazy providers, or the source/build feature graph. It also does not prove real software update application, crash report submission, encrypted playback, model execution, daily graphical stability, or target Arch/Hyprland compatibility. No source removal, package byte saving, installed profile modification or production browser change was made.

**M3 remains 5/6 acceptance gates (83%), overall Vulpra 61%, Δ0 percentage points.**
