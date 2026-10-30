# M3 — Native graphical loader root reachability and Bash launcher boundary (2026-10-30)

## Accepted source-pinned trace evidence

All measurements refer to the authentic original full-normal Linux browser compiled from `b1482404dfb8b01342990ee99ea3df0f9756b5f7` (original native tar.xz SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`). They concern two **different executed workloads**, not an exhaustive browser feature/dependency proof.

- [Headless New Tab loader 41137841775](https://github.com/sguzman/vulpra/actions/runs/41137841775) **PASS**, actual initialized-target loader relations.
- [Full graphical Wayland loader 41137841911](https://github.com/sguzman/vulpra/actions/runs/41137841911) **PASS**, real non-null Weston surface commit and ten-second native process survival inside disconnected Linux network namespace.
- [Independent dynamic request edge crosswalk 41138174618](https://github.com/sguzman/vulpra/actions/runs/41138174618) **PASS**, artifact `13016754545`. **67** additional graphical-only `needed by` relations, **3** extra loader-reported dynamic request relations, and **58** additional graphical-only initialized library names. Each real relation is a sanitized basename-to-basename pair, recorded only when the requested target was initialized in the same loader-PID trace.
- [Independent source-candidate mapping 41138797948](https://github.com/sguzman/vulpra/actions/runs/41138797948) **PASS**, artifact `13018260526`; original immutable source has direct GBM `dlopen`, an FFmpeg NSPR runtime linker, and a conditional Rust cubeb/PulseAudio `pulse-dlopen` build path. See [the carefully qualified source report](M3-DYNAMIC-REQUEST-SOURCE-MAP-20261030.md).
- [Bounded root reachability 41139132865](https://github.com/sguzman/vulpra/actions/runs/41139132865) **PASS** with fixtures rejecting forged graph names, request edges, sources, and gate closure. [Sanitized diagnostic 41139201370](https://github.com/sguzman/vulpra/actions/runs/41139201370) and [requester check 41139271964](https://github.com/sguzman/vulpra/actions/runs/41139271964) **PASS** provide per-root counts and the one non-reached name.

## Measured path reachability, not feature necessity

The graph traversal uses **only the 67 graphical-only observed `needed by` relations** and starts from the **three additional dynamic request targets**, without replacing observed edges with guesses.

| Dynamic-load seed | Number of the 58 graphical-only basenames reachable |
| --- | ---: |
| FFmpeg `libavcodec.so.60` | 49 |
| GTK DMA-BUF `libgbm.so.1` | 2 |
| PulseAudio `libpulse.so.0` | 12 |
| **Distinct union reachable from at least one seed** | **57** |
| **Not reached by those seeds** | **1** |

The three sets **overlap** (49 + 2 + 12 exceeds 57); those category totals cannot be added into a list of exclusive dependency ownership.

The single unreached name is **`libtinfo.so.6`**. The actual glibc relation is **`bash → libtinfo.so.6`**, recorded in [CI 41139271964](https://github.com/sguzman/vulpra/actions/runs/41139271964). The package is staged with [`packaging/vulpra`](../../packaging/vulpra), which begins with `#!/usr/bin/env bash`; the [stage script](../../packaging/stage.sh) installs it as the protected `vulpra-launch` wrapper around the native ELF; the [Wayland smoke harness](../../packaging/test-wayland.sh) passes `LD_DEBUG=libs,files` to that launcher. Consequently one `LD_DEBUG_OUTPUT.PID` file can include dependencies originating before native-browser `exec`, even if the later trace also loads `libxul.so`.

This **accounts for the last observation's loader-reported requester**. It does **not** prove the browser never needs libtinfo in other workloads, nor that all 57 other libraries are exclusively browser-owned. It would be a serious measurement error to call all libraries in a `libxul`-containing PID trace a set of exclusively browser-required libraries.

## Important instrumentation caveat and parser safeguards

A separate attempt to partition the log before/after its first `file=libxul.so` request **was not a reliable executable-image boundary**: the authentic headless trace already contained many core Firefox/GTK initialization events before that marker. Such first-request timestamps therefore cannot securely classify libraries as shell or native dependencies.

The parser was instead returned to its original **combined-trace initialized-name semantics**, preserving real initialized-target request edges and adding a source-grounded **`needed by bash` requester classification**, with an explicit flag that no exclusive browser requirement was proven. The browser trace still requires an actual `libxul.so` initialization to reject Bash-only false positives. Any new stage-specific claims must be independently tested; no guessed segment is promoted to accepted library ownership.

## Gate limits

This is **bounded graph reachability** in an original compiled browser workload. It is not per-feature necessity, transitive host/library ABI or symbol version closure, full unexecuted `dlopen`/WebExtensions route coverage, a source-pruning authorization, a new compressed package saving, or native acceptance on the user's Arch/Hyprland workstation. The original ordinary-runner SIGSEGV remains unresolved pending the source-pinned symbol build.

**M3 is still 5/6 (83%), overall project 61%, session Δ0 percentage points.**
