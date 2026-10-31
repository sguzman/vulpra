# M3 — All 28 original compiled ELF files pass read-only glibc direct-loader resolution (2026-10-31 UTC)

## Source-pinned result

[**Authenticated read-only original 28-ELF glibc loader-list CI 41207364061 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41207364061); [global workflow lint 41207364053 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41207364053).

The compiled full-normal Linux Vulpra archive was recovered from original source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, with full archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` verified before extraction. The bounded standard-library Rust observer `ci/m3-original-native-elf-loader-list.rs` inspected **only regular ELF archive members**, refused filename collisions, required exactly 28 files, and compared each file's `readelf -Wd` direct `DT_NEEDED` declarations against the provider basenames printed by the Ubuntu 24.04 x86-64 glibc interpreter's explicit **`--list` mode**.

Every loader invocation ran inside a **no-egress network namespace** with a disposable HOME and a precise package-local `LD_LIBRARY_PATH`. The loader listed direct and transitive providers **without executing the application's main function or its normal feature workflows**. Timeout and bounded-output checks were applied. Raw loader paths, PIDs, stdout/stderr and profiles were not uploaded; only sanitized original ELF/provider basenames and aggregate counts were retained.

| Original compiled package loader-list measurement | Verified |
|---|---:|
| Original regular ELF members checked | **28 / 28** |
| Declared direct `DT_NEEDED` relationships | **268** |
| Direct requested SONAMEs appearing in their individual loader lists | **268 / 268** |
| Total provider-basename occurrences across 28 separate loader lists | **586** |
| Distinct provider basenames appearing in those loader lists | **91** |
| Original ELF members with an unresolved required direct SONAME | **0 observed** |

The 91-basename set includes loader special names such as `linux-vdso.so.1` and the ELF interpreter; do not interpret it as 91 independently packaged browser libraries. Each direct edge was checked against a provider basename within the same ELF file's individual resolved list, not merely against a machine-wide candidate list.

## How this differs from earlier evidence

- [The original 28-requester normal-binding witness union 41206458805](https://github.com/sguzman/vulpra/actions/runs/41206458805) established actual glibc normal-symbol binding events for each original requester in at least one bounded startup or feature-specific workload. That did **not** show every direct required SONAME appearing in an individual loader map.
- [The direct-needed vs sampled binding crosswalk 41206941249](https://github.com/sguzman/vulpra/actions/runs/41206941249) identified 107 direct edges with same-provider *normal-symbol binding* witnesses in one startup. The remaining edges were **not** proven broken or unused. The read-only 28-ELF loader lists now independently show that the original declared direct SONAMEs can be found by glibc in this specific CI environment.
- Earlier 519/519 GNU ELF *version-identity checks* are separate from both read-only loader listing and symbol relocation/binding completion. All are valuable but prove different things.

## Remaining M3 acceptance boundary

This check **does not prove** that original application binaries execute all native entrypoints, all required symbol relocations actually bind, code loaded by future `dlopen` is complete, rare crash/update/media/ML integrations work end-to-end, the current source/build/link feature graph is complete, or the target EndeavourOS/Arch + Hyprland system resolves identical libraries and versions. The host was Ubuntu 24.04; `LD_LIBRARY_PATH` used the original packaged libraries and CI system libraries.

No original source was removed, no browser package size was reduced, no installed browser/launcher/profile was touched, and no safe-pruning permission was inferred.

**M3 still has 5/6 accepted gates (83%); Vulpra overall remains 61%; session Δ0 percentage points.**
