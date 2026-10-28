# Vulpra M3 — User-specific debloating

**Status (2026-10-28):** The working Linux personal baseline remains verified (M2 5/5). M3 has **six independently verified accepted selective changes**: three opt-in packaged resource experiments (Normandy runner's measured archive difference 27,620 compressed bytes; two ASRouter promotional modules 3,184 bytes; New Tab AdsFeed 7,120 bytes in the guarded paired build versus 219,360 bytes in the earlier paired build, not a reproducible component-level saving; these separate measurements may include packaging nondeterminism and are **not additive** without a combined build), and three source-only pruning passes: 453 Windows/Cocoa/installer files (6,266,676 original Git blob bytes), 14,134 Android app files (115,996,869 bytes), and 280 further Android/iOS/UIKit leaf files (7,704,040 bytes). Total **14,867 files / 129,967,585 original Git blob bytes** permanently removed from `main`. The final eight-root trial [native CI 40600510147](https://github.com/sguzman/vulpra/actions/runs/40600510147) passed compilation, package verification, Wayland, JS, WebExtensions, Nimbus and profile isolation; committed in [8331ca6](https://github.com/sguzman/vulpra/commit/8331ca63f97b84779d6b1765955dff6017d060f8). **M3 remains 2/6 gates (33%) and overall product 44%.** No compiled Linux package-size savings are attributed to the platform source deletions; the tested workstation browser and source have not been updated. Unsupported Android/iOS builds and mobile-specific tests may still reference removed paths.

## Pocket: two live source registrations and legacy fallback (2026-10-28)

[Source-pinned Pocket/New Tab boundary workflow 40773515182](https://github.com/sguzman/vulpra/actions/runs/40773515182) **PASSED**, artifact `m3-pocket-live-boundaries` ID **12854235698**, at exact checkout SHA `5f09f3581889490ff56bb6983a0220a8eefb41ae`. This complements the earlier 1,945-line broad Pocket grep by verifying *specific* source-to-registration relationships and expected fallback branches; the workflow uses sparse Git objects, not a full 469k-file checkout. Seven deliberately broken registration, fallback and package-source anchors were rejected.

| Source boundary | Observed relationship | Candidate decision |
| --- | --- | --- |
| `ActivityStream.sys.mjs` | Registers `system.topstories` → `TopStoriesFeed` and `discoverystreamfeed` → `DiscoveryStreamFeed` while keeping `system.topsites` and `prefs` | Retain |
| `TopStoriesFeed.sys.mjs` | Has a legacy discovery-disabled/pref-parse fallback, its own stories/topics and cache, and Pocket CTA | Retain |
| `DiscoveryStreamFeed.sys.mjs` | Connects modern recommendations, `showStories`, SPoCs, shared `AdsClient` and Nimbus-pref updates | Retain |
| `addon-jar.mn` and New Tab `moz.build` | Bundle both source feeds, default wildcard and generated content UI resources | Retain |
| `discoverystream.promoCard.enabled` / `pocketCta` | Preference keys exist in the source; consumer/rendering/deletion consequences NOT proven | Investigate only |

**Boundary:** source matches and factory/call-site guards are not proof of runtime execution or safe deletion. No native compilation, browser smoke, default change, package-size saving or removal authorization is claimed. Before testing a narrower opt-in Pocket promo removal, map renderer imports, all consumers and remotely supplied values, then build a protected fallback and repeat full native/runtime/package acceptance. The promotion/Pocket/Sync/telemetry gate remains OPEN: **M3 2/6 (33%); overall 44%**.

## Focused telemetry submission and policy dependency audit (2026-10-28)

The read-only [full tracked-source workflow 40721612576](https://github.com/sguzman/vulpra/actions/runs/40721612576) **PASSED** at source commit `8af4710591147d7fc110c002ed4b6a8a760d2708`, including synthetic path-class regression, invalid-checkout refusal, actual checked-out `git grep` and bounded artifact upload. Artifact `m3-telemetry-reference-audit` (ID 12830103191) holds exact file names and matching line numbers.

| Literal reference class | Matching source lines |
| --- | ---: |
| Telemetry JS policy/sender app | 74 |
| Telemetry native/other internals | 32 |
| Glean runtime / metrics | 34 |
| Crash reporter | 10 |
| Browser integration | 92 |
| Other toolkit consumers | 127 |
| Tests and fixtures | 663 |
| Documentation / tooling | 108 |
| Localization | 3 |
| Other source and generated metadata | 143 |
| **Total literal matching lines** | **1,286** |

This scope differs from the earlier 1,736-line reporting audit; its count cannot be interpreted as an increase or decrease. Literal references include comments, preference names and fixtures, and do not establish a dynamic call graph or real network transmission.

**Observed boundaries, not deletion authorization:**
- `toolkit/components/telemetry/moz.build` links native telemetry code into `xul`, traverses `pingsender`, and packages `TelemetryControllerParent.sys.mjs`, `TelemetryReportingPolicy.sys.mjs` and `TelemetrySend.sys.mjs` independently of the reporting preference. Deleting the sender outright would break packaged imports without guarding startup/shutdown.
- `TelemetryControllerParent.sys.mjs` calls `TelemetryReportingPolicy.setup()`, `TelemetrySend.earlyInit()`, `TelemetrySend.setup()`, and their shutdown paths; it also manages local telemetry and crash annotations.
- `MOZ_TELEMETRY_REPORTING` defaults according to `mozilla_official`; `MOZ_DATA_REPORTING` separately accounts for Health Report, Crash Reporter and Normandy. A build-time macro, UI preference or source default **does not prove actual uploads**. Vulpra's actual configured reporting state and policy/network behavior still need a verified check.
- Glean metric registration/IPC and crash reporting have distinct dependencies and should remain intact. Only a narrow **submission/transport opt-out** can be considered after verified disabled-path behavior, and would still require a native build, runtime/browser test, profile safety and matched package-size result.

**Result:** source evidence improved, zero code pruned and zero binary saving claimed. M3 stays **2/6 (33%)**.

## AdsFeed default-flag preprocessor repair and source-matched retry (2026-10-28)

The initially successful [experimental native build 40617558714](https://github.com/sguzman/vulpra/actions/runs/40617558714) remains an independently tested **opt-in candidate**, but its first [full AdsFeed baseline 40627016301](https://github.com/sguzman/vulpra/actions/runs/40627016301) FAILED **after successful native compilation and staging**: the default normal package lacked `builtin-addons/newtab/lib/AdsFeed.sys.mjs`. It is not a verified package reduction.

The cause was a preprocessor configuration bug rather than a compiler regression. `set_define("VULPRA_NO_NEWTAB_ADSFEED", False)` still inserts a named global macro into the JAR/JS preprocessor context; `#ifdef` tests *presence*, not value, so the default jar manifest and `AppConstants` mistakenly selected the experimental branch. The same error affected the default runtime value of `VULPRA_NO_ASROUTER_PROMOS`. The [surgical flag fix 16d8753](https://github.com/sguzman/vulpra/commit/16d87534e557be4d1e5edac08262ad8af0932af3) keeps the false `CONFIG` values used by `moz.build` but emits the global macros only when the opt-in is enabled. Source tests and a three-variant preflight now check normal baseline versus each isolated candidate. A first preflight 40707358202 revealed only that the enabled define was serialized as JSON string `"1"`, not integer `1`; corrected test commit [3b9f731](https://github.com/sguzman/vulpra/commit/3b9f7317f271b8ed5e1b169436662b3744fe4ce2) restarted [preflight 40708134402](https://github.com/sguzman/vulpra/actions/runs/40708134402).

To avoid another expensive serial pair, [commit 864e5b7](https://github.com/sguzman/vulpra/commit/864e5b7653b3a1cad94f5b60139e932ddb099b75) starts [corrected candidate 40708368192](https://github.com/sguzman/vulpra/actions/runs/40708368192) and [corrected FULL baseline 40708368442](https://github.com/sguzman/vulpra/actions/runs/40708368442) concurrently from the **same** source SHA. The normal baseline independently checks that original AdsFeed plus five protected New Tab modules are present, SHA-256 verifies package, and uploads bounded source/size/SHA evidence. The candidate exercises real Wayland/New Tab/JS/WebExtensions/Nimbus/profile isolation; only after it passes does a separate workflow_run compare both accepted source-matched reports. At the time the initial retry began no final paired saving was accepted. The subsequently successful native and matched-size result appears in the following section; the normal target workstation was not modified and M3 remains **2/6 (33%)**.

## Exact ZIP-entry package forensics (2026-10-28)

The existing read-only `ci/m3-package-footprint-local.py` now records exact packaged `builtin-addons/newtab/lib/` entries within every scanned `omni.ja`: member path, decompressed bytes, ZIP entry compressed bytes, CRC32 and ZIP compression type. The source package's `tar.xz` SHA-256 is checked **before** any census. The optional `ci/m3-compare-package-footprints.py BASELINE.json CANDIDATE.json OUTPUT.json` compares two existing census reports and classifies their exact resource additions, omissions and changed ZIP members without modifying or rebuilding the browser. Synthetic source tests cover the omission of AdsFeed, surviving ActivityStream and a deliberately different outer archive delta; comparison refuses duplicate resource paths and inconsistent counts. Initial [package-census CI 40753658338](https://github.com/sguzman/vulpra/actions/runs/40753658338) PASSED; the paired report comparator's [regression CI 40754147781](https://github.com/sguzman/vulpra/actions/runs/40754147781) was in progress when documented.

**Limits:** Independent ZIP entry byte sizes cannot establish a resource's marginal contribution to the outer XZ archive. The JSON reports do not contain source commit identity or independently rehash the packages when compared. They cannot replace the native build/runtime or source-matched package acceptance proof. The earlier 219,360-byte AdsFeed archive delta from `864e5b7` is not an isolated file-size measurement; the original source file is 20,046 B. The guarded `956bcdb` build subsequently PASSED its source-matched comparison, measuring 7,120 B; this reinforces the need for controlled resource-level attribution.

## Guarded AdsFeed native acceptance and variable compressed size (2026-10-28)

At source `956bcdb2b28316aedacd796793f0ccfac7360899`, the corrected [opt-in native Linux build 40744304129](https://github.com/sguzman/vulpra/actions/runs/40744304129) PASSED C++/Rust compilation, real packaged `omni.ja` omission of AdsFeed, SHA-256 archive checking, retained protected New Tab modules, Weston Wayland, real about:newtab, JavaScript navigation, WebExtensions, Nimbus and temporary profile isolation. The independent same-source [full baseline 40744304177](https://github.com/sguzman/vulpra/actions/runs/40744304177) PASSED and physically retained AdsFeed. [Comparison 40763684071](https://github.com/sguzman/vulpra/actions/runs/40763684071) PASS, evidence artifact `m3-newtab-adsfeed-matched-size` **12849826192**.

| Measure | Normal full | Guarded opt-in lean |
| --- | ---: | ---: |
| Compressed tar.xz bytes | 87,151,684 | 87,144,564 |
| SHA-256 | `8e4ffba3aa47c38ef6600bb3a46e2365abc53b2f064e640d0ce361ef6485ef7f` | `0be84b18391f336218a23114e5ae19ef55b9963512d4a62abd3b4ad5db319b56` |
| AdsFeed module present | Yes | No |
| Protected New Tab resources | Present | Present |

The paired observed difference is **7,120 B (0.00817%)**. A prior independent same-source pair at *different* commit `864e5b7` found **219,360 B (0.251711%)**, differing by **212,240 B**. Two experiments at different source revisions are **not** repeat builds. Neither measures marginal AdsFeed bytes or proves nondeterminism caused all the difference. Archive metadata, compression and source differences remain confounders. The 20,046-byte AdsFeed source file is not itself the size of its compressed package entry. CI artifacts here contain **small evidence JSON and checksums, not the whole packages or their per-entry ZIP indexes**. The newly added offline package-census tools will only perform real per-entry comparisons once both verified packages exist; no claims about original package entries can be inferred from the present evidence.

No cumulative opt-in savings, no default-browser changes, no permanent source deletion, no user workstation update, and no broader milestone credit: **M3 2/6 (33%), overall 44%**.

## AdsFeed residual sponsorship and missing-feed fallback review (2026-10-28)

**Scope correction:** The previously accepted opt-in removal physically omits only `AdsFeed.sys.mjs`. It is **not an ad-free New Tab**. Preserved `DiscoveryStreamFeed.sys.mjs` can still fetch sponsored stories through its legacy/direct MARS endpoint or `AdsClient` path. `TopSitesFeed.sys.mjs` can still fetch sponsored tiles through its direct Contile/MARS request or AdsClient path, and `TopStoriesFeed.sys.mjs` retains sponsored-story logic. These consumers remain because removing all New Tab discovery, rendering, and top-site capabilities would require a much larger fallback and compatibility proof. The existing opt-in archive saving must not be represented as the byte size of all sponsored-content features.

**Concrete bug in the opt-in variant:** both `DiscoveryStreamFeed.loadSpocs()` and `TopSitesFeed.ContileIntegration._fetchSites()` previously selected `state.Ads` based *solely* on the remote-overrideable `unifiedAds.adsFeed.enabled` preference, even though the opt-in browser never registered the AdsFeed factory. `DiscoveryStreamFeed.clearSpocs()` had the same missing-module selection for deleting user ads data. [Commit 956bcdb](https://github.com/sguzman/vulpra/commit/956bcdb2b28316aedacd796793f0ccfac7360899) adds a guard at all three sites using the immutable `AppConstants.VULPRA_NO_NEWTAB_ADSFEED` so the opt-in browser routes through the already-retained normal direct-fetch/AdsClient fallbacks. With the flag false, ordinary Vulpra selection is unchanged.

**Verification boundary:** source-level 2 DiscoveryStream + 1 TopSites guards were added to the pinned-HEAD contract. New [source audit 40744304643](https://github.com/sguzman/vulpra/actions/runs/40744304643), [three-way preflight 40744304060](https://github.com/sguzman/vulpra/actions/runs/40744304060), corrected [opt-in native 40744304129](https://github.com/sguzman/vulpra/actions/runs/40744304129), and [full baseline 40744304177](https://github.com/sguzman/vulpra/actions/runs/40744304177) were launched from the same commit and later PASSED; comparison 40763684071 measured **7,120 B (0.00817%)**. The original **219,360 B** standalone delta remains evidence only for the older source `864e5b7`. No source or normal-browser feature was deleted, and the larger M3 sponsor/Sync/telemetry audit remains open.

## Third accepted selective opt-in omission: New Tab AdsFeed (2026-10-28)

The corrected [native AdsFeed-free Linux run 40708368192](https://github.com/sguzman/vulpra/actions/runs/40708368192) **PASSED** C++/Rust compilation, SHA-256 packaging, physical absence of `builtin-addons/newtab/lib/AdsFeed.sys.mjs` in the real bundled `omni.ja`, retention of ActivityStream/DiscoveryStreamFeed/AdsClient/Store/TopStories, Weston Wayland, real about:newtab, JavaScript, WebExtension install/background/storage/uninstall, Nimbus and isolated Firefox-profile runtime acceptance. Its independently built [full normal Linux baseline 40708368442](https://github.com/sguzman/vulpra/actions/runs/40708368442) **PASSED**, including physical presence of AdsFeed and all five protected modules.

Both builds share exact source commit `864e5b7653b3a1cad94f5b60139e932ddb099b75`, with the same core build options and isolated objdirs. [Comparison 40717645290 attempt 2](https://github.com/sguzman/vulpra/actions/runs/40717645290) **PASSED** the independent source-commit, variant, protected-module and package-byte assertions, and uploaded `m3-newtab-adsfeed-matched-size` artifact **12837270260**.

| Measurement | Normal source-matched baseline | Isolated AdsFeed opt-out |
| --- | ---: | ---: |
| Compressed package bytes | 87,147,484 | 86,928,124 |
| SHA-256 | `4d7293a126342f6a424f56d41c679e61986c05ff30bf96ffc2288cca39fb872e` | `04448d3d4fc62b746cead7064f6676eb13d8e5def0cf14a036152728ce8279b3` |
| AdsFeed resource | Present | Omitted |
| Five protected New Tab resources | Present | Present |

The measured **219,360-byte (0.251711%) compressed archive difference** is **not proof that all 219,360 bytes are caused by the module**: independent builds may differ in nondeterministic package content. The first comparison attempt stopped waiting before baseline finished (its native compile/package subsequently PASSED), then CI reran only the failed comparison job against already-existing artifacts. No extra full compile was needed.

This is the third accepted **opt-in** removal experiment, **not** a default-browser removal or a permanent source deletion. Do not add savings from Normandy, ASRouter and AdsFeed without one combined source-matched tested build. It extends the existing per-removal evidence gate, **not** another broad M3 acceptance gate; **M3 remains 2/6 (33%), overall 44%**.

## First accepted removal: Normandy recipe runner (2026-10-27)

Two native Ubuntu 24.04 builds with the **same commit** `674db8e385c36aec23e78bbe059b2a1fec194fae` and identical non-Normandy compiler options both compiled and packaged successfully: [lean candidate](https://github.com/sguzman/vulpra/actions/runs/40431768974) and [full baseline](https://github.com/sguzman/vulpra/actions/runs/40431769117). The branded native ELF remains `vulpra`; the profile-isolating launcher is separately packaged as `vulpra-launch`. Both archives and SHA-256 attestations were uploaded as CI artifacts.

[Real packaged runtime acceptance](https://github.com/sguzman/vulpra/actions/runs/40439671494) **passed**. The lean browser attached and committed Wayland frames under Weston, captured a full valid PNG, preserved the Firefox profile, navigated with real browser JavaScript to a localhost HTTP 302 and verified the final DOM through persistent WebDriver, installed and removed an unsigned temporary WebExtension with content/background/storage execution, and initialized Nimbus ExperimentStore and API. A previous runtime attempt incorrectly used a short-lived screenshot process to judge asynchronous navigation; the real WebDriver check resolves that test race without changing the compiled engine.

[Matched artifact size comparison](https://github.com/sguzman/vulpra/actions/runs/40439793884) **passed**:

| Linux native compressed package | Actual bytes |
| --- | ---: |
| Full Normandy | 86,937,548 |
| Opt-in Normandy-free | 86,909,928 |
| **Verified reduction** | **27,620 (0.032%)** |

The lean package lacks `res/normandy/Normandy.sys.mjs` and retains required shared Nimbus/Normandy helpers. The result counts as **one** verified removal, not complete debloating, a comprehensive browser security audit, or an Arch-specific gain. No existing installed Firefox or M2 package was changed.

## GenAI bundled-runtime dependency audit (2026-10-27)

The [complete pinned-source Git audit](https://github.com/sguzman/vulpra/actions/runs/40441432696) passed with **845 literal matching lines**: 129 outside the GenAI subtree/tests/docs, 139 GenAI-owned, 561 tests, 16 documentation/tooling. The exact findings and locations are in the downloadable `m3-genai-references` JSON artifact. This is the actual complete repository, not an incomplete GitHub code-search index.

Important outside consumers: `browser/components/BrowserComponents.manifest` registers `LinkPreview.init` during delayed startup; `browser/components/DesktopActorRegistry.sys.mjs` contains GenAI actors; `browser/app/profile/firefox.js` contains prefs; sidebar, main preferences, enterprise policy, browser context menus, `toolkit/components/nimbus/FeatureManifest.yaml`, model manager and security sources also reference the feature. Whole-directory deletion would leave runtime/actor/UI references unresolved.

**Decision:** Keep GenAI modules bundled in the verified browser until narrow module boundaries and their complete consumers are guarded. Treat individual promotions, models or entry points as candidates, not as automatically removable. An eventual opt-in removal must pass the same source-pinned real native Wayland/JavaScript/WebExtension/Nimbus + compressed-package comparison suite used for the Normandy runner.

## Accepted Linux source-only pruning (2026-10-27)

The [complete GitHub CI native experiment](https://github.com/sguzman/vulpra/actions/runs/40519242468) **passed** after deleting exactly 453 platform-specific Git-tracked implementation files from `widget/windows/`, `widget/cocoa/` and `browser/installer/windows/` in an ephemeral checkout. Their aggregate Git blob bytes were **6,266,676**; this is a **source footprint measurement**, not a Linux binary or build-time saving. Read-back of the [permanent `main` deletion commit](https://github.com/sguzman/vulpra/commit/81d9b335b747c377b730a0c3a4de9ea1cf522fe5) verified that exactly eight files remain inside those directories.

The necessary survivors are `widget/windows/metrics.yaml` and `widget/cocoa/metrics.yaml` (Glean desktop generator), `browser/installer/windows/nsis/updater_append.ini` (unconditionally used by locale/update generator), plus `widget/windows/rust/Cargo.toml`, `rust/src/lib.rs`, `rust/src/permission_monitor.rs`, `rust/src/AlertsServiceRust.h`, `rust/src/PermissionMonitor.h` (Cargo target-gated dependency graph). Those resources are required to resolve a Linux build despite target-specific runtime code being excluded.

CI verified protected GTK/Wayland/Sandbox/Sync/Normandy/DevTools configuration, complete native compilation, staging and SHA-256 verification of a branded Vulpra package, committed private Weston/Wayland frames, local screenshot PNG/profile preservation, persistent WebDriver JavaScript -> HTTP 302 -> final DOM, temporary unsigned WebExtension lifecycle including storage/background, and Nimbus ExperimentStore/ExperimentAPI. Failed precursors revealed missing [Glean YAML](https://github.com/sguzman/vulpra/actions/runs/40443043378), [updater input](https://github.com/sguzman/vulpra/actions/runs/40514571558) and [target-gated Cargo manifest](https://github.com/sguzman/vulpra/actions/runs/40515987579); all resolved in the successful run.

**Scope limitation:** This accepts one bounded source-only platform-pruning gate. It does not certify all Windows/macOS-specific modules removed, that Linux packages got smaller, or that the telemetry infrastructure was deleted. Further platform, telemetry and promotion work requires separate dependency audits and protected native runtime acceptance.


## Four-way Pocket, promotion, Sync and reporting source audit (2026-10-27)

The read-only [complete source scan](https://github.com/sguzman/vulpra/actions/runs/40544803899) **PASSED** on source commit `dfdc1915b279f33d4d91992355aa8da48384b1a0`. Its synthetic Git fixture, actual tracked-tree scan and evidence artifact all passed. Unlike GitHub code search, the scan used the checked-out pinned source with `git grep`. The artifact contains exact literal matches and ranked non-test/non-doc file paths.

| Candidate reference set | Literal matching lines | Ranked non-test/non-doc paths |
| --- | ---: | ---: |
| Pocket | 3,292 | 295 |
| Promotions / onboarding | 368 | 55 |
| Sync / Accounts | 1,616 | 123 |
| Telemetry transport / reporting | 1,736 | 142 |

The path counts are **not unique runtime dependencies**: the ranking can include incidental third-party/sample matches, and the regexes can miss computed imports. No package-size change, runtime behavior or removal is claimed by the census.

Specific desktop blockers worth isolating before a native opt-out:
- **Pocket:** `browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs` and `ActivityStream.sys.mjs` reference Pocket content; Nimbus feature metadata and new-tab metrics also refer to it. Do not delete New Tab wholesale.
- **Promotions:** `browser/components/asrouter/moz.build` packages promo modules, with dispatch from `ASRouter.sys.mjs`, browser glue, and message-preview/enterprise consumers. Remove only narrow promotions after proving imports, behavior and fallback.
- **Sync / Accounts:** `browser/components/AccountsGlue.sys.mjs` is registered during browser startup and lazily imports **both** FxAccounts and Sync UIState. `services/fxaccounts` is traversed independently of `services/sync`. A compile switch for Sync alone cannot justify deleting Accounts.
- **Telemetry:** `TelemetrySend.sys.mjs` handles ping transmission; `TelemetryReportingPolicy.sys.mjs` and `TelemetryControllerParent.sys.mjs` participate in reporting startup/lifecycle. `toolkit/components/glean` contains native metrics and IPC integrations. `browser/app/profile/firefox.js` has defaults enabling several legacy ping types, but these defaults alone do not establish actual Vulpra network traffic. Treat submission/transport, local metric infrastructure, and crash reporting separately.

The dependency map and candidate statuses are recorded in [DEBLOAT-CANDIDATES.json](DEBLOAT-CANDIDATES.json). **M3 remains 2/6 gates (33%), overall 44%.** Next evidence gate: choose one narrow packaged feature, map every non-test caller and runtime fallback, and only then perform source-matched opt-in native build, live behavior and package-size comparison. No telemetry deletion or other candidate is yet authorized.

## Focused desktop Sync and Firefox Accounts dependency audit (2026-10-27)

A separate scoped [full checked-out Git source audit 40627908207](https://github.com/sguzman/vulpra/actions/runs/40627908207) passed at commit `0d7ff85261ba3e0e2deb0cf367adbad1228e8239`. Its negative-checkout and synthetic path-class regression passed before the real audit. Artifact `m3-sync-reference-audit` (ID 12790237398) records exact matching file paths and line numbers.

| Source reference class | Literal matching lines |
| --- | ---: |
| `services/sync` implementation | 332 |
| `services/fxaccounts` implementation | 281 |
| Browser integrations outside tests | 587 |
| WebExtension integrations | 11 |
| Test fixtures | 1,673 |
| Docs / tooling | 66 |
| Other source and generated metadata | 276 |
| **Total literal matching lines** | **3,226** |

The focused patterns are different from the earlier four-way Sync/Accounts scan (1,616 lines), so the totals cannot be interpreted as growth or code savings. These are literal grep hits, **not distinct live call sites**; they include prefs, comments, test fixtures and generated metadata.

**Concrete build and runtime boundaries:**
- `browser/moz.configure` implies `MOZ_SERVICES_SYNC=True`. `services/moz.build` traverses Sync conditionally but traverses `services/fxaccounts` **independently** for non-Android builds.
- `browser/components/AccountsGlue.sys.mjs` imports both `FxAccounts.sys.mjs` and Sync `UIState.sys.mjs` through lazy module getters, while `browser/base/content/browser-sync.js` imports Sync UIState directly. Merely turning off the Sync build flag without guarding these consumers could break account and browser UI.
- Additional source references in Firefox View, Synced Tabs, preferences, WebExtension Sync storage, and account-auth surfaces need explicit fallback/feature scope; a reference alone does not establish a running call.
- **Decision:** retain both subsystems, map exact activation/disabled-path behavior, and test an isolated source-matched variant before claiming a removable module. No Sync/Firefox Accounts pruning, native compilation, package saving or additional M3 milestone accepted by this audit.

## Focused Pocket / New Tab source dependency classification (2026-10-27)

The older four-way scan above remains historical evidence for Pocket, promotions, Sync and reporting. A **narrower Pocket/DiscoveryStream audit** followed to separate the New Tab production tree from test fixtures and identify external consumers. The corrected [full-source GitHub Actions run 40616102254](https://github.com/sguzman/vulpra/actions/runs/40616102254) **PASSED** at pinned Vulpra source commit `56d42a1f8773aacc239a3ea058a0a9ac09db9f8b`. Git checkout, synthetic class/failure regression, actual `git grep`, and artifact upload passed. Exact locations and classes are in `m3-pocket-reference-audit` artifact (ID 12784464892). The original audit run 40615824272 also passed, but grouped embedded New Tab tests with production code; commit 56d42a1 fixed that classification and retested it. These scoped patterns differ from the older four-way scan, so their counts **cannot be compared as growth/reduction**.

| Literal reference class | Matching source lines |
| --- | ---: |
| New Tab extension source (excluding tests/docs) | 607 |
| New Tab component source (excluding tests) | 36 |
| Test fixtures, including New Tab tests | 795 |
| Browser source outside New Tab | 99 |
| Other source, third-party or data | 312 |
| Documentation and tooling | 87 |
| Localization | 9 |
| **Total literal matching lines** | **1,945** |

**Observed dependency boundaries:**
- `browser/extensions/newtab/lib/ActivityStream.sys.mjs` registers `TopStoriesFeed` and `DiscoveryStreamFeed` in `FEEDS_DATA`, alongside unrelated Top Sites, wallpaper, weather, widgets and other New Tab feeds. `PrefsFeed.sys.mjs` consumes `NimbusFeatures.pocketNewtab`; `DiscoveryStreamFeed.sys.mjs` also uses `AdsClient`, Remote Settings and shared New Tab layouts. Treating these as an independently deletable Pocket application would be incorrect.
- `browser/extensions/newtab/addon-jar.mn` packages the built-in New Tab extension's `lib/*` and `common/*`, plus generated renderer bundles and ASRouter external components. `browser/extensions/newtab/moz.build` generates JavaScript/CSS with existing build steps. Source path deletion and packaged runtime resource exclusion are separate operations.
- Relevant outside definitions include `toolkit/components/nimbus/FeatureManifest.yaml` (102 pattern matches), `browser/app/profile/firefox.js` (71), enterprise `Policies.sys.mjs` (6), and the browser UI's `CustomizableUI.sys.mjs` (3). `ContextId.sys.mjs` and `MozCachedOHTTPProtocolHandler.sys.mjs` also reference New Tab endpoint preferences. These need guard/fallback review before any opt-in package change.
- **False positives exist**: e.g. `third_party/rust/rure/examples/sherlock.txt` and `security/manager/ssl/nsSTSPreloadList.inc` match Pocket-like text or domains but are not evidence of active Pocket imports. The broad `other-external` class is not an executable dependency count.

**Decision:** retain the built-in New Tab extension, its core feed/store, Nimbus, safety/automation, and Glean metadata. Only consider narrowly scoped optional recommendation/sponsorship resources after mapping their dispatch/consumers, default and disabled fallback, packaged-resource registration and feature preference interactions; then require matched-source full/lean native packages and Wayland, JavaScript, WebExtension, Nimbus and profile-isolation acceptance. **No source removal, default behavior change, binary saving, or M3 gate completion is claimed from this scan.**


## Isolated New Tab sponsored AdsFeed packaging trial (2026-10-27)

Source commit [a8547f9](https://github.com/sguzman/vulpra/commit/a8547f9a1cc4e81985cf171c679c1d19a46875b3) adds an explicitly opt-in **Linux-only** `VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED=1` candidate. The normal Vulpra and M3 matched-baseline mozconfigs remain unchanged, retaining all New Tab modules. The isolated candidate uses `obj-vulpra-linux-m3-newtab-adsfeed-experiment`, a compile-time AppConstants guard, and a skip for the `adsfeed` factory in `ActivityStream`'s FEEDS_DATA registration; it does not remove other New Tab feeds or browser-level ad protection.

The built-in `addon-jar.mn` ordinarily packages `lib/*`, and the train-hop XPI separately packages `../lib/**`; both remain unchanged for normal builds. In the experimental branch, the same **46 retained pinned-source library entries** are enumerated separately so only `AdsFeed.sys.mjs` is excluded. A pinned-tree source regression checks both lists against Git and verifies the ordinary wildcard, factory guard, protected dependencies and isolated mozconfig. This source-only manifest check alone cannot demonstrate actual packaged omission.

[Native CI 40617558714](https://github.com/sguzman/vulpra/actions/runs/40617558714) is the required experimental gate: supported Mozilla Clang and GTK configure, full C++/Rust build, independently SHA-256 verified package, omni.ja resource presence/absence, real Weston Wayland, JS, about:newtab fallback, WebExtensions, Nimbus and Firefox profile isolation. **Pending at time of this ledger entry.** If it passes, a separate source-matched baseline/native compressed-byte comparison is required before claiming savings. This experiment deletes **zero Git-tracked files** and changes **no default behavior**; no M3 gate or overall progress credit is awarded.


**Newest evidence:** [New Tab sponsored AdsFeed native trial 40617558714](https://github.com/sguzman/vulpra/actions/runs/40617558714) **PASSED** real Linux compilation, SHA-256 packaging, omni.ja omission of AdsFeed.sys.mjs and retained New Tab modules, Weston Wayland, about:newtab, JavaScript, WebExtensions, Nimbus and profile safety. Experimental compressed package = **86,932,376 B**. The [exact-source normal baseline 40627016301](https://github.com/sguzman/vulpra/actions/runs/40627016301) was still compiling when this entry was written, so **no package saving is accepted** yet.

## Isolated ASRouter AI promotion resource experiment (2026-10-27)

The full-source Pocket/promotion/Sync/reporting audit identified two narrow promotional modules packaged via `browser/components/asrouter/moz.build`. A guarded, **opt-in Linux-only** experiment now excludes exactly `SidebarChatBotPromo.sys.mjs` and `SmartWindowNewTabPromo.sys.mjs` from the browser's ASRouter resource map. It does **not** remove ASRouter, onboarding, feature callouts, new-tab UI, telemetry, WebExtensions, Sync or Nimbus.

- **Source implementation:** `browser/moz.configure` defines `VULPRA_NO_ASROUTER_PROMOS` only when explicitly requested with `VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS=1`. The default build retains both modules. `toolkit/modules/AppConstants.sys.mjs` exports the immutable compiled flag; the two respective `ASRouter.routeCFRMessage` cases never dereference absent modules when enabled. No mutable preference can bypass the guard.
- **Separate object directory:** `ci/mozconfig-linux-m3-promos-experiment`; default `ci/mozconfig-linux` and known-good local object tree remain untouched.
- **Native acceptance — PASSED:** [opt-in native compile, package and runtime 40547968387](https://github.com/sguzman/vulpra/actions/runs/40547968387): GTK/Wayland, sandbox/Sync/Normandy/DevTools retained; native C++/Rust compile; package SHA256; precisely two resources absent with ASRouter/telemetry/onboarding present; real Weston framebuffer commit; JavaScript redirect/DOM/screenshot; WebExtensions install/background/storage/uninstall; Nimbus initialization; Chrome-context guarded remote promo dispatch; Firefox profile isolation.
- **Strict source-matched package measurement — PASSED:** [matched comparison 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401) compiled a full browser from **the candidate's exact source commit `1683ca67b69389a879717bcd537772c3b40624b6`**, kept identical non-promo compiler options, verified both original promo resources in the full `omni.ja`, and SHA256-checked artifacts. **Full tar.xz = 86,930,792 bytes; isolated lean = 86,927,608 bytes; saved = 3,184 compressed bytes (0.00366%).** The first size-comparison job [40563942562](https://github.com/sguzman/vulpra/actions/runs/40563942562) failed solely because its configure assertion incorrectly rejected Mozilla's empty-string false configuration value; after fixing that assertion a source-pinned repair job was initiated by a workflow-file-only push. The corrected job passed. No candidate-vs-original-workstation comparison was used.
- **Offline checks:** `ci/tests/m3-asrouter-promos-optout-test.sh` protects source/config flags; WebExtension harness fixtures check both accepted and rejected Chrome-context promo probes. These tests are not a native browser substitute.

**Accepted, scoped result:** This **opt-in** native feature variant is now an accepted selective package removal under the same M3 per-removal testing gate already satisfied by Normandy and source-only platform pruning. The ordinary/default build still includes the two promotional modules, and ASRouter/other promotions/Pocket/Sync/telemetry remain. The immutable guard prevents remote messages from referencing the absent modules. The measured **3,184-byte** saving is small and must **not** be added mechanically to the separate 27,620-byte Normandy saving; no combined matched build exists. The comprehensive promotional/Pocket/account/Sync/reporting roadmap gate remains open, so M3 stays **2/6 (33%)**, overall **44%**.

## Test-source dependency boundary (read-only audit, 2026-10-27)

The **testing/** tree is not disposable merely because Vulpra's shipping Linux configuration sets `--disable-tests`. This is a classification checkpoint, **not a source deletion or M3 gate pass**.

- Root `moz.build` unconditionally traverses `testing/`; `testing/moz.build` traverses `manifest`, `mozbase` and `mozharness` and includes `performance/perftest.toml`. It also references `android-test/tests/python.toml` for every non-`JS_STANDALONE` application, including the native Linux browser. Therefore even the three-file `testing/android-test` tree is **not safe for direct deletion without a targeted manifest correction**.
- `toolkit/toolkit.mozbuild` unconditionally pulls in `/testing/gtest`, with additional paths for WebDriver, Marionette and Geckodriver when enabled. Browser automation and future repair/regression testing depend on keeping these contracts intact.
- `testing/web-platform/tests` is a web-standards conformance corpus for future Gecko/Rust changes; the GitHub tree output is **truncated**, so no complete blob/size claim was made. `testing/talos` contains 620 Git blobs / 39,772,123 uncompressed blob bytes, and `testing/raptor` contains 262 blobs / 4,859,505 bytes. These performance suites are **intentionally retained**, not identified as bloat purely from their unshipped size.
- Bounded source inventory of build/QA infrastructure: `testing/manifest` 71 blobs / 576,498 B; `testing/mozbase` 571 / 9,608,196 B; `testing/mozharness` 265 / 1,167,199 B; `testing/geckodriver` 44 / 447,128 B; `testing/marionette` 235 / 980,402 B. Sizes are **Git blob bytes**, not compressed Linux binary bytes.

**Decision:** retain the build-wired test infrastructure and performance/standards suites. Continue only with **narrow peripheral test fixtures** when exact build-graph conditions and future regression costs are understood; no blanket `testing/`, web-platform or performance-suite deletion is authorized. This classification addresses one part of the still-open M3 test-source audit, but does not complete the entire gate or change percentages.

## Accepted Android application source pruning (2026-10-27)

This is a **source-only Linux-first** reduction, not a runtime feature flag or a measured desktop package-size saving. The original unpruned Git parent contains **14,134 files / 115,996,869 Git blob bytes** in exactly these three unselected Android application roots: `mobile/android/fenix/` (3,881 files / 61,071,734 B), `mobile/android/focus-android/` (743 / 9,353,910 B), and `mobile/android/android-components/` (9,510 / 45,571,225 B).

A [real complete Linux native test, run 40585240593](https://github.com/sguzman/vulpra/actions/runs/40585240593), staged those exact deletions in a disposable checked-out source tree, installed Mozilla Clang >=19, configured protected GTK/Wayland/sandbox/Sync/Normandy/DevTools, compiled the browser, packaged and SHA-256-checked it, and **passed** actual Weston Wayland frame attachment/commit, localhost screenshot/PNG, real WebDriver JavaScript redirect and final DOM, unsigned WebExtension install/background/storage/uninstall, Nimbus readiness, and original Firefox profile isolation. All preserved shared modules were required to remain in the source tree. The earlier failed preflight [40584538820](https://github.com/sguzman/vulpra/actions/runs/40584538820) used Ubuntu's unsupported Clang 18 due to staged changes before toolchain bootstrap; this was a setup failure and the corrected source deletion was retested successfully.

The permanent [source commit 546755376021](https://github.com/sguzman/vulpra/commit/546755376021d230bb12ab2f904129a7d6f80973) deletes **only those three directory tree entries**. The root Git tree changes only under `mobile/android/`; every other mobile subentry retains its pre-prune tree SHA. `mobile/shared`, GeckoView, `mobile/android/moz.build`, `widget/android`, and shared build inputs remain.

**Known tradeoff:** The source reference scan reported **685 lines** outside the selected app roots, mostly Android Taskcluster jobs, Gradle roots, build sparse profiles, Android-only tests, formatting exclusions and source comments. The root `settings.gradle` and Android CI tasks still refer to deleted apps and must not be treated as working Android build paths. This personal fork intentionally does not support building those Android applications. Future Linux developer tooling and shared mobile/GeckoView source require their own focused checks. No claim is made about the compiled Linux binary becoming 116 MB smaller.

With the prior 453-file Windows/Cocoa pruning, **14,587 source files totaling 122,263,545 original Git blob bytes** have been deleted from `main`. This is source repository working-tree reduction, not Git history packfile savings or compiled binary size improvement. The broad mobile/testing/localization M3 audit remains unfinished, so the overall roadmap percentages remain **M3 33% (2/6 gates), product 44%**.

## Accepted further mobile/iOS/UIKit source-only pruning (2026-10-27)

[Full native/runtime CI 40600510147](https://github.com/sguzman/vulpra/actions/runs/40600510147) removed exactly eight directories in a disposable Git checkout; verified **280 Git blobs / 7,704,040 original blob bytes**, compiled the complete Linux GTK browser with supported Clang 22, packaged and SHA-256 checked the result, and passed real Weston Wayland, JavaScript navigation and screenshot, WebExtension install/storage/messaging/uninstall, Nimbus readiness, and original Firefox profile isolation. Artifact `m3-mobile-leaves-apps-native-evidence` (ID 12783184176) includes exact per-root counts, reference audit, package checksum and runtime reports; the trial archive measured **86,922,928 compressed bytes**, with no same-source full baseline comparison, so **no compiled-package saving is claimed**.

The eight removed roots are `mobile/android/fonts` (5 files / 6,766,009 B), `mobile/android/geckoview_example` (47 / 224,036 B), `mobile/android/examples` (48 / 168,270 B), `mobile/android/test_infra` (23 / 21,981 B), `mobile/android/test_runner` (27 / 151,217 B), `mobile/android/branding` (44 / 106,205 B), `mobile/ios` (54 / 137,629 B) and `widget/uikit` (32 / 128,693 B).

The evidence artifact includes **110 external literal reference lines**. These remain mainly in Android Gradle/mozconfig/Taskcluster/test configurations, platform-specific iOS logic, test runner manifests, lint ignores and documentation. A notable dependency is `testing/testsuite-targets.mk` `stage-android`, which copies `mobile/android/fonts` into reftest/mochitest output; that **Android test staging target is no longer supported**. The generic Linux test/QA sources remain preserved. This change deliberately does not assert that deleted mobile paths are safe for future Android builds.

The permanent [commit 8331ca6](https://github.com/sguzman/vulpra/commit/8331ca63f97b84779d6b1765955dff6017d060f8) contains only the tested 280 deletions. An independent GitHub compare verified no modified or out-of-scope files. The main branch preserves `mobile/shared`, GeckoView, `widget/android`, `widget/gtk`, `browser/app.mozbuild` and shared Rust build manifests. With the previous 14,587-file pruning, cumulative permanent source reduction is **14,867 files / 129,967,585 original Git blob bytes**; current Git history is not shortened. The broader mobile/test/localization M3 gate remains open.

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

The machine-readable **14-group review register** is
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
- `toolkit/components/moz.build` traverses the Normandy component
  directory in both variants, because Nimbus and targeting modules still
  depend on three shared helpers plus a legacy schema. The **original**
  conditional `toolkit/components/normandy/jar.mn` includes the full recipe
  runner only with `MOZ_NORMANDY` enabled; the lean variant ships those
  shared resources instead.
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

**Scope:** the separate lean configuration passed its native configure gate,
not package acceptance. The first full CI native build exhausted runner
memory during Rust compilation (15 GiB RAM + 3 GiB swap) and terminated,
without producing an alternate `libxul.so`, `omni.ja`, or tarball. Its
successor uses 24 GiB additional swap and serialized Cargo compilation;
that rebuild is still pending native/package acceptance.
A configure pass is **not** accepted debloating. Before promoting it, compare
the real old and new package sizes and run actual isolated native, Wayland,
HTTP/JS navigation and WebExtension lifecycle acceptance; investigate any
remaining Normandy resource references on that candidate build.

## Dependency boundary: Normandy is not independently removable

Pinned source review on 2026-10-26 exposed dependencies that are *not*
covered by the two guarded `BrowserComponents.manifest` registrations:

- `toolkit/modules/FirstStartup.sys.mjs` loads Normandy lazily, but its calls
  are guarded with `AppConstants.MOZ_NORMANDY`. This path is already conditionally
  safe; it does not prove all other paths are safe.
- `toolkit/components/nimbus/lib/ExperimentManager.sys.mjs` imports
  `resource://normandy/lib/ClientEnvironment.sys.mjs` and
  `resource://normandy/lib/NormandyUtils.sys.mjs`.
  `ClientEnvironment.sys.mjs` itself lazy-loads
  `resource://normandy/lib/NormandyApi.sys.mjs`.
- `toolkit/components/nimbus/FeatureManifest.yaml` includes
  `resource://normandy/schemas/LegacyHeartbeat.schema.json`. Generation
  retains a source path and runtime URI that must be audited.
- `toolkit/components/normandy/Normandy.sys.mjs` currently calls
  `await lazy.ExperimentAPI.init()` during startup. Removing the Normandy
  startup registration without an equivalent, independently validated Nimbus
  initialization path could change retained features' behavior.

The first opt-out disabled the entire Normandy directory. That cannot ship
because Nimbus and shared targeting still import three Normandy helper modules
plus the LegacyHeartbeat schema. The revised **source-only candidate** retains
their upstream URIs through a conditional branch of the *original*
`toolkit/components/normandy/jar.mn`, while omitting Normandy's runner, actions,
content and studies frontend. The normal build continues using the full
manifest. The build-system frontend explicitly rejects declaring a different
JAR manifest when a directory already contains `jar.mn`, so a separate
`vulpra-shared.jar.mn` attempt was removed.

The lean GTK build also registers a minimal `NimbusBootstrap.sys.mjs` via
`MOZ_SRC_FILES` and `BrowserComponents.manifest` to initialize
`ExperimentAPI` after `sessionstore-windows-restored`. It suppresses the
`ShieldFrame` JSWindowActor for the unavailable `about:studies` page.
These are guarded source changes, *not* verified runtime behavior.

The complete pinned-source reference scan passed
https://github.com/sguzman/vulpra/actions/runs/40382641564.
It found **379 matching tracked-source lines**: 143 inside Normandy,
72 obvious tests, 37 docs/tooling and 127 other-source lines requiring
classification. The complete machine-readable artifact was downloaded and
manually examined; remaining production references were checked for guards,
shared-module imports and runtime registration. CI evidence and further runs
are recorded in [M3 issue #1](https://github.com/sguzman/vulpra/issues/1).

After correcting the JAR manifest and source invariants, the opt-in Linux
configure/source checks passed
https://github.com/sguzman/vulpra/actions/runs/40384311987.
A separate [native candidate workflow](https://github.com/sguzman/vulpra/actions/workflows/build-m3-normandy.yml)
was added to compile, package and smoke-test this branch in hosted Ubuntu.
Hosted package metrics must not be misrepresented as a same-toolchain comparison
with the known-good Arch workstation 84,044,920-byte baseline.

The acceptance path is now wired without workstation commands:

1. [Native candidate build](https://github.com/sguzman/vulpra/actions/workflows/build-m3-normandy.yml) compiles the experimental GTK target, stages/checksums the tarball, verifies resource presence/absence and runs headless/Weston startup probes.
2. Only after that job succeeds, [packaged runtime acceptance](https://github.com/sguzman/vulpra/actions/workflows/verify-m3-normandy-runtime.yml) downloads the exact checksum-verified artifact and exercises localhost JS redirect, browser profile isolation and a temporary WebExtension lifecycle using geckodriver.
3. Only after runtime acceptance succeeds, [matched source/build-size comparison](https://github.com/sguzman/vulpra/actions/workflows/compare-m3-normandy-size.yml) uses the same full source commit and Ubuntu build options in an *additional* isolated normal full-Normandy build. It records the compressed and unpacked byte deltas and refuses positive-debloat status if there are no compressed savings.

The matched baseline uses `ci/mozconfig-linux-m3-baseline`; neither CI candidate object tree targets `obj-vulpra-linux`, and no CI step touches workstation files. A source-authenticated CI package is not proof of the local user's binary contents. All three stages require **actual passing workflow results** before this experiment can earn M3 completion. The workflows themselves are preparation and contribute zero percentage.


**Status: M3 0% (delta 0 pp).** No independently accepted removal or package
size savings. The lean binary, runtime Nimbus behavior, full WebExtension
acceptance and matched-toolchain package delta remain unverified.

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
