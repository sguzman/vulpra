# M3 — Original packaged ONNX Runtime internal dlopen origin under isolated API activation (2026-11-02)

## Verified original native runtime result

[**Original ONNX internal-loader CI 41524996253 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41524996253) produced **artifact 13178887819**, independently downloaded and inspected. Its bounded `m3-onnx-inner-dlopen-bounded.json` identifies original immutable compiled Vulpra source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and checksum-authenticated full-normal browser archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

This test uses the **real original compiled `libonnxruntime.so` from that package**, the existing dependency-free Rust `OrtGetApiBase` public C API probe, and a new CI-only optional `dlopen` interception library. Both the ordinary control and instrumented run succeeded inside isolated `unshare --net` Linux namespaces. No model, inference task, browser ML frontend, user data, external network, GPU or user profile was accessed.

| Observation in real source-pinned ONNX API-base workload | Exact result |
| --- | ---: |
| Original `OrtGetApiBase` and version API succeed without diagnostic interception | **Yes** |
| Same original `OrtGetApiBase` and version API succeed with interception | **Yes** |
| External Rust probe's `dlopen` of original ONNX library | **1 other-origin call** |
| Calls to `dlopen` *originating within original `libonnxruntime.so`* | **0** |
| ONNX-origin successful/failed calls | **0 / 0** |
| Internal compiled direct `dlopen` branch exercised by this API-base workload | **Not observed** |

The native verifier `ci/m3-original-onnx-inner-dlopen-observe.c` intercepts the C symbol `dlopen` and attributes calls to an exact `libonnxruntime.so` module origin from the **immediate caller return PC**, using `dladdr`. It retains only anonymous aggregate counts. It never uploads raw return addresses, process IDs, library path strings or loader arguments. In a **real compiled C shared-library fixture**, a synthetic library named `libonnxruntime.so` intentionally called `dlopen("libm.so.6")`: **one ONNX-origin call was detected and successful**. With identical test code in `libnotonnx.so`, **zero ONNX-origin calls** were detected. These positive and negative fixtures prove the instrumentation distinguishes a library-originating call from the harness's outer library load. They do **not** make the fake fixture part of the original Firefox browser.

The previous [**original feature-only binary loader audit 41523391875**](https://github.com/sguzman/vulpra/actions/runs/41523391875) established **one compiled named direct `dlopen` machine call in `libonnxruntime.so`**. The new separate, genuine original-native C API-base experiment establishes that this limited startup/API path **did not reach the module-origin call**, rather than mistaking the outer `dlopen` for execution of ONNX's compiled branch. This **does not** establish that the branch cannot execute when a model, execution provider, inference session, dynamic runtime plugin or other ONNX feature is activated.

## CI safety and acceptance

The first [workflow lint 41524996550](https://github.com/sguzman/vulpra/actions/runs/41524996550) **failed** on two shellcheck `sudo` plus stdout-redirection warnings, not on native code or original package execution. Commit `df935301` replaced them with explicit pipelines and changed the expensive original-package workflow to **manual dispatch only** after its successful native run. [**Corrected workflow lint 41525335916 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41525335916).

This diagnostic explicitly uses **`LD_PRELOAD`**, which changes native symbol resolution. The ordinary non-interposed control confirms the same public C API still works without the shim; it does not verify an uninstrumented internal call stack or exact machine-instruction origin. A caller-module basename alone does not associate an intercepted call with one particular compiler callsite if more than one call instruction exists. The observer cannot prove all future runtime loader paths, fallback branches, ABI availability on the real workstation, or a safe deletion.

**Next engineering target:** Activate a specific source-pinned ONNX execution-provider or session operation in a disposable, no-egress environment with an appropriately validated minimal fixture, then independently distinguish module-internal conditional loading from the harness loading the module. Avoid suggesting a full model or GPU feature was tested just because the C API base returned a version string.

No new native browser was compiled; no source was pruned and no package size savings were claimed. **M3 sixth gate OPEN (5/6 = 83%), Vulpra overall 61%, session Δ +0 percentage points.**
