# Independently join exact current compiled C++ machine-call branches to
# actual source-matched gkrust archive-member + linked libxul ABI definitions.
# These are ONLY three named direct callsites, not the complete FFI graph.
def insist($ok;$message):
  if $ok then true else error($message) end;
insist(($link|length)==1 and ($ffi|length)==1 and ($direct|length)==1;
       "Exactly one native link, FFI archive and machine branch report required") |
$link[0] as $l | $ffi[0] as $f | $direct[0] as $d |
[
  insist($l.schema_version==1 and $l.source_commit==$source and
    $l.workflow_run_id==$run and $l.native_build_required==true and
    $l.runtime_passed_after_link_audit==true and
    $l.source_removal_authorized==false;
    "Native source/run mismatch or actual runtime did not pass"),
  insist($l.linker_full_map_recorded==false and
    ($l.built_libxul_sha256 | type)=="string" and
    ($l.built_libxul_sha256 | test("^[0-9a-f]{64}$")) and
    $l.packaging_transform_replay.original_libxul_sha256==$l.built_libxul_sha256 and
    $l.packaging_transform_replay.deterministic_reproduction_verified==true;
    "Native unstripped ELF source or exact package replay untrusted"),
  insist($f.schema_version==1 and
    $f.status=="bounded_real_compiled_gkrust_archive_member_and_libxul_definitions" and
    $f.source_commit==$source and $f.rust_staticlib=="libgkrust.a" and
    $f.consumer_elf=="libxul.so" and
    $f.libxul_unstripped_sha256==$l.built_libxul_sha256 and
    ($f.rust_archive_sha256 | type)=="string" and
    ($f.rust_archive_sha256 | test("^[0-9a-f]{64}$")) and
    $f.named_ffi_symbol_pairs==2 and
    ([$f.symbol_members[].symbol] | sort)==["GkRust_Init","GkRust_Shutdown"] and
    all($f.symbol_members[]; .archive_definition_count==1 and
      .consumer_definition_count==1);
    "Compiled gkrust export definitions missing or not ELF-bound"),
  insist($f.compiled_current_rust_archive_member_definitions_observed==true and
    $f.compiled_current_elf_named_definitions_observed==true and
    $f.complete_member_to_linker_selection_graph_proven==false and
    $f.complete_rust_cpp_ffi_graph_proven==false and
    $f.dynamic_or_indirect_ffi_closure_proven==false and
    $f.additional_source_pruning_authorized==false and
    $f.m3_sixth_gate_closed==false;
    "Compiled FFI archive evidence falsely claims closure"),
  insist($d.schema_version==1 and
    $d.status=="three_current_compiled_cpp_direct_branches_to_named_gkrust_abi_exports" and
    $d.source_commit==$source and $d.linked_consumer=="libxul.so" and
    $d.unstripped_consumer_sha256==$l.built_libxul_sha256 and
    ($d.unstripped_consumer_bytes | type)=="number" and
    $d.unstripped_consumer_bytes>10000000 and
    $d.caller_functions_verified==3 and
    $d.ns_init_xpcom_to_gkrust_init_branches==1 and
    $d.ns_init_minimal_xpcom_to_gkrust_init_branches==1 and
    $d.mozilla_shutdown_xpcom_to_gkrust_shutdown_branches==1 and
    $d.current_machine_code_direct_branch_targets_verified==true;
    "No exact native machine callsites proved against same linked ELF"),
  insist($d.all_cpp_rust_ffi_callers_enumerated==false and
    $d.all_rust_archive_members_to_linker_edges_verified==false and
    $d.conditional_or_indirect_ffi_closure_proven==false and
    $d.source_pruning_authorized==false and
    $d.m3_sixth_gate_closed==false;
    "Direct branch proof falsely claims complete native dependency closure")
] | all as $verified |
{
  schema_version: 1,
  status: "actual_current_compiled_three_cpp_gkrust_machine_branches_joined_to_source_owned_archive_exports",
  native_source_commit: $source,
  native_run_id: $run,
  actual_native_build_and_runtime_joined: $verified,
  source_compiled_rust_archive_sha256: $f.rust_archive_sha256,
  source_compiled_consumer_libxul_sha256: $l.built_libxul_sha256,
  verified_rust_ffi_archive_symbols: 2,
  verified_actual_current_cpp_direct_branch_callers: 3,
  complete_compiled_linker_selection_map_proven: false,
  all_cpp_rust_ffi_edges_enumerated: false,
  indirect_ffi_and_dlopen_closure_proven: false,
  target_endeavouros_hyprland_verified: false,
  new_source_pruning_authorized: false,
  m3_sixth_gate_closed: false
}
