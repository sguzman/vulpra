# M3 — Original Vulpra glibc libudev self-binding versus isolated Arch host ELF relocation (2026-11-03)

## Accepted source-pinned evidence

**[Isolated Arch native ELF CI 41707399519 — PASS](https://github.com/sguzman/vulpra/actions/runs/41707399519)**, accepted sanitized artifact **13266620428** (`m3-original-libudev-host-self-reloc-crosswalk`), and [workflow lint **41707399563 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41707399563).

This small diagnostic reuses two **previously accepted** immutable results rather than rerunning the full browser: source-pinned actual compiled Vulpra in the original WebAuthn USB no-device glibc binding CI [41694350808](https://github.com/sguzman/vulpra/actions/runs/41694350808), original Vulpra source SHA `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, package archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`; and the source-matched original Rust WebAuthn `libudev-sys` 49-symbol isolated Arch ABI [41358205206](https://github.com/sguzman/vulpra/actions/runs/41358205206). All original run IDs, workflow paths, HEAD commits and artifact contents are authenticated by the CI crosswalk.

The original browser's glibc `LD_DEBUG=bindings` trace (without `LD_PRELOAD` or `LD_AUDIT`) contained **one** `udev_monitor_filter_update` binding in the original `libxul.so`-loaded browser process, with `libudev.so.1` both as glibc's **`binding file` requester** and as its `to` provider. The symbol is **not** among the 49 names declared by the original WebAuthn Rust `libudev-sys` module. That trace is not a direct Rust/C caller stack.

The new `ci/m3-original-libudev-host-self-reloc.jq` crosswalk is exercised against **actual native ELF metadata**, inspected with `readelf -Wr` and `readelf -W --dyn-syms` inside a separately built official Arch Linux container. That runtime uses `--network none`, `--read-only`, no Linux capabilities, no privileged user, no actual USB hardware and only a small private evidence mount. Raw ELF dump text remains on the disposable CI runner; only bounded, source-checked metadata is archived. The compared host library resolves to `libudev.so.1.7.15`, the same **backing filename** reported in the original browser's earlier process map.

| Native ELF / original browser evidence | Verified result |
| --- | --- |
| Compared isolated Arch host ELF basename | `libudev.so.1.7.15` |
| Actual inspected host ELF SHA-256 | `dd636932094404444ce8319c89d6074936322f96a8f80e08e22f71c295a84d9d` |
| Arch `libudev` relocation against the extra symbol | **`R_X86_64_GLOB_DAT`** |
| Arch relocation address/offset | **`0x000000000004eee8`** |
| Relocation symbol name and required version | **`udev_monitor_filter_update@@LIBUDEV_183`** |
| Dynamic symbol in this Arch library | **Defined `GLOBAL` `FUNC`, version `LIBUDEV_183`** |
| Previous actual Vulpra browser `libudev` requester/provider binding | **`libudev.so.1` → `libudev.so.1`** |
| Present among original WebAuthn Rust's 49 FFI names | **No** |

The distinctive relocation type matters. An independent **local Ubuntu** `libudev.so.1.7.10` had a `R_X86_64_JUMP_SLOT` relocation for the same versioned symbol; the real isolated **Arch** `libudev.so.1.7.15` instead uses **`R_X86_64_GLOB_DAT`**. The first two attempted native CI checks **41706626491** and **41706934894** correctly rejected an erroneous Ubuntu-derived requirement for `JUMP_SLOT`; they were not accepted as evidence. A bounded diagnostic read of the actual Arch `readelf` output exposed the mismatch, after which the workflow and crosswalk were renamed to **self-relocation**, not **PLT**, and the accepted run **41707399519** passed.

## Fail-closed proof and limits

The accepted crosswalk independently rejects **six** corruptions of real source/ELF inputs: removing the actual Arch relocation, removing the versioned defined function, forging the original-browser glibc requester, falsely inserting the symbol into original Rust WebAuthn FFI declarations while retaining 49 names, substituting a different host ELF backing filename, and providing an invalid host ELF fingerprint. The single sanitized report holds the Arch inspected SHA, symbol, relocation kind, relocation offset and explicit nonclosure flags. Workflow lint passed.

**Interpretation:** The actual Arch library demonstrably has a versioned internal address relocation for the same `libudev` function that glibc reported as a self-binding in an original browser process. This independently **supports a host-library internal binding explanation**, not a 50th Vulpra WebAuthn Rust declaration or an exact original caller. The inspected Arch ELF's hash is preserved for future matching, but the earlier browser run did **not** archive the host ELF SHA: equal filenames **do not prove byte-identical libudev binaries across these two CI runs**. Neither an uninterrupted uninstrumented original Rust-to-C call stack, the original browser's exact instruction ownership, all 49 browser FFI runtime resolutions, actual physical authenticator behavior, target EndeavourOS/Hyprland/GPU host, nor the complete 28-ELF source/build/feature/indirect `dlopen` dependency closure has been established.

**No source or packaged binary was removed, no native bytes were saved, and the sixth M3 acceptance gate remains open. Overall Vulpra 61%, M3 5/6 = 83%, session Δ +0 percentage points.** The lightweight diagnostic workflow is restored to manual-only `workflow_dispatch` after acceptance.
