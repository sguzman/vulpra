#!/usr/bin/env bash
# Synthetic report rejection only; no browser or real crashhelper is built.
set -euo pipefail
source_sha=0123456789abcdef0123456789abcdef01234567
run=42492978832
crash_hash=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
jq -n --arg source "$source_sha" --argjson run "$run" '{
  schema_version:1,source_commit:$source,workflow_run_id:$run,
  native_build_required:true,runtime_passed_after_link_audit:true,
  linker_full_map_recorded:false,source_removal_authorized:false,
  packaging_transform_replay:{deterministic_reproduction_verified:true}
}' > "$tmp/link.json"
jq -n --arg source "$source_sha" --arg hash "$crash_hash" '{
  schema_version:1,
  status:"one_current_linked_crashhelper_main_direct_branch_to_named_ffi_definition",
  source_commit:$source,consumer_elf:"crashhelper",
  unstripped_crashhelper_sha256:$hash,unstripped_crashhelper_bytes:1200000,
  main_strong_text_definitions:1,
  crash_generator_logic_desktop_text_definitions:1,
  main_to_crash_generator_logic_desktop_direct_branches:1,
  compiled_direct_branch_to_named_ffi_export_verified:true,
  real_rust_archive_member_proven:false,
  all_cpp_rust_ffi_edges_enumerated:false,
  conditional_or_indirect_ffi_closure_proven:false,
  source_pruning_authorized:false,m3_sixth_gate_closed:false
}' > "$tmp/crash.json"
verify() {
  jq -n --slurpfile link "$1" --slurpfile crash "$2" \
    --arg source "$source_sha" --argjson run "$run" \
    -f ci/m3-current-crashhelper-machine-branch-evidence.jq >/dev/null
}
verify "$tmp/link.json" "$tmp/crash.json"
bad=0
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/crash.json" > "$tmp/forged.json"
  if verify "$tmp/link.json" "$tmp/forged.json" 2>/dev/null; then
    echo "FAIL: accepted fabricated crashhelper attestation: $mutation" >&2
    exit 1
  fi
  bad=$((bad+1))
done <<'CRASH'
.schema_version = 99
.status = "unverified"
.source_commit = ("0"*40)
.consumer_elf = "libxul.so"
.unstripped_crashhelper_sha256 = "wrong"
.unstripped_crashhelper_bytes = 0
.main_strong_text_definitions = 0
.crash_generator_logic_desktop_text_definitions = 0
.main_to_crash_generator_logic_desktop_direct_branches = 0
.main_to_crash_generator_logic_desktop_direct_branches = 2
.compiled_direct_branch_to_named_ffi_export_verified = false
.real_rust_archive_member_proven = true
.all_cpp_rust_ffi_edges_enumerated = true
.conditional_or_indirect_ffi_closure_proven = true
.source_pruning_authorized = true
.m3_sixth_gate_closed = true
CRASH
while IFS= read -r mutation; do
  jq "$mutation" "$tmp/link.json" > "$tmp/forged.json"
  if verify "$tmp/forged.json" "$tmp/crash.json" 2>/dev/null; then
    echo "FAIL: accepted fabricated native runtime identity: $mutation" >&2
    exit 1
  fi
  bad=$((bad+1))
done <<'NATIVE'
.source_commit = ("0"*40)
.workflow_run_id = 1
.native_build_required = false
.runtime_passed_after_link_audit = false
.linker_full_map_recorded = true
.source_removal_authorized = true
.packaging_transform_replay.deterministic_reproduction_verified = false
NATIVE
test "$bad" -eq 23
test "$(jq -n --slurpfile link "$tmp/link.json" --slurpfile crash "$tmp/crash.json" \
  --arg source "$source_sha" --argjson run "$run" \
  -f ci/m3-current-crashhelper-machine-branch-evidence.jq |
  jq -r '.authenticated_native_build_and_runtime_joined')" = true
echo "PASS: 23/23 synthetic forged current crashhelper source/runtime/ABI claims rejected"
echo "LIMIT: no real Vulpra native crashhelper examined by this fixture"
