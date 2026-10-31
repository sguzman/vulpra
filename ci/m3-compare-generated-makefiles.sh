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
normalized_makefile() {
  local root=$1
  local rel=$2
  local name
  name=$(basename "$root")
  sed -e "s|$root|@CONFIGURED_OBJDIR@|g" \
      -e "s|$name|@CONFIGURED_OBJDIR_NAME@|g" \
      "$root/$rel"
}
normalized_sha() {
  normalized_makefile "$1" "$2" | sha256sum | cut -d ' ' -f 1
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

# The pinned current source yields exactly one differing generated Makefile.
# Capture a bounded diagnostic excerpt, not the full file or temporary host paths.
[ "$different_count" -eq 1 ]
[ ! -s "$tmp/only-full" ] && [ ! -s "$tmp/only-lean" ]
grep -Fxq 'faster/Makefile' "$tmp/different"
normalized_makefile "$full" faster/Makefile > "$tmp/faster-full"
normalized_makefile "$lean" faster/Makefile > "$tmp/faster-lean"
# This is the sole intended boolean difference in faster/Makefile;
# compare the COMPLETE normalized files after removing only that token.
grep -Fq -- ' -DMOZ_NORMANDY=1 ' "$tmp/faster-full"
if grep -Fq -- ' -DMOZ_NORMANDY=1 ' "$tmp/faster-lean"; then
  echo 'FAIL: lean faster Makefile still defines MOZ_NORMANDY' >&2
  exit 1
fi
sed -e 's/ -DMOZ_NORMANDY=1 / /g' "$tmp/faster-full" > "$tmp/faster-full-expected"
if cmp -s "$tmp/faster-full-expected" "$tmp/faster-lean"; then
  only_normandy_define=true
else
  only_normandy_define=false
fi
# Preserve a small machine-readable explanation of why this additional
# complete-file equivalence check did or did not pass.
grep '^ACDEFINES = ' "$tmp/faster-full" | tr ' ' '\n' | grep '^-D' | sort -u > "$tmp/defines-full"
grep '^ACDEFINES = ' "$tmp/faster-lean" | tr ' ' '\n' | grep '^-D' | sort -u > "$tmp/defines-lean"
comm -23 "$tmp/defines-full" "$tmp/defines-lean" > "$tmp/defines-full-only"
comm -13 "$tmp/defines-full" "$tmp/defines-lean" > "$tmp/defines-lean-only"
# The other changing Makefile variable is a generated installer-manifest
# declaration. Record only exact manifest tokens, not large rule bodies.
sed -n -E 's/^INSTALL_MANIFESTS[[:space:]]*[:+?]?=[[:space:]]*//p' "$tmp/faster-full" |
  tr ' ' '\n' | sed '/^$/d' | sort -u > "$tmp/manifests-full"
sed -n -E 's/^INSTALL_MANIFESTS[[:space:]]*[:+?]?=[[:space:]]*//p' "$tmp/faster-lean" |
  tr ' ' '\n' | sed '/^$/d' | sort -u > "$tmp/manifests-lean"
[ -s "$tmp/manifests-full" ] && [ -s "$tmp/manifests-lean" ]
comm -23 "$tmp/manifests-full" "$tmp/manifests-lean" > "$tmp/manifests-full-only"
comm -13 "$tmp/manifests-full" "$tmp/manifests-lean" > "$tmp/manifests-lean-only"
# Fail closed unless the exact source-pinned generated declaration changes
# match the four expected opt-in/Nimbus members.
printf '%s\n' '-DMOZ_NORMANDY=1' > "$tmp/expected-normal-defines"
printf '%s\n' '-DVULPRA_NO_ASROUTER_PROMOS=1' '-DVULPRA_NO_NEWTAB_ADSFEED=1' > "$tmp/expected-lean-defines"
printf '%s\n' 'dist/bin/moz-src/toolkit/components/nimbus' > "$tmp/expected-lean-manifests"
cmp -s "$tmp/defines-full-only" "$tmp/expected-normal-defines"
cmp -s "$tmp/defines-lean-only" "$tmp/expected-lean-defines"
[ ! -s "$tmp/manifests-full-only" ]
cmp -s "$tmp/manifests-lean-only" "$tmp/expected-lean-manifests"
# Compare complete normalized generated files after removing precisely the
# sanctioned ACDEFINES and INSTALL_MANIFESTS entries; no other changed lines.
sed -e '/^ACDEFINES = /s/ -DMOZ_NORMANDY=1//g' "$tmp/faster-full" > "$tmp/full-expected-only"
sed -e '/^ACDEFINES = /s/ -DVULPRA_NO_ASROUTER_PROMOS=1//g' \
    -e '/^ACDEFINES = /s/ -DVULPRA_NO_NEWTAB_ADSFEED=1//g' \
    -e '/^INSTALL_MANIFESTS = /s| dist/bin/moz-src/toolkit/components/nimbus||g' \
    "$tmp/faster-lean" > "$tmp/lean-expected-only"
if ! cmp -s "$tmp/full-expected-only" "$tmp/lean-expected-only"; then
  echo 'FAIL: faster/Makefile has additional generated rule drift beyond the four expected entries' >&2
  exit 1
fi
[ "$(wc -l < "$tmp/manifests-full")" -lt 200 ] &&
  [ "$(wc -l < "$tmp/manifests-lean")" -lt 200 ]
if diff -U 0 "$tmp/faster-full" "$tmp/faster-lean" > "$tmp/faster-diff"; then
  echo 'FAIL: faster/Makefile differs in hashes but has no line differences' >&2
  exit 1
else
  diff_rc=$?
  [ "$diff_rc" -eq 1 ]
fi
sed -n '3,55p' "$tmp/faster-diff" | head -c 9000 > "$tmp/faster-diff-bounded"
sed -n -E '/^[+-][A-Za-z_][A-Za-z0-9_]*[[:space:]]*[+:?]?=/s/^[+-]([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[+:?]?=.*/\1/p' "$tmp/faster-diff" | sort -u > "$tmp/changed-variable-names"
printf '%s\n' ACDEFINES INSTALL_MANIFESTS > "$tmp/expected-variable-names"
cmp -s "$tmp/changed-variable-names" "$tmp/expected-variable-names"

jq -n --arg sha "$SOURCE_SHA" \
  --argjson normal "$normal_count" --argjson lean "$lean_count" \
  --argjson shared "$common_count" --argjson same "$same_count" \
  --argjson different "$different_count" \
  --rawfile full_only "$tmp/only-full" \
  --rawfile lean_only "$tmp/only-lean" \
  --rawfile changed "$tmp/different" \
  --rawfile scoped_diff "$tmp/faster-diff-bounded" \
  --rawfile full_only_defines "$tmp/defines-full-only" \
  --rawfile lean_only_defines "$tmp/defines-lean-only" \
  --rawfile variable_names "$tmp/changed-variable-names" \
  --rawfile full_only_manifests "$tmp/manifests-full-only" \
  --rawfile lean_only_manifests "$tmp/manifests-lean-only" \
  --argjson only_normandy "$only_normandy_define" '
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
      faster_makefile_normalized_diff_excerpt:$scoped_diff,
      faster_makefile_diff_bounded:true,
      only_faster_makefile_differs:true,
      exactly_four_expected_faster_makefile_token_deltas:true,
      full_generated_faster_makefile_reconciles_after_expected_only:true,
      faster_makefile_only_normandy_define_removed:$only_normandy,
      differing_makefile_variable_names:($variable_names|lines),
      full_only_acdefines:($full_only_defines|lines),
      combined_only_acdefines:($lean_only_defines|lines),
      normal_only_install_manifests:($full_only_manifests|lines),
      combined_only_install_manifests:($lean_only_manifests|lines),
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
  .only_faster_makefile_differs==true and
  .exactly_four_expected_faster_makefile_token_deltas==true and
  .full_generated_faster_makefile_reconciles_after_expected_only==true and
  ((.faster_makefile_normalized_diff_excerpt|length)>0) and
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
