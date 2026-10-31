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

## Original evaluated JAR manifests and installer-resource declarations (continued)

[**Pinned original full-versus-combined evaluated resource-input graph 41237474046 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41237474046), with [**workflow lint 41237474231 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41237474231). The earlier first extension run [41237136182 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41237136182) exposed that the original object directories live under the checkout's source root; the follow-up collector explicitly prioritizes the configured objdir when classifying provenance and separately labels unexpanded globs. The original compiler source remains the pinned `b1482404` revision in independently configured full and four-opt-in trees.

| Evaluated frontend input declaration | Normal | Four opt-ins combined |
| --- | ---: | ---: |
| `JARManifest` source inputs | **121** | **121** |
| JAR manifest records unique to variant | **0** | **0** |
| Installer-resource input records | **2,928** | **2,971** |
| Records unique to variant after objdir-relative normalization | **3** | **46** |
| Explicitly unexpanded wildcard declarations | **16** | **22** |
| Noncanonical installer-component declarations, retained as unresolved | **1** | **1** |

The three full-only input records consist of the two deliberately omitted ASRouter promotion-module declarations, plus the normal New Tab `lib/**` wildcard. The combined New Tab build expands that broad declaration into a guarded, explicit list of 46 differently represented declarations (including narrower wildcard families); **46 does not mean 46 features were added**. The exact generated input records distinguish source files, object-generated files, declared installation targets and wildcards. They do **not** expand all `jar.mn` entries, demonstrate that a named resource actually reached `omni.ja`, establish unique generated backend/installer rules, or demonstrate causal packaged bytes. Reversible percent-encoding is used to keep unusual upstream filenames distinct rather than dropping them.

The established compiled full/lean package crosswalk for Normandy/Nimbus remains the physical packaged-resource witness. The new broad frontend inventory must not be substituted for that independently validated native acceptance. No extra source removal, browser modification or M3 gate credit is authorized by this comparison.

## Actual emitted native compilation-source membership

[**Original compiled-source membership inventory 41237964186 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41237964186) collected each real Mozilla `BaseSources` member (including `Sources`, `UnifiedSources`, `WasmSources` and `HostSources`) from the two configured source-matched frontend evaluations. [**Independent full-versus-lean reconciliation 41237976826 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41237976826), with [**workflow lint 41237976864 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41237976864), checked exact structured source-member records, not just emitted object-class counts.

| Evaluated native source membership | Normal | Four opt-ins combined |
| --- | ---: | ---: |
| Exact `BaseSources` member tuples | **11,104** | **11,104** |
| Source-tree file records | **10,402** | **10,402** |
| Object-tree/generated input records | **702** | **702** |
| Source members unique to each variant | **0** | **0** |

Each tuple retains owning build directory, frontend source class, static/generated declaration phase, source/object origin, and path relative to the corresponding source or object root. This proves **the emitted native compilation-source membership is unchanged** between the two *original-source configured* variants. It does **not** establish identical generated file contents, compile defines/flags, compilation commands, actual object-file binaries, linker input lists, FFI relationships, or conditional runtime loading. The compiled 28-ELF DT_NEEDED parity remains separate native-package evidence; neither result closes the full M3 build/FFI/dlopen gate.

## Evaluated native Linkable declarations (2026-10-31)

[**Pinned original Mozilla Linkable source-matched graph 41239615187 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41239615187) executed the extended actual `BuildReader`/`TreeMetadataEmitter` collector against both independently configured original `b1482404` variants. I inspected the archived pair's *exact records*, not just counts.

| Actual evaluated declared link relationship | Full normal | Combined lean | Unique to either |
| --- | ---: | ---: | ---: |
| Linkable target identities | **1,342** | **1,342** | **0** |
| Direct library-to-linkable declarations | **1,424** | **1,424** | **0** |
| Explicit system-library link declarations | **242** | **242** | **0** |
| Static library `link_into` declarations | **1,219** | **1,219** | **0** |

