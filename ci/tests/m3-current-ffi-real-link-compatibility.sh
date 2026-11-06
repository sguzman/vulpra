#!/usr/bin/env bash
# Compatibility replay: genuine older compiled-native JSON plus deliberately
# SYNTHETIC FFI member rows. This is parser QA, NOT an FFI runtime acceptance.
set -euo pipefail
: "${GH_TOKEN:?GitHub Actions read token required}"
test "${GITHUB_REPOSITORY:-}" = "sguzman/vulpra"
command -v gh >/dev/null
command -v jq >/dev/null
source_sha=96454f7a1fbe6b505af440c6c2c5fc91e798756d
run_id=41762298450
tmp="$(mktemp -d)"
trap "rm -rf -- '$tmp'" EXIT

gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run_id" > "$tmp/run.json"
jq -e --arg sha "$source_sha" --argjson id "$run_id" '
  .id == $id and .head_sha == $sha and .head_branch == "main" and
  .head_repository.full_name == "sguzman/vulpra" and
  .name == "M3 Source Matched Native Link Inputs and Runtime" and
  .path == ".github/workflows/m3-source-matched-native-link.yml" and
  .event == "push" and .status == "completed" and .conclusion == "success" and
  .run_attempt == 1
' "$tmp/run.json" >/dev/null

gh run download "$run_id" --repo "$GITHUB_REPOSITORY" \
  --name m3-source-matched-native-link-evidence --dir "$tmp/evidence"
mapfile -t native < <(find "$tmp/evidence" -type f -name m3-native-link-inputs.json -print)
test "${#native[@]}" -eq 1
jq -e --arg sha "$source_sha" --argjson id "$run_id" '
  .source_commit == $sha and .workflow_run_id == $id and
  .runtime_passed_after_link_audit == true and
  .packaging_transform_replay.deterministic_reproduction_verified == true and
  (.built_libxul_sha256 | test("^[a-f0-9]{64}$")) and
  .linker_full_map_recorded == false and .source_removal_authorized == false
' "${native[0]}" >/dev/null

# Every fabricated member name is conspicuously marked SYNTHETIC.
# The acceptance here verifies ONLY the contract against an authentic link
# report; the original native run never archived these Rust member records.
jq -n --arg src "$source_sha" \
  --arg elf "$(jq -r '.built_libxul_sha256' "${native[0]}")" \
  --arg arc "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" '
{
  schema_version:1,
  status:"bounded_real_compiled_gkrust_archive_member_and_libxul_definitions",
  source_commit:$src,rust_staticlib:"libgkrust.a",consumer_elf:"libxul.so",
  libxul_unstripped_sha256:$elf,rust_archive_sha256:$arc,
  rust_archive_bytes:4096,libxul_unstripped_bytes:20000000,rust_archive_members:2,
  named_ffi_symbol_pairs:2,
  symbol_members:[
    {symbol:"GkRust_Init",archive_member:"SYNTHETIC_init.o",
     archive_definition_count:1,consumer_definition_count:1},
    {symbol:"GkRust_Shutdown",archive_member:"SYNTHETIC_shutdown.o",
     archive_definition_count:1,consumer_definition_count:1}
  ],
  compiled_current_rust_archive_member_definitions_observed:true,
  compiled_current_elf_named_definitions_observed:true,
  complete_member_to_linker_selection_graph_proven:false,
  complete_rust_cpp_ffi_graph_proven:false,
  dynamic_or_indirect_ffi_closure_proven:false,
  additional_source_pruning_authorized:false,m3_sixth_gate_closed:false
}
' > "$tmp/synthetic-ffi.json"

jq -n --slurpfile link "${native[0]}" \
  --slurpfile ffi "$tmp/synthetic-ffi.json" \
  --arg source "$source_sha" --argjson run "$run_id" \
  -f ci/m3-current-ffi-native-evidence.jq > "$tmp/compatibility.json"
jq -e '
  .actual_native_runtime_evidence_joined == true and
  .two_named_rust_archive_and_elf_definitions_verified == true and
  .complete_archive_member_to_linker_selection_graph_proven == false and
  .complete_cpp_rust_ffi_graph_proven == false and
  .new_source_pruning_authorized == false and .m3_sixth_gate_closed == false
' "$tmp/compatibility.json" >/dev/null

jq '.libxul_unstripped_sha256=("0"*64)' \
  "$tmp/synthetic-ffi.json" > "$tmp/forged-ffi.json"
if jq -n --slurpfile link "${native[0]}" \
  --slurpfile ffi "$tmp/forged-ffi.json" \
  --arg source "$source_sha" --argjson run "$run_id" \
  -f ci/m3-current-ffi-native-evidence.jq >/dev/null 2>&1; then
  echo "FAIL: accepted wrong ELF SHA against authentic prior native report" >&2
  exit 1
fi
echo "PASS: genuine prior compiled-native link report authenticated and compatible with FFI evidence schema"
echo "PASS: falsified linked ELF SHA rejected against that authentic native report"
echo "LIMIT: all FFI members here are explicitly SYNTHETIC; this is not actual current compiled FFI acceptance"
