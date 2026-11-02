# M3 — Original packaged ONNX Runtime internal dlopen origin under isolated API activation (2026-11-02)

## Exact ONNX CPU output numerical correctness (2026-11-02)

**[Updated original source-pinned native CI 41528669862 — PASS](https://github.com/sguzman/vulpra/actions/runs/41528669862)** and **[workflow lint 41528669790 — PASS](https://github.com/sguzman/vulpra/actions/runs/41528669790)**. The sanitized original-native artifact **13180313981**, `m3-original-onnx-cpu-constant-session.json`, was **downloaded and independently inspected**; it authenticates the compiled full-normal original package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` and exact source Git `b1482404dfb8b01342990ee99ea3df0f9756b5f7`.

This strengthens the previous non-null-output-only result. The same generated in-memory `Constant` graph ran on the original compiled `libonnxruntime.so` in **both** ordinary and CI-interposed isolated no-egress modes, successfully calling `CreateSessionFromArray` then `Run`. A new narrowly scoped Rust C API reader now checks **`IsTensor==1`**, then `GetTensorTypeAndShape`, **float32 element type**, **rank 1**, **dimensions `[1]`**, **one element**, and `GetTensorMutableData`. It reads **exactly one validated float32** and compares its bits against the configured constant **1.25f32 / `0x3fa00000`**. Any unexpected type, rank, shape, null pointer, nonfinite or unequal value fails closed.

To avoid guessing the expanded native ONNX `OrtApi` function-table layout, CI fetched the upstream **MIT-licensed ONNX Runtime v1.22.0 C header pinned to Git blob `b01b7e48dc87bbeeb026c61fb06c591053853ad1`** and compiled seven C `offsetof(OrtApi,...)` static assertions against the exact Rust indexes for `IsTensor`, `GetTensorMutableData`, `GetTensorElementType`, `GetDimensionsCount`, `GetDimensions`, `GetTensorShapeElementCount`, and `GetTensorTypeAndShape`. Header Git hash, Rust unit tests, original package integrity and both native executions all passed.

| Checked scope | Outcome |
| --- | --- |
| Original CPU in-memory ONNX `Constant` inference | **PASS** |
| Original output `OrtValue` type | **Tensor** |
| Output tensor type and shape | **float32 `[1]`**, 1 element |
| Read actual output value, compare exact IEEE-754 bits | **1.25 = `0x3fa00000`, PASS** |
| Non-interposed and optional `LD_PRELOAD` runs | **Both PASS** |
| ONNX-library-origin internal `dlopen` calls in this CPU run | **0** |
| External probe-origin `dlopen` calls | **1** |

**Limits unchanged:** This verifies the one chosen CPU `Constant` graph and the displayed float32 output; it does not prove general ML model numerical accuracy, GPU or alternative execution-provider registration, an original browser ML frontend, every conditional future load, exact uninstrumented stacks, user EndeavourOS/Hyprland device behavior, code removals, or new savings. The `LD_PRELOAD` observation is explicitly instrumented. The new full-native replay ran **once** for this improved acceptance check; its workflow is restored to **manual-only** after successful evidence capture.

**M3 remains 5/6 (83%) and overall Vulpra 61%, Δ +0 percentage points.**

## Real in-memory ONNX CPU inference session verified (2026-11-02)

[**Original source-pinned native CPU inference CI 41526796993 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41526796993) and [**workflow lint 41526797290 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41526797290). The bounded report artifact **13180431757**, \`m3-original-onnx-cpu-constant-session.json\`, was independently downloaded and inspected. It attests the identical immutable **original compiled source \`b1482404dfb8b01342990ee99ea3df0f9756b5f7\`** and **full-normal archive SHA-256 \`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a\`**.

This advances beyond the preceding \`OrtGetApiBase\`/version-only test. A new std-only Rust fixture, \`ci/m3-original-onnx-constant-session.rs\`, builds **one small generated in-memory ONNX \`Constant\` operator graph** (tensor float32 \`[1]\`, configured constant \`1.25\`), using only bounded protobuf fields; it does not read, download or save any model. The probe loads the **actual packaged original \`libonnxruntime.so\`**, negotiates the stable public \`OrtApi\` v1 ABI prefix, creates an environment, disables ONNX telemetry, creates session options, **successfully calls \`CreateSessionFromArray\`**, and **successfully calls \`Run\` with no input tensors**, receiving a **nonnull output \`OrtValue\`**. The test itself does **not read or assert the numerical value** of that \`OrtValue\`: model construction, session creation, runtime execution and nonnull output are observed, not numerical-output correctness.

| Exact original CPU session observation | Native result |
| --- | --- |
| Real original compiled \`libonnxruntime.so\` + generated Constant graph, without observer | **Session created and \`Run\` succeeded** |
| Same native code and graph with diagnostic observer | **Session created and \`Run\` succeeded** |
| ONNX-origin intercepted \`dlopen\` calls during real CPU session and \`Run\` | **0** |
| Outer probe/other-origin intercepted \`dlopen\` calls | **1** |
| Execution of previously identified internal compiled ONNX \`dlopen\` branch | **Not observed** |
| External ONNX model, network or GPU provider activation | **None** |
| Browser ML frontend or actual target workstation exercised | **No** |

Both native experiments occurred in isolated Linux network namespaces; the optional \`LD_PRELOAD\` diagnostic was applied to **the probe process only**, not the timeout wrapper. The existing interceptor was independently tested using real compiled positive and negative ELF fixtures in [41524996253](https://github.com/sguzman/vulpra/actions/runs/41524996253). The one external probe-origin load was distinguished from zero internal calls; instrumentation changes symbol resolution and cannot certify uninstrumented module call stacks. **The previously observed ONNX internal loader branch may be associated with some optional execution provider, plugin, or other session feature that this constant CPU graph does not exercise.** A zero observation in this workload does not demonstrate that branch is dead or removable.

The new fixture's public-C-ABI prefix is based on the documented append-only \`OrtApi\` layout (see Microsoft's upstream ONNX Runtime header v1.22.0, original Git blob \`b01b7e48dc87bbeeb026c61fb06c591053853ad1\`); it accesses only the initial functions used here. This is a **one-shot disposable CI process** that leaves lifetime object reclamation to process exit rather than trying to guess release-function offsets beyond its partial ABI struct. No production browser code or runtime library bytes were modified.

After the successful expensive original-package replay the new workflow is **manual-only**. This result strengthens the feature-specific native runtime evidence; it **does not complete all optional provider, FFI, dynamic-loading, networking, graphical frontend, device or generated-build dependencies**. No original source removal, new package-size savings, security simplification or M3 sixth-gate credit is justified.

**M3 sixth gate OPEN (5/6 = 83%); overall Vulpra 61%; session Δ +0 percentage points.**

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
