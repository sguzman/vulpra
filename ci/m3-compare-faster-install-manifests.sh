#!/usr/bin/env bash
# Source-pinned actual FasterMakeBackend install-manifest ownership comparison.
# Read-only generated resource declarations, NOT installed package contents.
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 3 ]; then
  echo 'usage: m3-compare-faster-install-manifests.sh FULL_OBJDIR LEAN_OBJDIR OUTPUT_JSON' >&2
  exit 2
fi
full=$(realpath "$1")
lean=$(realpath "$2")
out=$3
[ "$SOURCE_SHA" = "b1482404dfb8b01342990ee99ea3df0f9756b5f7" ]
[ "$(dirname "$full")" = "$PWD" ] && [ "$(dirname "$lean")" = "$PWD" ]
[ "$(basename "$full")" = "obj-vulpra-linux-m3-baseline" ]
[ "$(basename "$lean")" = "obj-vulpra-linux-m3-combined-lean" ]
[[ "$full" =~ ^/[-_./a-zA-Z0-9]+$ ]] && [[ "$lean" =~ ^/[-_./a-zA-Z0-9]+$ ]]
[ -d "$full/faster" ] && [ -d "$lean/faster" ]

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for side in full lean; do
  if [ "$side" = full ]; then root=$full; else root=$lean; fi
  find "$root/faster" -maxdepth 1 -type f \
    \( -name 'install_*' -o -name unified_install_dist_bin \) \
    -printf '%f\n' | sort -u > "$tmp/$side"
done
full_count=$(wc -l < "$tmp/full")
lean_count=$(wc -l < "$tmp/lean")
[ "$full_count" -gt 0 ] && [ "$lean_count" -gt 0 ]
[ "$full_count" -lt 1000 ] && [ "$lean_count" -lt 1000 ]
grep -Fxq unified_install_dist_bin "$tmp/full"
grep -Fxq unified_install_dist_bin "$tmp/lean"

comm -12 "$tmp/full" "$tmp/lean" > "$tmp/shared"
comm -23 "$tmp/full" "$tmp/lean" > "$tmp/only-full"
comm -13 "$tmp/full" "$tmp/lean" > "$tmp/only-lean"
: > "$tmp/identical"
: > "$tmp/different"

normalized_sha() {
  local root=$1
  local rel=$2
  local name
  name=$(basename "$root")
  sed -b -e "s|$root|@CONFIGURED_OBJDIR@|g" \
         -e "s|$name|@CONFIGURED_OBJDIR_NAME@|g" \
         "$root/faster/$rel" | sha256sum | cut -d ' ' -f 1
}
while IFS= read -r rel; do
  [ -f "$full/faster/$rel" ] && [ -f "$lean/faster/$rel" ]
  if [ "$(normalized_sha "$full" "$rel")" = "$(normalized_sha "$lean" "$rel")" ]; then
    printf '%s\n' "$rel" >> "$tmp/identical"
  else
    printf '%s\n' "$rel" >> "$tmp/different"
  fi
done < "$tmp/shared"

shared_count=$(wc -l < "$tmp/shared")
same_count=$(wc -l < "$tmp/identical")
different_count=$(wc -l < "$tmp/different")
[ "$full_count" -eq "$((shared_count + $(wc -l < "$tmp/only-full")))" ]
[ "$lean_count" -eq "$((shared_count + $(wc -l < "$tmp/only-lean")))" ]
[ "$shared_count" -eq "$((same_count + different_count))" ]

jq -n --arg sha "$SOURCE_SHA" \
  --argjson full "$full_count" --argjson lean "$lean_count" \
  --argjson shared "$shared_count" --argjson same "$same_count" \
  --argjson different "$different_count" \
  --rawfile only_full "$tmp/only-full" \
  --rawfile only_lean "$tmp/only-lean" \
  --rawfile changed "$tmp/different" '
    def lines: split("\n")|map(select(length>0));
    {
      schema_version:1,
      status:"actual_source_matched_faster_generated_install_manifests",
      source_commit:$sha,
      full_generated_install_manifest_count:$full,
      combined_generated_install_manifest_count:$lean,
      shared_generated_install_manifest_count:$shared,
      identical_normalized_generated_install_manifest_count:$same,
      differing_normalized_generated_install_manifest_count:$different,
      full_only_generated_install_manifests:($only_full|lines),
      combined_only_generated_install_manifests:($only_lean|lines),
      differing_generated_install_manifests:($changed|lines),
      manifest_files_are_actual_generated_files:true,
      only_configured_objdir_paths_normalized:true,
      manifest_entry_semantics_parsed:false,
      installed_package_contents_proven:false,
      actual_compiler_or_linker_executed:false,
      ffi_or_late_dlopen_closure_proven:false,
      source_pruning_authorized:false,
      m3_sixth_gate_closed:false
    }
  ' > "$out"
jq -e '
  .source_commit=="b1482404dfb8b01342990ee99ea3df0f9756b5f7" and
  .full_generated_install_manifest_count>0 and
  .combined_generated_install_manifest_count>0 and
  (.identical_normalized_generated_install_manifest_count +
   .differing_normalized_generated_install_manifest_count ==
   .shared_generated_install_manifest_count) and
  ((.differing_generated_install_manifests|length) ==
   .differing_normalized_generated_install_manifest_count) and
  .installed_package_contents_proven==false and
  .m3_sixth_gate_closed==false
' "$out" >/dev/null
jq -c '{
  generated_manifests:[.full_generated_install_manifest_count,.combined_generated_install_manifest_count],
  shared:.shared_generated_install_manifest_count,
  identical:.identical_normalized_generated_install_manifest_count,
  differing:.differing_normalized_generated_install_manifest_count,
  full_only:.full_only_generated_install_manifests,
  lean_only:.combined_only_generated_install_manifests,
  first_changed:(.differing_generated_install_manifests[:8])
}' "$out"
