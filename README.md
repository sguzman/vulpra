# Vulpra 🦊

**Vulpra** is a personal, Linux-first Firefox-derived browser project. It targets x86-64 Linux with native Wayland/Hyprland use. It is independent of Mozilla and is not an official Firefox product.

> **Status (2026-11-08):** 🦊 **M2 working Linux browser: 100% (5/5 gates). M3 debloating: 83% (5/6 gates). Overall product roadmap: 61%.** M2 passed native startup, Wayland, localhost JavaScript and WebExtension/profile-isolation tests on the original target workstation. M3 has verified source-only non-Linux pruning and bounded opt-in omissions, with security, extension and account foundations retained. The sixth M3 gate remains open: complete feature-oriented native dependency, conditional loader, FFI and protected-fallback closure is not established. Full current Linux builds, packaging and bounded browser runtime checks passed in CI; an [independently reconciled current compiled Rust archive/ELF report](docs/vulpra/M3-REAL-CURRENT-GKRUST-ARCHIVE-ELF-FFI-20261108.json) confirms two named gkrust FFI definitions, **not** all Rust/C++ call edges or linker-member selections. [Native three-call branch acceptance](https://github.com/sguzman/vulpra/actions/runs/42491120174) remains pending. This is neither an Arch/Hyprland current-build acceptance nor a public release, security-current certification, or Rust-only browser.

> **Security maintenance blocker (verified 2026-11-06):** The `main` source still lacks at least two high-impact post-beta fixes, **CVE-2026-117860** (same-origin policy) and **CVE-2026-120572** (layout boundary); see the [source-authenticated audit](docs/vulpra/SECURITY-159-POSTBETA-PATCH-GAPS-20261104.md) and [security issue #3](https://github.com/sguzman/vulpra/issues/3). The fixes are isolated on `security/firefox-159-postbeta-hotfixes`. Its [full native Linux build and four original Mozilla crash-fixture replays passed](https://github.com/sguzman/vulpra/actions/runs/42224511431), and [independent source/package/runtime reconciliation passed](https://github.com/sguzman/vulpra/actions/runs/42231630654). **That is bounded test evidence, not a security-current or public-release certification:** Firefox advisory coverage remains incomplete, memory-safety exploit resistance and target workstation acceptance are unproven, and no patched branch has been merged or released. **Do not use the experimental browser for routine or sensitive browsing.** The immutable beta comparison branch and installed Firefox Developer Edition remain untouched.

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
- ✂️ **M3 — Personal debloating: 83% (5/6 gates)**; current normal browser native CI, source/pruning audits, selected loader callsites and two named compiled Rust archive-to-ELF definitions are verified. Complete FFI/conditional fallback closure, the three current compiled XPCOM call branches, and target-machine parity remain open. See the [dependency closure blockers](docs/vulpra/M3-NATIVE-DEPENDENCY-CLOSURE-BLOCKERS-20261104.md).
- 🦀 **M4 — Defect fixes / Rust trajectory: 0%**, pending M3

**Overall product roadmap: 61%** (equal-weight M2–M4; source scaffolding M1 excluded). Percentages are updated only for tested completion, not for roadmap or tooling preparation. Packaged size, source footprint, browser memory and startup measurements have separate provenance and must not be conflated. Upstream security maintenance and independent icon/trademark review remain necessary before distribution.

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
