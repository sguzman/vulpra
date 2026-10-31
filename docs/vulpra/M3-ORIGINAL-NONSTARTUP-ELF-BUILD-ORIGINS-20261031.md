# M3 — Original nonstartup native ELF build-origin crosswalk (2026-10-31)

## Exact original native provenance

[Source-pinned ownership CI 41158230644 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41158230644), bounded artifact **13025897239**, plus [workflow lint 41158230653 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41158230653), authenticates the historical Firefox/Vulpra build-source SHA `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and the *actual* successful original native private Weston 10-second runtime GNU loader-version-check report from [41157865349](https://github.com/sguzman/vulpra/actions/runs/41157865349). That report uses the checksum-pinned original full-normal compiled Vulpra archive `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

Of **519** original statically declared `.gnu.version_r` requirement triples, **336** were actually checked in the graphical `about:blank` startup, and **183** were not. The latter belong to **exactly nine** original packaged ELF basenames, and the additional source audit independently found each of their historical `moz.build` declaration anchors. It did not need a new Firefox compilation, executable invocation or user profile.

| Original ELF member | Static GNU version triples *not observed in one startup* | Authenticated historical build declaration |
| --- | ---: | --- |
| `crashhelper` | 27 | `toolkit/crashreporter/crash_helper/moz.build` — GeckoProgram |
| `updater` | 27 | `toolkit/mozapps/update/updater/moz.build` — Program |
| `libmozinference.so` | 24 | `third_party/llama.cpp/moz.build` — `mozinference` library and `toolkit/components/ml/backends/llama/moz.build` include |
| `pingsender` | 22 | `toolkit/components/telemetry/pingsender/moz.build` — GeckoProgram |
| `vulpra-bin` | 21 | `browser/app/moz.build` — app `-bin` output/source declaration |
| `crashreporter` | 20 | `toolkit/crashreporter/client/app/moz.build` — RustProgram |
| `libonnxruntime.so` | 20 | `toolkit/components/ml/moz.build` — `CONFIG["ONNX_RUNTIME"]` guarded imported final-target file |
| `libclearkey.so` | 14 | `media/gmp-clearkey/0.1/moz.build` — GeckoSharedLibrary in the GMP ClearKey directory |
| `gfxtest` | 8 | `toolkit/xre/gfxtest/moz.build` — Program, referenced by `toolkit/xre/moz.build` |
| **Total** | **183** | **All nine pinned source declarations independently inspected** |

## Interpreting the result safely

These are **source build-origin matches**, not claims that any of the nine is unused, unnecessary, or safe to prune. `crashhelper`, `crashreporter` and `updater` have important rare/error-path purposes; `pingsender` is a separate process; `libmozinference.so` and `libonnxruntime.so` are conditional inference resources; `libclearkey.so` serves a media plugin path; `gfxtest` runs a distinct graphics-test path. The packaged alternate `vulpra-bin` is not proof that the main native executable is absent or removable. Each case needs feature-specific runtime and build-effect tests before any opt-in or permanent removal decision.

The validator checks literal pinned historical source paths/anchors and authenticates the actual original runtime report and all nine observed counts, with a strict fail-closed source SHA and no allowance for source deletion. A real ELF runtime version check is itself **not** full dynamic symbol binding or complete `dlopen`/unversioned feature mapping. No native source code, browser binary, user profile, feature default, installation, or package contents were altered by this investigation.

The next practical M3 gap is **feature-triggered workload coverage for these nine auxiliary modules**, plus outstanding unversioned symbols, runtime `dlopen`, cross-platform build/source graph and actual compiled ABI closure. This report does not permit disabling crash handling, DRM, updating, inference or telemetry based on an about:blank launch.

**M3 remains 5/6 (83%), overall 61%, current round Δ0 percentage points.**

## Two feature-triggered native helper experiments (2026-10-31)

The nine binaries unexercised during the original about:blank graphical version-check test were **not** assumed removable. Instead, independently verified source-pinned native tests activated two real feature-specific binaries under constrained CI: [`gfxtest` private Weston Wayland EGL roundtrip 41158839352 PASS](https://github.com/sguzman/vulpra/actions/runs/41158839352) (8/8 original version needs checked) and [`pingsender` synthetic-only gzip localhost POST, no-egress netns 41159158976 PASS](https://github.com/sguzman/vulpra/actions/runs/41159158976) (22/22 checked, deletion and forbidden-host negative check verified). The [authenticated three-workload ABI version tuple union 41159289264 PASS](https://github.com/sguzman/vulpra/actions/runs/41159289264) found **366/519 observed** and **153 unobserved**, now localized to seven modules with separate conditions. [Scope and caveats](M3-NATIVE-FEATURE-ACTIVATION-WORKLOAD-UNION-20261031.md). No source removal, no product gate credit.
