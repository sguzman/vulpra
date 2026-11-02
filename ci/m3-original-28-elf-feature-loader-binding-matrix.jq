# Exact-original cross-artifact M3 feature/build/loader/runtime-binder matrix.
# Five immutable CI reports: 28 source owners, 28 Ubuntu loader lists,
# 28 Arch loader requesters, 28 runtime binder witnesses, 10 test workloads.
# Does NOT claim per-ELF Arch providers or exhaustively enumerated feature routes.
def mandatory($yes; $what): if $yes then true else error($what) end;
($manifest[0]) as $m |
($ubuntu[0]) as $u |
($arch[0]) as $a |
($runtime[0]) as $r |
($ten[0]) as $t |
($m.per_original_elf|keys) as $names |
($r.startup_unobserved_requesters_exercised_in_other_workloads|sort) as $feature_only |
($t.original_elf_requester_basenames|sort) as $ten_names |
[
  mandatory($m.schema_version==1 and $m.status=="all_original_28_elf_source_manifest_declarations_crosswalked" and
            $m.original_regular_elf_count==28 and $m.source_manifest_anchor_matches==28 and
            $m.source_manifest_declaration_classes_only==true and
            $m.config_guards_not_evaluated==true and $m.all_feature_bundle_reachability_not_proven==true and
            $m.source_removal_authorized==false and $m.m3_sixth_gate_closed==false;
            "unverified original source declaration report"),
  mandatory($u.schema_version==1 and $u.status=="source_pinned_original_all_28_elf_loader_list_resolution" and
            $u.original_elf_members_listed==28 and $u.declared_direct_needed_edges==268 and
            $u.direct_needed_sonames_present_in_loader_lists==268 and
            $u.loader_listed_provider_name_occurrences==586 and
            $u.distinct_loader_listed_provider_basenames==91 and
            $u.glibc_linker_list_metadata_only==true and $u.application_main_executed==false and
            $u.complete_lazy_or_future_dlopen_map_proven==false and $u.source_pruning_authorized==false;
            "unverified original Ubuntu loader metadata report"),
  mandatory($a.schema_version==1 and $a.status=="original_archlinux_userspace_all_28_elf_loader_list_resolved" and
            $a.original_elf_count==28 and $a.original_direct_needed_edges==268 and
            $a.direct_needed_names_listed_in_arch==268 and
            $a.distinct_arch_loader_provider_basenames==90 and
            $a.arch_userspace_container_only==true and $a.application_main_executed==false and
            $a.complete_lazy_transitive_feature_map_proven==false and $a.source_removal_authorized==false;
            "unverified original Arch loader metadata report"),
  mandatory($r.schema_version==1 and $r.status=="all_original_28_elf_requesters_have_bounded_runtime_binding_evidence" and
            $r.original_elf_requester_count==28 and
            $r.original_requesters_seen_during_headless_startup==21 and
            $r.original_requesters_seen_in_selected_feature_workloads==10 and
            $r.overlapping_requester_count==3 and
            $r.every_original_elf_requester_witnessed_in_at_least_one_bounded_workload==true and
            $r.complete_lazy_transitive_dependencies_proven==false and $r.source_removal_authorized==false and
            $r.m3_sixth_gate_closed==false;
            "unverified original runtime requester union"),
  mandatory($t.schema_version==1 and $t.status=="original_native_ten_requester_real_binding_observation_reconciled" and
            $t.original_elf_requester_count==10 and $t.separate_native_workloads_reconciled==7 and
            $t.complete_dependency_or_lazy_binding_map_proven==false and
            $t.new_source_removals_authorized==false and $t.m3_final_dependency_gate_closed==false;
            "unverified original selected-feature requester report"),
  mandatory(all([$m,$u,$a,$r,$t][]; .original_source_commit==$source and .original_archive_sha256==$archive);
            "cross-artifact source or archive identity mismatch"),
  mandatory(($names|length)==28 and
            ($u.per_original_elf|keys)==$names and
            ($u.original_elf_basenames|sort)==$names and
            ($a.original_requester_basenames|sort)==$names and
            ($r.original_elf_requester_basenames|sort)==$names;
            "original 28 ELF names differ across archived source/loader/runtime reports"),
  mandatory(($ten_names|length)==10 and ($ten_names|unique|length)==10 and
            all($ten_names[]; . as $n | $names|index($n)!=null) and
            ($feature_only|length)==7 and ($feature_only|unique|length)==7 and
            all($feature_only[]; . as $n | $ten_names|index($n)!=null);
            "feature-only and selected-workload requester sets disagree")
] as $assertions |
[$names[] as $name |
 ($m.per_original_elf[$name]) as $owner |
 ($u.per_original_elf[$name]) as $link |
 (if ($feature_only|index($name))!=null then "selected_feature_workloads_only"
  elif ($ten_names|index($name))!=null then "headless_and_selected_feature_workloads"
  else "headless_startup_only" end) as $observation |
 {
  elf:$name,
  source_manifest:$owner.source_manifest,
  source_manifest_anchor_line:$owner.anchor_line,
  source_declaration_class:$owner.declaration_class,
  source_declaration_guard_present:$owner.guard_present,
  ubuntu_direct_needed_count:$link.declared_direct_needed_count,
  ubuntu_loader_provider_count:$link.loader_listed_provider_count,
  ubuntu_loader_provider_basenames:$link.loader_listed_provider_basenames,
  native_binding_observation:$observation,
  original_runtime_requester_observed:true,
  arch_direct_needed_resolved_per_elf: null
 }
] as $rows |
[
  mandatory(($rows|length)==28 and
    all($rows[];
      (.source_manifest|type)=="string" and (.source_manifest|startswith("/")|not) and
      (.source_manifest|contains("..")|not) and (.source_manifest_anchor_line|type)=="number" and
      .source_manifest_anchor_line>0 and (.source_declaration_class|type)=="string" and
      (.source_declaration_guard_present|type)=="boolean" and
      (.ubuntu_direct_needed_count|type)=="number" and .ubuntu_direct_needed_count>=0 and
      (.ubuntu_loader_provider_count|type)=="number" and .ubuntu_loader_provider_count>0 and
      (.ubuntu_loader_provider_basenames|type)=="array" and
      (.ubuntu_loader_provider_basenames|length)==.ubuntu_loader_provider_count and
      (.ubuntu_loader_provider_basenames|unique|length)==.ubuntu_loader_provider_count and
      all(.ubuntu_loader_provider_basenames[]; type=="string" and length>0)
    ); "per-ELF source and Ubuntu provider fields are invalid"),
  mandatory(([$rows[].ubuntu_direct_needed_count]|add)==268 and
            ([$rows[].ubuntu_loader_provider_count]|add)==586 and
            ([$rows[]|select(.source_declaration_guard_present==true)]|length)==2;
            "per-ELF build/loader aggregate totals drift"),
  mandatory(([$rows[]|select(.native_binding_observation=="selected_feature_workloads_only")]|length)==7 and
            ([$rows[]|select(.native_binding_observation=="headless_and_selected_feature_workloads")]|length)==3 and
            ([$rows[]|select(.native_binding_observation=="headless_startup_only")]|length)==18;
            "original runtime workload partitions disagree")
] as $row_assertions |
{
 schema_version:1,
 status:"original_28_elf_source_loader_runtime_binding_matrix_crosschecked",
 original_source_commit:$source,
 original_archive_sha256:$archive,
 inputs:{
   original_source_build_manifest_run:41209703132,
   original_ubuntu_loader_run:41207364061,
   original_arch_loader_run:41211418491,
   original_runtime_binding_union_run:41206458805,
   original_selected_feature_binding_run:41206028051
 },
 source_manifest_owners:28,
 ubuntu_direct_needed_edges:268,
 ubuntu_direct_needed_resolved:268,
 arch_container_direct_needed_resolved:268,
 ubuntu_per_elf_loader_provider_occurrences:586,
 ubuntu_distinct_provider_names:91,
 arch_container_distinct_provider_names:90,
 observed_original_runtime_binding_requesters:28,
 headless_startup_only_requesters:18,
 both_headless_and_selected_requesters:3,
 selected_feature_only_requesters:7,
 per_elf_arch_provider_mapping_available:false,
 complete_lazy_and_future_dynamic_loading_map_proven:false,
 runtime_observation_does_not_prove_all_features:true,
 evaluated_source_build_graph_per_elf_proven:false,
 no_native_compilation_or_application_execution_performed:true,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false,
 rows:$rows
}
