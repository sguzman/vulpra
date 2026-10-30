# M3 — Private Weston native SIGSEGV investigation (2026-10-30)

## Protected baseline and scope

This investigates the **original full-Normandy, x86-64 native Vulpra** package compiled from source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` (successful build [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527)). The verified 87,154,544-byte tar.xz has SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The standard `packaging/test-wayland.sh` uses a disposable HOME/profile and private Weston headless compositor on Ubuntu 24.04; none of these probes touches the user's Arch/Hyprland browser or installed Firefox Developer Edition.

The required acceptance remains **10 seconds of process survival plus a non-null Wayland buffer attach and commit on the same surface**. Shortened or instrumented runs are *diagnostics only*.

## Reproduced observations

| Evidence | Result |
| --- | --- |
| [41117899170](https://github.com/sguzman/vulpra/actions/runs/41117899170) | Uninstrumented native private Weston startup failed mandatory ten-second survival, process exit 11. Protocol log had repeated non-null wl_buffer attach/commit events, but the final acceptance assertion was not reached. |
| [41131721765](https://github.com/sguzman/vulpra/actions/runs/41131721765) | Original ten-second test failed again at exit 11. Independent disposable profiles at 2, 5, and 8 seconds all failed at exit 11. An altered diagnostic with crash reporter disabled, otherwise retaining private Weston and MOZ_DISABLE_NONLOCAL_CONNECTIONS=1, exited **139** at ten seconds, consistent with POSIX SIGSEGV (11). These separate trials do not locate the exact elapsed crash time. |
| [41132264823](https://github.com/sguzman/vulpra/actions/runs/41132264823) | Separate GDB probe, same checked original archive with private explicit profile, detected **SIGSEGV**; its first 15 frames are from **libxul.so**, with function names unavailable in the stripped distribution build. Workflow lint [41132264822](https://github.com/sguzman/vulpra/actions/runs/41132264822) passed. GDB's own process exit 0 is *not* a browser or graphical acceptance pass. |
| [41116477542](https://github.com/sguzman/vulpra/actions/runs/41116477542) | The same exact package independently passed a **headless** about:newtab/ASRouter runtime check. This does not exercise native Weston graphics. |
| [40963098075](https://github.com/sguzman/vulpra/actions/runs/40963098075) | An earlier full-native source `cde4d830` passed ten-second private Weston + browser runtime acceptance in its own compile job. |

## Source comparison and limits

The Git comparison `cde4d83043f8c476173c8dbc78b66b078c3f6b5b...b1482404dfb8b01342990ee99ea3df0f9756b5f7` has **88 commits and 28 changed files**, all under `.github/`, `ci/`, and `docs/`; there are no intervening browser-engine source modifications. This makes a direct browser source change an unlikely explanation, but the two accepted native packages were **not** rebuilt together with an identical toolchain, process environment and build artifacts. It does not prove that their executable bytes, compiler configuration, host libraries or runtime behavior are equivalent.

The separate GDB probe uses the native executable directly with the same private-profile arguments, rather than the shell wrapper, and can change timing/sandbox interaction. The crash is localized only to the **stripped libxul library**, not a function or source line. Raw debugger output was retained only inside a disposable CI directory and deleted; only sanitized symbol/module summaries appear in CI logs.

## Additional null-address fault confirmation (2026-10-30)

In [CI 41133073378](https://github.com/sguzman/vulpra/actions/runs/41133073378), corrected position-aware GDB diagnostics showed **SIGSEGV**, memory address **exactly null (0x0)** and fault code **SEGV_MAPERR**, with the first 15 frames in stripped `libxul.so`. The original ten-second graphical acceptance **still failed**. A prior diagnostic incorrectly interpreted three numeric GDB booleans/code values as three independent signal codes; the replacement parser reads the first two boolean checks and third `si_code` in order. `ci/m3-wayland-gdb-sanitize.awk` plus `ci/tests/m3-wayland-gdb-sanitize-test.sh` now verify numeric and textual GDB output, two fault classes, sanitization of paths/addresses/arguments, and incomplete traces. This is fault classification, **not** a resolved source function or accepted graphical run.

### Final CI replay of diagnostic parser and original crash

[Live native test 41133467657](https://github.com/sguzman/vulpra/actions/runs/41133467657) **PASSED** the new synthetic fault-classification/privacy fixtures in the initial preflight, then reproduced the actual original 10-second Wayland exit **11**, the separate crash-reporter-disabled exit **139**, and GDB **SIGSEGV** at unmapped address **0x0** in `libxul.so`. The workflow's overall **FAILURE** is intentional under the preserved acceptance policy: a crash cannot be reclassified as a passing graphical browser.

Independent checks passed on the committed fixture revision: [workflow lint 41133467638](https://github.com/sguzman/vulpra/actions/runs/41133467638), [candidate boundaries 41133467616](https://github.com/sguzman/vulpra/actions/runs/41133467616), [source/build safety 41133467607](https://github.com/sguzman/vulpra/actions/runs/41133467607). M3 **5/6 (83%)**, overall **61%**, delta **+0 percentage points**.

## Next acceptance work

1. Recover source-matched native debug symbols or a dedicated symbolized diagnostic build, then identify the crashing libxul function and validate a real fix; retain sandboxing and profile protection.
2. Compare two independently verified native builds under **one** controlled private Weston runtime/toolchain before attributing a source, build or environmental regression. The earlier run preserved only bounded link evidence, not its whole package archive for immediate reuse.
3. Rerun the untouched ten-second same-surface graphical acceptance followed by protected New Tab, JavaScript navigation, WebExtension, and dependency checks. Do not count an instrumented or shortened run as a pass.

**Gate result: M3 remains 5/6 (83%), overall 61%, delta 0 pp.** No new pruning, measured saving, user-machine regression claim, or whole dynamic feature-graph completion.
