# Firefox 160 actual native libxul symbol binding observation (2026-11-15)

## Accepted real runtime witness, not complete dynamic dependency closure

The [real Firefox 160 binding workflow 43741731639](https://github.com/sguzman/vulpra/actions/runs/43741731639) **SUCCESS** launched the original, unchanged, source-authenticated Firefox 160 Vulpra browser archive twice on disposable GitHub Actions Ubuntu 24.04 x86-64 runner environments, using the existing real packaged-browser WebDriver lifecycle. The first launch used normal glibc symbol binding. The second explicitly set `LD_BIND_NOW=1`, forcing eager PLT relocation of modules actually loaded by that workload. Both set `LD_DEBUG=bindings`; only the bounded, validated Rust [binding parser](../../ci/m3-native-libxul-bindings.rs) inspected the PID-specific raw traces, which were removed at the end of the job. No user workstation was accessed, no native browser was rebuilt, and no executable/profile was installed.

### Exact source and archived byte provenance

- Original official Firefox 160 release source commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Independently assembled original candidate source Git tree: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5` (28 verified Vulpra overlay paths).
- Full original native archive SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Original compiled browser [producer CI 43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), exact original compiled source branch `0624235fdc956ab18af3c3f310b3588ca72fff61`.
- Source/byte preservation [CI 43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827), exact preserved branch `54728803f058c3edf54d2e8d3f6e0a7d2af0aec6`.
- Independently verified exact source-matched [28 native ELF, 268 direct DT_NEEDED graph](https://github.com/sguzman/vulpra/actions/runs/43730900702).

### Real bounded WebDriver and runtime linkage observations

| Actual `libxul.so` glibc trace witness | Default binding | `LD_BIND_NOW=1` |
| --- | ---: | ---: |
| Normal symbol-binding events observed | **6,337** | **6,338** |
| Distinct provider/symbol pairs **within the observed sample** | **2,861** | **2,861** |
| PID traces with matching real `libxul.so` records | **2** | **2** |
| Sanitized provider basenames | **45** | **45** |

Both modes passed genuine JS redirect/HTTP 302 and DOM navigation, localhost untrusted HTTPS rejection, temporary unsigned WebExtension install/content-script/background messaging/`storage.local`/uninstall, Nimbus ExperimentStore/API initialization, and isolation from the existing Firefox profile. These are the actual authenticated compiled browser's behavior, not parser-only fixtures or a report of a browser launched from the user's target EndeavourOS workstation.

The **one additional event** under eager binding must not be interpreted as one new symbol, one new dependency, or an FFI route. Symbol/provider pair counts and the 45 sanitized provider basename sets are identical. The observed set includes `libc.so.6`, `libxul.so`, the interpreter, `libnss3.so`, `libgtk-3.so.0`, and other regular packaged/host providers. Runtime traces were bounded and destroyed; no raw symbol names, filesystem paths, PIDs, private profiles or traces were exported to CI artifacts. The retained JSON is `firefox160-actual-libxul-default-eager-bindings-not-ffi-closure` (artifact **14172299413**).

The separately executed [independent evidence reconciliation 43742027662 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43742027662) authenticated the exact success states/commits of both the real runtime run and the earlier independent 28-ELF source/package graph, compared their source and archive hashes, checked both 45-provider basename lists and all meaningful limitation flags, and rejected **8 deliberately forged source/byte/count/provider/runtime/privacy/false-completion claims**. Independent sanitized witness: `firefox160-reconciled-actual-libxul-binding-witness-not-abi-release` (artifact **14172786842**).

### What remains unproven

The earlier [521 GNU provider-version contracts and 4,592 versioned import names](M3-FIREFOX160-VERSIONED-SYMBOL-CANDIDATES-20261115.md), [2,154 unversioned static imports](M3-FIREFOX160-UNVERSIONED-SYMBOL-CROSSWALK-20261115.md) and this **actual glibc runtime binding event witness** measure different boundaries. Their counts must not be added or treated as interchangeable coverage. This runtime observation is confined to the libraries and processes exercised by these two specific WebDriver workloads. It does not establish all delayed/lazy relocations, unused features, future `dlopen`/`dlsym`, transitive/preload cases, Rust/C++ and generated FFI edges, complete fallback behavior or safe source pruning.

It also does **not** establish the target mixed NVIDIA/iGPU EndeavourOS/Hyprland kernel/driver conditions, current security patch completeness, Safe Browsing provider readiness, all sandbox boundaries, public release readiness or user workstation compatibility. PR #6 stays draft and unmerged; issues #8/#9 remain open. The original package and `main`, the user's installed Firefox Developer Edition and personal Vulpra profiles remain untouched.

**Progress:** M3 sixth gate remains open; **83% (5/6)**. Overall **61%**, previous **61%**, session **Δ +0 percentage points**. Next bounded work is attributing observed/delayed `dlopen` and Rust/C++ FFI edges to source owners and testing their protected activation/fallback paths without claiming global closure.
