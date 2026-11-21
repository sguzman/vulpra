# Vulpra vertical-tab styling: isolated QA without rebuilding Firefox

**Status (2026-11-21):** Firefox Developer Edition's collapsed-group CSS
layout was confirmed by the user after pulling and restarting FDE. Vulpra's
matching CSS is committed and packaged in source. A real QA-browser visual
geometry run **has not yet been observed**. Synthetic CI only validates the
test harness, source wiring and strict failure conditions.

## First: preview from the existing copied QA browser

From the already-established detached Vulpra QA source (NOT the daily main
checkout, and without any full browser build):

```fish
~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa sync
~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa style-preview
```

`sync` explicitly fetches `origin/main` (HTTP/1.1) into the shared Git object
store and advances **only the clean detached QA checkout**. It refuses modified
or untracked QA source and never runs a browser, rebuild or main checkout
update. The prior copied QA binary remains available.

`style-preview` verifies the existing checksum-checked Vulpra 160.0.1
snapshot first. It launches that **copied QA executable** headlessly in a new
per-run private HOME/XDG/TMPDIR and a disposable GeckoDriver profile. The
current QA checkout's `vulpra-compact-tabs.css` is registered as a
user stylesheet in **that process only** using Gecko's style sheet service.
No persistent Vulpra profile, main source checkout, installed browser or
Firefox Developer Edition profile is read or modified.

This tests how the **new CSS renders** on the existing snapshot without
claiming that the older compiled binary already bundles that CSS.

### Measurements

The test opens synthetic `about:blank` tabs and constructs a temporary
native tab group using `gBrowser.addTabGroup`. Through GeckoDriver's
privileged **QA-only** chrome context, it samples both expanded and collapsed
sidebar layouts after the positions stabilize, and requires:

- Vertical orientation in both states; a real tab group and badge.
- `--tab-min-height: 27px`, with a compact measured tab outline height.
- Square group badge and label corners (`0px` computed radius).
- In collapsed mode, horizontal badge-to-tab-outline difference **at most
  6 CSS pixels**. Larger unexplained left gaps fail the test.
- Explicit stylesheet registration and expected computed border properties.

The test refuses forged/missing geometry, modified QA source stylesheet,
non-QA executables, profile overrides or unexpected report fields. No
external site, credentials or installed extensions are necessary.

**Evidence:** success prints the path to a private
`obj-vulpra-security-qa/runtime/style.*/style-result.json` report. Failure
prints the QA-only `style.log` path. Reports contain synthetic geometry,
not browsing data.

## Later: verify styling inside an independently compiled QA-native Vulpra

After the no-build preview looks correct, the optional heavier final check is:

```fish
~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa build --jobs 2
~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa style
```

`build` compiles the detached QA source into its **separate**
`obj-vulpra-security-qa-build` object directory using pinned Nix/nom.
It can require substantial CPU, memory, network downloads and disk space.
It does **not** rebuild or replace daily Vulpra. `style` runs the same
headless geometry assertions against those QA-native compiled bytes, without
a stylesheet overlay; this checks whether packaged CSS was integrated in the
new binary.

A passing headless test is still **not** human visual acceptance on Hyprland
or an NVIDIA multi-monitor regression test. Also, neither CSS-only nor
compiled style geometry tests constitute TLS/sandbox/Safe Browsing security
acceptance.

## Evidence levels and provenance

- [Source CSS/packaging contract CI](https://github.com/sguzman/vulpra/actions/runs/44852995683) — static source check only.
- [QA geometry/preview synthetic CI](https://github.com/sguzman/vulpra/actions/runs/44930928742) — mock paths, headless dispatch, false-result rejection and isolated profile checks; **not real Gecko layout**.
- A real workstation `style-preview` or `style` PASS is a distinct evidence tier, pending user-provided result.

**No daily-browser restart or promotion is part of this QA workflow.**
