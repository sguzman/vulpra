# M3 — Original protected native auxiliary symbol-binding observation (2026-10-31 UTC)

## Authenticated runtime result

[**Original compiled protected auxiliary glibc binding workflow 41164023607 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41164023607). The same-source original full-normal compiled archive from `b1482404dfb8b01342990ee99ea3df0f9756b5f7` was reauthenticated against SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` before executing the original protected ELF files. Its independent workflow lint [41164023612 succeeded](https://github.com/sguzman/vulpra/actions/runs/41164023612).

The original guarded no-egress network-namespace runner was reused with a narrow opt-in `LD_DEBUG=versions,bindings` mode. It executed **only** crashhelper's missing-arguments early exit, crashreporter's 1 MiB synthetic Rust `--memtest`, and updater's read-only `--channels-allowed` query. It used disposable HOME/config/cache paths and excluded network egress. `ci/m3-native-original-auxiliary-bindings.rs` (std-only Rust) parsed numeric-PID glibc files under bounded sizes, required real normal-symbol bindings for all three original ELF requesters, and emitted sanitized provider basenames and counts only.

The [successful sanitized CI artifact](https://github.com/sguzman/vulpra/actions/runs/41164023607) contains:

| Original requester | PID traces with normal bindings | Actual normal-binding events | Distinct (symbol, provider) pairs | Provider basename count |
|---|---:|---:|---:|---:|
| `crashhelper` | 1 | 246 | 220 | 5 |
| `crashreporter` | 1 | 227 | 221 | 9 |
| `updater` | 1 | 324 | 319 | 10 |
| **Sum (per member)** | **3** | **797** | **760** | — |

13 unique provider basenames were observed across the three diagnostic invocations. These are actual loader normal-symbol binding observations, **not** static candidate-provider matches, not 797 different imported-symbol obligations and not comprehensive native ABI coverage. Counts reflect *these particular invocations* on Ubuntu 24.04 x86-64, not Arch/Hyprland.

The first workflow attempt [41163951171 failed](https://github.com/sguzman/vulpra/actions/runs/41163951171) before executing the native binaries because GitHub artifact blob storage returned **HTTP 503: egress over account limit** when fetching a redundant pre-existing ABI inventory artifact. That extra download was removed only from this new binding-specific workflow. The original GNU version-contract audit continues to run separately, and its unchanged no-egress helper path [41163882417 PASS](https://github.com/sguzman/vulpra/actions/runs/41163882417) verified the normal (non-opt-in) behavior.

## Explicit exclusions

Only 3 original auxiliary ELF requesters were checked with actual symbol-binding traces. The preceding [libxul real-binding workload 41162866013](M3-ORIGINAL-NATIVE-LIBXUL-RUNTIME-BINDINGS-20261031.md) is separate and should not be numerically combined without a correctly defined unique-key reconciliation. This result does not establish lazy and transitive feature closure, runtime binding for all 28 original packaged ELF modules, end-to-end crash or software-update operation, media/DRM, ML inference, complete source/build ownership, or debloating safety.

No raw logs, symbol names, PIDs, filesystem paths or profile contents were uploaded. Source browser files, production binaries, installed profiles and package byte sizes remained unchanged. **Overall 61%, M3 5/6 gates (83%), Δ0 percentage points.**
