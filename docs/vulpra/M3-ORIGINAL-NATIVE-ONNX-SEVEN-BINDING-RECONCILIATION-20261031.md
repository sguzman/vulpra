# M3 — Original ONNX Runtime actual native symbol bindings and seven-requester reconciliation

## Authenticated original runtime evidence (2026-10-31 UTC)

The [original full-normal compiled ONNX/llama/ClearKey binding workflow 41165330510 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41165330510) authenticated the original source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and original compiled archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. Its original `libonnxruntime.so` C API diagnostic, in a private no-egress namespace with a disposable HOME, successfully exercised the original published API-base and nonempty version-string path. **No model was loaded, inference performed or user profile accessed.**

The existing std-only Rust bounded glibc observer `ci/m3-native-original-feature-module-bindings.rs` was extended with the explicit ONNX requester allowlist entry. Opt-in `LD_DEBUG=versions,bindings` observation recorded **246 original `libonnxruntime.so` normal-symbol binding events**, **244 distinct symbol/provider pairs** and **5 provider basenames** from one native requester trace. Original mozinference and ClearKey diagnostic paths passed unchanged in the same workflow; the standalone [original ONNX ABI regression 41165312238 PASS](https://github.com/sguzman/vulpra/actions/runs/41165312238) and [workflow lint 41165330480 PASS](https://github.com/sguzman/vulpra/actions/runs/41165330480) confirm the guarded baseline remains intact.

## Independent seven-requester verification

[**Seven-requester source-run-pinned binding reconciliation 41165414409 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41165414409), [global workflow lint 41165414404 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41165414404).

The independent `ci/m3-original-real-binding-seven-requester-union.jq` checks three successful original binary run IDs and commit SHAs, verifies all sanitized provider names and schema/source/archive identities, and requires exact event count reconciliation. It extends the previous immutable six-requester observation without modifying it.

| Original requester group | Runtime normal-symbol events | Distinct requester/symbol/provider combinations |
|---|---:|---:|
| Headless original browser `libxul.so` | 6,328 | 2,862 |
| `crashhelper`, `crashreporter`, `updater` early/synthetic/read-only paths | 797 | 760 |
| `libmozinference.so` original C API | 184 | 182 |
| `libclearkey.so` invalid-version C API | 71 | 70 |
| `libonnxruntime.so` original C API | 246 | 244 |
| **Seven distinct original ELF requesters** | **7,626** | **4,118** |

Exactly **49 distinct provider basenames** were observed across the four sanitized workload reports. These are observed runtime bindings, not static imported-symbol coverage rates or all possible lazy bindings. Raw symbol names, PIDs, absolute loader paths, raw logs and user profiles were not exported.

**Limits:** Original Vulpra package still contains 28 native ELF files; 21 original requester modules have not been individually observed through this narrowly defined binding method. These tests do not close complete real-world update, crash, DRM, ML, lazy/transitive import, Arch/Hyprland or source/build ownership acceptance. No browser code or installed profiles changed; no source removal, product performance gain or package-size savings established.

**Progress stays M3 5/6 (83%), Vulpra overall 61%, session Δ0 percentage points.**
