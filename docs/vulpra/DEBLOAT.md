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

## Verified pinned-workstation source census (2026-10-26)

The user ran `ci/m3-inventory-local.py` successfully on the actual source
checkout at `ee22392142889ed2d8f7d3953332901cafd964ef`.
The read-only inventory counted **483,753** tracked files and
**3,633,358,256** Git blob bytes. The complete JSON and tables are in
`.git/vulpra-debloat/m3-source-inventory.{json,md}` on the workstation.
None of these counts is packaged browser size or actual compile reachability.

| Top-level group | Tracked files | Git blob bytes | Initial review classification |
| --- | ---: | ---: | --- |
| `third_party/` | 54,643 | 942,332,791 | Dependency/license audit; not general deletion |
| `testing/` | 201,076 | 776,789,044 | Test/build footprint; separate source-only vs packaged impact |
| `dom/` | 32,401 | 271,653,154 | Web compatibility, retain by default |
| `security/` | 7,357 | 234,319,326 | Security-critical, retain |
| `js/` | 72,933 | 220,218,858 | Core JavaScript engine, retain |
| `mobile/` | 15,568 | 133,582,038 | Non-target platform review, not automatic removal |
| `devtools/` | 9,725 | 95,216,242 | Optional user-facing developer tools; determine necessity first |

Additional narrowly scoped source-prefix candidates:

| Source group | Files | Bytes | Review role |
| --- | ---: | ---: | --- |
| `widget/windows/` + `browser/installer/windows/` | 283 | 4,652,137 | Linux-excluded platform source |
| `widget/cocoa/` | 178 | 1,626,834 | macOS platform source |
| `mobile/android/` + `widget/android/` | 15,441 | 133,228,752 | Android-specific source |
| `services/sync/` | 223 | 2,059,832 | Optional Sync feature dependencies |
| `services/fxaccounts/` | 53 | 833,077 | Accounts/login integration dependencies |
| `toolkit/components/telemetry/` | 259 | 3,775,176 | Privacy/telemetry dependencies |
| `browser/components/newtab/` | 50 | 423,733 | New-tab functionality |

The suffix-based long-horizon language census counted **41,766**
C/C++/assembly files (670,776,071 bytes), **11,032** Python files
(76,786,691 bytes), **15,756** Rust files (223,048,891 bytes), and
**280,840** web-language files (880,986,062 bytes). It is not a build
dependency graph, and no amount of these non-Rust sources has been
demonstrated removable yet.

**Acceptance status:** Inventory collection PASSED. Dependency tracing,
source isolation, native before/after package measurements and safe removal
acceptance have NOT passed. Do not claim source size as package bloat.
The working browser's tested package belongs to the original local HEAD,
even after a future source-only Git fast-forward.

## First manifest-level dependency findings (2026-10-26)

The following are **verified references in the pinned release's build manifests**,
not guesswork about names. These findings narrow future edits but do not yet
demonstrate a successful native binary reduction.

| Build manifest | Observed build condition | Implication for Linux Vulpra |
| --- | --- | --- |
| `widget/moz.build` | `DIRS += [toolkit]` for the selected `MOZ_WIDGET_TOOLKIT`; GTK-selected branches provide Linux sources | Windows/Cocoa widget directories are **not selected as widget compilation units** in a GTK build. Their tracked sources still require a reference scan before deletion |
| `browser/moz.build` | `installer/windows` enters `DIRS` only if `MAKENSISU` | The Windows NSIS installer is excluded by default unless the Windows installer tool is configured |
| `services/moz.build` | `DIRS += ["sync"]` only if `MOZ_SERVICES_SYNC` | Sync is gated by a real configure switch; inspect its selected value and consumer references before disabling |
| `services/moz.build` | `fxaccounts` is selected for every toolkit except Android | **Do not conflate Accounts with Sync**. Disabling Sync alone does not establish FxAccounts is unused |
| root `moz.build` | `testing` and `third_party/python` included in unconditional root `DIRS` | The tests source tree cannot simply be removed, even with `--disable-tests`; the pinned build previously needed manifest workarounds |
| `toolkit/components/telemetry/moz.build` | Native telemetry units assigned to `FINAL_LIBRARY="xul"`, with generated interfaces and JS modules | Telemetry is not merely optional website reporting; removal can break core compilation/IPC consumers and must be scoped |
| `browser/components/moz.build` | Unconditional component dirs include `newtab`, `screenshots`, `genai`, `search` and more | Feature-disabling requires a specific dependency and UI audit, not blanket directory deletion |

**First low-risk review target:** Linux-unselected Windows/Cocoa desktop code
for *source footprint* reduction, but not as a claim of package-size savings.
For *binary-size* reductions, investigate actual packaged optional features
and their configure guards separately. There have been no source edits
or additional native builds at this stage.

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
