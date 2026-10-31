# M3 — Original compiled Vulpra five native workload GNU version-check coverage (2026-10-31)

## Binary identity, provenance, and acceptance scope

[Verified native alternate Vulpra executable 41160038198 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41160038198), artifact **13026996068**, used the exact original Firefox 159 beta-derived compiled Vulpra source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and immutable full-normal native archive SHA256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. Its packaged `vulpra-bin` binary was executed **unchanged** with a temporary, throwaway CI-only shell shim that supplied an explicitly isolated `--no-remote --new-instance --profile` directory. The real native [`packaging/test-wayland.sh`](../../packaging/test-wayland.sh) acceptance ran on a private Weston compositor (no X11), strict non-local HTTP test guard intact, and browser-only XRE early offline mode. It passed **10 seconds** of browser liveness, new profile `compatibility.ini` creation, and *same-surface* non-null Wayland buffer attach/commit both without loader traces and again with browser-only `LD_DEBUG=versions` enabled.

The actual compiled alternate executable requested and checked **all 21/21** distinct original GNU ELF `(vulpra-bin, provider, version)` declaration triples from the independent source-pinned immutable original archive. The report deliberately retains no raw profile path, loader path, PID, process argument, user data or URL. It **does not** mean the default installed launcher has been changed, users should launch this variant, the online host is verified, or Arch/Hyprland hardware is covered. Only this separately scoped compiled native alternate executable was exercised.

## Independently verified five native feature workloads

[Five successful real-workload exact GNU version-check reconciliation 41160181649](https://github.com/sguzman/vulpra/actions/runs/41160181649) **PASS**, artifact **13026777522**, with [workflow lint 41160181642](https://github.com/sguzman/vulpra/actions/runs/41160181642) **PASS**. It separately authenticated six immutable CI run IDs/source SHA identities: the original compiled 519-contract ELF `VERNEED` census and five independent native executables/libraries/workloads. Each actual source-triple set must be a subset of the archived immutable compiled package and disjoint where independently added; network and browser policy flags are validated before union.

| Source-pinned original native workload | Distinct original GNU ELF version-name triples checked |
| --- | ---: |
| Ten-second genuine private Weston graphical normal browser startup | **336** |
| Native `gfxtest` Wayland EGL attempt and real compositor roundtrip | **8** |
| Synthetic gzip HTTP POST via original native `pingsender` to local-only no-egress namespace receiver | **22** |
| Packaged `libonnxruntime.so` `OrtGetApiBase` + C API version getter using standalone Rust `dlopen`, no-egress | **20** |
| Genuine alternate native `vulpra-bin` real ten-second graphical Wayland frame/liveness | **21** |
| **Observed exact compiled-source version triple union** | **407** |
| **Original native package's 28 ELFs total static version triples** | **519** |
| **Not observed across these five tests** | **112** |

**407/519 = 78.4% of specifically the declared original compiled ELF GNU version-name contracts observed by these five different, constrained native workloads.** Not 78.4% of all features, imports, browser binary dependencies, code paths, package size or M3 completion.

The last **112** unexercised (in these particular workflows) original ELF version contracts are attributed via earlier source-anchored build mapping [41158230644](https://github.com/sguzman/vulpra/actions/runs/41158230644) to **five** protected/potentially rare-activation binaries:

| Original retained module | GNU version-name triples not checked in these workloads |
| --- | ---: |
| `crashhelper` | 27 |
| `updater` | 27 |
| `libmozinference.so` | 24 |
| `crashreporter` | 20 |
| `libclearkey.so` | 14 |
| **Total** | **112** |

Not-observed does not mean unused. The updater must not be invoked with arbitrary update arguments or real installation paths, crash handler scenarios require isolated crash/minidump inputs, `libmozinference.so` requires an appropriate browser ML activation, and `libclearkey.so` requires correct GMP/CDM host or media playback testing. No protected feature may be deleted solely because this startup audit did not trigger it.

## Explicit limitations and safety

Real glibc loader `checking for version` evidence does not prove each individual symbol relocation, weak/unversioned symbols, full feature-specific `dlopen`/custom host integration, all transient ELF loaders, source-to-linker bytes or target Arch/Hyprland ABI. Some executed workloads use different isolation/network settings: they **cannot be merged as if from a single browser session**. Synthetic payload tests transmit **no real user telemetry**, and the native ONNX C API probe performs **no model inference**. There has been no source deletion, user Firefox Developer Edition profile modification, default browser launcher change, native binary replacement, full new Firefox build or new measured compressed package saving in this work.

**Milestone M3 remains 5/6 (83%); overall Vulpra 61%; this session progress delta +0 percentage points.** The broad last native source/build/feature/ABI dependency coverage gate is still open.
