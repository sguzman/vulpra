# M3 — Original browser libudev glibc binding requester/provider crosswalk (2026-11-03)

## Source-pinned native acceptance

**[Actual original-browser native CI 41694350808 — PASS](https://github.com/sguzman/vulpra/actions/runs/41694350808)**, job **126120846383**, accepted artifact **13260496115** (`m3-original-browser-usb-nodevice-loader`), with [workflow lint **41693911538 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41693911538). Original compiled Vulpra package source SHA **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**, original package SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**. The original source's **49 `libudev-sys` FFI declarations** are authenticated through the earlier exact successful isolated Arch ABI [41358205206](https://github.com/sguzman/vulpra/actions/runs/41358205206).

The existing official disposable Arch Linux/private Weston runtime uses the real original Vulpra binary, private loopback WebDriver and origin, no external network, no physical USB/hidraw access and no user browser/profile access. The original real-click WebAuthn USB token no-device registration still correctly produced **`NotAllowedError`** with USB token enabled and software token disabled. The previous original three-phase mapped native `libudev.so.1.7.15` witness and its four negative mutations also passed.

## What the actual glibc trace observed

The source-pinned **`LD_DEBUG=bindings`** observer `ci/m3-original-udev-glibc-bindings.rs` now preserves a *sanitized basename* of the glibc log's **`binding file` (requester)** separately from the native **`to` (provider)** ELF basename. This is native glibc diagnostic output, **not** `LD_PRELOAD`, `LD_AUDIT`, an overwritten function pointer, or a direct return-address stack trace. Glibc binding messages are parsed only inside one private trace file containing the original packaged `libxul.so`. All raw loader logs, paths, transient PIDs and process memory remain inside the unprivileged disposable container and are discarded, never archived.

| Original native observation | Verified result |
| --- | --- |
| `libudev` native binding events across original `libxul`-loaded process traces | **16** |
| Distinct bound `udev_*` names | **16** |
| Names overlapping original WebAuthn Rust `libudev-sys` source declarations | **15 of the 49 declarations** |
| Additional name outside that declaration list | **`udev_monitor_filter_update`** |
| Additional name's native binding events | **1** |
| Additional name's glibc `binding file` basename | **`libudev.so.1`** |
| Additional name's glibc `to` provider basename | **`libudev.so.1`** |
| Same-library requester/provider according to glibc binding entry | **Yes** |
| Actual original caller instruction, Rust/FFI owner or initiating call stack established | **No** |

**This is a glibc-reported `libudev.so.1` → `libudev.so.1` self-binding** in a process that has loaded the original `libxul.so`. That is a stricter, useful observation than the previous unspecified requester and is consistent with an internal dynamic symbol binding of the host library. It is **not sufficient to prove the exact instruction that initiated the binding, whether another component called a `libudev` API earlier, or which browser/source feature ultimately owns that operation**. In particular, the extra name remains **outside the original WebAuthn `libudev-sys` 49-symbol declaration list**; neither the glibc `binding file` field nor the prior separate [instrumented browser callsite run 41682006070](https://github.com/sguzman/vulpra/actions/runs/41682006070) assigns it to that Rust crate. Do not promote it into a 50th source declaration or a proven native caller.

## Independent fail-closed acceptance

The extended `ci/m3-original-udev-glibc-bindings-crosswalk.jq` independently compares the exact original browser and source/ABI reports, verifies the genuine new requester/provider arrays and numeric event count, and emits a bounded conclusion that explicitly keeps **`extra_symbol_original_caller_ownership_proven:false`** and **`native_glibc_binding_file_requester_not_definitive_original_caller:true`**. In addition to the previous four adversarial checks (unexpected new symbol, fake provider, absent matching original browser trace, archive SHA drift), it **rejects three further corrupted actual observations**: missing requester array, zero additional-symbol binding events, and a spoofed extra-symbol provider `libxul.so`. The **seven** glibc checks and existing **four** independent native-map negative checks passed on source-pinned actual CI **41694350808**. The Rust parser tests also passed with warnings treated as errors.

Earlier [41693911715](https://github.com/sguzman/vulpra/actions/runs/41693911715) did produce the new native observation but **was not accepted**: an invalid jq parenthesis grouping around the derived requester/provider equality stopped the crosswalk. The corrected jq grouping was verified and successful in **41694350808**; no failed attempt was counted as a milestone.

## Unchanged boundaries and progress

The result is a **single original-browser feature workload** under official Arch Linux/Weston with glibc debug logging that changes diagnostic I/O and timing. It does not demonstrate exact host `libudev.so.1` native ELF machine relocation ownership, a full uninstrumented Rust-to-C caller stack, all `49` actual-browser FFI `dlsym` results, native `libudev` internal source callsite, any physical key, user EndeavourOS/Hyprland/GPU, or full original source/build/platform/28-ELF direct/indirect native loader dependency closure. **No original source or ELF was pruned; package bytes saved: 0. M3 5/6 = 83%; overall project 61%; this session Δ+0 percentage points.** The expensive original native workflow was restored to **manual-only `workflow_dispatch`**.
