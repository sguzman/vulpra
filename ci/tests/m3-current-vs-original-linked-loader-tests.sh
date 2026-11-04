#!/usr/bin/env bash
# Lightweight synthetic metadata regressions; NOT native runtime or original-source proof.
set -euo pipefail
repo="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
checker="$repo/ci/m3-current-vs-original-linked-loader.jq"
command -v jq >/dev/null
test -f "$checker"
tmp="$(mktemp -d -t vulpra-loader-pair-tests.XXXXXXXX)"
trap 'rm -rf -- "$tmp"' EXIT
oldsrc=b1482404dfb8b01342990ee99ea3df0f9756b5f7
newsrc=96454f7a1fbe6b505af440c6c2c5fc91e798756d
oldhash=$(printf 'a%.0s' {1..64})
newhash=$(printf 'b%.0s' {1..64})
# Entire fixture is synthetic. 47 unique records; 26 doubles + 21 singles = 73.
jq -n --arg source "$oldsrc" --arg hash "$oldhash" '
  def record($i): {
    caller_symbol:("synthetic_caller_"+($i|tostring)),
    loader_api:(if ($i % 3)==0 then "dlopen" elif ($i % 3)==1 then "PR_LoadLibrary" else "PR_LoadLibraryWithFlags" end),
    branch_kind:(if ($i % 5)==0 then "tail-jump" else "call" end),
    native_branches:(if $i < 26 then 2 else 1 end)
  };
  {schema_version:1,source_commit:$source,binary:"libxul.so",
   unstripped_native_elf_sha256:$hash,unstripped_native_elf_bytes:2590405472,
   status:"compiled_direct_loader_api_callsite_census",
   native_instruction_lines:15000000,direct_loader_branches:73,
   distinct_caller_loader_kind_records:47,
   independently_accepted_ffmpeg_to_nspr_call_count:1,
   direct_loader_callsite_records:[range(0;47)|record(.)],
   indirect_loader_calls_enumerated:false,
   every_dynamic_loader_api_enumerated:false,
   actual_dynamic_library_names_verified:false,
   conditional_runtime_routes_exercised:false,
   all_elf_consumers_covered:false,
   arch_workstation_verified:false,
   source_pruning_authorized:false,
   m3_sixth_gate_closed:false}
' > "$tmp/original.json"
jq --arg source "$newsrc" --arg hash "$newhash" \
 '.source_commit=$source|.unstripped_native_elf_sha256=$hash' \
 "$tmp/original.json" > "$tmp/current.json"
run() {
  jq -n --slurpfile original "$tmp/original.json" \
    --slurpfile current "$tmp/current.json" \
    --arg original_source "$oldsrc" --arg current_source "$newsrc" \
    --arg original_elf_sha256 "$oldhash" --arg current_elf_sha256 "$newhash" \
    -f "$checker"
}
run > "$tmp/accepted.json"
jq -e '.exact_both_source_and_elf_identities_checked == true and
       .historical_census.direct_branches == 73 and
       .historical_census.caller_api_kind_records == 47 and
       .changed_records == 0 and
       .all_indirect_loader_calls_or_sonames_enumerated == false and
       .m3_sixth_gate_closed == false and .source_pruning_authorized == false' \
 "$tmp/accepted.json" >/dev/null
for case in source elf_hash size instructions branch_total record_total missing_row \
 duplicate_row fake_api fake_kind blank_caller zero_branch ffmpeg indirect \
 workstation prune m3 historical_bogus_total; do
  base="$tmp/current.json"
  test "$case" = historical_bogus_total && base="$tmp/original.json"
  case "$case" in
    source) jq '.source_commit="0000000000000000000000000000000000000000"' "$base" > "$tmp/changed.json";;
    elf_hash) jq '.unstripped_native_elf_sha256="0000000000000000000000000000000000000000000000000000000000000000"' "$base" > "$tmp/changed.json";;
    size) jq '.unstripped_native_elf_bytes=0' "$base" > "$tmp/changed.json";;
    instructions) jq '.native_instruction_lines=0' "$base" > "$tmp/changed.json";;
    branch_total) jq '.direct_loader_branches+=1' "$base" > "$tmp/changed.json";;
    record_total) jq '.distinct_caller_loader_kind_records+=1' "$base" > "$tmp/changed.json";;
    missing_row) jq '.direct_loader_callsite_records|=.[1:]' "$base" > "$tmp/changed.json";;
    duplicate_row) jq '.direct_loader_callsite_records += [.direct_loader_callsite_records[0]]|.direct_loader_branches+=2|.distinct_caller_loader_kind_records+=1' "$base" > "$tmp/changed.json";;
    fake_api) jq '.direct_loader_callsite_records[0].loader_api="PR_LoadLibraryEvil"' "$base" > "$tmp/changed.json";;
    fake_kind) jq '.direct_loader_callsite_records[0].branch_kind="indirect"' "$base" > "$tmp/changed.json";;
    blank_caller) jq '.direct_loader_callsite_records[0].caller_symbol=""' "$base" > "$tmp/changed.json";;
    zero_branch) jq '.direct_loader_callsite_records[0].native_branches=0|.direct_loader_branches-=2' "$base" > "$tmp/changed.json";;
    ffmpeg) jq '.independently_accepted_ffmpeg_to_nspr_call_count=0' "$base" > "$tmp/changed.json";;
    indirect) jq '.indirect_loader_calls_enumerated=true' "$base" > "$tmp/changed.json";;
    workstation) jq '.arch_workstation_verified=true' "$base" > "$tmp/changed.json";;
    prune) jq '.source_pruning_authorized=true' "$base" > "$tmp/changed.json";;
    m3) jq '.m3_sixth_gate_closed=true' "$base" > "$tmp/changed.json";;
    historical_bogus_total) jq '.direct_loader_callsite_records[0].native_branches+=1|.direct_loader_branches+=1' "$base" > "$tmp/changed.json";;
  esac
  if test "$case" = historical_bogus_total; then
    cp "$tmp/original.json" "$tmp/saved.json"
    cp "$tmp/changed.json" "$tmp/original.json"
  else
    cp "$tmp/current.json" "$tmp/saved.json"
    cp "$tmp/changed.json" "$tmp/current.json"
  fi
  if run > "$tmp/unexpected.json" 2> "$tmp/error.log"; then
    echo "FAIL: forged $case accepted" >&2
    exit 1
  fi
  if test "$case" = historical_bogus_total; then
    mv "$tmp/saved.json" "$tmp/original.json"
  else
    mv "$tmp/saved.json" "$tmp/current.json"
  fi
done
# A genuine multiplicity change is reported without being treated as
# permission to prune a dynamically loaded library or its callers.
jq '.direct_loader_callsite_records[0].native_branches+=1|.direct_loader_branches+=1' \
 "$tmp/current.json" > "$tmp/change.json"
cp "$tmp/current.json" "$tmp/saved.json"
cp "$tmp/change.json" "$tmp/current.json"
run > "$tmp/drift.json"
jq -e '.changed_records==1 and
      (.changed_caller_api_kind_multiplicities|length)==1 and
      .source_pruning_authorized==false and
      .all_indirect_loader_calls_or_sonames_enumerated==false' \
 "$tmp/drift.json" >/dev/null
mv "$tmp/saved.json" "$tmp/current.json"
echo "PASS: synthetic native loader pair; 18/18 forged cases rejected; synthetic drift visible without pruning grant"
