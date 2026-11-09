# Compiled-source GBM and DRM required versus optional runtime symbols — 2026-11-09 UTC

**Accepted targeted source-function fixture:** [M3 Real CXX Source Loader Missing-Provider Fixtures #42548875293 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42548875293), [real artifact **13644671467**](https://github.com/sguzman/vulpra/actions/runs/42548875293/artifacts/13644671467), [workflow lint #42548875468 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42548875468). Original artifact JSON was downloaded and independently inspected: **28/28 scenarios; 25 guarded failure outcomes, 3 success outcomes; no mismatches**, with original browser-executed and M3-gate-closed flags explicitly false.

The original C++ functions `GbmLib::IsLoaded()` and `GbmLib::Load()` were **extracted verbatim and compiled into a standalone provider-mocking fixture**. Source Git objects were authenticated against the actual previously successful native build `bd2499aeadce0368faa8b717b0e8a17e9c9dc317`, including [`widget/gtk/DMABufDevice.cpp`](../../widget/gtk/DMABufDevice.cpp) at Git blob `4fd08d1453edac94bc96deb9a5ed0efcb27dad91`. Each case runs in a new process, and the fixture confirms its targeted `dlsym` name was actually requested by the original loader.

## All 18 symbols required by the real `GbmLib::IsLoaded()`

| Required `dlsym` name | Provider |
| --- | --- |
| `gbm_create_device` | `libgbm.so.1` |
| `gbm_device_destroy` | `libgbm.so.1` |
| `gbm_bo_create` | `libgbm.so.1` |
| `gbm_bo_create_with_modifiers` | `libgbm.so.1` |
| `gbm_bo_get_modifier` | `libgbm.so.1` |
| `gbm_bo_get_stride` | `libgbm.so.1` |
| `gbm_bo_get_fd` | `libgbm.so.1` |
| `gbm_bo_destroy` | `libgbm.so.1` |
| `gbm_bo_map` | `libgbm.so.1` |
| `gbm_bo_unmap` | `libgbm.so.1` |
| `gbm_bo_get_plane_count` | `libgbm.so.1` |
| `gbm_bo_get_handle_for_plane` | `libgbm.so.1` |
| `gbm_bo_get_stride_for_plane` | `libgbm.so.1` |
| `gbm_bo_get_offset` | `libgbm.so.1` |
| `gbm_device_is_format_supported` | `libgbm.so.1` |
| `drmPrimeHandleToFD` | `libdrm.so.2` |
| `gbm_surface_create` | `libgbm.so.1` |
| `gbm_surface_destroy` | `libgbm.so.1` |

The real source initializes 19 named dynamic symbol pointers in `GbmLib::Load()`; `GbmLib::IsLoaded()` requires **exactly the 18 above** nonnull. The 19th symbol, **`gbm_bo_create_with_modifiers2`**, is intentionally **not** in that required readiness set.

The mock-provider runtime tests include the original `gbm-no-symbol` mode for missing `gbm_create_device`, plus 17 additional one-at-a-time missing-required-symbol cases, all of which yielded `false` in the actual original `GbmLib::Load()`. The separately tested missing `gbm_bo_create_with_modifiers2` mode returned `true` for **initial `GbmLib::IsLoaded()` readiness**, exactly as the source dictates. Other VA-API and missing GBM/DRM-library guards account for the remaining scenarios in the 28 total.

## Optional-symbol consumer and next test boundary

The actual compiled-source [`widget/gtk/DMABufDevice.h`](../../widget/gtk/DMABufDevice.h) at Git blob `6ec965c96846bc09050b1567ef042228d59cdd1c` contains an inline `GbmLib::CreateWithModifiers2` wrapper. It checks `if (!sCreateWithModifiers2)` and, when the new symbol is missing, **calls `sCreateWithModifiers` instead** (the older required API). Actual source consumers in [`widget/gtk/DMABufSurface.cpp`](../../widget/gtk/DMABufSurface.cpp), unchanged source blob `105522389ad55ed0d139ca6ac738cc6831f82376`, call `GbmLib::CreateWithModifiers2` for modifier-based RGBA/YUV buffer creation.

**Important distinction:** This is a source-confirmed intended fallback and a fixture-confirmed optional *initial loader readiness* case. The fallback wrapper's old-API call itself, real DMABuf creation, GPU compatibility, compositor behavior and absence of crashes under missing modifiers2 have **not** been exercised or proven by the 28-mode fixture. A further source-body test should execute the inline old-API fallback and a separate true packaged-browser graphical workload must verify the real graphics behavior.

The earlier [10-case source-function report](M3-CURRENT-CXX-LOADER-MOCK-PROVIDER-RUNTIME-20261109.md) remains an accurate record of that earlier run; the **28-case result supersedes its scope**, not the historical tests. The actively running full-native [#42546880350](https://github.com/sguzman/vulpra/actions/runs/42546880350) is source-pinned to `d7bf1cb73b384df047871d6b8c608312eb6cb5b4` and tests optional-provider headless browser loads only **after** its normal compilation finishes. Its result is **not yet accepted** in this ledger.

**No extra source removal or release. M3 remains 5/6 (83%). Overall 61%, Δ+0 pp.**
