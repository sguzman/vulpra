# M3: accepted exact-source native linker, package transformation and host dependency evidence

**Verified 2026-10-29.** Full normal Linux GTK/Wayland/X11 browser, with
Sync, Normandy, DevTools, sandbox, WebExtensions and normal resources retained.

## Independent full-native evidence

- Original compile, package, generated-link inputs, Gecko `ExecutableFile.copy`
  ELF replay, private Weston, localhost JavaScript navigation, isolated
  WebExtension/profile and Nimbus: [GitHub Actions 40963098075](https://github.com/sguzman/vulpra/actions/runs/40963098075),
  **success**. Native evidence artifact **12938864326**.
- Independent bounded evidence reconciliation:
  [GitHub Actions 40969046569](https://github.com/sguzman/vulpra/actions/runs/40969046569),
  **success**. Reconciled artifact **12939456325**. The reconciler verifies
  that the original run itself concluded successfully, not merely that its
  JSON files look valid. Source SHA-1:
  `cde4d83043f8c476173c8dbc78b66b078c3f6b5b`.
- The normal compressed tar.xz package is **87,154,700 B** with SHA-256
  `18798900c5307fd136f7d93db6681741616981b609741a4b2209a1810273eb51`.
  It is **not** a source-matched opt-in/full package comparison, and its size
  alone is not a debloating saving.

| Source-matched native evidence | Measured result |
| --- | ---: |
| Generated `libxul_so.list` C/C++ object inputs | 2,435 |
| Packaged native ELF regular files | 28 |
| Packaged ELF direct `DT_NEEDED` edges | 268 |
| External direct library names (not packaged) | 36 |
| Packaged `libxul.so` logical bytes | 189,486,696 |
| Original linked `libxul.so` SHA-256 | `0ec00c074bd7b846e6b0bd621f43b92f49c3dc4ce9bff8b1c020e6a3d0521eb4` |
| Packaged and replay-reproduced `libxul.so` SHA-256 | `a6139ee9ec4d0d8df7bec6b89bab6c41c553703842486ddfe773a1acc50a76c2` |
| Generated object-input response SHA-256 | `3e1926f4674246622013393366071c80ca2b492afc15463e4a92eb17e1746126` |

**The raw and packaged `libxul.so` hashes correctly differ.**
Native CI's `file` showed the original **2,590,378,712 B** linked ELF with
debug information and a stripped **189,486,696 B** packaged ELF; both had
the same build ID. The generated `PKG_STRIP` was true, `USE_ELF_HACK`
false, and **Gecko's actual `mozpack.files.ExecutableFile.copy` on a
temporary file reproduced the packaged ELF SHA-256 exactly**. The helper
also verified both original files were intact after replay. This resolves
the prior source-vs-package hash contradiction without pretending raw
compiled and shipped files are bit-identical.

The earlier [40944392090](https://github.com/sguzman/vulpra/actions/runs/40944392090)
and [40952352531](https://github.com/sguzman/vulpra/actions/runs/40952352531)
full builds **compiled and packaged**, but their replay acceptance jobs
failed on artificially small original-ELF size limits (384 MiB and 2 GiB).
Their subsequent packaged-browser runtime steps were skipped. They are not
accepted native evidence; the new run is separately complete.

## Current source-matched CI host ELF metadata

A **separate read-only Ubuntu host crosswalk** uses only the accepted
native ELF report, not the historical archive:
[GitHub Actions 40972314570](https://github.com/sguzman/vulpra/actions/runs/40972314570)
**PASSED**, artifact **12940917291**. Checks verified exact
`source_commit`, original native run's success, the compressed package
SHA-256, native runtime flag, 28 ELF files, 268 direct edges and 36
unbundled names before any host lookup.

- Ubuntu 24.04 x86-64 `ldconfig -p` contained compatible regular ELF file
  candidates for **36/36** package-external direct library names.
- Recursive `readelf -dW` followed **76** distinct host direct/transitive
  names and **246** host-to-host `DT_NEEDED` edges; **76/76** had matching
  CI host-cache ELF file candidates. Maximum observed graph depth **3**.
- No Vulpra or host ELF was executed by this crosswalk, and neither
  `ldd` nor `dlopen` was called. The actual browser runtime was
  verified *separately* in the source-matched full native workflow.

**Scope boundary:** A `DT_NEEDED` response file and CI-host
`ldconfig` file presence are **not** a full resolved linker-symbol map,
ELF symbol-version or glibc/ABI agreement, actual dynamic-loader search
path resolution, plugin/`dlopen` closure, or the owner's Arch/Wayland
machine. Nor does the original library size establish which feature
could be removed, or how many compressed bytes would be saved.
The browser's normal GTK, Wayland/X11, security, Sync, Normandy, DevTools,
WebExtensions, AIWindow prompt data and Hungarian hyphenation remain protected.

**Progress accounting:** The roadmap's **source-matched native
build/link/packager/runtime subtask is accepted**, but the broader
feature bundle/build/binary dependency map and other M3 acceptance gates
are still incomplete. **M3 2/6 (33%); overall 44%; delta 0 pp.**
