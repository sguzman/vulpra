# M3 — Original compiled ELF direct DT_NEEDED edges crosswalked to sampled real binding providers (2026-10-31 UTC)

## Source/run identity and acceptance

[**Original compiled 28-ELF direct-needed vs native glibc normal-binding provider crosswalk 41206941249 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41206941249), [global actionlint 41206941247 — PASS](https://github.com/sguzman/vulpra/actions/runs/41206941247). The workflow authenticated the immutable original compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, original full-normal archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, and the independently successful actual original compiled package-binding run [41206627659](https://github.com/sguzman/vulpra/actions/runs/41206627659), head `62fc0e4a`.

Without invoking a new browser or importing user profiles, it safely re-extracted the **same** original compiled regular ELF files, parsed all exact `DT_NEEDED` declarations with `readelf -Wd`, and reconciled their requested provider basenames against the observed normal-binding **provider basename sets per original ELF requester** in the pre-sanitized Rust-produced runtime report. The original runtime run passed again after adding these per-requester provider lists; it recorded 21/28 observed requesters. Its event totals differ from the earlier run because native process/runtime samples can vary. The crosswalk is grounded in source identity and provider-name matching, not an assumption that event counts are invariant.

| Source-pinned original ELF comparison | Verified |
|---|---:|
| Regular packaged original ELF requesters in source archive | **28** |
| Declared direct `DT_NEEDED` edges across original 28 | **268** |
| Declared edges belonging to one of 21 requesters observed during the headless workload | **192** |
| Declared edges whose requester had a sampled normal-symbol binding to the same provider basename | **107** |
| Declared edges whose requester had *no* sampled normal-symbol binding in this startup | **76** |
| Declared edges whose requester was observed, but with no same-provider normal-binding witness | **85** |

The report retains safe basename-only per-edge categories, not raw symbols, absolute paths, PIDs or browser profiles. The independent historical 268-edge package-graph result is now corroborated by a freshly authenticated extraction of the *same* later compiled baseline used by the live-binding tests.

## What these edge counts mean

A matching provider-name normal-symbol binding is an observed glibc symbol-resolution event in this workload. It does **not** establish that the loader resolved that exact `DT_NEEDED` edge in the direct linkage mechanism; the provider may also be reachable transitively. Conversely, no normal-binding event is **not** proof a declared library failed to load or is unnecessary: it could be linked for constructors, a feature not triggered, glibc compatibility groups, or lazy/dynamic work outside this workload. The 76 edges are not proven failing, and 85 is **not** a candidate-removal list.

The companion [all-28 requester witness reconciliation 41206458805](https://github.com/sguzman/vulpra/actions/runs/41206458805) proves a narrower orthogonal statement: all 28 original ELF names had at least one actual normal-symbol binding witness across **different** guarded feature workloads. It does not fill every direct-needed edge here; the two reports must not be conflated.

No source was deleted or rebuilt, no installed launcher/profile altered, and no package-size reduction or safe-pruning authorization is claimed. Complete direct/transitive runtime loader closure, lazy/dlopen paths, current source/build-feature ownership and target Arch/Hyprland compatibility are still open.

**Progress unchanged: M3 5/6 gates (83%), Vulpra overall 61%, session delta +0 percentage points.**
