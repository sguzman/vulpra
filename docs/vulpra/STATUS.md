# Vulpra — current project snapshot

**As of:** 2026-11-17 (America/Mexico_City)  
**Source:** `main` on Firefox **159.0b5**; original comparison branch `upstream-base` is frozen.  
**Release status:** **Experimental. Do not treat as security-current or use for routine/sensitive browsing.**

This is a short navigation page, not a replacement for [the machine-readable ledger](PROGRESS.json), [roadmap](ROADMAP.md), [debloat evidence](DEBLOAT.md), or GitHub issue records. The percentage is the existing ledger figure; post-ledger QA checks are described separately without inventing milestone credit.

## Roadmap

| Milestone | Accepted status | Actual meaning |
| --- | --- | --- |
| **M1 · Reproducible source** | **100% · 5/5 gates** | Exact original upstream source and licensing/provenance foundations verified |
| **M2 · Working Linux browser** | **100% · 5/5 gates** | Real x86-64 Linux browser built, checksum-packaged, launched under isolated profiles, rendered Wayland buffers, ran localhost JS/navigation and WebExtension tests |
| **M3 · User-specific debloating** | **83% · 5/6 gates** | Some genuine source removal and guarded opt-in omissions; protected Linux browser builds and smoke tests passed, **complete build/link/runtime/feature dependency closure not accepted** |
| **M4 · Defect fixes / Rust trajectory** | **0% formally credited** | Feature work and long-term Rust ownership have not entered the accepted milestone; ongoing QA work does not automatically count as M4 completion |

**Overall product roadmap: 61%**, per `PROGRESS.json` (`floor((M2 + M3 + M4) / 3)`; M1 source scaffolding excluded). This is **not** a code-removal percentage, reliability score, or release-readiness estimate.

## What pruning is permanently done?

Three separately tested source-only removal passes are committed to `main`:

| Permanently deleted source scope | Tracked files | Original Git blob bytes |
| --- | ---: | ---: |
| Selected Windows/Cocoa widget and Windows installer implementations | 453 | 6,266,676 |
| Android application roots `fenix`, `focus-android`, `android-components` | 14,134 | 115,996,869 |
| Eight additional mobile/iOS/UIKit-only leaf roots | 280 | 7,704,040 |
| **Total** | **14,867** | **129,967,585** |

This removes source files from the active `main` tree, **not** original Git history. Those roots were excluded from Linux desktop compilation, so **no Linux runtime-binary savings can be inferred** from this source-only reduction. Mobile application builds are intentionally no longer supported.

Separate scoped native experiments omitted Normandy's recipe runner, two ASRouter promotional modules, New Tab AdsFeed, and a narrow PromoCard UI module under guarded configurations. Several native package/browser A/B checks passed, but **not all these removals are enabled in the default build**, and their archive-byte deltas are neither repeatable nor additive proof of a general package shrink. Pocket, Firefox Sync/FxAccounts, WebExtensions, sandbox, certificate validation, reporting/deletion semantics, localizations, GTK/Wayland, and necessary shared mobile/build inputs remain protected or retained.

Evidence: [DEBLOAT.md](DEBLOAT.md), [M3 verified-removal records](PROGRESS.json), and [dependency closure blocker register](M3-NATIVE-DEPENDENCY-CLOSURE-BLOCKERS-20261104.md).

## What is not done?

1. **M3 sixth and final gate remains open:** Complete an evidence-bounded feature-to-build, linked-ELF, Rust/C++ FFI, dynamic-loader and conditional fallback ownership map. Existing 28-ELF, loader, runtime and selected FFI audits are extensive but cannot justify arbitrary further deletion. Do not conflate a successful normal build with a complete feature dependency proof.
2. **Security currency remains blocked:** `main` is still based on Firefox **159.0b5**. Verified post-beta security patches are missing from that frozen-generation branch; work exists on separate security/candidate branches. [Security issue #3](https://github.com/sguzman/vulpra/issues/3). The Firefox **160** candidate is an **unmerged draft PR #6**; its Safe Browsing provider credential/terms [#8](https://github.com/sguzman/vulpra/issues/8) and full sandbox/platform [#9](https://github.com/sguzman/vulpra/issues/9) acceptance are open. Nothing here authorizes a public or sensitive-use release.
3. **Mixed-GPU lag remains unresolved:** [Issue #7](https://github.com/sguzman/vulpra/issues/7) records the actual EndeavourOS/Hyprland GPU mapping and bounded synthetic input measurements. The active AMD HDMI output is 1920×1080 at 60 Hz, while the connected NVIDIA HDMI output was disabled in the measured session. Native-Wayland synthetic input-to-next-rAF p50 **2 ms**, p95 **15 ms**, and rAF interval p95 **17 ms** for 48 events; headless p50 **1 ms**, p95 **14 ms**, rAF interval p95 **17.08 ms**. These are **not physical key-to-visible-pixel latency**, real presentation timing, typical heavy-page performance, or the two-active-monitor reproduction.
4. **Release distribution, final branding/icon review, update maintenance and long-term Rust replacement** are not finished. The current browser is a verified development/test baseline, not a release.

## Most useful next work

- **For M3 completion:** consolidate the *finite protected feature matrix* with evaluated build ownership, actual linked native objects/Rust archive members and observed conditional dependencies; identify exact still-unverified feature paths and require targeted safety tests before each new omission. Avoid repeated full Gecko builds when existing authenticated native artifacts suffice.
- **For browser performance:** compare equal workloads in packaged Vulpra versus Firefox Developer Edition using isolated profiles, then measure real Wayland frame presentation and the separately reported intermittent typing lag. Any second-monitor enabling, compositor config or driver change requires explicit owner approval.
- **For release viability:** prioritize an authorized Safe Browsing provider strategy and actual security patch/current-version migration, without weakening sandbox, account or download protections.

**Status discipline:** Do not award additional M3 or overall progress for source audits, CI mocks, a passing headless benchmark, or documentation alone. Update [PROGRESS.json](PROGRESS.json) only when a defined acceptance gate has passed. The most recent recorded milestone ledger is dated November 9; this snapshot incorporates separately verified November 17 workstation and CI outcomes.
