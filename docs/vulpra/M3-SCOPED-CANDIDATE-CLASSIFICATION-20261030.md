# M3 — Scoped candidate decision classification gate accepted

**October 30, 2026:** The roadmap's scoped **candidate safety-classification gate is accepted**, after [independent readiness CI 41110041517](https://github.com/sguzman/vulpra/actions/runs/41110041517) **PASSED** (evidence artifact **13001819129**) and [workflow lint 41110041605](https://github.com/sguzman/vulpra/actions/runs/41110041605) **PASSED**. This is a *classification milestone*, **not** a new compiled omission, complete browser dependency map, all-clear to delete tests, or a combined binary saving.

## Twenty decisions, with fallback and safety impact

| Decision | Count | Scope and actual acceptance |
| --- | ---: | --- |
| **KEEP** | **13** | Preserve shared GTK/Wayland/WebExtensions/security, Sync/FxAccounts, telemetry/deletion, DevTools, Pocket, GenAI, New Tab/ASRouter, original testing/QA, default localization and protected language/AI assets. Normal behavior and resources remain present. |
| **REMOVE_SOURCE** | **4** | Already accepted bounded non-Linux Windows/Cocoa/Android/iOS source cohorts; four candidate labels group into **three distinct deletion cohorts** (not four additive independent deletions). Their original Linux native acceptance runs are [40519242468](https://github.com/sguzman/vulpra/actions/runs/40519242468), [40585240593](https://github.com/sguzman/vulpra/actions/runs/40585240593), [40600510147](https://github.com/sguzman/vulpra/actions/runs/40600510147). |
| **CONDITIONAL_COMPILE** | **3** | Existing isolated opt-in recipe runner/Normandy, New Tab AdsFeed and PromoCard; normal browser retains default implementations. The independently successful native acceptance runs [40968542013](https://github.com/sguzman/vulpra/actions/runs/40968542013), [40617558714](https://github.com/sguzman/vulpra/actions/runs/40617558714), [40787698972](https://github.com/sguzman/vulpra/actions/runs/40787698972) are each scoped to their own source/configuration. |
| **REVIEW** | **0** | No additional broad category remains undecided **within the defined twenty-candidate inventory**. Optional subcomponents and as-yet-unmapped dependencies are not declared safe to remove. |

The 20 candidates are described in [the decision ledger](DEBLOAT-CANDIDATES.json); explicit nonblank scope, `safety_and_fallback`, source provenance and original evidence are required by [the fail-closed policy](../../ci/m3-candidate-decision-contract.jq).

## Why the final testing/ root is KEEP

The source-proven default development graph still traverses `testing/`, manifests, mozbase, mozharness, code generation and Python build tooling. The remote/Marionette/GeckoDriver gates operate independently of `--disable-tests`. Blanket deletion breaks the ability to build or regression-test the browser and future Rust migration.

[Source-pinned QA guard 41107821628](https://github.com/sguzman/vulpra/actions/runs/41107821628) **PASSED** **25/25** core source/build/WebDriver relationships and rejected **25** missing-anchor negative fixtures. Earlier [localization and test manifest audit 40922064826](https://github.com/sguzman/vulpra/actions/runs/40922064826) **PASSED** **14** conditional relationships and **17** negative mutations.

[Testing source/native evidence crosswalk 41109168322](https://github.com/sguzman/vulpra/actions/runs/41109168322) **PASSED** (artifact **13002321956**) after authenticating original, exact-source build/QA checks and the independent full-normal native browser. [Packaged native New Tab/ASRouter WebDriver 41106584931](https://github.com/sguzman/vulpra/actions/runs/41106584931) **PASSED** **10** real privileged module imports, **5** inert message/ASRouter assertions and `about:newtab` navigation in an isolated profile, without credentials or nonlocal messaging.

**All unmeasured or optional testing fixtures remain present**. We deliberately prefer retaining unused-looking test resources over sacrificing conformance/performance/QA. This is a *Keep* choice at the parent scope, not a complete evaluated generated build graph. Any smaller optional fixture would need a new scoped audit, native acceptance, a meaningful developer QA fallback and a source-matched size comparison.

## What the new accepted gate does *not* prove

The original three source-deletion cohorts account for **14,867 distinct tracked Git paths** and **129,967,585 original Git blob bytes**. These are not runtime, native binary or compressed installer savings. The original guarded opt-in native variants have independent archive differences; **none may be added as intrinsic, causal, repeatable or combined savings**.

The **feature/build/binary/platform dependency mapping**, **Pocket/promotional/Sync/telemetry safety audit**, and **platform/testing/localization asset audit** remain separate roadmap gates. Full dynamic JS imports, host ABI/runtime linker resolution, real remote messaging, real remote account Sync, untested language-pack fallbacks and future optional fixture deletions are *not* accepted by this gate.

**New M3 roadmap state: 3 of 6 gates (50%), a +17 percentage-point M3 delta. Overall Vulpra: 50%, a +6 percentage-point delta.** No default browser feature, user workstation profile, source deletion or compiled package was altered during this acceptance round.
