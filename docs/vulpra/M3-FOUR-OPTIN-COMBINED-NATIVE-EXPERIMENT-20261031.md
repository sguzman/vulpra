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

## Native source-matched combined trial

[**Native combined original source build 41222758405**](https://github.com/sguzman/vulpra/actions/runs/41222758405) is the source-pinned compilation/measurement workflow. It checks out the exact original full-browser compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, checks `browser/moz.configure` and the baseline mozconfig bytes against current opt-in controls, then invokes `mach configure` and requires **all four actual generated lean values** plus protected GTK/Wayland, sandbox, Sync, DevTools and Vulpra branding. It retains the original source's native toolchain bootstrap, 24-GiB swap, one Cargo job and compiler cache options.

Only if the actual native build/packages finish does `ci/m3-combined-four-native-package.sh` compare the newly staged candidate tar.xz against the **authenticated original source-matched full-normal compiled baseline** ([40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527), archived SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`). It reports signed compressed bytes, both SHA-256 digests, a non-mutated actual native executable, and explicit caveats. It does **not** claim independent per-feature compressed size, sum old measurements, attribute all bytes causally to omissions, or guarantee reproducibility across compiler/archiver runs made at different times.

Two independent post-build workflows are also scoped to a **successfully completed** exact combined build: [real disposable offline headless PNG and private 10-second Weston same-surface buffer-commit acceptance](https://github.com/sguzman/vulpra/blob/main/.github/workflows/m3-original-four-optin-native-acceptance.yml), and [original pinned native 26-check retained New Tab/modern-legacy fallback method replay](https://github.com/sguzman/vulpra/blob/main/.github/workflows/m3-original-four-optin-newtab-native.yml). Neither runs on a failed or incomplete compilation. The 26 New Tab checks use bounded inert hooks and do not trigger live Pocket feeds/remote content/real user accounts.

**Until the specific native workflow and corresponding runtime replays actually pass, only the source-contract test is accepted.** Build runtime, size deltas, native behavior and combined compatibility must not be recorded as complete on the strength of workflow definitions.

The open M3 gate still requires the complete feature/bundle/generated-build/dynamic dependency and platform map (not just a four-feature package experiment). This work does not itself close it, enable default removals, or begin M4.

**Ledger: M3 5/6 (83%); overall Vulpra 61%; accepted weighted milestone Δ0 percentage points.**
