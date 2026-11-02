# Original Linux browser: selected-feature-only compiled native ELF loader
# callsites versus real bounded graphical dynamic request observations.
# Only selected named direct calls and imports; not exhaustive dlopen paths.
def insist($ok; $msg): if $ok then true else error($msg) end;
($census[0]) as $c |
($map[0]) as $m |
($dynamic[0]) as $d |
($c.per_elf|map({key:.elf_basename,value:.})|from_entries) as $native |
($m.rows|map({key:.elf,value:.})|from_entries) as $owners |
(["crashreporter","libclearkey.so","libmozinference.so","libonnxruntime.so","pingsender","updater","vulpra-bin"]) as $selected |
([$m.rows[]|select(.original_native_binding_observation=="selected_feature_workloads_only")|.elf]|sort) as $feature_only |
[
 insist($c.schema_version==1 and
        $c.status=="original_27_non_libxul_loader_api_import_and_direct_branch_census" and
        $c.original_source_commit==$src and
        $c.original_native_archive_sha256==$sha and
        $c.original_packaged_elf_members==28 and
        $c.excluded_previously_audited_libxul_members==1 and
        $c.non_libxul_elf_members_inspected==27 and
        ($c.per_elf|length)==27 and
        ($native|length)==27 and
        $c.non_libxul_elves_with_loader_api_imports==16 and
        $c.non_libxul_direct_named_loader_api_branches==47 and
        $c.only_selected_imports_and_named_direct_branches==true and
        $c.all_possible_dynamic_library_routes_proven==false and
        $c.runtime_library_argument_values_verified==false and
        $c.source_pruning_authorized==false and $c.m3_sixth_gate_closed==false;
        "untrusted original 27 compiled ELF loader-import/branch report"),
 insist($m.schema_version==1 and
        $m.status=="original_28_elf_ubuntu_arch_per_elf_loader_and_source_crosswalk_verified" and
        $m.original_source_commit==$src and
        $m.original_archive_sha256==$sha and
        $m.source_manifest_owners==28 and
        $m.original_runtime_requester_observed_count==28 and
        ($owners|length)==28 and
        $m.complete_future_dlopen_closure_proven==false and
        $m.source_pruning_authorized==false and
        $m.m3_sixth_gate_closed==false;
        "untrusted original 28 compiled ELF source/loader/runtime binding report"),
 insist($d.schema_version==1 and
        $d.status=="original_graphical_21_dynamic_requests_outside_both_per_elf_loader_lists" and
        $d.original_source_commit==$src and
        $d.original_archive_sha256==$sha and
        ($d.rows|length)==21 and
        $d.observed_graphical_loader_dynamic_request_edges==21 and
        $d.original_trace_is_one_bounded_graphical_workload==true and
        $d.complete_future_dlopen_ffi_or_feature_graph_proven==false and
        $d.source_pruning_authorized==false and
        $d.m3_sixth_gate_closed==false;
        "untrusted original bounded 21-edge graphical startup dynamic loader report"),
 insist($selected==$feature_only and
        all($selected[]; $native[.]!=null and $owners[.]!=null);
        "exact seven original feature-only native ELF identities drifted"),
 insist(([$d.rows[].requester]|unique|sort)==["libnspr4.so","libxul.so","vulpra"] and
        all($selected[]; . as $n |
            all($d.rows[]; .requester!=$n and .requested_library!=$n));
        "feature-only ELF unexpectedly observed in bounded graphical dynamic trace")
] as $auth |
[
 $selected[] as $name |
 ($native[$name]) as $n |
 ($owners[$name]) as $m |
 {
   elf:$name,
   original_source_manifest:$m.source_manifest,
   source_manifest_anchor_line:$m.source_manifest_anchor_line,
   source_declaration_class:$m.source_declaration_class,
   selected_feature_workload_native_binding_observed:($m.original_runtime_requester_observed==true),
   observed_in_graphical_21_dynamic_request_trace:false,
   ubuntu_direct_needed_count:$m.direct_needed_ubuntu,
   arch_direct_needed_count:$m.direct_needed_arch,
   compiled_dynamic_loader_api_import_names:$n.dynamic_undefined_loader_api_imports,
   compiled_named_direct_loader_api_branch_count:$n.named_direct_loader_api_branches,
   compiled_named_direct_branch_records:$n.direct_branches,
   direct_branch_runtime_execution_proven:false,
   indirect_or_future_loader_calls_enumerated:false,
   not_seen_in_graphical_trace_does_not_authorize_pruning:true
 }
] as $rows |
[
 insist(($rows|length)==7 and
        all($rows[];
           (.original_source_manifest|type)=="string" and
           .source_manifest_anchor_line>0 and
           .selected_feature_workload_native_binding_observed==true and
           .observed_in_graphical_21_dynamic_request_trace==false and
           .ubuntu_direct_needed_count==.arch_direct_needed_count and
           (.compiled_dynamic_loader_api_import_names|type)=="array" and
           (.compiled_named_direct_loader_api_branch_count|type)=="number" and
           ([.compiled_named_direct_branch_records[].native_branches]|add//0)==.compiled_named_direct_loader_api_branch_count and
           .not_seen_in_graphical_trace_does_not_authorize_pruning==true);
        "original feature-only source/compiled branch partition drifted"),
 insist(([$rows[]|select(.compiled_dynamic_loader_api_import_names|length>0)]|length)==4 and
        ([$rows[]|select(.compiled_named_direct_loader_api_branch_count>0)]|length)==3 and
        ([$rows[].compiled_named_direct_loader_api_branch_count]|add)==8 and
        ($native["libonnxruntime.so"].dynamic_undefined_loader_api_imports==["dlopen"]) and
        ($native["libonnxruntime.so"].named_direct_loader_api_branches==1) and
        ($native["pingsender"].named_direct_loader_api_branches==6) and
        ($native["crashreporter"].dynamic_undefined_loader_api_imports==["dlopen"] and
         $native["crashreporter"].named_direct_loader_api_branches==0);
        "actual feature-only original compiled loader candidates drifted")
] as $proof |
{
 schema_version:1,
 status:"original_feature_only_seven_elf_compiled_loader_candidate_boundaries",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 original_compiled_27_elf_census_run:41350581069,
 original_28_elf_source_platform_matrix_run:41515803526,
 bounded_original_graphical_dynamic_trace_run:41522017287,
 original_feature_only_elf_count:7,
 feature_only_compiled_loader_importer_count:4,
 feature_only_with_named_direct_loader_branches:3,
 feature_only_named_direct_loader_branches:8,
 per_elf_source_and_ubuntu_arch_direct_needed_verified:true,
 original_feature_specific_real_binding_witnesses:7,
 feature_only_elves_not_seen_in_this_graphical_dynamic_request_trace:7,
 missing_from_one_graphical_trace_does_not_prove_dead_code:true,
 no_selected_feature_native_dynamic_calls_executed_by_this_test:true,
 compiled_selected_direct_branches_do_not_imply_runtime_execution:true,
 other_indirect_dynamic_loads_not_enumerated:true,
 all_future_optional_or_required_loader_routes_proven:false,
 no_native_application_rebuilt_or_run_by_crosscheck:true,
 source_pruning_authorized:false,
 m3_sixth_gate_closed:false,
 rows:$rows
}
