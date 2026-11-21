# Vulpra 🦊

**Vulpra** is a personal, Linux-first Firefox-derived browser project. It targets x86-64 Linux with native Wayland/Hyprland use. It is independent of Mozilla and is not an official Firefox product.

**Active development: `main` — Firefox 160.0.1 source directly in this branch.**
The complete upgraded browser source and Vulpra changes are committed to
`main`; no separate `160.0.1` working branch or external Mozilla checkout
is required for the default native build. `./nix/vulpra build` compiles the
checked-out `main` source using Nix/nom and an isolated
`obj-vulpra-main-160/` output directory. See [Nix build instructions](nix/README.md).
The owner verified **native workstation compilation and graphical launch** on November 20, 2026. Current-main package provenance, TLS/sandbox/security and public-release acceptance remain separate, unpassed gates.


**Non-interrupting security QA:** [Isolated worktree and copied-browser test setup](docs/vulpra/SECURITY-QA-ISOLATION.md) is available via `./nix/vulpra security-qa status|setup|sync|snapshot|headless`. It runs without Nix realization, never changes the main browser/profile and only creates a worktree/copy upon explicit command. The initial QA mock CI passed; real Gecko security acceptance is separate.

**Current project snapshot (2026-11-20):** [What is complete, what was actually pruned, remaining blockers, and next work](docs/vulpra/STATUS.md). The [active security acceptance roadmap](docs/vulpra/SECURITY-ACCEPTANCE-ROADMAP-20261120.md) lists the current gates. The November 8 milestone and November 6 security callouts below are historical, not claims about the present Firefox 160.0.1 source.

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
- [Known bugs and QA follow-ups](https://github.com/sguzman/vulpra/issues), including [Hyprland frame and typing lag](https://github.com/sguzman/vulpra/issues/7)
- [Roadmap and acceptance gates](docs/vulpra/ROADMAP.md)
- [Resumable source download and first local build](docs/vulpra/LOCAL-BUILD.md)
- [Nix Linux development toolchain and guarded terminal workflows](nix/README.md) — opt-in, pinned, with CI verification; native browser acceptance separately tracked in [issue #10](https://github.com/sguzman/vulpra/issues/10)
- [Current status / pruning and release gaps](docs/vulpra/STATUS.md)
- [Progress ledger](docs/vulpra/PROGRESS.json)
- [M3 debloat candidates and measurement rules](docs/vulpra/DEBLOAT.md)
- [Upstream provenance and license handling](docs/vulpra/UPSTREAM.md)
- [Import procedure and recovery](docs/vulpra/IMPORT.md)
- [Decisions](docs/vulpra/DECISIONS.md)

Project color: <img src="docs/vulpra/swatch.svg" alt="Vulpra lilac swatch" width="26" height="15"> `oklch(72% 0.13 308)`.

**License:** Firefox-derived files retain their upstream licensing, notices and third-party license obligations. Vulpra-specific files have their own explicit licensing as applicable. The initial template MIT license must not be treated as relicensing the Firefox code. See [license and provenance notes](docs/vulpra/UPSTREAM.md).


## Build the current Vulpra locally with Nix (Firefox 160.0.1)

From an up-to-date `main` checkout of Vulpra, use the **existing Nix/nom launcher**:

```fish
./nix/vulpra build
```

The default local build now targets the same independently authenticated Firefox 160.0.1 BYOB source candidate tested by CI, NOT the historical Firefox 159 source files still stored in the repository root. It assembles the 28 verified Vulpra source overlays with the official Mozilla Firefox 160.0.1 source in a **separate** `~/Code/Builds/vulpra-160.0.1/source` directory and runs the native `./mach configure` and `./mach build` **inside the repository's pinned Nix developer shell**. Build objects stay there; existing Vulpra 159 build outputs, Firefox Developer Edition and its profile remain untouched.

If the official source is not already cached, the command **stops before downloading it** and says how to authorize the one-time upstream SOURCE fetch:

```fish
./nix/vulpra build --fetch-source
```

This may be a **large download** of Mozilla's official Firefox source; it never downloads the CI-built Vulpra executable. Subsequent builds use the cached source and are incremental. Nix may also fetch missing pinned toolchain dependencies through the user's configured binary caches.

To launch **the locally built copy** with a separate profile:

```fish
./nix/vulpra run
```

To inspect cache readiness without downloading source or launching Firefox:

```fish
bash scripts/vulpra-build-160.sh --status
```

The signed-off candidate's complete source Git tree is pinned to `d6f7faf6583831a58d127480db54b5bcd5ab5949` and the Mozilla hotfix release commit to `58fed86b1b6864ad71b83c910a879d6f1a6b678b`. The source assembly and CI-produced compiled browser have been checked independently, but **the complete native build on the actual target EndeavourOS/Hyprland desktop is not yet verified**. Never confuse a source-only test or CI browser build with target-machine acceptance. This remains an experimental dogfood browser, not a public security release; Google Safe Browsing provider integration is deferred.

The repository retains historical Firefox 159 tracked source files for provenance; `./nix/vulpra mach` and `./nix/vulpra configure` still operate on those files. Use `./nix/vulpra build` for the current 160 candidate until further source-tree migration. Do not claim the physical 159 root has been replaced by 160.
