# M3 — Original compiled native feature-activation ELF coverage (2026-10-31)

## Verified source and immutable package

The experiments authenticate the *same* original Firefox-derived Vulpra source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, and its full-normal native tar.xz SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The independent [source-pinned static ELF VERNEED report 41157293087](https://github.com/sguzman/vulpra/actions/runs/41157293087) established exactly **519** original GNU `(requester basename, declared provider, version)` name requirements among 28 original native ELF files. The original [real normal-browser private Weston 10s `LD_DEBUG=versions` execution 41157865349](https://github.com/sguzman/vulpra/actions/runs/41157865349) checked **336** of those requirements, leaving nine modules/helper executables untouched by that one about:blank startup.

Rather than drawing removal conclusions from inactivity, actual original compiled auxiliary feature paths were independently exercised:

### Wayland graphics helper

[Native `gfxtest glx --wayland` 41158839352 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41158839352), artifact **13026525440**. A separate headless-backend, pixman-rendered Weston compositor supplied a fresh native Wayland socket, no X11 display, and a disposable home. The real extracted archive's packaged `gfxtest` ran its original Wayland EGL probe. In pinned `toolkit/xre/gfxtest/glxtest.cpp`, `TEST_TYPE / EGL` is recorded after `wl_display_connect`, an EGL capability attempt, `wl_display_roundtrip`, and `wl_display_disconnect`; CI required the exact adjacent marker and successful command status. The real `LD_DEBUG=versions` trace verified **8/8** original `gfxtest` version-name contracts.

This **does not prove hardware GPU acceleration**: Weston uses pixman/headless backend, and the EGL capability attempt may itself report failure even though the Wayland path executed and completed.

### Synthetic, isolated native ping sender

[Real packaged `pingsender` 41159158976 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41159158976), artifact **13025903405**. The source's genuine `Ping::Send` compresses an input file with gzip, resolves libcurl dynamically, sends HTTP POST, and deletes the input only after send succeeds. CI executed the genuine original binary as a standalone process **inside a fresh root-created Linux network namespace with only its loopback link enabled, no default route, no external network interfaces**. A disposable Python localhost test server verified synthetic fixed JSON bytes, gzip encoding, HTTP User-Agent and version header and returned 204; the source-pinned sender deleted only that temporary input. A separate disallowed numeric `127.0.0.1` destination was rejected under the pinned host allowlist while the local server remained ready, and the rejected payload remained intact. The subsequent permitted literal `localhost` request completed successfully, and the raw socket/process logs were discarded. No real telemetry, existing profiles, remote addresses or external network requests were used. Actual `LD_DEBUG=versions` confirmed **22/22** original `pingsender` ELF version-name contracts.

This is *synthetic no-egress functional behavior* of the sender, not an endorsement of production telemetry, actual browser telemetry policy, or user-data collection.

## Source-pinned observed ELF version-name union

[Comparison CI 41159289264 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41159289264), artifact **13026219719**, authenticated *all four upstream runs* (static source baseline, live browser, `gfxtest`, and strengthened `pingsender`) via exact immutable run ID, `main` source report head commit SHA and successful conclusion before fetching their sanitized artifacts. It compared *actual unique version triplets*, not just aggregate numeric counts, and rejected mismatched source versions, missing/duplicate triples, incompatible network-policy flags, and unsupported source-removal claims.

| Compiled source workload | Verified distinct original GNU version contracts observed |
| --- | ---: |
| Actual 10-second native browser graphical about:blank startup, offline ordinary host | **336** |
| Separate real native `gfxtest` Wayland EGL round-trip | **8** |
| Separate native `pingsender` synthetic gzip HTTP POST, no-egress loopback | **22** |
| **Disjoint observed union** | **366** |
| **Total source-pinned original ELF VERNEED contracts** | **519** |
| **Still not exercised** | **153** |

The **153** remaining unobserved contracts (in these three specific workloads) belong to exactly **seven** original source-anchored ELF members:

| ELF member basename | Original version contracts not exercised |
| --- | ---: |
| `crashhelper` | 27 |
| `updater` | 27 |
| `libmozinference.so` | 24 |
| `vulpra-bin` | 21 |
| `crashreporter` | 20 |
| `libonnxruntime.so` | 20 |
| `libclearkey.so` | 14 |
| **Total** | **153** |

Source/build ownership of all nine original nonstartup binaries was verified separately by [41158230644](https://github.com/sguzman/vulpra/actions/runs/41158230644). The remaining seven include error paths, independent update/install behavior, inference and ClearKey media, and a separate browser executable variant. Lack of a checked version contract during these workloads **does not prove those features are unused or removable**.

## Safety boundaries and remaining M3 gate

Observed GNU loader-version checks are *not actual resolved dynamic-symbol relocations*. Static version-name/provider matching separately verified [4,611 versioned imported symbols](M3-NATIVE-ELF-VERSIONED-SYMBOL-CANDIDATES-20261031.md) at the candidate level, but actual symbol/interposition behavior, unversioned imports, lazy `dlopen`/feature paths, binary source-level causal attribution, and target Arch/Hyprland acceptance remain incomplete. The three tested feature paths had different runtime environments and are not one browser-session usage profile. We cannot infer completeness of any service, updater, crash handler, multimedia path, memory/runtime performance, or compressed savings.

No original source files, compiled packages, installed Firefox Developer Edition profiles, production networking or default browser features were modified. No source pruning, feature removal, or new package savings were accepted.

**Overall 61%, M3 5/6 = 83%, round delta +0 percentage points.** The last broad M3 feature/build/ABI dependency-mapping gate remains open.

## Fourth actual native source-triggered feature path (2026-10-31)

[Original packaged `libonnxruntime.so` activation 41159617600 PASS](https://github.com/sguzman/vulpra/actions/runs/41159617600), verified by a minimal Rust ABI probe inside a no-egress network namespace, invoked original `OrtGetApiBase` and C-API version string, and observed **20/20** original ONNX version contracts. It did **not** run ML inference or integrate a model into the browser. [Authenticated four-way ELF version-check union 41159795580 PASS](https://github.com/sguzman/vulpra/actions/runs/41159795580) now measures **386/519** original compiled version-name checks observed across four *different* native feature workloads, **133** not exercised in six retained source-origin modules. This replaces only the three-workload count above, not its original exact source/runtime evidence; [current report](M3-NATIVE-ONNX-C-API-AND-FOUR-WORKLOAD-UNION-20261031.md). Still M3 5/6 (83%), overall 61%, Δ0pp, no source-removal credit.
