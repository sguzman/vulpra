# Source-pinned graphical Wayland provider-denial replay — 2026-11-09 UTC

## Why this test exists

Earlier Vulpra headless screenshot tests with optional native provider denials had **0 observed GBM/DRM calls, 0 VA-API calls, and 14 FFmpeg calls**. Headless screenshot success cannot be used to assert missing-GBM graphics fallback or VA-API fallback. The existing separate private [Weston graphical test](../../packaging/test-wayland.sh) actually launches non-`MOZ_HEADLESS` GTK Wayland and requires a non-null `wl_buffer` attach followed by a commit on the **same `wl_surface`**, live for ten seconds, with isolated profile and offline network guard. That makes a narrowly meaningful graphics workload; its **Pixman software compositor does not exercise a real GPU/DRM/DMABuf path**.

## Build and runtime provenance

The browser was **not rebuilt** for this experiment. The [no-rebuild graphical CI run 42662005847 succeeded](https://github.com/sguzman/vulpra/actions/runs/42662005847) against the previously compiled and packaged full-normal Vulpra:

- Original native build run: [42559566915](https://github.com/sguzman/vulpra/actions/runs/42559566915), compiled browser source `a17ac58d694bf77c4da352ed7ab9b37233fbc01e`. This run failed **only at its new VP9 harness step**, after successful native compile, package, original graphical/JS/WebExtension/Nimbus checks, FFI, and H.264. The VP9 fixture URI defect was fixed separately and native package replay [42660459080 succeeded](https://github.com/sguzman/vulpra/actions/runs/42660459080).
- Tested archive SHA-256: `f92fe8c29843e7521ffe1ddd7cbbed8836ff9491228b182628973e8484ed1a41`. CI authenticated the original archive sidecar and generated native-link report, checked original run ID/source/package hash and original accepted runtime contract **before executing** the graphical denial tests.
- Separate graphical harness revision: `321bb9e80ec49558c06b7fca819456e97508e726`. The compiled browser source and newer test harness identities are separately recorded; this is a *source-bound archive replay*, not a claim of having compiled the later harness revision into a new browser.
- Original graphical evidence artifact: **13694588403**, `m3-packaged-wayland-provider-denial-runtime.json`, downloaded and independently inspected. The earlier [run 42661665588 failed](https://github.com/sguzman/vulpra/actions/runs/42661665588) before the actual browser workload at package-authentication shell logic and is **not** counted as native graphical evidence; a corrected workflow passed. Lint [42662005686 passed](https://github.com/sguzman/vulpra/actions/runs/42662005686).

The small [interposer](../../ci/m3-deny-optional-native-providers.c) only changes matching browser-process `dlopen`/`dlmopen` calls, without deleting host libraries or modifying user profiles. Every graphical trial runs a new isolated private Weston/Pixman compositor and Vulpra profile with ten-second rendering/liveness assertions. The shim recorded **3 actual browser-process attachment witnesses per trial**.

## Actual measured graphical outcomes

| Provider group | Real matching loader denial events | Graphical Wayland surface buffer attach+commit | Precise result |
| --- | ---: | --- | --- |
| GBM/DRM | **1** | **Passed** | One matching GBM/DRM request was denied; a real graphical frame was also confirmed in the same isolated trial |
| VA-API | **0** | **Passed** | No matching library request; no missing-VA-API path tested |
| FFmpeg | **14** | **Passed** | Matching FFmpeg loads were denied; graphical startup and frame commit still worked in that isolated trial |

These are genuine **same-session** observations. The separate denial and Wayland log streams do **not** establish precise chronology; even though the original harness has a legacy field named `frame_after_observed_targeted_denial`, the evidence does not independently prove that the denial preceded the Wayland frame. Consequently the accepted scoped claim is *graphical frame and matching denied load in one browser trial*, **not** causal GPU software fallback. No VA-API hardware-video workload was exercised.

The browser remains responsive and graphical frames are confirmed under the private Weston/Pixman setup. There is **no evidence here** of complete accelerated GPU/DMABuf creation, VA-API decoder failure recovery, release parity on the owner's EndeavourOS/Hyprland/RTX 3090 workstation, complete indirect/dynamic/FFI graph closure, or correctness of every protected feature under missing providers.

## Independent report reconciliation

The [conservative classifier](../../ci/m3-wayland-provider-replay-audit.jq) authenticates the external expected native source SHA, later harness SHA, archive SHA and mandatory real Wayland/frame/attachment contracts. It checks per-group denial counts and preserves the distinction between **0 missing-provider requests** and **actually exercised loader-denial paths**. It explicitly sets `provider_denial_temporally_precedes_frame_proven=false`, as well as GPU/DMABuf, VA-API video, complete dependency graph, source-pruning, release and sixth-gate claims to false.

- [Independent CI 42664234555 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42664234555) executed the current **22/22 forged source, package, graphics frame, loader-denial, profile and release-claim rejection tests** and independently downloaded/classified the actual source-pinned graphical report. Its separately retained evidence artifact is **13696071122** (`m3-independent-graphical-provider-replay-classification`), downloaded and inspected.
- Independent classified counters: **GBM 1, VA-API 0, FFmpeg 14**, real private Wayland frame verified, GBM denial and frame **same session** true, chronology proved false, GPU/DMABuf fallback false, sixth M3 gate false, source pruning false. This is a cross-report validity check, not a second graphical execution.

## Next substantive work

The **highest-priority remaining graphics evidence gap is an actual feature-triggering VA-API/GBM/DRM/DMABuf workload** with observable provider requests and software/hardware outcome measurements in a runtime with appropriate device capabilities. Merely adding more startup screenshot trials does not close it. Separate protected-feature/conditional-loader/indirect Rust↔C++ FFI closure and target EndeavourOS/Hyprland acceptance remain necessary.

**M3 is still 5/6 gates (83%); overall Vulpra 61%, Δ+0 pp.** This round closed a bounded graphical-Wayland denial observation and its independent evidence audit, not the sixth milestone gate. No source pruning, workstation changes, security merge or release was authorized/performed.