The emitter's `Linkable.linked_libraries`, `linked_system_libs`, and static `link_into` references were collected **after full frontend emission**, avoiding premature snapshots of late-resolved links. Each direct edge includes the consuming and providing target's owner directory, frontend type, host/target kind, and declared name. The comparison is exact after source/objdir-neutral normalization.

**Limit:** This is *declared evaluated frontend linkage*, not actual `ld`/Ninja invocations, complete object-file members, flag equivalence, native-to-Rust FFI closure, or runtime `dlopen` coverage. Source deletion and the sixth M3 acceptance gate remain unauthorized. No extra binary-size reduction has been established.

## Evaluated compile units assigned to native linkable targets

[**Real original-source normal/combined ownership CI 41240056177 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41240056177), [**workflow lint 41240056235 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41240056235). The independently configured actual Mozilla frontend populated each `Linkable.sources` set; the collector retained target owner/class/host-vs-target/name, compilation suffix, file provenance and source-relative member, and compared exact records after original source emission. The archived output was inspected, not only job completion.

| Scoped actual evaluated source-to-link-target record | Full normal | Combined four-opt-in | Unique to either |
| --- | ---: | ---: | ---: |
| Distinct compile-unit/target tuples | **4,367** | **4,367** | **0** |
| Source/object-root classified tuples | **3,146** | **3,146** | **0** |
| Explicitly unresolved relative generated/source tuples | **1,221** | **1,221** | **0** |

These are **declared frontend compile-unit associations**, not all `BaseSources` member records (11,104 per variant), not evidence that 4,367 separate object files were compiled, and not a complete one-to-one generated-to-original-source mapping. For example, the emitted `Unified_cpp_accessible_aom0.cpp` unit is labeled unresolved relative rather than assigned a fabricated object path. Compilation options, actual compiler/linker invocations and generated contents remain unverified. No feature default, installed browser or source was altered; no M3 gate or byte-saving credit was added.

## Exact Mozilla generated unified translation-unit crosswalk

[**Actual original-source `UnifiedSources.unified_source_mapping` inventory 41240538279 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41240538279). Both independently configured source-matched original browser variants emitted **1,180 distinct generated unified units** and **7,959 exact original-source-to-unified-unit membership records**. I inspected the two archived inventories and verified **zero full-only and zero combined-only members**.

Each of the **1,180** previously unresolved `Unified_*` compiler units referenced by a linkable target exactly matches a generated-unit key in Mozilla's actual `UnifiedSources.unified_source_mapping`. The source member associations are not guessed from the generated filename. **Zero unmatched unified units** were reported in either configuration. The additional **41** non-`Unified_` relative linkable compile units (e.g. `BindingNames.cpp`, `RegisterBindings.cpp`, `UnifiedBindings0.cpp`) remain outside this specific mapping and require separate generated-provenance tracing.

The mapping documents the **frontend's generated grouping declarations**, not that those generated files were written, compiled successfully, or linked into byte-identical objects. The real `ld`/Ninja command, compiler options, generated source bytes, FFI and conditional runtime loading remain out of scope. No new source was deleted, no package-size claim added, and M3's final gate remains open.

## WebIDL frontend ownership of the final 41 generated compile units

[**Original-source evaluated `WebIDLCollection` 41241177489 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41241177489). The full/combined native Mozilla emitter produces precisely **41 generated WebIDL binding compilation-unit names** in `dom/bindings`, matching **all 41** non-`Unified_*` relative `Linkable.sources` records left from the previous scope. The exact `WebIDLCollection.all_source_files()` member sets have **zero unique records** to either variant; **zero unmatched** declared relative linker compile units remain.

The same actual collection's `unified_source_mapping` produces **998 binding-`.cpp` to generated `UnifiedBindings*.cpp` grouping records** in each configuration, again **zero differences** across full/lean. The standard `UnifiedSources` mapping already resolved the other **1,180** relative `Unified_*` linkable units. Together, those two native Mozilla frontend classes account for all **1,221** previously unresolved relative compile-unit names in this specific evaluated comparison, **without using name-prefix inference as proof**.

