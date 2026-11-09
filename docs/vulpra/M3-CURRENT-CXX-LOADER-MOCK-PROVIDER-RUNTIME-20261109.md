# Current compiled-source C++ VA-API and GBM missing-provider function runtime fixtures — 2026-11-09 UTC

**Accepted bounded CI:** [M3 Real CXX Source Loader Missing-Provider Fixtures #42545413236 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42545413236), independently checked [real JSON artifact **13643036791**](https://github.com/sguzman/vulpra/actions/runs/42545413236/artifacts/13643036791); [actionlint #42545413183 **SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42545413183).

This is the first runtime execution of **three genuine C++ loader function bodies extracted verbatim from the exact source files of the independently successful full Vulpra native browser build**, against deterministic fake provider APIs. It **does not** execute the packaged Vulpra browser and **does not** prove rendering or decoding fallback at process/application level.

## Exact source and test identity

- Original full-browser [normal native run **42507965586 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42507965586), compiled source commit `bd2499aeadce0368faa8b717b0e8a17e9c9dc317`; independent [source/runtime/native reconciliation **42513861084 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42513861084).
- `dom/media/platforms/ffmpeg/VALibWrapper.cpp`: unchanged source Git blob `76935cfb49270b0281362d186b65ddbe971f8f97`; original implementation of `VALibWrapper::LinkVAAPILibs`.
- `widget/gtk/DMABufDevice.cpp`: unchanged source Git blob `4fd08d1453edac94bc96deb9a5ed0efcb27dad91`; original implementations of `GbmLib::IsLoaded` and `GbmLib::Load`.
- The [Rust source extractor](../../ci/m3-extract-current-provider-functions.rs) verifies both Git blobs, insists on the full original native source SHA, extracts each exact bounded original C++ method, and rejects duplicate/missing functions and output overwrites. Its Rust tests and forged-source negative cases pass.
- The [C++ mock-provider harness](../../ci/tests/m3-current-real-cpp-missing-provider-fixture.cpp) **includes the three extracted original method bodies**. It supplies external NSPR/`dlopen`/`dlsym`/VA-API guard and symbol mocks—not copied or reimplemented loader methods—and executes one mode per fresh process, so the real GBM one-time initialization state cannot cross-contaminate cases.
- The [isolated workflow](../../.github/workflows/m3-real-cpp-provider-failure-fixtures.yml) authenticates the original native/reconciliation runs and source GitHub API blobs, compiles the Rust extractor/tests and C++ fixture, and preserves the bounded source-function test report. No system libraries, normal browser profile, user data, or user's host configuration were modified.

## Independently observed original C++ source-function results

All **10/10** modes passed. Expected and observed loader results matched in every mode; there were **eight expected failure/guard paths and two expected present-provider paths**.

| Runtime mode | Real original C++ method result | Mocked library loader calls | Other observed check |
| --- | --- | ---: | --- |
| VA-API hardware disabled | `false` | 0 | hardware guard short-circuit |
| VA-API outside RDD process | `false` | 0 | process guard short-circuit |
| VA-API missing `libva-drm.so.2` | `false` | 1 | no VA-API second load |
| VA-API missing `libva.so.2` | `false` | 2 | returned unavailable |
| VA-API missing `vaExportSurfaceHandle` | `false` | 2 | **one actual unload call** of rejected VA library |
| VA-API both providers and symbol available | `true` | 2 | **one actual `Link()` mock call** |
| GBM missing `libgbm.so.1` | `false` | 1 | no DRM second load |
| GBM missing `libdrm.so.2` | `false` | 2 | unavailable |
| GBM missing required `gbm_create_device` symbol | `false` | 2 | `IsLoaded()` rejects missing requirement |
| GBM required providers/symbols present | `true` | 2 | one-time second call returns cached result with no additional `dlopen` |

**Fail-closed safeguards:** original source Git object and checked-out bytes must match the source used by the compiled full browser; the source extract rejects a forged SHA and overwrites; the runtime fixture rejects invalid modes. Tests assert the exact expected loader-call counts, bool results, cleanup/link events, and GBM one-time retry behavior. Earlier workflow [#42545368573](https://github.com/sguzman/vulpra/actions/runs/42545368573) legitimately failed from an invalid CI token expression; it was corrected in [commit `93d3145`](https://github.com/sguzman/vulpra/commit/93d3145cf346abb606c4205909a669afbb2ef7e1), after which both fixtures and workflow lint passed.

## Scope and next evidence

**Verified:** actual original C++ function-body control flow under a controlled mocked absent/present provider, with expected calls to mocked NSPR or `dlopen`/dlsym and selected early returns. This advances beyond the prior source-text checks but **cannot** stand in for actual browser-level or system-native runtime proof.

**Still false/unverified:** dynamic library ABI/provider availability on Ubuntu or EndeavourOS, exact actual instruction argument values, WebDriver triggering of these feature paths, VA-API decoding and software-video fallback, GBM Wayland/dmabuf fallback, indirect/dlsym/FFI graph completeness, remaining feature activation routes, target workstation parity, source-pruning authority, milestone gate six, and release/security readiness.

**Next useful test:** run the actual source-pinned **packaged** browser in an isolated dedicated Weston/Wayland environment with per-process controlled provider denial and explicit evidence of the targeted call occurring; verify browser navigation and rendering after denial, plus explicit negative cases. This requires a browser binary (not retained by the bounded previous artifact run) and must not be claimed from these mock fixtures.

**Overall 61% (Δ+0 pp); M3 5/6 gates (83%), sixth gate still open.**
