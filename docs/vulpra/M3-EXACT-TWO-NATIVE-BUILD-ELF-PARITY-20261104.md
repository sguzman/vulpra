# M3 — Two real native packages retain identical direct ELF dependency interfaces (2026-11-04 UTC)

## Source identity and separate artifacts

This compares **two different source-compiled, full-normal Linux Vulpra packages** using independently downloaded and checksum-pinned metadata, not a standalone static source grep, two differently configured theoretical builds, or a native build run conducted by this comparison script:

| | Earlier full-normal Linux package | Current-pruned Linux package |
| --- | --- | --- |
| Source commit that compiled actual archive | `1683ca67b69389a879717bcd537772c3b40624b6` | `d5cfdb360ec9c3f9d113b2dbcbddaed74f406dfd` |
| Native metadata evidence | [CI 40931403992 PASS](https://github.com/sguzman/vulpra/actions/runs/40931403992), artifact **12923300697** | [Full compile/package/runtime CI 41749398233 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41749398233), artifact **13287746750** |
| Downloaded evidence ZIP SHA-256 | `2aeed6807ecadf459da9737b4fa26fc489221b9ecf710816542d3f370e330bea` | `28a283993c808dd0783995808631109490a4bae8b04db088159be4a16c86f909` |
| SHA-256 of actual compressed browser archive, as recorded by source-pinned audit | `e8717fd10a1ffc330ef96f802a4112da335aaf57c6e68d70e639b3e137c9e97f` | `9cc6b6bb106055d767a1117a216b673367cd91237ad7c41a50ae38bb2542661e` |

The **earlier** binary's `1683ca67` provenance is intentionally not conflated with immutable original-source `b1482404`; this is earlier full-normal vs current-pruned, not a claim of source-level upstream equivalence.

## Verified actual binary metadata parity

The new source-pinned read-only [`ci/m3-native-elf-pair-parity.jq`](../../ci/m3-native-elf-pair-parity.jq) rejects mismatched source/archive identities, malformed 28-ELF/268-edge observations, duplicate/missing native ELF files and needed declarations, renamed/native SONAME or per-file direct dependency changes, inconsistent packaged/external classification, and unsafe assertions of source-removal or `dlopen` closure. Against the independently downloaded reports, it confirms:

- **28/28** physical ELF paths, owner basenames and SONAME declarations match exactly.
- The **268/268** per-ELF direct `DT_NEEDED` declarations match exactly, **50/50** unique library names unchanged.
- All **14** packaged direct library names and **36** external direct library names unchanged, with **47** regular files in both browser archives and no archive link members.
- **Six ELF file content SHA-256 digests differ:** `crashhelper` (−16 bytes), `crashreporter` (−184 bytes), `libmozinference.so` (same byte length), `libxul.so` (−224 bytes), `vulpra` and `vulpra-bin` (both same byte lengths). Other **22/28** ELF member hashes match. This is binary identity change, **not** proof of a removed feature or ABI regression.
- Current archive has **928 more outer regular-file logical bytes** and is **223,532 compressed bytes larger** than the earlier archive. These are two separate outputs, **not** isolated causal or marginal savings measurements.

**Adversarial local tests:** the real pair passed; **20/20** deliberate forged source/archive metadata, missing/duplicate needed or ELF entries, rename, SONAME, per-file dependency change, changed imported package classifications and false safety/savings claims were rejected by running the actual jq verifier. This is a local verifier test, not a new GitHub CI build or comprehensive native symbol-resolved ABI check.

### Reproduction

After downloading the two named GitHub Actions artifacts and extracting their JSON reports into temporary files:

```sh
jq -n --slurpfile historical /path/to/earlier-elf.json \
      --slurpfile current /path/to/current-elf.json \
      --arg historical_source 1683ca67b69389a879717bcd537772c3b40624b6 \
      --arg current_source d5cfdb360ec9c3f9d113b2dbcbddaed74f406dfd \
      --arg historical_archive e8717fd10a1ffc330ef96f802a4112da335aaf57c6e68d70e639b3e137c9e97f \
      --arg current_archive 9cc6b6bb106055d767a1117a216b673367cd91237ad7c41a50ae38bb2542661e \
      -f ci/m3-native-elf-pair-parity.jq
```

### Boundary of acceptance

This is a **bounded direct native dependency parity** result. It does not compare code/sections beyond disclosed hashes, prove that `libxul` Rust/C++ transitive link inputs or lazy external `dlopen` and FFI routes match, exercise every retained feature or target workstation ABI, or authorize removal of additional source. The source-matched normal Wayland/JavaScript/extension/Nimbus runtime checks are separately established by CI 41749398233; this standalone jq comparison does not execute any binary. The corrected explicit-offline follow-up at `0889c4c`, [41750432275](https://github.com/sguzman/vulpra/actions/runs/41750432275), subsequently **succeeded** and independently verified its own 28-ELF/268-edge package and Wayland/JS/extension/Nimbus acceptance; this two-build comparison still concerns only the earlier `1683ca67` and `d5cfdb3` archive pair.

No source or installed browser/profile changes; no marginal compiled savings claimed. **Overall 61%, M3 5/6=83%, Δ+0 pp.**
