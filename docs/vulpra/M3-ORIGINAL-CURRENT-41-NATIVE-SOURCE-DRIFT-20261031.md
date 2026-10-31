# M3 — Original vs current native source build/feature boundary drift (2026-10-31)

[**Exact original-to-current native source drift CI 41210567100 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41210567100), [global workflow lint 41210567143 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41210567143). The original successful compiled source run [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527) was authenticated against original commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, which produced original compiled native archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

The small Rust std-only audit `ci/m3-original-to-current-native-feature-source-drift.rs` inspected **two separate exact Git checkouts**: the immutable original source SHA and the current `main` HEAD at workflow execution. It read and compared actual file bytes without attempting to evaluate or mutate `moz.build`, user profiles or the browser.

| Compared exact-source set | Files checked | Byte-changed | Missing in current checkout |
|---|---:|---:|---:|
| Unique source manifests that declare all 28 original native ELF output names | **27** | **0** | **0** |
| Protected feature boundary sources (native toolkit, GTK/Wayland, core Gecko/Rust, telemetry, Sync, DevTools, New Tab and GenAI) | **14** | **0** | **0** |
| **Unique paths** | **41** | **0** | **0** |

This corroborates and narrows the uncertainty in [all 28 original ELF output declaration mapping](M3-ORIGINAL-ALL-28-SOURCE-CONFIG-PRELOAD-20261031.md): all its 27 exact historical build-manifest paths are byte-identical in current `main`, while 14 central protected feature-boundary file sources also match. The original successful compile had additionally evaluated seven key `config.statusd` feature assertions, and the original archive's generated 14-member `dependentlibs.list` remains provenance-authenticated.

An additional direct pinned-vs-current Git blob comparison confirms that `ci/mozconfig-linux-m3-baseline` is also **identical**, with blob SHA `6e9731c0c1ac1e74ec29f891b2bdcf0eef207b06` in both checkouts. This is a separate file-level SHA check, not one of the 41 CI-audited feature/source paths, and not a newly evaluated `config.status` run.

**Limits:** This is not proof that the *entire* current Firefox tree equals the original compiled source. It does not validate generated Ninja files or every imported C++/Rust function, all intermediate `moz.build` inclusion paths, resolved configuration values for a *new* current-source build, all future dynamic `dlopen`/lazy dependencies, or the target Arch/Hyprland host ABI. New scripts, CI workflows, docs and source files *outside these exact 41 paths* can differ. In particular, no new current-source binary was built by this audit. Current source paths matching original ones is not permission to remove source, browser libraries or features.

**Progress:** M3 still **5/6 (83%)**, overall Vulpra **61%**, session **Δ0 percentage points**, no source removals, package-size savings or browser/profile changes.
