# M3 original browser: WebAuthn USB backend triggers a new `libudev.so.1` runtime mapping

- Date: **2026-11-02 UTC**
- Status: **bounded original-browser runtime loader observation VERIFIED**; broader USB hardware and dynamic dependency closure **NOT accepted**
- Scope: disposable original `b1482404` browser, no USB device passthrough, no network egress or installed user browser
- Progress: **Vulpra overall 61%; M3 5/6 = 83%; Δ+0 percentage points**. No code pruned, no savings.

## Actual archived original-browser evidence

[**Source-pinned no-device USB backend CI 41371647131 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41371647131), [**workflow lint 41371647074 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41371647074). **Artifact 13109247679 downloaded and its original JSON file independently inspected** (`m3-original-browser-usb-nodevice-loader.json`). Preliminary [41371450487](https://github.com/sguzman/vulpra/actions/runs/41371450487) also passed and printed `libudev mapping observed=true`, but omitted its artifact due to a wrong upload path; the corrected second run fixes the path, requires the mapping to be `true`, and requires artifact upload rather than silently ignoring a missing file.

Immutable original provenance is the successful source-pinned compiled full-normal package from [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527), exact source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. CI checks both provenance and actual original package identity, and uses the **original packaged Vulpra binary**, not system Firefox or a substituted Rust-only harness.

The same exact original `dom/webauthn/authrs_bridge/src/lib.rs` source contains the **separate production USB branch**:
`if static_prefs::pref!("security.webauth.webauthn_enable_usbtoken")` calling `self.usb_token_manager.lock().unwrap().register(...)`. Its source comment explicitly distinguishes this production USB transport from virtual-device tests, where USB is disabled. The earlier [virtual CTAP2 create/get test 41370020422](https://github.com/sguzman/vulpra/actions/runs/41370020422) used `webauthn_enable_softtoken=true`, `webauthn_enable_usbtoken=false`, and reported no `libudev` mapping at its end; **that successful virtual-key test was not a USB-backend test**. The new probe uses the same exact source-matched, trustworthy `http://localhost:18888/` WebAuthn registration page but deliberately uses **USB enabled, software token disabled, and no virtual authenticator**.

| Archived original-browser observation | Independently inspected value |
| --- | --- |
| `original_native_browser_executed` | `true` |
| `real_browser_usbtoken_pref` / `real_browser_softtoken_pref` | `true` / `false` (real XPCOM preferences read through isolated browser Chrome context) |
| `real_original_web_authn_create_called_from_user_click` | `true` |
| `virtual_authenticator_registered` / `physical_usb_device_passthrough` | `false` / `false` |
| `libudev_mapped_before_attempt` | **`false`** |
| `libudev_mapped_during_or_after_attempt` | **`true`** |
| `credential_create_result` | Expected **`NotAllowedError`** without an attached authenticator |
| `actual_original_dlopen_call_stack_observed` | `false` |
| `original_browser_libudev_runtime_dependency_proven` | `false` in the source's stricter **call-stack/causal attribution** sense |
| `physical_security_key_authentication_verified` / `whole_dynamic_loader_graph_proven` / `m3_sixth_gate_closed` | `false` / `false` / `false` |

**What this proves:** during a real original packaged browser's WebAuthn USB-backend request, with no virtual authenticator or device attached, `libudev.so.1` goes from **not mapped in the observed original Vulpra processes** before the registration attempt to **mapped in those processes** during or after the request. This is an actual isolated runtime load/mapping observation, not just a static imported symbol, a source-only guess, or the prior standalone original Rust libudev library test. Authentic source strongly connects the workload to the original `usb_token_manager` branch.

**What it does not prove:** an exact `dlopen` PC/stack or unambiguous call-site attribution (the CI is deliberately not a full dynamic linker trace); absence of all transient pre-request loads outside sampling; successful enumeration of a physical security key, device access, CTAP exchange, cryptographic verification, actual end-user EndeavourOS/Hyprland behavior, or full direct+indirect ELF/SONAME/ABI dependency closure. A contemporaneous mapping and source path are useful runtime evidence but **not enough by themselves to delete the USB/libudev code or close the sixth M3 gate**. This remains a **protected conditional feature path**.

### Isolation and repeatability

The probe runs inside `archlinux:base` under private Weston/pixman; the original binary and provenance are authenticated from the immutable original archive. Docker has `--network none`, no physical `/dev/hidraw*` passthrough, read-only mounted browser, disposable user profile, and transient loopback setup privileges dropped to a **zero-capability unprivileged browser**. Test-only `MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1` enables precise XPCOM preference checks under a disconnected browser, not a change to its shipped defaults. No credentials or machine-specific process maps are exported; the sanitized artifact contains only the Boolean mapping observations and fail-closed metadata.

The original virtual WebAuthn workflow remains manual; the newly added USB no-device probe is returned to **manual `workflow_dispatch`** after its passing evidence is accepted. The next engineering acceptance target is physically grounded USB/CTAP behavior and exact loader provenance without assuming an end-user's security key or modifying an installed browser. Even a complete WebAuthn feature proof would still require the **other conditional native loader and source/build/FFI dependency paths** for M3 gate six.
