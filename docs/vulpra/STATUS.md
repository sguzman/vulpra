# Vulpra — current project snapshot

**As of:** 2026-11-18 (America/Mexico_City)  
**Source:** `main` on Firefox **159.0b5**; original comparison branch `upstream-base` is frozen.  
**Release status:** **Experimental. Do not treat as security-current or use for routine/sensitive browsing.**

This is a short navigation page, not a replacement for [the machine-readable ledger](PROGRESS.json), [roadmap](ROADMAP.md), [debloat evidence](DEBLOAT.md), or GitHub issue records. The percentage is the existing ledger figure; post-ledger QA checks are described separately without inventing milestone credit.

## Roadmap

| Milestone | Accepted status | Actual meaning |
| --- | --- | --- |
| **M1 · Reproducible source** | **100% · 5/5 gates** | Exact original upstream source and licensing/provenance foundations verified |
| **M2 · Working Linux browser** | **100% · 5/5 gates** | Real x86-64 Linux browser built, checksum-packaged, launched under isolated profiles, rendered Wayland buffers, ran localhost JS/navigation and WebExtension tests |
| **M3 · User-specific debloating** | **83% · 5/6 gates · PAUSED** | Practical pruning campaign deferred by owner; no new omission/dependency closure work. Last gate remains genuinely unaccepted. |
| **M4 · Defect fixes / Rust trajectory** | **0% formally credited · may start** | M3-to-M4 sequencing restriction lifted by owner; security maintenance, real bugs and personalization may advance without more pruning. |

**Overall product roadmap: 61%**, per `PROGRESS.json` (`floor((M2 + M3 + M4) / 3)`; M1 source scaffolding excluded). This is **not** a code-removal percentage, reliability score, or release-readiness estimate.

## Active decision: pruning deferred (2026-11-18)

The owner considers the high-confidence pruning pass practically complete and does **not** want further general-purpose source removal, more M3 feature-dependency closure audits, or lean-by-default experimentation **for now**. The four recognized source-removal categories and three guarded compile omissions remain documented and untouched, with historical build evidence retained for future use. Do not spend more time pruning unless the owner explicitly reopens that work or an independently motivated security/upstream change requires narrowly scoped dependency review.

**Formal accounting is unchanged:** M3 **83% (5/6)**, overall **61% (Δ +0 pp)**. The final dynamic/build/native FFI/feature closure gate is **deferred, not passed**, and M4 is **unblocked in planning** despite its previous dependency on the M3 gate.

## Actual next work — ordered by release and user impact

1. **Firefox 160 modernization and security integration — main priority:** [draft PR #6](https://github.com/sguzman/vulpra/pull/6) already has exact-source browser/native tests, WebDriver, Wayland/media, extension, TLS and security-role evidence; **do not merge/release yet**. Port reviewed Vulpra branding/prefs and accept newer Mozilla fixes without overwriting upstream, then run target-source and security regression gates. Current `main` stays on the 159.0b5 source.
2. **Safe Browsing provider and release-key policy — hard blocker [#8](https://github.com/sguzman/vulpra/issues/8):** Firefox 160 isolated build's effective Google v5 provider check failed due to no usable credential. Authorized provider/usage policy, safe secret staging, actual list update and classification/download protection tests are not done. Never copy Mozilla proprietary credentials, expose keys, or disable protection to green CI.
3. **Host sandbox and security completeness — [#9](https://github.com/sguzman/vulpra/issues/9), [#3](https://github.com/sguzman/vulpra/issues/3):** real Gecko `tab` worker `prctl(PR_CAPBSET_READ)` denial and denied HOME file creation **passed** on Ubuntu CI and Arch container, plus supported role-specific namespace/seccomp observations. Still need end-to-end security acceptance on actual EndeavourOS/Hyprland, other relevant roles/policies, and comprehensive upstream-advisory patch coverage. Distinguish CI evidence from actual host guarantees.
4. **Real browser defects — [#7](https://github.com/sguzman/vulpra/issues/7), [#5](https://github.com/sguzman/vulpra/issues/5), [#11](https://github.com/sguzman/vulpra/issues/11):** investigate intermittent Firefox/Vulpra typing/display lag under actual two-active mixed-GPU monitor conditions and compare Firefox Developer Edition. The **Firefox 160 draft candidate** now passed actual isolated packaged-runtime `navigator.userAgent` checks for both `Firefox/160.0` and `Vulpra/160.0` with no override ([CI 44340267616](https://github.com/sguzman/vulpra/actions/runs/44340267616)); real Google UI/default-profile compatibility and the 159 `main` build remain separately unaccepted. Finish high-signal GCC warning triage and true online Remote Settings behavior when warranted. Existing real 48-event synthetic input→rAF tests passed; they do not measure physical input-to-pixel latency.
5. **Nix final handoff — [#10](https://github.com/sguzman/vulpra/issues/10):** native Nix-toolchain compile, package, Weston/Wayland, WebDriver/extension tests **passed on the real workstation**, and Nix CI passed. Document/close remaining comprehensive host parity and setup/maintenance (N6/N7), distinguish Nix devShell from pure/reproducible Firefox `nix build`. No urgent need to redo completed build work.
6. **Final branding/release distribution:** Vulpra display name, vendor, English Fluent branding, independent launcher/profile, Firefox-compatible UA pref and GitHub update-help URLs exist. Still assess independently licensed visual icons/trademarks, desktop/app-ID integration, branded UI consistency and a real independent **automatic security update/distribution** policy before any public release. [Branding audit](LICENSING-BRANDING.md) and [UA issue #5](https://github.com/sguzman/vulpra/issues/5).
7. **BYOB defaults now in source, runtime pending — [#12](https://github.com/sguzman/vulpra/issues/12):** `main` branding prefs now default to **no Firefox Accounts/Sync and no built-in password saving, autofill, or generator prompts**, leaving extension-based Vaultwarden ownership independent. [Static source/negative-fixture CI 44346485653 PASS](https://github.com/sguzman/vulpra/actions/runs/44346485653). **These defaults have NOT been verified in an updated native package or ported into the pinned Firefox 160 28-overlay candidate**. Preserve existing profiles and leave security services untouched. [BYOB policy](BYOB-DEFAULTS.md).
8. **Later, not current:** aggressive C++→Rust rewrites and further source pruning. They are strategic goals only after high-priority security and reliability work.

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

## Work selection after the pause

The active priority list above supersedes older suggestions to finish M3 dependency closure. Existing M3 evidence and decisions remain available as a future backlog, not immediate assignments. Do not advance the formal product percentage until separately defined acceptance gates pass.

**Status discipline:** Do not award additional M3 or overall progress for source audits, CI mocks, a passing headless benchmark, or documentation alone. Update [PROGRESS.json](PROGRESS.json) only when a defined acceptance gate has passed. The most recent recorded milestone ledger is dated November 9; this snapshot incorporates separately verified November 17 workstation and CI outcomes.
