# Independent source/run join for one actual current compiled crashhelper machine
# branch. No separately archived crashhelper ELF or Rust archive is present.
# Native CI verifies the input ELF directly before emitting its bounded JSON.
def insist($ok;$message): if $ok then true else error($message) end;
insist(($link|length)==1 and ($crash|length)==1;
  "Exactly one native link and current crashhelper report required") |
$link[0] as $l | $crash[0] as $c |
[
  insist($l.schema_version==1 and
    $l.source_commit==$source and $l.workflow_run_id==$run and
    $l.native_build_required==true and
    $l.runtime_passed_after_link_audit==true and
    $l.linker_full_map_recorded==false and
    $l.source_removal_authorized==false and
    $l.packaging_transform_replay.deterministic_reproduction_verified==true;
    "Authentic exact-source native runtime/link evidence required"),
  insist($c.schema_version==1 and
    $c.status=="one_current_linked_crashhelper_main_direct_branch_to_named_ffi_definition" and
    $c.source_commit==$source and $c.consumer_elf=="crashhelper" and
    ($c.unstripped_crashhelper_sha256|type)=="string" and
    ($c.unstripped_crashhelper_sha256|test("^[0-9a-f]{64}$")) and
    ($c.unstripped_crashhelper_bytes|type)=="number" and
    $c.unstripped_crashhelper_bytes>64 and
    $c.main_strong_text_definitions==1 and
    $c.crash_generator_logic_desktop_text_definitions==1 and
    $c.main_to_crash_generator_logic_desktop_direct_branches==1 and
    $c.compiled_direct_branch_to_named_ffi_export_verified==true;
    "Current crashhelper main -> Rust ABI direct machine branch unverified"),
  insist($c.real_rust_archive_member_proven==false and
    $c.all_cpp_rust_ffi_edges_enumerated==false and
    $c.conditional_or_indirect_ffi_closure_proven==false and
    $c.source_pruning_authorized==false and
    $c.m3_sixth_gate_closed==false;
    "Crashhelper report falsely claims wider FFI closure")
] | all as $verified |
{
  schema_version: 1,
  status: "source_matched_current_linked_crashhelper_direct_ffi_machine_branch_reconciled",
  native_source_commit: $source,
  native_run_id: $run,
  authenticated_native_build_and_runtime_joined: $verified,
  reported_unstripped_crashhelper_sha256: $c.unstripped_crashhelper_sha256,
  verified_exact_crashhelper_main_direct_branch_count: 1,
  independent_crashhelper_elf_hash_witnessed_elsewhere: false,
  rust_archive_member_source_proven: false,
  complete_cpp_rust_ffi_graph_proven: false,
  conditional_or_indirect_ffi_closure_proven: false,
  target_endeavouros_hyprland_verified: false,
  source_pruning_authorized: false,
  m3_sixth_gate_closed: false
}