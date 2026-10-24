# Native build measurement contract

The official source snapshot is preserved as the baseline for comparisons. Its inventory is in [run 40125494649](https://github.com/sguzman/vulpra/actions/runs/40125494649): **483,770 regular files, 3,633,991,406 bytes**. These are inventory values for the source tree, not compiled binary sizes.

After a **successful full native build**, `packaging/measure-build.sh` creates `vulpra-build-metrics.json` alongside the CI-preview archive. Fields:

| Field | Meaning |
| --- | --- |
| `source_commit` | Exact Git commit compiled by CI |
| `native_build_seconds` | Elapsed wall-clock time around `./mach build` only |
| `archive_bytes`, `archive_sha256` | Size and SHA-256 of the staged Vulpra preview archive |
| `native_executable_bytes` | Size of the compiled `dist/bin/firefox` entry |
| `libxul_bytes` | Bytes in the compiled `dist/bin/libxul.so`, if present |
| `measurement_scope` | Explicit exclusions: bootstrap, packaging and browser smoke |

The metric file ships as part of the CI-preview artifact so comparisons use the same native build evidence as the actual binary. The JSON generator's portability, basic field validity and checksum agreement have passed [mock-package CI 40132561502](https://github.com/sguzman/vulpra/actions/runs/40132561502).

**Not yet measured:** the real compiled executable/archive, build duration and runtime startup/memory numbers. Do not substitute mock values (for example, the test's artificial 123-second duration) for actual Firefox measurements.

Future debloating should compare exact source revisions, identical runner hardware and toolchains, cold versus warm compiler caches, and the same tests. A speedup cannot be attributed solely to removed features if the cache state also changed.
