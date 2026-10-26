# Vulpra M3 — User-specific debloating

**Status (2026-10-26):** M2 working personal Linux baseline verified on the target EndeavourOS workstation (5/5 native acceptance gates). M3 is open; **no removals or source-footprint comparison have been credited yet**.

## First rule: preserve a known-good baseline

Keep the pinned local workstation checkout, its build output, and the verified packaged tarball. Do not reset the tree, disable Git sparse settings blindly, delete build directories or relaunch a full Firefox compilation just to compute statistics. The source inventory is **read-only** and writes only to a private directory inside `.git`.

Retrieve the latest standalone source inventory and run it using Python already on the system:

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-m3-inventory.py https://raw.githubusercontent.com/sguzman/vulpra/main/ci/m3-inventory-local.py
and python ~/vulpra-m3-inventory.py
```

It measures tracked Git HEAD blobs, top-level directories, language families and selected source-prefix groups. It writes two files:

- `.git/vulpra-debloat/m3-source-inventory.json` — machine-readable source census
- `.git/vulpra-debloat/m3-source-inventory.md` — human-readable review tables

These do **not** measure the installed binary or determine actual linking/reachability. In particular, counting C/C++ or Python files is **not evidence they can be removed**. Replacements and safe removals are separate future steps.

## Audited source anchors (Firefox 159.0b5)

These directory names were verified against the source tree in GitHub on 2026-10-26. The labels below represent **review priorities, not deletion approval**.

| Source anchor | Classification | Why it matters |
| --- | --- | --- |
| `widget/gtk/` | **Retain** | Target Linux/Wayland desktop backend |
| `toolkit/mozapps/extensions/` | **Retain** | WebExtension runtime needed by the verified user case |
| `third_party/` | **Retain, license audit** | Bundled dependencies and third-party notices cannot be removed indiscriminately |
| `widget/windows/`, `browser/installer/windows/` | Platform-specific review | Windows widgets and installer sources, not necessarily build-independent |
| `widget/cocoa/` | Platform-specific review | macOS Cocoa widget implementation |
| `mobile/android/`, `widget/android/` | Platform-specific review | Android front end and platform widgets |
| `services/sync/` | Optional feature review | Sync and dependency boundaries require examination |
| `services/fxaccounts/` | Optional feature review | Account dependencies; not necessarily independent of browser login |
| `toolkit/components/telemetry/` | Privacy/feature review | Telemetry infrastructure with shared dependency implications |
| `browser/components/newtab/` | Privacy/feature review | New-tab experience and content/runtime dependencies |
| `testing/` | Build/test scope review | Dev/test materials may remain necessary for compiling and regression work |
| `browser/locales/` | Localization review | Keep required en-US inputs and shipping locale functionality |
| `browser/branding/` | Trademark/license review | Logos and branding require independent compliance review, not blind deletion |

`browser/components/pocket/` was **not present** at that path in this snapshot. It is not a validated deletion candidate. Any feature concerns involving Pocket must start from actual source references.

## Acceptance for an individual removal

A proposed change qualifies as a measured debloat only when all the following are evidenced:

1. Establish current files, bytes, packaged archive size, executable/library sizes, and available runtime baselines from the same source/configuration.
2. Trace build dependencies (moz.build, moz.configure, Rust manifests, references) and relevant runtime paths; classify the exact unit as keep, disable, conditionally compile, or remove.
3. Make one narrow, reversible edit directly on `main`. Keep licensing notices, profile isolation, web standards, Linux/Wayland behavior and the extension APIs covered by M2.
4. Rebuild the affected native artifacts and create a separate package; prove the real package still passes native startup, packaged checksum/launch, Weston Wayland, localhost navigation/JS and WebExtension lifecycle checks.
5. Compare source **and actual compiled/package** metrics before and after. Keep evidence with commit SHA and acceptance log. If a candidate regresses safety or UX, revert; a failed experiment does not count as completed debloat.

M2 proves a **working personal Linux browser baseline**. It does not certify a public release: upstream security update integration, complete icon/trademark independence, and comprehensive security analysis remain separate obligations. No automatic updater has been verified.
