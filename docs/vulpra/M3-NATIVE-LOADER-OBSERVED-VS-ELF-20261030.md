# M3 — Actual Linux native dynamic loader versus ELF declarations (2026-10-30)

**Accepted new read-only / native runtime evidence**, on the already compiled
full-normal Linux Vulpra package. Source:
`b1482404dfb8b01342990ee99ea3df0f9756b5f7`;
original [successful full-Normandy build 40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527).
Original 87,154,544 B archive checksum:
`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

## 1. Two independently authenticated kinds of evidence

1. [Source-pinned physical ELF and resource inventory 41077783489](https://github.com/sguzman/vulpra/actions/runs/41077783489)
   **PASSED**, artifact **12988211924**: inspect each of 28 actual
   packaged ELF binaries, read `DT_NEEDED`, inventory direct import
   relationships and 14 physically packaged names. This is a **read-only
   static declaration scan** and never runs the browser.
2. [New real GNU loader observation 41116477542](https://github.com/sguzman/vulpra/actions/runs/41116477542)
   **PASSED**, artifact **13006262063**. Reuses exactly the SHA-256
   authenticated normal archive and actually launches Vulpra headlessly
   against `about:newtab`, using disposable profiles and the previously
   tested inert ASRouter/New Tab bridge. The launcher inherits
   `LD_DEBUG=libs,files` and isolates glibc logs per process.
   `ci/m3-native-loader-runtime-observation.py` accepts only bounded
   numeric-PID traces containing `libxul.so` plus real glibc
   `calling init` events. **Seven trace files inspected**; **two**
   had actual Vulpra `libxul.so` evidence and yielded **94 distinct
   initialized library basenames**. Only sanitized basenames, counts
   and deliberately false completeness flags were saved; raw logs,
   PIDs, user paths and temporary profiles were discarded.
3. [Independent exact-archive ELF-versus-loader reconciliation 41116837335](https://github.com/sguzman/vulpra/actions/runs/41116837335)
   **PASSED**, artifact **13006511493**; [workflow lint
   41116837228](https://github.com/sguzman/vulpra/actions/runs/41116837228)
   **PASSED**. Its source-pinned
   `ci/m3-native-loader-static-reconciliation.py` rejects **12**
   deliberately corrupted archive/source/count/library/completeness
   inputs. This is a separate acceptance of *aggregate observed names
   versus declared names*, not an invented per-edge resolution.

## 2. Real observed results for one normal headless workload

| Meaning | Authenticated count |
| --- | ---: |
| Packaged ELF regular files (static) | **28** |
| Total packaged ELF direct `DT_NEEDED` edges (static) | **268** |
| Distinct direct required library names in all packaged ELF files | **50** |
| Direct required names *also observed somewhere* in the real loader's two browser traces | **50 / 50** |
| Required names provided by a physically packaged ELF | **14 / 14 observed** |
| Required direct names absent from outer packaged ELF (need host resolution) | **36** |
| All distinct library basenames the loader initialized in the observed browser traces | **94** |
| Observed names **not** in any direct packaged ELF `DT_NEEDED` list | **44** |
| Browser-process traces referencing native `libxul.so` | **2** |

Representative initialized basenames included `libmozgtk.so`,
`libmozwayland.so`, `libxul.so`, `libnss3.so`,
`libmozsandbox.so`, `libwayland-client.so.0`,
`libgtk-3.so.0`, `libasound.so.2`, and `libc.so.6`.
The presence of `libwayland-client.so.0` in a headless smoke **does
not establish Wayland compositor/session acceptance**; separate
Weston-based browser tests provide that evidence.

The **44 additional names** include host/transitive libraries such as
`libXau.so.6`, `libepoxy.so.0`, `libharfbuzz.so.0`,
`libwayland-client.so.0`, and media support
`libmozavcodec.so`. An observed name outside the direct list
could arise through **transitive host dependencies, `dlopen`, NSS/
font/GTK plugins, or another initialization route**. Do not attribute
all 44 to `dlopen` without the loader's actual requester/namespace
edge information and separately scoped runtime evidence.

## 3. Explicit non-claims and next safe work

- A basename appearing during one WebDriver workload does not prove
  every **individual** `DT_NEEDED` edge for each ELF can be
  resolved in the right library namespace, search order or ABI.
- The trace does not capture unexecuted feature branches, all runtime
  `dlopen`/plugin scenarios, user-installed extensions, content
  codecs, remote services, or on-demand graphics features.
- The observed host was **Ubuntu 24.04 x86-64 GitHub Actions**.
  It is not the target Arch/EndeavourOS + Hyprland/Wayland workstation,
  and does not establish that workstation's dependency compatibility.
- No full C/C++/Rust source-to-linker-to-feature reverse call graph,
  `GLIBC_*/GLIBCXX_*` ABI version closure, XPCOM/JS dynamic
  consumer coverage, or exact current-`main` newly compiled browser
  exists from this test.
- Browser source, default prefs, user profile, security modules and
  permanent/opt-in feature candidates were not modified. There is
  **no new source removal, compiled byte saving or combined size claim**.

This independently improves the *last open* M3 feature/build/binary
dependency-map gate, but **cannot close it**. Retain the current normal
browser; further work should focus on *per-feature* runtime/actor
relationships, generated link graph, loader namespaces, conditional
features, and a separate target-Linux QA environment. No further
feature removal can be authorized from counts alone.

**Progress at this evidence checkpoint: M3 5/6 gates (83%), Vulpra
overall 61%, Δ0 percentage points for this subtask.**
