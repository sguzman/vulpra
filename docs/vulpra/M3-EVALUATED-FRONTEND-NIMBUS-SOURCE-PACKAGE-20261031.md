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

## Actual generated FasterMake installation-manifest file parity

[**Original-source generated manifest CI 41247694163 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41247694163) read actual `faster/install_*` and `faster/unified_install_dist_bin` files from the two independently configured pinned Firefox 159 object directories. Its read-only comparison hashed complete generated file contents after normalizing only the corresponding configured objdir paths and basenames. The archived artifact `generated-faster-install-manifests.json` was inspected.

| Actual FasterMake generated manifest files | Full normal | Four-opt-in lean |
| --- | ---: | ---: |
| Total manifest files | **93** | **94** |
| Shared paths | **93** | **93** |
| Identical normalized shared files | **90** | **90** |
| Differing normalized shared files | **3** | **3** |
| Unique files | **0** | **1** |

The **only lean-only generated manifest file** is `install_dist_bin_moz-src_toolkit_components_nimbus`, consistent with the separately verified Normandy-disabled Nimbus bootstrap fallback. The three differing existing generated manifest files are precisely `install_dist_bin`, `install_dist_bin_browser`, and `unified_install_dist_bin`. Counts and complete file hashes have been checked; **individual entries of those three manifest files have not yet been parsed and reconciled**, nor have package installation or runtime resource resolution been executed by this check.

This narrows original-source **generated installer declaration ownership** but is not proof of installed final package contents, generated resource bytes, actual native compiler/linker invocation, FFI or conditional `dlopen` closure. It provides **no permission to prune further source**. M3 remains **5/6 (83%)**, overall Vulpra **61%**, and accepted milestone delta **+0pp**.

## Actual Mozilla CompileDB declared native compiler command parity

[**Original-source full-vs-lean CompileDB generation 41247908462 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41247908462) ran the pinned original Firefox 159 `./mach build-backend -b CompileDB` against **each independently configured** Linux objdir, **without invoking a compiler or linker**. A bounded verifier compared exact `[file, directory, command]` tuples after normalizing only each variant's configured object-directory path and name, preserving all declared flag and argument strings. The full `compile_commands.json` contents were **not archived**; only reconciliation counts and bounded differing file identities were preserved in `compile-command-declarations.json`.

| Actual generated CompileDB records | Normal | Four-opt-in lean | Unique to either |
| --- | ---: | ---: | ---: |
| Emitted compiler command entries | **12,028** | **12,028** | — |
| Distinct normalized complete command tuples | **12,028** | **12,028** | **0** |
| Identical normalized complete command tuples | **12,028** | **12,028** | — |
| Differing source-file identities | **0** | **0** | **0** |

This is *stronger than emitted `BaseSources` membership parity* because it includes generated C/C++ compiler command strings, arguments, and flags from the actual Mozilla CompileDB backend. It does **not** prove the commands were executed, what generated source bytes contain, the actual native object outputs or their equality, Cargo/`rustc` commands, linker command-line/archives, FFI edges, dynamic `dlopen` use or installed browser behavior. The earlier compiled native smoke tests remain separate evidence. No new source pruning or package-size savings are authorized. **M3 remains 5/6 (83%); overall 61%; accepted delta +0pp.**

## Actual serialized FasterMake installer-manifest record delta

[**Source-pinned Mozilla InstallManifest v5 serialized-entry reconciliation 41248639266 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41248639266) examined only the **three differing existing** generated FasterMake manifest files and the **one lean-only Nimbus manifest**. Records were validated as version 5 and split on Mozilla's actual ASCII unit-separator format, compared exactly after the configured object-root normalization, and destination names were sampled at a bounded size. The full serialized manifests and host paths were not archived.

| Changed manifest | Full records | Lean records | Full-only exact records | Lean-only exact records |
| --- | ---: | ---: | ---: | ---: |
| `install_dist_bin` | **1,687** | **1,682** | **13** | **8** |
| `install_dist_bin_browser` | **3,875** | **3,918** | **3** | **46** |
| `unified_install_dist_bin` | **6,152** | **6,191** | **16** | **55** |

The new lean-only `install_dist_bin_moz-src_toolkit_components_nimbus` contains precisely **one record**, declaring `NimbusBootstrap.sys.mjs`. Representative changed destination declarations include opt-in Normandy/ASRouter paths, the new-tab `lib/*` wildcard versus individually declared resources, and generated/preprocessed toolkit files.

**Interpretation boundary:** An exact serialized record can differ even if its **destination is unchanged** (for example preprocessing inputs or manifest content), and a wildcard can account for many concrete resources without explicit one-to-one records. The full-only and lean-only counts must therefore **not** be presented as physical package file additions/removals. This proves bounded generated installer rule differences, not final installed package bytes or browser runtime resource behavior. No new source deletion or package-size saving. M3 **5/6 (83%)**, overall **61%**, delta **+0pp**.

## Evaluated Mozilla Rust static-library Cargo ownership and feature parity

[**Original pinned source Rust `BaseRustLibrary` source-ownership inventory 41249357750 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41249357750). The unchanged Firefox 159 source was separately configured for full-normal and combined lean. After all original `BuildReader`/`TreeMetadataEmitter` objects were emitted, the observer enumerated each actual Rust static-library target identity, source-relative `Cargo.toml`, Cargo crate/profile options, target/host kind, direct Cargo dependency **names**, and explicitly requested Rust features. I inspected the archived `full-normal-evaluated.json` and `combined-four-evaluated.json` record sets directly, not only the CI status.

| Actual evaluated Rust static-library declarations | Full normal | Combined lean | One-sided records |
| --- | ---: | ---: | ---: |
| Emitted Rust static-library target identities | **4** | **4** | **0** |
| Explicit Rust feature declarations | **18** | **18** | **0** |
| Direct Cargo dependency-name declarations | **39** | **39** | **0** |

