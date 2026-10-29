# M3 package-wide native ELF direct-dependency graph

**Observed actual binary evidence:** [Native archive graph CI 40931403992](https://github.com/sguzman/vulpra/actions/runs/40931403992) **PASSED** (bounded machine-readable artifact `m3-native-elf-package-graph`, ID **12923300697**). It inspected each regular ELF file from the previously checksum-verified, **full normal Linux Vulpra** `tar.xz`, originally compiled at source commit `1683ca67b69389a879717bcd537772c3b40624b6`. Eight tamper/metadata safety fixtures passed. The inspector never executed native code, called `ldd`, followed archive symlinks, edited source, or invoked the compiler.

| Verified archive measurement | Result |
| --- | ---: |
| Compressed full normal browser archive | **86,930,792 B** |
| Outer tar regular-file members | **47** |
| Outer regular-file logical total | **339,565,212 B** |
| Regular **ELF** native members parsed | **28** |
| Direct dynamic-library `DT_NEEDED` edges across those 28 files | **268** |
| Distinct direct `DT_NEEDED` names | **50** |
| Matching regular packaged ELF basename or SONAME | **14** |
| Only matched archive link declarations | **0** |
| No matching package ELF/member, external loader resolution needed | **36** |

The **14** matched packaged library names are `libgkcodecs.so`, `liblgpllibs.so`, `libmozavutil.so`, `libmozgtk.so`, `libmozsandbox.so`, `libmozsqlite3.so`, `libmozwayland.so`, `libnspr4.so`, `libnss3.so`, `libnssutil3.so`, `libplc4.so`, `libplds4.so`, `libsmime3.so` and `libssl3.so`. The prior [`libxul.so`-only scan](M3-NATIVE-ELF-DEPENDENCIES.md) observed **49** names and **13** matching packaged files; inspecting the other ELF modules added `libmozavutil.so` and changed the full-graph totals, **not** the single-library result.

The **36** external-resolution names include GTK/GDK/Pango/Cairo/GLib, X11/XCB, ALSA, fonts, C/C++ runtime, DBus and other system libraries. **Absent from tarball is not equivalent to absent at runtime.** No target machine's libraries, ABI versions or search paths were checked.

## What this does and does not close

The census records *every package-regular ELF's direct loader declarations* and groups package presence by names. This is materially broader than reading the one largest `libxul.so`. The output contains requesting ELF path, requested library name and any matching physical archive members, plus member SHA-256. It is enough to identify the **direct native package interface**, including the mix of bundled Mozilla libraries and system dependencies.

It is **not** a complete runtime dependency graph: host libraries themselves can depend on other host libraries; components may be loaded by `dlopen`, Firefox resource modules may import JS dynamically, archive links are not resolved, and actual loader resolution can depend on RPATH, environment and installed ABI. No test on the user's Arch/Wayland system is implied.

It also cannot apportion bytes among Firefox optional features. A library's size, ELF section length or direct edge count is **never** an estimate of safe removable bloat.

## Next engineering boundary

The source-side native/Rust/GTK crosswalk is [here](M3-NATIVE-FEATURE-DEPENDENCIES.md), and the original selected compiled configuration attestation is [here](M3-HISTORICAL-BUILD-CONFIG-PROVENANCE.md). Closing the **complete feature/binary dependency gate** still requires exact-current-source configuration evidence and native build/link-map output, plus a separate runtime loader/Wayland/browser smoke for any later candidate omission. Preserve core GTK+Wayland, NSS, SQLite, sandbox, profile, WebExtensions and privacy deletion paths.

**Progress:** evidence subtask completed; full M3 gate remains open. **M3 2/6 (33%), overall 44% (Δ 0 pp).**
