# Vulpra 🦊

**Vulpra** is a personal, Linux-first Firefox-derived browser project. It targets x86-64 Linux with native Wayland/Hyprland use. It is independent of Mozilla and is not an official Firefox product.

> **Status (2026-10-27):** 🦊 **M2 working Linux browser 100% (5/5 gates); M3 debloating 33% (2/6 gates).** Vulpra 159.0b5 compiled and passed packaged Wayland, JavaScript/HTTP, temporary WebExtension and profile-isolation acceptance. M3 has two independently **measured opt-in Linux package reductions** (Normandy runner: 27,620 compressed bytes, 0.032%; ASRouter two AI promo modules: 3,184 compressed bytes, 0.00366%; both with native/runtime and source-matched comparison evidence; not additive without a combined build) and two **source-only pruning passes** (453 Windows/Cocoa files / 6,266,676 Git blob bytes and 14,134 Android-only app files / 115,996,869 Git blob bytes; total **14,587 files / 122,263,545 original Git blob bytes**, both with native/runtime CI verification). Shared GeckoView/Android widget and generator/Cargo dependencies remain; unsupported Android Gradle/app Taskcluster jobs still reference removed app roots. **The personal browser baseline works; these changes do not establish a finished public release, full telemetry removal, automatic updater, broader security audit or Rust-only browser.**

## Direction

1. Import and freeze a **pristine, auditable Firefox 159.0b5** baseline, preserving Mozilla's licensing and provenance.
2. Obtain a reproducible, isolated Linux build that does not disturb the installed Firefox Developer Edition.
3. Audit and incrementally remove features and unsupported platform code that are genuinely unnecessary for this particular browser.
4. Fix directly experienced defects and implement personal features.
5. Over the long term, replace the retained non-Rust native/application infrastructure with Rust while retaining web technologies. This is a destination, not a prerequisite for working software.

Avoid deleting security foundations, extension support, essential web standards or media functionality simply to make the source tree smaller. Track source size, packaged size, memory, startup time and build time separately.

## Evidence-based progress

- ✅ **M1 — Source foundation: 100%**
- ✅ **M2 — Working Linux browser: 100%**, five actual acceptance gates complete on the target machine
- ✂️ **M3 — Personal debloating: 33% (2/6 gates)**, opt-in Normandy and two-module ASRouter package reductions plus Windows/Cocoa and Android-only application source pruning verified; more feature/platform/privacy and test/localization work remains
- 🦀 **M4 — Defect fixes / Rust trajectory: 0%**, pending M3

**Overall product roadmap: 44%** (equal-weight M2–M4; source scaffolding M1 excluded). Percentages are updated only for tested completion, not for roadmap or tooling preparation. Packaged size, source footprint, browser memory and startup measurements have separate provenance and must not be conflated. Upstream security maintenance and independent icon/trademark review remain necessary before distribution.

## Pinned source

- Original project: [Mozilla Firefox source](https://github.com/mozilla-firefox/firefox)
- Version: **159.0b5** (Firefox Beta / Developer Edition generation)
- Tag: `FIREFOX_159_0b5_RELEASE`
- Tag target: `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`
- Release source: https://archive.mozilla.org/pub/firefox/releases/159.0b5/source/

The `upstream-base` branch contains the original release source snapshot with Mozilla's two original workflow files restored. `main` contains that source and Vulpra's own governance files. The **first workstation browser build and runtime acceptance are now verified**; see the evidence in the progress ledger. The workstation source remains pinned at its build-tested commit rather than pulled forward merely to run small standalone QA scripts.

## Project records

- [Stewardship rules](AGENTS.md)
- [Roadmap and acceptance gates](docs/vulpra/ROADMAP.md)
- [Resumable source download and first local build](docs/vulpra/LOCAL-BUILD.md)
- [Progress ledger](docs/vulpra/PROGRESS.json)
- [M3 debloat candidates and measurement rules](docs/vulpra/DEBLOAT.md)
- [Upstream provenance and license handling](docs/vulpra/UPSTREAM.md)
- [Import procedure and recovery](docs/vulpra/IMPORT.md)
- [Decisions](docs/vulpra/DECISIONS.md)

Project color: <img src="docs/vulpra/swatch.svg" alt="Vulpra lilac swatch" width="26" height="15"> `oklch(72% 0.13 308)`.

**License:** Firefox-derived files retain their upstream licensing, notices and third-party license obligations. Vulpra-specific files have their own explicit licensing as applicable. The initial template MIT license must not be treated as relicensing the Firefox code. See [license and provenance notes](docs/vulpra/UPSTREAM.md).
