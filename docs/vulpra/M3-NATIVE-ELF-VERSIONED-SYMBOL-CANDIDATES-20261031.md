# M3 — GNU ELF versioned undefined symbol candidates (2026-10-31)

## Exact compiled-source and archive scope

[Successful GitHub Actions native audit 41157611807](https://github.com/sguzman/vulpra/actions/runs/41157611807), artifact **13025831414**; [independent workflow lint 41157611863](https://github.com/sguzman/vulpra/actions/runs/41157611863) **PASS**. Source/runner checksum and full-original native package are authenticated to `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` (87,154,544-byte original tar.xz). The tool inspects **28** ELF64 x86-64 package members, without executing native code, loading libraries with `ldd`, or changing source.

For each imported dynamic symbol whose name carries a GNU version, the parser validates the actual `readelf -W --dyn-syms` *undefined symbol index* against the original module's `.gnu.version_r` **version-index-to-provider-and-version** mapping. It checks exact `(symbol name, version name)` export candidates from the checksum-pinned *packaged* provider, otherwise the Ubuntu 24.04 x86-64 `ldconfig` candidate, using only static metadata. This is more discriminating than the separate 519 **version-name-only** contracts because each of the 4,611 entries names a concrete undefined function/variable symbol. Undefined symbol name/required version are compared without recording addresses, host library paths or user data.

| Source-pinned compiled undefined symbol cases | Count |
| --- | ---: |
| **Total versioned imports** | **4,611** |
| Exact `name@version` export in declared candidate provider | **4,008** |
| Exact `name@version` export in modern `libc.so.6` candidate, not declared old provider | **603** |
| No provider candidate available | **0** |
| No candidate export found | **0** |

### Why 603 are not immediately broken imports

Modern glibc (Ubuntu 24.04 CI) retains old symbol versions in `libc.so.6` while formerly separate libraries can be smaller compatibility stubs. The checker recognizes a versioned import whose declared provider candidate no longer exports its name but **`libc.so.6` does export that same name and version**. These *candidate* matches break down as `libpthread.so.0` **535**, `libdl.so.2` **60**, `librt.so.1` **7**, and `libresolv.so.2` **1**. We did not treat an identical version string alone as a substitute for an exported symbol: actual symbol name plus version must match. This does **not** prove the runtime loader chose libc, applies symbol interposition as expected, or that an individual relocation resolved, because no Vulpra executable or library was dynamically loaded by this analysis.

A prior [separate real GUI loader comparison 41150562882](https://github.com/sguzman/vulpra/actions/runs/41150562882) **PASSED**, with 152 actual initialized library basenames/147 needed-by/21 dynamic-request edges matching across two startup execution environments. The present audit is a *static extension* to that measured runtime observation, not a replacement for real per-symbol relocation/binding evidence.

## Evidence integrity and bounded interpretation

The parser authenticates the exact immutable archive, validates every ELF header and direct needed declaration against the established package scanner, and reconstructs GNU version indexes rather than guessing a symbol's provider from a version label that may occur in multiple libraries. It records symbol names, declared SONAMEs, names of available provider candidates, status classifications, explicit limits and source SHA. No host library **absolute paths**, pointer values, user profile contents, or native process arguments are retained. Malformed/version-index spoofing fixtures and workflow lint passed.

**Not established:** unversioned/weak-symbol runtime behavior, actual linker/loader search path or symbol binding, all imports and non-ELF resources, `dlsym`/`dlopen`, lazy feature routes, symbol type/ABI semantics, all host transitive dependencies, binary source-feature causal attribution, target Arch/Hyprland host ABI, new package savings or safe compiled source deletion.

**M3 stays 5/6 (83%), overall 61%, session delta +0 percentage points.** The broad sixth dependency-feature gate is still open; the 4,611 matches do not constitute ABI completeness.
