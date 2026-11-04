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
  --arg current_elf_sha256 29c18dbee18eda918cfd0013e2e730ae47ddcf888ed5951327e26012aa76b3cf \
  -f ci/m3-current-vs-original-linked-loader.jq
```

The `current_elf_sha256` value is now accepted from the compiled source-pinned native linker report, independently joined to the separate current callsite artifact. The completed result and exact digests are recorded below.

## Independent local parser and anti-forgery tests

The comparison accepted the **real historic 47-row census** against a **clearly synthetic test copy** relabeled with a fabricated current ELF hash. This tested only the jq comparison algorithm, **not actual current binary parity**. Local fixtures rejected **17/17** malformed source/ELF identities, aggregate counts, duplicated/missing rows, fake loader APIs, kinds, symbol names and unauthorized safety claims; an 18th positive drift test confirmed that a truly changed branch multiplicity is reported in one row without inventing pruning rights. The canonical uploaded Git blob SHA for the jq script was checked against the tested local file.

**Repeatable standalone CI validation:** [run 41765832361 PASS](https://github.com/sguzman/vulpra/actions/runs/41765832361) executed the committed [Bash/jq synthetic negative fixtures](../../ci/tests/m3-current-vs-original-linked-loader-tests.sh) under [its lightweight workflow](../../.github/workflows/m3-current-linked-loader-crosswalk-tests.yml), without any new browser compilation. **18/18** forged-source/ELF-hash/count/record/API/safety cases were rejected, and one deliberate current-count change remained visible while all pruning/closure claims stayed false. [Workflow lint 41765831541 PASS](https://github.com/sguzman/vulpra/actions/runs/41765831541). The 18-case suite is separate from the earlier local 17-case test against an authentic historic report and a synthetic current copy; **neither substitutes for the pending actual current compiled callsite evidence**.

### Limits and acceptance rule

No output here asserts that actual current callsites equal the historical 73/47 baseline. Same/missing/new call counts are bounded evidence of the **selected direct** disassembly parser, not complete native loader entrypoint coverage, `dlsym` return/function ABI, Rust/C++/C FFI ownership, dynamic runtime path selection, protected fallback behavior, current native builds on EndeavourOS/Hyprland, source-deletion safety or compiled package marginal byte savings. Historic original's source `b1482404` and current source `96454f7` must never be conflated.

**Resolved for selected direct loader branches:** the real compiled current run and all bounded artifacts were inspected and compared; there are **0 changed caller/API/branch-kind multiplicities**. This does not close broader M3 native dependencies or protected feature gates. **Overall 61%, M3 5/6=83%, Δ+0 percentage points.**

## Accepted source-matched binary evidence and actual comparison (2026-11-04 UTC)

[**Current native build 41762298450 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41762298450), exact source `96454f7a1fbe6b505af440c6c2c5fc91e798756d`: full `mach build`, package, native ELF audit, isolated Weston/Wayland graphical render, loopback JS/302/final DOM, disposable unsigned WebExtension and Nimbus runtime all passed. The new Rust examiner's compiled C++ positive/negative fixtures also passed in the workflow. The actual current linked-callsite step completed successfully.

**Independently downloaded and ZIP-integrity checked:** original historical census artifact **13099309380**, ZIP SHA-256 `06e38ceacd997c1b274016261781892ad43626252a0157142c69fc62b908ec24`; new current callsite artifact **13292978622**, ZIP SHA-256 `5dc78a1b0d2698c94bd2979b8b2d8094461087ca8e37d7093e1e7fe91abec579`; current seven-report native-link/runtime artifact **13292758940**, ZIP SHA-256 `e0f4bb8def5d777c99d28fc622dfe8c52a63e6b8d2c1b9e3c87bf22176a8966e`. Actual linked unstripped current `libxul.so` SHA-256 is **`29c18dbee18eda918cfd0013e2e730ae47ddcf888ed5951327e26012aa76b3cf`**; this **exactly matches** the source-pinned native link report and packaging replay's source ELF SHA. The current normal package SHA-256 is **`279de506d3e737de5c5925549ba690ae32529a4d4e16938b115aceac74c458da`**, with **28** native ELFs and **268** direct `DT_NEEDED` edges. No user profile or installed browser touched.

Running the **unchanged committed** `ci/m3-current-vs-original-linked-loader.jq` (verified Git blob `bf4d8a487568ebba8a6c41deee714bd5a775fa3c`) on the real two ELF reports with independently bound source and ELF hashes produced **`changed_records: 0`**. All **47/47 exact caller-symbol, loader-API, branch-kind and branch-multiplicity records match**. Both report **73 selected direct branches**: `PR_LoadLibrary` **35** (20 caller records), `PR_LoadLibraryWithFlags` **14** (10), and `dlopen` **24** (17); the FFmpeg-to-NSPR direct call remains **1**. The underlying unstripped `libxul` hashes differ and the current ELF is **26,760 bytes smaller**; identical selected loader branches **do not prove binary equality or causal feature savings**.

A machine-readable [source-pinned accepted summary](M3-CURRENT-NATIVE-LOADER-CALLSITE-PARITY-20261104.json) captures the exact source/artifact/ELF/package hashes, bounded acceptance counters and explicit false values for unproven coverage. This is an accepted *selected-direct-branch census parity*, **not** full future `dlopen`/NSPR/indirect call coverage, `dlsym`/FFI ABI resolution, fallback safety, all-protected-feature runtime, actual EndeavourOS/Hyprland compatibility or permission to remove source. **No new source removals, no causal native savings, M3 5/6=83%, overall 61%, Δ+0 pp.**
