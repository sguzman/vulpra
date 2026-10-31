# M3 — Four existing guarded omissions in one source-matched native experiment (2026-10-31)

## Goal and default behavior

Before this experiment, four opt-in omissions had each been tested separately, with **different source revisions or independent before/after native builds**. Their compressed archive deltas must **not** be summed as a single production saving. This experiment deliberately combines only the existing, individually guarded optional features without changing the full-normal Vulpra browser, existing Vulpra/Firefox installation, user profiles or release defaults:

| Experimental environment setting | Scoped feature omitted only in candidate |
|---|---|
| `VULPRA_EXPERIMENT_NO_NORMANDY=1` | Normandy remote recipe runner (not core Nimbus) |
| `VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS=1` | Two narrow AI ASRouter promotion implementations (not all ASRouter or GenAI) |
| `VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED=1` | New Tab AdsFeed implementation (not Top Sites or all feed/sponsor infrastructure) |
| `VULPRA_EXPERIMENT_NO_NEWTAB_PROMOCARD=1` | New Tab PromoCard renderer/JS-bundle choice (not all Discovery Stream or AdBanner) |

The new `ci/mozconfig-linux-m3-combined-lean` differs from `ci/mozconfig-linux-m3-baseline` **only** in its isolated build output directory and these four explicit exports. `browser/moz.configure` already contained all four Linux-scoped features; its Git blob `1d7a9bd2af8eb419e7f59d3f737c2fcf9c57995a` is identical between original native compiler source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and current main at experiment initiation.

## Verified cheap/source acceptance

[**Source guard 41222375475 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41222375475); [workflow lint 41222375596 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41222375596).

Rust-only std-library verifier `ci/m3-combined-optin-source-guard.rs` checks exactly four recognized switches enabled once each, retained exact ordinary baseline build settings, independently named object directory, preserved source Linux opt-in guards, and retained Sync/DevTools/profile migrator. Negative fixtures reject missing, duplicated, unknown, disabled or other altered native build options. These checks do **not** execute `mach configure`, compile the browser or verify size/feature runtime.

## Actual compiled result and independent acceptance (2026-10-31 UTC)

