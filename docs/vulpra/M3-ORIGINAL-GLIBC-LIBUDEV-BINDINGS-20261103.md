# M3 — Original browser libudev glibc binding observation without LD_PRELOAD (2026-11-03)

## Actual compiled-browser result and immutable provenance

**[Original native Vulpra USB/WebAuthn CI 41692027881 — PASS](https://github.com/sguzman/vulpra/actions/runs/41692027881)**, job **126112764955**, accepted artifact **13258160425** (`m3-original-browser-usb-nodevice-loader`), and [workflow lint **41692027859 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41692027859). The browser was the original source-pinned full package **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**, original package SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**. Original WebAuthn Rust's **49 function declarations** were authenticated through the prior exact successful isolated Arch ABI artifact of [41358205206](https://github.com/sguzman/vulpra/actions/runs/41358205206), without inventing a new symbol list.

In the existing official disposable Arch Linux, private Weston/Wayland, no-network, no-physical-USB / hidraw original browser test, the real clicked `navigator.credentials.create` request with USB token enabled and software token disabled ended in **`NotAllowedError`** as expected. The existing three live `/proc/maps` phases and their four negative mutations still **PASS**, including the newly mapped native `libudev.so.1.7.15` backing ELF during the USB request.

New **Rust** `ci/m3-original-udev-glibc-bindings.rs` observes the native dynamic linker's **`LD_DEBUG=bindings`** diagnostic output. This does **not** install `LD_PRELOAD` or `LD_AUDIT` hooks, change original source or binary, or replace native symbol pointers. `LD_DEBUG` **does** change the run's diagnostics, I/O and timing, so this is **not** an untouched production-process trace. The diagnostic was exported only to the private `geckodriver` and spawned original browser descendants, with actual raw logs limited to a disposable private `/tmp` path and destroyed at test cleanup. The observer processed bounded raw logs inside the already unprivileged container, and exported only sanitized distinct symbol names, provider basenames and aggregate counts: **no process IDs, raw paths, user data, credentials or raw glibc text**.

## Accepted actual symbol provider observations

| Observation from exact original browser test | Accepted value |
| --- | ---: |
| Private glibc trace files read | **5** |
| Traces containing original packaged `libxul.so` | **2** |
| Same-process traces with `libxul.so` and `libudev` symbol binding | **1** |
| Relevant successful `libudev` binding events | **16** |
| Unique native `udev_*` symbol names | **16** |
| Names that **match** the 49 declared in original WebAuthn Rust `libudev-sys` | **15** |
| Native symbol name **outside** that source declaration list | **1 — `udev_monitor_filter_update`** |
| Native provider basename from actual glibc lookup | **`libudev.so.1`** |

The **15** exact names overlapping original `libudev-sys` declarations were `udev_new`, `udev_unref`, `udev_device_get_parent`, `udev_device_unref`, `udev_enumerate_add_match_subsystem`, `udev_enumerate_get_list_entry`, `udev_enumerate_new`, `udev_enumerate_scan_devices`, `udev_enumerate_unref`, `udev_monitor_enable_receiving`, `udev_monitor_filter_add_match_subsystem_devtype`, `udev_monitor_get_fd`, `udev_monitor_new_from_netlink`, `udev_monitor_receive_device`, and `udev_monitor_unref`.

**Ownership is not inferred from symbol-name overlap.** Glibc's debug log may attribute a `dlsym` lookup to the provider itself rather than the Rust caller. Finding a binding in the same process as original `libxul.so` is **not an uninstrumented `libxul` caller proof**. In particular, `udev_monitor_filter_update` was **not** one of the 49 original WebAuthn Rust declarations. It must remain an explicitly **unattributed native provider symbol** until its actual caller and source/feature owner are independently established; it must never be recast as a 50th WebAuthn Rust declaration. The prior separate [instrumented `libxul` `dlsym` trace 41682006070](https://github.com/sguzman/vulpra/actions/runs/41682006070) established **13** original `libxul`-origin resolved names, but its `LD_PRELOAD` changes binding. No combination of those experiments proves one uninterrupted **uninterposed Rust→C `dlsym`** call stack.

The independent source-pinned `ci/m3-original-udev-glibc-bindings-crosswalk.jq` preserves this boundary: **15 source-overlapping names, one exact pinned unattributed symbol, zero unsupported source ownership assertions**. It rejects four modifications of the actual glibc observation: an arbitrary additional undeclared `udev_*` symbol, substitution of `libxul.so` for the real `libudev.so.1` provider, absence of a same-trace original `libxul` witness, and a mismatched authenticated package SHA. The Rust parser's native unit tests passed under `-D warnings`, and the original user-clicked no-device test and its existing negative cases passed.

The diagnostic first reached a real native glibc observation in [41691174924](https://github.com/sguzman/vulpra/actions/runs/41691174924), but that **run was not accepted**: the initial validator incorrectly required *every* glibc symbol in the browser process to occur in the one WebAuthn Rust module's 49-name list. The correct behavior is to retain the extra observed `udev_monitor_filter_update` **without claiming source ownership**, while still rejecting any new unsupported names. The corrected [41692027881](https://github.com/sguzman/vulpra/actions/runs/41692027881) passed the complete original native run, independent crosswalk, and four mutated fixtures. After acceptance the expensive native workflow returned to **manual-only `workflow_dispatch`**.

## Unchanged safety and M3 acceptance

The native test did **not** access a real security key, user's actual browser/profile, target EndeavourOS/Hyprland system or internet. There is **no evidence yet** for exact original Rust-C FFI caller provenance from this glibc debug mode, complete function ABI versions, all 49 original Rust bindings resolving in an actual browser, every feature's on-demand dependencies, all 28 original packaged ELFs, or complete source/build/platform/indirect `dlopen` dependency closure. No original source, ELF, security subsystem or packaged library was removed. **Saved native bytes: 0. M3 remains 5/6=83%; overall 61%; this session Δ+0pp.**
