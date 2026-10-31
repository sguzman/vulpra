# M3 — Original compiled native Vulpra ELF resolution on Arch Linux userspace (2026-10-31 UTC)

## Authenticated original source and tested platform

The **unchanged original compiled Vulpra package** was built from `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and authenticated using archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, from original full-normal compiled run [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527).

[Arch Linux loader test 41211418491 — **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41211418491); [global workflow lint 41211418424 — **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41211418424). A disposable official `archlinux:base` container installed GTK, DBus/GLib, ALSA, NSS, Mesa, GLVND and ELF tools. Its **glibc package version** in the successful report was `2.44+r50+g1848099f063e-1`; the report also retains the content-addressed container image ID. Dependency installation occurred during the container-build step; actual ELF inspection ran with **network disabled**, a read-only original package mount, read-only container root, no Linux capabilities, `no-new-privileges`, and the original metadata observer running as a non-root mount owner.

The same std-only Rust `ci/m3-original-native-elf-loader-list.rs` observer used in the prior Ubuntu audit independently parsed all 28 original regular ELF files and executed the **Arch glibc dynamic interpreter's read-only `--list`** option on each original member. That option reports loader-resolved direct/transitive provider names; it does **not** execute application `main`, browser features or a normal Firefox content process.

| Original package measurement | Ubuntu 24.04 x86-64 CI | Arch Linux x86-64 container |
|---|---:|---:|
| Original regular ELF files listed | **28/28** | **28/28** |
| Declared direct `DT_NEEDED` names | **268** | **268** |
| Direct names present in each ELF's respective loader list | **268/268** | **268/268** |
| Distinct listed provider basenames | **91** | **90** |

The Ubuntu original [read-only loader audit 41207364061](https://github.com/sguzman/vulpra/actions/runs/41207364061) remains independently successful.

## Independently reconciled cross-distribution providers

[Exact-run/head/source-authenticated cross-distro loader set verification 41211723003 — **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41211723003); [global workflow lint 41211722957 — **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41211722957). The verifier fetched only the existing **sanitized** successful original Ubuntu and Arch loader metadata artifacts. It cross-checked the immutable source/archive SHA, all original 28 ELF names, direct loader resolution, distinct/valid provider basenames, platform scope flags and source-run commit identities.

Across both environments, there were **100 distinct provider basenames**: **81** appeared in both loader-list unions, **10** only in Ubuntu's lists, and **9** only in Arch's lists. The one-name difference in total count (91 versus 90) should **not** be confused with a one-library discrepancy.

| Observed only in Ubuntu's loader-list union (10) | Observed only in Arch's loader-list union (9) |
|---|---|
| `libbsd.so.0` | `libcloudproviders.so.0` |
| `libcap.so.2` | `libglycin-2.so.0` |
| `libgcrypt.so.20` | `libicudata.so.78` |
| `libgpg-error.so.0` | `libicuuc.so.78` |
| `libjpeg.so.8` | `libjson-glib-1.0.so.0` |
| `liblz4.so.1` | `libseccomp.so.2` |
| `liblzma.so.5` | `libsqlite3.so.0` |
| `libmd.so.0` | `libtinysparql-3.0.so.0` |
| `libselinux.so.1` | `libxml2.so.16` |
| `libzstd.so.1` | — |

These are **transitive loader-list provider basename observations**, not failed `DT_NEEDED` requirements, recommendations to remove libraries, or proof that either platform must install the other's transitive set. Both environments resolved every original direct declared name in their own loader lists.

## Beyond read-only listing: actual original browser startup on Arch userspace

[**Original native `vulpra` headless Arch browser smoke 41211936574 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41211936574), [workflow lint 41211936575 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41211936575). The unchanged original SHA-authenticated compiled `vulpra` ELF was executed in a disposable official Arch Linux x86-64 userspace. With the container network disabled and a unique temporary home/cache/profile, it rendered `about:blank` as a **real nonempty screenshot with verified PNG signature** and exited successfully. The screenshot, browser logs and profile were **not uploaded**; only provenance, Arch glibc version/image identity and boolean result status were retained. No protected Firefox sandbox preference was intentionally turned off, but that alone is not proof of exact seccomp/user-namespace enforcement.

[**Original graphical Arch Wayland private Weston frame 41212319956 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41212319956), [workflow lint 41212319876 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41212319876). This separate Arch container installed private Weston and Wayland protocol tools. The existing strict `packaging/test-wayland.sh` graphical harness launched the original `vulpra` native binary via a temporary read-only compatibility shim with an isolated profile, `MOZ_ENABLE_WAYLAND=1`, GTK Wayland backend, disabled host networking, and no `MOZ_HEADLESS`. CI authenticated an actual compositor socket and `wl_compositor` / `xdg_wm_base` registry, **10 seconds of native browser liveness**, an initialized isolated `compatibility.ini`, and a **non-null `wl_buffer` attached then committed to the same `wl_surface`**. This is a live Wayland graphical browser test rather than merely loader metadata or a headless screenshot. The temporary launcher, native logs, compositor logs and profile were not exported to the user.

These native Arch startup tests exercise a useful portion of the target platform boundary without modifying the user's live EndeavourOS system. They still use a **headless/pixman Weston compositor and Ubuntu CI host kernel**, not Hyprland, real graphics drivers or the user's exact Arch package inventory. They do **not** prove DRM playback, arbitrary `dlopen`, crash report delivery, updater apply/restart or complete original build/source feature dependency ownership.

## Actual browser dynamic loader initializers during Arch graphical Wayland startup

[**Original real Arch Weston frame + bounded glibc `LD_DEBUG=libs,files` observation 41212665605 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41212665605), [global workflow lint 41212665584 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41212665584). The same original native compiled browser again passed the existing private Weston ten-second same-surface buffer commit and isolated native profile checks, this time with **browser-process-only** loader traces. The source-pinned standard-library Rust observer `ci/m3-original-arch-wayland-loader-events.rs` consumed the traces **inside the temporary network-disabled Arch container**, exported safe provider basenames and counts only, and discarded raw traces, absolute paths, symbols and PID data with container termination.

| Real original browser loader observation | Verified |
|---|---:|
| Native process loader traces with initializer events | **7** |
| Distinct native library basenames whose glibc initializer was called | **103** |
| Distinct basenames *requested* via dynamically loaded-by paths | **40** |
| Distinct basenames *requested* via direct needed-by paths | **84** |
| Core `libmozgtk.so`, `libmozwayland.so`, `libxul.so` initializers | **All observed** |

**A dynamically requested basename is not a claim that 40 individual `dlopen` operations succeeded or that all future `dlopen` paths were exercised.** These counts refer to a bounded graphical workload, not all imported symbols and not every conceivable process path.

[**Independent original compiled 14-library generated preload vs real Arch initializer reconciliation 41212920509 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41212920509), [global lint 41212920443 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41212920443). This separate validator source/run-authenticated both the historical actual compiled `dependentlibs.list` workflow [41210245353](https://github.com/sguzman/vulpra/actions/runs/41210245353) and the successful live Arch graphical loader run 41212665605, checked the same immutable original source/archive SHAs, real private Wayland frame acceptance flags and redacted provider sets. **Every one of the original 14/14 generated preload library basenames was actually observed receiving a glibc initializer call during the private Arch graphical frame.** This directly connects a **generated build artifact** to **actual Linux runtime library initialization** on a second distribution. The list's recorded `mozgtk` → `mozwayland` → `libxul` order is a *preload declaration order*, not an assertion that glibc initializer call order was independently proven.

The successful 14/14 result is an **original compiled runtime/preload preparatory subtask**. The full conditional feature tree, generated Ninja/FFI graph, full lazy/future-dlopen paths, exact host Hyprland/GPU support and all rare end-to-end workflows remain unverified; the sixth M3 acceptance gate remains open.

## Limits, especially for the actual user's EndeavourOS + Hyprland workstation

The container's **Arch userspace** ran on an **Ubuntu GitHub Actions host**. It does not test the user's actual Arch-derived EndeavourOS kernel, graphics hardware, driver stack, Hyprland compositor, existing Firefox profile, remote/DRM media, updates, crash reporting or every future `dlopen` feature path. The read-only loader audit itself does not execute the browser; the separate successful Arch native headless and Weston startup tests above cover bounded real startup paths. This read-only loader audit does not check ABI symbol relocation completion nor the generated Ninja/FFI feature graph. Its Arch base image was unpinned by tag but the resulting image ID and glibc version are recorded for audit; these findings are for that recorded snapshot, not all future Arch releases.

No installed browser, launchers, user data or profiles were touched; no source removal, bytes saved, new performance claim or complete M3 closure was inferred.

**M3 remains 5/6 (83%); Vulpra overall remains 61%; accepted progress delta +0 percentage points.**
