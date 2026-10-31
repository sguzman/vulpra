# M3 — Original native libxul.so actual symbol bindings (2026-10-31 UTC)

## Verified result

[Original compiled libxul runtime binding test 41162866013 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41162866013). This new, separately scoped native workload authenticates the original full-normal Vulpra source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and existing compiled archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` before running the original packaged browser with private-profile headless New Tab / ASRouter smoke.

A std-only Rust parser (`ci/m3-native-libxul-bindings.rs`) inspected bounded glibc `LD_DEBUG=bindings` PID traces. Its initial negative fixture correctly failed the first attempt 41162822101 because it caught a path-bearing symbol name; after making the parser reject slash/backslash names, the corrected test passed, and the new GitHub Actions workflow passed independent workflow lint 41162822039.

**Actual observed original `libxul.so` symbol bindings: 6,328 glibc normal-symbol binding events across two native PID traces, representing 2,862 distinct (symbol, provider basename) pairs in this single bounded workload.** These are real dynamic loader binding events, not a static `DT_NEEDED` provider-name guess or merely the 519 GNU version label checks. Counts are observations, not an exhaustive count of all symbol relocations. The sanitized artifact exports provider **basenames and counts only**; symbol names, absolute paths, process IDs, raw logs, profiles and environment are not exported. Raw logs are deleted by the CI step's cleanup trap and are not uploaded. The CI environment is Ubuntu 24.04 x86-64, not the user's Arch/Hyprland machine.

## Boundary of evidence

This observation includes a protected headless WebDriver New Tab workload. It **does not** prove all lazy bindings, all loaded features, all 28 original ELF modules, all transitive dependencies, source/build ownership, actual application update/crash recovery, DRM decryption or ML inference. The previous [2,153 unversioned undefined dynamic import census](M3-ORIGINAL-NATIVE-UNVERSIONED-DYNSYM-20261031.md) and [519/519 GNU ELF version identity result](M3-ORIGINAL-NATIVE-ALL-ELF-VERSION-CHECKS-20261031.md) remain separate, narrower measurements. Do not equate their counts or infer dependency closure from this run.

No source removal, Vulpra rebuild, installed Firefox profile modification, new package saving or pruning authorization occurred.

**M3 remains 5/6 gates (83%), Vulpra overall 61%, accepted milestone delta +0 percentage points.**
