# M3 — Actual configured Mozilla frontend graph and Nimbus fallback source/package crosswalk

**Date:** 2026-10-31 UTC. **Exact original compiled native source:** `b1482404dfb8b01342990ee99ea3df0f9756b5f7`. The two evaluated configurations used independent Linux object directories at the same Mozilla Firefox 159 source SHA, not an assumed current HEAD binary.

## Exact generated graph evidence

[**Mozilla frontend source-matched normal-versus-four-opt-in CI 41234342128 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41234342128) and [**workflow lint 41234342098 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41234342098). Its archived `m3-original-fully-evaluated-normal-vs-combined-mozbuild-frontend` artifact contains the full evaluated repository-relative `DirectoryTraversal.dirs` edges, object-type counts, scoped counts, and 12 allowlisted real `config.statusd`-equivalent configure substitutions for **both** variants, plus a source-matched comparison.

This is **not a source grep**: the pinned original source checkout bootstrapped Mozilla's native toolchain, ran `./mach configure` separately for normal and combined lean, and then used Mozilla's real `BuildConfig.from_config_status`, `BuildReader`, and `TreeMetadataEmitter.emit` APIs via `./mach python`. The small Python bridge `ci/m3-pinned-evaluated-mozbuild-graph.py` exists only because Mozilla's frontend evaluator is implemented in Python; the repository's browser implementation/porting policy is unchanged.

| Actual emitted original-source build frontend | Normal | Four opt-ins combined |
| --- | ---: | ---: |
| Mozilla emitted metadata objects | **19,139** | **19,140** |
| `DirectoryTraversal` objects | **2,024** | **2,024** |
| Distinct evaluated directory traversal edges | **1,959** | **1,959** |
| Added/removed source directory traversal edges | — | **0 / 0** |
| `MozSrcFiles` objects | **85** | **86** |
| `MozSrcFiles` under `toolkit/components/` | **20** | **21** |
| Distinct evaluated `MOZ_SRC_FILES` file members | **561** | **562** |
| Exact `MOZ_SRC_FILES` members added/removed | — | **1 / 0** |
| Explicitly unresolved noncanonical install-base labels | **1** | **1** |

[**File-member ownership extension 41235510396 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41235510396) additionally enumerates the exact class-specific `MozSrcFiles.files.walk()` member paths from the actual emitted graph. The exact added four-field member is `["toolkit/components/nimbus", "src", "toolkit/components/nimbus/NimbusBootstrap.sys.mjs", ""]`: owner directory, source-file origin, source path and installation subdirectory. The full graph has **561** distinct members, combined has **562**, with **exactly one added and zero removed**. Each graph also labels one noncanonical install-base member explicitly as unresolved; those records cannot support a guessed destination path. Earlier source-collector runs 41235006535 and 41235264968 failed because of path normalization and are **not** counted as evidence.

Every **other top-level emitted object-type count** (including the 1,291 static-library, 23 shared-library, 427 `FinalTargetFiles`, 121 `JARManifest`, 847 unified-source and 2,713 computed-flag records) was equal across both configured frontends. Every other **scoped** object-type count among the explicitly audited `browser/components/`, `browser/extensions/`, `toolkit/components/`, `toolkit/library/`, `toolkit/mozapps/`, `widget/`, `security/`, `dom/` source prefixes was equal too. These are counts and evaluated `DIRS` edges, **not** proof that every emitted object has identical file members, payloads, compiler flags or link inputs.

Actual generated flags retained `MOZ_SANDBOX=1`, `MOZ_WAYLAND=1`, `MOZ_SERVICES_SYNC=1`, `MOZ_DEVTOOLS=all`, crash reporter and updater in both; `MOZ_NORMANDY=1` was present in normal and **absent** (not a literal false-value substitution) in lean. All three named Vulpra New Tab/ASRouter opt-out keys were empty in the normal generated substitutions and `1` in lean.

## Independent actual compiled Nimbus fallback witness

[**Initial source/build/package crosswalk 41234793345 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41234793345), followed by [**strict exact source-member + packaged fallback crosswalk 41235807342 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41235807342); [**latest workflow lint 41235807319 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41235807319).

Exact original `toolkit/components/nimbus/moz.build` Git blob `263de482d19bf6afa5ad0ae2e986ffad6d007456` contains the explicit Linux browser + GTK + **`not CONFIG["MOZ_NORMANDY"]`** condition adding **`MOZ_SRC_FILES += ["NimbusBootstrap.sys.mjs"]`**. That source file is byte-identical in the original native compiled source and current main at verification time.

The independent CI re-authenticated the two compiled browser package SHA-256 values and the full generated graph artifact and checked actual `omni.ja` ZIP members. **Normal** contains the Normandy runner and **does not** contain the Nimbus bootstrap resource. **Combined lean** has the inverse: the runner is absent and `moz-src/toolkit/components/nimbus/NimbusBootstrap.sys.mjs` is physically present. Both preserve the essential New Tab `ActivityStream`, `TopStoriesFeed`, and `DiscoveryStreamFeed` compiled resources.

This is now a strict **exact source-condition + evaluated `MOZ_SRC_FILES` member path + actual compiled package resource** crosswalk, not merely a source-scope or object-count inference. The independent verifier requires the single added "toolkit/components/nimbus/NimbusBootstrap.sys.mjs" member, **zero removed members**, matched normal/lean configure conditions and the inverse physical Normandy/Nimbus package resources. It does not prove that other source-object classes or generated backend installer rules are identical, nor that the added bootstrap is the only change to compiled JavaScript.

## Boundaries and next actual work

The selected opt-in features **do not shrink the evaluated directory-traversal graph**; they change guarded packaged JS/resources and add a Nimbus bootstrap fallback. The previous separately verified compiled 28-ELF direct library-import graph also remained unchanged. Consequently this 26,136-byte combined compressed-archive delta cannot be projected into eliminated native libraries or a smaller Gecko compilation tree.

The final M3 gate still requires **file-level member ownership for remaining emitted object classes and backend rules**, generated installer/JAR assets, conditional linker and FFI edges, and unknown late runtime `dlopen`/platform paths. This result specifically closes the bounded "`MOZ_SRC_FILES` explicit source-file delta" subtask, not the full build graph. None of these results authorize further source pruning, disabling protected Sync/telemetry/security behavior or calling M3 completed. No user's installed browser or profile was touched.

**M3 remains 5/6 gates (83%); Vulpra overall remains 61%; accepted milestone delta +0 percentage points.**
