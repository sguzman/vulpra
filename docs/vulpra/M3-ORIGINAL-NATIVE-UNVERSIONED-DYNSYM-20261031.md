# M3 — Source-pinned unversioned undefined dynamic symbols (2026-10-31 UTC)

## Result and provenance

[**Original native unversioned ELF symbol name candidate audit 41161945147 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41161945147), source HEAD `d3dcaf1471a9541ee06855c2ed182fe4abb20fb7`. The test authenticates the original 159 beta compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and full-normal native archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` before processing any binary metadata.

The read-only audit inspected all **28 original packaged ELF files** using `readelf -W --dyn-syms`, with bounded extraction, ELF architecture checks and an original compiled archive checksum guard. It identified **2,153 unversioned undefined dynamic-symbol import occurrences**. The report independently counts strong GLOBAL and optional WEAK undefined imports, classifies each against direct `DT_NEEDED` provider *name candidates* in the immutable package or the Ubuntu 24.04 `ldconfig` host library catalog, and retains sanitized symbol/provider names in its bounded CI artifact `m3-original-elf-unversioned-undefined-symbol-census`.

The initial audit 41161796990 rejected a C++-mangled symbol longer than the earlier validator's name limit. After explicit diagnostics 41161866471, the strict parser was extended to accept bounded, valid long C++ mangled names, without allowing unsafe path/control characters. Successful 41161945147 validated the final output, category count sums, original source fingerprint, and proof limitations. Workflow lint also passed on the initial workflow, [41161797137](https://github.com/sguzman/vulpra/actions/runs/41161797137).

## What this adds — and does not establish

The pre-existing [individual versioned symbol audit 41157611807](https://github.com/sguzman/vulpra/actions/runs/41157611807) had enumerated 4,611 versioned imported symbol occurrences with exact declared-provider or consolidated-glibc export candidates, but deliberately **did not inspect unversioned imports**. The new report closes that *bounded inventory gap* for GLOBAL/WEAK DEFAULT/PROTECTED dynamic-symbol imports in this original native archive. The separately [authenticated ten-invocation GNU ELF version-identity reconciliation 41161592443](https://github.com/sguzman/vulpra/actions/runs/41161592443) remains **519/519** observed, but is a different and narrower type of evidence.

The new audit's candidate classifications are **not** actual ELF relocation binding or necessarily runtime-selected providers; a missing direct `DT_NEEDED` name match is **not** a failure because transitive dependency resolution and load order are outside this audit. Other limits: lazy `dlopen` names, indirect loader search paths, exceptional/weak semantics, source/build feature reachability, actual real-world update/crash/ML/DRM behavior, target Arch/Hyprland host, and incremental debloating removals. No packaged executable was run as part of this static census, no browser source or installed profile changed, and no bytes were removed.

**M3 remains 5/6 gates (83%); overall Vulpra 61%; milestone delta +0 percentage points.** The final broad source/build/feature and actual runtime symbol dependency gate remains open despite the completed inventory.
