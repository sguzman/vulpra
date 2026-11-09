# GBM modifiers2 optional ABI fallback — original source inline wrapper runtime proof

**Accepted 2026-11-09 UTC:** [M3 Real CXX Source Loader Missing-Provider Fixtures #42549654470 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42549654470), [source and inline mock-runtime evidence artifact #13644688014](https://github.com/sguzman/vulpra/actions/runs/42549654470/artifacts/13644688014), [workflow lint #42549654437 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42549654437).

This acceptance is based on **both JSON files downloaded and independently parsed** from the successful current fixture artifact, not on workflow status alone:

- `m3-real-cpp-missing-provider-fixtures.json` still reports **28/28 source-owned loader tests**, 25 guarded failure/absence cases, 3 successful/accepted cases, all 18 required GBM/DRM dynamic symbols denied one at a time, and the one optional modifiers2 missing-symbol case accepted for initial `GbmLib::Load()` readiness.
- `m3-gbm-inline-modifier-fallback.json` independently reports **5/5 additional real-source inline wrapper calls** with expected old/new API invocation counts, untouched forwarded arguments, and correctly returned success/failure pointers. Both artifacts retain `false` for live GBM/device integration, actual DMABuf creation, packaged-browser graphics fallback, source pruning, M3 gate six, and release approval.

## Exact source and test provenance

The extracted function is the **actual source-body implementation** of `GbmLib::CreateWithModifiers2` in [`widget/gtk/DMABufDevice.h`](../../widget/gtk/DMABufDevice.h) at immutable Git blob `6ec965c96846bc09050b1567ef042228d59cdd1c`. The source-matched [Rust extractor](../../ci/m3-extract-current-provider-functions.rs) requires the original full native browser source revision `bd2499aeadce0368faa8b717b0e8a17e9c9dc317`, validates the header Git-blob identity, extracts the complete bounded method verbatim, rejects source tampering/duplicate bodies/overwriting, and emits the original inline body in a separate include.

[The isolated C++ runtime fixture](../../ci/tests/m3-gbm-inline-modifiers2-fallback-fixture.cpp) includes this original method directly in a minimal C++ `GbmLib` class using ABI-shaped mocked function pointers. It does **not** copy or reimplement the fallback branch. The [CI workflow](../../.github/workflows/m3-real-cpp-provider-failure-fixtures.yml) also independently authenticates the same `DMABufDevice.h` blob via GitHub's exact-source file API and reruns the original 28 source-function provider tests.

## Five distinct original C++ inline wrapper observations

| Input and simulated provider | Original wrapper return | Observed old API calls | Observed new API calls |
| --- | --- | ---: | ---: |
| Null GBM device | null | 0 | 0 |
| Valid device, `sCreateWithModifiers2` absent; older required `sCreateWithModifiers` succeeds | old API `gbm_bo*` | **1** | **0** |
| Valid device, both APIs present | newer API `gbm_bo*` | **0** | **1** |
| Valid device, `sCreateWithModifiers2` absent; old API fails | null propagated | **1** | **0** |
| Valid device, new API present but itself fails | null propagated, **no automatic retry on the old API** | **0** | **1** |

The fixture explicitly checks that the forwarded `gbm_device*`, width, height, pixel format, modifier array/count and, on the new-API route, flags are preserved. It rejects unsupported scenario names. Both routes are tested in separate processes, independent of the existing `GbmLib::Load()` one-shot initialization tests.

The important compatibility distinction is **absence versus failure**: this source wrapper intentionally falls back to the old API when the *new function pointer is absent*, but does **not** retry the old API when the *new function exists and returns null*. The latter is an observed source-function behavior, not proof of a defect; calling surfaces may have their own later recovery paths.

## Known gaps and next work

The check **actually executes the source wrapper**, advancing beyond the earlier 28-mode `Load()/IsLoaded()` readiness test and the source-text observation. However, the callbacks return synthetic `gbm_bo*` objects; there is no real GBM driver, DMA-BUF allocation, device or compositor, no functional graphics fallback, no target EndeavourOS/Hyprland QA and no complete indirect dependency graph.

A real source-pinned full browser run [#42546880350](https://github.com/sguzman/vulpra/actions/runs/42546880350) was **still compiling at the latest audit check**. Its optional-provider headless browser probe must complete before any claim about packaged-browser missing-provider behavior; the prepared Weston graphical denial wrapper is not part of that running source revision. Further realistic workload coverage would need actual GBM/DRM library ABI and Wayland/DMABuf buffer creation checks.

This test is a **bounded compatibility branch closed, not milestone gate six closed**.

**M3 5/6 gates (83%). Overall 61% (Δ +0 pp). No source pruning, security merge, release or workstation changes.**
