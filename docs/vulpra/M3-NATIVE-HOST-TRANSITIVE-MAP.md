# M3 bounded Ubuntu host ELF transitive import map

**Accepted read-only source/host metadata experiment:** [GitHub Actions run 40947712769](https://github.com/sguzman/vulpra/actions/runs/40947712769) **PASSED**; artifact `m3-native-host-elf-transitive-map` ID **12930680277**.

## Evidence chain

This workflow did not recompile, repackage, execute, load, or modify the browser. It reused the bounded, SHA-256-verified historical archive graph from [host-cache preflight 40947019427](https://github.com/sguzman/vulpra/actions/runs/40947019427), whose underlying original full normal package came from [run 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401) and compiled Vulpra source `1683ca67b69389a879717bcd537772c3b40624b6`. None of these artifacts are substituted for the later exact-source package build at `3f9945cb...`.

The script `ci/m3-native-host-transitive-map.py` starts with the **36 package-external direct `DT_NEEDED` names** and consults the Ubuntu 24.04 CI runner's fresh `ldconfig -p`. It accepts only regular x86-64 host ELF file candidates and reads each matching library's own dynamic section with `readelf -dW`, recursively, under bounded node, edge, and depth limits.

| Actual metadata observation | Count |
| --- | ---: |
| Original package-external direct ELF names | **36** |
| Distinct Ubuntu host direct + transitive ELF names inspected | **76** |
| Host-library-to-host-library direct `DT_NEEDED` edges | **246** |
| Host names with an architecture-compatible `ldconfig` file candidate | **76** |
| Host names without a compatible cache candidate | **0** |
| Self-test host-cache safety fixtures | **11 passed** |
| Self-test transitive-graph fixtures | **6 passed** |

## Interpretation and limits

This is a stronger **host file-presence and declared-edge inventory**, not a resolved runtime load graph. The 76 names are not 76 separately required files in the shipped archive; they are the union of the original 36 external names and further direct imports declared by Ubuntu host libraries, with repeat names deduplicated.

A matching host file does not establish that the dynamic loader selects it or can satisfy all symbols and version requirements. The graph cannot cover `RPATH`/`RUNPATH` choices, `dlopen`/plugin loads, namespaces, versioned symbols, hardware driver availability, or all conditional runtime paths. The observed host is **Ubuntu 24.04 in GitHub Actions**, not the user's Arch/Wayland workstation. No native executable or shared library was loaded or executed by this workflow; the previous real-browser smoke remains a separate, source-pinned test.

**Decision:** keep normal Linux GTK/Wayland/X11 fallback, sandboxing, NSS/NSPR, SQLite, crash and extension infrastructure. No additional deletion is authorized, no compressed marginal savings are measured, and no broad M3 gate advances. Further independent source-matched runtime and packaging evidence remains necessary.

**Progress remains overall 44%, M3 2/6 (33%), Δ 0 pp.**
