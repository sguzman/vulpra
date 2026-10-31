#!/usr/bin/env bash
# Compare serialized entries of only the source-pinned changed FasterMake install
# manifests. The file format is Mozilla InstallManifest v5 (US-separated).
# This does not execute installs, expand patterns or read installed browser files.
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 4 ]; then
  echo 'usage: m3-compare-faster-manifest-entries.sh FULL_OBJ LEAN_OBJ FILE_AUDIT_JSON OUT_JSON' >&2
  exit 2
fi
full=$(realpath "$1")
lean=$(realpath "$2")
audit=$3
out=$4
[ "$SOURCE_SHA" = "b1482404dfb8b01342990ee99ea3df0f9756b5f7" ]
[ "$(dirname "$full")" = "$PWD" ] && [ "$(dirname "$lean")" = "$PWD" ]
[ "$(basename "$full")" = "obj-vulpra-linux-m3-baseline" ]
[ "$(basename "$lean")" = "obj-vulpra-linux-m3-combined-lean" ]
[ -s "$audit" ]
jq -e '.status=="actual_source_matched_faster_generated_install_manifests" and
  .manifest_files_are_actual_generated_files==true' "$audit" >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' install_dist_bin install_dist_bin_browser unified_install_dist_bin > "$tmp/expected_changed"
jq -r '.differing_generated_install_manifests[]' "$audit" | sort -u > "$tmp/changed"
cmp -s "$tmp/expected_changed" "$tmp/changed"
printf '%s\n' install_dist_bin_moz-src_toolkit_components_nimbus > "$tmp/expected_lean_only"
jq -r '.combined_only_generated_install_manifests[]' "$audit" > "$tmp/lean_only"
cmp -s "$tmp/expected_lean_only" "$tmp/lean_only"
[ "$(jq '.full_only_generated_install_manifests|length' "$audit")" -eq 0 ]

normalize_records() {
  local root=$1
  local manifest=$2
  local name
  name=$(basename "$root")
  [ "$(head -n 1 "$root/faster/$manifest")" = 5 ]
  tail -n +2 "$root/faster/$manifest" |
    sed -e "s|$root|@CONFIGURED_OBJDIR@|g" \
        -e "s|$name|@CONFIGURED_OBJDIR_NAME@|g" |
    sort -u
}
validate_records() {
  local path=$1
  # Every actionable manifest v5 entry has a numeric type and destination
  # separated by ASCII Unit Separator; no expansion/copy is attempted.
  awk -F '\037' '
    NF<2 || $1 !~ /^-?[0-9]+$/ || length($2)==0 { bad=1 }
    END { if (bad) exit 1 }
  ' "$path"
}
: > "$tmp/deltas.jsonl"
for manifest in install_dist_bin install_dist_bin_browser unified_install_dist_bin; do
  [ -f "$full/faster/$manifest" ] && [ -f "$lean/faster/$manifest" ]
  normalize_records "$full" "$manifest" > "$tmp/full-records"
  normalize_records "$lean" "$manifest" > "$tmp/lean-records"
  validate_records "$tmp/full-records"
  validate_records "$tmp/lean-records"
  comm -23 "$tmp/full-records" "$tmp/lean-records" > "$tmp/full-only-records"
  comm -13 "$tmp/full-records" "$tmp/lean-records" > "$tmp/lean-only-records"
  full_entries=$(wc -l < "$tmp/full-records")
  lean_entries=$(wc -l < "$tmp/lean-records")
  full_only=$(wc -l < "$tmp/full-only-records")
  lean_only=$(wc -l < "$tmp/lean-only-records")
  [ "$full_entries" -gt 0 ] && [ "$lean_entries" -gt 0 ]
  [ "$full_only" -gt 0 ] || [ "$lean_only" -gt 0 ]
  awk -F '\037' '{print $2}' "$tmp/full-only-records" |
    sort -u | sed -n '1,8p' > "$tmp/full-sample"
  awk -F '\037' '{print $2}' "$tmp/lean-only-records" |
    sort -u | sed -n '1,8p' > "$tmp/lean-sample"
  jq -nc --arg manifest "$manifest" \
    --argjson full "$full_entries" --argjson lean "$lean_entries" \
    --argjson full_only "$full_only" --argjson lean_only "$lean_only" \
    --rawfile full_sample "$tmp/full-sample" \
    --rawfile lean_sample "$tmp/lean-sample" '
      def lines: split("\n") | map(select(length>0));
      {
        manifest:$manifest,
        normal_serialized_entries:$full,
        combined_serialized_entries:$lean,
        normal_only_serialized_entries:$full_only,
        combined_only_serialized_entries:$lean_only,
        normal_only_destination_sample:($full_sample|lines),
        combined_only_destination_sample:($lean_sample|lines)
      }' >> "$tmp/deltas.jsonl"
done

manifest=install_dist_bin_moz-src_toolkit_components_nimbus
[ -f "$lean/faster/$manifest" ] && [ ! -e "$full/faster/$manifest" ]
normalize_records "$lean" "$manifest" > "$tmp/new-manifest-records"
validate_records "$tmp/new-manifest-records"
new_entries=$(wc -l < "$tmp/new-manifest-records")
[ "$new_entries" -gt 0 ]
awk -F '\037' '{print $2}' "$tmp/new-manifest-records" |
  sort -u | sed -n '1,8p' > "$tmp/new-sample"

jq -s --arg source "$SOURCE_SHA" --argjson new_entries "$new_entries" \
  --rawfile new_sample "$tmp/new-sample" '
    def lines: split("\n")|map(select(length>0));
    {
      schema_version:1,
      status:"pinned_mozilla_faster_manifest_serialized_entry_delta",
      original_source_commit:$source,
      exact_three_changed_manifest_files_compared:true,
      shared_changed_manifest_entry_summaries:.,
      lean_only_nimbus_manifest:"install_dist_bin_moz-src_toolkit_components_nimbus",
      lean_only_nimbus_serialized_entry_count:$new_entries,
      lean_only_nimbus_destination_sample:($new_sample|lines),
      actual_serialized_manifest_v5_records_read:true,
      manifest_pattern_entries_expanded:false,
      installed_browser_package_files_compared:false,
      native_compiler_or_linker_executed:false,
      ffi_and_runtime_dlopen_graph_proven:false,
      source_pruning_authorized:false,
      m3_sixth_gate_closed:false
    }' "$tmp/deltas.jsonl" > "$out"

jq -e '.exact_three_changed_manifest_files_compared==true and
  (.shared_changed_manifest_entry_summaries|length)==3 and
  .lean_only_nimbus_serialized_entry_count>0 and
  .manifest_pattern_entries_expanded==false and
  .installed_browser_package_files_compared==false and
  .m3_sixth_gate_closed==false' "$out" >/dev/null
jq -c '{shared:[.shared_changed_manifest_entry_summaries[] |
  {name:.manifest,normal:.normal_serialized_entries,
   lean:.combined_serialized_entries,
   normal_only:.normal_only_serialized_entries,
   lean_only:.combined_only_serialized_entries}],
  nimbus_manifest_entries:.lean_only_nimbus_serialized_entry_count}' "$out"