**Limits:** The WebIDL binding-`.cpp` group members are generated code names, not proof that each upstream WebIDL input was processed or that the generated bytes were written/compiled. These are emitter declarations, not the actual backend output rules, object files, link command, FFI or runtime loader closure. The sixth M3 gate remains open; no additional source deletion, feature changes or size saving.

## Actual configured RecursiveMake backend.mk parity

[**Original source-matched generated backend comparison 41242708413 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41242708413). An independent read-only shell auditor enumerated every actual `RecursiveMakeBackend`-generated `backend.mk` regular file after running `mach configure` in the two original-source `b1482404` Linux object directories. File paths were compared relative to their configured objdirs. The only byte normalization before SHA-256 comparison was each configured absolute object-directory path and its basename; all other emitted content was retained.

| Actual generated `backend.mk` files | Normal | Combined lean |
| --- | ---: | ---: |
| Existing relative file paths | **2,024** | **2,024** |
| Paths present in one variant only | **0** | **0** |
| Identical normalized file contents | **2,022** | **2,022** |
| Different normalized file contents | **2** | **2** |

The **only differing generated paths** are `toolkit/content/backend.mk` and `toolkit/modules/backend.mk`. This is exact path/content-hash parity for **2,022/2,024** generated backend make-rule files, not proof their commands were executed. Upstream `toolkit/modules/moz.build` includes the generated `MOZ_NORMANDY_BOOL` define, and the toolkit content/modules directories also own JAR/resource rules; which emitted lines account for each observed difference requires a separate scoped generated-file diff witness.

**Important limits:** This compares generated **`backend.mk`**, *not every generated `Makefile`*, compiler command line, final linker object archive, FFI edge or late `dlopen` request. It does not establish that changed rules are safe to delete. Historical compiled full/lean native package smoke evidence remains independent. No changes to the actual browser, production feature defaults or installed profiles, and no new source deletion or package savings. M3 stays **5/6 (83%)**, overall **61%**, Δ0pp.

## Exact intended-only generated backend rule-delta contract

[**Scoped generated-file diff witness 41243077510 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41243077510) preserved at most 40 unified-diff lines for each of the **two** changing `backend.mk` files, after configured object-root normalization. Direct inspection confirmed both differences are **single `DEFINES +=` lines**: `toolkit/content/backend.mk` includes the four explicit `VULPRA_EXPERIMENT_NO_*=1` tokens in the generated `MOZ_CONFIGURE_OPTIONS` text; `toolkit/modules/backend.mk` changes `-DMOZ_NORMANDY_BOOL=true` to `false`. Its other define values—including protected Sync, sandbox, crash reporter, updater and safe-browsing-related declarations—did not differ in that emitted line.

[**Independent exact intended-only backend contract 41243485129 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41243485129) now **fails closed** unless all 2,024 generated `backend.mk` paths exist in both configurations, exactly the two listed file paths differ, the normal build lacks the four opt-in tokens, the lean build contains all four in the expected order, the Normandy boolean switches as intended, and both differing *complete* generated files become byte-identical after neutralizing only those exact expected token changes plus their own configured object-directory paths/names. **No unrelated generated backend rule difference was accepted.**

This is a bounded generated recursive-Make output invariant, not proof of identical `Makefile` bodies, environment-dependent final compiler invocations, built object bytes, link command/FFI, actual dynamic loads or full safety of deleting source. The diff witness contains configuration text, not secrets from the user workstation. The original browser/user profiles were untouched. No new compiled package size or source-removal claim; M3 remains **5/6 (83%)**, overall **61%**, Δ0pp.

## Source-matched actual generated Makefile file-content comparison

[**Pinned original full/lean generated Makefile inventory 41245140514 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41245140514); [**workflow lint 41245140493 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41245140493). The bounded observer enumerated genuine regular files named `Makefile` under each independently configured original-source object tree, compared exact relative path sets, and SHA-256-hashed complete contents after normalizing only the configured object-directory absolute path and basename.

| Generated Makefile evidence | Normal | Combined lean |
| --- | ---: | ---: |
| Generated `Makefile` relative paths | **2,028** | **2,028** |
| Unique file paths | **0** | **0** |
| Identical normalized full-file hashes | **2,027** | **2,027** |
| Differing normalized full-file hashes | **1** | **1** |

