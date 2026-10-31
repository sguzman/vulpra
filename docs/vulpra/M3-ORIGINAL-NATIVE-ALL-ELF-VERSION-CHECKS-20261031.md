# M3 — All original GNU ELF version-check identities observed (2026-10-31 UTC)

## Verification

The complete immutable original Vulpra Linux native package, source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, declares **519 distinct GNU ELF version-requirement tuples across 28 original native ELF files**.

- [Seven authenticated native feature-oriented invocations 41161137900 — PASS](https://github.com/sguzman/vulpra/actions/runs/41161137900): 445/519 original triples. These include graphical browser startup, Wayland gfxtest, synthetic loopback telemetry sender, standalone ONNX and llama library entrypoints, alternate browser executable, and ClearKey negative CDM entrypoint; see [seven-workload provenance report](M3-ORIGINAL-NATIVE-SEVEN-WORKLOAD-ABI-20261031.md).
- [Three protected auxiliary executable diagnostic paths 41161508642 — PASS](https://github.com/sguzman/vulpra/actions/runs/41161508642): 74/74 additional original triples. The **27 crashhelper** checks occurred on the missing-argument early exit, before PID/minidump handling; the **20 crashreporter** checks occurred during a synthetic 1 MiB standalone Rust memory test, not report submission; the **27 updater** checks occurred during its read-only `--channels-allowed` query, not an installed update. All ran in a no-egress network namespace with disposable HOME; the compiled package was SHA-authenticated first. Initial diagnostic harness run 41161461599 failed due to resolving a relative repository path after changing cwd; corrected without altering source or package.
- [Independent original declared-identity union 41161592443 — PASS](https://github.com/sguzman/vulpra/actions/runs/41161592443): authenticated successful CI run identities and commit SHAs, compared both sanitized loader observation sets to the immutable 519 original static contracts, rejected overlapping/foreign identities. **519/519 (100%) observed, zero missing**. [Workflow lint 41161592661 — PASS](https://github.com/sguzman/vulpra/actions/runs/41161592661).

This evidence witnesses each declared GNU ELF `(requester filename, provider filename, version label)` at least once **across ten separate bounded invocations**, not within one fully featured browser run. Compared with the prior five-workload baseline, this session newly exercised **112** version-check triples (407 → 519), of which 38 came from inference and ClearKey activation and 74 from the three protected auxiliary diagnostic routes.

## Critical limits — no M3 milestone closure

A GNU version label checked by the loader is **not** proof that every named symbol was relocated and correctly bound, that all unversioned/weak imports work, that plugins load in rare contexts, or that full build/source/feature dependencies are mapped. No real crash recovery, crash report submission, updater patch apply, encrypted media playback or ML model inference was verified. The original Arch/Hyprland workstation was not revalidated by these Ubuntu CI runs. In particular, a 100% ELF version-*identity* observation rate is **not** 100% binary/dynamic ABI, regression, source-dependency or feature coverage.

The **three protected auxiliary binaries remain retained**; no source code was removed, no default build or launcher modified, no browser profile changed, and no additional package-byte savings claimed.

The **sixth M3 acceptance gate remains open** until source-to-feature and binary/build/loader graphs, unversioned and lazy bindings, real end-to-end update/crash/ML/DRM safeguards, and bounded candidate impact are verified.

**Vulpra overall 61%; M3 5/6 = 83%; session milestone delta +0 percentage points.** This session completed a bounded version-identity coverage subtask, not the entire broad dependency map.
