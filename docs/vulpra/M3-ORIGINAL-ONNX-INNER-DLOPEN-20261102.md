# M3 — Original packaged ONNX Runtime internal dlopen origin under isolated API activation (2026-11-02)

## Original ONNX Runtime 1.30 mixed external-provider/CPU inference — verified (2026-11-03 UTC)

**[Native CI 41565179887 — PASS](https://github.com/sguzman/vulpra/actions/runs/41565179887)**, job **125684867781**, artifact **13199070295**. The pinned original Firefox 159.0b5 native archive and SHA-1-pinned upstream ONNX C v30 headers were authenticated again. All **five** independent no-egress test modes passed on the real packaged `libonnxruntime.so` 1.30.0: default external factory registration, one genuine CPU `OrtEpDevice` enumeration, one-node CPU fallback, actual external-EP scalar `Mul` execution, and the new **mixed-provider dependent-node** execution.

The mixed test passes three separately named runtime tensors to one in-memory ONNX graph: `Mul(x,z)->mid` (external CI plugin) then `Add(mid,b)->y` (built-in ONNX CPU provider). With `float32[1]` inputs **x=1.25, z=1.25, b=2**, the plugin's `GetCapability` reports support **only** for the `Mul` node, explicitly declining `Add`; `Compile` and plugin `Compute` are observed, and the independently checked final output is exactly **3.5625**. The graph's additive contribution is independently supplied at runtime, so a skipped `Add` cannot produce the accepted result. ONNX Runtime is configured to disable graph optimizations. Only the CI external EP and built-in CPU provider are selected for the session.

Native trace markers observed in the successful mixed workload: `plugin_declined_add`, `plugin_claimed_mul`, `plugin_compile_mul`, `plugin_create_compute_state`, `plugin_compute_mul`, `mixed_native_cpu_numerical_result_3_5625`, `plugin_release_compute_state`, `plugin_release_compute_infos`, `release_ep`, `mixed_ep_cpu_model_pass`, and `unregistration_succeeded`. The previous `Identity` fallback result 1.25 and single-node external `Mul` result 1.5625 also passed again. All modes executed with temporary package paths and no network namespace egress. After verification, the expensive GitHub Actions workflow returned to **`workflow_dispatch` only**.

**Scope/limits:** This proves a bounded dataflow boundary and functioning inference between a test-only fixed-shape CPU `Mul` EP and the original CPU EP on one ONNX graph. It is **not** proof of Vulpra browser use of this plugin, GPU/accelerator support, a deployable EP, broader data types/operators, cross-device memory transfer, actual complete feature/FFI/ELF/`dlopen` dependency closure, source removal, or native package savings. **M3 5/6=83%; overall 61%; session Δ +0pp.**

## Original ONNX Runtime 1.30 external-EP model execution — verified (2026-11-03 UTC)

**[Source-pinned native CI 41563943117 — PASS](https://github.com/sguzman/vulpra/actions/runs/41563943117)** (job **125680812143**). The original full-normal source/pinned package SHA-256 and v30 public headers were authenticated again. A separate, CI-owned, CPU-only external provider was compiled with `-Wall -Wextra -Werror` and loaded by the **original packaged** `libonnxruntime.so` 1.30.0 in a no-egress Ubuntu 24.04 namespace. Four modes passed end to end: default zero-device factory registration/teardown; enumerated actual CPU `OrtEpDevice`; registered CPU session with builtin-CPU numerical fallback; and actual model execution **inside the external plugin**.

The new opt-in `VULPRA_CI_ONNX_EP_NATIVE_COMPUTE=1` mode appends the external EP through `SessionOptionsAppendExecutionProvider_V2`, constructs a dynamic ONNX `Mul(x, z)->y` model with **two distinct graph inputs** of `float32[1]`, disables graph optimizations, and supplies runtime values **1.25** and **1.25**. The CI plugin uses `OrtApi::Graph_GetNumNodes`, `Graph_GetNodes`, `Node_GetOperatorType`, `Node_GetDomain` to choose only a single `Mul` node. `OrtEpApi::EpGraphSupportInfo_AddNodesToFuse` claims it. The runtime invokes `OrtEp::Compile`, `OrtNodeComputeInfo::CreateState`, and **the actual plugin's** `OrtNodeComputeInfo::Compute`. The compute callback reads two CPU float32 scalar tensors, multiplies them, writes the output tensor, and returns the exact numerical result **1.5625**, which the separate probe independently validates. No CPU fallback is credited for this mode.

Native evidence markers observed: `plugin_claimed_mul` → `plugin_compile_mul` → `plugin_create_compute_state` → `external_ep_session_created` → `plugin_compute_mul` → `external_ep_numerical_result_1_5625` → `plugin_release_compute_state` → `plugin_release_compute_infos` → `release_ep` → `factory_released` → `unregistration_succeeded`. The original CPU-fallback mode again verified `Identity(x)->y` with output **1.25**.

The first attempt **[41563644907](https://github.com/sguzman/vulpra/actions/runs/41563644907)** failed strict header compilation because graph functions were initially mistaken for members of `OrtModelEditorApi` rather than `OrtApi`; the corrected header compile passed. The next diagnostic run **[41563729283](https://github.com/sguzman/vulpra/actions/runs/41563729283)** reached real plugin compilation and state creation but showed that the same logical input used twice (`Mul(x,x)`) could be represented as **one** fused-node kernel input. The corrected `Mul(x,z)` with separate ONNX graph input names passed all callbacks and numerical assertions in **41563943117**. These failed diagnostic runs are not counted as passes.

**Limits:** Demonstrates that a tiny, non-production **external** CPU-only execution provider can accept, compile, and execute one fixed-shape `float32[1]` ONNX `Mul` node using the pinned original runtime API. It does not demonstrate GPU/accelerator support, a general-purpose EP, integration with Firefox/Vulpra ML frontends, automatic backend replacement, compatibility of other ONNX operators/types/shapes, FFI/build/link/dynamic-loading closure, removability of `libonnxruntime.so`, or native-package savings. The CI-owned fixture and test-only C code are not browser runtime components. No browser source or user installation/profile was modified. The expensive native workflow was restored to **manual-only**; **M3 remains 5/6=83%, overall 61%, Δ +0pp**.

## Original ONNX Runtime 1.30 external session with CPU fallback — verified (2026-11-03 UTC)

**[Source-pinned native CI 41562244114 — PASS](https://github.com/sguzman/vulpra/actions/runs/41562244114)**. Original full-normal source and packaged archive SHA-256 were authenticated again; the pinned v30 ONNX C/EP headers and all three C translation units compiled with `-Wall -Wextra -Werror`. Native job **125675320392** passed in a disposable no-egress Ubuntu 24.04 process and uploaded bounded artifact **13197086384** (`m3-original-onnx-external-ep-factory-lifecycle`). The original library reported version **1.30.0**, supporting `GetApi(30)`.

The old default zero-device registration and the separate one-CPU-device enumeration **both passed again**. The new opt-in mode (`VULPRA_CI_ONNX_EP_CPU_FALLBACK=1`) selected one **real ONNX-discovered CPU hardware device**, appended a CI-only external execution provider to actual session options via `SessionOptionsAppendExecutionProvider_V2`, then created a genuine `OrtEp` instance from the pinned callback ABI. The plugin's `GetCapability` callback was **observed** and intentionally reported support for **zero model nodes**; no custom kernels or external-provider inference were implemented.

The execution test builds a network-independent, in-memory ONNX `Identity(x)->y` model with a runtime-provided `float32[1]` input of **1.25**, explicitly disables graph optimizations, creates a real ONNX session, executes `Run`, and validates the output type, rank, dimension and exact float value **1.25**. It releases output, input, memory info, session and options **before** unregistering the external library. Logged stages: `external_ep_appended` → `session_ep_created` → `get_capability_no_nodes` → `external_ep_session_created` → `cpu_fallback_numerical_result_1_25` → `release_ep` → `cpu_fallback_model_pass` → `factory_released` → `unregistration_succeeded`.

**Earlier diagnostic attempt [41562107414](https://github.com/sguzman/vulpra/actions/runs/41562107414) did not pass the strict capability-callback assertion**: the original constant-only model produced a correct 1.25 output and valid session teardown, but the callback was not observed. This was **not** evidence of an ONNX runtime or model-inference failure. Replacing it with a genuine input-dependent Identity graph made capability negotiation observable and allowed the full acceptance assertion to pass in **41562244114**.

**Scope:** This is real ONNX **external-provider session integration and built-in CPU fallback**, not execution **by** the external provider, GPU/accelerator testing, full integration into browser ML frontends, complete compile/link/FFI/`dlopen` graph closure, native distribution support on EndeavourOS/Hyprland, or authorization to prune source. Both original compiled package and pinned headers were unchanged; all tests used disposable CI namespaces. The expensive workflow was restored to **manual-only**. No Firefox installation/profile was modified, and there were **zero** source deletions or additional measured native-package savings. **M3 remains 5/6 (83%), overall 61%, session Δ +0 percentage points.**

## Original ONNX Runtime 1.30 external CPU EP-device enumeration — verified (2026-11-03 UTC)

**[Original native CI 41560348027 — PASS](https://github.com/sguzman/vulpra/actions/runs/41560348027)** and **[workflow lint 41560348229 — PASS](https://github.com/sguzman/vulpra/actions/runs/41560348229)**. Native job 125669201769 authenticated the original full-normal archive and pinned v30 API headers, compiled the C fixtures, executed the original runtime in two isolated no-egress processes, and uploaded bounded artifact **13196981996**.

The existing factory with **zero advertised devices** passed again. A separate opt-in mode, `VULPRA_CI_ONNX_EP_DEVICE_PROBE=1`, enumerated an **actual ONNX-discovered CPU hardware device**, used `OrtEpApi::CreateEpDevice` to create **one** CI-owned `OrtEpDevice`, and returned it to the original runtime. The independent C test queried `OrtApi::GetEpDevices`, matched exactly one `VulpraCIProbeEP` device of CPU hardware type, and unregistered cleanly. Logged native stages: `get_supported_devices` → `cpu_ep_device_created` → `create_data_transfer` → `registration_succeeded` → `cpu_ep_device_enumerated` → `factory_released` → `unregistration_succeeded`.

Source and package remain pinned to original compiled Vulpra source b1482404dfb8b01342990ee99ea3df0f9756b5f7 and archive SHA-256 7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a. The same ONNX v30 header hashes as the prior test were validated. This test does **not** fabricate a GPU, exercise an accelerator, or use the host's installed Firefox.

**Limits:** `CreateEp` deliberately returns `ORT_NOT_IMPLEMENTED`, so no external-EP session selection or model execution was tested. This is genuine device creation/enumeration and teardown, **not** functional provider inference, GPU support, complete feature/build/FFI/dynamic-dependency closure, or evidence authorizing pruning. The expensive workflow is restored to **manual-only**. No source deletion or native-package savings. **M3 stays 5/6=83%, Vulpra overall 61%, Δ +0 percentage points.**


## Original compiled ONNX Runtime 1.30 external factory registration and cleanup — verified (2026-11-03 UTC)

**[Source-pinned original native execution-provider lifecycle CI 41559011764 — PASS](https://github.com/sguzman/vulpra/actions/runs/41559011764)**. Original job logs were inspected, and the successful run uploaded bounded artifact **13195696866** (`m3-original-onnx-external-ep-factory-lifecycle`). Earlier workflow lint at [41558445051](https://github.com/sguzman/vulpra/actions/runs/41558445051) passed; the final manual-only workflow conversion requires its own lint acceptance. This work is a narrow, actual **native registration and cleanup** proof; it does not close the remaining full-loader-graph gate.

The authenticated original **full-normal** Linux Vulpra package was compiled at immutable source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`; the archive SHA-256 was `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. Crucially, the **actual** packaged `libonnxruntime.so` reports **ONNX Runtime 1.30.0**, and exposes `GetApi(30)`, not merely the previously inspected backwards-compatible v22 surface. The C headers in the successful fixture were pinned to upstream ONNX v1.30.0 Git blobs `a254e990237d5575186cf3871392db8c70835a56` (core API), `0424a95c2d2c1102f328b4e3aeb77ec72601a120` (execution-provider ABI), and `732fcd7a82eaa0208c7c97aa5f2fb2b0c694456f` (error enums); CI authenticated them before compilation.

Two genuine **test-fixture defects** were independently isolated through failing runs and corrected rather than attributed to Vulpra:

1. The old v22 `CreateEpFactories` callback accepted **five arguments**, while the actual runtime's v30 callback requires **six**, adding a `const OrtLogger* default_logger`. Runtime diagnostic [41558068068](https://github.com/sguzman/vulpra/actions/runs/41558068068) showed the original `1.30.0` string and rejected implausible callback arguments before dereference.
2. Once the v30 callback and factory structure were used, run [41558697742](https://github.com/sguzman/vulpra/actions/runs/41558697742) reached **one created factory** and `GetSupportedDevices`, then failed. Pinned upstream v1.30 `Environment::RegisterExecutionProviderLibrary` calls `factory.CreateDataTransfer` **unconditionally** after enumeration, even for a factory returning zero device entries. The test fixture had left that callback null. Implementing a well-formed callback returning `NULL` transfer and successful status resolved this failure.

**Final accepted native observation:** `entered_factory_init` → `factory_created` → `get_supported_devices` → `create_data_transfer` → `registration_succeeded` → `factory_released` → `unregistration_succeeded`. The standalone pinned-header factory unit self-test also passed. Runtime execution used a disposable Ubuntu 24.04 GitHub Actions Linux process with `unshare --net`, no egress/profiles, a bounded timeout, and the **actual authenticated original ONNX ELF**. The CI-owned plugin reports **exactly one provider factory and zero EP devices**, performs **no inference, device dispatch, GPU work, custom memory transfer, or browser ML frontend activity**. There was no install or modification of the owner's Firefox or workstation.

**Acceptance scope:** Validates that **one real ONNX-origin optional execution-provider library registration and unregistration lifecycle works** with a correctly implemented, version-matched, non-executing factory. It does **not** prove any usable real external execution provider, real EP device enumeration, CUDA/other GPU support, accelerator numerical correctness, browser ML integration, optional feature activation under every condition, native distribution compatibility, or complete binary/build/FFI/`dlopen` dependency closure. Earlier valid read-only v22 API proof, CPU-provider numerical test and custom-ops dynamic loader remain separate. The experimental workflow was restored to **manual-only** after passing; no source was pruned or native package bytes saved. **M3 sixth gate remains open: 5/6=83%, Vulpra overall 61%, session Δ +0 percentage points.**

## Original compiled ONNX v22 external execution-provider API surface: read-only proof and failed inert registration (2026-11-03 UTC)

**[Source-pinned original native API-surface CI 41555767577 — PASS](https://github.com/sguzman/vulpra/actions/runs/41555767577)**, **[workflow lint 41555767549 — PASS](https://github.com/sguzman/vulpra/actions/runs/41555767549)**. Bounded report artifact **13194656363**, `m3-original-onnx-external-ep-api-surface.json`, was downloaded and independently inspected. It authenticates the original compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, original full-normal package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, and upstream public MIT ONNX Runtime v1.22.0 C header Git blob `b01b7e48dc87bbeeb026c61fb06c591053853ad1`.

The exact original packaged `libonnxruntime.so` successfully loads in a disposable **no-egress** CI Linux namespace; `OrtGetApiBase` returns a nonempty version and **`GetApi(22)` returns a non-null table**. C `offsetof` assertions compiled against the SHA-pinned upstream header derive the **actual** `OrtApi.RegisterExecutionProviderLibrary` table index **301** and adjacent `UnregisterExecutionProviderLibrary` index **302**. Both function pointers are non-null in the original compiled library. This is a proven **API surface**, **not** proof that a usable external execution provider can be registered or used.

The first trial ([41554078873](https://github.com/sguzman/vulpra/actions/runs/41554078873)) stopped at a correct C `offsetof` assertion: an initially assumed function-table offset was wrong. After replacing guessed offsets with **compiled pinned-header offsets**, trial [41554347776](https://github.com/sguzman/vulpra/actions/runs/41554347776) reached the original library but **segfaulted** in the isolated native registration call. A bounded native stage trace on trial [41554575881](https://github.com/sguzman/vulpra/actions/runs/41554575881) confirmed successful original ELF loading, v22 API access and ONNX environment creation before the registration call. After correcting a `-Werror` diagnostic fixture compilation issue, trial [41555361620](https://github.com/sguzman/vulpra/actions/runs/41555361620) confirmed that the original ONNX registration path actually **loaded the CI-only inert `libvulpra-onnx-inert-ep.so`** and **invoked its `CreateEpFactories` callback**, but subsequently segfaulted **before the original registration call returned**.

That intentionally inert fixture returned zero execution-provider factories and represented **no actual CPU, GPU or accelerator provider**. The segmentation fault is an **unresolved result of this narrow, deliberately empty test fixture**, not proof that the production browser or ONNX's legitimate external providers are broken. There is no independently verified complete registration, functional external provider, provider-device enumeration, or fallback behavior from those attempts. **The crashing experiment was replaced** with a new read-only Rust v22 API-surface inspector that never calls `RegisterExecutionProviderLibrary`, `UnregisterExecutionProviderLibrary`, or any plugin callback. Its only native operations are loading and querying the original library's API table and unloading the handle; it made no network calls and did not touch user/browser profiles.

| Exact original compiled ONNX external EP question | Observed |
| --- | --- |
| `GetApi(22)` supported | **Yes** |
| Pinned original `OrtApi` function-table indices for registration/removal | **301 / 302** |
| Both function pointers non-null | **Yes** |
| Original library loaded the zero-factory CI fixture and entered its `CreateEpFactories` callback | **Yes, in failed registration trial** |
| That deliberately zero-factory trial returned successfully | **No — native process segfaulted** |
| Any functioning real external provider or GPU feature validated | **No** |
| Complete optional provider, FFI and `dlopen` dependency graph closed | **No** |

Next step for true registration proof would require a separately reviewed, well-formed `OrtEpFactory` fixture implementing the complete required factory/device ABI and safe teardown, with exact-source C header pinning and isolated native crash diagnostics, **not** another zero-factory attempt. The earlier accepted genuine CPU provider and custom-operator loader evidence remains separate and valid. The read-only source-pinned replay is restored to **manual-only** after acceptance.

**No application source was pruned or native bytes saved. M3 sixth gate remains OPEN (5/6=83%), Vulpra overall 61%, session Δ +0 percentage points.**

## Exact original ONNX CPU execution-provider registration, separated from optional dynamic plugin loading (2026-11-03 UTC)

**[Source-pinned original ONNX CPU provider CI 41551291000 — PASS](https://github.com/sguzman/vulpra/actions/runs/41551291000)** and **[workflow lint 41551290931 — PASS](https://github.com/sguzman/vulpra/actions/runs/41551290931)**. Sanitized runtime artifact **13191721752**, `m3-original-onnx-explicit-cpu-ep.json`, was independently downloaded and inspected. Exact original source Git `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, native full-normal package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` and upstream MIT ONNX C API v1.22.0 header Git blob `b01b7e48dc87bbeeb026c61fb06c591053853ad1` were independently authenticated.

This test **explicitly selects the real CPU execution provider**, rather than merely observing that ONNX's CPU provider is implicitly present by default. The std-only Rust probe now has a narrowly scoped `--explicit-cpu` mode that calls the original `OrtApi.GetAvailableProviders` (function pointer slot **125**) and `OrtApi.ReleaseAvailableProviders` (slot **126**), validates a bounded provider list and requires the precise **`CPUExecutionProvider`** name. It then uses `dlsym` on the **actual compiled original `libonnxruntime.so`** to require its exported `OrtSessionOptionsAppendExecutionProvider_CPU` function and calls that C API explicitly with a CPU arena enabled. Both entry points and the actual registration status were verified as successful, followed by real in-memory `Constant` CPU session and `Run`, producing **an exact validated `float32[1] = 1.25` numerical result**.

| Original source-pinned compiled ONNX CPU execution-provider check | Verified result |
| --- | --- |
| Original `GetAvailableProviders` reports the CPU execution-provider name | **Yes** |
| `OrtSessionOptionsAppendExecutionProvider_CPU` exported from the original ELF | **Yes** |
| Explicit CPU execution-provider registration returns success | **Yes** |
| Separate noninterposed control and CI-interposed CPU inference both pass exact value | **Yes; float32[1] = 1.25** |
| Original `libonnxruntime.so`-origin internal `dlopen` in this explicitly selected CPU workload | **0** |
| Separately counted outer Rust probe `dlopen` | **1** |
| Actual CUDA or optional GPU execution-provider registration, runtime plugin, device, or shader | **Not exercised** |

The two new public ONNX C API field offsets were independently compiled with `offsetof(OrtApi,...)` static assertions against the pinned upstream header. The new no-egress CI uses the same original package as the previously accepted numerical CPU and custom-ops loader tests. The original CPU execution provider is not proven to require dynamic loading: in fact **the bounded observer reports zero ONNX-origin internal `dlopen` calls during explicit CPU registration**. This is distinct from the [earlier real `RegisterCustomOpsLibrary` test 41549851976](https://github.com/sguzman/vulpra/actions/runs/41549851976), which did cause one genuine ONNX-origin dynamic load for a harmless CI-owned custom-operator plugin. These paths must not be conflated.

The API returns a list of provider names; this experiment **only requires CPU membership**, and makes **no claim** about the number of other providers, CUDA availability, their registration, model compatibility, fallback behavior, or GPU loading. A successful CPU registration/inference does **not** close all optional execution-provider / generated-build / FFI / `dlopen` graphs, prove an original graphical browser ML frontend, or exercise the user's physical EndeavourOS/Hyprland machine. Both ordinary control and observer runs are isolated; `LD_PRELOAD` changes native resolution and supplies no uninstrumented full caller stack. The expensive source-pinned native archive replay was restored to **manual dispatch only** after its verified acceptance.

**No code was pruned, no package bytes saved. M3 sixth gate remains OPEN (5/6=83%), Vulpra overall 61%, session Δ +0 percentage points.**

## Original ONNX Runtime internal dynamic load successfully exercised — custom-ops path (2026-11-02)

**[Original compiled native custom-ops registration CI 41549851976 — PASS](https://github.com/sguzman/vulpra/actions/runs/41549851976)**, **[workflow lint 41549851930 — PASS](https://github.com/sguzman/vulpra/actions/runs/41549851930)**. The bounded artifact **13191140584**, `m3-original-onnx-customops-runtime-boundary.json`, was independently downloaded and inspected. Both exact original source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and full-normal compiled native package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` were authenticated.

The previous real original ONNX **CPU `Constant`** model tests (API-base, session, and numerically checked `Run`) showed **zero ONNX-origin internal `dlopen` calls**; this was a genuine bounded negative result. The next executable original ONNX boundary was found in the upstream ONNX Runtime v1.22.0 `onnxruntime/core/session/onnxruntime_c_api.cc` implementation of **`RegisterCustomOpsLibrary`**, which calls `Env::Default().LoadDynamicLibrary`. The public C API slot **29** was compiled/checked with C `offsetof(OrtApi, RegisterCustomOpsLibrary)` against immutable upstream header blob `b01b7e48dc87bbeeb026c61fb06c591053853ad1` before invoking it from Rust. This is **custom-operator registration, not execution-provider or GPU activation**.

The reusable std-only Rust test in `ci/m3-original-onnx-constant-session.rs` now accepts a second, tightly restricted argument for a locally compiled fixture named `libvulpra-onnx-test-customops.so`. That CI-owned fixture exports a trivial `RegisterCustomOps` callback registering **no custom operators**, and a counter. Original `libonnxruntime.so` receives the local fixture path through `OrtApi.RegisterCustomOpsLibrary`, returns its actual loader handle, and calls the fixture's registration callback. The Rust probe checks that callback counter equals **1**. Both an **ordinary uninstrumented control** and an isolated no-egress, **CI-only LD_PRELOAD observer** run subsequently create the same in-memory CPU `Constant` session and verify the exact **float32[1] = 1.25** numerical output, with neither model downloads nor personal browser data.

| Independently observed original compiled ONNX native result | Verified |
| --- | ---: |
| Real original `RegisterCustomOpsLibrary` entry point called | **Yes** |
| Actual CI-only inert plugin `RegisterCustomOps` callback invoked | **1** |
| `dlopen` calls attributed to original `libonnxruntime.so` by immediate native caller | **1** |
| Successful ONNX-origin internal `dlopen` calls | **1** |
| Failed ONNX-origin internal `dlopen` calls | **0** |
| Separately counted outer Rust probe/harness `dlopen` calls | **1** |
| Both original CPU `Run` outcomes and exact output value | **PASS, float32[1] = 1.25** |
| External execution provider, CUDA/GPU, real browser ML frontend | **Not tested** |

The same origin observer had already passed native compiled positive and negative interposition fixtures ([41524996253](https://github.com/sguzman/vulpra/actions/runs/41524996253)); it distinguishes the **internal module-origin load** from the test harness's outer load, without exporting absolute load paths, caller PCs, symbol tables, runtime trace PIDs, or user state. The result demonstrates **at least one successful actual runtime call from original compiled ONNX into the conditional `dlopen` boundary**, unlike a symbol-only census. It does **not** assign that observation to one exact machine instruction in the original stripped binary, prove all alternate provider registrations, or establish provider-specific fallback behavior. It is an **instrumented** origin observation; the separate noninterposed run proves registration/inference correctness but has no origin stack.

No browser was built, installed, or launched; no source was deleted, no package bytes saved, no third-party model or network needed. The now-proven custom-ops loader path is only one controlled native case; **complete ONNX optional loaders, all other FFI/dlopen paths, full feature-source ownership and live EndeavourOS/Hyprland behavior remain unproven**. The expensive original-package replay is returned to **manual dispatch only** following its acceptance.

**M3 gate six still OPEN (5/6, 83%); Vulpra overall 61%; session Δ +0 percentage points.**

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