**Actual [source-matched native build 41222758405 PASS](https://github.com/sguzman/vulpra/actions/runs/41222758405)** compiled the four existing experiments together, authenticated the original fully enabled original browser artifact, and produced the immutable SHA-256 `e7aa6273fc1078134c216408c7cc110886dc60ada90c062d7f2482fd3f288eec`.

| Original source-matched package | Combined four-opt-in package | Observed compressed difference |
| ---: | ---: | ---: |
| 87,154,544 B | 87,128,408 B | **26,136 B (0.0300%)** |

The reduction is **one signed archive difference from independently built packages at the same browser source revision**. Packaging/nondeterministic binary differences can contribute. It is not the sum of individual trials, not a proven isolated causal four-feature byte saving, and not reproducibility across compilers or CI runs. The current source diff beyond these experimental build controls was not recompiled into a current-HEAD browser.

**Real combined native success:**

- [Corrected original-source native New Tab replay **41233330991 PASS**](https://github.com/sguzman/vulpra/actions/runs/41233330991): 26 actual browser assertions, now modeled correctly as **24 retained New Tab behavior/factory/prefs checks plus two deliberate AdsFeed omission assertions** (`sponsored_adsfeed_omitted` and `newtab_adsfeed_omission_enabled`). The unchanged normal-browser New Tab harness still expects the original retained AdsFeed. New isolated `ci/smoke-newtab-four-optin-retained-runtime.py` rejects missing core factory behavior and an unexpectedly retained opted-out AdsFeed; it additionally checks physically bundled resource absence.
- [Combined source-pinned native Arch Linux offline headless `about:blank` PNG **41233300074 PASS**](https://github.com/sguzman/vulpra/actions/runs/41233300074): actual compiled candidate executable under disposable, network-disabled/read-only Arch userspace, with separate private tmpfs HOME/profile. No screenshot, browsing data or profile uploaded.
- [Combined native Arch Linux private Weston real Wayland frame **41233372221 PASS**](https://github.com/sguzman/vulpra/actions/runs/41233372221): actual isolated GTK/Wayland executable remained alive at least **10 seconds**, created a private native profile and attached/committed a **nonnull Wayland buffer on the same `wl_surface`**. No real Hyprland/GPU or target workstation claim.
- Independent compiler-source artifact check and [workflow lint **41233372211 PASS**](https://github.com/sguzman/vulpra/actions/runs/41233372211) retain default normal browser and existing Firefox Developer Edition/Vulpra profiles.

**Physical native import compatibility:** [separate compiled full-versus-lean 28-ELF `readelf -dW` crosswalk **41233548326 PASS**](https://github.com/sguzman/vulpra/actions/runs/41233548326) verified **all 28 ELF paths present** in both exact authenticated packages; **268 direct `DT_NEEDED` entries per package**, **50 unique direct names**, and exact per-file importer/NEEDED name **order**. `ci/m3-combined-four-elf-direct-graph.rs` is Rust std-only and reads ELF metadata without executing any file. The binary SHA-256 values do not have to match, and this alone does not prove ELF version binding, feature runtime initialization, late `dlopen` paths, generated Ninja build graph closure or safety to remove more source.

**Superseded failures, not hidden:** the first combined New Tab run [41229905045 FAILED](https://github.com/sguzman/vulpra/actions/runs/41229905045) solely on its old `sponsored_adsfeed_retained` expectation, which directly contradicted the intentionally omitted feature. The old Ubuntu-host headless screenshot run [41229905025 FAILED](https://github.com/sguzman/vulpra/actions/runs/41229905025) exited before emitting a screenshot; raw browser logs were confined to its temporary runner and not uploaded, so **its exact failure cause was not determined**. Successfully replaying the package in a different, proven Arch offline/userspace test validates that environment, not the failed Ubuntu-host launch context.

## Native source-matched combined trial

[**Native combined original source build 41222758405**](https://github.com/sguzman/vulpra/actions/runs/41222758405) is the source-pinned compilation/measurement workflow. It checks out the exact original full-browser compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, checks `browser/moz.configure` and the baseline mozconfig bytes against current opt-in controls, then invokes `mach configure` and requires **all four actual generated lean values** plus protected GTK/Wayland, sandbox, Sync, DevTools and Vulpra branding. It retains the original source's native toolchain bootstrap, 24-GiB swap, one Cargo job and compiler cache options.

Only if the actual native build/packages finish does `ci/m3-combined-four-native-package.sh` compare the newly staged candidate tar.xz against the **authenticated original source-matched full-normal compiled baseline** ([40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527), archived SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`). It reports signed compressed bytes, both SHA-256 digests, a non-mutated actual native executable, and explicit caveats. It does **not** claim independent per-feature compressed size, sum old measurements, attribute all bytes causally to omissions, or guarantee reproducibility across compiler/archiver runs made at different times.

Two independent post-build workflows are also scoped to a **successfully completed** exact combined build: [real disposable offline headless PNG and private 10-second Weston same-surface buffer-commit acceptance](https://github.com/sguzman/vulpra/blob/main/.github/workflows/m3-original-four-optin-native-acceptance.yml), and [original pinned native 26-check retained New Tab/modern-legacy fallback method replay](https://github.com/sguzman/vulpra/blob/main/.github/workflows/m3-original-four-optin-newtab-native.yml). Neither runs on a failed or incomplete compilation. The 26 New Tab checks use bounded inert hooks and do not trigger live Pocket feeds/remote content/real user accounts.

**Accepted for the bounded combined four-opt-in native experiment:** compile/package/size observation, real native Arch userspace headless PNG and private Weston frame, and native New Tab 24-retained/2-deliberately-omitted test. **Not accepted:** target Hyprland/GPU behavior, live Pocket/Sync telemetry services, complete generated feature/build/dlopen graph, repeatable per-feature saving or default-source removals.

The open M3 gate still requires the complete feature/bundle/generated-build/dynamic dependency and platform map (not just a four-feature package experiment). This work does not itself close it, enable default removals, or begin M4.

**Ledger: M3 5/6 (83%); overall Vulpra 61%; accepted weighted milestone Δ0 percentage points.**
