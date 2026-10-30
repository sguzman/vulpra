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

## Controlled environment comparisons (2026-10-30)

The unchanged, SHA-256-pinned original native archive has now been exercised in two independently constrained settings, without changing Firefox source or the user's installed profile.

- [Historical/current harness A/B 41134954781](https://github.com/sguzman/vulpra/actions/runs/41134954781): historical `b1482404` harness **FAIL** and current `main` harness **FAIL**, both using the exact same compiled archive and original 10-second private Weston contract on one Ubuntu runner. The only observed historical/current harness changes were opt-in loader environment injection and improved early-exit diagnostics. This does not establish a browser-engine regression or a successful native graphical run.
- [Original empty-network-namespace probe 41135199262](https://github.com/sguzman/vulpra/actions/runs/41135199262): original archived browser **PASS** for the full 10-second private Weston contract under `sudo unshare --net`/unprivileged `runuser` with `MOZ_DISABLE_NONLOCAL_CONNECTIONS=1`; also **PASS** in the same namespace with the flag unset. Both probes have no default external network routes, disposable HOME/profiles and no changed browser binary.
- [Independent namespace repeat 41135294175](https://github.com/sguzman/vulpra/actions/runs/41135294175): both network-namespace probes **PASS** again. These probes alter multiple conditions (namespace, launch through privilege drop and inherited environment), so the network flag cannot be identified as causal from these observations.
- [Launch-context controlled matrix](https://github.com/sguzman/vulpra/actions/workflows/m3-wayland-launch-context-matrix.yml) now tests unmodified runner environment, scrubbed inherited variables, runuser on host networking and runuser inside a no-egress namespace using a common SHA-verified binary. **No matrix outcome is credited until actual CI has finished.**

**Interpretation:** A reproducible SIGSEGV in the original Ubuntu CI launch **is not inevitable for the original native binary**: the same checksum-pinned executable can pass real graphical frame and liveness checks in a different isolated environment. This is a diagnostic clue, not a resolved root cause, not a claim about the user's Arch/Hyprland workstation and not the complete M3 feature/build/ABI map. M3 remains **5/6 (83%)**, overall **61%**, session progress **+0 pp**.

## Controlled launch-context matrix: namespace boundary confirmed

[Initial matrix 41135404840](https://github.com/sguzman/vulpra/actions/runs/41135404840) and [independent shared-helper replay 41135492848](https://github.com/sguzman/vulpra/actions/runs/41135492848) both executed **the exact same SHA-256-pinned original native package, same 10-second frame/liveness contract and fresh disposable profiles** on Ubuntu 24.04.

| Launch context | Initial | Repeat |
| --- | --- | --- |
| Ordinary GitHub runner, nonlocal connections disabled | **FAIL**, native exit 11 | **FAIL**, native exit 11 |
| Scrubbed inherited variables, same UID/host network | **FAIL**, native exit 11 | **FAIL**, native exit 11 |
| `runuser` under host network, restricted connections | **FAIL**, native exit 11 | **FAIL**, native exit 11 |
| `runuser` in loopback-only network namespace, restricted connections | **PASS**, real 10s Weston check | **PASS**, real 10s Weston check |

The source contract and archive are unchanged; the successful combination requires an isolated Linux network namespace. Environment scrubbing and changing the launch user **alone are insufficient**. This points to a network-namespace-related runtime condition but **does not prove** which network interface, route, notification or kernel-state difference is causal. The independent controlled `ci/m3-wayland-netns-launch.sh` refuses namespaces with additional interfaces or routes. [Workflow lint 41135492709](https://github.com/sguzman/vulpra/actions/runs/41135492709) **PASS**; network namespace [41135492695](https://github.com/sguzman/vulpra/actions/runs/41135492695) **PASS**.

A further [disconnected-interface topology test](https://github.com/sguzman/vulpra/actions/workflows/m3-wayland-private-network-topology.yml) compares loopback down, loopback up, and a synthetic dummy interface without host or internet access. **That test's outcome must be checked separately before assigning a cause.**

**Acceptance remains open:** the original ordinary-runner compiled browser still crashes. The network-namespace pass is a real native graphical result in a special test environment, not acceptance for the target Arch/Hyprland workstation and not a completed feature/build/binary dependency graph. M3 **5/6 (83%)**, overall **61%**, round **Δ0 pp**.

## Next acceptance work

1. Recover source-matched native debug symbols or a dedicated symbolized diagnostic build, then identify the crashing libxul function and validate a real fix; retain sandboxing and profile protection.
2. Compare two independently verified native builds under **one** controlled private Weston runtime/toolchain before attributing a source, build or environmental regression. The earlier run preserved only bounded link evidence, not its whole package archive for immediate reuse.
3. Rerun the untouched ten-second same-surface graphical acceptance followed by protected New Tab, JavaScript navigation, WebExtension, and dependency checks. Do not count an instrumented or shortened run as a pass.

**Gate result: M3 remains 5/6 (83%), overall 61%, delta 0 pp.** No new pruning, measured saving, user-machine regression claim, or whole dynamic feature-graph completion.
