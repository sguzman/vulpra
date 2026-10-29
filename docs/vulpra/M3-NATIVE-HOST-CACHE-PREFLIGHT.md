# M3 external host ELF cache crosswalk

**Accepted bounded CI presence audit:** [GitHub Actions run 40947019427](https://github.com/sguzman/vulpra/actions/runs/40947019427) **PASSED**. The bounded JSON artifact `m3-native-host-cache-preflight` (ID **12928349526**) contains both the independently re-extracted historic ELF dependency graph and the host-cache crosswalk.

The input browser was the **normal unomitted historical Vulpra package** originally compiled at source `1683ca67b69389a879717bcd537772c3b40624b6`, fetched from [native package run 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401) with its exact SHA-256 verified. This is not the more recent successfully compiled source `3f9945cb...` or the still-pending packager-replay build. Those provenance boundaries must not be conflated.

## What actually passed

| Observed fact | Result |
| --- | ---: |
| Packaged ELF regular files in original archive | **28** |
| Direct `DT_NEEDED` dependency edges | **268** |
| Unique dependency names | **50** |
| Matched packaged ELF basename/SONAMEs | **14** |
| External names needing system resolution | **36** |
| External names with an x86-64 ELF file candidate in the *CI Ubuntu 24.04* `ldconfig -p` cache | **36** |
| External names without a matching cache file candidate | **0** |
| Host-cache input/parsing safety checks | **11 passed** |
| ELF graph input/archive checks | **8 passed** |

The implementation `ci/m3-native-host-dependency-preflight.py` reads the checksum-verified direct-import graph and `ldconfig -p` output and then uses `readelf -hW` on resolved, regular, host ELF files. It deliberately never calls `ldd`, `dlopen`, invokes the browser or runs any archive ELF code. The checksum-verified underlying direct graph is recomputed in the workflow.

## Explicit limitations

An available file of the correct ELF architecture is **not** proof that a dynamic linker would choose that file, that required symbols and versions resolve, or that every feature would load it successfully. The dynamic loader also considers `RPATH`/`RUNPATH`, symlinks, ABI and version requirements, transitive dependencies, `dlopen`, NSS/graphics plugins and runtime conditions. This inventory uses the installed packages and cache of a **GitHub-hosted Ubuntu 24.04 runner**, **not** the user's EndeavourOS/Arch machine.

The host check does not establish full runtime dependency closure, nor any removal candidate's reachability, necessity, size or safe fallback. An absent match would not alone prove a runtime missing-library failure. The previously passed real Wayland/JS/WebExtension/Nimbus browser smoke is separately scoped to a different source-pinned normal build; it is not silently attributed to this older archive.

**Decision:** retain mandatory GTK/Wayland, X11 fallback, NSS, SQLite, profile, sandbox, crash and extension infrastructure. This result is a useful physical loader-interface submap, **not** approval to prune any additional source or claim compressed-package savings.

**M3 remains 2/6 (33%), Vulpra overall 44%, Δ 0 percentage points.**
