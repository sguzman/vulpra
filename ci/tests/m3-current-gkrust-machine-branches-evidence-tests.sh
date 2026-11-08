#!/usr/bin/env bash
# Source-pinned compiled machine-call cross-report checker fixtures.
# All records below are synthetic and never accepted as a Firefox build.
set -euo pipefail
source_sha=0123456789abcdef0123456789abcdef01234567
libxul_sha=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
archive_sha=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
run=42397502966
tmp="$(mktemp -d)"
trap "rm -rf -- '$tmp'" EXIT
jq -n --arg s "$source_sha" --arg e "$libxul_sha" --argjson r "$run" '{
  schema_version:1,source_commit:$s,workflow_run_id:$r,
  native_build_required:true,runtime_passed_after_link_audit:true,
  source_removal_authorized:false,linker_full_map_recorded:false,
  built_libxul_sha256:$e,
  packaging_transform_replay:{
    original_libxul_sha256:$e,deterministic_reproduction_verified:true}
}' > "$tmp/link.json"
jq -n --arg s "$source_sha" --arg e "$libxul_sha" --arg a "$archive_sha" '{
  schema_version:1,
  status:"bounded_real_compiled_gkrust_archive_member_and_libxul_definitions",
  source_commit:$s,rust_staticlib:"libgkrust.a",consumer_elf:"libxul.so",
  libxul_unstripped_sha256:$e,rust_archive_sha256:$a,
  named_ffi_symbol_pairs:2,symbol_members:[
    {symbol:"GkRust_Init",archive_definition_count:1,consumer_definition_count:1},
    {symbol:"GkRust_Shutdown",archive_definition_count:1,consumer_definition_count:1}],
  compiled_current_rust_archive_member_definitions_observed:true,
  compiled_current_elf_named_definitions_observed:true,
  complete_member_to_linker_selection_graph_proven:false,
  complete_rust_cpp_ffi_graph_proven:false,
  dynamic_or_indirect_ffi_closure_proven:false,
  additional_source_pruning_authorized:false,m3_sixth_gate_closed:false
}' > "$tmp/ffi.json"
jq -n --arg s "$source_sha" --arg e "$libxul_sha" '{
 schema_version:1,
 status:"three_current_compiled_cpp_direct_branches_to_named_gkrust_abi_exports",
 source_commit:$s,linked_consumer:"libxul.so",unstripped_consumer_sha256:$e,
 unstripped_consumer_bytes:25000000,caller_functions_verified:3,
 ns_init_xpcom_to_gkrust_init_branches:1,
 ns_init_minimal_xpcom_to_gkrust_init_branches:1,
 mozilla_shutdown_xpcom_to_gkrust_shutdown_branches:1,
 current_machine_code_direct_branch_targets_verified:true,
 all_cpp_rust_ffi_callers_enumerated:false,
 all_rust_archive_members_to_linker_edges_verified:false,
 conditional_or_indirect_ffi_closure_proven:false,
 source_pruning_authorized:false,m3_sixth_gate_closed:false
}' > "$tmp/direct.json"

verify() {
  jq -n --slurpfile link "$1" --slurpfile ffi "$2" \
    --slurpfile direct "$3" --arg source "$source_sha" \
    --argjson run "$run" \
    -f ci/m3-current-gkrust-machine-branches-evidence.jq >/dev/null
}
verify "$tmp/link.json" "$tmp/ffi.json" "$tmp/direct.json"
bad=0
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/direct.json" > "$tmp/forged.json"
  if verify "$tmp/link.json" "$tmp/ffi.json" "$tmp/forged.json" 2>/dev/null; then
    echo "FAIL: accepted forged machine-code direct branch: $mutation" >&2; exit 1
  fi
  bad=$((bad+1))
done <<'DIRECT'
.source_commit = ("0"*40)
.status = "unverified"
.linked_consumer = "not-libxul.so"
.unstripped_consumer_sha256 = ("0"*64)
.unstripped_consumer_bytes = 0
.caller_functions_verified = 2
.ns_init_xpcom_to_gkrust_init_branches = 0
.ns_init_minimal_xpcom_to_gkrust_init_branches = 2
.mozilla_shutdown_xpcom_to_gkrust_shutdown_branches = 0
.current_machine_code_direct_branch_targets_verified = false
.all_cpp_rust_ffi_callers_enumerated = true
.all_rust_archive_members_to_linker_edges_verified = true
.conditional_or_indirect_ffi_closure_proven = true
.source_pruning_authorized = true
.m3_sixth_gate_closed = true
DIRECT
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/ffi.json" > "$tmp/forged.json"
  if verify "$tmp/link.json" "$tmp/forged.json" "$tmp/direct.json" 2>/dev/null; then
    echo "FAIL: accepted forged Rust archive/consumer proof: $mutation" >&2; exit 1
  fi
  bad=$((bad+1))
done <<'FFI'
.source_commit = ("0"*40)
.rust_archive_sha256 = "bad"
.libxul_unstripped_sha256 = ("0"*64)
.symbol_members[0].archive_definition_count = 2
.complete_rust_cpp_ffi_graph_proven = true
FFI
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/link.json" > "$tmp/forged.json"
  if verify "$tmp/forged.json" "$tmp/ffi.json" "$tmp/direct.json" 2>/dev/null; then
    echo "FAIL: accepted forged native source, SHA or runtime: $mutation" >&2; exit 1
  fi
  bad=$((bad+1))
done <<'LINK'
.source_commit = ("0"*40)
.workflow_run_id = 1
.runtime_passed_after_link_audit = false
.built_libxul_sha256 = ("0"*64)
.packaging_transform_replay.deterministic_reproduction_verified = false
LINK
test "$bad" -eq 25
echo "PASS: 25/25 forged native compiled source, FFI, machine branch and gate claims rejected"
echo "LIMIT: these are synthetic evidence-contract fixtures, not real current browser machine branches"
