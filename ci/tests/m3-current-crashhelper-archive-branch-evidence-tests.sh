#!/usr/bin/env bash
# Synthetic fail-closed contract fixtures only; not evidence of actual Vulpra
# Rust archive member selection or a real current crashhelper ELF.
set -euo pipefail
src=0123456789abcdef0123456789abcdef01234567
run=42492978832
pkg=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
elf=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
rust=23456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

jq -n --arg source "$src" --argjson run "$run" --arg package "$pkg" '{
  schema_version:1,
  source_commit:$source,workflow_run_id:$run,native_build_required:true,
  runtime_passed_after_link_audit:true,linker_full_map_recorded:false,
  source_removal_authorized:false,package:{package_sha256:$package},
  packaging_transform_replay:{deterministic_reproduction_verified:true}
}' > "$tmp/link.json"

jq -n --arg source "$src" --arg package "$pkg" --arg binary "$elf" '{
  schema_version:1,source_commit:$source,archive_sha256:$package,
  direct_needed_edges:268,source_removal_authorized:false,
  dlopen_and_indirect_runtime_dependencies_complete:false,
  elf_members:([range(0;27) | {
     name:("fixture"+(.|tostring)),path:("vulpra/fixture"+(.|tostring)),
     sha256:$binary,logical_bytes:100
  }] + [{
     name:"crashhelper",path:"vulpra/crashhelper",
     sha256:$binary,logical_bytes:250000
  }])
}' > "$tmp/package.json"

jq -n --arg source "$src" --arg binary "$elf" '{
  schema_version:1,
  status:"one_current_linked_crashhelper_main_direct_branch_to_named_ffi_definition",
  source_commit:$source,consumer_elf:"crashhelper",
  unstripped_crashhelper_sha256:$binary,unstripped_crashhelper_bytes:500000,
  main_strong_text_definitions:1,
  crash_generator_logic_desktop_text_definitions:1,
  main_to_crash_generator_logic_desktop_direct_branches:1,
  compiled_direct_branch_to_named_ffi_export_verified:true,
  real_rust_archive_member_proven:false,
  all_cpp_rust_ffi_edges_enumerated:false,
  conditional_or_indirect_ffi_closure_proven:false,
  source_pruning_authorized:false,m3_sixth_gate_closed:false
}' > "$tmp/direct.json"

jq -n --arg source "$src" --arg binary "$elf" --arg archive "$rust" '{
  schema_version:1,
  status:"bounded_current_crashhelper_rust_staticlib_export_and_linked_elf_definition",
  source_commit:$source,rust_staticlib:"libcrash_helper_server.a",
  consumer_elf:"crashhelper",rust_archive_sha256:$archive,
  unstripped_crashhelper_sha256:$binary,
  rust_archive_bytes:1000000,unstripped_crashhelper_bytes:500000,
  rust_archive_members:22,export_name:"crash_generator_logic_desktop",
  export_strong_archive_definition_count:1,
  export_linked_elf_text_definition_count:1,
  export_archive_member:"crash_helper_server.1234-cgu.0.rcgu.o",
  real_rust_archive_member_definition_observed:true,
  real_linked_elf_definition_observed:true,
  archive_member_selected_by_final_linker_proven:false,
  all_rust_archive_member_selection_edges_proven:false,
  complete_cpp_rust_ffi_graph_proven:false,
  conditional_or_indirect_ffi_closure_proven:false,
  source_pruning_authorized:false,m3_sixth_gate_closed:false
}' > "$tmp/archive.json"

verify() {
  jq -n --slurpfile link "$1" --slurpfile package "$2" \
    --slurpfile direct "$3" --slurpfile archive "$4" \
    --arg source "$src" --argjson run "$run" \
    -f ci/m3-current-crashhelper-archive-branch-evidence.jq >/dev/null
}
verify "$tmp/link.json" "$tmp/package.json" "$tmp/direct.json" "$tmp/archive.json"
rejected=0

