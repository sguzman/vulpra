# SOURCE-PINNED INDEPENDENT EVALUATED FRONTEND COUNT AGREEMENT.
# Not an edge-by-edge or compiled-binary equivalence check. Raw original
# graph (5.5MB) is available; current original graph's raw records were NOT
# archived, so only exact counts/selected generated flags can be compared.
def require($ok;$why): if $ok then true else error($why) end;
($original[0]) as $o |
($current[0]) as $c |
($compiledb[0]) as $db |
[
  require(($original|length)==1 and ($current|length)==1 and ($compiledb|length)==1;
    "exactly one independently archived original/current/compiledb report required"),
  require($o.schema_version==1 and
    $o.status=="original_configure_evaluated_mozbuild_frontend" and
    $o.original_source_commit==$source and
    $o.variant=="normal" and
    $o.evaluated_mozbuild_emission==true and
    $o.native_linker_or_binary_executed==false and
    $o.source_pruning_authorized==false and
    $o.m3_sixth_gate_closed==false;
    "untrusted historical original evaluated Mozilla source graph"),
  require($c.schema_version==1 and
    $c.status=="current_main_evaluated_native_frontend_and_compile_command_declarations" and
    $c.current_source_commit==$current_sha and
    $c.compared_against_original_compiled_source_sha==$source and
    $c.original_full_normal_archive_is_not_current_binary==true and
    $c.actual_current_main_configure_completed==true and
    $c.actual_current_mozbuild_frontend_emitted==true and
    $c.generated_current_compiledb_command_declarations==true and
    $c.current_source_native_compilation_executed==false and
    $c.current_source_browser_package_built==false and
    $c.all_runtime_optional_dlopen_or_ffi_edges_enumerated==false and
    $c.target_workstation_abi_parity_proven==false and
    $c.source_pruning_authorized==false and
    $c.native_package_bytes_saved==null and
    $c.m3_sixth_gate_closed==false;
    "untrusted original/current source provenance or false compile claim"),
  require($db.schema_version==1 and
    $db.status=="pinned_configured_mozilla_compiledb_command_declarations_compared" and
    $db.source_commit==$source and
    $db.normal_compiler_command_entries>500 and
    $db.compiler_commands_generated_but_not_executed==true and
    $db.actual_compiler_or_linker_executed==false and
    $db.source_pruning_authorized==false and $db.m3_sixth_gate_closed==false;
    "untrusted historical evaluated native CompileDB command source")
] as $trusted |
[
  {key:"emitted_frontend_objects",
   original:$o.emitted_object_count,current:$c.actual_evaluated_frontend_object_count},
  {key:"evaluated_directory_edges",
   original:$o.evaluated_directory_edges,current:$c.actual_evaluated_source_directory_edges},
  {key:"native_link_target_nodes",
   original:$o.actual_evaluated_linkable_node_count,current:$c.actual_evaluated_link_target_count},
  {key:"declared_native_link_edges",
   original:$o.actual_evaluated_library_link_edge_count,current:$c.actual_evaluated_link_dependency_edges},
  {key:"rust_static_library_targets",
   original:$o.actual_evaluated_rust_library_target_count,current:$c.actual_evaluated_rust_static_libraries},
  {key:"rust_program_targets",
   original:$o.actual_evaluated_rust_program_target_count,current:$c.actual_evaluated_rust_program_targets},
  {key:"evaluated_compile_source_inputs",
   original:$o.actual_evaluated_compile_source_input_count,current:$c.actual_evaluated_compile_source_inputs},
  {key:"evaluated_webidl_binding_units",
   original:$o.actual_evaluated_webidl_binding_unit_count,current:$c.actual_evaluated_webidl_binding_units},
  {key:"evaluated_install_resource_inputs",
   original:$o.actual_evaluated_install_resource_input_count,current:$c.actual_evaluated_install_resource_inputs},
  {key:"actual_generated_c_cpp_compiledb_entries",
   original:$db.normal_compiler_command_entries,current:$c.generated_current_compile_db_entry_count}
] as $counts |
($o.generated_configure_flag_values) as $original_flags |
($c.actual_generated_configure_selected_flags) as $current_flags |
[
  require(($counts|length)==10 and
    ([ $counts[].key ]|unique|length)==10 and
    all($counts[]; (.original|type)=="number" and .original>0 and
                   (.current|type)=="number" and .current>0 and
                   .original==.current);
    "original/current count aggregates differ"),
  require(($original_flags|type)=="object" and
    $original_flags==$current_flags and
    ($original_flags|keys|length)==12 and
    $original_flags.MOZ_WIDGET_TOOLKIT.value=="gtk" and
    $original_flags.MOZ_WAYLAND.value=="1" and
    $original_flags.MOZ_X11.value=="1" and
    $original_flags.MOZ_SANDBOX.value=="1" and
    $original_flags.MOZ_CRASHREPORTER.value=="1" and
    $original_flags.MOZ_UPDATER.value=="1" and
    $original_flags.MOZ_SERVICES_SYNC.value=="1" and
    $original_flags.MOZ_NORMANDY.value=="1" and
    $original_flags.MOZ_DEVTOOLS.value=="all" and
    $original_flags.VULPRA_NO_ASROUTER_PROMOS.value=="" and
    $original_flags.VULPRA_NO_NEWTAB_ADSFEED.value=="" and
    $original_flags.VULPRA_NO_NEWTAB_PROMOCARD.value=="";
    "historical/current selected protected generated flags diverge")
] as $verified |
{
  schema_version:1,
  status:"independent_original_vs_current_mozilla_evaluated_native_count_agreement",
  original_compiled_source_commit:$source,
  current_evaluated_source_commit:$current_sha,
  original_full_compiled_archive_sha256:$original_archive,
  original_frontend_evidence_from_original_sha:true,
  current_frontend_evidence_from_distinct_current_sha:true,
  original_full_compiled_package_is_not_current_compiled_binary:true,
  source_bound_independent_original_and_current_buildreader_runs:true,
  compared_generated_frontend_metric_count:($counts|length),
  all_ten_independently_measured_aggregate_counts_match:true,
  compared_actual_selected_generated_flag_count:($original_flags|keys|length),
  all_twelve_protected_generated_flags_match:true,
  counts:[$counts[]|. + {match:(.original==.current)}],
  selected_protected_flags:[$original_flags|to_entries[]|
    {key:.key,original_value:.value.value,current_value:$current_flags[.key].value,match:true}],
  actual_original_linker_commands_or_compiled_package_rebuilt_in_this_join:false,
  exact_per_edge_and_per_compiler_command_record_equality_proven:false,
  entire_current_source_tree_identical_to_historical_original_proven:false,
  actual_current_native_compiler_or_linker_executed:false,
  generated_cargo_feature_dependency_closure_proven:false,
  actual_complete_future_dynamic_ffi_dependencies_proven:false,
  protected_feature_runtime_parity_proven:false,
  target_endeavouros_hyprland_abi_parity_proven:false,
  source_pruning_authorized:false,
  native_bytes_saved:0,
  m3_sixth_gate_closed:false,
  audit_is_read_only:true
}
