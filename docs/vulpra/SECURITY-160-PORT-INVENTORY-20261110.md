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

[Extended isolated Firefox 160 staging **CI 42908889139 PASS**](https://github.com/sguzman/vulpra/actions/runs/42908889139); subsequently [**CI 42909332136 PASS**](https://github.com/sguzman/vulpra/actions/runs/42909332136) validated the tightened pre-creation destination guard, including rejection of a nonexistent output directory nested inside the live checkout **without creating that directory**. produced **17** correctly hashed outputs, rejected nonempty and live-tree output locations, and checked source trees remained unmodified. Earlier [15-file staging CI 42908313313 PASS](https://github.com/sguzman/vulpra/actions/runs/42908313313) independently proved the prior step. Intermediate failed staging CI runs were workflow/setup issues, not browser compilation or runtime test results.

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


## Third port pass: 21 verified source-stage files (2026-11-10)

After the 17-source-file pass, four further upstream-changed files were migrated as small, exact, targeted patches against authentic Firefox 160 sources, **never** by copying complete older source files onto new ones:

| Newly staged file | Verified Vulpra 159 delta and Firefox 160 preservation |
| --- | --- |
| `toolkit/components/moz.build` | Exact original Vulpra beta delta is a split `DIRS += ["messaging-system", "normandy"]` with comments explaining the experimental no-Normandy helper-jar pathway. Applied to Firefox 160 while explicitly retaining the newly added `widgets` component registration. |
| `browser/components/asrouter/modules/ASRouter.sys.mjs` | Exactly two original Vulpra 159 promo-call guards (`SidebarChatBotPromo` and `SmartWindowNewTabPromo`) were isolated and shown to reproduce Mozilla 159 beta byte-for-byte when removed. Firefox 160 retains both original call sites; only the guards were reintroduced. |
| `python/mozbuild/mozbuild/frontend/emitter.py` | Exactly one original Vulpra modification to skip test-manifest processing when `ENABLE_TESTS` is false was isolated. Reinserted into Firefox 160's changed emitter at its unique function entry, retaining all newer source logic. A Python compile check additionally passed. |
| `taskcluster/kinds/toolchain/android.yml` | Two identical old Vulpra substitutions remove references to absent Android Gradle-plugin source files; both replacements were validated by byte-for-byte restoration of the original Mozilla 159 beta file. Firefox 160 still has both source blocks. The adaptation **retains Firefox 160's newly added Robolectric toolchain job**, rather than overwriting the entire file. |

Every source preimage and generated postimage was checked by **exact SHA-1 Git blob identity**, not expected-string presence alone. The full isolated stage preserves original Vulpra and Mozilla checkouts and refuses source-tree output paths before creating anything.

- [18-file isolated overlay CI **42910079463 PASS**](https://github.com/sguzman/vulpra/actions/runs/42910079463)
- [19-file isolated overlay CI **42910267959 PASS**](https://github.com/sguzman/vulpra/actions/runs/42910267959)
- [20-file isolated overlay + Python syntax CI **42910531243 PASS**](https://github.com/sguzman/vulpra/actions/runs/42910531243)
- [21-file isolated overlay CI **42910773551 PASS**](https://github.com/sguzman/vulpra/actions/runs/42910773551)

### Remaining five code/config migration tasks

1. `browser/extensions/newtab/lib/ActivityStream.sys.mjs` — integrate modern Firefox 160 lifecycle/state and Vulpra's optional New Tab ads/promo gates.
2. `browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs` — preserve new 160 Discovery Stream behavior while reworking opt-in filters.
3. `browser/extensions/newtab/lib/TopSitesFeed.sys.mjs` — preserve 160 Top Sites handling while reworking sponsored-site opt-in source.
4. `browser/extensions/newtab/webext-glue/moz.build` — old Vulpra explicit library allowlist must be reconciled against 160's new preview-string resource stanza; verify resource availability. Do not overwrite the new `newtabPreview.ftl` packaging.
5. `toolkit/components/normandy/jar.mn` — **confirmed source incompatibility**: old Vulpra's optional no-Normandy manifest references `toolkit/components/normandy/lib/ClientEnvironment.sys.mjs`; this path does **not exist** in the authenticated Firefox 160 release, though `NormandyApi.sys.mjs`, `NormandyUtils.sys.mjs`, and `schemas/LegacyHeartbeat.schema.json` do. Requires new component/resource graph analysis rather than reusing the old manifest.

The above are port obligations, not proof of failing runtime behavior. **21/26** modified browser/code/config files have isolated, exact-source migration overlays. Five remain, and the **entire Firefox 160 browser tree has not been assembled, configured, compiled, packaged, or runtime-tested**. No source-pruning, security-current, release, or M3 closure claimed. Overall **61% (Δ+0 pp)**, M3 **83% (5/6)**.


## Fourth port pass: all 26 existing source modifications staged, plus two Vulpra-added source files

The remaining five previously unresolved modified files were adapted against the **actual Firefox 160 release source** rather than copied from Firefox 159.

- `ActivityStream.sys.mjs`: exact original Vulpra delta is a single optional AdsFeed factory filter inside `FEEDS_DATA` initialization; reinserted at the unique surviving 160 anchor. Generated 160 postimage Git SHA `96c542d338f72c22f448a799e6b1b2a569c8c6f3`.
- `DiscoveryStreamFeed.sys.mjs`: exact old delta comprises one lazy AppConstants getter and two opt-in AdsFeed state guards; all three reinserted into the modern 160 source. Postimage `2f4046cdf9d02cef0260da14acd4fd7c859cf854`.
- `TopSitesFeed.sys.mjs`: exact old delta comprises one lazy AppConstants getter and one AdsFeed guard; both inserted into the modern 160 source. Postimage `c68ac1440fe93656a563210ecb9d55d79760a573`. JavaScript parser checks were added for all three New Tab modules.
- `browser/extensions/newtab/webext-glue/moz.build`: the exact original Vulpra beta delta changes only the optional New Tab XPI library wildcard into an opt-in AdsFeed-less allowlist. The authenticated Firefox 160 **root `lib/` inventory still has 47 entries**, and the opt-in Vulpra allowlist covers all **46 other files/directories**, omitting only `AdsFeed.sys.mjs`. The regular build retains its upstream recursive wildcard. The modern Firefox 160 **`newtabPreview.ftl` localization packaging** is preserved. Postimage `6301413e4e5a0f7caf6d2b8195bfc222d3646b7c`.
- `toolkit/components/normandy/jar.mn`: the 160 source deleted `ClientEnvironment.sys.mjs`, so Vulpra's old four-helper no-Normandy branch **cannot be carried verbatim**. Kept the complete modern 160 normal Normandy manifest unchanged inside the normal `MOZ_NORMANDY` conditional and adapted the experimental no-Normandy branch to three *verified-present* helpers: `NormandyApi.sys.mjs`, `NormandyUtils.sys.mjs`, and `LegacyHeartbeat.schema.json`. This is a **new conditional resource policy**, not the exact 159 runtime contract; opt-in feature behavior still needs native validation. Postimage `06317cdd540b6e32eeb195b555923795894f5b0e`.

Source-only independent runs: [**24-source CI 42912907386 PASS**](https://github.com/sguzman/vulpra/actions/runs/42912907386), [**25-source CI 42913289016 PASS**](https://github.com/sguzman/vulpra/actions/runs/42913289016), and [**26-source CI 42913809736 PASS**](https://github.com/sguzman/vulpra/actions/runs/42913809736).

The complete Git delta inventory lists only **two genuinely Vulpra-added files under browser/toolkit source roots**:

- `browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCardOptOut.jsx`, exact Git blob `717e107fa4af5dbffbb0b98083fe84bc5f0c6705`.
- `toolkit/components/nimbus/NimbusBootstrap.sys.mjs`, exact Git blob `df7e5b95aa96d930550d794753c1acef942c70da`.

Both were independently found **absent from the full official Firefox 160 Git tree** and staged without overwriting an upstream file; each copied byte-for-byte from Vulpra's existing source Git blob. They are experimental source dependencies for source overlays already staged, not substitutions for upstream browser features. [**28-file isolated staging CI 42914236622 PASS**](https://github.com/sguzman/vulpra/actions/runs/42914236622), with **26 modified existing code/config sources + 2 added opt-in source files**.

Other Vulpra additions are **232 GitHub workflow, 324 `ci/`, 139 `docs/`, 6 `packaging/`, one import script, and one `sourcestamp.txt`**. Those are tracked outside the 28-file Firefox 160 browser-engine overlay. In particular, copying the old `sourcestamp.txt` into a Firefox 160 build would be misleading and is not part of this source candidate.

The 14,909 Firefox 159 beta paths absent from the old Vulpra tree also remain **untouched** by source-overlay staging. Most are platform-specific: 14,384 `mobile/`, 431 `widget/`, 54 Windows installer. The other **40** include repository/editor metadata, testing fixtures, WebGPU test `.gitignore` files, a Chromium build config, and `aiohttp` vendor files. No source deletion is accepted as safe merely because it was absent from earlier Vulpra; **the complete Firefox 160 source should be preserved by default**.

**Status: source-only overlay review 26/26 existing changed code/config files and 2/2 genuinely new runtime source files checked.** An isolated **full upstream 160 Git-tree composition** check and subsequent native browser build/runtime checks are separate required gates. No Firefox 160 binary, profile migration, public release, or security-current status is claimed. Overall Vulpra 61% (Δ0pp), M3 83% (5/6).
