# M3 — Current-to-original compiled native loader-callsite comparison (2026-11-04 UTC)

## Scope and motivation

The original native source-pinned audit [41342247184 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41342247184), evidence artifact **13099309380**, recorded **73** selected *direct* ELF loader branches across **47** caller/API/branch-kind rows from a **2,590,405,472-byte original-source unstripped `libxul.so`**, with SHA-256 `611a7ed79e581f84dcefb28bd12737f0c1ccacb8ee88b551a77256eb6616e1c7`. The 73 include **35** `PR_LoadLibrary`, **14** `PR_LoadLibraryWithFlags` and **24** `dlopen` calls/jumps. These are a bounded historical comparator only: three PLT forwarding stubs are present in the original census; indirect calls and runtime selected SONAMEs are not exhaustively classified.

Current-pruned-source native CI [41762298450](https://github.com/sguzman/vulpra/actions/runs/41762298450) uses [`ci/m3-current-compiled-loader-api-census.rs`](../../ci/m3-current-compiled-loader-api-census.rs) to analyze the actual unstripped new `libxul` following native build/package/runtime tests. A new read-only [`ci/m3-current-vs-original-linked-loader.jq`](../../ci/m3-current-vs-original-linked-loader.jq) consumes the separate original and current reports with **externally authenticated source commit SHA and linked ELF SHA-256** supplied by the caller. It verifies schemas, binary identity, size and instruction bounds, unique caller/API/branch-kind records, direct-branch aggregate counts, preserved FFmpeg-to-NSPR witness, and fail-closed `M3`/pruning flags. It then reports caller-level differences instead of demanding exact code identity between revisions or automatically interpreting a missing branch as removal permission.

## Reproducible use after the current native CI artifact exists

Download the original artifact **13099309380** and the **separate** `m3-current-native-loader-callsite-evidence` artifact from completed workflow run **41762298450**. Extract `m3-original-compiled-loader-api-census.json` and `m3-current-native-loader-callsite.json`. Before comparison, independently inspect the current run head SHA and its `m3-native-link-inputs.json` `built_libxul_sha256` from the 7-report native evidence artifact.

```sh
jq -n \
  --slurpfile original /tmp/original-loader.json \
  --slurpfile current /tmp/current-loader.json \
  --arg original_source b1482404dfb8b01342990ee99ea3df0f9756b5f7 \
  --arg current_source 96454f7a1fbe6b505af440c6c2c5fc91e798756d \
  --arg original_elf_sha256 611a7ed79e581f84dcefb28bd12737f0c1ccacb8ee88b551a77256eb6616e1c7 \
  --arg current_elf_sha256 'READ_ACTUAL_COMPILED_LIBXUL_SHA_FROM_NATIVE_LINK_EVIDENCE' \
  -f ci/m3-current-vs-original-linked-loader.jq
```

The `current_elf_sha256` placeholder is **not** a claimed hash. The actual SHA and result remain pending native CI completion.

## Independent local parser and anti-forgery tests

The comparison accepted the **real historic 47-row census** against a **clearly synthetic test copy** relabeled with a fabricated current ELF hash. This tested only the jq comparison algorithm, **not actual current binary parity**. Local fixtures rejected **17/17** malformed source/ELF identities, aggregate counts, duplicated/missing rows, fake loader APIs, kinds, symbol names and unauthorized safety claims; an 18th positive drift test confirmed that a truly changed branch multiplicity is reported in one row without inventing pruning rights. The canonical uploaded Git blob SHA for the jq script was checked against the tested local file.

### Limits and acceptance rule

No output here asserts that actual current callsites equal the historical 73/47 baseline. Same/missing/new call counts are bounded evidence of the **selected direct** disassembly parser, not complete native loader entrypoint coverage, `dlsym` return/function ABI, Rust/C++/C FFI ownership, dynamic runtime path selection, protected fallback behavior, current native builds on EndeavourOS/Hyprland, source-deletion safety or compiled package marginal byte savings. Historic original's source `b1482404` and current source `96454f7` must never be conflated.

**Pending:** receive and inspect actual complete native run and current loader report, run this crosswalk against trusted SHA values, investigate any genuine differences, and accept only verified bounded findings. **Overall 61%, M3 5/6=83%, Δ+0 percentage points.**