The **only differing generated Makefile path is `faster/Makefile`**. Its exact changed definitions and installation-manifest targets have since been reconciled by the independently verified intended-only check below; raw count equality alone was not used as proof. Together with the **2,024/2,024 existing `backend.mk` files** already reconciled under the exact opt-in configure delta, this covers both known generated recursive-Make file classes, **not** the generated Ninja/rustc/Clang commands that an actual full build might invoke.

No native compiler or linker was invoked by this new comparison, nor were generated code bytes, feature-specific link objects, FFI or late `dlopen` closure established. No new pruning, browser/profile modifications, package-size savings or M3 gate credit. **M3 remains 5/6 (83%), overall 61%, Δ0pp.**

## Exact intended-only faster Makefile contract

[**Scoped original-source generated faster Makefile diff 41245705972 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41245705972) first exposed that `faster/Makefile` changes more than just the Normandy definition. [**Structured exact `ACDEFINES` and installer-manifest comparison 41246349867 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41246349867), followed by [**manifest-target ownership 41246873618 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41246873618), established the exact four changed entries:

| Actual emitted `faster/Makefile` item | Full normal | Four-opt-in lean |
| --- | --- | --- |
| `ACDEFINES`: `-DMOZ_NORMANDY=1` | Present | Absent |
| `ACDEFINES`: `-DVULPRA_NO_ASROUTER_PROMOS=1` | Absent | Present |
| `ACDEFINES`: `-DVULPRA_NO_NEWTAB_ADSFEED=1` | Absent | Present |
| `INSTALL_MANIFESTS`: `dist/bin/moz-src/toolkit/components/nimbus` | Absent | Present |

[**Strict normalized complete-file assertion 41247224120 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41247224120) now fails closed if any of the original **2,028** `Makefile` paths are missing/added, if any other path differs, if the changed variable names are not exactly `ACDEFINES` and `INSTALL_MANIFESTS`, if the listed full/lean token sets differ from these four values, **or if the entire normalized `faster/Makefile` contents fail byte-for-byte comparison after removing only those intended entries**. The archived result explicitly records `full_generated_faster_makefile_reconciles_after_expected_only=true`. Full-normal and lean preserve **2,027** otherwise-identical complete Makefiles, and the single remaining file is thus accounted for by exact expected configure/resource differences.

`FasterMakeBackend.consume_finished` in the pinned original Mozilla source constructs both `ACDEFINES` from generated configure substitutions and `INSTALL_MANIFESTS` from actual frontend resource targets. The Nimbus target matches the separately compiled/runtime-checked fallback crosswalk. A separate stricter check also reconciles **all 2,024 generated `backend.mk` files** after exactly the expected opt-in arguments and Normandy boolean. This closes *the generated recursive-Make file-content parity subtask*, not code generation execution, full Clang/Rust compilation commands or object/linker/FFI/`dlopen` closure. No user workstation files/profiles, browser source or installed binary were touched; no new source removal or package-size saving. **M3 5/6 (83%), overall 61%, Δ0pp.**

## Boundaries and next actual work

The selected opt-in features **do not shrink the evaluated directory-traversal graph**; they change guarded packaged JS/resources and add a Nimbus bootstrap fallback. The previous separately verified compiled 28-ELF direct library-import graph also remained unchanged. Consequently this 26,136-byte combined compressed-archive delta cannot be projected into eliminated native libraries or a smaller Gecko compilation tree.

The final M3 gate still requires **file-level member ownership for remaining emitted object classes and backend rules**, generated installer/JAR assets, conditional linker and FFI edges, and unknown late runtime `dlopen`/platform paths. This result specifically closes the bounded "`MOZ_SRC_FILES` explicit source-file delta" subtask, not the full build graph. None of these results authorize further source pruning, disabling protected Sync/telemetry/security behavior or calling M3 completed. No user's installed browser or profile was touched.

**M3 remains 5/6 gates (83%); Vulpra overall remains 61%; accepted milestone delta +0 percentage points.**
