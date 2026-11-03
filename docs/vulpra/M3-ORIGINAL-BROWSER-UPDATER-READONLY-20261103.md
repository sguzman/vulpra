# M3 — Original compiled browser's updater service: read-only disabled/idle native observation (2026-11-03)

## Accepted original native result

[**Original browser updater-disabled read-only CI 41727954123 PASS**](https://github.com/sguzman/vulpra/actions/runs/41727954123), job `126237560943`, sanitized artifact **13274367840** (`m3-original-browser-updater-readonly`). Artifacts were downloaded and the exact JSON inspected. The verified immutable full-normal original source was `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, and the unchanged full package archive SHA-256 was `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The actual executable `/original/vulpra` and actual packaged native ELF `/original/updater` were present; no original source or binary was rebuilt, replaced, or deleted.

The actual original browser was started **directly** with a temporary isolated profile, then controlled via `geckodriver --connect-existing` in a private Arch Linux/Weston container. This is the same genuine-original-browser attachment method accepted in the crash-reporter native tests and does not invoke an updater CLI or synthetic service implementation.

The container had **`--network none`**, mounted the entire original browser package read-only, used only temporary HOME/profile storage, dropped all process capabilities after enabling private loopback, and neither mounted the user's browser profiles nor accessed a physical desktop. In that disposable profile only, the test applied `app.update.disabledForTesting=true`, `app.update.auto=false`, `app.update.background.enabled=false`, and `app.update.staging.enabled=false` before startup. These values are explicitly **test-controlled safeguards** rather than production defaults; the test does not claim that updates are disabled in a normal Vulpra installation.

The original browser's *actual chrome-context XPCOM service* returned this same read-only snapshot **twice**, separated by 2 seconds:

| Source-authenticated original getter | Actual browser result |
|---|---|
| `nsIApplicationUpdateServiceStub.updateDisabledForTesting` | `true` |
| `nsIApplicationUpdateServiceStub.updateDisabled` | `true` |
| `nsIApplicationUpdateService.disabled` | `true` |
| `nsIApplicationUpdateService.canUsuallyCheckForUpdates` | `false` |
| `nsIApplicationUpdateService.currentState` against `STATE_IDLE` | `true` |
| `nsIApplicationUpdateService.getStateName(currentState)` | `STATE_IDLE` |
| Temporary original profile's four explicit update prefs | `true, false, false, false` as configured |

Both original update service XPCOM singleton contracts were authenticated against the immutable `toolkit/mozapps/update/components.conf`, while their getter declarations were checked in `nsIUpdateService.idl`. The corresponding actual original implementation in `UpdateServiceStub.sys.mjs` establishes that `updateDisabledForTesting` requires automation and the explicit testing pref; `UpdateService.sys.mjs` establishes that `canUsuallyCheckForUpdates` rejects disabled service, and `currentState` reads its current state.

An independent std-only Rust `/proc` observer, `ci/m3-original-browser-updater-readonly-observer.rs`, sampled the live original process namespace **45 times**, seeing original packaged browser executable processes in **all 45 samples** (up to 11 concurrent browser-process executable mappings) and **zero** instances of the original packaged `/original/updater` executable during those finite observations. This negative observation does **not** prove the updater is never launched by other workloads. The probe completed the original read-only XPCOM queries and emitted only bounded sanitized counters and flags; no PIDs, profile paths, browser logs, process command lines or private data were exported.

The CI passed **2/2 Rust unit tests** and rejected **8/8 deliberately forged evidence summaries**: incorrect update stub disabled flag, incorrect update service disabled flag, non-idle service state, spoofed updater process appearance, use of write-testing getters, forged updater process-launch proof, incorrect original archive SHA, and false source pruning authorization. No update check, download, staging, update processor, install, or updater executable launch method was called; no network route existed for update fetching.

### Crucial source-level side-effect finding

**Not every getter named `can*Updates` is read-only.** In the accepted original source, `UpdateService.sys.mjs::get canUsuallyApplyUpdates()` calls `getCanApplyUpdates()`, which runs `testWriteAccess(updateTestFile, false)`. This **creates/removes a temporary file** (and may check install-directory writability). `canApplyUpdates` in turn calls `canUsuallyApplyUpdates`. They were **intentionally not queried**. Similarly, `nsIUpdateManager.getReadyUpdate`, `getDownloadingUpdate`, `nsIApplicationUpdateService.init`, update checks, downloads, update processors, cleanup and install methods were not called because they may initialize/resume state, write files, request network, or trigger update processing.

A first native run [41727124977](https://github.com/sguzman/vulpra/actions/runs/41727124977) failed from an HTTP 500 in the first browser-side XPCOM query. Metadata-only stage diagnostics in [41727361137](https://github.com/sguzman/vulpra/actions/runs/41727361137) confirmed browser attachment and chrome context had succeeded. A per-field, exception-type-only probe [41727687045](https://github.com/sguzman/vulpra/actions/runs/41727687045) showed **all original updater XPCOM getters already succeeded** (disabled/idle), while our initial `ChromeUtils.importESModule("...Services.sys.mjs").Services.prefs` preference lookup was unavailable in this Marionette execution context. The accepted run switched only the **read-only preference accessor** to `@mozilla.org/preferences-service;1` via `nsIPrefBranch.getBoolPref`. It did not change the original binaries or weaken updater-service/idle assertions. Failed diagnostics were not used as acceptance evidence.

## Interpretation and milestone accounting

**Established:** source-pinned, real compiled Vulpra browser exposes its actual update service and startup stub in a disposable automated session; with explicit temporary disabled prefs, both report disabled and the real service remains `STATE_IDLE` across two separate checks; no packaged `updater` executable was observed in 45 bounded live browser samples. This is **real browser-controlled update-service gating**, beyond previous isolated updater CLI/native binding diagnostics.

**Not established:** normal update availability when updates are enabled; background update scheduling or checks; parsing or fetching a MAR update; stage/install correctness; the real updater's normal browser-initiated launch; full binary/FFI/lazy/conditional dependency closure; production EndeavourOS/Hyprland behavior; source pruning eligibility. The observed absence of updater processes is a bounded property of this **explicitly disabled** test, not a reason to remove the binary. No native bytes saved. No original browser or user profile modified.

The expensive workflow `.github/workflows/m3-original-browser-updater-readonly.yml` returned to **manual-only `workflow_dispatch`** after acceptance, and the standard workflow lint checked that restored trigger. Completion accounting remains **M3 5/6 = 83%; overall 61%; delta +0 percentage points**. A future higher-value updater test would need to exercise browser-driven installation intent with a strictly authenticated, non-applicable fixture and a provable no-install safeguard, not invoke update processing on real profiles.
