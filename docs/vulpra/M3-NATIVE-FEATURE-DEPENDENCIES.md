# M3 Linux native and feature build dependency crosswalk

**Evidence:** [M3 Linux Native and Rust Feature Boundary Audit 40922965533](https://github.com/sguzman/vulpra/actions/runs/40922965533) **PASSED**, checking **14 bounded source relationships** and rejecting **18 deliberate source mutations**. Its `m3-native-build-feature-boundaries` artifact includes the exact Git SHA, source paths, line numbers, source anchors, classifications and limitations. The workflow uses partial Git checkout and `git show HEAD:path`, not a full Firefox rebuild.

## Native dependency and feature map

| Boundary | Source-observed relationship | Decision |
| --- | --- | --- |
| Browser → shared Gecko | `browser/app.mozbuild` includes `toolkit/toolkit.mozbuild`; this is not a standalone Rust browser. | Retain |
| GTK/Wayland → widget/xul | `widget/moz.build` chooses toolkit directory using `MOZ_WIDGET_TOOLKIT`, includes X11/Wayland path when enabled and adds GTK/Wayland flags; widget native code targets `xul`. | Retain |
| Native xul linkage | `toolkit/library/moz.build` builds xul and links JS, NSPR, NSS, SQLite, and other native dependencies. | Retain |
| Rust gkrust | Shared toolkit includes Rust library unless `MOZ_OVERRIDE_GKRUST`; `RustLibrary("gkrust", ...)` and `for_xul` integrate Rust into Gecko. | Retain; not proof of all-Rust implementation |
| Glean official-build distinction | `gkrust-features.mozbuild` includes `glean_with_gecko`, plus `glean_disable_upload` when `MOZILLA_OFFICIAL` is false. | Protected; source config alone does not prove uploads |
| Crash reporter | Rust feature `crashreporter` under `MOZ_CRASHREPORTER`. | Conditional; preserve crash privacy/error paths |
| Native Telemetry | Toolkit traverses telemetry; `FINAL_LIBRARY="xul"`, pingsender directory and non-mobile IPC implementations are wired. | Retain |
| Core Glean, WebExtensions, security | Toolkit build traverses Glean/extensions, native security, and sandbox under separate compilation guards. | Retain |
| Sync vs FxAccounts | Browser enables Sync by default; desktop `fxaccounts` is separately included from `MOZ_SERVICES_SYNC`-gated `sync`. | Independent lifecycle/fallback work required |
| DevTools client vs server | Browser requests `MOZ_DEVTOOLS=all`; client conditional but server, startup and platform retain separate source wiring. | Retain baseline |
| New Tab and GenAI | Browser components include New Tab/GenAI/AIWindow; New Tab native pieces enter `browsercomps` and GenAI separately packages modules. | No whole-directory removal |
| New Tab generated assets | Built-in New Tab addon uses `addon-jar.mn`; Node-generated JS/CSS and webextension glue have distinct build inputs. | Isolated bundle experiments only |
| Nimbus and Normandy | Browser defaults to Normandy; toolkit always traverses Nimbus and browser-shared Normandy helper even for opt-in runner omission. | Retain shared helper |
| Updater | Native `libmar` included under `MOZ_UPDATER`; signing and NSS dependency must be preserved. | Conditional; updater enabled is not verified remote update infrastructure |

## What the audit proves and does not prove

This is an **actual pinned-source manifest crosswalk**, not an evaluated generated Ninja graph, complete FFI/caller analysis, or linker map. No emitted binary member or compressed package byte saving has been measured by this audit.

The distinction between Glean's non-official build feature and the earlier telemetry sender tests is particularly important: the prior local telemetry HTTP test explicitly enabled a test-only sender path. Nothing here proves how normal official-build data upload behaves or that a remote erasure request has been honored.

The source classification complements [testing, WebDriver and localization dependencies](M3-TESTING-LOCALE-DEPENDENCIES.md), the source-level Pocket/Sync/telemetry audits, and existing opt-in native package experiments.

**Next:** reconcile source guards with exact generated `config.statusd` values at a source-matched normal build; inventory actual packaged locale and binary resources; evaluate dynamic consumers and fallbacks; and only then consider isolated source-matched native omissions with full functional/privacy and byte-level acceptance.

This is another **bounded M3 inventory subtask**, not the complete graph or a new passed broad gate. **M3 2/6 (33%); overall 44%, Δ0 pp.** No source was removed or default feature disabled.
