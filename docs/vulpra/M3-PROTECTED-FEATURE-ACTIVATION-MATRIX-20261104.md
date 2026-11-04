# M3 — Protected-feature activation and fallback acceptance matrix (2026-11-04 UTC)

## Why this exists

The project has credible native build, loader and narrowly scoped browser-test evidence, but the final M3 dependency/safety gate still needs a **finite, explicit feature-by-feature activation and fallback matrix**. The [read-only machine ledger](M3-PROTECTED-FEATURE-ACTIVATION-MATRIX-20261104.json) enumerates **18 retained browser/security/media/account features**, with explicit source-bounded proof categories and a next negative/error-path check for each. It does **not** itself execute a browser or authorize feature removal.

The current normal source-built browser is **`96454f7a1fbe6b505af440c6c2c5fc91e798756d`**, authenticated by [native CI 41762298450 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41762298450). The historical original browser's immutable compiled source is **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**. These are **not the same binaries**. The ledger intentionally preserves that distinction.

### Three strictly different evidence types

| Class | Bounded currently recorded coverage | Interpretation |
| --- | ---: | --- |
| Selected **current source-matched compiled browser runtime** | **4/18** | Private offline Weston Wayland frame, localhost JavaScript/302/final DOM, temporary unsigned WebExtension lifecycle, Nimbus API/store initialized in actual current package |
| **Historical original** or separately instrumented native diagnostic | **9/18** | Original lean New Tab fallback, real crashreporter trigger, read-only updater diagnostic, instrumented pingsender/libcurl refusal, FFmpeg host ABI, ClearKey interface, original WebAudio, WebAuthn no-key rejection, ONNX module diagnostic; these **do not prove** current normal feature behavior |
| **Bounded negative or fallback witness**, from either build | **3/18** | Current temporary WebExtension uninstall stays inactive; historical optional New Tab omission fallback; original no-key WebAuthn rejection. Not a complete failure/error-path matrix |

Seven explicitly generated normal current configuration substitutions are independently distinguished from feature runtime execution: `MOZ_WAYLAND=1`, `MOZ_NORMANDY=1`, `MOZ_SANDBOX=1`, `MOZ_SERVICES_SYNC=1`, `MOZ_DEVTOOLS=all`, `MOZ_CRASHREPORTER=1`, and `MOZ_UPDATER=1`. Configuration values alone do not prove corresponding protected runtime behavior, sandbox enforcement, policy updates, account services, browser media or ABI safety. The normal browser also retains other security and privacy requirements, including certificate validation/Safe Browsing, not yet verified as complete current-package behavioral tests.

### Evidence references for selected sensitive paths

- The actual current browser's [native CI 41762298450](https://github.com/sguzman/vulpra/actions/runs/41762298450) verified isolated Wayland rendering, loopback JavaScript/navigation, unsigned WebExtension install/content/background/storage/uninstall, Nimbus readiness and profile isolation; ordinary online Weston background egress and GPU hardware are outside this test.
- The original guarded New Tab opt-out's [combined runtime 41233793696](https://github.com/sguzman/vulpra/actions/runs/41233793696) exercised fallback with optional promo/AdsFeed modules omitted, not the current normal browser's comprehensive fallback behavior.
- The original private browser [WebAudio 41714793962](https://github.com/sguzman/vulpra/actions/runs/41714793962) and [USB WebAuthn 41674689904](https://github.com/sguzman/vulpra/actions/runs/41674689904) measured bounded playback/provider and no-device rejection respectively; they are historical evidence, not current-user device acceptance.
- The original protected [crashreporter 41724548163](https://github.com/sguzman/vulpra/actions/runs/41724548163), [read-only updater diagnostic 41161508642](https://github.com/sguzman/vulpra/actions/runs/41161508642), [browser-owned libcurl refusal 41741770814](https://github.com/sguzman/vulpra/actions/runs/41741770814), [FFmpeg host ABI 41266875131](https://github.com/sguzman/vulpra/actions/runs/41266875131), [ClearKey interface 41161025114](https://github.com/sguzman/vulpra/actions/runs/41161025114), and [ONNX module lifecycle 41567402153](https://github.com/sguzman/vulpra/actions/runs/41567402153) are **specific diagnostics**, never ordinary production update, upload, DRM decrypt or full inference proofs.

## Testable acceptance contract

The read-only [`ci/m3-protected-feature-activation-matrix.jq`](../../ci/m3-protected-feature-activation-matrix.jq) enforces the **exact 18 protected feature IDs**, authenticated *recorded* source and run identities, seven observed flag values, exact allowed current/historical/fallback witness classifications, explicit remaining checks and every required false/undecided claim. Its [Bash mutation fixtures](../../ci/tests/m3-protected-feature-activation-matrix-tests.sh) exercise **28 deliberately fabricated** stronger source/feature/ABI/workstation/pruning assertions. The lightweight [workflow](../../.github/workflows/m3-protected-feature-activation-matrix.yml) runs these without a browser rebuild.

This contract checks **internal ledger consistency with the previously accepted report IDs**, not GitHub API authenticity of those reports, new user hardware or new binary behavior. Future evidence updates must separately authenticate the referenced source-pinned workflow/artifact, inspect actual runtime results, then deliberately update the allowlist, ledger, documentation and tests together. A failed or untested feature must not be silently accepted through a changed label.

## Prioritized next runtime acceptance work

1. **Security error paths on the new normal package:** verify sandbox child denial and certificate/Safe Browsing negative cases without lowering protection. Keep real account credentials, real malware destinations and live telemetry out of tests.
2. **Conditional native media and hardware fallbacks:** current browser WebAuthn no-key/permission failure and audio/FFmpeg provider missing or alternate-version behavior; preserve device support and DRM functionality without claiming the absence of a hardware device makes the source unneeded.
3. **Protected lifecycle paths:** current native crashreporter/helper and signed updater failure/authenticity, Sync/FxAccounts local offline error, disabled/failed policy and Glean consent handling, plus browser-side real inference/DRM activation where appropriate.
4. **Real current-workstation ABI/Wayland parity:** tested only on a separate Vulpra profile and binary under EndeavourOS/Hyprland, keeping the installed Firefox Developer Edition and its profiles untouched; the historic M2 workstation success is not a test of this new current-source binary.

No source deletion, newly measured native savings, complete conditional `dlopen`/FFI graph or sixth-gate closure. **Overall 61%, M3 5/6=83%, Δ+0 percentage points.**

## Accepted CI validation (2026-11-04 UTC)

[**Lightweight contract run 41842786384 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41842786384) executed the exact checked-in jq verifier and shell fixtures from `main`, reporting **18 protected feature records; four current normal-browser runtime witnesses, nine historical or diagnostic witnesses, three strictly bounded negative/fallback witnesses, and 28/28 deliberate forged claims rejected**. [Full workflow lint 41842786096 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41842786096). The acceptance fixture checks that all **14** current unverified runtime cases and **15** unverified negative/fallback cases remain explicitly open; an editable next-check description cannot itself turn a missing proof into a pass.

**Scope:** this is genuine executed CI of the *acceptance contract*, not another browser build, a new runtime test, independent verification of every historical GitHub run, or workstation QA. The broad M3 sixth gate remains open, with current source compile and protected normal-build smoke evidence handled by prior successful native CI. No removals or measured marginal native savings; **overall 61%, M3 83% (5/6), Δ+0 pp**.
