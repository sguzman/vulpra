#!/usr/bin/env bash
# Compare actual Mozilla RecursiveMakeBackend-produced backend.mk files.
# This is source-pinned configured backend evidence, NOT executed compiler/linker commands.
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 3 ]; then
  echo "usage: m3-compare-generated-backend.sh FULL_OBJDIR LEAN_OBJDIR OUTPUT_JSON" >&2
  exit 2
fi

full=$(realpath "$1")
lean=$(realpath "$2")
out=$3
[ -d "$full" ] && [ -d "$lean" ]
[ "$(basename "$full")" = "obj-vulpra-linux-m3-baseline" ]
[ "$(basename "$lean")" = "obj-vulpra-linux-m3-combined-lean" ]
[ "$(dirname "$full")" = "$PWD" ]
[ "$(dirname "$lean")" = "$PWD" ]
# Only use the tightly bounded, allowlisted CI object directories.
[[ "$full" =~ ^/[-_./a-zA-Z0-9]+$ ]]
[[ "$lean" =~ ^/[-_./a-zA-Z0-9]+$ ]]
[ "$SOURCE_SHA" = "b1482404dfb8b01342990ee99ea3df0f9756b5f7" ]

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
find "$full" -type f -name backend.mk -printf '%P\n' | sort -u > "$tmp/full"
find "$lean" -type f -name backend.mk -printf '%P\n' | sort -u > "$tmp/lean"
full_count=$(wc -l < "$tmp/full")
lean_count=$(wc -l < "$tmp/lean")
if [ "$full_count" -lt 500 ] || [ "$lean_count" -lt 500 ]; then
  echo "FAIL: Mozilla backend.mk file inventory unexpectedly small" >&2
  exit 1
fi

comm -12 "$tmp/full" "$tmp/lean" > "$tmp/shared"
comm -23 "$tmp/full" "$tmp/lean" > "$tmp/full_only"
comm -13 "$tmp/full" "$tmp/lean" > "$tmp/lean_only"
: > "$tmp/identical"
: > "$tmp/different"

# Normalize ONLY the configured absolute object directory and its basename.
# All other emitted backend content remains byte-exact. This is intentionally
# conservative and makes differences visible rather than inventing equality.
normalize_backend() {
  local root=$1
  local rel=$2
  local name
  name=$(basename "$root")
  sed -e "s|$root|@CONFIGURED_OBJDIR@|g" \
      -e "s|$name|@CONFIGURED_OBJDIR_NAME@|g" \
      "$root/$rel"
}
backend_hash() {
  normalize_backend "$1" "$2" | sha256sum | cut -d ' ' -f 1
}
while IFS= read -r rel; do
  [ -f "$full/$rel" ] && [ -f "$lean/$rel" ]
  full_hash=$(backend_hash "$full" "$rel")
  lean_hash=$(backend_hash "$lean" "$rel")
  if [ "$full_hash" = "$lean_hash" ]; then
    printf '%s\n' "$rel" >> "$tmp/identical"
  else
    printf '%s\n' "$rel" >> "$tmp/different"
  fi
done < "$tmp/shared"

shared_count=$(wc -l < "$tmp/shared")
same_count=$(wc -l < "$tmp/identical")
different_count=$(wc -l < "$tmp/different")
[ "$shared_count" -eq "$((same_count + different_count))" ]
[ "$full_count" -eq "$((shared_count + $(wc -l < "$tmp/full_only")))" ]
[ "$lean_count" -eq "$((shared_count + $(wc -l < "$tmp/lean_only")))" ]

# Keep only small source-scoped snippets from two real generated Make backend
# files. This is diagnostic evidence, not a complete full-file comparison log.
: > "$tmp/scoped_diff"
for rel in toolkit/content/backend.mk toolkit/modules/backend.mk; do
  if grep -Fxq "$rel" "$tmp/different"; then
    normalize_backend "$full" "$rel" > "$tmp/diff-full"
    normalize_backend "$lean" "$rel" > "$tmp/diff-lean"
    if diff -U 0 "$tmp/diff-full" "$tmp/diff-lean" > "$tmp/diff-output"; then
      echo "FAIL: changed backend file unexpectedly has no normalized diff" >&2
      exit 1
    else
      diff_result=$?
      [ "$diff_result" -eq 1 ]
    fi
    printf 'FILE %s\n' "$rel" >> "$tmp/scoped_diff"
    # Omit diff headers with temporary host paths. Cap each file to 40 lines.
    sed -n '3,42p' "$tmp/diff-output" >> "$tmp/scoped_diff"
  fi
done
head -c 10000 "$tmp/scoped_diff" > "$tmp/scoped_diff_bounded"

jq -n --arg source "$SOURCE_SHA" \
  --argjson full "$full_count" --argjson lean "$lean_count" \
  --argjson common "$shared_count" \
  --argjson identical "$same_count" --argjson differing "$different_count" \
  --rawfile only_full "$tmp/full_only" \
  --rawfile only_lean "$tmp/lean_only" \
  --rawfile changed "$tmp/different" \
  --rawfile scoped_witness "$tmp/scoped_diff_bounded" \
  'def paths: split("\n") | map(select(length > 0));
  {
    schema_version: 1,
    status: "actual_mozilla_generated_recursive_make_backend_mk_compared",
    original_source_commit: $source,
    normal_generated_backend_mk_files: $full,
    combined_generated_backend_mk_files: $lean,
    shared_generated_backend_mk_files: $common,
    identical_normalized_backend_mk_files: $identical,
    differing_normalized_backend_mk_files: $differing,
    normal_only_backend_mk: ($only_full | paths),
    combined_only_backend_mk: ($only_lean | paths),
    differing_normalized_backend_mk: ($changed | paths),
    scoped_normalized_backend_diff_excerpt: $scoped_witness,
    scoped_diff_excerpt_is_bounded_not_full_output: true,
    normalized_only_configured_objdir_absolute_path_and_name: true,
    actual_recursive_make_backend_files_read: true,
    generated_makefile_or_link_command_fully_compared: false,
    native_compile_or_link_executed: false,
    generated_source_contents_proven: false,
    ffi_and_runtime_dlopen_graph_proven: false,
    source_pruning_authorized: false,
    m3_sixth_gate_closed: false
  }' > "$out"

jq -e '.normal_generated_backend_mk_files > 500 and
  .combined_generated_backend_mk_files > 500 and
  .shared_generated_backend_mk_files > 500 and
  (.identical_normalized_backend_mk_files +
   .differing_normalized_backend_mk_files == .shared_generated_backend_mk_files) and
  ((.differing_normalized_backend_mk | length) ==
   .differing_normalized_backend_mk_files) and
  .native_compile_or_link_executed == false and
  .m3_sixth_gate_closed == false' "$out" >/dev/null
jq -c '{backend_files:[.normal_generated_backend_mk_files,.combined_generated_backend_mk_files],
  shared:.shared_generated_backend_mk_files,
  identical:.identical_normalized_backend_mk_files,
  differing:.differing_normalized_backend_mk_files,
  full_only:(.normal_only_backend_mk|length),
  lean_only:(.combined_only_backend_mk|length),
  first_changed:(.differing_normalized_backend_mk[:8])}' "$out"
