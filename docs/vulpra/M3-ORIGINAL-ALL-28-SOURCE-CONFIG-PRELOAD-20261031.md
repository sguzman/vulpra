# M3 — Original 28-ELF source/build declarations, evaluated configuration, and generated native preload order (2026-10-31)

## Authentic provenance and accepted evidence

Every result below refers to the **same successful original native full-normal build** from `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, compiled archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` (original run [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527)). The source was checked out by its exact historical Git SHA. No modern/upstream source declarations were substituted for the historical build. Scripts use Rust/std-only and export only paths/line numbers, library basenames, and bounded status/count data.

### 1. All 28 compiled ELF file basenames have historical build declarations

[Original source-pinned 28-ELF manifest crosswalk 41209703132 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41209703132), with [workflow lint 41209605532 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41209605532).

The compiled archive was SHA verified, its 28 regular ELF files identified by actual ELF magic, unique safe basenames checked, and **each one** mapped to one exact unique declaration in its pinned build source. The machine-readable artifact contains per-original-binary source path, exact source line and declaration class. This includes:

| Original native ELF group | Original source/build declaration |
|---|---|
| `vulpra`, `vulpra-bin` | `browser/app/moz.build` — configured application `GeckoProgram` names |
| `libxul.so` | `toolkit/library/moz.build` — Gecko shared `xul` |
| `libmozgtk.so`, `libmozwayland.so` | `widget/gtk/mozgtk/moz.build`, `widget/gtk/mozwayland/moz.build` |
| `libmozsandbox.so` | `security/sandbox/linux/moz.build` |
| `libmozavcodec.so`, `libmozavutil.so` | Two ffvpx `SharedLibrary` declarations |
| `libgkcodecs.so`, `liblgpllibs.so` | Two `config/external` Gecko shared-library declarations |
| `libmozsqlite3.so` | `config/external/sqlite/moz.build` — shared-library output name |
| `libnspr4.so`, `libplc4.so`, `libplds4.so` | Three NSPR `config/external/nspr` declarations |
| `libnss3.so`, `libnssutil3.so`, `libssl3.so`, `libsmime3.so`, `libsoftokn3.so`, `libfreeblpriv3.so` | Six separate original NSS `manifest.mn` output names, respecting their own NSS sub-build rather than pretending they are direct Firefox `moz.build` targets |
| `libmozinference.so` | `config/external/mozinference/moz.build` |
| `libonnxruntime.so` | `toolkit/components/ml/moz.build` — conditional `ONNX_RUNTIME` imported runtime file, *not* a demonstrated locally compiled ONNX library |
| `libclearkey.so` | `media/gmp-clearkey/0.1/moz.build` |
| `crashhelper`, `crashreporter`, `gfxtest`, `pingsender`, `updater` | Their original protected Gecko/C++/Rust native program build declarations |

**Important:** this is a validated historical *declaration-origin* map, not the evaluated generated Ninja graph, complete intermediate FFI/caller dependency graph, or confirmation that every conditional branch was active. A declaration anchor alone does not authorize removing a binary.

### 2. Seven critical features actually had evaluated original configure assertions

[Original compiled `config.statusd` assertion provenance 41210034120 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41210034120), [workflow lint 41209989806 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41209989806).

This separately authenticated exact successful original build **run 40997075527**, its `full-normandy-baseline` job, and the successful **configure, native compile, and package** steps. A second pinned-source check verified the corresponding original workflow's assertion code reads the *evaluated* `obj-vulpra-linux-m3-baseline/config.statusd/substs` and would fail if any of these values were wrong:

| Evaluated original build setting | Verified requirement |
|---|---|
| `MOZ_NORMANDY` | Enabled |
| `MOZ_WIDGET_TOOLKIT` | `gtk` |
| `MOZ_APP_BASENAME` | `Vulpra` |
| `MOZ_DEVTOOLS` | `all` |
| `MOZ_SANDBOX` | Enabled |
| `MOZ_WAYLAND` | Enabled |
| `MOZ_SERVICES_SYNC` | Enabled |

The pinned baseline `mozconfig` was also authenticated as the protected full-normal (not Normandy-omitted experiment) configuration. Other conditional values such as `ONNX_RUNTIME`, NSS sub-build options and arbitrary generated build graph edges were **not** retrospectively inferred from the seven passing assertions.

### 3. Actual compiled generated `dependentlibs.list` matches protected Wayland preload order

[Original compiled native preload order 41210245353 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41210245353), [global workflow lint 41210195980 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41210195980).

The same SHA-verified original package contains an actual **14-item generated `dependentlibs.list`**, not a guessed or recreated text list. Every listed library was independently checked to exist as a regular packaged file. Exact historical `toolkit/library/moz.build` and `toolkit/library/build/moz.build` source declarations were also checked for the generated-list mechanism and the special GTK-before-Wayland requirement.

The original generated order was:

1. `libnspr4.so`
2. `libplc4.so`
3. `libplds4.so`
4. `libmozsandbox.so`
5. `libgkcodecs.so`
6. `liblgpllibs.so`
7. `libnssutil3.so`
8. `libnss3.so`
9. `libsmime3.so`
10. `libmozsqlite3.so`
11. `libssl3.so`
12. **`libmozgtk.so`**
13. **`libmozwayland.so`**
14. **`libxul.so`**

This validates a real generated **feature/binary load-order dependency**: source comments require loading `mozgtk` before `mozwayland` before Gecko to preserve the dynamic Wayland/GTK interaction. No library in this list may be assumed removable merely because it has no startup symbol binding.

## Explicit remaining boundary

This round materially improves all-28 ELF **historical source declaration ownership**, confirms **seven actual configured build settings**, and authenticates the compiled **14-library preload list**. But the M3 final acceptance gate requires a **complete feature bundle / generated build / native runtime and platform dependency map**. Full evaluated Ninja/FFI/caller graph, arbitrary `dlopen` feature reachability, exact current checkout feature state, cross-platform comparisons, and end-to-end original rare feature workflows remain incomplete.

No installed Vulpra/Firefox profiles were modified, no source was removed or browser rebuilt, no package-size reduction was observed. **Overall 61%; M3 83% (5/6 gates); session Δ0 percentage points.**
