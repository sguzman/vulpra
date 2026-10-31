# M3 — Seven original native feature workloads: bounded GNU ELF coverage (2026-10-31 UTC)

## Reproducible evidence and exact binary provenance

The unchanged original compiled Vulpra/Firefox 159 beta Linux x86-64 full-normal binary archive comes from source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. Its pinned independent census covers 28 packaged ELF files and 519 distinct original `(requester basename, provider basename, version name)` GNU VERNEED requirements. No new browser build or package removal is part of these helper tests.

New activation tests:
- [Original packaged mozinference native C API 41160836283 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41160836283), under no-egress network namespace: original `libmozinference.so` loaded, source-proven production `LlamaRuntimeLinker` exports located, log callback installed, **24/24** declared version checks observed. No model loaded, tokenization, inference, browser integrated ML, or user profile.
- [Original packaged ClearKey CDM negative C API 41161025114 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41161025114), under no-egress network namespace: original `libclearkey.so` loaded, invalid CDM interface version rejected by actual `CreateCdmInstance`, **14/14** declared version checks observed. No valid CDM session, keys, decrypted media or browser EME integration.
- [Authenticated six-workload tuple reconciliation 41160946141 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41160946141) and [independent seven-workload reconciliation 41161137900 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41161137900). Both verify original archive, strict run ID/source head SHA, exact original declared tuple membership, non-overlap and fail-closed feature-specific claims. Existing five-workload evidence [41160181649 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41160181649) is preserved.

## Audited original native GNU version-check coverage

| Independent native workload | Source-pinned original ELF version triples observed |
| --- | ---: |
| Browser, private Weston 10-second graphical startup | 336 |
| `gfxtest` real Wayland compositor roundtrip | 8 |
| `pingsender` synthetic gzip localhost HTTP, no egress | 22 |
| `libonnxruntime.so` standalone Rust C API entrypoint | 20 |
| Alternate `vulpra-bin` private Weston 10-second graphical startup | 21 |
| **New:** `libmozinference.so` production-linked C API activation | **24** |
| **New:** `libclearkey.so` rejected invalid CDM interface | **14** |
| **Total observed original compiled version triples** | **445 / 519 (85.7%)** |
| **Remaining not executed in these paths** | **74** |

Only **three** original protected auxiliary executables are not exercised by these seven chosen routes: `crashhelper` (**27**), `updater` (**27**), and `crashreporter` (**20**) unique original ELF version triples. These must remain available; a missing version check in a finite set of workloads is not evidence of nonuse. The updater requires isolated staged update input/environment; crash-helper and reporter require purpose-built disposable crash/minidump fixtures, no user data and no external reports.

## Explicit limits and progress

A glibc `LD_DEBUG=versions` check witnesses a requested version *identity*, not every individual symbol binding, weak/unversioned import, future `dlopen`, effective media/ML feature usability, runtime-only dependencies, completed source/build graph, or workstation Arch/Hyprland compatibility. Separate invocations use different secure isolation contexts and are not one browser process. The ClearKey negative-path result is **not proof decryption works**. The inference probe is **not proof model inference works**.

No production source, default browser features, installed user profile, package contents, or launcher were changed by these tests. No new binary-size saving is claimed and the remaining protected modules are **not** deletion candidates.

**M3 stays 5/6 (83%); overall Vulpra 61%; session progress +0 percentage points.** The broad M3 source/build/feature/dynamic ABI dependency acceptance gate remains open, notwithstanding **+38** exact version-check tuples newly exercised compared with the earlier five-workload checkpoint (407 → 445).
