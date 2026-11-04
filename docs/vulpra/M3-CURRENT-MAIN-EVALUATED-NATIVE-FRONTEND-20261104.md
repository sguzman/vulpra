# M3 — Current-main evaluated Mozilla native frontend and CompileDB (2026-11-04 UTC)

## Actual accepted current-source CI

[**Current-main configured Mozilla native frontend CI 41746278259 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41746278259), job **126299976839**, exact **current-main source SHA `71be5255f3ea4faba8842ca00a85d0678387197e`**. The generated summary artifact **13283772259** (`m3-current-main-evaluated-native-frontend`) was separately downloaded and inspected: a single **2,381-byte JSON** summary compressed to a **992-byte ZIP**.

**This CI really checked out and configured the current pruned `main` source.** It did not re-checkout the older successful compiled original source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`. The original full-normal compiled package archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` remains an **independent historical baseline**, not a binary produced by this run.

After a full current-source checkout and Mozilla toolchain bootstrap, CI ran **`./mach configure`**, verified the generated `obj-vulpra-linux-m3-baseline/config.status` and `config.statusd/substs`, then used Mozilla's **actual `BuildReader` + `TreeMetadataEmitter`** API (reusing the preexisting source-aware Python bridge in `ci/m3-pinned-evaluated-mozbuild-graph.py`) to emit the actual current-source native/Rust/C++/resource build declarations. It also invoked **`./mach build-backend -b CompileDB`**, generating the actual current source's C/C++ compiler **command declarations** without executing any of those commands.

The existing historical evaluator gained a narrowly scoped **`VULPRA_CURRENT_MAIN_EVALUATED_GRAPH=1`** branch. This requires `SOURCE_SHA == GITHUB_SHA`, `GITHUB_REF == refs/heads/main`, a 40-character hexadecimal Git SHA, and the current checkout root matching the configured source tree. Its original source-pin default path remains unchanged. Its new current mode explicitly emits `status=current_main_configure_evaluated_mozbuild_frontend`, `current_source_commit`, and `original_compiled_baseline_represented_by_this_output=false`, preventing a current-build declaration from masquerading as the older source-pinned compiled binary. The main Mozilla frontend bridge remains Python because Mozilla's native BuildReader/emitter APIs are Python; it is not a new Python application or replacement build system.

## Native build declarations actually measured on current `main`

| Generated current-source property | Verified |
| --- | ---: |
| Mozilla `moz.build` frontend emitted objects | **19,139** |
| Evaluated source-directory traversal edges | **1,959** |
| Declared native link targets | **1,342** |
| Declared native library dependency edges | **1,424** |
| Evaluated C/C++ compile source inputs | **11,104** |
| Generated `CompileDB` command declarations | **12,028** |
| Evaluated Rust static library targets | **4** |
| Evaluated Rust executable targets | **2** |
| Evaluated WebIDL binding units | **41** |
| Evaluated resource-install inputs | **2,928** |

These are **genuine generated declarations for current source**, not estimates from `moz.build` text, nor evidence that the compiler, `rustc`, linker, Cargo resolution or browser runtime successfully executed. The large raw generated `CompileDB` (which contains CI absolute paths and command lines) and the raw expanded frontend graph were deliberately **not uploaded**. The one small archived summary includes the source SHA, selected counts, generated option values and explicit negative claims.

### Protected generated current configuration

Actual current `config.status` frontend values were:

| Evaluated configuration | Current value |
| --- | --- |
| `MOZ_WIDGET_TOOLKIT` | `gtk` |
| `MOZ_WAYLAND` | `1` |
| `MOZ_X11` | `1` |
| `MOZ_SANDBOX` | `1` |
| `MOZ_DEVTOOLS` | `all` |
| `MOZ_SERVICES_SYNC` | `1` |
| `MOZ_NORMANDY` | `1` |
| `MOZ_CRASHREPORTER` | `1` |
| `MOZ_UPDATER` | `1` |
| `VULPRA_NO_ASROUTER_PROMOS` | empty/unset |
| `VULPRA_NO_NEWTAB_ADSFEED` | empty/unset |
| `VULPRA_NO_NEWTAB_PROMOCARD` | empty/unset |

Thus the **normal current-source build configuration still declares** protected browser/core features and does not select the three guarded promotional omissions. Actual built binary resource availability and runtime success remain separate.

## Validation, limitations and next work

The current graph's own browser/native verifier passed, required a source-matched current checkout and generated config/graph/CompileDB, and independently rejected **five deliberately forged summary claims** (wrong current source identity, omitted configure, falsely claimed native compilation, wrongly closed M3 gate, and invented source-pruning authority). The standalone Python frontend bridge's reverse Rust graph fixture test passed. Workflow lint passed. The expensive workflow was returned to **manual-only `workflow_dispatch`** immediately after acceptance.

This work **partially reduces the first of the four explicit sixth-gate blockers** in [the independently accepted 28-ELF dependency blocker register](M3-NATIVE-DEPENDENCY-CLOSURE-BLOCKERS-20261104.md): current `main` now has a verified actually emitted Mozilla frontend and generated C/C++ command declaration summary. **It does not close that blocker entirely** because the current `main` source was **not compiled**, no `rustc` or linker commands ran, Cargo feature resolution was not recorded, full generated object/link provenance was not archived, and no current packaged 28-ELF output was produced or compared to the original package.

The other three blockers remain unchanged: conditional runtime `dlopen`/FFI closure and fallback coverage, complete protected feature activation/safety matrix, and genuine target EndeavourOS/Hyprland workstation parity. The original source/pruned current main cannot be declared bit-for-bit equivalent from these current counts alone.

**Next engineering step:** use a **single native current-main compilation/package run**, with isolated build artifacts and source-pinned `config.status`, protected feature checks, compiled 28-ELF identity, and post-build private-profile Wayland smoke validation. Avoid redundant original auxiliary runtime probes. No need to remove existing compiler output or touch installed Firefox.

**No Vulpra source deletion, no current compiled binary removal, no new compiled package bytes saved**, no user profile or host devices touched. **Overall Vulpra 61%, M3 5/6=83%, delta +0 percentage points.** Historical accepted 14,867 source-only removals and 129,967,585 source Git-blob bytes are unrelated to this iteration and are not newly claimed.
