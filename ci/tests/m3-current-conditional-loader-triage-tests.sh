#!/usr/bin/env bash
# Validate independently retrieved source-matched native reports and reject
# fabricated direct-loader, source, package, conditional or closure claims.
# Usage: script LINK_JSON LOADER_JSON PACKAGE_JSON SOURCE_SHA RUN_ID
set -euo pipefail
if [ "$#" -ne 5 ]; then
  echo "usage: $0 LINK LOADER PACKAGE SOURCE_SHA NATIVE_RUN_ID" >&2
  exit 2
fi
link="$1"; loader="$2"; package="$3"; source="$4"; run="$5"
filter=ci/m3-current-conditional-loader-triage.jq
for f in "$link" "$loader" "$package" "$filter"; do test -s "$f"; done
[[ "$source" =~ ^[0-9a-f]{40}$ ]]
[[ "$run" =~ ^[0-9]+$ ]]

check() {
  jq -n --slurpfile link "$1" --slurpfile loader "$2" \
    --slurpfile package "$3" --arg source "$source" --argjson run "$run" \
    -f "$filter"
}
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
check "$link" "$loader" "$package" > "$tmp/accepted.json"
jq -e --arg src "$source" --argjson run "$run" '
  .schema_version == 1 and
  .status == "source_linked_current_compiled_conditional_loader_callsite_gap_triage" and
  .native_source_commit == $src and .native_run_id == $run and
  .authenticated_compiled_source_package_runtime_and_direct_loader_report_joined == true and
  .scoped_compiled_direct_loader_branches == 73 and
  .scoped_distinct_caller_api_kind_records == 47 and
  .scoped_targeted_risk_witnesses == 12 and
  .scoped_targeted_direct_branches == 19 and
  (.scoped_witnesses | length) == 12 and
  ([.scoped_witnesses[].id] | unique | length) == 12 and
  all(.scoped_witnesses[];
    .observed_direct_branches >= 1 and
    .actual_requested_library_arg_verified == false and
    .conditional_fallback_exercised == false and
    .feature_safe_to_remove == false) and
  .indirect_loader_calls_enumerated == false and
  .library_name_arguments_and_dlsym_targets_proven == false and
  .all_caller_symbols_in_other_packaged_elfs_enumerated == false and
  .alternative_runtime_feature_paths_exercised == false and
  .platform_endeavouros_hyprland_parity_proven == false and
  .full_dependency_ffi_and_feature_closure_proven == false and
  .additional_source_pruning_authorized == false and
  .m3_sixth_gate_closed == false and .release_ready == false
' "$tmp/accepted.json" >/dev/null
failures=0
reject() {
  if check "$1" "$2" "$3" > "$tmp/fake-output.json" 2>/dev/null; then
    echo "FAIL: forged compiled conditional-loader evidence accepted ($4)" >&2
    exit 1
  fi
  failures=$((failures + 1))
}
while IFS= read -r mutation; do
  jq "$mutation" "$loader" > "$tmp/forged-loader.json"
  reject "$link" "$tmp/forged-loader.json" "$package" "$mutation"
done <<'LOADER_MUTATIONS'
.source_commit = ("0" * 40)
.unstripped_native_elf_sha256 = ("0" * 64)
.direct_loader_branches = 74
.distinct_caller_loader_kind_records = 46
.direct_loader_callsite_records[0].native_branches += 1
.direct_loader_callsite_records[0].loader_api = "faux"
.direct_loader_callsite_records[0].branch_kind = "indirect"
.direct_loader_callsite_records[0].caller_symbol = ""
.indirect_loader_calls_enumerated = true
.every_dynamic_loader_api_enumerated = true
.actual_dynamic_library_names_verified = true
.conditional_runtime_routes_exercised = true
.all_elf_consumers_covered = true
.arch_workstation_verified = true
.source_pruning_authorized = true
.m3_sixth_gate_closed = true
(.direct_loader_callsite_records[] | select(.caller_symbol | contains("GetOrtAPIEv")) | .loader_api) = "dlopen"
(.direct_loader_callsite_records[] | select(.caller_symbol | contains("LlamaRuntimeLinker4InitEv")) | .native_branches) = 2
(.direct_loader_callsite_records[] | select(.caller_symbol | contains("GbmLib4Load")) | .caller_symbol) = "_ZN7mozilla19FFmpegRuntimeLinker4InitEv"
.direct_loader_callsite_records |= .[:-1]
.direct_loader_callsite_records += [ .direct_loader_callsite_records[0] ]
LOADER_MUTATIONS
while IFS= read -r mutation; do
  jq "$mutation" "$link" > "$tmp/forged-link.json"
  reject "$tmp/forged-link.json" "$loader" "$package" "$mutation"
done <<'LINK_MUTATIONS'
.source_commit = ("0" * 40)
.workflow_run_id = 1
.built_libxul_sha256 = ("0" * 64)
.runtime_passed_after_link_audit = false
.packaging_transform_replay.deterministic_reproduction_verified = false
.source_removal_authorized = true
LINK_MUTATIONS
while IFS= read -r mutation; do
  jq "$mutation" "$package" > "$tmp/forged-package.json"
  reject "$link" "$loader" "$tmp/forged-package.json" "$mutation"
done <<'PACKAGE_MUTATIONS'
.source_commit = ("0" * 40)
.archive_sha256 = ("0" * 64)
.direct_needed_edges = 267
.elf_members |= .[:-1]
.dlopen_and_indirect_runtime_dependencies_complete = true
.source_removal_authorized = true
PACKAGE_MUTATIONS
test "$failures" -eq 33
echo "PASS: real source-linked 12 conditional loader witnesses / 19 direct branches, 33/33 forged evidence cases rejected"
echo "LIMIT: caller symbols only; not library args, indirect loaders, runtime fallbacks, M3 gate six, pruning or release"
