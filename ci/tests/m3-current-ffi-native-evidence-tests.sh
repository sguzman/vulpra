#!/usr/bin/env bash
# Synthetic tests of the read-only native evidence join.
# Never claim these fabricated records were produced by Firefox.
set -euo pipefail
src=ci/m3-current-ffi-native-evidence.jq
tmp="$(mktemp -d)"
trap "rm -rf -- '$tmp'" EXIT
sha=0123456789abcdef0123456789abcdef01234567
elf=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
arc=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
run=41762298450

jq -n --arg sha "$sha" --arg elf "$elf" --argjson run "$run" '
{schema_version:1,source_commit:$sha,workflow_run_id:$run,native_build_required:true,
 runtime_passed_after_link_audit:true,source_removal_authorized:false,
 linker_full_map_recorded:false,
 libxul_link_input_response:{contains_rust_archive_reference:false,contains_archive_references:false},
 built_libxul_sha256:$elf,
 packaging_transform_replay:{original_libxul_sha256:$elf,deterministic_reproduction_verified:true}}
' > "$tmp/link.json"

jq -n --arg sha "$sha" --arg elf "$elf" --arg arc "$arc" '
{schema_version:1,status:"bounded_real_compiled_gkrust_archive_member_and_libxul_definitions",
 source_commit:$sha,rust_staticlib:"libgkrust.a",consumer_elf:"libxul.so",
 libxul_unstripped_sha256:$elf,rust_archive_sha256:$arc,
 rust_archive_bytes:8192,libxul_unstripped_bytes:25000000,rust_archive_members:4,
 named_ffi_symbol_pairs:2,symbol_members:[
 {symbol:"GkRust_Init",archive_member:"one.rcgu.o",archive_definition_count:1,consumer_definition_count:1},
 {symbol:"GkRust_Shutdown",archive_member:"two.rcgu.o",archive_definition_count:1,consumer_definition_count:1}],
 compiled_current_rust_archive_member_definitions_observed:true,
 compiled_current_elf_named_definitions_observed:true,
 complete_member_to_linker_selection_graph_proven:false,
 complete_rust_cpp_ffi_graph_proven:false,
 dynamic_or_indirect_ffi_closure_proven:false,
 additional_source_pruning_authorized:false,
 m3_sixth_gate_closed:false}
' > "$tmp/ffi.json"

verify() {
  jq -ne --slurpfile link "$1" --slurpfile ffi "$2" \
    --arg source "$sha" --argjson run "$run" \
    -f "$src" >/dev/null
}
verify "$tmp/link.json" "$tmp/ffi.json"
count=0

while IFS= read -r mutation; do
  jq "$mutation" "$tmp/ffi.json" > "$tmp/forged-ffi.json"
  if verify "$tmp/link.json" "$tmp/forged-ffi.json" 2>/dev/null; then
    echo "FAIL: accepted forged compiled FFI assertion: $mutation" >&2; exit 1
  fi
  count=$((count + 1))
done <<'FFI_MUTATIONS'
.source_commit = ("0" * 40)
.status = "fake"
.rust_staticlib = "libwrong.a"
.consumer_elf = "vulpra"
.libxul_unstripped_sha256 = ("0" * 64)
.rust_archive_sha256 = "invalid"
.rust_archive_bytes = 0
.libxul_unstripped_bytes = 0
.rust_archive_members = 0
.named_ffi_symbol_pairs = 3
.symbol_members |= .[:1]
.symbol_members[0].symbol = "fake_export"
.symbol_members[0].archive_member = "../escape.o"
.symbol_members[0].archive_definition_count = 2
.symbol_members[1].consumer_definition_count = 0
.compiled_current_rust_archive_member_definitions_observed = false
.compiled_current_elf_named_definitions_observed = false
.complete_member_to_linker_selection_graph_proven = true
.complete_rust_cpp_ffi_graph_proven = true
.dynamic_or_indirect_ffi_closure_proven = true
.additional_source_pruning_authorized = true
.m3_sixth_gate_closed = true
FFI_MUTATIONS

while IFS= read -r mutation; do
  jq "$mutation" "$tmp/link.json" > "$tmp/forged-link.json"
  if verify "$tmp/forged-link.json" "$tmp/ffi.json" 2>/dev/null; then
    echo "FAIL: accepted forged native build evidence: $mutation" >&2; exit 1
  fi
  count=$((count + 1))
done <<'LINK_MUTATIONS'
.source_commit = ("0" * 40)
.workflow_run_id = 1
.runtime_passed_after_link_audit = false
.source_removal_authorized = true
.linker_full_map_recorded = true
.libxul_link_input_response.contains_rust_archive_reference = true
.built_libxul_sha256 = ("0" * 64)
.packaging_transform_replay.deterministic_reproduction_verified = false
LINK_MUTATIONS

test "$count" -eq 30
echo "PASS: 30/30 forged source, symbol, archive, ELF, runtime and pruning claims rejected"
echo "LIMIT: synthetic regression fixtures, not actual native Firefox compiled acceptance"
