# M3 — Original Vulpra WebAuthn USB native library activation (2026-11-03)

## Source-pinned real-browser result

**[Native CI 41674689904 — PASS](https://github.com/sguzman/vulpra/actions/runs/41674689904)**, job **126052050153**, artifact **13248739521** (`m3-original-browser-usb-nodevice-loader`). [Workflow lint 41674689835 — PASS](https://github.com/sguzman/vulpra/actions/runs/41674689835).

The original packaged browser was authenticated at source SHA **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**, original archive SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**, and executed in an official disposable Arch userspace with private Weston, loopback-only WebDriver/origin and a disconnected network namespace. The real original browser had USB WebAuthn enabled and software-token WebAuthn disabled. Its actual clicked `navigator.credentials.create` request produced **`NotAllowedError`** as expected without any physical USB security key, hidraw device or network egress. This is a negative hardware-path test, **not** successful authenticator use.

The shared bounded Rust browser observer `ci/m3-original-browser-on-demand-maps.rs` now captures **three opt-in phases**, without altering the normal browser or its WebDriver configuration: `usb-before` immediately before the click, `usb-during` when the existing browser test sees a libudev mapping while the request is running, and `usb-after` following the negative result. Only executable processes resolved under `/original` are sampled. The independent validator `ci/m3-original-webauthn-usb-maps-crosswalk.jq` checks their authenticated original-source identity, exact phase names, original browser core ELF mappings, no-device test evidence, actual versioned mapped `libudev.so.1` backing filename and nonclosure flags. Raw PIDs, paths, credentials and key material remain confined to the disposable process, never uploaded.

| Native measurement | Before click | During USB request | After `NotAllowedError` |
| --- | ---: | ---: | ---: |
| Original browser processes | **10** | **10** | **11** |
| Original packaged mapped shared libraries | **18** | **18** | **18** |
| Host mapped shared libraries | **82** | **83** | **83** |
| Mapped backing ELF `libudev.so.1.7.15` | **No** | **Yes** | **Yes** |
| Unreadable original-browser maps | **0** | **0** | **0** |

The actual newly observed mapped host shared-library basename across `usb-before` → `usb-during` was **only `libudev.so.1.7.15`**. No original-package shared library basename was added or removed; `libudev` stayed mapped after the no-device result. The loader's `libudev.so.1` SONAME is different from the fully versioned backing ELF path seen in `/proc/maps`. The original feature test's earlier boolean observation is thus now reconciled against a concrete ELF filename and the request stage rather than being mistaken for a complete dynamic-load call graph.

The accepted native test also **rejected four adversarial mutations**: deleting the *actual versioned* libudev mapping from the during-phase report, changing the archive SHA, adding a duplicated original-package library basename, and contradicting the pre-click udev-mapped flag. Rust unit tests passed with warnings denied. The five uploaded JSON files comprise the original USB no-device status, three phase map reports, and the independent phase crosswalk. After acceptance the expensive workflow was restored to manual-only `workflow_dispatch`.

## Limits and remaining M3 gate

Three sampled process-map unions cannot prove the precise first `dlopen` instruction, a particular `libxul`/Rust/C++/FFI caller or symbol version, intermediate transient mappings, full session/reference-count lifetime, actual physical key interoperability or all browser-feature paths. This one no-egress Arch/Weston workload is neither target EndeavourOS/Hyprland hardware validation nor complete original 28-ELF feature/build/binary dependency closure. It does not authorize source or ELF deletion.

**No new source pruning, package library removal or size savings. M3 = 5/6 gates (83%); overall = 61%; session Δ +0 percentage points.** The sixth feature/binary/build/dynamic-dependency closure gate is still open.
