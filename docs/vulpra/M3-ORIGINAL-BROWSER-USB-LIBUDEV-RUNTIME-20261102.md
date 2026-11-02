# M3 original browser: WebAuthn USB backend triggers a new `libudev.so.1` runtime mapping

- Date: **2026-11-02 UTC**
- Status: **bounded original-browser runtime loader observation VERIFIED**; broader USB hardware and dynamic dependency closure **NOT accepted**
- Scope: disposable original `b1482404` browser, no USB device passthrough, no network egress or installed user browser
- Progress: **Vulpra overall 61%; M3 5/6 = 83%; Δ+0 percentage points**. No code pruned, no savings.

## Exact original `libxul.so` caller return PCs and `dlopen("libudev.so.1")` flags (2026-11-02 UTC)

[**CI 41374201977 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41374201977), [lint 41374201953 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41374201953). **Artifact 13110232821 independently downloaded and JSON inspected** (`m3-original-browser-libudev-dlopen-callsite.json`). The diagnostic builds tiny `ci/m3-original-libudev-dlopen-callsite.c` with strict GCC flags and injects it **only into a disposable original-browser CI namespace** via `LD_PRELOAD` to interpose the `dlopen` entrypoint. It forwards to the real `dlopen` via `dlsym(RTLD_NEXT, "dlopen")` and filters strictly to requests named `libudev.so.1` from an address inside `libxul.so`, using `dladdr` to normalize the caller return address against the original ELF's load base. Raw per-process trace lines (with transient PIDs) are validated inside the container but **never uploaded**. This is **instrumented tracing, not byte-for-byte ordinary runtime symbol binding**.

The source-pinned original browser's **real user-click WebAuthn USB-backend registration request**, with USB pref `true`, softtoken pref `false`, no WebDriver virtual authenticator and no device passed through, made both exact source-matched calls. The CI fail-closed verifier requires the two observations to be from **the same original browser process**:

| Original `libxul.so` machine instruction | Observed ASLR-normalized return PC | Actual loader flags | Result |
| --- | --- | --- | --- |
| `0x993664f` — `call *%r14` | `0x9936652` | `0x105` = `RTLD_LAZY \| RTLD_GLOBAL \| RTLD_NOLOAD` | **miss** |
| `0x9936664` — `call *%r14` | `0x9936667` | `0x101` = `RTLD_LAZY \| RTLD_GLOBAL` | **hit** |

These return PCs reconcile with the **previously independently authenticated original packaged** 189,486,696-byte stripped `libxul.so` native machine audit [41357321586 PASS](https://github.com/sguzman/vulpra/actions/runs/41357321586), source ownership `dom/webauthn/libudev-sys/src/lib.rs`, `dlopen` GOT slot `0xb3c33c8`, and the original Rust `ifnull!` fallback logic. They do **not** count as new distinct library-loading branches beyond the already recorded two machine calls. This makes the requested **SONAME `libudev.so.1`**, **two exact loader callsites**, **loader flags**, and **miss/success result** empirically attributable in the isolated instrumented original-browser USB workload.

The archived JSON also verifies **`libudev_mapped_before_attempt=false`** and **`libudev_mapped_during_or_after_attempt=true`**; an **independent uninstrumented control** already saw the same mapping transition in [41371647131 PASS](https://github.com/sguzman/vulpra/actions/runs/41371647131). The tracer therefore does **not** serve as the only evidence the browser loads libudev.

### Strict non-claims

- **No complete original-browser call stack** was captured. The interposer captures a **single direct caller return PC**, not a backtrace; archived `actual_original_dlopen_call_stack_observed=false` is correct.
- `LD_PRELOAD` intentionally **changes dynamic symbol resolution** for this experiment. Although the uninstrumented control exhibits the same mapping transition, these exact traced calls/flags were observed **with instrumentation**; do not generalize all callsites' behavior to an unmodified loader without qualification.
- No physical key/device was passed through, `NotAllowedError` without a key is expected, and **no hardware USB/CTAP authentication was performed**.
- No complete direct/indirect dynamic loader graph, cross-build conditional feature/FFI closure, actual user EndeavourOS/Hyprland ABI, or source-pruning authority follows from this one successfully verified path.

`ci/m3-original-browser-webauthn-webdriver.sh` has an explicit **`usb-dlopen-trace` mode** and requires source-pinned return PCs `0x9936652`/`0x9936667` with flags/outcomes `0x105 miss` then `0x101 hit` for at least one original-browser PID; the instrumented report retains `source_pruning_authorized=false`, `whole_dynamic_loader_graph_proven=false`, `physical_security_key_authentication_verified=false`, `m3_sixth_gate_closed=false`. All probes remain **manual-dispatch only** after the successful evidence capture, never routine build gates.

**Progress remains overall 61%; M3 5/6 = 83%; Δ+0 percentage points, no source removed and no measured byte savings.**

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