while IFS= read -r mutation; do
  jq "$mutation" "$tmp/link.json" > "$tmp/mutated.json"
  if verify "$tmp/mutated.json" "$tmp/package.json" "$tmp/direct.json" "$tmp/archive.json" 2>/dev/null; then
    echo "FAIL: accepted forged native source/run: $mutation" >&2; exit 1
  fi
  rejected=$((rejected+1))
done <<'LINK'
.source_commit = ("0"*40)
.workflow_run_id = 1
.native_build_required = false
.runtime_passed_after_link_audit = false
.package.package_sha256 = ("0"*64)
.packaging_transform_replay.deterministic_reproduction_verified = false
LINK

while IFS= read -r mutation; do
  jq "$mutation" "$tmp/package.json" > "$tmp/mutated.json"
  if verify "$tmp/link.json" "$tmp/mutated.json" "$tmp/direct.json" "$tmp/archive.json" 2>/dev/null; then
    echo "FAIL: accepted forged package: $mutation" >&2; exit 1
  fi
  rejected=$((rejected+1))
done <<'PACKAGE'
.source_commit = ("0"*40)
.archive_sha256 = ("0"*64)
.elf_members = .elf_members[:-1]
.elf_members += [.elf_members[-1]]
.elf_members[-1].sha256 = "invalid"
.direct_needed_edges = 0
.source_removal_authorized = true
.dlopen_and_indirect_runtime_dependencies_complete = true
PACKAGE

while IFS= read -r mutation; do
  jq "$mutation" "$tmp/direct.json" > "$tmp/mutated.json"
  if verify "$tmp/link.json" "$tmp/package.json" "$tmp/mutated.json" "$tmp/archive.json" 2>/dev/null; then
    echo "FAIL: accepted forged C++ machine branch: $mutation" >&2; exit 1
  fi
  rejected=$((rejected+1))
done <<'DIRECT'
.source_commit = ("0"*40)
.unstripped_crashhelper_sha256 = ("0"*64)
.unstripped_crashhelper_bytes = 0
.main_to_crash_generator_logic_desktop_direct_branches = 0
.main_to_crash_generator_logic_desktop_direct_branches = 2
.compiled_direct_branch_to_named_ffi_export_verified = false
.m3_sixth_gate_closed = true
DIRECT

while IFS= read -r mutation; do
  jq "$mutation" "$tmp/archive.json" > "$tmp/mutated.json"
  if verify "$tmp/link.json" "$tmp/package.json" "$tmp/direct.json" "$tmp/mutated.json" 2>/dev/null; then
    echo "FAIL: accepted forged current Rust archive member: $mutation" >&2; exit 1
  fi
  rejected=$((rejected+1))
done <<'ARCHIVE'
.source_commit = ("0"*40)
.rust_archive_sha256 = "not-a-valid-sha256"
.unstripped_crashhelper_sha256 = ("0"*64)
.unstripped_crashhelper_bytes = 10
.export_name = "fake_export"
.export_strong_archive_definition_count = 2
.export_archive_member = "../escape"
.archive_member_selected_by_final_linker_proven = true
.conditional_or_indirect_ffi_closure_proven = true
.m3_sixth_gate_closed = true
ARCHIVE

test "$rejected" -eq 31
jq -n --slurpfile link "$tmp/link.json" --slurpfile package "$tmp/package.json" \
  --slurpfile direct "$tmp/direct.json" --slurpfile archive "$tmp/archive.json" \
  --arg source "$src" --argjson run "$run" \
  -f ci/m3-current-crashhelper-archive-branch-evidence.jq |
  jq -e '
    .authenticated_build_runtime_and_package_joined == true and
    .one_named_rust_archive_export_and_linked_elf_definition == true and
    .one_named_cpp_main_direct_branch == true and
    .archive_member_selected_by_final_linker_proven == false and
    .complete_protected_feature_activation_proven == false and
    .source_removal_authorized == false and .m3_sixth_gate_closed == false
  ' >/dev/null
echo "PASS: 31/31 forged current crashhelper Rust archive owner/C++ direct branch/native provenance claims rejected"
echo "LIMIT: synthetic fixtures only, not an actual latest native crashhelper archive proof"
