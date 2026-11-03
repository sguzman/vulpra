# M3 — Original Vulpra browser live mapped ELF inventory on private Arch/Wayland (2026-11-03)

## Verified original source-pinned graphical browser workload

**Accepted [native CI 41658199812 — PASS](https://github.com/sguzman/vulpra/actions/runs/41658199812)**, job **125994092134**, artifact **13240906966** (`m3-original-archlinux-weston-real-native-loader-initializers`). Preceding [full native 41657809770 — PASS](https://github.com/sguzman/vulpra/actions/runs/41657809770) had already passed the private frame, proc-map observer, and negative crosswalk mutations; a subsequent **library-name precision fix** excluded the mapped loader cache file `ld.so.cache`, which is *not* a shared ELF library. This report credits the **corrected final run** for all numerical counts. GitHub Actions workflow lint [41657448677 — PASS](https://github.com/sguzman/vulpra/actions/runs/41657448677) covered the new workflow wiring. The first test attempt **41657448640** was **not** accepted: actual browser/proc-map/frame checks passed but a new jq assertion had a syntax error, corrected in `79eecda9`. The cache-filter fix is `470559e1`.

The exact original source commit **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**, packaged archive SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**, and detached original compiled `vulpra` ELF were authenticated and mounted **read-only** into a disposable official Arch Linux userspace. The native browser started a graphical `about:blank` session on an independent headless Weston compositor in **`--network none`**, without X11, a real user profile, or Firefox Developer Edition. Original `packaging/test-wayland.sh` still required actual `wl_surface` non-null buffer attachment and corresponding commit, ten seconds of liveness and an isolated initialized `compatibility.ini` profile. The original glibc `LD_DEBUG=libs,files` parser independently witnessed **103** initialized provider basenames across **seven** loader PID traces, including `libxul.so`, `libmozgtk.so`, and `libmozwayland.so`.

New standalone Rust observer `ci/m3-original-arch-browser-proc-maps.rs` runs as a separate opt-in process beside that unchanged graphical harness. It discovers **only** native browser processes whose actual `/proc/<pid>/exe` resolves under the disposable `/original` package with an approved Vulpra binary name. It samples `/proc/<pid>/maps` for a bounded window without attaching a debugger, modifying browser runtime settings, reading user applications or changing browser code. Only sanitized **basenames** and `package`/`host` classes, plus aggregate counts, are exported; raw paths and PIDs remain private to the ephemeral container. The observer excludes nonshared cache files such as `ld.so.cache`.

## Exact final corrected observation

| Metric | Corrected original native result |
| --- | ---: |
| Process-map samples with original Vulpra processes | **16** |
| Maximum simultaneous original Vulpra processes observed | **12** |
| Distinct original Vulpra processes seen within the sample window | **12** |
| Unreadable browser process map observations | **0** |
| Original-package mapped named objects (shared objects + executable) | **19** |
| Original-package mapped **shared libraries** | **18** |
| Host mapped **shared libraries** | **82** |
| Independently observed loader-initializer basenames (package and host) | **103** |
| Original-package mapped shared libraries with initializer witness | **18** |
| Original-package mapped executable without shared-library initializer witness | **`vulpra` (1)** |
| Intentionally malformed report mutations correctly rejected | **3** |

The **18** original-package shared-library basenames both mapped and initialized are:

`libfreeblpriv3.so`, `libgkcodecs.so`, `liblgpllibs.so`, `libmozavcodec.so`, `libmozavutil.so`, `libmozgtk.so`, `libmozsandbox.so`, `libmozsqlite3.so`, `libmozwayland.so`, `libnspr4.so`, `libnss3.so`, `libnssutil3.so`, `libplc4.so`, `libplds4.so`, `libsmime3.so`, `libsoftokn3.so`, `libssl3.so`, `libxul.so`.

The exported source-pinned artifacts are `original-arch-wayland-frame.json`, `original-arch-loader-witness.json`, `original-arch-browser-proc-maps.json`, and `original-arch-browser-maps-init-crosswalk.json`. The independent reconciliation is implemented in `ci/m3-original-arch-browser-proc-maps-reconcile.jq`. It fail-closed on three deliberate real-report mutations: missing mapped `libxul.so`, altered original archive SHA-256, and a duplicate mapped library basename. The observer's Rust unit tests separately reject `ld.so.cache` and nonshared path suffixes.

## Explicit limits and remaining sixth M3 gate

This is a **time-bounded union of sampled process residency**, not a whole-session or whole-browser call graph. GNU loader initializers and process maps have different semantics; names may initialize then unload before sampling, mapped ELFs may not generate an ordinary shared-library initializer witness (notably the executable), and all missing feature paths remain unknown. **The original package has 28 ELF members**, and only these 19 mapped package objects appeared in one brief private `about:blank` graphical workload; the other nine are **not evidence of unused or safely removable files**. The comparison is by basename and does not prove provider identity, versioned symbols, FFI/late `dlsym`, all conditional `dlopen`, source-to-binary ownership, security features beyond the exercised smoke, or Arch/Hyprland host hardware/GPU behavior. It does not change release readiness or upstream security guarantees.

**M3 remains 5/6 gates = 83%; overall remains 61%; this session Δ +0 percentage points.** No source files or packaged libraries were pruned and no compressed native-package byte savings are claimed. The final feature, build, binary, and dynamic-dependency closure gate remains open.

