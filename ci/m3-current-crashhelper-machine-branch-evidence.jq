# Independently join one exact-current compiled crashhelper C++ -> Rust ABI
# direct branch with source/run-authenticated native link and packaged ELF census.
# Packaged crashhelper may be stripped/elfhacked; its digest is NOT asserted
# byte-equal to the unstripped compiled helper. No Rust archive proof is implied.
def insist($ok;$message): if $ok then true else error($message) end;
insist(($link|length)==1 and ($crash|length)==1 and ($package|length)==1;
  "Exactly one native link, current crashhelper and packaged ELF report required") |
$link[0] as $l | $crash[0] as $c | $package[0] as $p |
($p.elf_members | map(select(.name=="crashhelper"))) as $helpers |
[
  insist($l.schema_version==1 and
    $l.source_commit==$source and $l.workflow_run_id==$run and
    $l.native_build_required==true and
    $l.runtime_passed_after_link_audit==true and
    $l.linker_full_map_recorded==false and
    $l.source_removal_authorized==false and
    $l.packaging_transform_replay.deterministic_reproduction_verified==true and
    ($l.package.package_sha256|type)=="string" and
    ($l.package.package_sha256|test("^[0-9a-f]{64}$"));
    "Authentic exact-source native runtime/link evidence required"),
  insist($p.schema_version==1 and
    $p.source_commit==$source and
    $p.archive_sha256==$l.package.package_sha256 and
    ($p.elf_members|type)=="array" and
    ($p.elf_members|length)==28 and
    $p.direct_needed_edges==268 and
    $p.source_removal_authorized==false and
    $p.dlopen_and_indirect_runtime_dependencies_complete==false and
    ($helpers|length)==1 and
    ($helpers[0].path|type)=="string" and
    ($helpers[0].path|endswith("/crashhelper")) and
    ($helpers[0].sha256|type)=="string" and
    ($helpers[0].sha256|test("^[0-9a-f]{64}$")) and
    ($helpers[0].logical_bytes|type)=="number" and
    $helpers[0].logical_bytes>64;
    "Source-matched protected native package lacks one validated crashhelper ELF"),
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
  exact_packaged_crashhelper_present: true,
  packaged_crashhelper_sha256: $helpers[0].sha256,
  packaged_crashhelper_bytes: $helpers[0].logical_bytes,
  verified_exact_crashhelper_main_direct_branch_count: 1,
  byte_equal_unstripped_to_packaged_crashhelper_verified: false,
  independent_unstripped_crashhelper_elf_hash_witnessed_elsewhere: false,
  rust_archive_member_source_proven: false,
  complete_cpp_rust_ffi_graph_proven: false,
  conditional_or_indirect_ffi_closure_proven: false,
  target_endeavouros_hyprland_verified: false,
  source_pruning_authorized: false,
  m3_sixth_gate_closed: false
}