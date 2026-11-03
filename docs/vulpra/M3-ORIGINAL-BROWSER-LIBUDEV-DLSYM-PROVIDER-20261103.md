# M3 — Actual original Vulpra WebAuthn libudev native symbol providers (2026-11-03)

## Native acceptance and provenance

**[Source-pinned actual original-browser CI 41682006070 — PASS](https://github.com/sguzman/vulpra/actions/runs/41682006070)**, job **126077815492**, accepted bounded artifact **13254755028** (`m3-original-browser-libudev-dlopen-callsite`). The existing complete-actions workflow lint [41681129270 — PASS](https://github.com/sguzman/vulpra/actions/runs/41681129270) covered the integration before the final source-membership and polling corrections. The original native browser package came from exact original source commit **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**, packaged archive SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**, mounted read-only into a no-egress official Arch Linux / private Weston browser test. The source-declared allowed-symbol list was independently fetched from successful [original Rust-source Ubuntu/Arch 49/49 host ABI CI **41358205206**](https://github.com/sguzman/vulpra/actions/runs/41358205206), tied to its exact authenticated Git commit. The user installation, profile, physical USB keys, hidraw devices and host audio devices were never accessed.

The bounded `ci/m3-original-libudev-dlopen-callsite.c` diagnostic now also intercepts **`dlsym`** using the real glibc versioned entry point, while retaining the previously accepted original `libxul.so`-origin **`dlopen`** callsite and bounded unwind diagnostics. Its optional `VULPRA_M3_LIBUDEV_DLSYM_TRACE` activation records only source-style `udev_` names requested by the actual original `libxul.so` ELF, their ASLR-normalized caller return PCs, the successful or failed lookup outcome, and the **`dladdr`-identified actual mapped provider basename of the returned function pointer**. It does **not** substitute a guessed provider, force a new library load or invoke arbitrary `udev` functions. The existing WebAuthn no-device registration still ends in the expected **`NotAllowedError`**, and the original verified machine `dlopen` sites still show **`0x9936652` RTLD_NOLOAD miss** and **`0x9936667` normal load hit**.

## Actual same-browser-process native symbol-resolution evidence

| Original observed result | Accepted native value |
| --- | ---: |
| Unique `udev_*` names resolved from original `libxul.so` | **13** |
| Successful native `dlsym` calls observed | **13** |
| Failed native `dlsym` calls observed | **0** |
| Unique native returned-pointer provider basenames | **1 — `libudev.so.1`** |
| Source-defined possible FFI symbol names | **49** |
| Original browser PIDs with both source-matched loader events and at least one successful actual provider resolution | **At least 1; identities not exported** |
| Actual physical security key sessions | **0** |

All **13** distinct source-declared symbols that the instrumented original browser resolved during this no-device USB backend request:

`udev_new`, `udev_unref`, `udev_enumerate_new`, `udev_enumerate_unref`, `udev_enumerate_add_match_subsystem`, `udev_enumerate_scan_devices`, `udev_enumerate_get_list_entry`, `udev_monitor_new_from_netlink`, `udev_monitor_filter_add_match_subsystem_devtype`, `udev_monitor_enable_receiving`, `udev_monitor_get_fd`, `udev_monitor_receive_device`, `udev_monitor_unref`.

The interposed `dlsym` returns point to **`libudev.so.1`** according to actual `dladdr`, while the earlier **uninterposed original browser `/proc/maps` snapshot** ([41674689904](https://github.com/sguzman/vulpra/actions/runs/41674689904)) recorded the versioned file **`libudev.so.1.7.15`** as newly mapped during the USB test. These are **separately observed forms** of the dynamic provider name from separate runs; no assertion is made that they prove identical pointer identity or exact loader reference counts across runs. The 13 original `libxul.so`-normalized `dlsym` return PCs are archived in the public safe JSON, without any raw runtime PID or path.

The original-source list is matched **per observed name** by the independent fail-closed `ci/m3-original-browser-libudev-dlsym-provider.jq`. The new standalone `ci/m3-original-browser-libudev-dlsym-verify.sh` runs in the existing **unprivileged** WebDriver test process, after the browser's original negative-result JSON is written and before private `/tmp` cleanup. It confirms the **same original process ID** produced both exact native `dlopen` miss/hit records and a successful `dlsym` provider resolution; only this aggregate boolean is archived, never that process ID. It rejected **four mutations** of the original data: undeclared `udev_` symbol, wrong actual pointer-provider library, unmatched process identifier, and invalid compiled native loader-callsite witness. The accepted archive contains only two sanitized JSON reports. The expensive original-browser workflow was restored to **manual-only `workflow_dispatch`**.

## Iteration diagnostics and strict interpretation

The initial experimental workflow had a nested-shell quoting error (not accepted); the next post-run verifier was unreachable after the intentional `exec setpriv` privilege drop (not accepted), so the check moved into the already-unprivileged browser runner rather than retaining a privileged parent. A later adversarial test exposed an erroneous source-membership scope in jq (fixed to use each observed symbol, not the source list as its own lookup). A subsequent run reached a browser WebAuthn pending state too close to the page's 10-second timeout; only the **opt-in instrumented** mode's bounded polling window was extended. **CI 41682006070** passed the native test, sanitizer, source allowlist, four adversarial checks, and complete artifact upload after those corrections. Earlier invalid attempts receive no milestone credit.

**Critical limits:** `LD_PRELOAD` interposes `dlsym` and `dlopen`, therefore this is **instrumented actual-browser execution**, not an untouched / production `dlsym` trace. It does not establish that **all 49 source-declared functions** were resolved or called by the original browser, that all 13 resolved functions were actually called, precise ABI function signatures or symbol versions, or a complete uninterrupted uninstrumented Rust→C FFI call chain. It does not verify a real physical security key, target EndeavourOS/Hyprland GPU hardware, any other browser feature or complete source/build/feature/transitive dependency closure across the original 28 compiled ELFs.

**No source or packaged binaries were deleted, no byte savings were claimed, and the sixth M3 acceptance gate remains open. Overall 61%; M3 5/6 gates = 83%; session Δ +0 percentage points.**
