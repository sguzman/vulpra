# Current source-matched packaged browser optional-provider denial probe — 2026-11-09 UTC

## Accepted mechanism, separate pending full-browser observation

A small Linux-only C ABI shim, [`ci/m3-deny-optional-native-providers.c`](../../ci/m3-deny-optional-native-providers.c), has been tested with six real disposable shared-ELF provider files. It uses the actual `dlopen` and `dlmopen` process lookup APIs, requires an opt-in provider group, verifies `/proc/self/exe` is named `vulpra` or `firefox` (or an explicitly allowed synthetic fixture binary), and delegates a targeted load to a deliberately nonexistent library to create a genuine failed loader result. It does not modify installed host libraries, the native browser binaries, normal profiles, or global loader configuration.

**Accepted fast control:** [M3 Optional Native Provider Denial Fixtures #42546761377 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42546761377), [bounded evidence artifact 13643797194](https://github.com/sguzman/vulpra/actions/runs/42546761377/artifacts/13643797194). The original JSON archive was independently downloaded and parsed: **6/6** selected actual `dlopen` requests were denied against real synthetic ELF provider files; **4/4** unrelated, cross-group or non-target-executable requests were allowed. Its `test_executable_is_real_browser`, `actual_packaged_vulpra_provider_denials_exercised`, `actual_browser_fallback_proven`, target QA, pruning and release flags are all **false**. [Workflow lint #42546761382 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42546761382). A second [fixture run #42546567441 succeeded](https://github.com/sguzman/vulpra/actions/runs/42546567441) after the process-attachment witness was added. The latest fast fixture also checked the shell harness's syntax and missing-input rejection.

**Live full-browser run:** [M3 Source Matched Native Link Inputs and Runtime #42546880350](https://github.com/sguzman/vulpra/actions/runs/42546880350), source `d7bf1cb73b384df047871d6b8c608312eb6cb5b4`, was **in progress at this checkpoint**, not yet passed or failed. [Workflow lint #42546880251 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42546880251). This is one ordinary unomitted `./mach build` and `./mach package` in GitHub Actions, with existing private localhost screenshot, WebDriver JS/extension/TLS/Nimbus smoke, Rust archive/native ELF census, direct-machine branch and independent reconciliation checks still required. No duplicate native full build was initiated.

## Actual packaged-browser probe protocol

The [`ci/m3-smoke-packaged-optional-provider-denial.sh` harness](../../ci/m3-smoke-packaged-optional-provider-denial.sh) is called **after** the successful normal packaged screenshot and WebDriver runs. The probe rebuilds only the small C interposer and **reuses the same verified archive and the existing `ci/smoke-m3-localhost-package.py`** to invoke the real staged, packaged native Vulpra binary. The latter already validates the archive digest, a real PNG screenshot, localhost request and an untouched disposable Firefox-profile sentinel.

Each trial uses a fresh temporary browser HOME and tries to deny one selected group:

| Trial | Exact library match set | Acceptance scope |
| --- | --- | --- |
| GBM/DRM | `libgbm.so.1`, `libdrm.so.2` | Did a targeted native `dlopen`/`dlmopen` actually occur? Did a real screenshot succeed after the denied call? |
| VA-API | `libva.so.2`, `libva-drm.so.2` | Did the real process request a selected VA-API library? Was the isolated screenshot still successful? |
| FFmpeg | `libavcodec.so.*` and `libavcodec-ffmpeg.so.*` | Did the real process actually attempt an FFmpeg provider load? Did the browser screenshot still succeed? |

The shim emits a bounded `ATTACHED browser-process PID` witness to prove it was loaded by the real native browser executable, and a `DENIED dlopen/dlmopen LIBRARY PID` witness **only on an observed matched loader request**. `ATTACHED` with zero `DENIED` is **not a test of the missing-library branch**. The probe reports all three modes and their observed denial counts, and it fails if attachment or the real screenshot is missing. It restores the prior ordinary-runtime acceptance JSON and does not touch the user's workstation.

The new `m3-current-packaged-optional-provider-denial-evidence` artifact, if generated, will be a **bounded JSON**, not the large browser tarball. **Do not state the exact missing-provider behavior succeeded until the artifact and actual run have been examined.**

## Non-claims and next actions

Even if all three screenshots pass, **full VA-API hardware decode or software fallback**, GBM/DMABuf compositor fallback, FFmpeg H.264 decoding fallback, every transitive `dlsym`/indirect edge, and target EndeavourOS/Hyprland parity remain **unproven** unless a matching provider request was observed and an adequate feature workload was exercised. Headless screenshot success is narrower than video playback and real Wayland rendering.

If the new run fails, inspect the precise native step and bounded artifact before modifying CI or starting another native build. If the run succeeds with zero denials, treat it as a useful no-regression **instrumented** screenshot only, then design explicit feature-triggering tests in a new controlled runtime environment rather than claim the branch was covered.

**M3 remains 5/6 (83%). Overall progress 61% (Δ+0 percentage points). No new pruning, release approval, security hotfix merge, or user's host changes.**
