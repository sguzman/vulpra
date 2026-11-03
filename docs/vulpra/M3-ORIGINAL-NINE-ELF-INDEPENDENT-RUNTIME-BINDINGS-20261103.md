# M3 — Nine unobserved-in-browser-sample original ELFs independently exercised (2026-11-03)

## Accepted source-pinned real native evidence

**[Nine-member original native binding crosswalk 41719403020 — PASS](https://github.com/sguzman/vulpra/actions/runs/41719403020)**, job `126207869529`, sanitized artifact **13271520712** (`m3-original-nine-feature-native-binding-evidence`); initial workflow lint [41719202304 PASS](https://github.com/sguzman/vulpra/actions/runs/41719202304).

All input evidence comes from the same checksum-authenticated *original* full-normal Vulpra compiled source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and browser package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The join-only verifier first confirmed the previous **28 original packaged ELF** source/build/native-loader matrix and **three actual native browser workload** mappings ([41717623238 PASS](https://github.com/sguzman/vulpra/actions/runs/41717623238)); 19 packaged ELFs appeared in the bounded Wayland/WebAudio/USB browser snapshots and nine did not. The nine **not observed in those browser samples** were `crashhelper`, `crashreporter`, `gfxtest`, `libclearkey.so`, `libmozinference.so`, `libonnxruntime.so`, `pingsender`, `updater`, and `vulpra-bin`. **Nonobservation in three selected browser snapshots is not non-use**.

The new `ci/m3-original-nine-feature-runtime-evidence-crosswalk.jq` independently authenticates seven previously successful input CI runs by exact run ID/head commit, validates each source/archive-pinned sanitized native report, maps each of those nine original file names to an evaluated source owner, separates **six original executable** diagnostic activations from **three standalone C API shared-library** tests, checks the actual glibc normal-binding event counts and provider-pair counts, and enforces the original ten-requester aggregate. No new browser test or native code execution is performed by this cross-artifact reconciliation.

| Original packaged ELF | Independently accepted native workload | Real glibc normal binding events | Distinct symbol/provider pairs |
| --- | --- | ---: | ---: |
| `crashhelper` | Protected CLI early-exit diagnostic | **246** | **220** |
| `crashreporter` | Synthetic crash reporter diagnostic, not full submission | **227** | **221** |
| `updater` | Read-only update/channel CLI diagnostic | **324** | **319** |
| `libmozinference.so` | Standalone inference C API, no user model | **184** | **182** |
| `libclearkey.so` | Standalone invalid-interface CDM C API, no decryption | **71** | **70** |
| `libonnxruntime.so` | Standalone ONNX C API, no browser ML frontend | **246** | **244** |
| `pingsender` | Synthetic-only loopback HTTP transaction, no real telemetry | **170** | **170** |
| `gfxtest` | Private Weston/Wayland EGL probe, not hardware GPU acceleration | **64** | **59** |
| `vulpra-bin` | Alternate private Weston browser frame, not ordinary browser launcher | **534** | **173** |
| **Nine-source total** | **6 separately launched helper/executable tests; 3 C API library tests** | **2,066** | **1,658** |

The nine source-owned member identities and exact original-source manifest paths are carried by the sanitized 9-row CI artifact. A separate earlier independently accepted [ten-requester source-pinned real binding union **41206028051 PASS**](https://github.com/sguzman/vulpra/actions/runs/41206028051) confirms **8,394** glibc normal-symbol binding events and **4,520** summed distinct requester/symbol/provider pairs across the nine plus core `libxul.so`. The current crosswalk verifies that `8,394 - 6,328` original `libxul.so` event count equals the independently summed **2,066** event count for the nine, along with the **1,658** distinct pair sum.

Source-authenticated feature and helper run provenance:
- [Protected original auxiliary helpers **41164023607 PASS**](https://github.com/sguzman/vulpra/actions/runs/41164023607), artifact **13028208513** — three separate diagnostic-only executables.
- [Original ML/ONNX/ClearKey native binding reports **41165330510 PASS**](https://github.com/sguzman/vulpra/actions/runs/41165330510), artifact **13028516730** — three separate C API module probes in no-egress namespaces.
- [Synthetic-only original `pingsender` **41165514106 PASS**](https://github.com/sguzman/vulpra/actions/runs/41165514106), artifact **13028906801**.
- [Original `gfxtest` private Weston **41165690323 PASS**](https://github.com/sguzman/vulpra/actions/runs/41165690323), artifact **13029112826**.
- [Original alternate `vulpra-bin` private Weston **41205746021 PASS**](https://github.com/sguzman/vulpra/actions/runs/41205746021), artifact **13043573467**.

The crosswalk rejected **eight deliberately modified archived inputs**: forged unobserved ELF identity, wrong ten-source binding total, missing updater symbol events, wrong ML module identity, falsely claiming ClearKey no-egress, missing ONNX binding events, removing the `pingsender` synthetic-only guard, and falsely claiming the `gfxtest` Weston route. The first attempted join CI [41719202257](https://github.com/sguzman/vulpra/actions/runs/41719202257) **was not accepted**: it required two boolean fields absent from the independently archived older ML/ClearKey/ONNX evidence schema. The verifier was corrected to check only originally recorded fields; **41719403020** then passed all real assertions and all eight negative mutations. This was a validator schema mismatch, not an original native feature failure.

## What is—and is not—established

These are **nine real original ELF native binding requesters in separate diagnostic workloads**, not proof they were resident during the three sampled ordinary browser feature runs. The six executables ran in purpose-specific disposable CLI or compositor contexts, not necessarily through their full browser-controlled launch paths. The three shared objects underwent standalone C API loads and had real glibc bindings; that is not evidence that every browser feature or normal integration route activated them. The work does not establish actual crash submission, an update installation, real telemetry upload, ClearKey media decryption, user-model inference, hardware GPU acceleration, or replacing the standard launcher.

ELF source-owner declarations, glibc per-file provider lists, process mappings, executable launch, `dlopen`, and symbol bindings are **different relations**. Neither a list of 28 direct-needed binaries nor 2,066 observed native binding events closes all future lazy/transitive feature paths, symbol callers, fallback paths or source/build reachability on the actual target workstation. None of these nine binaries is certified removable. No real browser profile or installed Firefox was accessed; no original source or packaged native files were deleted and no bytes saved were claimed. The join-only workflow was restored to **manual-only `workflow_dispatch`**.

**Milestone accounting remains: M3 5/6 = 83%, Vulpra overall 61%, delta +0 percentage points.** The sixth dependency and feature/build/binary closure gate is still open. More useful future work should test unverified actual browser-to-helper launching and alternative feature integration paths, not repeatedly revalidate the same already accepted isolated C API diagnostics.
