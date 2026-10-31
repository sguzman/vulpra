# M3 — Source-pinned ordinary-host OFFLINE vs netns ONLINE graphical loader reconciliation
**Measured:** 2026-10-31 UTC  
**No new source deletion, M3 gate acceptance, or compiled savings.**

## Independent native inputs

Both jobs authenticated the exact original source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and original archived full-normal Vulpra package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

- [Ordinary Ubuntu 24.04 host private Weston, OFFLINE run 41149955223](https://github.com/sguzman/vulpra/actions/runs/41149955223) SUCCESS, artifact `13021914490`. Real native uninstrumented ten-second same-surface non-null Wayland buffer attach/commit, profile initialization, followed by ten-second LD_DEBUG observed real browser. The host browser alone opts into `XRE_START_OFFLINE=1`; nonlocal-connection guard is still on.
- [Disconnected Linux network-namespace private Weston, normal ONLINE run 41149955004](https://github.com/sguzman/vulpra/actions/runs/41149955004) SUCCESS, artifact `13022128668`. Same original compiled archive, real uninstrumented and LD_DEBUG graphical ten-second checks, normal online Gecko startup with **no external routes**. Harness explicitly clears `XRE_START_OFFLINE` by default.

Both jobs ran the identical parser source at report-workflow head `f39403ce50bd550b0123a9d68e45b3be947b38d7`. These reports deliberately contain only sanitized glibc-loader basenames/loader-request edges from PID traces; no raw paths, network addresses, user data, symbols or PIDs.

## Reconciliation with fail-closed provenance

[Comparison workflow 41150562882](https://github.com/sguzman/vulpra/actions/runs/41150562882) SUCCESS, [artifact `13023095587`](https://github.com/sguzman/vulpra/actions/runs/41150562882/artifacts/13023095587). Before reading reports, it authenticated each successful upstream GitHub Actions run by **immutable run ID, completed/success status, workflow name, and original source/report head SHA**. The bounded parser requires the original compiled archive identifiers, real ten-second graphical-workload flags, initialized library names, request-target validity, no raw traces, no falsely complete ABI flags, and exact reported counts. Synthetic positives exercise divergent name/edge sets; six malformed/unsafe fixture mutations are rejected.

| Observed exact source-sanitized set | Shared between host offline and netns online | Host-only | Netns-only |
| --- | ---: | ---: | ---: |
| `calling init` library basenames | **152** | **0** | **0** |
| `needed by` initialized edges | **147** | **0** | **0** |
| `dynamically loaded by` initialized edges | **21** | **0** | **0** |

This proves that in **these two executions** offline startup did not change *any observed sanitized initialized loader basename, needed-by edge, or dynamic-request edge*. The entire JSON report files from each independent job also had the same SHA-256 when compared separately; however the CI comparison is what grounds the labeled source provenance and validated set equality. This **does not establish that all native feature routes are equivalent**. A shell wrapper and native browser can emit loader events under one PID, so an initialized basename cannot be assumed exclusive to Gecko.

## Limits and unchanged milestone

These are limited *executed* startup-frame traces of the same original archived browser, on Ubuntu CI. They do not cover future feature execution, unobserved `dlopen`, lazy library activation, all build/compile-time dependencies, dynamic symbol/ABI closure, cross-platform behavior on Arch/Hyprland, production network behavior, or measured new savings. Exact name equality is stronger than equal aggregate counts but not full functional equivalence of an offline and a no-egress-online runtime. No pruning may use this submap as the sole justification.

**Result:** nested source-pinned workload comparison PASS, broad M3 dependency gate still **OPEN (5/6 = 83%)**, overall **61%**, session delta **+0 percentage points**. See [source-based CI crash correction](M3-WAYLAND-HTTP-NONLOCAL-ROOT-CAUSE-20261030.md) and [graphical dependency reachability](M3-GRAPHICAL-LOADER-ROOT-REACHABILITY-20261030.md).
