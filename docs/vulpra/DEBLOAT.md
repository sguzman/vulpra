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

## Versioned candidate decisions (updated 2026-10-26)

The machine-readable **13-group review register** is
[`docs/vulpra/DEBLOAT-CANDIDATES.json`](DEBLOAT-CANDIDATES.json). Each group
states its current disposition, code/binary distinction, supporting manifest
evidence and the exact proof missing before modification. Current decisions:

- **Protected:** GTK/Wayland, WebExtensions, core JS/DOM/network/security and
  license dependencies. These are baseline functionality, not space targets.
- **Source-only review:** Windows/Cocoa widget code and the Windows installer
  are gated by the selected platform in `widget/moz.build` and
  `browser/moz.build`. Android source has separate build/tooling references.
  Source removal is still **not** proven safe from these gates alone; do a
  full-tree reference scan first. It may yield zero packaged-byte savings.
- **Test source retention:** `testing/` is **not** globally optional.
  Root `moz.build` unconditionally traverses `testing`; the toolkit
  traverses `/testing/gtest` separately from the harnesses guarded by
  `ENABLE_TESTS`. The original workstation build needed test-manifest
  workarounds. Trim only after resolving those references, never by deletion
  of the entire tree.
- **Compile/configuration review:** Desktop `browser/moz.configure`
  explicitly implies `MOZ_SERVICES_SYNC=True`, `MOZ_NORMANDY=True`,
  `MOZ_SERVICES_HEALTHREPORT=True`, and `MOZ_DEVTOOLS=all`.
  Sync's traversal depends on `MOZ_SERVICES_SYNC`, while
  `services/fxaccounts` is traversed independently on GTK builds. DevTools
  client is conditional on `all`, but platform/server/shared/startup
  remain; eliminating the client would eliminate debugging workflows.
- **Runtime-bundled feature review:** `browser/components/moz.build`
  unconditionally includes the GenAI, new-tab, onboarding and messaging
  subdirectories, and their manifests package JavaScript, actors or XPCOM
  components. Turning off a feature pref is **not** an equal claim to
  physically removing code or saving package bytes.
- **Telemetry separation:** `MOZ_TELEMETRY_REPORTING` is a configure
  reporting control, defaulting according to `mozilla_official`, while
  `toolkit/components/telemetry/moz.build` still links native telemetry
  into `xul`. The actual local reporting configuration is **unmeasured**.
  Likewise `glean` contains IPC and native generated interfaces; blanket
  deletion is unsafe.

**High-value outcome of this audit:** We can now distinguish platform-gated
tracked source from included Linux runtime modules, and identify which flags
must be measured on the **actual workstation configuration**. We have not
verified global reference reachability, native feature-off builds or source
and package byte deltas. Those remain necessary before physical pruning.

## Inspect the real configured Linux feature switches

Source defaults alone do not tell us what the verified workstation
binary was configured to include. Mozilla's own
`python/mozbuild/mozbuild/backend/configenvironment.py` stores each
configured substitution as a JSON value at
`obj-vulpra-linux/config.statusd/substs/<KEY>`. That is build metadata,
**not** a request to reconfigure or recompile.

The standalone read-only checker below queries selected flags (Sync,
Accounts-adjacent reporting switches, Normandy, DevTools, telemetry reporting,
crash reporter, updater, sandbox, tests, Wayland and WebDriver):

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-m3-config-baseline.sh https://raw.githubusercontent.com/sguzman/vulpra/main/ci/m3-config-baseline-local.sh
and bash ~/vulpra-m3-config-baseline.sh
```

It writes `.git/vulpra-debloat/m3-config-baseline.tsv` and prints flags.
Unrecorded settings are reported as `(missing)` or `null`; neither means
`false`. It never runs `mach` or writes the source or object directory.
The existing object directory predates the Git fast-forward, so **its
config values reflect the previously built browser**, not proof that the new
Git HEAD has been recompiled.

These values are required to rank genuinely compile-gated candidates such
as Sync and the DevTools client. Even an option that reports `false` may
leave runtime code in `libxul` or `omni.ja`; use package content and
before/after native tests to prove a real reduction.

## Actual M2 package baseline (workstation, 2026-10-26 12:28 local)

The real native package census ran successfully after the independent SHA-256
sidecar verification (report in the private workstation Git metadata):

| Metric | Verified measurement | Meaning |
| --- | ---: | --- |
| Compressed Vulpra tar.xz | **84,044,920 bytes** | Real shipped archive before debloating |
| Sum of regular-file tar member sizes | **324,566,909 bytes** | Logical bytes inside tar, not allocated disk space |
| Resource JARs (`omni.ja`) located | **2** | Candidate indexes for targeted bundled-feature investigation |
| Source Git blob bytes | 3,633,358,256 bytes | Source-only census, **not** package size |

The SHA-256 and full per-member/omni index reside in
`.git/vulpra-debloat/m3-package-footprint.json` and
`.git/vulpra-debloat/m3-package-footprint.md`. The uploaded terminal output
shows successful checksum validation and the aggregates above; it **does
not show** any per-feature path hints, exact libxul bytes, or resource sizes.
Do not manufacture numeric savings for Sync, Normandy, DevTools, or GenAI.

This 84,044,920-byte compressed archive is the **pre-removal baseline**
for any later same-target native build. Neither source-only pruning nor a
configure-only test earns package-size credit. A meaningful reduction
requires another independently staged archive, passing M2 functional tests
and a comparable size measurement.

## First isolated shipping-feature removal experiment: Normandy

A first **opt-in candidate**, not yet an accepted removal, is now committed
on `main`. The original `ci/mozconfig-linux` and original
`obj-vulpra-linux` build remain unchanged and stay the M2 reference.

- `ci/mozconfig-linux-normandy-experiment` selects a **different**
  `obj-vulpra-linux-normandy-experiment` directory and explicitly exports
  `VULPRA_EXPERIMENT_NO_NORMANDY=1`. Never select it for the existing
  known-good browser.
- `browser/moz.configure` continues to imply `MOZ_NORMANDY=True` unless
  that experimental flag is set.
- `toolkit/components/moz.build` now traverses the Normandy component
  directory only when `MOZ_NORMANDY` is configured. This is necessary
  because the previous manifest added it unconditionally.
- `browser/components/BrowserComponents.manifest` now guards **both**
  startup and shutdown registrations under `#ifdef MOZ_NORMANDY`.
  Previously Normandy's shutdown hook was unconditional, which could have
  referenced a removed resource.