The four source-root libraries are `toolkit/library/rust` (`gkrust`), `toolkit/crashreporter/crash_helper_server`, `toolkit/components/uniffi-bindgen-gecko-js/components`, and `toolkit/components/uniffi-bindgen-gecko-js/test-fixtures`. This is an **exact evaluated frontend root-and-direct-declaration parity** check, **not** Cargo's resolved transitive package graph, activated feature graph, actual `rustc` invocations, combined native linker inputs, compiled crate artifacts, Rust/C++ FFI linkage or conditional runtime `dlopen`. No browser or profile changes and no new source removal or binary savings. **M3 5/6 (83%), overall 61%, Δ0pp.**

## Emitted Rust program Cargo root ownership

[**Pinned original-source full/lean Rust executable target inventory 41249591785 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41249591785). The expanded real `BuildReader`/`TreeMetadataEmitter` inventory also enumerates `BaseRustProgram` target and host program records with original source-relative `Cargo.toml` roots, target kind and explicitly requested program features.

| Actual evaluated Rust program declarations | Full normal | Combined lean | One-sided |
| --- | ---: | ---: | ---: |
| Rust program target identities | **2** | **2** | **0** |
| Explicit program feature records | **0** | **0** | **0** |

The two emitted programs are `toolkit/components/uniffi-bindgen-gecko-js` (`uniffi-bindgen-gecko-js`) and `toolkit/crashreporter/client/app` (`crashreporter`). The same archived run reverified **4/4** Rust static-library targets, **18/18** static-library features, and **39/39** direct Cargo dependency declarations with **zero one-sided records**. This closes the **bounded evaluated Mozilla Rust executable/static-library roots** inventory, not Cargo's full transitive feature-resolved package graph, `build.rs` outputs, `rustc` commands, dynamic linking, native/Cargo FFI, or runtime `dlopen` closure. No removal, new size saving, or M3 gate credit: **M3 5/6 (83%), overall 61%, Δ0pp.**

## Actual pinned offline Cargo metadata dependency-and-feature resolution

[**Pinned full/lean `gkrust` Cargo metadata resolution 41250371149 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41250371149), [**workflow lint 41250371146 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41250371146). The verifier read the exact 17 explicitly emitted `gkrust-shared/*` feature requests from the normal and lean original-source evaluated frontend artifacts, temporarily activated the existing Mozilla vendored Cargo config **only in the ephemeral CI source checkout**, and invoked `cargo metadata --offline --locked --format-version 1 --manifest-path toolkit/library/rust/Cargo.toml --features <emitted list>` separately for each variant. No Cargo dependency download, `rustc`, native compiler, or linker execution occurred.

| Offline Cargo metadata | Full normal | Four-opt-in lean | One-sided |
| --- | ---: | ---: | ---: |
| Requested `gkrust` Cargo features | **17** | **17** | **0** |
| Resolved workspace package records | **889** | **889** | **0** |
| Resolved node records with activated feature sets and dependency edges | **889** | **889** | **0** |

Every complete normalized `[package-ID, enabled-feature-set, dependency-kind/target edges]` node matched, as did the package identity/version/source records. These are real **Cargo-resolved metadata** and more conclusive than comparing only `Cargo.toml` root declarations or `Cargo.lock` text. **Important scope:** Cargo's metadata output includes the *entire workspace* under the requested `gkrust` features, not just nodes transitively reachable from `gkrust`. The other emitted Rust root libraries/programs' distinct explicit feature combinations were not independently resolved in this check, and build-script output / actual `rustc` command lines / native linker object archives / FFI and conditional runtime `dlopen` remain outside scope. The raw Cargo metadata and filesystem paths were not uploaded, only bounded aggregate evidence.

No profile/browser modified and no new source pruning or packaged savings. **M3 remains 5/6 (83%); Vulpra overall 61%, milestone delta +0pp.**

## Isolated actual `gkrust`-reachable Cargo closure

[**Pinned offline `gkrust` reachable resolved dependency graph 41250793026 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41250793026). The bounded verifier took the same 17 original Mozilla frontend feature requests, invoked `cargo metadata --offline --locked`, then followed each actual `resolve.nodes[].deps[].pkg` edge starting at the metadata package ID for `gkrust`. A visited-ID set handled cycles/repeated dependencies, and each reachable node's complete activated feature set, dependency package IDs, kind and platform target was compared across the two separately configured original full/lean runs. Raw Cargo metadata and host paths were never uploaded.

| Exact Cargo metadata graph | Full normal | Combined lean | One-sided |
| --- | ---: | ---: | ---: |
| Workspace-wide resolved node records | **889** | **889** | **0** |
| **`gkrust`-reachable resolved node records** | **747** | **747** | **0** |
| Identical reachable node/feature/dependency-edge records | **747** | **747** | — |

This provides a concrete, bounded `gkrust` **transitive resolved dependency closure** within the pinned workspace activation context, rather than equating the entire 889-node workspace to the `gkrust` subtree. It still does **not** independently resolve each of the other Mozilla Rust root libraries/programs with its own requested features or establish feature unification during an actual full native build, `build.rs` products, final compiled crate objects, linker/FFI/dlopen closure or runtime behavior. This is a source/configure-time equivalence result, not a reduction in compiled Rust. **M3 remains 5/6 (83%), overall 61%, accepted milestone delta +0pp.**

## Remaining five Mozilla Rust roots: independent offline feature-resolved closures

[**Pinned original-source other-five-root Cargo resolution 41251318660 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41251318660), [**workflow lint 41251318658 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41251318658). The bounded resolver read the actual `BaseRustLibrary` and `BaseRustProgram` frontend target/manifest identities, independently invoked offline locked Cargo metadata with **each root's own emitted feature list**, followed resolved package-ID dependencies from the root and compared the reachable package, activated feature and edge records across independently configured full-normal and combined-four-lean builds.

