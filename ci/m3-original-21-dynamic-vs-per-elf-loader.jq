# Reconcile 21 genuine original graphical glibc dynamic requests against each
# original packaged requester's independent Ubuntu + Arch glibc --list sets.
# Metadata gaps are observed-workload-only and NOT a general callsite census.
def insist($ok; $message): if $ok then true else error($message) end;
def valid_basename: type=="string" and length>0 and length<=111 and test("^[A-Za-z0-9._+-]+$");
($native[0]) as $n |
($source[0]) as $s |
($map[0]) as $m |
($m.rows|map({key:.elf,value:.})|from_entries) as $owners |
($n.loader_reported_dynamic_initialized_edges|sort_by(.requester_basename,.requested_library_basename)) as $edges |
[
 insist($n.schema_version==1 and
        $n.status=="actual_native_full_normal_loader_observation" and
        $n.observed_workload_mode=="private_weston_wayland" and
        $n.real_native_wayland_surface_commit_passed==true and
        $n.old_normal_native_archive_source==$src and
        $n.old_normal_native_archive_sha256==$sha and
        $n.loader_reported_dynamic_initialized_edge_count==21 and
        $n.request_relationships_from_same_browser_pid_trace==true and
        $n.only_initialized_request_targets_included==true and
        $n.loader_request_edges_complete==false and
        $n.complete_dlopen_graph_proven==false and
        $n.unexecuted_feature_routes_proven==false and
        $n.new_source_removal_authorized==false and
        $n.whole_m3_feature_dependency_gate_completed==false;
        "actual original native graphical trace not authenticated"),
 insist($s.schema_version==1 and
        $s.historical_compiled_source==$src and
        $s.original_package_sha256==$sha and
        $s.original_real_graphical_observed_dynamic_edges==21 and
        $s.original_xpcom_packaged_manifest_preloads==14 and
        $s.independently_source_supported_other_dynamic_edges==7 and
        $s.observed_edge_source_candidate_set_matches_exactly==true and
        $s.source_candidates_are_not_proven_compiled_callsites==true and
        $s.all_possible_dlopen_paths_proven==false and
        $s.source_removal_authorized==false and
        $s.m3_sixth_gate_closed==false;
        "original 21 dynamic source candidates not authenticated"),
 insist($m.schema_version==1 and
        $m.status=="original_28_elf_ubuntu_arch_per_elf_loader_and_source_crosswalk_verified" and
        $m.original_source_commit==$src and
        $m.original_archive_sha256==$sha and
        $m.source_manifest_owners==28 and
        $m.resolved_ubuntu_direct_needed==268 and
        $m.resolved_arch_direct_needed==268 and
        $m.every_original_elf_has_arch_loader_provider_list==true and
        $m.every_elf_direct_needed_count_matches_across_distros==true and
        $m.complete_future_dlopen_closure_proven==false and
        $m.source_pruning_authorized==false and
        $m.m3_sixth_gate_closed==false and
        ($m.rows|length)==28 and ($owners|length)==28;
        "original 28 ELF two-platform list not authenticated"),
 insist(($edges|length)==21 and
        ($edges|unique|length)==21 and
        all($edges[];
          (.requester_basename|valid_basename) and
          (.requested_library_basename|valid_basename) and
          ($owners[.requester_basename]!=null));
        "observed dynamic edges contain duplicates or unknown original requester")
] as $preflight |
[
 $edges[] as $edge |
 ($owners[$edge.requester_basename]) as $requester |
 ($owners[$edge.requested_library_basename]!=null) as $packaged_target |
 ($requester.ubuntu_loader_provider_basenames|index($edge.requested_library_basename)!=null) as $ubuntu_static |
 ($requester.arch_loader_provider_basenames|index($edge.requested_library_basename)!=null) as $arch_static |
 {
   requester:$edge.requester_basename,
   requested_library:$edge.requested_library_basename,
   requester_source_manifest:$requester.source_manifest,
   requester_native_binding_observation:$requester.original_native_binding_observation,
   requested_library_is_packaged_original_elf:$packaged_target,
   requested_library_in_requester_ubuntu_glibc_list:$ubuntu_static,
   requested_library_in_requester_arch_glibc_list:$arch_static,
   source_candidate_group:(
      if $edge.requester_basename=="vulpra" then "manifest_preload_source_candidate"
      elif ($edge.requester_basename=="libnspr4.so" or $edge.requester_basename=="libxul.so") then "other_original_source_candidate"
      else "unclassified_original_observed_requester" end),
   actual_runtime_dynamic_request_observed:true,
   uninstrumented_exact_native_callsite_proven:false
 }
] as $rows |
([$rows[]|select(.requested_library_is_packaged_original_elf)]|length) as $packaged |
([$rows[]|select(.source_candidate_group=="manifest_preload_source_candidate")]|length) as $preloads |
([$rows[]|select(.source_candidate_group=="other_original_source_candidate")]|length) as $other |
([$rows[]|select(.requested_library_in_requester_ubuntu_glibc_list)]|length) as $ubuntu_overlap |
([$rows[]|select(.requested_library_in_requester_arch_glibc_list)]|length) as $arch_overlap |
([
   $rows[]|select(.requested_library_is_packaged_original_elf|not)|.requested_library
 ]|sort) as $host_roots |
[
 insist(($rows|length)==21 and
        $packaged==18 and ($rows|length)-$packaged==3 and
        $preloads==14 and $other==7 and
        $ubuntu_overlap==0 and $arch_overlap==0 and
        $host_roots==["libavcodec.so.60","libgbm.so.1","libpulse.so.0"];
        "observed conditional library counts or name/ordinary-provider classification drift"),
 insist(([$rows[]|select(.requester=="vulpra")]|length)==14 and
        ([$rows[]|select(.requester=="libnspr4.so")]|length)==5 and
        ([$rows[]|select(.requester=="libxul.so")]|length)==2 and
        all($rows[];
          .actual_runtime_dynamic_request_observed==true and
          .uninstrumented_exact_native_callsite_proven==false and
          (.requester_source_manifest|type=="string") and
          .requester_source_manifest!="" and
          .requester_native_binding_observation!=null);
        "actual dynamic request owner/source groups inconsistent")
] as $accept |
{
 schema_version:1,
 status:"original_graphical_21_dynamic_requests_outside_both_per_elf_loader_lists",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 observed_native_workload_run:41149955223,
 original_source_candidate_run:41269693997,
 original_28_elf_platform_matrix_run:41515803526,
 observed_graphical_loader_dynamic_request_edges:21,
 original_packaged_dynamic_request_targets:18,
 conditional_host_library_targets:3,
 conditional_host_library_names:$host_roots,
 original_bootstrap_manifest_source_candidate_edges:14,
 other_original_source_candidate_edges:7,
 observed_requester_basename_counts:{
   vulpra:14,
   "libnspr4.so":5,
   "libxul.so":2
 },
 observed_dynamic_edges_already_listed_under_requester_ubuntu:0,
 observed_dynamic_edges_already_listed_under_requester_arch:0,
 per_elf_glibc_metadata_cannot_substitute_for_conditional_loader_map:true,
 dynamic_request_source_candidate_is_not_exact_callsite:true,
 no_additional_original_native_browser_run:true,
 original_trace_is_one_bounded_graphical_workload:true,
 complete_future_dlopen_ffi_or_feature_graph_proven:false,
 target_endeavouros_hyprland_verified:false,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false,
 rows:$rows
}
