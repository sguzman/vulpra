# M3 — Headless and real Wayland native loader name overlap (2026-10-30)

## Authenticated provenance

These are **two real, distinct runtime workloads** of the *same* original **full-Normandy compiled Linux Vulpra**. Source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`; original compressed native archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. Neither trace was generated from a mock, reconstructed from source names or the user's installed Arch/Hyprland profile.

- **Headless New Tab/ASRouter**: [native loader CI 41116477542](https://github.com/sguzman/vulpra/actions/runs/41116477542), sanitized artifact `13006262063`. An earlier version of the report did not explicitly carry `observed_workload_mode` or `real_native_wayland_surface_commit_passed`; the crosswalk accepts *absence only for this authenticated historical headless record*, retaining source/sha and real WebDriver validation.
- **Native graphical Wayland on private Weston**: [CI 41137086850](https://github.com/sguzman/vulpra/actions/runs/41137086850), sanitized artifact `13016563085`. Authenticated same native archive, independent **uninstrumented** 10-second non-null surface buffer/commit **PASS**, followed by a **loader-traced** 10-second non-null surface buffer/commit **PASS** in a private Linux network namespace with no external routes. **Three** actual browser loader PID traces referenced `libxul.so`; glibc `calling init` events were parsed as sanitized unique basenames. [Independent graphical-only rerun 41137151137](https://github.com/sguzman/vulpra/actions/runs/41137151137) **PASS**, artifact `13017318185`.
- **Independent overlap reconciler**: [CI 41137467860](https://github.com/sguzman/vulpra/actions/runs/41137467860) **PASS**, immutable sanitized artifact `13015534860`. `ci/m3-graphical-loader-workload-diff.sh` verifies both proven source/packaged archive identities, the genuine workload-status contract, safe sorted unique basename strings, no raw-trace retention or acceptance inflation; synthetic adversarial fixtures reject mismatched source SHA, unsafe paths, duplicates, altered counts and fabricated Wayland success.

## Measured observation, not deduction

| Runtime-initialized library basenames | Count |
| --- | ---: |
| Headless New Tab workload | **94** |
| Graphical Wayland workload | **152** |
| Observed in both | **94** |
| Observed in headless only | **0** |
| Observed in graphical Wayland only | **58** |

The exact **94** headless-observed names form a subset of the **152** Wayland-observed names. These are initialized **basenames across executed process traces**, not loader paths, direct imported edges, ELF symbols, complete `dlopen` traces, or one-name-per-subsystem attributions. A name observed only in one workload is **not proven required only by that feature or absent from all other workloads**.

Independent physical ELF / headless-loader crosswalk [41116837335](https://github.com/sguzman/vulpra/actions/runs/41116837335) already observed **all 50 distinct directly declared DT_NEEDED names** somewhere in the headless workload. Because those **94** observed headless names are also in the graphical list, those **50** names appeared in this graphical workload too. This still **does not establish per-edge binding, ABI symbol resolution, dynamic-linker choice under every path, user Arch library compatibility, or the complete feature/dependency closure**.

## Outstanding work

- Identify which of the **58 graphical-only observed basenames** arise from transitive load, GTK/Wayland plugin loading, explicit `dlopen`, and browser features; do not claim all are `dlopen`.
- Resolve the ordinary-runner [native `libxul.so` null-address SIGSEGV](M3-WAYLAND-SIGSEGV-20261030.md); the no-egress network namespace graphical success does **not** prove normal Ubuntu or target Arch/Hyprland graphical acceptance.
- Preserve source/module keep boundaries and no deletion without mapped route coverage, native acceptance and a source-matched measurement. **No new omitted feature or byte saving in this round.**

**Accepted gate status remains M3 5/6 (83%), overall product roadmap 61%, this round Δ0 percentage points.** This is accepted **nested dependency-mapping evidence** within the still-open sixth M3 gate, not whole-gate closure.