| Rust root manifest (source-relative) | Requested features (each) | Reachable resolved nodes (each) | Full/lean mismatches |
| --- | ---: | ---: | ---: |
| `toolkit/components/uniffi-bindgen-gecko-js/Cargo.toml` | **0** | **90** | **0** |
| `toolkit/components/uniffi-bindgen-gecko-js/components/Cargo.toml` | **1** | **278** | **0** |
| `toolkit/components/uniffi-bindgen-gecko-js/test-fixtures/Cargo.toml` | **0** | **125** | **0** |
| `toolkit/crashreporter/client/app/Cargo.toml` | **0** | **325** | **0** |
| `toolkit/crashreporter/crash_helper_server/Cargo.toml` | **0** | **102** | **0** |

Together with [the independently verified `gkrust` root (747 reachable nodes, 17 requested features, zero full/lean mismatches)](https://github.com/sguzman/vulpra/actions/runs/41250793026), **all six emitted Rust library/program roots** now have individually compared offline lockfile-pinned, feature-resolved reachable dependency graphs. These per-root closure sizes **overlap** and cannot be summed into unique crates. Each invocation uses Cargo workspace resolution, so activated feature sets are contextual to its selected manifest and requested features and are not proof of the exact unification in a full build invoking multiple targets together.

The raw `cargo metadata` files, full environment paths and Rust build invocations were not archived. No `build.rs` execution, compiled `rustc` artifacts, actual native link command/objects, Rust/C++ FFI or dynamic `dlopen` closure is established. No source pruning or new binary/package savings. **M3 remains 5/6 (83%), Vulpra overall 61%, milestone delta +0pp.**

## Actual emitted native-link-target ownership of Rust staticlibs

[**Pinned original-source typed Rust-to-native `Linkable.linked_libraries` inventory 41251904637 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41251904637). After the full original Mozilla BuildReader/emitter traversal, the observer walked actual library object identities in each `Linkable.linked_libraries` set, isolating links whose target is an emitted `BaseRustLibrary`, with source-relative consumer identity and Rust static-library target identity, both independently configured variants.

| Native target (emitted `Linkable`) | Directly linked emitted Rust static library | Full vs. combined lean |
| --- | --- | --- |
| `toolkit/library/build` / `libxul.so` | `toolkit/library/rust` / `libgkrust.a` | **Identical** |
| `toolkit/crashreporter/crash_helper` / `crashhelper` | `toolkit/crashreporter/crash_helper_server` / `libcrash_helper_server.a` | **Identical** |

Both original full and combined lean emitted **2 exact Rust-staticlib-to-native-consumer edges** and **0** library-link edges originating at the Rust static-library `Linkable` objects themselves; the two consumer-edge sets are **exactly identical**. The two separately enumerated UniFFI static-library targets had no direct link consumers in this narrowed set, which does **not** imply these crates are unused: their generated code and target-specific linkage can exist outside this exact direct `linked_libraries` relation.

**Scope is precisely source-evaluated linking ownership.** No actual compiler command/link invocation, archive members, ELF symbol lookup or Rust/C++ FFI call sites were checked here; neither runtime conditional loading nor `dlopen` is closed. This does not authorize deleting a Rust root or claim compiled binary savings. **M3 stays 5/6 (83%), overall 61%, delta +0pp.**

## Rust staticlib transitive native-consumer reachability

[**Pinned original Mozilla emitted Rust staticlib reverse-Linkable inventory 41252792147 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41252792147). A read-only observer follows the **complete evaluated declared consumer → linked-library graph in reverse** from each of four emitted Rust static-library roots, recording the shortest native consumer distance. The archived original full/combined four-opt-in artifacts were independently inspected, not inferred from repository source.

| Emitted Rust static library | Full and lean downstream consumers | Distance |
| --- | --- | --- |
| `libgkrust.a` | `libxul.so` | 1 |
| `libgkrust.a` | `plugin-container`, `xpcshell` | 2 |
| `libcrash_helper_server.a` | `crashhelper` | 1 |
| Two UniFFI static-library roots | No native consumer within this **particular emitted relation** | Not applicable |

Both variants have **4 Rust roots, 2 direct Rust-to-native link edges, 4 reachable native consumer records, 2 roots without directly emitted native consumers, and 0 full/lean differences**. Absence of a direct Mozilla `linked_libraries` edge does **not** prove the UniFFI crates unused; Cargo/integration relations and generated FFI can lie outside that relation. Cycles are bounded via shortest-path traversal. No compiler/rustc/linker execution, build artifact attribution, complete FFI call graph, or dynamic loader closure was proven.

## Actual compiled full-versus-opt-in ELF dynamic import/export ABI surface

[**Checksum-authenticated source-matched full vs combined-four native dynamic-symbol export audit 41253276903 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41253276903), [**workflow lint 41253276916 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41253276916). The independent std-only Rust observer `ci/m3-combined-four-elf-dynsym-abi.rs` compiled and passed its fixtures, authenticated both separately built original-source browser packages using existing pinned SHA-256 and successful build-run identities, then examined the **actual ELF dynamic symbol tables** read-only with `readelf --wide --dyn-syms`, without invoking the browser executables. The [**expanded paired imported-and-exported symbol audit 41253438551 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41253438551), [**lint 41253438662 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41253438662) additionally checks undefined dynamic import records and requires positive import inventories. Its exact archived JSON was downloaded and inspected.

| Checked compiled ABI surface | Full normal | Combined opt-in | Difference |
| --- | --- | --- | --- |
| Identical relative ELF member paths | 28 | 28 | 0 |
| Exported dynamic-symbol occurrences (name, type, binding, visibility, multiplicity; excluding relocation values and section-index layout) | **4,669** | **4,669** | **0** |
| Undefined dynamic-symbol imports (versioned name, type, binding, visibility, multiplicity) | **6,764** | **6,764** | **0** |
| **Total dynamic symbol occurrences** | **11,433** | **11,433** | **0** |
| ELF paths with exported-symbol record drift | — | — | **0** |

This extends the previously verified 28-ELF identical ordered `DT_NEEDED` inventory to an **actual compiled imported-and-exported dynamic ABI surface comparison**, not identical file bytes, internal/static Rust/C++ FFI symbols, linker arguments, runtime symbol binding, or late `dlopen`. It does not authorize deleting any Rust root, protected browser feature, or native library. No new compressed-byte savings or M3 gate credit. **M3 remains 5/6 (83%), overall 61%, Δ0 percentage points.**

### Actual compiled ELF `.text` section byte identity and limits

[**Read-only original compiled full vs combined-four `.text` comparison 41253658309 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41253658309), with [**per-differing-file exact byte metrics 41253791286 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41253791286). The same two independent original-source SHA-256-authenticated packaged native builds were read without execution. `objcopy` extracted each actual ELF `.text` section into ephemeral CI files; `cmp` checked exact byte identity. The follow-up streamed and counted mismatched byte positions over the shared prefix of each differing pair.

**23/28 compiled ELF `.text` sections are byte-identical; 5/28 differ.**

| Differing compiled ELF | Full `.text` bytes | Lean `.text` bytes | Mismatched byte offsets in common prefix |
| --- | ---: | ---: | ---: |
| `crashhelper` | 1,221,487 | 1,221,487 | 10,693 |
| `crashreporter` | 2,738,341 | 2,738,341 | 15,658 |
| `libxul.so` | 128,073,093 | 128,073,125 | 110,373,438 |
| `vulpra` | 414,754 | 414,754 | 1,462 |
| `vulpra-bin` | 414,754 | 414,754 | 1,462 |

These are **byte-position differences**, **not** counts of changed functions, semantic code differences, missing dependencies, or broken behavior. The 32-byte `libxul.so` section length difference can shift downstream byte offsets, so its large mismatch count must **not** be interpreted as 110 million independently changed instructions. Build and link layout, symbolized disassembly and code provenance are not reconciled here. Dynamic symbol names and multiplicities nevertheless remain identical in all 28 ELF paths. This specifically prevents claiming bit-for-bit complete native code identity merely from ABI parity. No new compiled size savings, source pruning or M3 sixth-gate credit. Overall **61%**, M3 **5/6 (83%)**, Δ0pp.

### Source-matched compiled `.text` layout resynchronization

[**Pinned actual ELF code-section alignment audit 41254104883 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254104883), [**workflow lint 41254104846 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254104846). The read-only Rust inspector measured exact same-offset and size-difference-shifted byte positions, longest identical prefix and nonoverlapping suffix for the five previously established nonidentical compiled `.text` pairs. It audited the **same two SHA-256-authenticated original full and combined-four native packages** without executing them. Its archived JSON was inspected.

| Compiled code section | Full vs lean length difference | Exact common prefix | Nonoverlapping identical suffix | Conclusion allowed |
| --- | ---: | ---: | ---: | --- |
| `libxul.so` | lean **+32 bytes** | 17 B | 148 B | Large layout shift; not a single perfectly identical inserted block |
| `crashhelper` | 0 B | 162 B | 236 B | Some byte differences within equal-size section |
| `crashreporter` | 0 B | 995 B | 241 B | Some byte differences within equal-size section |
| `vulpra`, `vulpra-bin` (each) | 0 B | 410 B | 6,830 B | Some byte differences within equal-size section |

For `libxul.so`, **17,699,655 / 128,073,093 positions (13.82%)** are equal at their same index, but **115,507,445 / 128,073,093 (90.19%)** match if the lean section is read **32 bytes ahead**. This is strong evidence that code layout displacement accounts for much of the previously observed 110,373,438 same-index mismatches. However, the full shifted streams do **not** match perfectly, and neither the exact contiguous-insertion nor complete code identity condition passed. It does **not** count equal functions, prove semantic equivalence, identify the cause of layout drift, or verify static Rust/C++ FFI and late `dlopen`. No new source pruning, compiled savings, or final M3 gate credit. **M3 5/6 (83%), overall 61%, Δ0pp.**

### Compiled libxul named exported-function byte ownership

[**Symbol-address matched actual original full/combined compiled `libxul.so` function comparison 41254295260 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254295260), [**lint 41254295193 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254295193). The independent Rust verifier read the real compiled `.text` bytes at the virtual addresses declared by `readelf --wide --dyn-syms`, normalizing each function to its own symbol-address/length rather than file offset. Unit fixtures and source-matched SHA-256 package checks passed; the bounded machine report was inspected.

There were **exactly 2 eligible named defined exported `FUNC` symbols** in each `libxul.so`; both matched across the variants with equal function lengths and **exactly +32 bytes** of lean relative `.text` offset displacement. **1 function body was byte-identical; 1 differed**, the retained exported symbol `XRE_GetBootstrap@@libxul.so`. The absence of additional defined dynamic exported functions in this specific native ELF is a **severe coverage limit**, not evidence that the other compiled code, stripped/internal symbols, Rust/C++ FFI, or runtime dynamic loading is unchanged. No pruning, compiled size savings, or M3 sixth-gate credit; **M3 5/6 (83%), overall 61%, Δ0pp**.

### Compiled `libxul.so` unwind-described code-range comparison

[**Pinned actual source-matched native `.eh_frame` FDE code-range comparison 41254586276 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254586276). Rust std-only source `ci/m3-libxul-unwind-fde-shift.rs` streamed the actual compiled original full and combined-four lean ELF unwind FDE records (without uploading raw FDE paths or executing browser code), bounded records and output lines, checked each range against actual `.text` boundaries, then compared code bytes at matching native offsets, with and without the observed +32-byte lean displacement. The workflow and fixtures passed and its archived JSON was inspected.

| Native compiled FDE and code-range metric | Normal | Combined lean |
| --- | ---: | ---: |
| Raw FDE records | **282,697** | **282,697** |
| FDE records outside `.text` | 3 | 3 |
| Unique in-`.text` unwind-described ranges | **282,694** | **282,694** |

| Tested original → lean alignment | Zero offset | Lean +32 B |
| --- | ---: | ---: |
| Matching declared FDE-range boundaries | **37,740** | **253,073** |
| Corresponding ranges with identical `.text` bytes | **11,396** | **87,913** |
| Corresponding ranges with differing `.text` bytes | 26,344 | **165,160** |
| Sum of byte-identical range spans (not unique coverage) | 992,474 | **14,717,219** |

**253,073 / 282,694 (89.5%)** of original unwind ranges have a same-length, exact FDE boundary witness **at the +32-byte position** in lean. This gives strong, function-like (unwind-described) structural evidence for the widespread linker/code-layout displacement, far beyond the **two** defined dynamic exported `FUNC` symbols. The 165,160 shifted-boundary matched but byte-different FDE code spans prevent claiming native bit identity; byte changes may include address-relative instructions, but their meaning is **not established**. FDE ranges need not cover every machine-code function, can overlap, and identical span byte totals cannot be treated as unique verified code coverage. No full executable linker/reproducibility or static Rust/C++ FFI graph, conditional `dlopen` closure, source pruning or further package savings; M3 stays **5/6 (83%)**, overall **61%**, Δ0pp.

### Exclusive original ELF `.eh_frame` zero-vs-32-byte range reconciliation

[**Exact source-matched compiled `libxul.so` FDE alignment partition 41254766335 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254766335), [**lint 41254740114 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254740114). The original source-pinned full versus four-opt-in lean native ELF verifier now counts each full-build FDE range **exactly once**, classified as matching the lean emitted FDE boundary at zero offset, +32 bytes, both offsets, or neither. The archived JSON passed fail-closed arithmetic checks and was inspected.

| Mutually exclusive original `.text` unwind FDE classification | Full-origin distinct FDE ranges |
| --- | ---: |
| Zero offset only | **29,619** |
| +32 bytes only | **244,952** |
| Both placements | **8,121** |
| Neither placement | **2** |
| **Total** | **282,694** |

Therefore **282,692 / 282,694 (99.9993%)** of original unwind-described code-range boundaries have at least one exact corresponding lean range at these two placements. **99,201** original FDE ranges also have equal actual machine-code bytes under at least one of the two placements (not unique function/code coverage). The regional one-eighth census is particularly diagnostic: in the **last seven eighths**, all **236,819** original FDE ranges have a +32-byte lean counterpart and **zero** fail both alignments. The **first eighth** contains 45,875 FDE ranges with 32,375 zero-offset matches, 16,254 shifted matches and **two** unmatched FDE boundaries (the zero/shift matches can overlap). This strongly narrows the native compiled layout-boundary discrepancy to an early transition; it does **not** prove a single inserted 32-byte instruction block, source reason, full code equivalence, disassembly equivalence, Rust/C++ FFI, actual linker command parity or arbitrary runtime `dlopen` coverage. No new pruning, size savings or full M3 sixth gate credit; **M3 5/6 (83%), overall 61%, Δ0pp.**

### Numeric native linker-layout hinge in original `libxul.so`

[**Exact-source checksum-authenticated native FDE transition locator 41254941837 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254941837), [**lint 41254941840 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41254941840). After proving the 282,692/282,694 two-offset boundary reconciliation, a separate bounded read-only `.text` code-address audit identified the monotonic transition region. Offsets here are measured **relative to the beginning of original compiled `.text`**, not source-code line numbers, function names, or ELF file offsets.

- Last *zero-only* original FDE range starts at byte **11,654,880**.
- First *+32-only* original FDE range starts at byte **11,655,824**.
- The two original FDE intervals that fail both placements are **[11,654,896, 11,655,350)** (454 B) and **[11,655,360, 11,655,821)** (461 B).
- **Zero** zero-only original FDEs occur after the first +32-only record, and **zero** +32-only original FDEs precede the last zero-only record.

Thus the exclusive layout transition occurs within a tightly bounded **944-byte window between those start offsets**, surrounding exactly two original unmatched FDE ranges. The FDE scan still covers only unwind-described intervals; many ranges at matching offsets have differing machine-code bytes, so the evidence does **not** establish a single inserted code sequence, source-level cause, same runtime semantics, or full native FFI/dlopen dependency closure. There is no authorization to prune any code based solely on this mapping. **Overall 61%, M3 5/6 (83%), Δ0pp.**

### Exact native 32-byte layout delta explained by two anonymous unwind ranges

[**Source-pinned full vs four-opt-in compiled native two-range/gap arithmetic 41255162049 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41255162049), [**workflow lint 41255162053 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41255162053). The follow-up read-only FDE inspector exposed **six** lean FDE intervals adjacent to the monotonic hinge, and a strict machine-checked independent `jq` audit reconciled the original two unmatched code-range lengths and the respective inter-range gaps. The final archived JSON was inspected, rather than relying on the workflow status alone.

| Exact source-pinned compiled native component | Original `.text` | Combined four-opt-in lean `.text` | Difference |
| --- | ---: | ---: | ---: |
| First anonymous unwind-described range | **454 B** | **466 B** | **+12 B** |
| Gap between these ranges | **10 B** | **14 B** | **+4 B** |
| Second anonymous unwind-described range | **461 B** | **473 B** | **+12 B** |
| Gap to next corresponding FDE boundary | **3 B** | **7 B** | **+4 B** |
| **Total layout growth at the hinge** | | | **+32 B** |

The first original and lean range share `.text` starting offset **11,654,896**. The next original FDE shift-only start at **11,655,824** matches the lean start at **11,655,856**, precisely +32 bytes. The exact `12 + 4 + 12 + 4 = 32` decomposition **fully accounts for the change in layout addresses after this transition**. The gaps are measured byte distances between FDE intervals; their contents and reasons for growth were **not** asserted to be padding instructions. Likewise these two ranges have no established named source owner or identical semantics. This explains an important compiled address-layout discrepancy but **does not** close full native/Rust/C++ FFI symbol equivalence, actual linker command reproducibility, or unobserved runtime `dlopen` dependencies; it permits no source pruning or new packaged-savings claim. **M3 remains 5/6 (83%), overall 61%, Δ0pp.**

### Compiled packaged source-function attribution limit

Both independently compiled original-source package artifacts were inspected read-only and individually verified against their retained SHA-256 sidecars: [**normal full native run 40997075527**](https://github.com/sguzman/vulpra/actions/runs/40997075527) and [**four-opt-in lean run 41222758405**](https://github.com/sguzman/vulpra/actions/runs/41222758405). Only the actual packaged `vulpra/libxul.so` member was extracted from each archive in an isolated analysis workspace; no application executable was run.

Neither packaged `libxul.so` has `.symtab`, `.debug_info`, or `.debug_line` sections. Both carry a `.gnu_debuglink` section whose declared separate debug-info filename is **`crti.o`**, not a usable `libxul.so` source-symbol companion in these artifacts. Consequently the two anonymously named native FDE code ranges (454→466 B and 461→473 B) **cannot be reliably attributed to source function names using these packaged ELF symbols alone**. A separately retained exact-build link map or proper debug-symbol artifact would be needed to assign them source identities. This is an attribution and evidence-retention limitation, **not** proof of a browser runtime defect or of source-level semantic changes.

This manual bounded artifact inspection does not grant deletion authority, new packaged savings or the final M3 dependency-closure gate; **M3 5/6 (83%), overall 61%, Δ0pp.**

### Actual compiled hash-divisor root cause of the two anonymous `libxul.so` code-range growths

[**Independent original compiled ELF disassembly and hashed-divisor witness 41256689265 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41256689265), [**workflow lint 41256689254 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41256689254). The std-only Rust inspector `ci/m3-libxul-hinge-assembly.rs` uses system `objdump` to inspect only the two previously checksum-pinned source-matched full-vs-combined-lean `.text` FDE code intervals. Its synthetic opcode-sequence fixtures pass and its bounded result JSON was independently downloaded and inspected. This resolves **why the two native code ranges grew by 12 bytes each**, without relying on stripped names or claiming full source ownership.

| Native code-range feature | Full normal original | Four-opt-in lean original |
| --- | ---: | ---: |
| First FDE range size / instructions | **454 B / 115** | **466 B / 120** |
| Second FDE range size / instructions | **461 B / 115** | **473 B / 120** |
| Integer remainder divisor embedded in both routines | **652 (`0x28c`)** | **651 (`0x28b`)** |
| Reciprocal multiplication constant used by compiler | `0xc907da4f` | `0x92add007` |
| Common 32-bit hash multiplication constant | `0x1000193` | `0x1000193` |

Both FDE pairs retain the entire original **115-mnemonic ordered subsequence** and add exactly **five** lean mnemonics: `mov`, `sub`, `shr`, `add`, `shr`, with **none removed**. The changed reciprocal-division sequence implements remainder by **651 instead of 652**, accounting for the **+12 B in each routine** and hence the earlier fail-closed **12+4+12+4 = 32 B** layout decomposition. An independent deterministic 50,007-value arithmetic spot-check per divisor matched the modulo results; this is supportive local math, not exhaustive theorem proving.

The native function input performs FNV-style byte mixing (same `0x1000193` prime), and the assembly references an adjacent indexed static table. The change is produced by an indexed perfect-hash table; the subsequent pinned source/native crosswalk below identifies its XPCOM/AboutRedirector registration owner. Runtime equivalence and the wider dependency closure remain unverified. Mnemonic ordered-subsequence equality does *not* prove identical operations or semantics: the compiler has changed division/remainder arithmetic by construction. The original packaged binaries remain stripped, lacking a reliable named source-function owner for these ranges. No new source pruning, savings, linker/FFI/dlopen closure or sixth-gate credit. Overall **61%**, M3 **5/6 (83%)**, Δ0pp.

### Original compiled indexed hash-table cardinality and single anonymous field difference

[**Source-pinned compiled `libxul.so` 8-byte indexed table check 41257069967 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257069967), [**workflow lint 41257070033 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257070033). The Rust disassembly witness independently reads the actual `.rodata` bytes behind the verified 652-versus-651 integer remainder operations in both original full and four-opt-in native packages, and follows the next indexed-array address to validate element stride and alignment. The archived machine report from [**initial evidence run 41257052284 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257052284) was inspected.

| Anonymous original native table property | Full | Four-opt-in lean |
| --- | ---: | ---: |
| Actual indexed 8-byte records | **652** | **651** |
| Distinct first 32-bit words | 652 | 651 |
| Distinct second 32-bit words | **535** | **535** |
| Zero bytes to next aligned compiled array | 0 | **8** |
| Occurrences of *uninterpreted* second word `452` | **36** | **35** |

All other **534 distinct second-field values** maintain identical frequencies. This independently ties the compiled remainder-divisor change to a **one-record reduction in the indexed static data**, with no offset/stride guess required. The meaning of either 32-bit record field is **not established**: `452` is a raw binary value, **not** an authorized Mozilla feature ID, function, property, asset or user-facing removal. The FDE machine-code growth remains proven, but neither the source owner nor safe removal semantics are. No source pruning, new package savings, or final M3 gate credit; **M3 5/6 (83%), overall 61%, Δ0pp.**

### Original XPCOM AboutRedirector source and native module ID 452 crosswalk

[**Pinned original-source and compiled native module-ID reconciliation 41257697927 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257697927), [**workflow lint 41257697908 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257697908). The small Rust source guard was run against the **exact Vulpra source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`**, not current Firefox defaults, and compared with both checksum-pinned original compiled browser archives. The archived source and binary crosswalk reports were independently inspected.

- Exact pinned `browser/components/about/components.conf` contains **31** ordinary AboutRedirector page contracts; `MOZ_SELECTABLE_PROFILES` (unconditionally set true in the pinned `toolkit/moz.configure`) adds **four**; `MOZ_NORMANDY` adds precisely **one**, `studies`. Thus the original full build registers **36** AboutRedirector contracts; the guarded four-opt-in lean build registers **35**. The excluded contract is **`@mozilla.org/network/protocol/about;1?what=studies`**. `AboutRedirector.cpp` independently guards the corresponding route with `#ifdef MOZ_NORMANDY`, preserving the non-Normandy AboutRedirector.
- Pinned `xpcom/ds/PerfectHash.h` and `xpcom/components/gen_static_components.py` match the observed two-stage FNV code generation. The generated `ContractEntry` holds a string offset and a **ModuleID**, and `StaticComponents.h` defines that ModuleID as an index into `gStaticModules`.
- **Direct native code and CID verification**: both original packaged `libxul.so` variants calculate module-record addresses with a **28-byte stride**. At `gStaticModules[452]`, the actual compiled 16-byte `nsID` exactly equals **`{7e4bb6ad-2fc4-4dc6-89ef-23e8e5ccf980}`**, the pinned AboutRedirector CID, in **both** packages. Thus the previously anonymous second 32-bit compiled contract-table field `452` is now independently mapped to AboutRedirector—not guessed from matching counts.
- In the same original compiled contract index, AboutRedirector ModuleID `452` occurs **36** times full and **35** times lean; the **534 other distinct ModuleID values** retain their frequencies. The compiled hash-table length therefore falls **652→651**, regenerating the reciprocal remainder by 652 vs 651 and causing the two **+12-byte** code expansions and two **+4-byte** inter-range gap changes already independently accounted for.

This closes the **source ownership and generated-code explanation of the specific 32-byte `libxul.so` transition**, not the full sixth M3 gate. The native archives were not executed in this audit, `about:studies` runtime handling was not exercised here, and completeness of unrelated FFI/linker/`dlopen` dependencies remains open. The normal build retains Normandy and `about:studies`; the lean removal is explicitly opt-in. No production pruning or additional savings. **M3 5/6 (83%), overall 61%, Δ0pp.**

### Compiled XPCOM contract literal and retained AboutRedirector controls

[**Checksum-verified original compiled `libxul.so` full-versus-four-opt-in contract string and source crosswalk 41257817588 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257817588), [**lint 41257817568 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41257817568). A fail-closed read-only scanner checked the actual authenticated full and four-opt-in lean `libxul.so` bytes, independent of the generator inspection:

| Exact compiled XPCOM AboutRedirector contract string | Full original | Lean original |
| --- | --- | --- |
| `@mozilla.org/network/protocol/about;1?what=studies` | **Present** | **Absent** |
| `@mozilla.org/network/protocol/about;1?what=welcomeback` | Present | Present |
| `@mozilla.org/network/protocol/about;1?what=profilemanager` | Present | Present |

The machine crosswalk checks the string census against **36→35** original source contract declarations, **36→35** compiled AboutRedirector ModuleID `452` occurrences, and the **exact CID equality at `gStaticModules[452]` in both compiled browser packages**. It therefore demonstrates a specific intentional **Normandy-disabled `about:studies` native contract omission** while preserving two independently checked about-route controls. This is evidence of compiled **literal presence/absence and generated registration ownership**, **not an executed XPCOM lookup test**, a claim that the page loads successfully in normal builds, or a complete audit of all protected browser features. The remaining Rust/C++ FFI, other native linker inputs, and conditional `dlopen` closure are still unproved. No further source pruning, savings or sixth-gate credit; **overall 61%, M3 5/6 (83%), Δ0pp**.

### Source-matched original compiled typed and packed ELF relocation coverage

[**Actual original full-versus-four-opt-in 28-ELF native typed relocation and `libxul.so` packed RELR CI 41259530887 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41259530887), [**workflow lint 41259457000 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41259457000). Std-only Rust inspectors `ci/m3-original-native-relocation-shape.rs` and `ci/m3-libxul-packed-relr.rs` read both SHA-256-authenticated original-source native packages without executing browser code. All 28 exact matching packaged ELF paths were audited by GNU `readelf --wide --relocs`, and the additional packed `.relr.dyn` section of `libxul.so` was decoded explicitly from its original native ELF64 bytes. Negative fixtures passed. The archived bounded JSON reports from the final green run were downloaded and inspected.

| Actually compiled source-matched relocation metric | Original full | Combined four-opt-in lean | Per-record shape difference |
| --- | ---: | ---: | --- |
| Compiled ELF members examined | **28** | **28** | Same paths |
| Ordinary typed ELF relocation records | **46,356** | **46,356** | **0** per-ELF relocation-type differences |
| Named typed relocation-reference occurrences | **8,894** | **8,894** | **0** per-ELF named-reference differences |
| Packed `libxul.so` ELF64 `.relr.dyn` encoded 64-bit words | **13,206** | **13,206** | Not identical byte-for-byte |
| Decoded packed ELF64 relative relocation target offsets | **478,592** | **478,592** | Counts match; target addresses differ |
| **Ordinary typed + decoded packed target records** | **524,948** | **524,948** | Not a semantic graph-equivalence claim |

Both `.relr.dyn` sections have **26** direct-base words and **478,592** sorted unique decoded relocation target addresses. **6,884 / 13,206** original packed words match the lean word at the same encoded index; **327,359** relocation target addresses occur in both sets, but **0** decoded target offsets match *at the same positional index*, consistent with data-section relocation and changed link layout. Alignment of positional target offsets produces **43 distinct delta values**; the most common lean-minus-full shift is **+8,224 bytes for 372,931** targets. These offsets are not imported symbol names, and positional matching cannot establish identical relocation ownership. The former typed-relocation inspector deliberately excluded packed RELR, so these two separate checks are needed to cover the observed original format.

**Limit:** This strengthens the actual compiled ELF relocation *shape* inventory, which is more direct than previous mere `.dynsym` name parity, but it does **not** reveal relocated values/addends, prove resolved dynamic bindings, associate all internal C++/Rust FFI functions with retained source/build features, cover conditional `dlopen` routes, or establish runtime equivalence. Native linker/source pruning remains **not authorized**. No new package savings or additional M3 gate credit. **M3 5/6 (83%), overall Vulpra 61%, session Δ0pp.**

**Fail-closed acceptance update:** [**Cross-reconciled original compiled 28-ELF typed plus packed relocation CI 41259697697 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41259697697), [**GitHub Actions lint 41259697798 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41259697798). The final workflow now *requires*, rather than merely displays, exact **46,356** typed rows per build, **8,894** named references per build, zero changed per-ELF typed types or named references, **478,592** decoded native `libxul.so` packed RELR relocation offsets per variant, and exactly **524,948** combined records per variant. The independently produced combined JSON `original-compiled-typed-packed-relocation-crosswalk.json` was downloaded and inspected; its `actual_relocation_target_values_equivalent`, `source_removal_authorized`, and `m3_sixth_gate_closed` assertions remain explicitly **false**. This is the accepted reproducible relocation-shape subtask completion, **not** gate 6 completion.

### Exact-source native C++ → Rust FFI seams and compiled Rust source-file provenance

[**Original-source C++/Rust staticlib FFI witness 41261202884 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41261202884), [**workflow lint 41261203008 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41261203008), [**source-matched compiled Rust provenance 41261498555 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41261498555). The std-only Rust source inspector `ci/m3-static-rust-cpp-ffi-source-witness.rs` runs on immutable original Vulpra commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`. It verifies exact source Rust exports `#[no_mangle] pub extern "C"` and actual C++ callsites and declarations, pinned Cargo staticlib types, the Mozilla `USE_LIBS`/RustLibrary owning edges and generated cbindgen header. The separate compiled native inspector `ci/m3-original-compiled-rust-provenance.rs` reads only the independently built checksum-pinned full and lean ELF packages and requires original Rust source path witnesses in both native consumers.

| Actual declared Rust static archive | Native consumer | Verified exported Rust function and C++ use |
| --- | --- | --- |
| `libgkrust.a` | `libxul.so` | `GkRust_Init` — **2** original C++ calls in `xpcom/build/XPCOMInit.cpp` |
| `libgkrust.a` | `libxul.so` | `GkRust_Shutdown` — **1** original C++ call in the same source |
| `libcrash_helper_server.a` | `crashhelper` | `crash_generator_logic_desktop` — **1** original C++ call in `crashhelper.cpp`, through generated `crash_helper_ffi_generated.h` |

**Actual compiled provenance:** `libxul.so` in **both** original normal and lean packages retains the exact original `toolkit/library/rust/shared/lib.rs` Rust source filename; `crashhelper` in **both** retains `toolkit/crashreporter/crash_helper_server/src/lib.rs`, `src/ipc_server.rs`, and `src/breakpad_crash_generator.rs`, each once. The binary path witnesses were read from compiled ELF bytes rather than inferred from source; the archived JSON includes **4 full / 4 lean** exact source-path occurrences and explicit fail-closed negative acceptance flags. This demonstrates **two concrete native staticlib source roots with compiled Rust source provenance, three explicitly called C++→Rust FFI functions and four concrete C++ callsites**.

**Important scope boundary:** source-level FFI declarations/calls plus retained compiled Rust source filename strings do **not** prove a particular internal linker-resolved symbol/relocation or callsite machine instruction in these stripped archives, nor enumerate every source or generated FFI boundary, static library/archive member, or conditional runtime `dlopen` dependency. This is a meaningful **narrow source-to-binary provenance crosswalk**, not completion of the sixth M3 gate. No changes to installed Firefox, source pruning, new compressed savings, or progress percentage. **M3 5/6 (83%), Vulpra overall 61%, Δ0pp.**

### Exact original unstripped Rust archive-to-ELF symbol definitions (2026-11-01 UTC)

[Corrected native source-pinned compilation and symbol proof **41266265493 PASS**](https://github.com/sguzman/vulpra/actions/runs/41266265493), artifact **13068918079** independently inspected. After a previous successfully compiled source-matched original Firefox build [41261983583](https://github.com/sguzman/vulpra/actions/runs/41261983583) hit the original auditor's **2 GiB maximum input-file bound**, the proof was rerun with explicit bounded file-size diagnostics and a **16 GiB upper bound**. The corrected native job compiled unmodified original source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and successfully ran the real GNU `nm` archive-plus-ELF verifier. The report `m3-original-ffi-symbol-definitions.json` says `status="compiled_archive_and_consumer_named_definitions_verified"`, with **3/3 original archive-to-linked-ELF function-definition pairs** and **one external defined text symbol in each expected inspected input**:

| Exact original Rust static archive | Native linked consumer | Verified named function definition in both |
| --- | --- | --- |
| `libgkrust.a` | `libxul.so` | `GkRust_Init` |
| `libgkrust.a` | `libxul.so` | `GkRust_Shutdown` |
| `libcrash_helper_server.a` | `crashhelper` | `crash_generator_logic_desktop` |

This advances the earlier *source-only/retained-source-path* provenance into **actual original linked named definitions**, but it does not independently associate all **four original C++ callsites** with native relocation targets, prove all internal or generated FFI seams, demonstrate functional execution of the Rust exports, or establish unobserved runtime conditional loading. The original diagnostic report also retains the prior test-only `MOZ_Crash`/network-guard trace; that report is not a new graphical acceptance. The proof flags are explicitly `complete_static_callsite_resolution_proven=false`, `conditional_dlopen_closure_proven=false`, `source_pruning_authorized=false`, and `m3_sixth_gate_closed=false`. **M3 5/6 (83%), overall 61%, Δ0 pp**, no new source deletion or accepted package savings.

## Boundaries and next actual work

The selected opt-in features **do not shrink the evaluated directory-traversal graph**; they change guarded packaged JS/resources and add a Nimbus bootstrap fallback. The previous separately verified compiled 28-ELF direct library-import graph also remained unchanged. Consequently this 26,136-byte combined compressed-archive delta cannot be projected into eliminated native libraries or a smaller Gecko compilation tree.

The final M3 gate still requires **file-level member ownership for remaining emitted object classes and backend rules**, generated installer/JAR assets, conditional linker and FFI edges, and unknown late runtime `dlopen`/platform paths. This result specifically closes the bounded "`MOZ_SRC_FILES` explicit source-file delta" subtask, not the full build graph. None of these results authorize further source pruning, disabling protected Sync/telemetry/security behavior or calling M3 completed. No user's installed browser or profile was touched.

**M3 remains 5/6 gates (83%); Vulpra overall remains 61%; accepted milestone delta +0 percentage points.**
