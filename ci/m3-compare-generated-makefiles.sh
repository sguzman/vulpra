#!/usr/bin/env bash
# Read-only inventory of actual configured Mozilla RecursiveMakeBackend Makefiles.
# Reports file path/content parity; NEVER infers executed compiler/linker commands.
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 3 ]; then
  echo 'usage: m3-compare-generated-makefiles.sh FULL_OBJDIR LEAN_OBJDIR OUTPUT_JSON' >&2
  exit 2
fi

full=$(realpath "$1")
lean=$(realpath "$2")
out=$3
[ "$SOURCE_SHA" = "b1482404dfb8b01342990ee99ea3df0f9756b5f7" ]
[ -d "$full" ] && [ -d "$lean" ]
[ "$(dirname "$full")" = "$PWD" ] && [ "$(dirname "$lean")" = "$PWD" ]
[ "$(basename "$full")" = "obj-vulpra-linux-m3-baseline" ]
[ "$(basename "$lean")" = "obj-vulpra-linux-m3-combined-lean" ]
[[ "$full" =~ ^/[-_./a-zA-Z0-9]+$ ]] && [[ "$lean" =~ ^/[-_./a-zA-Z0-9]+$ ]]

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
find "$full" -type f -name Makefile -printf '%P\n' | sort -u > "$tmp/full"
find "$lean" -type f -name Makefile -printf '%P\n' | sort -u > "$tmp/lean"
normal_count=$(wc -l < "$tmp/full")
lean_count=$(wc -l < "$tmp/lean")
[ "$normal_count" -gt 500 ] && [ "$lean_count" -gt 500 ]
comm -12 "$tmp/full" "$tmp/lean" > "$tmp/shared"
comm -23 "$tmp/full" "$tmp/lean" > "$tmp/only-full"
comm -13 "$tmp/full" "$tmp/lean" > "$tmp/only-lean"
: > "$tmp/same"
: > "$tmp/different"

# Normalize only explicitly configured objdir path and basename. Do not
# strip arbitrary lines or imply that Make's expanded commands were compared.
normalized_sha() {
  local root=$1
  local rel=$2
  local name
  name=$(basename "$root")
  sed -e "s|$root|@CONFIGURED_OBJDIR@|g" \
      -e "s|$name|@CONFIGURED_OBJDIR_NAME@|g" \
      "$root/$rel" | sha256sum | cut -d ' ' -f 1
}
while IFS= read -r rel; do
  [ -f "$full/$rel" ] && [ -f "$lean/$rel" ]
  if [ "$(normalized_sha "$full" "$rel")" = "$(normalized_sha "$lean" "$rel")" ]; then
    printf '%s\n' "$rel" >> "$tmp/same"
  else
    printf '%s\n' "$rel" >> "$tmp/different"
  fi
done < "$tmp/shared"

common_count=$(wc -l < "$tmp/shared")
same_count=$(wc -l < "$tmp/same")
different_count=$(wc -l < "$tmp/different")
normal_only_count=$(wc -l < "$tmp/only-full")
lean_only_count=$(wc -l < "$tmp/only-lean")
[ "$normal_count" -eq "$((common_count + normal_only_count))" ]
[ "$lean_count" -eq "$((common_count + lean_only_count))" ]
[ "$common_count" -eq "$((same_count + different_count))" ]

jq -n --arg sha "$SOURCE_SHA" \
  --argjson normal "$normal_count" --argjson lean "$lean_count" \
  --argjson shared "$common_count" --argjson same "$same_count" \
  --argjson different "$different_count" \
  --rawfile full_only "$tmp/only-full" \
  --rawfile lean_only "$tmp/only-lean" \
  --rawfile changed "$tmp/different" '
    def lines: split("\n") | map(select(length > 0));
    {
      schema_version:1,
      status:"original_source_actual_generated_makefile_comparison",
      original_source_commit:$sha,
      normal_generated_makefile_count:$normal,
      combined_generated_makefile_count:$lean,
      shared_generated_makefile_count:$shared,
      identical_normalized_makefile_count:$same,
      differing_normalized_makefile_count:$different,
      normal_only_generated_makefiles:($full_only|lines),
      combined_only_generated_makefiles:($lean_only|lines),
      differing_generated_makefiles:($changed|lines),
      normalized_configured_objdir_path_and_basename_only:true,
      actual_generated_makefile_contents_hashed:true,
      all_generated_makefile_rules_equal:false,
      make_recipe_execution_or_expansion_proven:false,
      native_compiler_or_linker_executed:false,
      compiled_object_contents_identical_proven:false,
      ffi_and_runtime_dlopen_graph_proven:false,
      source_pruning_authorized:false,
      m3_sixth_gate_closed:false
    }
  ' > "$out"

jq -e '
  .normal_generated_makefile_count>500 and
  .combined_generated_makefile_count>500 and
  .shared_generated_makefile_count>500 and
  (.identical_normalized_makefile_count + .differing_normalized_makefile_count ==
   .shared_generated_makefile_count) and
  ((.differing_generated_makefiles|length) == .differing_normalized_makefile_count) and
  .native_compiler_or_linker_executed==false and .m3_sixth_gate_closed==false
' "$out" >/dev/null
jq -c '{
  generated_makefiles:[.normal_generated_makefile_count,.combined_generated_makefile_count],
  shared:.shared_generated_makefile_count,
  identical:.identical_normalized_makefile_count,
  changed:.differing_normalized_makefile_count,
  normal_only:(.normal_only_generated_makefiles|length),
  combined_only:(.combined_only_generated_makefiles|length),
  first_changed:(.differing_generated_makefiles[:12])
}' "$out"
