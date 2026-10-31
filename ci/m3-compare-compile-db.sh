#!/usr/bin/env bash
# Compare source-pinned Mozilla CompileDBBackend compiler command declarations.
# Generating compile_commands.json is NOT executing clang, rustc, or the linker.
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 3 ]; then
  echo 'usage: m3-compare-compile-db.sh FULL_OBJDIR LEAN_OBJDIR OUTPUT_JSON' >&2
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
[ -s "$full/compile_commands.json" ] && [ -s "$lean/compile_commands.json" ]

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
canonical_db() {
  local root=$1
  local name
  name=$(basename "$root")
  # Normalize only corresponding configured objdir roots/names. No flags,
  # source paths or command arguments are deleted.
  sed -e "s|$root|@CONFIGURED_OBJDIR@|g" \
      -e "s|$name|@CONFIGURED_OBJDIR_NAME@|g" \
      "$root/compile_commands.json" |
    jq -c '.[] | [.file, .directory, .command] | @json' | sort -u
}
for side in full lean; do
  if [ "$side" = full ]; then root=$full
  else root=$lean; fi
  jq -e 'type=="array" and length>500 and
    all(.[]; (.directory|type)=="string" and (.file|type)=="string" and
      (.command|type)=="string")' "$root/compile_commands.json" >/dev/null
  jq -r 'length' "$root/compile_commands.json" > "$tmp/$side-count"
  canonical_db "$root" > "$tmp/$side-records"
  [ "$(wc -l < "$tmp/$side-records")" -gt 500 ]
done

comm -12 "$tmp/full-records" "$tmp/lean-records" > "$tmp/shared-records"
comm -23 "$tmp/full-records" "$tmp/lean-records" > "$tmp/full-only-records"
comm -13 "$tmp/full-records" "$tmp/lean-records" > "$tmp/lean-only-records"

# Report bounded file identities, not the full compiler command-line lists.
# @json represents a tuple string, so decode it back to [file,dir,command].
for side in full lean; do
  jq -r 'fromjson | .[0]' "$tmp/$side-only-records" | sort -u > "$tmp/$side-only-files"
done
full_count=$(cat "$tmp/full-count")
lean_count=$(cat "$tmp/lean-count")
full_records=$(wc -l < "$tmp/full-records")
lean_records=$(wc -l < "$tmp/lean-records")
shared_records=$(wc -l < "$tmp/shared-records")
full_only_records=$(wc -l < "$tmp/full-only-records")
lean_only_records=$(wc -l < "$tmp/lean-only-records")
[ "$full_records" -eq "$((shared_records + full_only_records))" ]
[ "$lean_records" -eq "$((shared_records + lean_only_records))" ]
[ "$full_records" -le "$full_count" ] && [ "$lean_records" -le "$lean_count" ]
full_files=$(wc -l < "$tmp/full-only-files")
lean_files=$(wc -l < "$tmp/lean-only-files")

jq -n --arg source "$SOURCE_SHA" \
  --argjson full "$full_count" --argjson lean "$lean_count" \
  --argjson full_records "$full_records" --argjson lean_records "$lean_records" \
  --argjson shared "$shared_records" \
  --argjson full_only "$full_only_records" --argjson lean_only "$lean_only_records" \
  --argjson full_files "$full_files" --argjson lean_files "$lean_files" \
  --rawfile full_sample <(head -n 12 "$tmp/full-only-files") \
  --rawfile lean_sample <(head -n 12 "$tmp/lean-only-files") '
  def lines: split("\n") | map(select(length>0));
  {
    schema_version:1,
    status:"pinned_configured_mozilla_compiledb_command_declarations_compared",
    source_commit:$source,
    normal_compiler_command_entries:$full,
    combined_compiler_command_entries:$lean,
    normal_distinct_compiler_command_records:$full_records,
    combined_distinct_compiler_command_records:$lean_records,
    identical_normalized_command_records:$shared,
    normal_only_command_records:$full_only,
    combined_only_command_records:$lean_only,
    normal_only_distinct_file_count:$full_files,
    combined_only_distinct_file_count:$lean_files,
    normal_only_file_sample:($full_sample|lines),
    combined_only_file_sample:($lean_sample|lines),
    complete_raw_compile_commands_archived:false,
    normalized_only_configured_object_directory_paths_and_names:true,
    compiler_commands_generated_but_not_executed:true,
    actual_compiler_or_linker_executed:false,
    rustc_and_linker_command_closure_proven:false,
    generated_source_contents_proven:false,
    ffi_and_runtime_dlopen_graph_proven:false,
    source_pruning_authorized:false,
    m3_sixth_gate_closed:false
  }' > "$out"

jq -e '.normal_compiler_command_entries>500 and
  .combined_compiler_command_entries>500 and
  (.identical_normalized_command_records+.normal_only_command_records ==
   .normal_distinct_compiler_command_records) and
  (.identical_normalized_command_records+.combined_only_command_records ==
   .combined_distinct_compiler_command_records) and
  .actual_compiler_or_linker_executed==false and
  .m3_sixth_gate_closed==false' "$out" >/dev/null
jq -c '{
  declared_commands:[.normal_compiler_command_entries,.combined_compiler_command_entries],
  identical:.identical_normalized_command_records,
  normal_only:.normal_only_command_records,
  combined_only:.combined_only_command_records,
  normal_files:.normal_only_distinct_file_count,
  combined_files:.combined_only_distinct_file_count,
  normal_sample:.normal_only_file_sample[:4],
  combined_sample:.combined_only_file_sample[:4]
}' "$out"