The source changes are conditional and keep the normal build default.
They are an actual conditional compilation/packaging change, **not**
proof that the runtime works without Normandy. In particular, remaining
callers to `resource://normandy` need a reference scan and an independently
built native package must pass the full M2 regression suite before this
experiment can be promoted or contribute to M3's percentage.

**Actual isolated Linux configure PASS:**
https://github.com/sguzman/vulpra/actions/runs/40379371528.
The hosted runner bootstrapped the full Firefox native configuration and
verified that `MOZ_NORMANDY` was absent/false while GTK, Wayland, sandbox,
Sync, DevTools and the Vulpra application identity remained enabled.
Source-guard and standard-build-default regressions passed
https://github.com/sguzman/vulpra/actions/runs/40379675945.

**Scope:** the separate lean configuration is working, but no alternate
`libxul.so`, `omni.ja`, tarball or installed browser was compiled or tested.
A configure pass is **not** accepted debloating. Before promoting it, compare
the real old and new package sizes and run actual isolated native, Wayland,
HTTP/JS navigation and WebExtension lifecycle acceptance; investigate any
remaining Normandy resource references on that candidate build.

## Actual native configuration results (workstation, 2026-10-26 12:14 local)

The user ran the no-rebuild configuration probe on the *real original object
directory*. It reported GTK/Linux and independent `vulpra` identity
(159.0). The observed values are:

| Configuration field | Generated value | Review consequence |
| --- | --- | --- |
| `MOZ_SERVICES_SYNC` | `"1"` | Sync is **compiled into the baseline**; disabling requires an experimental build and checking its UI/callers |
| `MOZ_SERVICES_HEALTHREPORT` | `"1"` | Health reporting enabled; investigate configuration separately from crash/security infrastructure |
| `MOZ_NORMANDY` | `"1"` | Remote recipe support enabled; candidate for an isolated disabled-feature trial |
| `MOZ_DEVTOOLS` | `"all"` | Full DevTools client enabled; keep by default because local debugging matters |
| `MOZ_TELEMETRY_REPORTING` | `(missing)` | **Unknown**, not proof of disabled reporting |
| `MOZ_CRASHREPORTER` | `"1"` | Preserve until a verified equivalent exists; crash diagnostics are not synonymous with promotional telemetry |
| `MOZ_UPDATER` | `"1"` | Built-in update subsystem enabled; **not** proof independent Vulpra upstream security updates work |
| `MOZ_SANDBOX`, `MOZ_WAYLAND` | `"1"`, `"1"` | Protect Linux security and graphics baseline |
| `MOZ_HAS_REMOTE`, `ENABLE_WEBDRIVER` | `"1"`, `"1"` | Keep for existing remote/automation acceptance until justified otherwise |
| `MOZ_GECKODRIVER`, `ENABLE_TESTS` | `(missing)` | Unrecorded in these generated substitutions; cannot assume false |

This is configuration evidence, **not a completed removal**. The object tree
was built before the recent source-only Git fast-forward. No new compilation
has been performed.

## Measure real package contents before selecting feature cuts

Source size alone can greatly exaggerate shipping impact. A new read-only
native-package census uses the same independently staged package and SHA256
sidecar already verified under M2:

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-m3-package-footprint.py https://raw.githubusercontent.com/sguzman/vulpra/main/ci/m3-package-footprint-local.py
and python ~/vulpra-m3-package-footprint.py
```

It measures the actual compressed tarball and unpacked regular-file sizes,
groups archive contents, and attempts to index `omni.ja` entries (if readable)
to find path-name clues for bundled features such as Sync, Normandy, GenAI,
telemetry, and DevTools. It **never** extracts or executes the browser. Results
stay under `.git/vulpra-debloat/m3-package-footprint.{json,md}`.

The exact counts in this new report are still **pending the workstation run**.
The synthetic fixture tested checksum validation, archive accounting, resource
indexing, and corrupt/missing checksum refusal in
https://github.com/sguzman/vulpra/actions/runs/40376689384.

Path hints may overlap or omit dependencies. Only comparative package
measurements after a compiled feature-off change and actual M2 runtime smoke
can establish a successful binary debloat.

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
