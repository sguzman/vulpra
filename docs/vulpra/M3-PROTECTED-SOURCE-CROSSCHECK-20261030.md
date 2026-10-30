# M3: one-source Pocket, Sync, telemetry and deletion-request boundary crosscheck

**Date:** 2026-10-30 UTC (2026-10-29 America/Mexico_City)

[Source-pinned CI 40982290720](https://github.com/sguzman/vulpra/actions/runs/40982290720)
**PASSED** at commit `010d4b7e847f3a0cd0bb69d20b17db59108120ae`.
Artifact **12945352163** contains four original source-audit reports
and a joined, conservative `m3-protected-boundary-crosscheck.json`.

The job performs a sparse checkout of the already existing individual
source-audit implementations. They read the same exact Git source commit via
`git show HEAD:<path>` and separately run their own deliberately broken
source fixture tests. The new `ci/m3-protected-boundary-crosscheck.py`
refuses missing/mismatched commits, incomplete/duplicate boundary names,
unsafe dispositions, missing/invalid source line anchors and false removal
claims. Its regression includes **13 negative cases**. This does **not**
compile or run Vulpra, modify browser source, or observe network uploads.

| Independent source audit | Protected boundaries | Decision |
| --- | ---: | --- |
| Pocket/Discovery Stream | 5 | Keep modern/legacy feeds, optional sponsored and promo boundaries guarded |
| Sync and Firefox Accounts | 7 | Keep Sync and separately packaged FxAccounts, extension and UI consumers |
| Telemetry sender, native/Glean and crash | 6 | Keep policy/setup/shutdown, separate local native and crash functions |
| Upload opt-out and deletion request | 6 | Keep deletion queue cleanup, identifiers and sender exception handling |
| **Total** | **24** | **No source deletion authorized** |

## Five high-impact joint findings

1. **Pocket's modern and legacy recommendation feeds are separate.** Both
   are still registered, and sponsored content shares a modern AdsClient path.
   A preference or isolated PromoCard bundle omission does not authorize
   removing the recommendation feed or all branded New Tab resources.
2. **FxAccounts is built independently of Sync's conditional directory.**
   Account startup, synced tabs, WebExtension `storage.sync` and AI-window
   account authentication have distinct consumers. Opting out of one source
   area without checking the others would be unsound.
3. **Two telemetry upload preferences have different responsibilities.**
   User opt-out can involve queued-ping clearing, identifier replacement and
   a deletion-request exception; do not simply remove the send/storage path.
4. **Local Glean/native telemetry and crash handling are not identical to
   legacy remote ping transport.** The source build registers separate
   native dependencies. No telemetry transport change was made here.
5. **Telemetry startup/shutdown, upload policy, privacy UI and deletion
   behavior must be checked together** with a guarded real native/runtime
   test before any submission-related opt-in experiment.

## Limits and next evidence

This joins **24 specifically named source-level contracts**. It is not
the *complete* source/build/runtime dependency graph: literal source
anchors are not dynamic imports or loaded modules; individual audits do
not enumerate every caller; the crosscheck did not observe actual telemetry
traffic or protected fallback behavior on Arch, and it did not measure
compiled, linked, or compressed feature savings.

Before any protected candidate is accepted for disable/compile/remove:
prove the per-feature packaged artifact boundary, native private Wayland
runtime, protected fallback, relevant account/storage/API behavior,
and, for reporting, the opt-out/deletion sender lifecycle and
observable network behavior. Retain existing Sync/FxA, local Glean,
crashreporter, Pocket stories and New Tab UI for now.

**Progress accounting:** M3 remains **2/6 (33%)**, overall **44%**.
The source dependency mapping is stronger but the broad gate remains open.
