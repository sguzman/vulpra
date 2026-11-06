# Independently reconcile a completed exact-source normal native build's
# Rust archive/consumer symbol census against the existing linked ELF report.
# Input: jq -n --slurpfile link FILE --slurpfile ffi FILE
#        --arg source SHA --argjson run ID -f this.jq
# Source/runtime provenance is validated by the calling Actions workflow.
# Successful output is bounded FFI evidence, not a full feature dependency map.
def insist($condition;$message):
  if $condition then true else error($message) end;
($link | length) as $lc |
($ffi | length) as $fc |
insist($lc == 1 and $fc == 1;"Expected exactly one linked-native and FFI report") |
$link[0] as $l |
$ffi[0] as $f |
[
  insist($l.schema_version == 1 and $l.source_commit == $source and
    $l.workflow_run_id == $run and $l.native_build_required == true and
    $l.runtime_passed_after_link_audit == true and
    $l.source_removal_authorized == false;
    "Original full native run identity or runtime acceptance invalid"),
  insist($l.linker_full_map_recorded == false and
    $l.libxul_link_input_response.contains_rust_archive_reference == false and
    $l.libxul_link_input_response.contains_archive_references == false;
    "Existing response list falsely elevated to complete linker proof"),
  insist(($l.built_libxul_sha256 | type) == "string" and
    ($l.built_libxul_sha256 | test("^[0-9a-f]{64}$")) and
    $l.packaging_transform_replay.original_libxul_sha256 == $l.built_libxul_sha256 and
    $l.packaging_transform_replay.deterministic_reproduction_verified == true;
    "Existing native ELF SHA or packaging replay unverified"),
  insist($f.schema_version == 1 and
    $f.status == "bounded_real_compiled_gkrust_archive_member_and_libxul_definitions" and
    $f.source_commit == $source and
    $f.rust_staticlib == "libgkrust.a" and
    $f.consumer_elf == "libxul.so" and
    $f.libxul_unstripped_sha256 == $l.built_libxul_sha256;
    "FFI evidence not source and ELF bound to real compiled native run"),
  insist(($f.rust_archive_sha256 | type) == "string" and
    ($f.rust_archive_sha256 | test("^[0-9a-f]{64}$")) and
    ($f.rust_archive_bytes | type) == "number" and
    $f.rust_archive_bytes > 64 and $f.rust_archive_bytes < 17179869184 and
    ($f.libxul_unstripped_bytes | type) == "number" and
    $f.libxul_unstripped_bytes > 10000000 and
    ($f.rust_archive_members | type) == "number" and
    $f.rust_archive_members > 0 and $f.rust_archive_members <= 1000000;
    "No plausibly bounded actual compiled Rust archive/member census"),
  insist($f.named_ffi_symbol_pairs == 2 and
    ($f.symbol_members | type) == "array" and
    ($f.symbol_members | length) == 2 and
    ([$f.symbol_members[].symbol] | sort) ==
      ["GkRust_Init","GkRust_Shutdown"] and
    (all($f.symbol_members[];
      (.archive_member | type) == "string" and
      (.archive_member | test("^[A-Za-z0-9._+@$-]{1,255}$")) and
      (.archive_definition_count == 1) and
      (.consumer_definition_count == 1)));
    "Required real native archive-member definitions absent, duplicate or unbounded"),
  insist($f.compiled_current_rust_archive_member_definitions_observed == true and
    $f.compiled_current_elf_named_definitions_observed == true and
    $f.complete_member_to_linker_selection_graph_proven == false and
    $f.complete_rust_cpp_ffi_graph_proven == false and
    $f.dynamic_or_indirect_ffi_closure_proven == false and
    $f.additional_source_pruning_authorized == false and
    $f.m3_sixth_gate_closed == false;
    "Real native FFI evidence overclaims feature closure or pruning authority")
] | all as $verified |
{
  schema_version: 1,
  status: "source_linked_compiled_gkrust_archive_ffi_definitions_reconciled",
  source_commit: $source,
  native_run_id: $run,
  compiled_unstripped_libxul_sha256: $l.built_libxul_sha256,
  current_rust_archive_sha256: $f.rust_archive_sha256,
  examined_rust_archive_member_count: $f.rust_archive_members,
  named_source_owned_archive_ffi_pairs: $f.named_ffi_symbol_pairs,
  actual_native_runtime_evidence_joined: $verified,
  two_named_rust_archive_and_elf_definitions_verified: $verified,
  complete_archive_member_to_linker_selection_graph_proven: false,
  complete_cpp_rust_ffi_graph_proven: false,
  indirect_runtime_ffi_and_dlopen_closure_proven: false,
  target_endeavouros_hyprland_workstation_verified: false,
  new_source_pruning_authorized: false,
  m3_sixth_gate_closed: false
}
