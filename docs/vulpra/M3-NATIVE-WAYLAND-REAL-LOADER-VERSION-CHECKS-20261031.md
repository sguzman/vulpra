# M3 — Real original Wayland browser loader version checks (2026-10-31)

## Authenticated native binary and runtime contract

[Native glibc loader version-check CI 41157865349 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41157865349), sanitized artifact **13025557030**. The job authenticates original compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, archived full-normal native browser SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, and the independent [519 source-pinned ELF VERNEED name contracts CI 41157293087](https://github.com/sguzman/vulpra/actions/runs/41157293087), artifact **13025696998**.

The actual checksum-pinned Vulpra browser is launched on ordinary Ubuntu 24.04 CI under a private headless-backend Weston compositor, but **not Gecko headless mode**. It passes the original mandatory **ten seconds** of native process survival, isolated browser-created profile and non-null Wayland `wl_buffer` attach followed by `wl_surface.commit` on the same surface, both **untraced** and again with `LD_DEBUG=versions`. The strict `MOZ_DISABLE_NONLOCAL_CONNECTIONS=1` remains active, while the **test browser alone** opts into `XRE_START_OFFLINE=1` to avoid background HTTP test-mode crashes. No installed Firefox/Vulpra user profile is accessed.

Only trace PID files that **actually initialize `libxul.so`** are accepted. Raw trace paths, PIDs, environment, bytes and addresses are discarded after parsing; output includes only approved source-version/provider/requester basenames and counts. Browser-only `LD_DEBUG=versions` is an opt-in trace kind; the default existing `LD_DEBUG=libs,files` no-egress network-namespace dependency mapping is preserved. Regressions [Wayland harness 41157820060](https://github.com/sguzman/vulpra/actions/runs/41157820060), [original host actual loader 41157820083](https://github.com/sguzman/vulpra/actions/runs/41157820083), [normal online no-egress netns loader 41157820067](https://github.com/sguzman/vulpra/actions/runs/41157820067), and [workflow lint 41157865389](https://github.com/sguzman/vulpra/actions/runs/41157865389) all passed independently.

## Real source-to-loader check reconciliation

| Declared original-compiled ELF version-name requirement tuples | Count |
| --- | ---: |
| **Total source-pinned original package VERNEED triples** | **519** |
| Seen as actual `glibc` loader `checking for version` in real browser PID traces | **336** |
| Not observed in this ten-second `about:blank` startup | **183** |

All **183** absent original requirement triples belong to just **nine** packaged module/executable basenames:

| Original ELF member basename | Original version-name requirements not checked |
| --- | ---: |
| `crashhelper` | 27 |
| `updater` | 27 |
| `libmozinference.so` | 24 |
| `pingsender` | 22 |
| `vulpra-bin` | 21 |
| `crashreporter` | 20 |
| `libonnxruntime.so` | 20 |
| `libclearkey.so` | 14 |
| `gfxtest` | 8 |
| **Total** | **183** |

This **does not mean those modules can be removed**. Crash handling, updating, ping submission, machine-learning inference, ClearKey media playback and graphics diagnostics each have separate activation triggers. An about:blank opening is neither those triggers nor a test of their dependent functionality. The unobserved `vulpra-bin` ELF is a separate archive member, not evidence that the running Vulpra native executable was absent. It would be unsafe to infer unused code or a deletable library from this list.

Separately the real three-browser-PID traces reported **1,064 distinct additional** `(requester basename, provider basename, version name)` checks beyond the original archive's 519 direct contracts. They include Ubuntu host transitive dependencies, GTK/audio/media libraries and the Bash launcher; an `LD_DEBUG` trace may include wrapper and native exec stages under one PID. Those extra checks are not 1,064 independently browser-required binaries and do not prove complete runtime resolution.

## Accepted result and explicit gaps

This extends static [original per-symbol candidate matching](M3-NATIVE-ELF-VERSIONED-SYMBOL-CANDIDATES-20261031.md): **4,611** versioned undefined imports found candidate exported names, including **603** compatible modern-glibc libc name/version candidates. The **present live check** supplies real loader-observed *version-lookup* evidence for **336** distinct original VERNEED triples, not proof of individual relocation bindings or the lazy functions exposed by the nine inactive modules. It does not inventory unversioned symbols, full host library selection rules, all source build options, all `dlsym`/`dlopen` routes, other platforms or the target Arch/Hyprland workstation.

**Still M3 5/6 (83%), overall product 61%, per-round +0pp.** No additional source pruning, package saving, default feature change or final broad dependency gate closure is authorized.
