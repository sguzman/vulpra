# M3 original compiled browser: isolated WebAuthn virtual-authenticator integration checkpoint

- Date: 2026-11-02 UTC.
- Issue: [#4 — Original browser WebAuthn virtual authenticator returns `NotAllowedError` in isolated CI](https://github.com/sguzman/vulpra/issues/4).
- **Current status: original-browser virtual-authenticator create/get ACCEPTED; prior `NotAllowedError` blocker resolved by matching upstream attachment selection.** Earlier failures below are historical diagnostic evidence, not current failures. The result does **not** establish physical USB/libudev runtime execution, full loader closure or source-pruning authority.
- Overall Vulpra: **61%**, M3: **5/6 = 83%**, session delta **+0 percentage points**; no new source removals or measured package bytes.

## Verified resolution: original-browser WebAuthn credential round trip (2026-11-02 UTC)

[**CI 41370020422 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41370020422), [workflow lint 41370020375 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41370020375). **Artifact 13109166364 independently downloaded and JSON inspected** (`m3-original-browser-webauthn-virtual.json`). The earlier test configuration combined a registered **`internal` virtual CTAP2 authenticator** with `authenticatorAttachment:"platform"`. Comparing the **exact original Firefox test helper** `dom/webauthn/tests/browser/head.js` at immutable source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7` revealed that upstream uses **`authenticatorAttachment:"cross-platform"`** for credential creation even while its virtual authenticator is registered as **`internal`**. Switching only the isolated Rust-served QA page's WebAuthn selection to `cross-platform` (with `residentKey:"discouraged"`) fixed the observed `NotAllowedError`. **The original Vulpra package, source, and user browser remain unchanged.**

The successful workflow still SHA-authenticates the original source/native archive, executes the actual packaged original `vulpra` browser under a disposable Arch private-Weston graphical process, establishes a real localhost-only WebDriver session, inspects Gecko's actual virtual-authenticator registry, and issues a genuine WebDriver click that triggers `navigator.credentials.create`. It confirms the generated credential is stored in the virtual authenticator via WebDriver's credential-list endpoint; then a second click triggers `navigator.credentials.get` and validates non-empty authenticator data and signature. These are **actual browser WebAuthn JavaScript results**, not a standalone `libudev-sys` Rust test or faked JavaScript success.

| Source-pinned archived result | Verified value |
| --- | --- |
| `original_native_browser_executed`, `localhost_secure_origin` | `true`, `true` |
| `actual_browser_navigator_credentials_create_succeeded` | `true` |
| `actual_browser_navigator_credentials_get_succeeded` | `true` |
| `virtual_ctap2_internal_authenticator_used`, `virtual_credential_is_ephemeral` | `true`, `true` |
| `original_browser_libudev_mapped_at_end` | **`false`** |
| `original_browser_dynamic_libudev_load_proven`, `actual_physical_usb_webauthn_path_verified` | `false`, `false` |
| `no_network_egress`, `real_user_profile_or_browser_accessed` | `true`, `false` |
| `full_dynamic_loader_graph_proven`, `source_pruning_authorized`, `m3_sixth_gate_closed` | `false`, `false`, `false` |

**Limit:** the virtual `internal` software authenticator is not a hardware USB/FIDO device. `libudev.so.1` was **not present in the observed browser process mappings at the end of this workload**. This does not prove it was never transiently loaded, and it does not exercise the actual USB authenticator/libudev branch. The separate source-pinned Ubuntu/Arch `libudev` ABI/first-use checks remain valid, but cannot stand in for actual original-browser USB use. **M3 sixth gate stays open; no new deletion or package-byte savings.**

The expensive browser regression remains available through manual `workflow_dispatch`; its earlier temporary push trigger was removed after the passing run. Issue [#4](https://github.com/sguzman/vulpra/issues/4) records the resolution and is suitable for closure as a **virtual-authenticator-only** blocker.

## Immutable native provenance

The existing source-pinned full-normal native archive from successful Actions run **40997075527** is checked before testing:

- Original source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`.
- Original archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.
- **Actual packaged `vulpra`** starts; no system Firefox, user profile or installed browser binary is substituted.
- Original WebAuthn test source `dom/webauthn/tests/test_webauthn_webdriver_virtual_authenticator.html` and `tests/browser/browser.toml` are fetched from the same original source commit.
- New disposable test files: `ci/m3-original-browser-webauthn-local-origin.rs` (Rust static loopback server), `ci/m3-original-browser-webauthn-webdriver.sh` (bounded WebDriver smoke) and `.github/workflows/m3-original-browser-webauthn-offline.yml`.

## Actual browser evidence established

After addressing test-environment startup constraints, the test runs the **actual original browser** under a private Weston/pixman Wayland compositor on a disposable Arch Linux userspace, creates a real geckodriver/Marionette WebDriver session, and navigates to an isolated `http://localhost:18888/` origin. Browser JavaScript observes `isSecureContext=true`, with `navigator.credentials.create` and `navigator.credentials.get` exposed.

The W3C WebDriver virtual CTAP2 authenticator API accepts an *internal* test authenticator, and a **Chrome-context inspection of the original browser's actual `nsIWebAuthnService.hasVirtualAuthenticator(id)` returns true**. Thus the registered test device is real inside the browser's virtual-authenticator database, not just an HTTP endpoint accepting a request.

In the **historical, misconfigured** runs, both direct async JavaScript and genuine WebDriver user-click requests to `navigator.credentials.create` returned **`NotAllowedError`**. This was seen using the original test's internal virtual-authenticator/softtoken preference configuration. **No credential creation, virtual credential storage, or credential assertion has been established.** Do not classify this as a successful WebAuthn feature test, nor infer a product regression on normal user hosts.

## Diagnostic progression and strict exclusions

| Real CI run | Observation |
| --- | --- |
| [41367447736](https://github.com/sguzman/vulpra/actions/runs/41367447736), [41367578426](https://github.com/sguzman/vulpra/actions/runs/41367578426) | Container setup privilege handoff failed; corrected by transient setup-only capabilities, then unprivileged browser with asserted zero effective/permitted capabilities |
| [41367870914](https://github.com/sguzman/vulpra/actions/runs/41367870914) | Initial bare headless rendering/Marionette startup failure; moved to already proven private Weston |
| [41368049303](https://github.com/sguzman/vulpra/actions/runs/41368049303) | Browser shutdown during startup; corrected by source-compatible test-only `XRE_START_OFFLINE=1` guard |
| [41368235721](https://github.com/sguzman/vulpra/actions/runs/41368235721) | Browser tab subprocess/sandbox threads exhausted with container PID ceiling 128; increased to bounded 512 threads and 4 GiB |
| [41368364375](https://github.com/sguzman/vulpra/actions/runs/41368364375) | First actual WebDriver browser/localhost/virtual-authenticator path reached; create returns `NotAllowedError` |
| [41368580234](https://github.com/sguzman/vulpra/actions/runs/41368580234), [41368809411](https://github.com/sguzman/vulpra/actions/runs/41368809411) | Aligned internal test authenticator with original source prefs; used WebDriver button activation; create still returns `NotAllowedError` |
| [41369031033](https://github.com/sguzman/vulpra/actions/runs/41369031033), [41369170245](https://github.com/sguzman/vulpra/actions/runs/41369170245) | Privileged Marionette registry lookup requires `MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1` only in the disposable test browser |
| [41369295456](https://github.com/sguzman/vulpra/actions/runs/41369295456) | The original Gecko virtual-authenticator service *does* contain the registered device, but browser create still fails `NotAllowedError` |

**Security:** All of these were GitHub Actions CI workloads, not the user's machine. Docker ran `--network none`, enabling only a local loopback socket for geckodriver and the disposable Rust HTTP origin. The original browser and driver run as an unprivileged user with the test asserting **zero effective and permitted capabilities**. The only Chrome privileged remote access is confined to `MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1` inside this no-egress ephemeral test; no user profile, key, actual USB device, external origin, persistent browser setting, or source sandbox policy was accessed or changed. The original `XRE_START_OFFLINE` browser guard remains **test-only**.

## Forward engineering acceptance

The isolated test remains available by **manual `workflow_dispatch` only** as an expensive passing regression, rather than a routine push CI job. Issue #4's original virtual-device rejection is resolved as described above. The next dependency-closure target is genuine, physically grounded USB/libudev loading and ABI coverage without modifying the user's installed browser. Only accept a browser-level WebAuthn gate if the original native browser creates a credential, the browser's virtual authenticator owns it, and `navigator.credentials.get` produces a real assertion. Even that still would not prove physical USB security-key discovery or dynamic `libudev.so.1` loading by the original packaged browser.

**Not achieved:** any source pruning, all-ELF build/source/FFI/loader dependency closure, actual runtime WebAuthn USB/libudev behavior, real EndeavourOS/Hyprland host verification, or the sixth M3 acceptance gate. Previous isolated original Rust `udev_new`/symbol compatibility evidence remains valid independently, but cannot substitute for this browser feature integration.
