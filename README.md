# Vulpra 🦊

**Vulpra** is a personal, Linux-first Firefox-derived browser project. It targets x86-64 Linux with native Wayland/Hyprland use. It is independent of Mozilla and is not an official Firefox product.

> **Status:** repository bootstrap. No Firefox source has been imported, no browser has been built, and no Vulpra-specific bug fix has been verified.

## Direction

1. Import and freeze a **pristine, auditable Firefox 159.0b5** baseline, preserving Mozilla's licensing and provenance.
2. Obtain a reproducible, isolated Linux build that does not disturb the installed Firefox Developer Edition.
3. Audit and incrementally remove features and unsupported platform code that are genuinely unnecessary for this particular browser.
4. Fix directly experienced defects and implement personal features.
5. Over the long term, replace the retained non-Rust native/application infrastructure with Rust while retaining web technologies. This is a destination, not a prerequisite for working software.

Avoid deleting security foundations, extension support, essential web standards or media functionality simply to make the source tree smaller. Track source size, packaged size, memory, startup time and build time separately.

## Pinned source

- Original project: [Mozilla Firefox source](https://github.com/mozilla-firefox/firefox)
- Version: **159.0b5** (Firefox Beta / Developer Edition generation)
- Tag: `FIREFOX_159_0b5_RELEASE`
- Tag target: `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`
- Release source: https://archive.mozilla.org/pub/firefox/releases/159.0b5/source/

The `upstream-base` branch is intended to contain the unmodified source snapshot. `main` is the development branch. **Until those branches and the build are verified, no browser-completion claim is warranted.**

## Project records

- [Stewardship rules](AGENTS.md)
- [Roadmap and acceptance gates](docs/vulpra/ROADMAP.md)
- [Progress ledger](docs/vulpra/PROGRESS.json)
- [Upstream provenance and license handling](docs/vulpra/UPSTREAM.md)
- [Import procedure and recovery](docs/vulpra/IMPORT.md)
- [Decisions](docs/vulpra/DECISIONS.md)

Project color: <img src="docs/vulpra/swatch.svg" alt="Vulpra lilac swatch" width="26" height="15"> `oklch(72% 0.13 308)`.

**License:** Firefox-derived files retain their upstream licensing, notices and third-party license obligations. Vulpra-specific files have their own explicit licensing as applicable. The initial template MIT license must not be treated as relicensing the Firefox code. See [license and provenance notes](docs/vulpra/UPSTREAM.md).
