# M3 — Independent native CI artifact reconciliation (2026-11-04 UTC)

## Exact artifact and independently supplied run identity

The source-matched normal native build [GitHub Actions run 41749398233](https://github.com/sguzman/vulpra/actions/runs/41749398233) **SUCCEEDED** at source `d5cfdb360ec9c3f9d113b2dbcbddaed74f406dfd`. Its bounded ZIP artifact **13287746750**, named `m3-source-matched-native-link-evidence`, was downloaded independently (ZIP SHA-256 `28a283993c808dd0783995808631109490a4bae8b04db088159be4a16c86f909`).

New read-only verifier: [`ci/m3-native-artifact-reconcile.py`](../../ci/m3-native-artifact-reconcile.py). It requires trusted workflow-run head SHA and run ID from GitHub metadata, independent of any artifact field. It processes **exactly seven** sanitized artifact records; rejects unexpected, duplicate, unsafe-path, symlink or overlarge ZIP entries; recomputes the dependent metadata from all native ELF/edge rows; crosschecks source and compressed archive SHA, physical package size, unstripped/stripped `libxul` replay identities, preload order, 14 protected generated flags, snapshot, real localhost screenshot, WebDriver navigation/redirect/final DOM, WebExtension install/message/storage/uninstall and Nimbus readiness. It never downloads the full 87 MB browser in the validator, invokes a loader, starts a browser, or edits a user profile.

The canonical package SHA-256 is `9cc6b6bb106055d767a1117a216b673367cd91237ad7c41a50ae38bb2542661e`; the archived report's 2,435 recorded `libxul` object inputs, **28** ELF members, **268** direct `DT_NEEDED` edges, **50** distinct dependency names and **36** package-external direct names passed cross-report reconciliation. These are current-pruned-main compiled normal-browser observations, **not** full Cargo/linker symbol/FFI/conditional-load closure. Runtime success originates from the first source-authenticated native Actions run, not from the standalone verifier.

### Repeatable acceptance and negative fixtures

```sh
python3 ci/m3-native-artifact-reconcile.py evidence.zip \
  --source-sha d5cfdb360ec9c3f9d113b2dbcbddaed74f406dfd \
  --run-id 41749398233 \
  --expected-zip-sha256 28a283993c808dd0783995808631109490a4bae8b04db088159be4a16c86f909 \
  --self-test
```

**Verified against this exact downloaded ZIP in the development environment:** `python -m py_compile` succeeded; real evidence reconciled; **20/20 deliberate forgeries were rejected** (15 source, run ID, link-graph/package-replay, protected flags and real-runtime claim mutations, plus 5 hostile ZIP layout/size tests). This is a **local tool test**, not a claimed new native CI run or a release test. The tool's bounded JSON result has explicit `fully_resolved_native_ffi_or_dlopen=false`, `arch_hyprland_workstation_tested=false`, `native_feature_bytes_saved_claimed=null`, `source_removal_authorized=false`.

### Remaining sixth-gate work

The corrected run [41750432275](https://github.com/sguzman/vulpra/actions/runs/41750432275), built from `0889c4c`, should be independently reconciled with **its own actual Actions result, SHA and artifact ID**, never by reusing the first run's artifact metadata. Complete conditional native `dlopen`/FFI branch and fallback graph, broader protected-feature activation and actual EndeavourOS/Hyprland GPU/library/UI parity remain open. The standalone static graph's `current_main_compiled_source_matched=false` correctly says the static script alone cannot authenticate source, whereas the joined external workflow metadata and staged native evidence can provide this scoped source match.

No source removal, no measured marginal package savings, no change to installed Firefox Developer Edition or user profiles. **M3 remains 5/6=83%, overall 61%, Δ+0 percentage points.**
