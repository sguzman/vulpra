# M3 — Source-pinned ONNX C API and native four-workload GNU ABI coverage (2026-10-31)

## Separate original-archive native ONNX Runtime activation

[Real original compiled native ONNX test 41159617600 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41159617600), sanitized artifact **13026641633**. Source provenance `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, immutable full-normal archive SHA256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, 87,154,544 tar.xz bytes. The original `toolkit/components/ml/moz.build` packages the optional external artifact under the `CONFIG["ONNX_RUNTIME"]` build gate. This test uses the shipped `libonnxruntime.so` **unchanged**, not a newly built substitute.

A deliberately minimal **Rust `std` and glibc `libdl`** executable invoked `dlopen(RTLD_NOW|RTLD_LOCAL)`, resolved `OrtGetApiBase`, called the real compiled ONNX Runtime C API's version-string getter, and validated the returned string is nonempty/ASCII. It ran *inside a separate root-created Linux `unshare --net` namespace with no non-loopback network interface and no default route*, plus disposable HOME. An actual `LD_DEBUG=versions` trace of that Rust probe's process confirmed **all 20/20 original `libonnxruntime.so` source-pinned GNU VERNEED version-name requirements checked**. Raw trace paths, PIDs and process arguments were discarded, only the bounded version names/source provenance and explicit limits retained.

The first CI candidate [41159557574](https://github.com/sguzman/vulpra/actions/runs/41159557574) failed only because the scoped helper incorrectly expected `GITHUB_WORKSPACE` to survive `sudo` environment scrubbing; this helper-path error was corrected. The successful [41159617600](https://github.com/sguzman/vulpra/actions/runs/41159617600) ran the real native `dlopen`, C ABI symbol/API, source ABI trace and no-egress checks. No ONNX model was loaded; there was no inference, browser-ML integration, model downloading, production user-data handling or ordinary workstation verification. A working ONNX Runtime API entry point is not proof of any model's accuracy or performance.

## Independently authenticated four-workload union

[Exact native original GNU loader-version-check union 41159795580 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41159795580), artifact **13026552164**, authenticates five immutable successful CI runs by their run IDs and original code SHA: independent static 519-contract archive report, real original private Weston 10s browser startup, real original `gfxtest` Wayland/EGL connection, synthetic-only `pingsender` gzip localhost POST within no-egress namespace, and original compiled ONNX C-API probe. [Workflow lint 41159795514 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41159795514).

| Authenticated actual native workload | Distinct original compiled ELF `(requester, provider, GNU version)` checks observed |
| --- | ---: |
| Ten-second original browser graphical startup, separate isolated profile | **336** |
| `gfxtest glx --wayland` private Weston/EGL roundtrip | **8** |
| `pingsender` one synthetic gzip POST to the namespace-only localhost receiver, forbidden-host rejection verified | **22** |
| `libonnxruntime.so` `OrtGetApiBase` C ABI initialization via minimal Rust loader, no-egress namespace | **20** |
| **Source-verified disjoint union** | **386** |
| **All original 28 native ELF files' declared version triples** | **519** |
| **Not observed by any of these four specific workloads** | **133** |

**Remaining 133** not-exercised original compiled ABI version triples are limited to six original build/source-anchored ELF basenames:

| Native module/helper | Version triples not checked |
| --- | ---: |
| `crashhelper` | 27 |
| `updater` | 27 |
| `libmozinference.so` | 24 |
| `vulpra-bin` | 21 |
| `crashreporter` | 20 |
| `libclearkey.so` | 14 |
| **Total** | **133** |

All six remain retained and cannot be inferred removable from non-activation under four artificial test workloads. In particular, updater and crash handling are critical separate error paths; `vulpra-bin` is a separate packaged executable; the inference and ClearKey media paths require real feature triggers and native integration tests.

## Final scope boundary

**386/519 = 74.4% observed GNU version-name requirement coverage across four source-pinned executed workloads.** This is **not** 74.4% Firefox feature coverage, source pruning, all binary imports, RAM/CPU efficiency, or project completion. A version-check does not prove each dynamic-symbol relocation actually bound, lazy `dlopen` or `dlsym` in every feature context, unversioned imports, NSS/multimedia behavior, or the user's Arch/Hyprland runtime. The Rust probe succeeds at the ONNX C-API boundary, but **the browser ML service was not tested**.

None of the original Vulpra source, normal compiled archive, installed Firefox Developer Edition profiles, launch defaults or production networking were changed. No new binary savings, source deletions or additional product M3 acceptance gate were earned.

**M3 5/6 (83%), overall project 61%, this session Δ0 percentage points.**

## Additional real original compiled `vulpra-bin` Wayland executable (2026-10-31)

The alternative native original-compiled `vulpra-bin` executable passed [CI 41160038198](https://github.com/sguzman/vulpra/actions/runs/41160038198) **SUCCESS**, two separate real 10s private Weston graphical frame/liveness checks (untraced and traced) under an ephemeral private-profile shim. All **21/21** original alternate-executable ELF version triples observed; no installed Vulpra/Firefox launcher/profile/default changes. [Five-run original compiled source-version union 41160181649](https://github.com/sguzman/vulpra/actions/runs/41160181649) **SUCCESS** extends this four-workload record to **407/519** original version triples observed and **112** still unexercised in five modules. This supersedes only the earlier narrower total; [final current source ABI evidence](M3-ORIGINAL-NATIVE-FIVE-WORKLOAD-ABI-20261031.md). M3 5/6 (83%), overall 61%, Δ0pp.
