# Independently reconcile one source-owned current Rust archive export with
# one actual compiled crashhelper C++ direct branch and the native package.
# This is an acceptance contract, NOT evidence that a current-native archive
# report has already been emitted. All inputs must originate in one authenticated
# normal native run; a fixture alone cannot satisfy that origin requirement.
def insist($ok;$why): if $ok then true else error($why) end;

insist(
  ($link|length)==1 and ($package|length)==1 and
  ($direct|length)==1 and ($archive|length)==1;
  "Exactly one link, packaged ELF, current direct-branch and Rust archive report required"
) |
$link[0] as $l |
$package[0] as $p |
$direct[0] as $d |
$archive[0] as $a |
($p.elf_members | map(select(.name=="crashhelper"))) as $helpers |
[
  insist($l.schema_version==1 and
    $l.source_commit==$source and $l.workflow_run_id==$run and
    $l.native_build_required==true and
    $l.runtime_passed_after_link_audit==true and
    $l.linker_full_map_recorded==false and
    $l.source_removal_authorized==false and
    ($l.package.package_sha256|type)=="string" and
    ($l.package.package_sha256|test("^[0-9a-f]{64}$")) and
    $l.packaging_transform_replay.deterministic_reproduction_verified==true;
    "Authentic current normal native build and runtime report required"),
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
    "Normal same-source package must contain exactly one crashhelper ELF"),
  insist($d.schema_version==1 and
    $d.status=="one_current_linked_crashhelper_main_direct_branch_to_named_ffi_definition" and
    $d.source_commit==$source and $d.consumer_elf=="crashhelper" and
    ($d.unstripped_crashhelper_sha256|type)=="string" and
    ($d.unstripped_crashhelper_sha256|test("^[0-9a-f]{64}$")) and
    ($d.unstripped_crashhelper_bytes|type)=="number" and
    $d.unstripped_crashhelper_bytes>64 and
    $d.main_strong_text_definitions==1 and
    $d.crash_generator_logic_desktop_text_definitions==1 and
    $d.main_to_crash_generator_logic_desktop_direct_branches==1 and
    $d.compiled_direct_branch_to_named_ffi_export_verified==true;
    "Actual compiled main-to-Rust direct ABI branch missing"),
  insist($a.schema_version==1 and
    $a.status=="bounded_current_crashhelper_rust_staticlib_export_and_linked_elf_definition" and
    $a.source_commit==$source and
    $a.rust_staticlib=="libcrash_helper_server.a" and
    $a.consumer_elf=="crashhelper" and
    ($a.rust_archive_sha256|type)=="string" and
    ($a.rust_archive_sha256|test("^[0-9a-f]{64}$")) and
    ($a.rust_archive_bytes|type)=="number" and
    $a.rust_archive_bytes>64 and
    ($a.rust_archive_members|type)=="number" and
    $a.rust_archive_members>=1 and $a.rust_archive_members<=1000000 and
    $a.export_name=="crash_generator_logic_desktop" and
    $a.export_strong_archive_definition_count==1 and
    $a.export_linked_elf_text_definition_count==1 and
    ($a.export_archive_member|type)=="string" and
    ($a.export_archive_member|test("^[a-zA-Z0-9._+@$-]{1,255}$")) and
    $a.real_rust_archive_member_definition_observed==true and
    $a.real_linked_elf_definition_observed==true;
    "Source-owned real Rust archive member or linked crashhelper definition missing"),
  insist($a.unstripped_crashhelper_sha256==$d.unstripped_crashhelper_sha256 and
    $a.unstripped_crashhelper_bytes==$d.unstripped_crashhelper_bytes;
    "Archive-member and direct-branch verifiers examined different unstripped crashhelper ELF"),
  insist($d.real_rust_archive_member_proven==false and
    $d.all_cpp_rust_ffi_edges_enumerated==false and
    $d.conditional_or_indirect_ffi_closure_proven==false and
    $d.source_pruning_authorized==false and
    $d.m3_sixth_gate_closed==false and
    $a.archive_member_selected_by_final_linker_proven==false and
    $a.all_rust_archive_member_selection_edges_proven==false and
    $a.complete_cpp_rust_ffi_graph_proven==false and
    $a.conditional_or_indirect_ffi_closure_proven==false and
    $a.source_pruning_authorized==false and
    $a.m3_sixth_gate_closed==false;
    "Unsupported full linker, FFI closure, pruning or milestone claim")
] | all as $verified |
{
  schema_version:1,
  status:"one_current_rust_crashhelper_archive_owner_and_cpp_direct_branch_source_linked",
  native_source_commit:$source,
  native_run_id:$run,
  authenticated_build_runtime_and_package_joined:$verified,
  rust_staticlib_sha256:$a.rust_archive_sha256,
  rust_staticlib_member_count:$a.rust_archive_members,
  strong_archive_export_owner:$a.export_archive_member,
  compiled_unstripped_crashhelper_sha256:$a.unstripped_crashhelper_sha256,
  packaged_crashhelper_sha256:$helpers[0].sha256,
  one_named_rust_archive_export_and_linked_elf_definition:true,
  one_named_cpp_main_direct_branch:true,
  source_owned_rust_archive_member_compiled:true,
  archive_member_selected_by_final_linker_proven:false,
  all_cpp_rust_ffi_edges_enumerated:false,
  conditional_ffi_or_dlopen_closure_proven:false,
  complete_protected_feature_activation_proven:false,
  target_endeavouros_hyprland_accepted:false,
  source_removal_authorized:false,
  m3_sixth_gate_closed:false
}
