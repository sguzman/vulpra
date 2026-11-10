# Firefox 160 migration — complete Vulpra delta inventory, 2026-11-10

## What was actually measured

An [independent source-tree CI run **42906150081 PASS**](https://github.com/sguzman/vulpra/actions/runs/42906150081) compared **entire Git trees**, not a sparse working tree, between the authenticated Mozilla Firefox **`FIREFOX_159_0b5_RELEASE` = `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`** and Vulpra branch commit **`3e30b2418bf6ef20d9e87b422a7f7198a3df86c5`**. The CI fetched upstream **tree objects only** with `git fetch --filter=blob:none`; the delta enumerator used `git diff --no-renames --name-status -z` and validated source/head identity and status counts. A full tab-separated file list, per-directory counts, and machine-readable summary were published as the 30-day workflow artifact `firefox160-vulpra159-full-delta-git-tree-inventory` (112,120 compressed bytes). No native build, source reset, Git clean, deletion, merge or workstation action was performed.

| Compared-to-upstream status | Distinct paths |
| --- | ---: |
| Added in Vulpra | **705** |
| Modified | **28** |
| Deleted or absent from Vulpra | **14,909** |
| Type changes | **0** |
| **Total** | **15,642** |

The 'deleted' paths exist in the Mozilla 159.0b5 tree but are absent from Vulpra's current tree. That does **not** establish why each was removed or whether restoring/omitting it is safe for Firefox 160.

### Source-family concentration

- `mobile/`: **14,384 paths missing**, including **14,330 Android** and **54 iOS** paths.
- `widget/`: **431 paths missing**, comprising **222 Windows**, **177 Cocoa/macOS**, and **32 UIKit/iOS** paths.
- `browser/installer/windows/`: **54 missing**.
- The above account for **14,869 / 14,909 absent paths** (~99.7%). The remaining **40 paths** span miscellaneous tooling/tests/configuration. Treat these as unresolved until reviewed.
- Added paths are **232 `.github/`**, **324 `ci/`**, **139 `docs/`**, **6 `packaging/`**, and 1 each in `scripts/`, `browser/`, `toolkit/`, `sourcestamp.txt`. Some are source changes, not only documentation/tests.

### Modified 28 paths (exhaustive)

```text
AGENTS.md
README.md
browser/app/profile/firefox.js
browser/branding/unofficial/configure.sh
browser/branding/unofficial/locales/en-US/brand.ftl
browser/branding/unofficial/pref/firefox-branding.js
browser/components/BrowserComponents.manifest
browser/components/DesktopActorRegistry.sys.mjs
browser/components/asrouter/modules/ASRouter.sys.mjs
browser/components/asrouter/moz.build
browser/extensions/newtab/addon-jar.mn
browser/extensions/newtab/build-newtab-bundles.py
browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/AdBanner/AdBanner.jsx
browser/extensions/newtab/lib/ActivityStream.sys.mjs
browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs
browser/extensions/newtab/lib/TopSitesFeed.sys.mjs
browser/extensions/newtab/webext-glue/moz.build
browser/extensions/newtab/webpack.system-addon.config.js
browser/moz.configure
dom/webgpu/tests/cts/checkout/node.tsconfig.json
python/mozbuild/mozbuild/frontend/emitter.py
python/mozbuild/mozbuild/testing.py
taskcluster/kinds/toolchain/android.yml
toolkit/components/moz.build
toolkit/components/nimbus/moz.build
toolkit/components/normandy/jar.mn
toolkit/components/normandy/moz.build
toolkit/modules/AppConstants.sys.mjs
```

These 28 modifications are not automatically 28 independent patches: some form a feature group (ASRouter, ads/promos, newtab, Nimbus, Normandy, build preprocessing). Review and test them as cohesive subsystems.

## Proven Firefox 160 overlay subset — 5 files only

A separate [GitHub Actions run **42905448281 PASS**](https://github.com/sguzman/vulpra/actions/runs/42905448281) took an exact-source sparse checkout of Mozilla Firefox 160 release commit `2887d9de1f69c0e9776413da80e7ba0d1225dd9b` and staged Vulpra's **five** independently hash-verified differences into an **empty private runner temporary directory**. The four original Mozilla 159 source files had the same Git blobs in the Firefox 160 release, allowing the existing Vulpra customizations to carry forward verbatim:

- `browser/branding/unofficial/configure.sh`
- `browser/branding/unofficial/locales/en-US/brand.ftl`
- `browser/branding/unofficial/pref/firefox-branding.js`
- `browser/moz.configure`

The fifth, `browser/app/profile/firefox.js`, **changed upstream in Firefox 160**. The staging script preserves the **exact Firefox 160 preference source** and adds only Vulpra's proven `general.useragent.compatMode.firefox=true`, without a hardcoded blanket user-agent override. The generated file and the other four overlays are checked against hard-coded Git blob postimage SHAs. CI also rejected reuse of a nonempty staging target and an attempt to write to the live Vulpra source tree. This is a **source overlay**, not a complete updated browser. At least **23 other modified paths** remain outside this five-path candidate; other source additions and all absence decisions must also be reviewed.

## Next gates

1. Review each other source change and feature group against **Firefox 160**, with explicit decisions to reapply, rework, omit, or upstream-equivalent. Do not blindly overwrite any newer upstream 160 source.
2. Review platform-specific missing trees against the **target build** and protected dependency graph before deciding to keep any exclusions. Their concentration under Android/iOS/macOS/Windows does not prove safe pruning or complete loader/FFI closure.
3. Prepare a separate *complete* Firefox 160 source tree and Vulpra delta, then build and package it at a single source commit with preserved normal-browser features. Keep old main/QA checkout/immutable baseline intact.
4. Recheck official Mozilla security advisory scope and all unverified fixes; run native Wayland, JS, profile, WebExtensions, Nimbus, strict TLS/sandbox, media/optional-providers, and security regressions.
5. No public/sensitive release or security-current claim until independent package/runtime evidence and ongoing Mozilla security maintenance are accepted.

**Progress remains overall 61% (Δ+0 pp), M3 5/6 (83%).** Neither this delta inventory nor the five-file staging test earns source-pruning, full Firefox 160 migration or security-release credit.


## Second port pass: 17 staged source overlays (source-only acceptance)

A second review checked all **21 other modified code/configuration paths** against Vulpra current main, the exact Mozilla 159 beta, and Firefox 160 source. The original 28 modified paths include **two documentation/control files** (`AGENTS.md`, `README.md`), leaving **26 actual code/configuration paths**. Of those, **14 have identical upstream source Git blobs in Firefox 159 beta and 160**, while **12 have changed upstream**.

- **14 unchanged-upstream-base code/configuration paths:** four original branding/mozconfigure paths plus **ten** additional Vulpra modifications carried verbatim into isolated output. The ten include ASRouter/newtab build and bundle configuration, the `AdBanner` component, WebGPU test configuration, `mozbuild.testing`, Nimbus/Normandy `moz.build`, and `AppConstants`. Each original Firefox 160 blob and current Vulpra modified blob is independently pinned and hash-verified. Their unchanged upstream bases permit an exact file-level carry-over but **do not demonstrate feature integration or compatibility** with new Firefox 160 callers.
- **3 upstream-changed code paths adapted:** the 192 KiB `browser/app/profile/firefox.js` contains the single Firefox compatibility preference added to Firefox 160's *new* complete pref file; `browser/components/BrowserComponents.manifest` and `browser/components/DesktopActorRegistry.sys.mjs` receive their original Vulpra conditional Normandy/Nimbus edits at exact unique anchors in modern Firefox 160 files. For the latter two, removing Vulpra's additions was independently shown to reproduce the old Firefox 159 beta **byte-for-byte**, so no additional Vulpra source modifications were silently missed. All three **generated modern-source postimages** are independently hashed.
- **9 remaining upstream-changed code/configuration paths:** need explicit conflict-aware port decisions and integration tests, listed below.

[Extended isolated Firefox 160 staging **CI 42908889139 PASS**](https://github.com/sguzman/vulpra/actions/runs/42908889139) produced **17** correctly hashed outputs, rejected nonempty and live-tree output locations, and checked source trees remained unmodified. Earlier [15-file staging CI 42908313313 PASS](https://github.com/sguzman/vulpra/actions/runs/42908313313) independently proved the prior step. Intermediate failed staging CI runs were workflow/setup issues, not browser compilation or runtime test results.

### Nine unresolved upstream-changed files

| Path | Porting consideration |
| --- | --- |
| `browser/components/asrouter/modules/ASRouter.sys.mjs` | Optional promotion-module gating; review 160 UI routing and lazy-load semantics before reapplying |
| `browser/extensions/newtab/lib/ActivityStream.sys.mjs` | New Tab lifecycle; preserve 160 initialization and advertisement preferences |
| `browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs` | Discovery Stream promotions; maintain normal safe feature defaults |
| `browser/extensions/newtab/lib/TopSitesFeed.sys.mjs` | Top Sites / sponsored tile handling; preserve modern source changes |
| `browser/extensions/newtab/webext-glue/moz.build` | New Tab bundled resources; no wholesale beta file override |
| `python/mozbuild/mozbuild/frontend/emitter.py` | Gecko build emitter; version-specific parser and build contracts |
| `taskcluster/kinds/toolchain/android.yml` | Android toolchain CI despite Vulpra's Linux-desktop focus; review before assuming removable |
| `toolkit/components/moz.build` | Critical Gecko component-registration list; cannot drop 160 components |
| `toolkit/components/normandy/jar.mn` | Normandy resource manifest: 160 source changed and optional-no-Normandy branch needs separate validation |

These are **source migration work items, not license to delete resources**. Their old Vulpra versions are not automatically valid in Firefox 160. Even after resolving all nine, complete 160 source registration, the changed/new file tree, protected features and actual native browser build/runtime remain mandatory.

**Source-stage coverage: 17/26 modified code/configuration files; 9/26 still unresolved, 0 native Firefox 160 browser acceptance.** This count measures only selected source-overlay analysis; it is **not** a new project percentage or a security readiness claim. Overall project/M3 checkpoint remains **61% / 83%**.
